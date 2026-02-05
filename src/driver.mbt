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
    failing_classes~ : @sorted_set.SortedSet[String]
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
  max_shrink? : Int = 100,
  max_success? : Int = 100,
  max_size? : Int = 100,
  discard_ratio? : Int = 10,
  expect? : Expected = Success,
  abort? : Bool = false,
) -> Unit raise Failure {
  let prop = map_total_result(prop, res => { ..res, expect, abort })
  try {
    let result = quick_check_with_result(
      {
        replay: None,
        max_shrink,
        max_success,
        max_size,
        max_discard_ratio: discard_ratio,
      },
      prop,
    )
    match result {
      Success(output~, coverage~, num_tests~) => {
        println(output)
        println(coverage.to_string(num_tests))
      }
    }
  } catch {
    // TODO: Print coverage
    GaveUp(output~, ..) => fail(output)
    Fail(output~, failing_case~, ..) =>
      fail(output + "\n" + failing_case.join("\n"))
    NoneExpectedFail(output~, ..) => fail(output)
  }
}

///|
pub fn[P : Testable] quick_check_silence(
  prop : P,
  max_shrink? : Int = 100,
  max_success? : Int = 100,
  max_size? : Int = 100,
  discard_ratio? : Int = 10,
  expect? : Expected = Success,
  abort? : Bool = false,
) -> String {
  let prop = map_total_result(prop, res => { ..res, expect, abort })
  try {
    let result = quick_check_with_result(
      {
        replay: None,
        max_shrink,
        max_success,
        max_size,
        max_discard_ratio: discard_ratio,
      },
      prop,
    )
    match result {
      Success(output~, coverage~, num_tests~) =>
        return output + coverage.to_string(num_tests)
    }
  } catch {
    // TODO: Print coverage
    GaveUp(output~, ..) => output
    Fail(output~, failing_case~, ..) => output + "\n" + failing_case.join("\n")
    NoneExpectedFail(output~, ..) => output
  }
}

///|
pub fn[A : @coreqc.Arbitrary + Shrink + Show, B : Testable] quick_check_fn(
  f : (A) -> B,
  max_shrinks? : Int,
  max_success? : Int,
  max_size? : Int,
  discard_ratio? : Int,
  expect? : Expected = Success,
  abort? : Bool = false,
) -> Unit raise Failure {
  quick_check(
    Arrow(f),
    max_shrink?=max_shrinks,
    max_success?,
    max_size?,
    discard_ratio?,
    expect~,
    abort~,
  )
}

///|
pub fn[A : @coreqc.Arbitrary + Shrink + Show, B : Testable] quick_check_fn_silence(
  f : (A) -> B,
  max_shrinks? : Int,
  max_success? : Int,
  max_size? : Int,
  discard_ratio? : Int,
  expect? : Expected = Success,
  abort? : Bool = false,
) -> String {
  quick_check_silence(
    Arrow(f),
    max_shrink?=max_shrinks,
    max_success?,
    max_size?,
    discard_ratio?,
    expect~,
    abort~,
  )
}

///|
pub fn[A : @coreqc.Arbitrary + Shrink + Show, B : Testable] quick_check_fn_error(
  f : (A) -> B raise,
  max_shrinks? : Int,
  max_success? : Int,
  max_size? : Int,
  discard_ratio? : Int,
  expect? : Expected = Success,
  abort? : Bool = false,
) -> Unit raise Failure {
  quick_check(
    ArrowError(f),
    max_shrink?=max_shrinks,
    max_success?,
    max_size?,
    discard_ratio?,
    expect~,
    abort~,
  )
}

///|
pub fn[A : @coreqc.Arbitrary + Shrink + Show, B : Testable] quick_check_fn_error_silence(
  f : (A) -> B raise,
  max_shrinks? : Int,
  max_success? : Int,
  max_size? : Int,
  discard_ratio? : Int,
  expect? : Expected = Success,
  abort? : Bool = false,
) -> String {
  quick_check_silence(
    ArrowError(f),
    max_shrink?=max_shrinks,
    max_success?,
    max_size?,
    discard_ratio?,
    expect~,
    abort~,
  )
}

///|
pub fn[P : Testable] quick_check_with_result(
  cfg : Config,
  prop : P,
) -> TestSuccess raise TestError {
  from_config(cfg).run_test(prop.property())
}

///|
pub fn[A : @feat.Enumerable + Show, B : Testable] small_check(
  f : (A) -> B,
  max_size? : Int = 100,
  expect? : Expected = Success,
  abort? : Bool = false,
) -> Unit raise Failure {
  try {
    let result = small_check_with_result(f, max_size, expect, abort)
    match result {
      Success(output~, coverage~, num_tests~) => {
        println(output)
        println(coverage.to_string(num_tests))
      }
    }
  } catch {
    GaveUp(output~, ..) => fail(output)
    Fail(output~, failing_case~, ..) =>
      fail(output + "\n" + failing_case.join("\n"))
    NoneExpectedFail(output~, ..) => fail(output)
  }
}

///|
pub fn[A : @feat.Enumerable + Show, B : Testable] small_check_silence(
  f : (A) -> B,
  max_size? : Int = 100,
  expect? : Expected = Success,
  abort? : Bool = false,
) -> String {
  try {
    let result = small_check_with_result(f, max_size, expect, abort)
    match result {
      Success(output~, coverage~, num_tests~) =>
        return output + coverage.to_string(num_tests)
    }
  } catch {
    GaveUp(output~, ..) => output
    Fail(output~, failing_case~, ..) => output + "\n" + failing_case.join("\n")
    NoneExpectedFail(output~, ..) => output
  }
}

///|
pub fn[A : @feat.Enumerable + Show, B : Testable] small_check_error(
  f : (A) -> B raise,
  max_size? : Int = 100,
  expect? : Expected = Success,
  abort? : Bool = false,
) -> Unit raise Failure {
  small_check(fn(a : A) { try? f(a) }, max_size~, expect~, abort~)
}

///|
pub fn[A : @feat.Enumerable + Show, B : Testable] small_check_error_silence(
  f : (A) -> B raise,
  max_size? : Int = 100,
  expect? : Expected = Success,
  abort? : Bool = false,
) -> String {
  small_check_silence(fn(a : A) { try? f(a) }, max_size~, expect~, abort~)
}

///|
fn[A : @feat.Enumerable + Show, B : Testable] small_check_with_result(
  f : (A) -> B,
  max_size : Int,
  expect : Expected,
  abort : Bool,
) -> TestSuccess raise TestError {
  let limit = if max_size < 0 { 0 } else { max_size }
  let mut st = from_config({
    replay: None,
    max_shrink: 0,
    max_success: limit,
    max_size: limit,
    max_discard_ratio: 0,
  })
  st.expected = expect
  let dummy : Property = succeed().property()
  loop (A::enumerate().eval(), None, 0, limit, 0) {
    (_, _, _, remaining, _) if remaining <= 0 => break st.complete_test(dummy)
    (@lazy.Nil, _, _, _, _) => break st.complete_test(dummy)
    (parts, None, _, remaining, idx) =>
      match parts {
        @lazy.Nil => break st.complete_test(dummy)
        @lazy.Cons(finite, rest) =>
          if finite.fCard == 0 {
            continue (rest.force(), None, 0, remaining, idx)
          } else {
            continue (rest.force(), Some(finite), 0, remaining, idx)
          }
      }
    (parts, Some(finite), j, remaining, idx) =>
      if BigInt::compare_int(finite.fCard, j) <= 0 {
        continue (parts, None, 0, remaining, idx)
      } else {
        let val = (finite.fIndex)(BigInt::from_int(j))
        let prop = map_total_result(counterexample(f(val), val.to_string()), res => {
          ..res,
          expect,
          abort,
        })
        let rnd1 = st.random_state.split()
        let rnd2 = st.random_state
        let { val: res, .. } = prop.0.run(idx, rnd1)
        st.random_state = rnd2
        st.update_state_from_res(res)
        st.callback_post_test(res)
        match res.ok {
          Some(true) => {
            st.add_coverages(res)
            st = {
              ..st,
              num_success_tests: st.num_success_tests + 1,
              num_recent_discarded_tests: 0,
            }
            if res.abort {
              break st.complete_test(dummy)
            } else {
              continue (parts, Some(finite), j + 1, remaining - 1, idx + 1)
            }
          }
          Some(false) => break st.find_failure_no_shrink(res, idx)
          None => {
            st = {
              ..st,
              num_discarded_tests: st.num_discarded_tests + 1,
              num_recent_discarded_tests: st.num_recent_discarded_tests + 1,
            }
            if res.abort {
              break st.give_up(dummy)
            } else {
              continue (parts, Some(finite), j + 1, remaining - 1, idx + 1)
            }
          }
        }
      }
  }
}

///|
pub fn State::run_test(
  self : State,
  prop : Property,
) -> TestSuccess raise TestError {
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
pub fn State::complete_test(
  self : State,
  _prop : Property,
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
pub fn State::give_up(
  self : State,
  _prop : Property,
) -> TestSuccess raise TestError {
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

///|
/// Run a single test and return the Ok(result) if ended successfully, or Err(state) if it should continue.
pub fn State::run_single_test(
  self : State,
  prop : Property,
) -> Result[TestSuccess, State] raise TestError {
  let rnd1 = self.random_state.split()
  let rnd2 = self.random_state
  let { val: res, branch: ts } = prop.0.run(self.compute_size(), rnd1)
  fn update_state(st0 : State) {
    self.random_state = rnd2
    st0.update_state_from_res(res)
  }

  fn next(
    end_with : (State, Property) -> TestSuccess raise TestError,
    next_state : State,
    p : Property,
  ) -> Result[TestSuccess, State] raise TestError {
    update_state(next_state)
    if res.abort {
      Ok(end_with(next_state, p))
    } else {
      Err(next_state)
    }
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
pub fn State::find_failure(
  self : State,
  res : SingleResult,
  ts : Iter[Rose[SingleResult]],
) -> TestSuccess raise TestError {
  let (n, tf, lf, ce) = { ..self, num_try_shrinks: 0 }.local_min(res, ts)
  self.callback_post_final_failure(ce)
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
fn State::find_failure_no_shrink(
  self : State,
  res : SingleResult,
  size : Int,
) -> TestSuccess raise TestError {
  self.callback_post_final_failure(res)
  match res.expect {
    Success | GaveUp =>
      raise TestError::Fail(
        error=res.error,
        replay_info=Replay::new(self.random_state, size),
        num_tests=self.num_success_tests + 1,
        num_discarded=self.num_discarded_tests,
        num_shrinks=0,
        num_shrink_tries=0,
        num_shrink_final=0,
        reason=res.reason,
        output="*** \{self.counts()} Failed! \{res.reason}",
        failing_case=res.test_case.to_array(),
        failing_labels=res.labels.to_array(),
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
pub fn State::local_min(
  self : State,
  res : SingleResult,
  ts : Iter[Rose[SingleResult]],
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
  res : SingleResult,
) -> (Int, Int, Int, SingleResult) {
  // TODO: Print error
  (
    st.num_success_shrinks,
    st.num_to_try_shrinks - st.num_try_shrinks,
    st.num_try_shrinks,
    res,
  )
}
