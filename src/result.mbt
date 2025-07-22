///|
pub(all) enum Outcome[T] {
  Success
  GaveUp
  Fail(T) // Counterexample
}

///|
pub(all) enum Expected {
  Fail
  Success
  GaveUp
}

///|
pub impl[T] Show for Outcome[T] with output(self, logger) {
  match self {
    Fail(_) => logger.write_string("FAIL")
    Success => logger.write_string("OK")
    GaveUp => logger.write_string("GAVE UP")
  }
}

///|
pub(all) struct Replay {
  rand_state : RandomState
  size : Int
}

///|
pub fn Replay::new(rand_state : RandomState, size : Int) -> Replay {
  { rand_state, size }
}

///|
struct SingleResult {
  ok : Bool?
  expect : Expected
  reason : String
  abort : Bool
  maybe_num_tests : Int?
  maybe_discarded_ratio : Int?
  maybe_max_shrinks : Int?
  maybe_max_test_size : Int?
  labels : List[String]
  classes : List[(String, Bool)]
  tables : List[(String, String)]
  test_case : List[String]
  error : Error
  callbacks : List[Callback]
}

///|
pub fn succeed() -> SingleResult {
  { ..Default::default(), ok: Some(true) }
}

///|
pub fn failed() -> SingleResult {
  { ..Default::default(), ok: Some(false) }
}

///|
pub fn rejected() -> SingleResult {
  { ..Default::default(), ok: None }
}

///|
impl Default for SingleResult with default() {
  {
    ok: None,
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
