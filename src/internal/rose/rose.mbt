// Rose Tree used for shrinking

///|
/// A rose tree: a value plus a (possibly infinite, possibly lazy)
/// `Iter` of child rose trees. The shape QuickCheck and falsify both
/// use to represent a *shrinkable* value — `val` is the current
/// candidate; `branch` enumerates the strictly-simpler alternatives
/// the driver should try if `val` falsifies a property.
///
/// `branch : Iter[Rose[T]]` rather than `Array[Rose[T]]` on purpose —
/// `Iter` is single-shot and lazy, so an infinite tree (e.g. the
/// shrink space of `Int` or a recursive data type) is representable
/// without materialising every candidate.
///
/// Primary constructor: `Rose(val, branch)`. `Rose::new` is kept as a
/// deprecated alias for callers that haven't migrated yet.
pub(all) struct Rose[T] {
  val : T
  branch : Iter[Rose[T]]
} derive(Debug)

///|
/// Deprecated: prefer the primary constructor `Rose(val, branch)`.
/// Kept for backward compatibility with callers that predate the
/// primary-constructor migration.
#as_free_fn(deprecated="Use Rose(...) directly")
pub fn[T] Rose::Rose(val : T, branch : Iter[Rose[T]]) -> Rose[T] {
  { val, branch }
}

///|
/// Flatten `Rose[Rose[T]]` into `Rose[T]` — the monadic `join`.
///
/// The inner tree at the root contributes its value and its branches;
/// the outer tree's branches are recursively joined and prepended to
/// the inner branches. Used internally to implement `bind`.
///
/// ```mbt check
/// test {
///   let nested : Rose[Rose[Int]] = pure(pure(42))
///   assert_eq(nested.join().iter().collect(), [42])
/// }
/// ```
pub fn[T] Rose::join(self : Rose[Rose[T]]) -> Rose[T] {
  let tss = self.branch
  let ts = self.val.branch
  { val: self.val.val, branch: tss.map(x => x.join()).concat(ts) }
}

///|
/// The unit of the `Rose` monad: a leaf carrying `val` with no
/// alternatives.
///
/// ```mbt check
/// test {
///   let r : Rose[String] = pure("hello")
///   assert_eq(r.val, "hello")
///   assert_eq(r.branch.collect().length(), 0)
/// }
/// ```
pub fn[T] pure(val : T) -> Rose[T] {
  { val, branch: Iter::empty() }
}

///|
/// Map `f` over every node in the tree, preserving structure. The
/// result has the same shape as `self`, with each node's value
/// replaced by `f(value)`.
///
/// ```mbt check
/// test {
///   let tree = Rose::{ val: 1, branch: [pure(2), pure(3)].iter() }
///   let doubled = tree.fmap(x => x * 2)
///   assert_eq(doubled.iter().collect(), [2, 4, 6])
/// }
/// ```
pub fn[T, U] Rose::fmap(self : Rose[T], f : (T) -> U) -> Rose[U] {
  { val: f(self.val), branch: self.branch.map(x => x.fmap(f)) }
}

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

///|
test "iter walks root then branches in depth-first order" {
  // A small handcrafted tree:
  //
  //        1
  //       / \
  //      2   5
  //     / \   \
  //    3   4   6
  let leaf = pure
  let tree = Rose::{
    val: 1,
    branch: [
      { val: 2, branch: [leaf(3), leaf(4)].iter() },
      { val: 5, branch: [leaf(6)].iter() },
    ].iter(),
  }
  let collected = tree.iter().collect()
  assert_eq(collected, [1, 2, 3, 4, 5, 6])
}

///|
test "iter on a leaf yields only the root" {
  assert_eq(pure(42).iter().collect(), [42])
}

///|
test "for .. in sugar walks every value" {
  let tree = Rose::{ val: 10, branch: [pure(20), pure(30)].iter() }
  let acc = []
  for x in tree {
    acc.push(x)
  }
  assert_eq(acc, [10, 20, 30])
}

///|
/// Sibling branches are an infinite stream. `iter().take(n)` must
/// terminate — a naive eager implementation would try to build an
/// unbounded prefix before yielding anything.
test "iter is lazy over an infinite-width tree" {
  let infinite_siblings = Iter::repeat(pure(7))
  let tree = Rose::{ val: 0, branch: infinite_siblings }
  assert_eq(tree.iter().take(5).collect(), [0, 7, 7, 7, 7])
}

///|
/// Depth is unbounded: spine(n) has exactly one child, spine(n+1).
/// The `branch` field is a lazy `Iter::new(...)` so the recursive call
/// is only forced when the outer iterator pulls a value. If
/// `Rose::iter` were not lazy, building spine(0) or calling .iter() on
/// it would non-terminate.
test "iter is lazy over an infinite-depth spine" {
  fn spine(n : Int) -> Rose[Int] {
    let mut pulled = false
    let branch : Iter[Rose[Int]] = Iter::new(() => {
      if pulled {
        None
      } else {
        pulled = true
        Some(spine(n + 1))
      }
    })
    { val: n, branch }
  }

  assert_eq(spine(0).iter().take(6).collect(), [0, 1, 2, 3, 4, 5])
}

///|
/// Early `break` in a `for .. in` loop must also be lazy: we should
/// never touch the sub-trees past the break point.
test "for .. in with early break visits only the prefix" {
  let infinite = Rose::{ val: 0, branch: Iter::repeat(pure(1)) }
  let acc = []
  for x in infinite {
    if acc.length() == 3 {
      break
    }
    acc.push(x)
  }
  assert_eq(acc, [0, 1, 1])
}
