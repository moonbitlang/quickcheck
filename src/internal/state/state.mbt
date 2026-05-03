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
/// Placeholder value for `SingleResult.error`. The field is typed as
/// the abstract `Error`, so any suberror works; this one is used only
/// to initialise a fresh `SingleResult` before the real error (if any)
/// is filled in.
priv suberror InternalError {
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
/// Which lifecycle stage a `Callback` wants to fire at. Used by the
/// driver to decide whether a callback's role is to decorate the
/// counter-example (`CounterExample`) or to stay quiet
/// (`Nothing`) — the dispatch happens inside
/// `State::callback_post_test` / `State::callback_post_final_failure`.
pub(all) enum Kind {
  CounterExample
  Nothing
}

///|
/// Everything the driver learns about a single generated input. The
/// leaf payload of the `@rose.Rose[SingleResult]` tree that every
/// `Testable` collapses to — so each node in the shrink tree
/// (the original sample plus every candidate tried during shrinking)
/// carries one of these.
///
/// Fields split into three groups:
///
/// - The verdict: `status` (pass / fail / reject), `expect` (what
///   the author predicted), `reason` (free-text explanation shown on
///   failure), `abort` (stop the outer loop after this sample?),
///   `error` (the raised exception when `status = Failed`).
/// - Driver-option overrides: the `maybe_*` fields let a combinator
///   reconfigure the run from *inside* the property (e.g.
///   `with_max_success(50)`); `State::update_state_from_res`
///   copies any `Some` back onto `State`.
/// - Metadata attached by combinators: `labels` / `classes` /
///   `tables` feed the coverage report, `test_case` collects
///   counter-example lines, and `callbacks` carries the `PostTest`
///   / `PostFinalFailure` hooks to run later.
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
/// Immutable driver configuration: the four caps a caller passes via
/// `quick_check(max_success=..., max_size=..., discard_ratio=...,
/// max_shrink=...)`. Consumed by `from_config` to seed an initial
/// `State`; never mutated afterwards.
///
/// - `max_success`: target number of passing inputs before the run
///   reports success.
/// - `max_discard_ratio`: how many discards per success we tolerate
///   before giving up (`discarded > max_discard_ratio * success`).
/// - `max_size`: upper bound on the `size` argument handed to the
///   generator; larger values ask for bigger inputs.
/// - `max_shrink`: cap on the total shrink attempts after a failure.
pub(all) struct Config {
  max_success : Int
  max_discard_ratio : Int
  max_size : Int
  max_shrink : Int
}

///|
/// Mutable driver state kept across the main test loop and the shrink
/// search. A fresh `State` is built once via `from_config` and then
/// threaded through every step: `run_test` reads the caps, increments
/// the success / discard counters, and updates `random_state` between
/// draws; `find_failure` / `local_min` bump the shrink counters as
/// they descend the rose tree.
///
/// Field groups:
///
/// - `name` — a fresh identifier for the run (for diagnostics).
/// - `max_*_` — immutable caps copied from `Config`.
/// - `num_success_tests` / `num_discarded_tests` /
///   `num_recent_discarded_tests` — progress counters the driver
///   updates after each sample.
/// - `collects` — the running `Coverage` tally (labels + classes)
///   accumulated by `add_coverages`.
/// - `expected` — the author-supplied expected outcome; the driver
///   flips the verdict against this at the end of the run.
/// - `random_state` — mutable PRNG the driver splits off for each
///   generated sample.
/// - `num_success_shrinks` / `num_try_shrinks` / `num_to_try_shrinks`
///   — shrink-loop counters reported in the final `Fail` payload.
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
/// Build a fresh `State` from the caller-supplied caps. All counters
/// start at zero, `expected` defaults to `Success`, and the PRNG is
/// seeded from `@splitmix.new()`.
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
/// Shallow-copy the `State`. Used by the driver to fork a snapshot
/// before a step that may need to be rolled back on discard /
/// failure.
pub fn State::clone(self : State) -> State {
  { ..self }
}

///|
/// Pick the `size` argument to hand to the generator on the next
/// draw. Grows with the number of successful tests so far (so later
/// inputs are larger) while staying bounded by `max_test_size_`, and
/// nudges up for every recently-discarded case so discards don't
/// stall at a trivial size.
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
      let dDenom = if mdr > 0 {
        (mss * mdr / 3).clamp(min=1, max=10)
      } else {
        1
      }
      fn round_to(n, m) {
        n / m * m
      }

      if round_to(n, mts) + mts <= mss || n >= mss || mss % mts == 0 {
        (n % mts + d / dDenom).min(mts)
      } else {
        (n % mts * mts / (mss % mts) + d / dDenom) % mts
      }
    }
  }
}

///|
/// Fold the labels / classes carried by `res` into the running
/// `Coverage` tally. Called after each passing test so the final
/// report can print label-and-class percentages.
pub fn State::add_coverages(self : State, res : SingleResult) -> Unit {
  self.collects.label_incr(res.labels)
  self.collects.class_incr(res.classes)
}

///|
/// Propagate any `maybe_*` overrides that combinators (e.g.
/// `with_max_tests`) attached to `result` back onto `State`, and
/// sync `expected` with whatever the property annotated itself with.
/// Called once per sample before the verdict is inspected.
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
/// `true` once the run has gathered enough passing samples to stop.
pub fn State::finished_successfully(self : State) -> Bool {
  self.num_success_tests >= self.max_success_tests_
}

///|
/// `true` once the discard budget
/// (`num_discarded / max_discarded_ratio_`) has overrun the current
/// success count — the driver then bails out with `GaveUp`.
pub fn State::discarded_too_much(self : State) -> Bool {
  if self.max_discarded_ratio_ > 0 {
    self.num_discarded_tests / self.max_discarded_ratio_ >=
    self.num_success_tests.max(self.max_success_tests_)
  } else {
    false
  }
}

///|
/// Fire every `PostTest` callback attached to `res`. Called once per
/// generated sample (success, failure, or discard), before the driver
/// decides what to do next.
pub fn State::callback_post_test(self : State, res : SingleResult) -> Unit {
  for cb in res.callbacks {
    match cb {
      PostTest(_, f) => f(self, res)
      _ => ()
    }
  }
}

///|
/// Fire every `PostFinalFailure` callback attached to `res`. Called
/// exactly once at the end of the shrink search, so combinators like
/// `counterexample` can pull in extra context only for the minimal
/// failing input.
pub fn State::callback_post_final_failure(
  self : State,
  res : SingleResult,
) -> Unit {
  for cb in res.callbacks {
    match cb {
      PostFinalFailure(_, f) => f(self, res)
      _ => ()
    }
  }
}

///|
/// Render the `[ok/discarded/total]` triple that prefixes every
/// report line.
pub fn State::counts(self : State) -> String {
  "[\{self.num_success_tests}/\{self.num_discarded_tests}/\{self.max_success_tests_}]"
}

///|
// TODO : Maybe a more general way to collect infos (use typeclass?)

///|
/// Running tallies of `label(...)` and `classify(...)` hits, built
/// up across the run and handed to the reporter at the end. The only
/// externally-visible operation is `Coverage::to_string`, which
/// renders the tallies as the percentage lines appended to the
/// success / failure report; construction and update happen inside
/// this package.
pub struct Coverage {
  labels : @sorted_map.SortedMap[@list.List[String], Int]
  classes : @sorted_map.SortedMap[String, Int]
}

///|
/// Fresh, empty `Coverage` — seeded into `State.collects` by
/// `from_config`.
fn Coverage::new() -> Coverage {
  { labels: @sorted_map.new(), classes: @sorted_map.new() }
}

///|
/// Record one occurrence of the given label stack (as
/// attached by `label(...)`).
fn Coverage::label_incr(self : Coverage, key : @list.List[String]) -> Unit {
  match self.labels.get(key) {
    Some(x) => self.labels[key] = x + 1
    None => self.labels[key] = 1
  }
}

///|
/// Bump the per-class counters from one `classify(...)` hit. `true`
/// increments the count; `false` still registers the class so it
/// shows up in the report with 0%.
fn Coverage::class_incr(
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
fn Coverage::label_to_string(self : Coverage, success : Int) -> String {
  let res = []
  self.labels.each((list, i) => {
    if list.is_empty() {
      return
    } else {
      let l = list.to_array().join(", ")
      res.push("\{format_percent(i, success)} : \{l}")
    }
  })
  res.join("\n")
}

///|
fn Coverage::class_to_string(self : Coverage, success : Int) -> String {
  let res = []
  self.classes.each(fn(s, i) {
    res.push("\{format_percent(i, success)} : \{s}")
  })
  res.join("\n")
}

///|
/// Render the labels + classes tally as percentage lines for the
/// report (normalised against `success`, the number of passing
/// samples). Called by `CheckReport::render` in the root package.
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
