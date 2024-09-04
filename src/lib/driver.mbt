/// Configuration for initializing a test runner.
struct Args {
  replay : (RandomState, Int)?
  max_success : Int
  max_discard_ratio : Int
  max_size : Int
  max_shrink : Int
}

impl Default for Args with default() {
  {
    replay: None,
    max_success: 100,
    max_discard_ratio: 10,
    max_size: 100,
    max_shrink: 100,
  }
}

type! TestError {
  Fail(
    ~num_tests : Int,
    ~num_discarded : Int,
    ~num_shrinks : Int,
    ~num_shrink_tries : Int,
    ~num_shrink_final : Int,
    ~replay_info : Replay,
    ~reason : String,
    ~error : Error,
    ~output : String,
    ~failing_case : Array[String],
    ~failing_labels : Array[String],
    ~failing_classes : @sorted_set.T[String]
  )
  GaveUp(
    ~num_tests : Int,
    ~num_discarded : Int,
    ~coverage : Coverage,
    ~output : String
  )
  NoneExpectedFail(
    ~num_tests : Int,
    ~num_discarded : Int,
    ~coverage : Coverage,
    ~output : String
  )
}

enum TestSuccess {
  Success(
    ~num_tests : Int,
    ~num_discarded : Int,
    ~coverage : Coverage,
    ~output : String
  )
}

pub fn quick_check[P : Testable](prop : P) -> Unit!Failure {
  quick_check_with!(Default::default(), prop)
}

pub fn quick_check_fn[A : Arbitrary + Shrink + Show, B : Testable](
  f : (A) -> B
) -> Unit!Failure {
  quick_check!(Arrow(f))
}

pub fn quick_check_with[P : Testable](cfg : Args, prop : P) -> Unit!Failure {
  fn f(s : String) -> _!Failure {
    fail!("\n\{s}")
  }

  try {
    match quick_check_with_result!(cfg, prop) {
      Success(~output, ..) => println(output)
    }
  } catch {
    // TODO: Print coverage
    GaveUp(~output, ..) => f!(output)
    Fail(~output, ~failing_case, ..) =>
      f!(output + "\n" + failing_case.join("\n"))
    NoneExpectedFail(~output, ..) => f!(output)
  }
}

pub fn quick_check_with_result[P : Testable](
  cfg : Args,
  prop : P
) -> TestSuccess!TestError {
  run_test!(from_config(cfg), prop.property())
}

pub fn run_test(self : State, prop : Property) -> TestSuccess!TestError {
  if self.finished_successfully() {
    self.complete_test!(prop)
  } else if self.discarded_too_much() {
    self.give_up!(prop)
  } else {
    self.run_single_test!(prop)
  }
}

pub fn complete_test(self : State, _prop : Property) -> TestSuccess!TestError {
  if self.expected.not() {
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

pub fn give_up(self : State, _prop : Property) -> TestSuccess!TestError {
  raise TestError::GaveUp(
    num_tests=self.num_success_tests,
    num_discarded=self.num_discarded_tests,
    coverage=self.collects,
    output="*** \{self.counts()} Gave up! Passed only \{self.num_success_tests} tests.",
  )
}

pub fn run_single_test(self : State, prop : Property) -> TestSuccess!TestError {
  let rnd1 = self.random_state.split()
  let rnd2 = self.random_state
  let size = self.compute_size()
  let { val: res, branch: ts } = prop.property.run(size, rnd1)
  fn next(
    end_with : (State, Property) -> TestSuccess!TestError,
    nst : State,
    p : Property
  ) -> _!TestError {
    update_state(nst)
    if res.abort {
      end_with!(nst, p)
    } else {
      run_test!(nst, p)
    }
  }

  fn update_state(st0) {
    self.random_state = rnd2
    update_state_from_res(st0, res)
  }

  fn add_coverages(st0 : State) -> Unit {
    match st0.collects.labels[res.labels] {
      Some(v) => st0.collects.labels[res.labels] = v + 1
      None => st0.collects.labels[res.labels] = 1
    }
  }

  let stc = self.clone()
  add_coverages(stc)
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
    { ok: Some(false), .. } => self.find_failure!(res, ts)
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

pub fn find_failure(
  self : State,
  res : SingleResult,
  ts : Iter[Rose[SingleResult]]
) -> TestSuccess!TestError {
  let (n, tf, lf, ce) = local_min({ ..self, num_try_shrinks: 0 }, res, ts)
  match res.expect {
    true =>
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
    false =>
      Success(
        num_tests=self.num_success_tests + 1,
        num_discarded=self.num_discarded_tests,
        coverage=self.collects,
        output="+++ \{self.counts()} Success! Failed as expected.",
      )
  }
}

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

test "quick check" {
  let prop_rev = fn(l : List[Int]) { l.rev().rev() == l.rev() }
  quick_check_fn!(prop_rev)
}

test "success" {
  let prop_rev = fn(l : List[Int]) { l.rev().rev() == l }
  quick_check_fn!(prop_rev)
}
