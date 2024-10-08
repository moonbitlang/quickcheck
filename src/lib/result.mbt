pub enum Outcome[T] {
  Success
  GaveUp
  Fail(T) // Counterexample
}

pub fn to_string[T](self : Outcome[T]) -> String {
  match self {
    Fail(_) => "FAIL"
    Success => "OK"
    GaveUp => "GAVE UP"
  }
}

pub fn output[T](self : Outcome[T], logger : Logger) -> Unit {
  logger.write_string(self.to_string())
}

pub struct Replay {
  rand_state : RandomState
  size : Int
}

pub fn Replay::new(rand_state : RandomState, size : Int) -> Replay {
  { rand_state, size }
}

struct SingleResult {
  ok : Bool?
  expect : Bool
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
} derive(Show)

pub fn succeed() -> SingleResult {
  { ..Default::default(), ok: Some(true) }
}

pub fn failed() -> SingleResult {
  { ..Default::default(), ok: Some(false) }
}

pub fn rejected() -> SingleResult {
  { ..Default::default(), ok: None }
}

impl Default for SingleResult with default() {
  {
    ok: None,
    expect: true,
    reason: "unknown",
    abort: false,
    maybe_num_tests: None,
    maybe_discarded_ratio: None,
    maybe_max_shrinks: None,
    maybe_max_test_size: None,
    labels: Nil,
    classes: Nil,
    tables: Nil,
    test_case: Nil,
    error: InternalError("none"),
    callbacks: Nil,
  }
}
