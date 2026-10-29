///|
test "feat int" {
  let fe : @coreqc.Generator[Int32] = @feat.feat_random(10)
  let values = fe.samples(count=50, size=50)
  assert_eq(values.length(), 50)
  for value in values {
    assert_true(value > -10 && value < 10)
  }
  assert_true(values.iter().any(x => x < 0))
  assert_true(values.iter().any(x => x > 0))
  assert_eq(values, fe.samples(count=50, size=50))
}

///|
test "feat nat" {
  let fe : @coreqc.Generator[Nat] = @feat.feat_random(21)
  let values = fe.samples(count=20, size=20)
  assert_eq(values.length(), 20)
  let depths = values.map(nat_depth)
  for depth in depths {
    assert_true(depth >= 0 && depth < 21)
  }
  assert_true(depths.contains(0))
  assert_true(depths.iter().any(x => x > 10))
  assert_eq(depths, fe.samples(count=20, size=20).map(nat_depth))
}

///|
test "feat nat index" {
  let x = [0N, 1, 2, 3, 4, 5, 6].map(x => {
    (@feat.Enumerable::enumerate() : @feat.Enumerate[Nat])[x]
  })
  debug_inspect(
    x,
    content=(
      #|[
      #|  Zero,
      #|  Succ(Zero),
      #|  Succ(Succ(Zero)),
      #|  Succ(Succ(Succ(Zero))),
      #|  Succ(Succ(Succ(Succ(Zero)))),
      #|  Succ(Succ(Succ(Succ(Succ(Zero))))),
      #|  Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))),
      #|]
    ),
  )
}

///|
test "feat int index order" {
  let e : @feat.Enumerate[Int32] = @feat.Enumerable::enumerate()
  let xs = [0N, 1, 2, 3, 4, 5].map(i => e[i])
  debug_inspect(xs, content="[0, 1, -1, 2, -2, 3]")
}

///|
test "feat byte index order" {
  let e : @feat.Enumerate[Byte] = @feat.Enumerable::enumerate()
  let xs = [0N, 1, 2, 3].map(i => e[i])
  debug_inspect(
    xs,
    content=(
      #|[0x00, 0x01, 0x02, 0x03]
    ),
  )
}

///|
test "feat char index order" {
  let e : @feat.Enumerate[Char] = @feat.Enumerable::enumerate()
  let xs = [0N, 1, 2, 3].map(i => e[i])
  debug_inspect(xs, content="['\\u{00}', '\\u{01}', '\\u{02}', '\\u{03}']")
}

///|
test "enumerate int" {
  let gen : @feat.Enumerate[Int32] = @feat.Enumerable::enumerate()
  let arr = Array::makei(10, i => gen[BigInt::from_int(i)])
  debug_inspect(arr, content="[0, 1, -1, 2, -2, 3, -3, 4, -4, 5]")
}

///|
priv enum SingleTree {
  Leaf(Bool)
  Node(Bool, SingleTree)
} derive(Debug)

///|
impl @feat.Enumerable for SingleTree with fn enumerate() {
  @feat.consts(
    List([
      @feat.Enumerable::enumerate().fmap(x => Leaf(x)),
      @feat.unary((p : (Bool, SingleTree)) => Node(p.0, p.1)),
    ]),
  )
}

///|
priv enum Tree[T] {
  Leaf(T)
  Branch(Forest[T])
} derive(Debug)

///|
priv struct Forest[T] {
  forest : @list.List[Tree[T]]
}

///|
impl[T : Debug] Debug for Forest[T] with fn to_repr(self) {
  @debug.Repr::opaque_(
    "Forest",
    @debug.Repr::array(self.forest.to_array().map(x => Repr(x))),
  )
}

///|
impl[E : @feat.Enumerable] @feat.Enumerable for Forest[E] with fn enumerate() {
  @feat.pay(() => @feat.Enumerable::enumerate().fmap(forest => { forest, }))
}

///|
impl[E : @feat.Enumerable] @feat.Enumerable for Tree[E] with fn enumerate() {
  @feat.pay(() => {
    E::enumerate().fmap(x => Leaf(x)) +
    @feat.Enumerable::enumerate().fmap(x => Branch(x))
  })
}

///|
test "feat tree random" {
  let tg : @coreqc.Generator[Tree[Nat]] = @feat.feat_random(10)
  let trees = tg.samples()
  assert_eq(trees.length(), 10)
  assert_true(trees.iter().any(x => x is Leaf(_)))
  assert_true(trees.iter().any(x => x is Branch(_)))
  for tree in trees {
    assert_true(tree_size(tree) < 10)
  }
  assert_eq(Repr(trees).to_string(), Repr(tg.samples()).to_string())
}

///|
test "feat tree" {
  let fe : @coreqc.Generator[Tree[Nat]] = @feat.feat_random(11)
  assert_true(tree_size(fe.sample()) < 11)
  let x : SingleTree = @feat.Enumerable::enumerate()[200]
  debug_inspect(
    x,
    content=(
      #|Node(
      #|  false,
      #|  Node(
      #|    true,
      #|    Node(true, Node(false, Node(true, Node(false, Leaf(true))))),
      #|  ),
      #|)
    ),
  )
}

///|
test "index large" {
  let eTree : @feat.Enumerate[SingleTree] = @feat.Enumerable::enumerate()
  for i = 100000N; i > 0; i = i - 1 {
    eTree[i] |> ignore
  }
}

///|
fn nat_depth(n : Nat) -> Int32 {
  match n {
    Zero => 0
    Succ(n) => 1 + nat_depth(n)
  }
}

///|
fn tree_size(tree : Tree[Nat]) -> Int32 {
  match tree {
    Leaf(n) => 1 + nat_depth(n)
    Branch(forest) =>
      1 +
      forest.forest.fold(init=1, (size, child) => size + 1 + tree_size(child))
  }
}
