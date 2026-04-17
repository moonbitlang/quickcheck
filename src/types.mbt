// -----------------------------------------------------------------------
// Public type surface for `moonbitlang/quickcheck`.
//
// This file consolidates every public, user-facing type declared by the
// root package so that an author exploring the library can find and
// understand the core data structures in one place. Methods, traits, and
// implementation-private helpers stay in the file that owns the
// behaviour — see the referenced files in each docstring.
//
// The types fall into three conceptual groups:
//
//   1. Property outcomes:     Outcome[T], Expected
//   2. Replay & auditing:     Replay
//   3. Testable plumbing:     Arrow[A, B], ArrowError, ArrowAsync
//
// `Gen[T]` deliberately stays in `gen.mbt` — its struct body carries
// the primary-constructor declaration plus every combinator method, so
// splitting it would cost more than it saves.
// -----------------------------------------------------------------------

// ========================================================================
//  Property outcomes
// ========================================================================

///|
/// The outcome the driver reports for a single `quick_check` run.
///
/// The classical QuickCheck trichotomy:
///
/// - `Success`: every test passed; no counterexample was found within
///   the configured budget.
/// - `GaveUp`: too many inputs were discarded (via preconditions or
///   `@qc.filter`) before we could run the requested number of tests.
/// - `Fail(t)`: at least one generated input falsified the property.
///   `t` carries the already-shrunk counterexample in whatever shape
///   the driver chose — typically a pretty-printable record of the
///   failing case, the seed, and the shrink trail.
///
/// The `Show` implementation (defined in `result.mbt`) renders `OK`,
/// `GAVE UP`, or `FAIL`, irrespective of the payload of `Fail`. Users
/// who need the payload should pattern-match on the `Outcome`
/// directly.
pub(all) enum Outcome[T] {
  Success
  GaveUp
  Fail(T) // Counterexample
}

///|
/// What the *author* of a property *expects* to happen. This is the
/// knob behind `quick_check_fn(..., expect=Fail)` and friends: if the
/// driver's actual `Outcome` matches `Expected`, the check is
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

// ========================================================================
//  Replay & auditing
// ========================================================================

///|
/// A snapshot of the RNG state and size parameter sufficient to rerun
/// a property on the exact same input sequence.
///
/// Every failing `Outcome::Fail` in the driver carries a `Replay`
/// inside its counterexample record — copy it into a test, pass it
/// back via the driver's replay hook, and you will deterministically
/// reproduce the failure on any machine. This is how the project's
/// test suite pins previously-found counterexamples.
///
/// Fields:
/// - `rand_state`: SplitMix seed captured just before the offending
///   sample was drawn.
/// - `size`: the size parameter the property was running at (the same
///   value threaded through `sized` / `scale`).
///
/// Constructor: `Replay::new(rand_state, size)` (see `result.mbt`).
pub(all) struct Replay {
  rand_state : RandomState
  size : Int
}

///|
impl Show for Replay with output(self, logger) {
  logger.write_string(
    "Replay: { state : \{self.rand_state}, size : \{self.size} }",
  )
}

// ========================================================================
//  Testable plumbing
// ========================================================================

///|
/// `Arrow[A, B]` is a newtype wrapper around a pure, total function
/// `(A) -> B`. Wrapping is what lets us write
///
///     pub impl[P : Testable, A : Arbitrary + Shrink + Show] Testable for Arrow[A, P]
///
/// — MoonBit does not let us implement a trait *directly* on the bare
/// function type `(A) -> B`, so `Arrow` is the obligatory detour.
///
/// For the user this shows up as `@qc.Arrow(prop)` at the driver
/// boundary:
///
///     @qc.quick_check(@qc.Arrow(fn(x : Int) -> Bool { x == x }))
///
/// Most users never see `Arrow` directly because `quick_check_fn`
/// wraps the function for them. Reach for the explicit form only when
/// you need to hand a `Testable`-wrapped property to a combinator that
/// takes `Testable` values (e.g. `classify`, `label`).
///
/// See also: `ArrowError` (for properties that may `raise`) and
/// `ArrowAsync` (for properties that are `async`).
pub(all) struct Arrow[A, B]((A) -> B)

///|
/// Same role as `Arrow`, but the wrapped function may `raise` an error.
/// Use this when your property calls into code that throws and you
/// want the driver to treat a raised exception as a test failure with
/// the captured error as the counterexample's `reason`.
///
/// Under the hood it's identical to `Arrow` plus a `raise` clause.
pub(all) struct ArrowError[A, B]((A) -> B raise)

///|
/// Same role as `Arrow`, but the wrapped function is `async`. The
/// async driver in the main package (see `driver.mbt`) awaits the
/// inner coroutine and threads it through the same shrink loop as the
/// synchronous path.
pub(all) struct ArrowAsync[A, B](async (A) -> B)
