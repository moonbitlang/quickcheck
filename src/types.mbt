// -----------------------------------------------------------------------
// Public type facade for `moonbitlang/quickcheck`.
//
// The property/testable core now lives in
// `moonbitlang/quickcheck/property`; root keeps these re-exports so
// existing callers can keep using the familiar `@quickcheck.*` surface.
// -----------------------------------------------------------------------

///|
/// Re-export the `Shrink` trait so existing callers can keep writing
/// `@quickcheck.Shrink` after the trait's definition moved to the
/// `moonbitlang/quickcheck/shrink` subpackage.
pub using @shrink {trait Shrink}

///|
/// Re-export `Expected` from `internal/state` so the public driver
/// API (`quick_check(..., expect=Fail)`) stays spelled as
/// `@quickcheck.Expected` even though the enum now lives in the
/// internal package alongside the rest of the driver state.
pub using @state {type Expected}

///|
/// Re-export property/testable types from the lower-level property
/// package.
pub using @property {
  type Arrow,
  type ArrowError,
  type ArrowAsync,
  type Discard,
  type Property,
  trait Testable,
}

///|
/// Re-export the property DSL from `moonbitlang/quickcheck/property`.
pub using @property {
  callback,
  classify,
  collect,
  counterexample,
  filter,
  forall,
  forall_shrink,
  if_fail,
  label,
  map_size,
  property,
  shrinking,
}
