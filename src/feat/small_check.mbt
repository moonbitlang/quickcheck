///|
pub using @property {trait Testable, type Expected}

///|
fn finish_report(
  report : @report.CheckReport,
  verbose : Bool,
) -> Unit raise Failure {
  let rendered = report.render(verbose~)
  if report.is_ok() {
    println(rendered)
  } else {
    fail(rendered)
  }
}

///|
fn[P : Testable] run_testable_once(
  prop : P,
  size : Int,
  state : @state.State,
  expect : Expected,
  abort : Bool,
) -> (@state.SingleResult, @state.State) {
  let prop = @property.with_run_options(prop, expect, abort)
  let rnd1 = state.random_state.split()
  let rnd2 = state.random_state
  let res = prop.run(size, rnd1)
  let next_state = state
  next_state.random_state = rnd2
  (res.val, next_state)
}

///|
/// Exhaustive-ish testing via Feat enumeration: walk values of `A` in
/// ascending size order, checking each one against `f`, up to at most
/// `max_size` total test cases.
pub fn[A : Enumerable + Debug, B : Testable] small_check(
  f : (A) -> B,
  max_size? : Int = 100,
  expect? : Expected = Success,
  abort? : Bool = false,
  verbose? : Bool = false,
) -> Unit raise Failure {
  let report = @report.CheckReport(
    try? small_check_with_result(f, max_size, expect, abort),
  )
  finish_report(report, verbose)
}

///|
/// `small_check` silent variant: returns the formatted outcome as a
/// `String`.
pub fn[A : Enumerable + Debug, B : Testable] small_check_silence(
  f : (A) -> B,
  max_size? : Int = 100,
  expect? : Expected = Success,
  abort? : Bool = false,
  verbose? : Bool = false,
) -> String {
  @report.CheckReport(try? small_check_with_result(f, max_size, expect, abort)).render(
    verbose~,
  )
}

///|
/// `small_check` variant that accepts a property that may `raise`. A
/// raised error is treated as a counter-example.
pub fn[A : Enumerable + Debug, B : Testable] small_check_error(
  f : (A) -> B raise,
  max_size? : Int = 100,
  expect? : Expected = Success,
  abort? : Bool = false,
  verbose? : Bool = false,
) -> Unit raise Failure {
  small_check(a => try? f(a), max_size~, expect~, abort~, verbose~)
}

///|
/// Silent variant of `small_check_error`: returns the formatted
/// outcome as a `String` instead of raising.
pub fn[A : Enumerable + Debug, B : Testable] small_check_error_silence(
  f : (A) -> B raise,
  max_size? : Int = 100,
  expect? : Expected = Success,
  abort? : Bool = false,
  verbose? : Bool = false,
) -> String {
  small_check_silence(a => try? f(a), max_size~, expect~, abort~, verbose~)
}

///|
fn[A : Debug, B : Testable] check_small_value(
  f : (A) -> B,
  val : A,
  idx : Int,
  st : @state.State,
  expect : Expected,
  abort : Bool,
) -> (@state.State, @report.TestSuccess?) raise @report.TestError {
  let (res, next_st) = run_testable_once(
    @property.property(f(val)).counterexample(@debug.to_string(val)),
    idx,
    st,
    expect,
    abort,
  )
  let mut st = next_st
  st.update_state_from_res(res)
  st.callback_post_test(res)
  match res.status {
    Passed => {
      st.add_coverages(res)
      st = {
        ..st,
        num_success_tests: st.num_success_tests + 1,
        num_recent_discarded_tests: 0,
      }
      if res.abort {
        (st, Some(st.small_complete_test()))
      } else {
        (st, None)
      }
    }
    Failed => (st, Some(st.small_find_failure_no_shrink(res)))
    Rejected => {
      st = {
        ..st,
        num_discarded_tests: st.num_discarded_tests + 1,
        num_recent_discarded_tests: st.num_recent_discarded_tests + 1,
      }
      if res.abort {
        (st, Some(st.small_give_up()))
      } else {
        (st, None)
      }
    }
  }
}

///|
fn[A : Enumerable + Debug, B : Testable] small_check_with_result(
  f : (A) -> B,
  max_size : Int,
  expect : Expected,
  abort : Bool,
) -> @report.TestSuccess raise @report.TestError {
  let limit = if max_size < 0 { 0 } else { max_size }
  let enumeration = A::enumerate()
  let mut st = @state.from_config({
    max_shrink: 0,
    max_success: limit,
    max_size: limit,
    max_discard_ratio: 0,
  })
  st.expected = expect
  for size = 0, remaining = limit, idx = 0 {
    if remaining <= 0 {
      break st.small_complete_test()
    } else {
      let seq = part(enumeration, size)
      let len = @ifseq.length(seq)
      if len == 0 {
        continue size + 1, remaining, idx
      } else if BigInt::compare_int(len, remaining) <= 0 {
        let values = @ifseq.to_array(seq)
        let mut next_st = st
        let mut next_remaining = remaining
        let mut next_idx = idx
        let mut done : @report.TestSuccess? = None
        for val in values {
          match done {
            Some(_) => break
            None =>
              if next_remaining <= 0 {
                break
              } else {
                let (checked_st, result) = check_small_value(
                  f, val, next_idx, next_st, expect, abort,
                )
                next_st = checked_st
                match result {
                  Some(success) => done = Some(success)
                  None => {
                    next_remaining = next_remaining - 1
                    next_idx = next_idx + 1
                  }
                }
              }
          }
        }
        st = next_st
        match done {
          Some(success) => break success
          None => continue size + 1, next_remaining, next_idx
        }
      } else {
        let mut next_st = st
        let mut next_remaining = remaining
        let mut next_idx = idx
        let mut done : @report.TestSuccess? = None
        for j in 0..<remaining {
          match done {
            Some(_) => break
            None => {
              let val = @ifseq.get(seq, BigInt::from_int(j))
              let (checked_st, result) = check_small_value(
                f, val, next_idx, next_st, expect, abort,
              )
              next_st = checked_st
              match result {
                Some(success) => done = Some(success)
                None => {
                  next_remaining = next_remaining - 1
                  next_idx = next_idx + 1
                }
              }
            }
          }
        }
        st = next_st
        match done {
          Some(success) => break success
          None => continue size, next_remaining, next_idx
        }
      }
    }
  }
}

///|
fn active_classes(
  classes : @list.List[(String, Bool)],
) -> @sorted_set.SortedSet[String] {
  [ for pair in classes if pair.1 => pair.0 ] |> @sorted_set.from_array
}

///|
fn @state.State::small_complete_test(
  self : @state.State,
) -> @report.TestSuccess raise @report.TestError {
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
fn @state.State::small_give_up(
  self : @state.State,
) -> @report.TestSuccess raise @report.TestError {
  if self.expected is GaveUp {
    Success(
      num_tests=self.num_success_tests,
      coverage=self.collects,
      output="+++ \{self.counts()} Ok, gave up!",
    )
  } else {
    raise GaveUp(
      num_tests=self.num_success_tests,
      num_discarded=self.num_discarded_tests,
      coverage=self.collects,
      output="*** \{self.counts()} Gave up! Passed only \{self.num_success_tests} tests.",
    )
  }
}

///|
fn @state.State::small_find_failure_no_shrink(
  self : @state.State,
  res : @state.SingleResult,
) -> @report.TestSuccess raise @report.TestError {
  self.callback_post_final_failure(res)
  match res.expect {
    Success | GaveUp =>
      raise Fail(
        error=res.error,
        num_tests=self.num_success_tests,
        num_discarded=self.num_discarded_tests,
        num_shrinks=0,
        num_shrink_tries=0,
        num_shrink_final=0,
        reason=res.reason,
        output="*** \{self.counts()} Failed! \{res.reason}",
        coverage=self.collects,
        failing_case=res.test_case.to_array(),
        failing_labels=res.labels.to_array(),
        failing_classes=active_classes(res.classes),
      )
    Fail =>
      Success(
        num_tests=self.num_success_tests,
        coverage=self.collects,
        output="+++ \{self.counts()} Ok! Failed as expected.",
      )
  }
}
