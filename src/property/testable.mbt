///|
fn[T] promote_rose(s : @rose.Rose[@gen.Gen[T]]) -> @gen.Gen[@rose.Rose[T]] {
  @gen.Gen((n, rs) => (g : @gen.Gen[T]) => g.run(n, rs)).fmap(m => s.fmap(m))
}

///|
/// The shape every `Testable` collapses to before a driver runs it:
/// a generator of a shrink tree of per-run outcomes.
///
/// `Property` wraps `@gen.Gen[@rose.Rose[SingleResult]]`, keeping the
/// representation opaque while exposing controlled execution helpers.
struct Property(@gen.Gen[@rose.Rose[@state.SingleResult]])

///|
/// Anything that can be handed to a QuickCheck-style driver.
///
/// Implementors turn themselves into a `Property`, which a driver then
/// evaluates. Built-in instances exist for `Bool`, `Unit`, results,
/// optional values, generators, and the `Arrow` wrappers.
pub(open) trait Testable {
  property(Self) -> Property
}

///|
/// A property that discards the current test case.
struct Discard {} derive(Default)

///|
pub impl Testable for Property with property(self) {
  self
}

///|
pub impl Testable for Discard with property(_self) {
  Testable::property(@state.rejected())
}

///|
pub impl Testable for Unit with property(_self) {
  Testable::property(@state.succeed())
}

///|
pub impl Testable for @state.SingleResult with property(self) {
  @gen.pure(@rose.pure(self))
}

///|
pub impl Testable for Bool with property(self) {
  match self {
    true => Testable::property(@state.succeed())
    false => Testable::property({ ..@state.failed(), reason: "Falsified." })
  }
}

///|
pub impl[P : Testable] Testable for @gen.Gen[P] with property(self) {
  self.bind(run_prop)
}

///|
pub impl[P : Testable] Testable for P? with property(self) {
  match self {
    None => Testable::property(@state.rejected())
    Some(x) => x.property()
  }
}

///|
pub impl[P : Testable, E : Debug] Testable for Result[P, E] with property(self) {
  match self {
    Ok(p) => p.property()
    Err(e) =>
      Testable::property({ ..@state.failed(), reason: @debug.to_string(e) })
  }
}

///|
pub impl[P : Testable, A : @coreqc.Arbitrary + @shrink.Shrink + Debug] Testable for Arrow[
  A,
  P,
] with property(self) {
  forall_shrink(@gen.Gen::spawn(), A::shrink, self.0)
}

///|
/// `Testable` for a raising function: wraps `raise` as a failure by
/// catching the error and turning it into the counter-example reason.
pub impl[P : Testable, A : @coreqc.Arbitrary + @shrink.Shrink + Debug] Testable for ArrowError[
  A,
  P,
] with property(self) {
  forall_shrink(@gen.Gen::spawn(), A::shrink, (a : A) => try? (self.0)(a))
}

///|
/// Project a `Testable` to its underlying `@gen.Gen[Rose[SingleResult]]`.
/// This stays private so callers can compose through `Property` instead
/// of depending on its representation.
fn[P : Testable] run_prop(
  prop : P,
) -> @gen.Gen[@rose.Rose[@state.SingleResult]] {
  prop.property().0
}

///|
/// Lift any `Testable` value to a chainable `Property`.
pub fn[P : Testable] property(prop : P) -> Property {
  prop.property()
}

///|
/// Apply `f` to every `SingleResult` produced by `prop`. Used by the
/// label / classify / counterexample combinators to decorate the
/// per-run result without changing the verdict.
fn[P : Testable] map_total_result(
  prop : P,
  f : (@state.SingleResult) -> @state.SingleResult,
) -> Property {
  run_prop(prop).fmap(rose => rose.fmap(f))
}

///|
/// Attach driver run options to every result produced by `prop`.
/// Driver packages use this instead of reaching into `Property`'s
/// representation directly.
pub fn[P : Testable] with_run_options(
  prop : P,
  expect : Expected,
  abort : Bool,
) -> Property {
  map_total_result(prop, res => { ..res, expect, abort })
}

///|
/// Evaluate a `Property` with an explicit size and random state.
/// This is the controlled representation boundary used by drivers.
pub fn Property::run(
  self : Property,
  size : Int,
  random_state : @gen.RandomState,
) -> @rose.Rose[@state.SingleResult] {
  self.0.run(size, random_state)
}

///|
/// Adjust the size parameter before running `p`. Equivalent to
/// `Gen::scale(f)` but lifted to the `Testable` level.
pub fn[P : Testable] map_size(p : P, f : (Int) -> Int) -> Property {
  run_prop(p).scale(f)
}

///|
/// Method form of `map_size`, useful for chaining property decorators.
pub fn Property::map_size(self : Property, f : (Int) -> Int) -> Property {
  map_size(self, f)
}

///|
/// Manually drive shrinking with a user-supplied shrinker and starting
/// value.
pub fn[P : Testable, T] shrinking(
  shrinker : (T) -> Iter[T],
  x0 : T,
  pf : (T) -> P,
) -> Property {
  fn props(x) -> @rose.Rose[@gen.Gen[@rose.Rose[@state.SingleResult]]] {
    Rose(pf(x) |> run_prop, shrinker(x).map(props))
  }

  promote_rose(props(x0)).fmap(x => x.join())
}

///|
/// Attach a post-test or post-final-failure callback to `p`.
pub fn[P : Testable] callback(p : P, cb : @state.Callback) -> Property {
  map_total_result(p, res => { ..res, callbacks: res.callbacks.add(cb) })
}

///|
/// Method form of `callback`, useful for chaining property decorators.
pub fn Property::callback(self : Property, cb : @state.Callback) -> Property {
  callback(self, cb)
}

///|
/// Attaches a label to a test case.
pub fn[P : Testable] label(p : P, s : String) -> Property {
  map_total_result(p, res => { ..res, labels: res.labels.add(s) })
}

///|
/// Method form of `label`, useful for chaining property decorators.
pub fn Property::label(self : Property, s : String) -> Property {
  label(self, s)
}

///|
/// Attaches a rendered value as a label to a test case.
pub fn[P : Testable, T : Show] collect(p : P, t : T) -> Property {
  p |> label(Show::to_string(t))
}

///|
/// Method form of `collect`, useful for chaining property decorators.
pub fn[T : Show] Property::collect(self : Property, t : T) -> Property {
  collect(self, t)
}

///|
/// Classifies a test case based on a condition.
pub fn[P : Testable] classify(p : P, cond : Bool, s : String) -> Property {
  map_total_result(p, res => { ..res, classes: res.classes.add((s, cond)) })
}

///|
/// Method form of `classify`, useful for chaining property decorators.
pub fn Property::classify(self : Property, cond : Bool, s : String) -> Property {
  classify(self, cond, s)
}

///|
/// Adds a string to the counterexample if the property fails.
pub fn[P : Testable] counterexample(p : P, s : String) -> Property {
  let cb = callback(p, PostFinalFailure(CounterExample, (_st, _res) => ()))
  map_total_result(cb, res => { ..res, test_case: res.test_case.add(s) })
}

///|
/// Method form of `counterexample`, useful for chaining diagnostics.
pub fn Property::counterexample(self : Property, s : String) -> Property {
  counterexample(self, s)
}

///|
/// Filters a property based on a condition.
pub fn[P : Testable] filter(p : P, cond : Bool) -> Property {
  match cond {
    true => p.property()
    false => Discard::default().property()
  }
}

///|
/// Method form of `filter`, useful for chaining property decorators.
pub fn Property::filter(self : Property, cond : Bool) -> Property {
  filter(self, cond)
}

///|
/// Run with an explicit generator.
pub fn[T : Testable, A : Debug] forall(
  gen : @gen.Gen[A],
  f : (A) -> T,
) -> Property {
  forall_shrink(gen, _x => Iter::empty(), f)
}

///|
/// Run a property with an explicit generator and shrinker.
pub fn[T : Testable, A : Debug] forall_shrink(
  gen : @gen.Gen[A],
  shrinker : (A) -> Iter[A],
  f : (A) -> T,
) -> Property {
  gen.bind(x => {
    shrinking(shrinker, x, (a : A) => {
      let s = @debug.to_string(a)
      counterexample(f(a), s)
    }).0
  })
}

///|
/// Adds a callback that is called if the property fails.
pub fn[P : Testable] if_fail(p : P, f : () -> Unit) -> Property {
  callback(
    p,
    PostTest(Nothing, fn(_st, res) {
      guard res.status is Failed else { () }
      f()
    }),
  )
}

///|
/// Method form of `if_fail`, useful for chaining property decorators.
pub fn Property::if_fail(self : Property, f : () -> Unit) -> Property {
  if_fail(self, f)
}
