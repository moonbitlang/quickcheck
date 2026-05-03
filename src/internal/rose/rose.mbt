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
pub struct Rose[T] {
  val : T
  branch : Iter[Rose[T]]
} derive(Debug)

///|
/// Deprecated: prefer the primary constructor `Rose(val, branch)`.
/// Kept for backward compatibility with callers that predate the
/// primary-constructor migration.
// TODO(upstream): as_free_fn(deprecated="Use Rose(...) directly")
// the attribute unknown is unclear, should report `unused attribute`? 
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
  Rose(self.val.val, tss.map(x => x.join()).concat(ts))
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
  Rose(val, Iter::empty())
}

///|
/// Map `f` over every node in the tree, preserving structure. The
/// result has the same shape as `self`, with each node's value
/// replaced by `f(value)`.
///
/// ```mbt check
/// test {
///   let tree = @rose.Rose(1, [pure(2), pure(3)].iter())
///   let doubled = tree.fmap(x => x * 2)
///   assert_eq(doubled.iter().collect(), [2, 4, 6])
/// }
/// ```
pub fn[T, U] Rose::fmap(self : Rose[T], f : (T) -> U) -> Rose[U] {
  Rose(f(self.val), self.branch.map(x => x.fmap(f)))
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
  let tree = Rose(
    1,
    [Rose(2, [leaf(3), leaf(4)].iter()), Rose(5, [leaf(6)].iter())].iter(),
  )
  let collected = tree.iter().collect()
  assert_eq(collected, [1, 2, 3, 4, 5, 6])
}

///|
test "iter on a leaf yields only the root" {
  assert_eq(pure(42).iter().collect(), [42])
}

///|
test "for .. in sugar walks every value" {
  let tree = Rose(10, [pure(20), pure(30)].iter())
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
  let tree = Rose(0, infinite_siblings)
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
    Rose(n, branch)
  }

  assert_eq(spine(0).iter().take(6).collect(), [0, 1, 2, 3, 4, 5])
}

///|
/// Early `break` in a `for .. in` loop must also be lazy: we should
/// never touch the sub-trees past the break point.
test "for .. in with early break visits only the prefix" {
  let infinite = Rose(0, Iter::repeat(pure(1)))
  let acc = []
  for x in infinite {
    if acc.length() == 3 {
      break
    }
    acc.push(x)
  }
  assert_eq(acc, [0, 1, 1])
}
