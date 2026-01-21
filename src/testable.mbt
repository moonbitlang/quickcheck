///|
priv suberror InternalError {
  InternalError(String)
}

///|
pub(all) struct Arrow[A, B]((A) -> B)

///|
type RoseRes = Rose[SingleResult]

///|
using @rose {type Rose}

///|
/// TODO: determine the execution of callback by kind
enum Callback {
  PostTest(Kind, (State, SingleResult) -> Unit)
  PostFinalFailure(Kind, (State, SingleResult) -> Unit)
}

///|
priv enum Kind {
  CounterExample
  Nothing
}

///|
fn[T] promote_rose(s : Rose[Gen[T]]) -> Gen[Rose[T]] {
  delay().fmap(fn(m) { s.fmap(m) })
}

///|
struct Property(Gen[RoseRes])

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
  rejected().property()
}

///|
pub impl Testable for Unit with property(_self) {
  succeed().property()
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
  lift_bool(self).property()
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
pub impl[P : Testable, A : @coreqc.Arbitrary + Shrink + Show] Testable for Arrow[
  A,
  P,
] with property(self) {
  forall_shrink(Gen::spawn(), A::shrink, self.0)
}

///|
pub fn[P : Testable] run_prop(prop : P) -> Gen[Rose[SingleResult]] {
  prop.property().0
}

///|
pub fn[P : Testable] map_total_result(
  prop : P,
  f : (SingleResult) -> SingleResult,
) -> Property {
  run_prop(prop).fmap(fn(rose) { rose.fmap(f) })
}

///|
fn lift_bool(b : Bool) -> SingleResult {
  match b {
    true => succeed()
    false => { ..failed(), reason: "Falsified." }
  }
}

///|
fn[T : Testable] lift_option(opt : T?) -> Property {
  match opt {
    None => rejected().property()
    Some(x) => x.property()
  }
}

///|
pub fn[P : Testable] map_size(p : P, f : (Int) -> Int) -> Property {
  run_prop(p).scale(f)
}

///|
pub fn[P : Testable, T] shrinking(
  shrinker : (T) -> Iter[T],
  x0 : T,
  pf : (T) -> P,
) -> Property {
  fn props(x) -> Rose[Gen[RoseRes]] {
    @rose.new(pf(x) |> run_prop, shrinker(x).map(props))
  }

  promote_rose(props(x0)).fmap(fn(x) { x.join() })
}

///|
pub fn[P : Testable] callback(p : P, cb : Callback) -> Property {
  map_total_result(p, fn(res) { { ..res, callbacks: res.callbacks.add(cb) } })
}

///|
/// Attaches a label to a test case
pub fn[P : Testable] label(p : P, s : String) -> Property {
  map_total_result(p, fn(res) { { ..res, labels: res.labels.add(s) } })
}

///|
/// Attaches a label (Show) to a test case
pub fn[P : Testable, T : Show] collect(p : P, t : T) -> Property {
  p |> label(t.to_string())
}

///|
/// Classifies a test case based on a condition
pub fn[P : Testable] classify(p : P, cond : Bool, s : String) -> Property {
  map_total_result(p, fn(res) { { ..res, classes: res.classes.add((s, cond)) } })
}

///|
/// Adds a string to the counterexample if the property fails
pub fn[P : Testable] counterexample(p : P, s : String) -> Property {
  let cb = callback(p, PostFinalFailure(CounterExample, fn(_st, _res) {  }))
  map_total_result(cb, fn(res) { { ..res, test_case: res.test_case.add(s) } })
}

///|
/// Filters a property based on a condition
pub fn[P : Testable] filter(p : P, cond : Bool) -> Property {
  match cond {
    true => p.property()
    false => Discard::default().property()
  }
}

///|
/// Run with an explicit generator
pub fn[T : Testable, A : Show] forall(gen : Gen[A], f : (A) -> T) -> Property {
  forall_shrink(gen, fn(_x) { Iter::empty() }, f)
}

///|
pub fn[T : Testable, A : Show] forall_shrink(
  gen : Gen[A],
  shrinker : (A) -> Iter[A],
  f : (A) -> T,
) -> Property {
  gen.bind(fn(x) {
    shrinking(shrinker, x, fn(a : A) {
      let s = a.to_string()
      counterexample(f(a), s)
    }).0
  })
}

///|
/// Adds a callback that will be called if the property fails
pub fn[P : Testable] if_fail(p : P, f : () -> Unit) -> Property {
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
