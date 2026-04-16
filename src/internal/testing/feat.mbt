///|
test "feat int" {
  let fe : @qc.Gen[Int] = @qc.Gen::feat_random(10)
  inspect(
    fe.samples(size=50),
    content="[0, 0, -2, 5, -2, -4, -1, -1, 4, -2, 4, -4, -3, -3, 2, 4, 2, -2, 5, -2, -4, 0, -4, -3, -4, -4, -1, -2, -4, -2, -2, 5, 5, -4, -1, -3, -3, 4, 2, -2, -3, 0, -2, 4, -3, 5, 5, 3, 5, 4]",
  )
}

///|
test "feat nat" {
  let fe : @qc.Gen[Nat] = @qc.Gen::feat_random(21)
  inspect(
    fe.samples(size=20),
    content="[Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))))), Zero, Succ(Succ(Succ(Succ(Zero)))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))))))))))))), Succ(Succ(Zero)), Succ(Succ(Zero)), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))), Succ(Succ(Succ(Succ(Zero)))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))))))))))), Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))), Succ(Succ(Succ(Zero))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))))))))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))))), Succ(Succ(Succ(Succ(Zero))))]",
  )
}

///|
test "feat nat index" {
  let x = [0N, 1, 2, 3, 4, 5, 6].map(x => {
    (@feat.Enumerable::enumerate() : @feat.Enumerate[Nat])[x]
  })
  inspect(
    x,
    content="[Zero, Succ(Zero), Succ(Succ(Zero)), Succ(Succ(Succ(Zero))), Succ(Succ(Succ(Succ(Zero)))), Succ(Succ(Succ(Succ(Succ(Zero))))), Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))]",
  )
}

///|
test "feat int index order" {
  let e : @feat.Enumerate[Int] = @feat.Enumerable::enumerate()
  let xs = [0N, 1, 2, 3, 4, 5].map(i => e[i])
  inspect(xs, content="[0, 1, -1, 2, -2, 3]")
}

///|
test "feat byte index order" {
  let e : @feat.Enumerate[Byte] = @feat.Enumerable::enumerate()
  let xs = [0N, 1, 2, 3].map(i => e[i])
  inspect(xs, content="[b'\\x00', b'\\x01', b'\\x02', b'\\x03']")
}

///|
test "feat char index order" {
  let e : @feat.Enumerate[Char] = @feat.Enumerable::enumerate()
  let xs = [0N, 1, 2, 3].map(i => e[i])
  inspect(xs, content="['\\u{00}', '\\u{01}', '\\u{02}', '\\u{03}']")
}

///|
test "enumerate int" {
  let gen : @feat.Enumerate[Int] = @feat.Enumerable::enumerate()
  let arr = Array::makei(10, i => gen[BigInt::from_int(i)])
  inspect(arr, content="[0, 1, -1, 2, -2, 3, -3, 4, -4, 5]")
}

///|
priv enum SingleTree {
  Leaf(Bool)
  Node(Bool, SingleTree)
}

///|
impl Show for SingleTree with output(self, logger) {
  match self {
    Leaf(b) => {
      logger.write_string("Leaf(")
      b.output(logger)
      logger.write_string(")")
    }
    Node(b, t) => {
      logger.write_string("Node(")
      b.output(logger)
      logger.write_string(", ")
      t.output(logger)
      logger.write_string(")")
    }
  }
}

///|
impl @feat.Enumerable for SingleTree with enumerate() {
  @feat.consts(
    @list.from_array([
      @feat.Enumerable::enumerate().fmap(x => Leaf(x)),
      @feat.unary(pair_function((x, y) => Node(x, y))),
    ]),
  )
}

///|
fn[A, B, C] pair_function(f : (A, B) -> C) -> ((A, B)) -> C {
  fn(x : (A, B)) -> C { f(x.0, x.1) }
}

///|
priv enum Tree[T] {
  Leaf(T)
  Branch(Forest[T])
}

///|
priv struct Forest[T] {
  forest : List[Tree[T]]
}

///|
impl[T : Show] Show for Tree[T] with output(self, logger) {
  match self {
    Leaf(x) => {
      logger.write_string("Leaf(")
      x.output(logger)
      logger.write_string(")")
    }
    Branch(f) => {
      logger.write_string("Branch(")
      f.output(logger)
      logger.write_string(")")
    }
  }
}

///|
impl[T : Show] Show for Forest[T] with output(self, logger) {
  logger.write_string("{forest: ")
  self.forest.output(logger)
  logger.write_string("}")
}

///|
impl[E : @feat.Enumerable] @feat.Enumerable for Forest[E] with enumerate() {
  @feat.pay(() => @feat.Enumerable::enumerate().fmap(forest => { forest, }))
}

///|
impl[E : @feat.Enumerable] @feat.Enumerable for Tree[E] with enumerate() {
  @feat.pay(() => {
    E::enumerate().fmap(x => Leaf(x)) +
    @feat.Enumerable::enumerate().fmap(x => Branch(x))
  })
}

///|
test "feat tree random" {
  let tg : @qc.Gen[Tree[Nat]] = @qc.Gen::feat_random(10)
  inspect(
    tg.samples(),
    content="[Leaf(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))), Leaf(Succ(Succ(Succ(Succ(Zero))))), Branch({forest: @list.from_array([Leaf(Succ(Succ(Zero)))])}), Leaf(Succ(Succ(Succ(Succ(Succ(Zero)))))), Leaf(Succ(Succ(Succ(Zero)))), Branch({forest: @list.from_array([Branch({forest: @list.from_array([])})])}), Leaf(Succ(Succ(Zero))), Branch({forest: @list.from_array([Leaf(Succ(Zero))])}), Leaf(Succ(Succ(Succ(Succ(Succ(Zero)))))), Branch({forest: @list.from_array([Branch({forest: @list.from_array([])})])})]",
  )
}

///|
test "feat tree" {
  let fe : @qc.Gen[Tree[Nat]] = @qc.Gen::feat_random(11)
  inspect(fe.sample(), content="Leaf(Succ(Succ(Succ(Succ(Zero)))))")
  let x : SingleTree = @feat.Enumerable::enumerate()[196606]
  inspect(
    x,
    content="Node(false, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Leaf(true)))))))))))))))))",
  )
}

///|
test "index large" {
  let eTree : @feat.Enumerate[SingleTree] = @feat.Enumerable::enumerate()
  for i = 100000N; i > 0; i = i - 1 {
    eTree[i] |> ignore
  }
}
