# `quickcheck/feat`

This package implements FEAT-style functional enumeration using the same core
shape as `feat_moon`: an `Enumerate[T]` is a memoized function from an exact
size to an implicit finite sequence, plus an internal global-index prefix cache.

```moonbit nocheck
///|
struct Enumerate[T] {
  // private fields
}
```

`@ifseq.Seq[T]` stores a cardinality, a random-access indexer, and an ordered
traversal closure. Random access is still used for global indexing and random
sampling; full-part traversal/materialization uses the traversal closure.

## Core Operations

```mbt check
///|
test "part and index" {
  let bools : @feat.Enumerate[Bool] = @feat.Enumerable::enumerate()
  let part1 = @feat.part(bools, 1)
  @debug.assert_eq(@ifseq.length(part1), 2)
  @debug.assert_eq(@ifseq.get(part1, 0), true)
  @debug.assert_eq(@ifseq.get(part1, 1), false)
  @debug.assert_eq(bools[0], true)
  @debug.assert_eq(bools[1], false)
}
```

```mbt check
///|
test "product keeps full-part traversal fast" {
  let pairs : @feat.Enumerate[(Byte, Byte)] = @feat.Enumerable::enumerate()
  let part1 = @feat.part(pairs, 1)
  @debug.assert_eq(@ifseq.length(part1), 65536)
  let mut seen = 0
  @ifseq.each(part1, fn(_pair) { seen = seen + 1 })
  @debug.assert_eq(seen, 65536)
}
```

Recursive enumerations are guarded with `pay`.

```mbt check
///|
priv enum Tree {
  Leaf
  Node(Tree, Tree)
}

///|
fn node(pair : (Tree, Tree)) -> Tree {
  Node(pair.0, pair.1)
}

///|
impl @feat.Enumerable for Tree with fn enumerate() {
  @feat.pay(fn() {
    @feat.singleton(Leaf) +
    @feat.product(@feat.Enumerable::enumerate(), @feat.Enumerable::enumerate()).fmap(
      node,
    )
  })
}

///|
test "recursive product" {
  let trees : @feat.Enumerate[Tree] = @feat.Enumerable::enumerate()
  @debug.assert_eq(@ifseq.length(@feat.part(trees, 1)), 1)
  match trees[1] {
    Node(Leaf, Leaf) => ()
    _ => abort("expected Node(Leaf, Leaf)")
  }
}
```

## SmallCheck Bridge

`small_check` walks parts in increasing size order. When an entire part fits in
the remaining budget it materializes through `@ifseq.each`; if only a prefix is
needed it uses random access through `@ifseq.get`.
