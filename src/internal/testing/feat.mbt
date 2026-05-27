///|
test "feat int" {
  let fe : @gen.Gen[Int] = @feat.feat_random(10)
  debug_inspect(
    fe.samples(size=50),
    content=(
      #|[
      #|  2,
      #|  0,
      #|  -4,
      #|  7,
      #|  -2,
      #|  -8,
      #|  7,
      #|  6,
      #|  -7,
      #|  4,
      #|  9,
      #|  -9,
      #|  0,
      #|  -3,
      #|  -4,
      #|  0,
      #|  6,
      #|  -6,
      #|  1,
      #|  9,
      #|  1,
      #|  9,
      #|  -5,
      #|  7,
      #|  6,
      #|  -8,
      #|  -4,
      #|  4,
      #|  -2,
      #|  3,
      #|  9,
      #|  -2,
      #|  5,
      #|  -1,
      #|  0,
      #|  3,
      #|  2,
      #|  4,
      #|  5,
      #|  9,
      #|  1,
      #|  9,
      #|  -9,
      #|  4,
      #|  1,
      #|  -9,
      #|  4,
      #|  8,
      #|  2,
      #|  -2,
      #|]
    ),
  )
}

///|
test "feat nat" {
  let fe : @gen.Gen[Nat] = @feat.feat_random(21)
  debug_inspect(
    fe.samples(size=20),
    content=(
      #|[
      #|  Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))))),
      #|  Zero,
      #|  Succ(Succ(Succ(Succ(Zero)))),
      #|  Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))))),
      #|  Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))))))))),
      #|  Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(...))))))))))))))),
      #|  Succ(Succ(Zero)),
      #|  Succ(Succ(Zero)),
      #|  Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))),
      #|  Succ(Succ(Succ(Succ(Zero)))),
      #|  Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))),
      #|  Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))),
      #|  Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(...))))))))))))))),
      #|  Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))),
      #|  Succ(Succ(Succ(Zero))),
      #|  Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(...))))))))))))))),
      #|  Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))))))))),
      #|  Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))))))))),
      #|  Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))))),
      #|  Succ(Succ(Succ(Succ(Zero)))),
      #|]
    ),
  )
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
  let e : @feat.Enumerate[Int] = @feat.Enumerable::enumerate()
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
  let gen : @feat.Enumerate[Int] = @feat.Enumerable::enumerate()
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
    @list.from_array([
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
    @debug.Repr::array(self.forest.to_array().map(x => @debug.to_repr(x))),
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
  let tg : @gen.Gen[Tree[Nat]] = @feat.feat_random(10)
  debug_inspect(
    tg.samples(),
    content=(
      #|[
      #|  Leaf(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))),
      #|  Leaf(Succ(Succ(Succ(Succ(Zero))))),
      #|  Branch(<Forest: [Leaf(Succ(Succ(Zero)))]>),
      #|  Leaf(Succ(Succ(Succ(Succ(Succ(Zero)))))),
      #|  Leaf(Succ(Succ(Succ(Zero)))),
      #|  Branch(<Forest: [Branch(<Forest: []>)]>),
      #|  Leaf(Succ(Succ(Zero))),
      #|  Branch(<Forest: [Leaf(Succ(Zero))]>),
      #|  Leaf(Succ(Succ(Succ(Succ(Succ(Zero)))))),
      #|  Branch(<Forest: [Branch(<Forest: []>)]>),
      #|]
    ),
  )
}

///|
test "feat tree" {
  let fe : @gen.Gen[Tree[Nat]] = @feat.feat_random(11)
  debug_inspect(fe.sample(), content="Leaf(Succ(Succ(Succ(Succ(Zero)))))")
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
