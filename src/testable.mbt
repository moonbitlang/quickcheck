///|
priv suberror InternalError {
  InternalError(String)
}

// `Arrow`, `ArrowError`, and `ArrowAsync` are declared in `types.mbt`.
// The `Testable` impls for them live further down in this file.

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
/// Anything that can be handed to the `quick_check` driver.
///
/// Implementors turn themselves into a `Property` — a `Gen` of a
/// `Rose` of per-run outcomes — which the driver then evaluates.
/// Built-in instances exist for `Bool` (treated as pass/fail) and
/// for `Arrow[A, P]` / `ArrowError[A, P]` when
/// `A : Arbitrary + Shrink + Show` and `P : Testable`.
///
/// The `ArrowAsync[A, P]` newtype exists but no `Testable` impl is
/// provided yet — async property testing is planned but not wired up.
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
  match self {
    true => succeed().property()
    false => { ..failed(), reason: "Falsified." }.property()
  }
}

///|
pub impl[P : Testable] Testable for Gen[P] with property(self) {
  self.bind(run_prop)
}

///|
pub impl[P : Testable] Testable for P? with property(self) {
  match self {
    None => rejected().property()
    Some(x) => x.property()
  }
}

///|
pub impl[P : Testable, E : Show] Testable for Result[P, E] with property(self) {
  match self {
    Ok(p) => p.property()
    Err(e) => { ..failed(), reason: e.to_string() }.property()
  }
}

///|
pub impl[P : Testable, A : @coreqc.Arbitrary + Shrink + Show] Testable for Arrow[
  A,
  P,
] with property(self) {
  forall_shrink(Gen::spawn(), A::shrink, self.0)
}

///|
/// `Testable` for a raising function: wraps `raise` as a failure by
/// catching the error and turning it into the counter-example reason.
pub impl[P : Testable, A : @coreqc.Arbitrary + Shrink + Show] Testable for ArrowError[
  A,
  P,
] with property(self) {
  forall_shrink(Gen::spawn(), A::shrink, fn(a : A) { try? (self.0)(a) })
}

///|
/// Project a `Testable` to its underlying `Gen[Rose[SingleResult]]`.
/// Primarily used by other combinators that want to thread extra
/// transformations through the property.
pub fn[P : Testable] run_prop(prop : P) -> Gen[Rose[SingleResult]] {
  prop.property().0
}

///|
/// Apply `f` to every `SingleResult` produced by `prop`. Used by the
/// label / classify / counterexample combinators to decorate the
/// per-run result without changing the verdict.
pub fn[P : Testable] map_total_result(
  prop : P,
  f : (SingleResult) -> SingleResult,
) -> Property {
  run_prop(prop).fmap(fn(rose) { rose.fmap(f) })
}

///|
/// Adjust the size parameter before running `p`. Equivalent to
/// `Gen::scale(f)` but lifted to the `Testable` level.
pub fn[P : Testable] map_size(p : P, f : (Int) -> Int) -> Property {
  run_prop(p).scale(f)
}

///|
/// Manually drive shrinking: given a user-supplied `shrinker` and a
/// starting value `x0`, build a `Property` whose `Rose` branches mirror
/// the shrink tree produced by `shrinker`. Rarely needed in user code
/// — the `Shrink` trait instances drive this automatically — but
/// useful when a one-off custom shrink sequence is required.
pub fn[P : Testable, T] shrinking(
  shrinker : (T) -> Iter[T],
  x0 : T,
  pf : (T) -> P,
) -> Property {
  fn props(x) -> Rose[Gen[RoseRes]] {
    Rose(pf(x) |> run_prop, shrinker(x).map(props))
  }

  promote_rose(props(x0)).fmap(fn(x) { x.join() })
}

///|
/// Attach a post-test (or post-final-failure) callback to `p`. The
/// callback receives the driver state and result; typical use is to
/// print diagnostics on a shrunk counter-example.
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
/// Run a property with an explicit generator and shrinker. `forall`
/// is a convenience that passes `fn(_) { Iter::empty() }` — use this
/// version when you want a hand-rolled shrinker without going through
/// the `Shrink` trait.
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
      guard res.status is Failed else { () }
      f()
    }),
  )
}
