///|
priv suberror InternalError {
  InternalError(String)
}

// `Arrow`, `ArrowError`, and `ArrowAsync` are declared in `types.mbt`.
// The `Testable` impls for them live further down in this file.

///|
/// The per-sample output of a property: a *tree* of `SingleResult`s
/// rather than a bare verdict.
///
/// - The **root** carries the verdict on the value the generator
///   originally produced — pass, fail, or discard.
/// - Each **child** carries the verdict on a strictly-simpler
///   candidate reached by one shrinking step. The tree is rooted at
///   the value the user's property was *actually* called with and
///   branches outward through every alternative a `Shrink` instance
///   (or a hand-rolled shrinker passed to `shrinking` / `forall_shrink`)
///   has to offer.
///
/// The driver's shrink loop (`State::local_min` in `driver.mbt`) is
/// precisely a walk of this tree: when the root reports `Failed` it
/// dives into the branches, keeps the first child that still falsifies
/// the property, and recurses — producing the minimal counter-example
/// the user sees in the failure report.
///
/// The choice of `@rose.Rose` (branches are `Iter[Rose[T]]`, not
/// `Array[Rose[T]]`) is what lets the shrink space of e.g. `Array[Int]`
/// or a recursive datatype stay lazy: we only force the candidates
/// we actually explore.
///
/// Package-private. External code talks to `Property` or to the
/// `Testable` trait rather than building `RoseResult`s directly.
type RoseResult = @rose.Rose[SingleResult]

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
fn[T] promote_rose(s : @rose.Rose[@gen.Gen[T]]) -> @gen.Gen[@rose.Rose[T]] {
  @gen.Gen((n, rs) => (g : @gen.Gen[T]) => g.run(n, rs)).fmap(m => s.fmap(m))
}

///|
/// The shape every `Testable` collapses to before the driver runs it:
/// a generator of a shrink tree of per-run outcomes.
///
/// Unpacking the definition — `Property` wraps
/// `@gen.Gen[@rose.Rose[SingleResult]]` — exposes the three layered
/// concerns the library composes independently:
///
/// 1. **`@gen.Gen[_]`** — *where does the input come from?* The
///    generator layer takes the driver-supplied `(size, RandomState)`
///    and produces one concrete test input per sample. `forall`,
///    `Gen::bind`, `Arbitrary::arbitrary`, and the size-scaling
///    combinators (`map_size`, `scale`) act at this layer.
/// 2. **`@rose.Rose[_]`** — *once input is fixed, how would we
///    shrink it?* The rose tree layer encodes the lazy space of
///    simpler candidates. `shrinking` and the `Shrink`-trait-backed
///    `forall_shrink` are the builders; the driver's shrink loop is
///    the consumer.
/// 3. **`SingleResult`** — *what happened for one concrete run?*
///    The leaf of each tree node records pass/fail/discard plus
///    label, classify, counter-example, and callback metadata. The
///    combinators `label` / `classify` / `collect` / `counterexample`
///    / `callback` all funnel through `map_total_result`, which
///    `rose.fmap`s a `SingleResult -> SingleResult` across every
///    node without touching the tree structure.
///
/// Because `Property` itself has a trivial `Testable` instance
/// (`property(self) = self`), every user-facing combinator can accept
/// any `P : Testable` and return a `Property` — the canonical,
/// driver-ready form.
///
/// Newtype rather than a raw alias so that the `Testable` trait can
/// name it in its signature without callers having to spell out the
/// layered `Gen[Rose[SingleResult]]` type.
struct Property(@gen.Gen[RoseResult])

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
impl Testable for SingleResult with property(self) {
  @gen.pure(@rose.pure(self))
}

///|
pub impl Testable for Bool with property(self) {
  match self {
    true => succeed().property()
    false => { ..failed(), reason: "Falsified." }.property()
  }
}

///|
pub impl[P : Testable] Testable for @gen.Gen[P] with property(self) {
  Property(self.bind(run_prop))
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
  forall_shrink(@gen.Gen::spawn(), A::shrink, self.0)
}

///|
/// `Testable` for a raising function: wraps `raise` as a failure by
/// catching the error and turning it into the counter-example reason.
pub impl[P : Testable, A : @coreqc.Arbitrary + Shrink + Show] Testable for ArrowError[
  A,
  P,
] with property(self) {
  forall_shrink(@gen.Gen::spawn(), A::shrink, (a : A) => try? (self.0)(a))
}

///|
/// Project a `Testable` to its underlying `@gen.Gen[Rose[SingleResult]]`.
/// Primarily used by other combinators that want to thread extra
/// transformations through the property.
fn[P : Testable] run_prop(prop : P) -> @gen.Gen[@rose.Rose[SingleResult]] {
  prop.property().0
}

///|
/// Apply `f` to every `SingleResult` produced by `prop`. Used by the
/// label / classify / counterexample combinators to decorate the
/// per-run result without changing the verdict.
fn[P : Testable] map_total_result(
  prop : P,
  f : (SingleResult) -> SingleResult,
) -> Property {
  run_prop(prop).fmap(rose => rose.fmap(f))
}

///|
/// Adjust the size parameter before running `p`. Equivalent to
/// `Gen::scale(f)` but lifted to the `Testable` level.
pub fn[P : Testable] map_size(p : P, f : (Int) -> Int) -> Property {
  p.property().map_size(f)
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
  fn props(x) -> @rose.Rose[@gen.Gen[RoseResult]] {
    { val: pf(x) |> run_prop, branch: shrinker(x).map(props) }
  }

  promote_rose(props(x0)).fmap(x => x.join())
}

///|
/// Attach a post-test (or post-final-failure) callback to `p`. The
/// callback receives the driver state and result; typical use is to
/// print diagnostics on a shrunk counter-example.
pub fn[P : Testable] callback(p : P, cb : Callback) -> Property {
  p.property().callback(cb)
}

///|
/// Attaches a label to a test case
pub fn[P : Testable] label(p : P, s : String) -> Property {
  p.property().label(s)
}

///|
/// Attaches a label (Show) to a test case
pub fn[P : Testable, T : Show] collect(p : P, t : T) -> Property {
  p.property().collect(t)
}

///|
/// Classifies a test case based on a condition
pub fn[P : Testable] classify(p : P, cond : Bool, s : String) -> Property {
  p.property().classify(cond, s)
}

///|
/// Adds a string to the counterexample if the property fails
pub fn[P : Testable] counterexample(p : P, s : String) -> Property {
  p.property().counterexample(s)
}

///|
/// Filters a property based on a condition
pub fn[P : Testable] filter(p : P, cond : Bool) -> Property {
  p.property().filter(cond)
}

///|
/// Run with an explicit generator
pub fn[T : Testable, A : Show] forall(
  gen : @gen.Gen[A],
  f : (A) -> T,
) -> Property {
  forall_shrink(gen, _x => Iter::empty(), f)
}

///|
/// Run a property with an explicit generator and shrinker. `forall`
/// is a convenience that passes `_ => Iter::empty()` — use this
/// version when you want a hand-rolled shrinker without going through
/// the `Shrink` trait.
pub fn[T : Testable, A : Show] forall_shrink(
  gen : @gen.Gen[A],
  shrinker : (A) -> Iter[A],
  f : (A) -> T,
) -> Property {
  gen.bind(x => {
    shrinking(shrinker, x, (a : A) => {
      let s = a.to_string()
      counterexample(f(a), s)
    }).0
  })
}

///|
/// Adds a callback that will be called if the property fails
pub fn[P : Testable] if_fail(p : P, f : () -> Unit) -> Property {
  p.property().if_fail(f)
}

// ========================================================================
//  Chainable `Property` methods.
//
//  These are the canonical, dot-callable form of the library's
//  decoration combinators:
//
//      forall(gen, prop)
//        .counterexample("after shrink")
//        .classify(n > 100, "big")
//        .collect(category)
//        .label("first pass")
//
//  Because `forall` and friends return `Property`, chains can start
//  right from a constructor. For a non-`Property` start (e.g. a bare
//  `Bool` or a `Gen[Bool]`), add an explicit `.property()` hop first:
//
//      some_bool.property().classify(...).label(...)
//
//  MoonBit doesn't yet allow dot-call on trait methods for concrete
//  types, so the methods live on `Property` rather than on the
//  `Testable` trait itself.
// ========================================================================

///|
/// Attach a label to the current test run. See the deprecated `label`
/// free function for the raw-expression form.
pub fn Property::label(self : Property, s : String) -> Property {
  Property(
    run_prop(self).fmap(rose => {
      rose.fmap(res => { ..res, labels: res.labels.add(s) })
    }),
  )
}

///|
/// Attach a `Show`-formatted label to the current test run. Shorthand
/// for `self.label(t.to_string())`.
pub fn[T : Show] Property::collect(self : Property, t : T) -> Property {
  self.label(t.to_string())
}

///|
/// Classify the current test run by a boolean condition.
pub fn Property::classify(self : Property, cond : Bool, s : String) -> Property {
  Property(
    run_prop(self).fmap(rose => {
      rose.fmap(res => { ..res, classes: res.classes.add((s, cond)) })
    }),
  )
}

///|
/// Append to the counter-example report that the driver prints when
/// the property's shrink-minimised witness fails.
pub fn Property::counterexample(self : Property, s : String) -> Property {
  let with_cb = self.callback(
    PostFinalFailure(CounterExample, (_st, _res) => ()),
  )
  Property(
    run_prop(with_cb).fmap(rose => {
      rose.fmap(res => { ..res, test_case: res.test_case.add(s) })
    }),
  )
}

///|
/// Discard the current input unless `cond` holds — short-circuits the
/// property to `Discard::default()` when `cond` is false.
pub fn Property::filter(self : Property, cond : Bool) -> Property {
  match cond {
    true => self
    false => Discard::default().property()
  }
}

///|
/// Attach a driver callback (post-test or post-final-failure hook).
pub fn Property::callback(self : Property, cb : Callback) -> Property {
  Property(
    run_prop(self).fmap(rose => {
      rose.fmap(res => { ..res, callbacks: res.callbacks.add(cb) })
    }),
  )
}

///|
/// Register a function to run when this property fails (post-final-failure).
pub fn Property::if_fail(self : Property, f : () -> Unit) -> Property {
  self.callback(
    PostTest(Nothing, (_st, res) => {
      guard res.status is Failed else { () }
      f()
    }),
  )
}

///|
/// Scale the size parameter threaded through the underlying generator.
pub fn Property::map_size(self : Property, f : (Int) -> Int) -> Property {
  Property(run_prop(self).scale(f))
}

///|
/// Demonstrate the chainable form on a `Property` returned by `forall`.
test "Property decorator methods chain in dot-call style" {
  let prop = forall(@gen.int_range(0, 100), (x : Int) => x >= 0)
    .counterexample("x should be non-negative")
    .classify(true, "checked")
    .label("range-0-100")
  quick_check(prop)
}
