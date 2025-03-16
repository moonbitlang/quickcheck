///|
type! InternalError String

///|
pub type Arrow[A, B] (A) -> B

///|
typealias RoseRes = Rose[SingleResult]

///|
typealias Rose[T] = @rose.Rose[T]

///| TODO: determine the execution of callback by kind
enum Callback {
  PostTest(Kind, (State, SingleResult) -> Unit)
  PostFinalFailure(Kind, (State, SingleResult) -> Unit)
}

///|
enum Kind {
  CounterExample
  Nothing
} derive(Show)

///|
fn promote_rose[T](s : Rose[Gen[T]]) -> Gen[Rose[T]] {
  delay().fmap(fn(m) { s.fmap(m) })
}

///|
type Property Gen[RoseRes]

///|
pub(open) trait Testable {
  property(Self) -> Property
}

///|
struct Discard {} derive(Default)

///|
pub impl Testable for Property with property(self) {
  self
}

///|
pub impl Testable for Discard with property(_self) {
  rejected() |> Testable::property
}

///|
pub impl Testable for Unit with property(_self) {
  succeed() |> Testable::property
}

///|
pub impl Testable for RoseRes with property(self) {
  pure(self)
}

///|
pub impl Testable for SingleResult with property(self) {
  pure(@rose.pure(self))
}

///|
pub impl Testable for Bool with property(self) {
  lift_bool(self) |> Testable::property
}

///|
pub impl[P : Testable] Testable for Gen[P] with property(self) {
  self.bind(run_prop)
}

///|
pub impl[P : Testable] Testable for P? with property(self) {
  lift_option(self)
}

///|
pub impl[P : Testable, A : @quickcheck.Arbitrary + Shrink + Show] Testable for Arrow[
  A,
  P,
] with property(self) {
  forall_shrink(Gen::spawn(), A::shrink, self._)
}

///|
pub fn run_prop[P : Testable](prop : P) -> Gen[Rose[SingleResult]] {
  prop.property()._
}

///|
pub fn map_total_result[P : Testable](
  prop : P,
  f : (SingleResult) -> SingleResult
) -> Property {
  run_prop(prop).fmap(fn { rose => rose.fmap(f) })
}

///|
fn lift_bool(b : Bool) -> SingleResult {
  match b {
    true => succeed()
    false => { ..failed(), reason: "Falsified." }
  }
}

///|
fn lift_option[T : Testable](opt : T?) -> Property {
  match opt {
    None => rejected() |> Testable::property
    Some(x) => x.property()
  }
}

///|
pub fn map_size[P : Testable](p : P, f : (Int) -> Int) -> Property {
  run_prop(p).scale(f)
}

///|
pub fn shrinking[P : Testable, T](
  shrinker : (T) -> Iter[T],
  x0 : T,
  pf : (T) -> P
) -> Property {
  fn props(x) -> Rose[Gen[RoseRes]] {
    @rose.new(pf(x) |> run_prop, shrinker(x).map(props))
  }

  promote_rose(props(x0)).fmap(fn(x) { x.join() })
}

///|
pub fn callback[P : Testable](p : P, cb : Callback) -> Property {
  map_total_result(p, fn(res) { { ..res, callbacks: Cons(cb, res.callbacks) } })
}

///| Attaches a label to a test case
pub fn label[P : Testable](p : P, s : String) -> Property {
  map_total_result(p, fn(res) { { ..res, labels: Cons(s, res.labels) } })
}

///| Attaches a label (Show) to a test case
pub fn collect[P : Testable, T : Show](p : P, t : T) -> Property {
  p |> label(t.to_string())
}

///| Classifies a test case based on a condition
pub fn classify[P : Testable](p : P, cond : Bool, s : String) -> Property {
  map_total_result(p, fn(res) {
    { ..res, classes: Cons((s, cond), res.classes) }
  })
}

///| Adds a string to the counterexample if the property fails
pub fn counterexample[P : Testable](p : P, s : String) -> Property {
  let cb = callback(p, PostFinalFailure(CounterExample, fn(_st, _res) {  }))
  map_total_result(cb, fn(res) { { ..res, test_case: Cons(s, res.test_case) } })
}

///| Filters a property based on a condition
pub fn filter[P : Testable](p : P, cond : Bool) -> Property {
  match cond {
    true => p.property()
    false => Testable::property(Discard::default())
  }
}

///| Run with an explicit generator
pub fn forall[T : Testable, A : Show](gen : Gen[A], f : (A) -> T) -> Property {
  forall_shrink(gen, fn(_x) { Iter::empty() }, f)
}

///|
pub fn forall_shrink[T : Testable, A : Show](
  gen : Gen[A],
  shrinker : (A) -> Iter[A],
  f : (A) -> T
) -> Property {
  gen.bind(fn(x) {
    shrinking(shrinker, x, fn(a : A) {
      let s = a.to_string()
      counterexample(f(a), s)
    })._
  })
}

///| Adds a callback that will be called if the property fails
pub fn if_fail[P : Testable](p : P, f : () -> Unit) -> Property {
  callback(
    p,
    PostTest(Nothing, fn(_st, res) {
      match res.ok {
        Some(false) => f()
        _ => ()
      }
    }),
  )
}

///| Modifies a property to make it terminate after the first test
pub fn terminate[P : Testable](p : P) -> Property {
  map_total_result(p, fn(res) { { ..res, abort: true } })
}

///|
pub fn expect_fail[P : Testable](p : P) -> Property {
  map_total_result(p, fn(res) { { ..res, expect: Some(false) } })
}

///|
pub fn expect_gave_up[P : Testable](p : P) -> Property {
  map_total_result(p, fn(res) { { ..res, expect: None } })
}

///|
pub fn with_max_success[P : Testable](p : P, n : Int) -> Property {
  map_total_result(p, fn(res) { { ..res, maybe_num_tests: Some(n) } })
}

///|
pub fn with_discarded_ratio[P : Testable](p : P, n : Int) -> Property {
  map_total_result(p, fn(res) { { ..res, maybe_discarded_ratio: Some(n) } })
}

///|
pub fn with_max_shrinks[P : Testable](p : P, n : Int) -> Property {
  map_total_result(p, fn(res) { { ..res, maybe_max_shrinks: Some(n) } })
}

///|
pub fn with_max_size[P : Testable](p : P, n : Int) -> Property {
  map_total_result(p, fn(res) { { ..res, maybe_max_test_size: Some(n) } })
}
