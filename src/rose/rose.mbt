// Rose Tree used for shrinking

///|
pub(all) struct Rose[T] {
  val : T
  branch : Iter[Rose[T]]
} derive(Debug)

///|
pub fn[T] new(val : T, branch : Iter[Rose[T]]) -> Rose[T] {
  { val, branch }
}

///|
pub fn[T] Rose::join(self : Rose[Rose[T]]) -> Rose[T] {
  let tss = self.branch
  let ts = self.val.branch
  { val: self.val.val, branch: tss.map(fn(x) { x.join() }).concat(ts) }
}

///|
pub fn[T] pure(val : T) -> Rose[T] {
  { val, branch: Iter::empty() }
}

///|
pub fn[T, U] Rose::fmap(self : Rose[T], f : (T) -> U) -> Rose[U] {
  { val: f(self.val), branch: self.branch.map(fn(x) { x.fmap(f) }) }
}

///|
pub fn[T, U] Rose::bind(self : Rose[T], f : (T) -> Rose[U]) -> Rose[U] {
  self.fmap(f).join()
}

///|
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
