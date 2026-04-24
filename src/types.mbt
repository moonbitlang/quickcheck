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
//   1. Driver expectations:   Expected
//   2. Testable plumbing:     Arrow[A, B], ArrowError, ArrowAsync
//
// Generator APIs now live in the dedicated `moonbitlang/quickcheck/gen`
// package. The root package keeps property DSL and driver types only.

// -----------------------------------------------------------------------

///|
/// Re-export the `Shrink` trait so existing callers can keep writing
/// `@quickcheck.Shrink` after the trait's definition moved to the
/// `moonbitlang/quickcheck/shrink` subpackage.
pub using @shrink {trait Shrink}

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
///     @qc.quick_check(@qc.Arrow((x : Int) => x == x))
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
