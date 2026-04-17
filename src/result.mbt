// `Expected` and `Replay` are declared in `types.mbt`.
// Constructor helpers and internal result modeling live here.

///|
/// Capture the current RNG state and size parameter as a `Replay` so
/// that a failing test can be rerun deterministically. Typically used
/// inside the driver — the `Replay` record also surfaces in the
/// counter-example reported by a failing check.
pub fn Replay::new(rand_state : @gen.RandomState, size : Int) -> Replay {
  { rand_state, size }
}

///|
priv enum Status {
  Passed
  Failed
  Rejected
}

///|
priv struct SingleResult {
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
fn succeed() -> SingleResult {
  { ..Default::default(), status: Passed }
}

///|
/// A `SingleResult` that reports the current input failed. The
/// `reason` / `test_case` / `labels` can be filled in by chaining
/// further combinators before handing it to the driver.
fn failed() -> SingleResult {
  { ..Default::default(), status: Failed }
}

///|
/// A `SingleResult` that represents a discarded input — the driver
/// should skip it and try another. Produced by `filter` when its
/// precondition fails.
fn rejected() -> SingleResult {
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
