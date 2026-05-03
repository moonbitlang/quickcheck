// Public API surface that has no current production callers but is
// kept exported on purpose — for users of the library and for the
// `mbt check` examples in `README.mbt.md`. Convention: items that
// are only reached from tests / docs live here so that grepping
// `rose.mbt` reflects the genuine in-driver-path code.

///|
/// Monadic bind: replace each node's value with the tree produced by
/// `f`. Equivalent to `self.fmap(f).join()`.
///
/// ```mbt check
/// test {
///   let r = pure(3).bind(x => pure(x * x))
///   assert_eq(r.iter().collect(), [9])
/// }
/// ```
pub fn[T, U] Rose::bind(self : Rose[T], f : (T) -> Rose[U]) -> Rose[U] {
  self.fmap(f).join()
}

///|
/// Inspect a node — pass its value and its branches to `f` and use
/// whatever `f` returns as the new node. Essentially a controlled
/// node-level rewrite; used when a shrinker wants to transform a
/// rose without descending into every child.
pub fn[T] Rose::apply(
  self : Rose[T],
  f : (T, Iter[Rose[T]]) -> Rose[T],
) -> Rose[T] {
  f(self.val, self.branch)
}

///|
/// Pre-order traversal: yields the root value, then the values of every
/// branch depth-first. Enables `for x in rose { ... }` and any other
/// `Iter`-shaped consumer.
///
/// The traversal is lazy: only as many sub-trees as you actually walk
/// are forced. Note that — like every `Iter` in MoonBit — the result
/// is single-shot; iterating the same `Rose` twice will only visit the
/// elements that were not yet consumed by an earlier walk.
pub fn[T] Rose::iter(self : Rose[T]) -> Iter[T] {
  Iter::singleton(self.val) + self.branch.flat_map(child => child.iter())
}
