// A self-contained shrink-search built on `Rose[T]`, with no
// QuickCheck driver / generators in sight. The whole point of `Rose`
// is that the *shape* is enough — given a tree of candidates and a
// predicate that decides "this candidate fails", we can find the
// minimum failing value with one short recursive walk.
//
// This file is the smallest illustration of why the rose-tree shape
// matters: ~12 lines of search logic, no per-type `Shrink` instance,
// no re-running of any shrinker on intermediate candidates.

///|
/// Find the minimum failing value in `rose`, given a `fails` predicate
/// (true ⇒ this value fails the property).
///
/// Returns:
/// - `None` if `rose.val` already passes (nothing to shrink).
/// - `Some(v)` where `v` is the deepest failing value reachable by
///   following the first failing child at each step.
///
/// This is exactly what a QuickCheck-style shrink loop does — the
/// real driver in `src/driver.mbt` adds bookkeeping (counts, abort
/// handling, callbacks) but the search itself is this.
fn[T] find_min_failing(rose : @rose.Rose[T], fails : (T) -> Bool) -> T? {
  if !fails(rose.val) {
    return None
  }
  // rose.val fails — descend into the first child that also fails.
  for child in rose.branch {
    match find_min_failing(child, fails) {
      Some(deeper) => return Some(deeper)
      None => continue
    }
  }
  // No child still fails: rose.val is the smallest failing value
  // along this path.
  Some(rose.val)
}

///|
/// Halving shrink tree: a single child per node, halving towards 0.
fn halve_tree(x : Int) -> @rose.Rose[Int] {
  if x == 0 {
    @rose.pure(0)
  } else {
    Rose(x, Iter::singleton(halve_tree(x / 2)))
  }
}

///|
test "find_min_failing on a halving int tree, predicate x >= 10" {
  // halve_tree(80) = 80 → 40 → 20 → 10 → 5 → 2 → 1 → 0
  // Smallest value still satisfying `x >= 10` is 10.
  debug_inspect(
    find_min_failing(halve_tree(80), x => x >= 10),
    content="Some(10)",
  )
}

///|
test "find_min_failing returns None when the root already passes" {
  let r = @rose.Rose(3, Iter::empty())
  debug_inspect(find_min_failing(r, x => x >= 10), content="None")
}

///|
test "find_min_failing skips passing siblings and follows the first failing branch" {
  // Tree (predicate: fails iff x >= 6):
  //
  //        10 (fails)
  //       /          \
  //      3 (passes)   8 (fails)
  //                   |
  //                   5 (passes)
  //
  // Walk: 10 fails → first child 3 passes (skip) → second child 8 fails →
  // descend into 8 → only child 5 passes → 8 is the smallest failure.
  let r = @rose.Rose(
    10,
    [@rose.pure(3), Rose(8, [@rose.pure(5)].iter())].iter(),
  )
  debug_inspect(find_min_failing(r, x => x >= 6), content="Some(8)")
}

///|
test "find_min_failing terminates on an infinite-width tree thanks to laziness" {
  // The root fails the predicate `x >= 0`. It has an infinite stream
  // of leaf children, all of which also fail. Without laziness this
  // would diverge; with `Iter`-shaped children, the walk pulls only
  // the first child it needs, finds it has no further shrinks, and
  // reports it.
  let infinite_failing = Iter::repeat(@rose.pure(7))
  let r = @rose.Rose(42, infinite_failing)
  debug_inspect(find_min_failing(r, x => x >= 0), content="Some(7)")
}
