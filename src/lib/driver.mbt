///|
type! TestError {
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
  Success(
    num_tests~ : Int,
    num_discarded~ : Int,
    coverage~ : Coverage,
    output~ : String
  )
}

///|
pub fn quick_check[P : Testable](prop : P) -> Unit!Failure {
  quick_check_with!(Default::default(), prop)
}

///|
pub fn quick_check_fn[A : @quickcheck.Arbitrary + Shrink + Show, B : Testable](
  f : (A) -> B
) -> Unit!Failure {
  quick_check!(Arrow(f))
}

///|
pub fn quick_check_with[P : Testable](cfg : Config, prop : P) -> Unit!Failure {
  fn f(s : String) -> _!Failure {
    fail!("\n\{s}")
  }

  try {
    match quick_check_with_result!(cfg, prop) {
      Success(output~, coverage~, num_tests~, ..) => {
        println(output)
        println(coverage.to_string(num_tests))
      }
    }
  } catch {
    // TODO: Print coverage
    GaveUp(output~, ..) => f!(output)
    Fail(output~, failing_case~, ..) =>
      f!(output + "\n" + String::concat(failing_case, separator="\n"))
    NoneExpectedFail(output~, ..) => f!(output)
  }
}

///|
pub fn quick_check_with_result[P : Testable](
  cfg : Config,
  prop : P
) -> TestSuccess!TestError {
  run_test!(from_config(cfg), prop.property())
}

///|
pub fn run_test(self : State, prop : Property) -> TestSuccess!TestError {
  let mut res = None
  let mut st = self
  while res.is_empty() &&
        not(st.finished_successfully()) &&
        not(st.discarded_too_much()) {
    match st.run_single_test!(prop) {
      Ok(s) => res = Some(s)
      Err(s) => st = s
    }
  } else {
    if st.finished_successfully() {
      st.complete_test!(prop)
    } else if st.discarded_too_much() {
      st.give_up!(prop)
    } else {
      res.unwrap()
    }
  }
}

///|
pub fn complete_test(self : State, _prop : Property) -> TestSuccess!TestError {
  if self.expected == Some(false) {
    raise NoneExpectedFail(
      num_tests=self.num_success_tests,
      num_discarded=self.num_discarded_tests,
      coverage=self.collects,
      output="*** \{self.counts()} Failed! Expected failure, but passed!",
    )
  } else {
    Success(
      num_tests=self.num_success_tests,
      num_discarded=self.num_discarded_tests,
      coverage=self.collects,
      output="+++ \{self.counts()} Ok, passed!",
    )
  }
}

///|
pub fn give_up(self : State, _prop : Property) -> TestSuccess!TestError {
  if self.expected == None {
    Success(
      num_tests=self.num_success_tests,
      num_discarded=self.num_discarded_tests,
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

///|
pub fn run_single_test(
  self : State,
  prop : Property
) -> Result[TestSuccess, State]!TestError {
  let rnd1 = self.random_state.split()
  let rnd2 = self.random_state
  let size = self.compute_size()
  let { val: res, branch: ts } = prop.property.run(size, rnd1)
  fn next(
    end_with : (State, Property) -> TestSuccess!TestError,
    next_state : State,
    p : Property
  ) -> _!TestError {
    update_state(next_state)
    if res.abort {
      end_with!(next_state, p) |> Ok
    } else {
      Err(next_state)
    }
  }

  fn update_state(st0) {
    self.random_state = rnd2
    update_state_from_res(st0, res)
  }

  let stc = self.clone()
  add_coverages(stc, res) // The failure should not be counted.
  callback_post_test(self, res)
  match res {
    { ok: Some(true), .. } =>
      next!(
        complete_test,
        {
          ..stc,
          num_success_tests: self.num_success_tests + 1,
          num_recent_discarded_tests: 0,
        },
        prop,
      )
    { ok: Some(false), .. } => Ok(self.find_failure!(res, ts))
    { ok: None, .. } =>
      next!(
        give_up,
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
) -> TestSuccess!TestError {
  let (n, tf, lf, ce) = local_min({ ..self, num_try_shrinks: 0 }, res, ts)
  match res.expect {
    Some(true) | None =>
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
    Some(false) =>
      Success(
        num_tests=self.num_success_tests + 1,
        num_discarded=self.num_discarded_tests,
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
            local_min(self, val, branch)
          }
          _ => {
            self.num_to_try_shrinks += 1
            self.num_try_shrinks += 1
            local_min(self, res, ts.drop(1))
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
