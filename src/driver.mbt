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
/// Run a `Testable` property against randomly-generated inputs and
/// print the outcome. The driver runs up to `max_success` successful
/// tests, trying increasingly large inputs up to `max_size`, and
/// discarding no more than `max_success × discard_ratio` inputs
/// before giving up. On failure it shrinks for up to `max_shrink`
/// steps before reporting.
///
/// `expect` asserts the expected outcome (`Success` by default); the
/// driver flips the verdict accordingly (a failing property with
/// `expect=Fail` is a pass). `abort=true` short-circuits the outer
/// loop after the first test result is processed — note that a
/// failing result still goes through the full shrink search before
/// returning.
///
/// Raises `Failure` on mismatch with `expect` — so it's the
/// drop-in entry point inside `test "…"` blocks.
pub fn[P : Testable] quick_check(
  prop : P,
  max_shrink? : Int = 100,
  max_success? : Int = 100,
  max_size? : Int = 100,
  discard_ratio? : Int = 10,
  expect? : Expected = Success,
  abort? : Bool = false,
  verbose? : Bool = false,
) -> Unit raise Failure {
  let prop = map_total_result(prop, res => { ..res, expect, abort })
  let report = @report.CheckReport(
    try? quick_check_with_result(
      { max_shrink, max_success, max_size, max_discard_ratio: discard_ratio },
      prop,
    ),
  )
  finish_report(report, verbose)
}

///|
/// Like `quick_check` but returns the formatted outcome as a `String`
/// instead of printing it or raising. Useful in tests that want to
/// pin the driver's output with `inspect(..., content=...)`.
pub fn[P : Testable] quick_check_silence(
  prop : P,
  max_shrink? : Int = 100,
  max_success? : Int = 100,
  max_size? : Int = 100,
  discard_ratio? : Int = 10,
  expect? : Expected = Success,
  abort? : Bool = false,
  verbose? : Bool = false,
) -> String {
  let prop = map_total_result(prop, res => { ..res, expect, abort })
  let report = @report.CheckReport(
    try? quick_check_with_result(
      { max_shrink, max_success, max_size, max_discard_ratio: discard_ratio },
      prop,
    ),
  )
  report.render(verbose~)
}

///|
/// Thin sugar over `quick_check`: accept a plain `(A) -> B` property
/// function, wrap it in `Arrow`, and run. The shortest path from a
/// user-written property to a full QuickCheck run.
pub fn[A : @coreqc.Arbitrary + Shrink + Show, B : Testable] quick_check_fn(
  f : (A) -> B,
  max_shrinks? : Int,
  max_success? : Int,
  max_size? : Int,
  discard_ratio? : Int,
  expect? : Expected = Success,
  abort? : Bool = false,
  verbose? : Bool = false,
) -> Unit raise Failure {
  quick_check(
    Arrow(f),
    max_shrink?=max_shrinks,
    max_success?,
    max_size?,
    discard_ratio?,
    expect~,
    abort~,
    verbose~,
  )
}

///|
/// `quick_check_fn` variant that returns the formatted outcome as a
/// `String` instead of raising / printing.
pub fn[A : @coreqc.Arbitrary + Shrink + Show, B : Testable] quick_check_fn_silence(
  f : (A) -> B,
  max_shrinks? : Int,
  max_success? : Int,
  max_size? : Int,
  discard_ratio? : Int,
  expect? : Expected = Success,
  abort? : Bool = false,
  verbose? : Bool = false,
) -> String {
  quick_check_silence(
    Arrow(f),
    max_shrink?=max_shrinks,
    max_success?,
    max_size?,
    discard_ratio?,
    expect~,
    abort~,
    verbose~,
  )
}

///|
/// `quick_check_fn` for properties that may `raise`. A raised error
/// is treated as a counter-example with the error captured as the
/// reason.
pub fn[A : @coreqc.Arbitrary + Shrink + Show, B : Testable] quick_check_fn_error(
  f : (A) -> B raise,
  max_shrinks? : Int,
  max_success? : Int,
  max_size? : Int,
  discard_ratio? : Int,
  expect? : Expected = Success,
  abort? : Bool = false,
  verbose? : Bool = false,
) -> Unit raise Failure {
  quick_check(
    ArrowError(f),
    max_shrink?=max_shrinks,
    max_success?,
    max_size?,
    discard_ratio?,
    expect~,
    abort~,
    verbose~,
  )
}

///|
/// `quick_check_fn_error` silent variant that returns the formatted
/// outcome as a `String`.
pub fn[A : @coreqc.Arbitrary + Shrink + Show, B : Testable] quick_check_fn_error_silence(
  f : (A) -> B raise,
  max_shrinks? : Int,
  max_success? : Int,
  max_size? : Int,
  discard_ratio? : Int,
  expect? : Expected = Success,
  abort? : Bool = false,
  verbose? : Bool = false,
) -> String {
  quick_check_silence(
    ArrowError(f),
    max_shrink?=max_shrinks,
    max_success?,
    max_size?,
    discard_ratio?,
    expect~,
    abort~,
    verbose~,
  )
}

///|
/// Internal helper: run a property with a fully-specified `Config`
/// and return the structured `TestSuccess` / raise `TestError`.
fn[P : Testable] quick_check_with_result(
  cfg : @state.Config,
  prop : P,
) -> @report.TestSuccess raise @report.TestError {
  @state.from_config(cfg).run_test(prop.property())
}

///|
/// Exhaustive-ish testing via the `feat` enumeration: walk values of
/// `A` in ascending size order, checking each one against `f`, up to
/// **at most `max_size` total test cases** (not all values of size
/// `≤ max_size` — that would usually be combinatorially huge). So
/// `small_check` is "enumerate prefix by size, check the first
/// `max_size` values"; pick `max_size` large enough to cover the
/// interesting sizes for your type.
///
/// Complements `quick_check`: use `small_check` when you want
/// deterministic, size-indexed coverage rather than random sampling.
pub fn[A : @feat.Enumerable + Show, B : Testable] small_check(
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
pub fn[A : @feat.Enumerable + Show, B : Testable] small_check_silence(
  f : (A) -> B,
  max_size? : Int = 100,
  expect? : Expected = Success,
  abort? : Bool = false,
  verbose? : Bool = false,
) -> String {
  let report = @report.CheckReport(
    try? small_check_with_result(f, max_size, expect, abort),
  )
  report.render(verbose~)
}

///|
/// `small_check` variant that accepts a property that may `raise`. A
/// raised error is treated as a counter-example.
pub fn[A : @feat.Enumerable + Show, B : Testable] small_check_error(
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
pub fn[A : @feat.Enumerable + Show, B : Testable] small_check_error_silence(
  f : (A) -> B raise,
  max_size? : Int = 100,
  expect? : Expected = Success,
  abort? : Bool = false,
  verbose? : Bool = false,
) -> String {
  small_check_silence(a => try? f(a), max_size~, expect~, abort~, verbose~)
}

///|
fn[A : @feat.Enumerable + Show, B : Testable] small_check_with_result(
  f : (A) -> B,
  max_size : Int,
  expect : Expected,
  abort : Bool,
) -> @report.TestSuccess raise @report.TestError {
  let limit = if max_size < 0 { 0 } else { max_size }
  let mut st = @state.from_config({
    max_shrink: 0,
    max_success: limit,
    max_size: limit,
    max_discard_ratio: 0,
  })
  st.expected = expect
  let dummy : Property = Testable::property(@state.succeed())
  for parts = A::enumerate().eval(), finite_opt = None, j = 0, remaining = limit, idx = 0 {
    if remaining <= 0 {
      break st.complete_test(dummy)
    }
    match (parts, finite_opt) {
      (Nil, _) => break st.complete_test(dummy)
      (Cons(finite, rest), None) =>
        if finite.fCard == 0 {
          continue rest.force(), None, 0, remaining, idx
        } else {
          continue rest.force(), Some(finite), 0, remaining, idx
        }
      (_, Some(finite)) =>
        if BigInt::compare_int(finite.fCard, j) <= 0 {
          continue parts, None, 0, remaining, idx
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
          match res.status {
            Passed => {
              st.add_coverages(res)
              st = {
                ..st,
                num_success_tests: st.num_success_tests + 1,
                num_recent_discarded_tests: 0,
              }
              if res.abort {
                break st.complete_test(dummy)
              } else {
                continue parts, Some(finite), j + 1, remaining - 1, idx + 1
              }
            }
            Failed => break st.find_failure_no_shrink(res)
            Rejected => {
              st = {
                ..st,
                num_discarded_tests: st.num_discarded_tests + 1,
                num_recent_discarded_tests: st.num_recent_discarded_tests + 1,
              }
              if res.abort {
                break st.give_up(dummy)
              } else {
                continue parts, Some(finite), j + 1, remaining - 1, idx + 1
              }
            }
          }
        }
    }
  }
}

///|
fn active_classes(
  classes : @list.List[(String, Bool)],
) -> @sorted_set.SortedSet[String] {
  let acc : Array[String] = []
  classes.each(fn(pair) {
    let (name, active) = pair
    if active {
      acc.push(name)
    }
  })
  @sorted_set.from_iter(acc.iter())
}

///|
/// Run the main QuickCheck loop: draw inputs, evaluate the property,
/// book-keep successes and discards, and on failure hand off to
/// `find_failure` for shrinking. Returns the aggregated
/// `TestSuccess` or raises `TestError`.
fn @state.State::run_test(
  self : @state.State,
  prop : Property,
) -> @report.TestSuccess raise @report.TestError {
  for cur = self.run_single_test(prop) {
    match cur {
      Ok(res) => break res
      Err(ns) =>
        if ns.finished_successfully() {
          break ns.complete_test(prop)
        } else if ns.discarded_too_much() {
          break ns.give_up(prop)
        } else {
          continue ns.run_single_test(prop)
        }
    }
  }
}

///|
/// Wrap up a finished test run — produce the formatted success
/// report when the expected outcome matches, or raise the
/// appropriate `TestError` when it does not (e.g. the property was
/// supposed to fail but no counter-example appeared).
fn @state.State::complete_test(
  self : @state.State,
  _prop : Property,
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
/// Abandon the run when too many inputs have been discarded (the
/// `max_success × discard_ratio` budget is exhausted). Produces the
/// `GaveUp` outcome with the current coverage snapshot.
fn @state.State::give_up(
  self : @state.State,
  _prop : Property,
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
/// Run a single test and return the Ok(result) if ended successfully, or Err(state) if it should continue.
fn @state.State::run_single_test(
  self : @state.State,
  prop : Property,
) -> Result[@report.TestSuccess, @state.State] raise @report.TestError {
  let rnd1 = self.random_state.split()
  let rnd2 = self.random_state
  let { val: res, branch: ts } = prop.0.run(self.compute_size(), rnd1)
  fn update_state(st0 : @state.State) {
    self.random_state = rnd2
    st0.update_state_from_res(res)
  }

  fn next(
    end_with : (@state.State, Property) -> @report.TestSuccess raise @report.TestError,
    next_state : @state.State,
    p : Property,
  ) -> Result[@report.TestSuccess, @state.State] raise @report.TestError {
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
    { status: Passed, .. } =>
      next(
        @state.State::complete_test,
        {
          ..stc,
          num_success_tests: self.num_success_tests + 1,
          num_recent_discarded_tests: 0,
        },
        prop,
      )
    { status: Failed, .. } => Ok(self.find_failure(res, ts))
    { status: Rejected, .. } =>
      next(
        @state.State::give_up,
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
/// Enter the shrink loop on a counter-example: starting from `res`
/// and the iter of alternative `Rose` sub-trees, walk the shrinkers
/// to find a minimal failing case, then raise the appropriate
/// `TestError` (or `TestSuccess` if the failure was expected).
fn @state.State::find_failure(
  self : @state.State,
  res : @state.SingleResult,
  ts : Iter[@rose.Rose[@state.SingleResult]],
) -> @report.TestSuccess raise @report.TestError {
  let (n, tf, lf, ce) = { ..self, num_try_shrinks: 0 }.local_min(res, ts)
  self.callback_post_final_failure(ce)
  match res.expect {
    Success | GaveUp =>
      raise Fail(
        error=res.error,
        num_tests=self.num_success_tests,
        num_discarded=self.num_discarded_tests,
        num_shrinks=n,
        num_shrink_tries=tf,
        num_shrink_final=lf,
        reason=res.reason,
        output="*** \{self.counts()} Failed! \{res.reason}",
        coverage=self.collects,
        failing_case=ce.test_case.to_array(),
        failing_labels=ce.labels.to_array(),
        failing_classes=active_classes(ce.classes),
      )
    Fail =>
      Success(
        num_tests=self.num_success_tests,
        coverage=self.collects,
        output="+++ \{self.counts()} Ok! Failed as expected.",
      )
  }
}

///|
fn @state.State::find_failure_no_shrink(
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

///|
/// The inner shrink-search loop: given a failing `SingleResult` and a
/// candidate `Rose` branch to explore, walk downward as long as we
/// keep finding smaller failures, bailing out after
/// `self.max_shrinks_` total attempts. Returns the full tally
/// `(successful shrinks, tries without success, last-stage tries,
/// final result)` that the driver reports in the `Fail` outcome.
fn @state.State::local_min(
  self : @state.State,
  res : @state.SingleResult,
  ts : Iter[@rose.Rose[@state.SingleResult]],
) -> (Int, Int, Int, @state.SingleResult) {
  if self.num_success_shrinks + self.num_to_try_shrinks >= self.max_shrinks_ {
    local_min_found(self, res)
  } else {
    let t = ts.head()
    match t {
      Some({ val, branch }) => {
        self.callback_post_test(val)
        match val.status {
          Failed => {
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
/// Finalise the shrink tally when the search terminates (either
/// because the shrink budget is exhausted or no smaller failure was
/// found). Returns the counts the driver reports in the `Fail`
/// outcome.
fn local_min_found(
  st : @state.State,
  res : @state.SingleResult,
) -> (Int, Int, Int, @state.SingleResult) {
  // TODO: Print error
  (
    st.num_success_shrinks,
    st.num_to_try_shrinks - st.num_try_shrinks,
    st.num_try_shrinks,
    res,
  )
}
