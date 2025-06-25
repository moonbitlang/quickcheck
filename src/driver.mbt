///|
suberror TestError {
  Fail(
    num_tests~ : Int,
    num_discarded~ : Int,
    num_shrinks~ : Int,
    num_shrink_tries~ : Int,
    num_shrink_final~ : Int,
    replay_info~ : Replay,
    reason~ : String,
    error~ : Error,
    output~ : String,
    failing_case~ : Array[String],
    failing_labels~ : Array[String],
    failing_classes~ : @sorted_set.T[String]
  )
  GaveUp(
    num_tests~ : Int,
    num_discarded~ : Int,
    coverage~ : Coverage,
    output~ : String
  )
  NoneExpectedFail(
    num_tests~ : Int,
    num_discarded~ : Int,
    coverage~ : Coverage,
    output~ : String
  )
}

///|
enum TestSuccess {
  Success(num_tests~ : Int, coverage~ : Coverage, output~ : String)
}

///|
pub fn[P : Testable] quick_check(
  prop : P,
  max_shrinks? : Int,
  max_success? : Int,
  max_size? : Int,
  discard_ratio? : Int,
  expect~ : Expected = Success,
  abort~ : Bool = false
) -> Unit raise Failure {
  let prop = map_total_result(prop, fn(res) {
    {
      ..res,
      maybe_num_tests: max_success,
      maybe_max_test_size: max_size,
      maybe_max_shrinks: max_shrinks,
      maybe_discarded_ratio: discard_ratio,
      expect,
      abort,
    }
  })
  quick_check_with(Default::default(), prop)
}

///|
pub fn[A : @quickcheck.Arbitrary + Shrink + Show, B : Testable] quick_check_fn(
  f : (A) -> B,
  max_shrinks? : Int,
  max_success? : Int,
  max_size? : Int,
  discard_ratio? : Int,
  expect~ : Expected = Success,
  abort~ : Bool = false
) -> Unit raise Failure {
  quick_check(
    Arrow(f),
    max_shrinks?,
    max_success?,
    max_size?,
    discard_ratio?,
    expect~,
    abort~,
  )
}

///|
pub fn[P : Testable] quick_check_with(
  cfg : Config,
  prop : P
) -> Unit raise Failure {
  fn f(s : String) -> _ raise Failure {
    fail("\n\{s}")
  }

  try {
    match quick_check_with_result(cfg, prop) {
      Success(output~, coverage~, num_tests~) => {
        println(output)
        println(coverage.to_string(num_tests))
      }
    }
  } catch {
    // TODO: Print coverage
    GaveUp(output~, ..) => f(output)
    Fail(output~, failing_case~, ..) =>
      f(output + "\n" + failing_case.join("\n"))
    NoneExpectedFail(output~, ..) => f(output)
  }
}

///|
pub fn[P : Testable] quick_check_with_result(
  cfg : Config,
  prop : P
) -> TestSuccess raise TestError {
  from_config(cfg).run_test(prop.property())
}

///|
pub fn run_test(self : State, prop : Property) -> TestSuccess raise TestError {
  loop self.run_single_test(prop) {
    Ok(res) => res
    Err(ns) =>
      if ns.finished_successfully() {
        ns.complete_test(prop)
      } else if ns.discarded_too_much() {
        ns.give_up(prop)
      } else {
        continue ns.run_single_test(prop)
      }
  }
}

///|
pub fn complete_test(
  self : State,
  _prop : Property
) -> TestSuccess raise TestError {
  if self.expected is Fail {
    raise NoneExpectedFail(
      num_tests=self.num_success_tests,
      num_discarded=self.num_discarded_tests,
      coverage=self.collects,
      output="*** \{self.counts()} Failed! Expected failure, but passed!",
    )
  } else {
    Success(
      num_tests=self.num_success_tests,
      coverage=self.collects,
      output="+++ \{self.counts()} Ok, passed!",
    )
  }
}

///|
pub fn give_up(self : State, _prop : Property) -> TestSuccess raise TestError {
  if self.expected is GaveUp {
    Success(
      num_tests=self.num_success_tests,
      coverage=self.collects,
      output="+++ \{self.counts()} Ok, gave up!",
    )
  } else {
    raise TestError::GaveUp(
      num_tests=self.num_success_tests,
      num_discarded=self.num_discarded_tests,
      coverage=self.collects,
      output="*** \{self.counts()} Gave up! Passed only \{self.num_success_tests} tests.",
    )
  }
}

///| Run a single test and return the Ok(result) if ended successfully, or Err(state) if it should continue.
pub fn run_single_test(
  self : State,
  prop : Property
) -> Result[TestSuccess, State] raise TestError {
  let rnd1 = self.random_state.split()
  let rnd2 = self.random_state
  let { val: res, branch: ts } = prop.inner().run(self.compute_size(), rnd1)
  fn next(
    end_with : (State, Property) -> TestSuccess raise TestError,
    next_state : State,
    p : Property
  ) -> Result[TestSuccess, State] raise TestError {
    update_state(next_state)
    if res.abort {
      end_with(next_state, p) |> Ok
    } else {
      Err(next_state)
    }
  }

  fn update_state(st0) {
    self.random_state = rnd2
    st0.update_state_from_res(res)
  }

  let stc = self.clone()
  stc.add_coverages(res) // The failure should not be counted.
  self.callback_post_test(res)
  match res {
    { ok: Some(true), .. } =>
      next(
        State::complete_test,
        {
          ..stc,
          num_success_tests: self.num_success_tests + 1,
          num_recent_discarded_tests: 0,
        },
        prop,
      )
    { ok: Some(false), .. } => Ok(self.find_failure(res, ts))
    { ok: None, .. } =>
      next(
        State::give_up,
        {
          ..self,
          num_discarded_tests: self.num_discarded_tests + 1,
          num_recent_discarded_tests: self.num_recent_discarded_tests + 1,
        },
        prop,
      )
  }
}

///|
pub fn find_failure(
  self : State,
  res : SingleResult,
  ts : Iter[Rose[SingleResult]]
) -> TestSuccess raise TestError {
  let (n, tf, lf, ce) = { ..self, num_try_shrinks: 0 }.local_min(res, ts)
  match res.expect {
    Success | GaveUp =>
      raise TestError::Fail(
        error=res.error,
        replay_info=Replay::new(self.random_state, self.compute_size()),
        num_tests=self.num_success_tests + 1,
        num_discarded=self.num_discarded_tests,
        num_shrinks=n,
        num_shrink_tries=tf,
        num_shrink_final=lf,
        reason=res.reason,
        output="*** \{self.counts()} Failed! \{res.reason}",
        failing_case=ce.test_case.to_array(),
        failing_labels=ce.labels.to_array(),
        failing_classes=@sorted_set.new(), // TODO: Add classes
      )
    Fail =>
      Success(
        num_tests=self.num_success_tests + 1,
        coverage=self.collects,
        output="+++ \{self.counts()} Ok! Failed as expected.",
      )
  }
}

///|
pub fn local_min(
  self : State,
  res : SingleResult,
  ts : Iter[Rose[SingleResult]]
) -> (Int, Int, Int, SingleResult) {
  if self.num_success_shrinks + self.num_to_try_shrinks >= self.max_shrinks_ {
    local_min_found(self, res)
  } else {
    let t = ts.head()
    match t {
      Some({ val, branch }) => {
        self.callback_post_test(val)
        match val.ok {
          Some(false) => {
            self.num_success_shrinks += 1
            self.num_try_shrinks = 0
            self.local_min(val, branch)
          }
          _ => {
            self.num_to_try_shrinks += 1
            self.num_try_shrinks += 1
            self.local_min(res, ts.drop(1))
          }
        }
      }
      None => local_min_found(self, res)
    }
  }
}

///|
pub fn local_min_found(
  st : State,
  res : SingleResult
) -> (Int, Int, Int, SingleResult) {
  // TODO: Print error
  (
    st.num_success_shrinks,
    st.num_to_try_shrinks - st.num_try_shrinks,
    st.num_try_shrinks,
    res,
  )
}
