// Package-private driver internals: the mutable test-runner state,
// its configuration, accumulated coverage, per-run result, and the
// callback types. Consolidated here because they are mutually
// recursive (State holds SingleResult-taking callbacks; SingleResult
// holds a list of Callback; Callback closes over State/SingleResult)
// and because none of them are user-facing.
//
// `Expected` is the one exception: it's part of the public driver
// API (`quick_check(..., expect=Fail)`) and lives here only so its
// `Expected` field on State doesn't re-introduce a cycle with the
// root package. The root re-exports it via `pub using`.

///|
/// Internal suberror used as a placeholder for `SingleResult.error`
/// before a real error is attached.
pub(all) suberror InternalError {
  InternalError(String)
}

///|
/// What the *author* of a property *expects* to happen. This is the
/// knob behind `quick_check_fn(..., expect=Fail)` and friends: if the
/// driver's actual verdict matches `Expected`, the check is
/// considered a pass even when the property raises.
///
/// Use cases:
///
/// - `Success` (the default) — property must hold on every generated
///   input.
/// - `Fail` — the property *should* fail; useful when you want to
///   demonstrate a known bug or lock in a regression check. The test
///   fails if the driver *can't* find a counterexample.
/// - `GaveUp` — the property is expected to discard too many cases.
///   Rarely useful in isolation; handy for testing the driver itself.
pub(all) enum Expected {
  Fail
  Success
  GaveUp
}

///|
/// Pass / fail / rejected for a single generated input.
pub(all) enum Status {
  Passed
  Failed
  Rejected
}

///|
/// Two flavours of callback the driver may invoke:
/// - `PostTest` fires after every generated input regardless of
///   outcome (used by `classify`, `label`, etc.).
/// - `PostFinalFailure` fires only after shrinking has settled on
///   its minimal counter-example (used by `counterexample`).
pub(all) enum Callback {
  PostTest(Kind, (State, SingleResult) -> Unit)
  PostFinalFailure(Kind, (State, SingleResult) -> Unit)
}

///|
pub(all) enum Kind {
  CounterExample
  Nothing
}

///|
/// Outcome of a single generated input before shrinking: the verdict
/// plus every piece of metadata the combinators may have attached
/// (labels, classifications, counter-example text, callbacks, …).
pub(all) struct SingleResult {
  status : Status
  expect : Expected
  reason : String
  abort : Bool
  maybe_num_tests : Int?
  maybe_discarded_ratio : Int?
  maybe_max_shrinks : Int?
  maybe_max_test_size : Int?
  labels : @list.List[String]
  classes : @list.List[(String, Bool)]
  tables : @list.List[(String, String)]
  test_case : @list.List[String]
  error : Error
  callbacks : @list.List[Callback]
}

///|
/// A `SingleResult` that reports the current input passed. Used by
/// combinators that wrap a `Bool` into a `Testable`.
pub fn succeed() -> SingleResult {
  { ..Default::default(), status: Passed }
}

///|
/// A `SingleResult` that reports the current input failed. The
/// `reason` / `test_case` / `labels` can be filled in by chaining
/// further combinators before handing it to the driver.
pub fn failed() -> SingleResult {
  { ..Default::default(), status: Failed }
}

///|
/// A `SingleResult` that represents a discarded input — the driver
/// should skip it and try another. Produced by `filter` when its
/// precondition fails.
pub fn rejected() -> SingleResult {
  { ..Default::default(), status: Rejected }
}

///|
impl Default for SingleResult with default() {
  {
    status: Rejected,
    expect: Success,
    reason: "unknown",
    abort: false,
    maybe_num_tests: None,
    maybe_discarded_ratio: None,
    maybe_max_shrinks: None,
    maybe_max_test_size: None,
    labels: @list.empty(),
    classes: @list.empty(),
    tables: @list.empty(),
    test_case: @list.empty(),
    error: InternalError("none"),
    callbacks: @list.empty(),
  }
}

///|
/// Internal configuration for initializing a test runner.
pub(all) struct Config {
  max_success : Int
  max_discard_ratio : Int
  max_size : Int
  max_shrink : Int
}

///|
/// Internal State of the driver.
pub(all) struct State {
  // Name of the test
  name : String
  // Top bound of test size (immutable, the argument of the Gen)
  mut max_test_size_ : Int
  // Maximum number of successful tests (immutable)
  mut max_success_tests_ : Int
  // Maximum ratio of discarded tests (immutable)
  // For instance if max_success_tests is 100 and max_discarded_ratio is 0.1
  // then the maximum number of discarded tests is 10
  mut max_discarded_ratio_ : Int
  // Maximum number of shrinks (immutable)
  mut max_shrinks_ : Int

  // Number of tests that have succeeded (mutable)
  num_success_tests : Int
  // Number of tests that have been discarded (mutable, total)
  num_discarded_tests : Int
  // Since last successful test, number of discarded tests (mutable)
  num_recent_discarded_tests : Int

  // Note that Map provides inner mutability hence we don't need to use mut tag.

  collects : Coverage
  // Expected result of the test
  mut expected : Expected
  // Current random state
  mut random_state : @gen.RandomState
  // Number of successful shrinks
  mut num_success_shrinks : Int
  // Number of shrinks tried since last successful shrink
  mut num_try_shrinks : Int
  // Number of shrinks failed (total)
  mut num_to_try_shrinks : Int
}

///|
pub fn from_config(cfg : Config) -> State {
  {
    name: @utils.fresh_name(),
    max_test_size_: cfg.max_size,
    max_success_tests_: cfg.max_success,
    max_discarded_ratio_: cfg.max_discard_ratio,
    max_shrinks_: cfg.max_shrink,
    num_success_tests: 0,
    num_discarded_tests: 0,
    num_recent_discarded_tests: 0,
    collects: Coverage::new(),
    expected: Success,
    random_state: @splitmix.new(),
    num_success_shrinks: 0,
    num_try_shrinks: 0,
    num_to_try_shrinks: 0,
  }
}

///|
pub fn State::clone(self : State) -> State {
  { ..self }
}

///|
pub fn State::compute_size(self : State) -> Int {
  match self {
    {
      max_success_tests_: mss,
      max_test_size_: mts,
      max_discarded_ratio_: mdr,
      num_success_tests: n,
      num_recent_discarded_tests: d,
      ..,
    } => {
      fn clamp(x, l, h) {
        @cmp.maximum(l, @cmp.minimum(x, h))
      }

      let dDenom = if mdr > 0 { clamp(mss * mdr / 3, 1, 10) } else { 1 }
      fn round_to(n, m) {
        n / m * m
      }

      if round_to(n, mts) + mts <= mss || n >= mss || mss % mts == 0 {
        @cmp.minimum(n % mts + d / dDenom, mts)
      } else {
        (n % mts * mts / (mss % mts) + d / dDenom) % mts
      }
    }
  }
}

///|
pub fn State::add_coverages(self : State, res : SingleResult) -> Unit {
  self.collects.label_incr(res.labels)
  self.collects.class_incr(res.classes)
}

///|
pub fn State::update_state_from_res(
  self : State,
  result : SingleResult,
) -> Unit {
  self.max_success_tests_ = result.maybe_num_tests.unwrap_or(
    self.max_success_tests_,
  )
  self.max_discarded_ratio_ = result.maybe_discarded_ratio.unwrap_or(
    self.max_discarded_ratio_,
  )
  self.max_test_size_ = result.maybe_max_test_size.unwrap_or(
    self.max_test_size_,
  )
  self.max_shrinks_ = result.maybe_max_shrinks.unwrap_or(self.max_shrinks_)
  self.expected = result.expect
}

///|
pub fn State::finished_successfully(self : State) -> Bool {
  self.num_success_tests >= self.max_success_tests_
}

///|
pub fn State::discarded_too_much(self : State) -> Bool {
  if self.max_discarded_ratio_ > 0 {
    self.num_discarded_tests / self.max_discarded_ratio_ >=
    @cmp.maximum(self.num_success_tests, self.max_success_tests_)
  } else {
    false
  }
}

///|
pub fn State::callback_post_test(self : State, res : SingleResult) -> Unit {
  res.callbacks.each(cb => {
    match cb {
      PostTest(_, f) => f(self, res)
      _ => ()
    }
  })
}

///|
pub fn State::callback_post_final_failure(
  self : State,
  res : SingleResult,
) -> Unit {
  res.callbacks.each(cb => {
    match cb {
      PostFinalFailure(_, f) => f(self, res)
      _ => ()
    }
  })
}

///|
pub fn State::counts(self : State) -> String {
  "[\{self.num_success_tests}/\{self.num_discarded_tests}/\{self.max_success_tests_}]"
}

///|
pub(all) struct ListCompare[T](@list.List[T]) derive(Eq)

///|
impl[T : Compare] Compare for ListCompare[T] with compare(self, other) {
  match (self.0, other.0) {
    (More(x, tail=xs), More(y, tail=ys)) => {
      let res = T::compare(x, y)
      if res == 0 {
        Compare::compare(ListCompare(xs), ListCompare(ys))
      } else {
        res
      }
    }
    (More(_), Empty) => 1
    (Empty, More(_)) => -1
    (Empty, Empty) => 0
  }
}

// Labels / Classes / Tables are used to collect statistics of the test
// TODO : Maybe a more general way to collect infos (use typeclass?)

///|
pub(all) struct Coverage {
  // Note that List[String] is not hashable, so we use ListCompare[String]
  // and sorted_map instead
  labels : @sorted_map.SortedMap[ListCompare[String], Int]
  classes : @sorted_map.SortedMap[String, Int]
}

///|
pub fn Coverage::new() -> Coverage {
  { labels: @sorted_map.new(), classes: @sorted_map.new() }
}

///|
pub fn Coverage::label_incr(self : Coverage, key : @list.List[String]) -> Unit {
  match self.labels.get(key) {
    Some(x) => self.labels[key] = x + 1
    None => self.labels[key] = 1
  }
}

///|
pub fn Coverage::class_incr(
  self : Coverage,
  classes : @list.List[(String, Bool)],
) -> Unit {
  classes.each(item => {
    let (s, b) = item
    let i = if b { 1 } else { 0 }
    match self.classes.get(s) {
      Some(x) => self.classes[s] = x + i
      None => self.classes[s] = i
    }
  })
}

///|
fn format_percent(count : Int, total : Int) -> String {
  guard total > 0 else { "0%" }
  let scaled = count * 10000
  let whole = scaled / total / 100
  let frac = scaled / total % 100
  if frac == 0 {
    "\{whole}%"
  } else if frac % 10 == 0 {
    "\{whole}.\{frac / 10}%"
  } else if frac < 10 {
    "\{whole}.0\{frac}%"
  } else {
    "\{whole}.\{frac}%"
  }
}

///|
pub fn Coverage::label_to_string(self : Coverage, success : Int) -> String {
  let res = []
  self.labels.each((list, i) => {
    if list.0.is_empty() {
      return
    } else {
      let l = list.0.to_array().join(", ")
      res.push("\{format_percent(i, success)} : \{l}")
    }
  })
  res.join("\n")
}

///|
pub fn Coverage::class_to_string(self : Coverage, success : Int) -> String {
  let res = []
  self.classes.each(fn(s, i) {
    res.push("\{format_percent(i, success)} : \{s}")
  })
  res.join("\n")
}

///|
pub fn Coverage::to_string(self : Coverage, success : Int) -> String {
  let res = [
      if self.labels.length() == 0 {
        ""
      } else {
        self.label_to_string(success)
      },
      if self.classes.length() == 0 {
        ""
      } else {
        self.class_to_string(success)
      },
    ]
    .filter(x => x != "")
    .join("\n")
  res
}
