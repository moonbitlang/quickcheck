// -----------------------------------------------------------------------
// Public type surface for `moonbitlang/quickcheck/property`.
//
// This lower-level package owns the `Testable -> Property` collapse and
// the function wrappers that make function properties implementable.
// -----------------------------------------------------------------------

///|
/// Re-export `Expected` from `internal/state` so lower-level property
/// runners can spell run expectations without importing driver internals.
pub using @state {type Expected}

///|
/// `Arrow[A, B]` is a newtype wrapper around a pure, total function
/// `(A) -> B`. Wrapping is what lets the package implement `Testable`
/// for generated inputs; MoonBit does not allow implementing a trait
/// directly on the bare function type `(A) -> B`.
pub(all) struct Arrow[A, B]((A) -> B)

///|
/// Same role as `Arrow`, but the wrapped function may `raise` an error.
/// A raised error is converted into a failing property result.
pub(all) struct ArrowError[A, B]((A) -> B raise)

///|
/// Same role as `Arrow`, but the wrapped function is `async`. The type
/// is reserved for async property testing; no `Testable` impl is wired
/// up yet.
pub(all) struct ArrowAsync[A, B](async (A) -> B)
