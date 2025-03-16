///|
test "feat int" {
  let fe : @qc.Gen[Int] = @qc.Gen::feat_random(10)
  inspect!(
    fe.samples(size=50),
    content="[-3, 2, 3, -1, 2, -1, -4, 5, 0, 2, -4, 2, -2, -2, -5, 2, -3, 0, 1, 0, 1, -4, -2, -1, 2, -2, -2, -4, 0, 1, 0, 3, 0, 2, 3, 0, -2, -2, 1, -1, -1, -4, -1, 0, -2, -4, 0, 0, -2, -1]",
  )
}

///|
test "feat nat" {
  let fe : @qc.Gen[Nat] = @qc.Gen::feat_random(21)
  inspect!(
    fe.samples(size=20),
    content="[Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))))), Zero, Succ(Succ(Succ(Succ(Zero)))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))))))))))))), Succ(Succ(Zero)), Succ(Succ(Zero)), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))), Succ(Succ(Succ(Succ(Zero)))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))))))))))), Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))), Succ(Succ(Succ(Zero))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))))))))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))))), Succ(Succ(Succ(Succ(Zero))))]",
  )
}

///|
test "feat nat index" {
  let x = [0N, 1, 2, 3, 4, 5, 6].map(fn(x) {
    (@feat.Enumerable::enumerate() : @feat.Enumerate[Nat]).en_index(x)
  })
  inspect!(
    x,
    content="[Zero, Succ(Zero), Succ(Succ(Zero)), Succ(Succ(Succ(Zero))), Succ(Succ(Succ(Succ(Zero)))), Succ(Succ(Succ(Succ(Succ(Zero))))), Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))]",
  )
}

///|
enum SingleTree {
  Leaf(Bool)
  Node(Bool, SingleTree)
} derive(Show)

///|
impl @feat.Enumerable for SingleTree with enumerate() {
  @feat.consts(
    @immut/list.of([
      @feat.Enumerable::enumerate().fmap(SingleTree::Leaf),
      @feat.unary(pair_function(SingleTree::Node)),
    ]),
  )
}

///|
pub fn pair_function[A, B, C](f : (A, B) -> C) -> ((A, B)) -> C {
  fn { (x, y) => f(x, y) }
}

///|
enum Tree[T] {
  Leaf(T)
  Branch(Forest[T])
} derive(Show)

///|
struct Forest[T] {
  forest : @immut/list.T[Tree[T]]
} derive(Show)

///|
impl[E : @feat.Enumerable] @feat.Enumerable for Forest[E] with enumerate() {
  @feat.pay(fn() {
    @feat.Enumerable::enumerate().fmap(fn { forest => { forest, } })
  })
}

///|
impl[E : @feat.Enumerable] @feat.Enumerable for Tree[E] with enumerate() {
  @feat.pay(fn() {
    E::enumerate().fmap(Tree::Leaf) +
    @feat.Enumerable::enumerate().fmap(Tree::Branch)
  })
}

///|
test "feat tree random" {
  let tg : @qc.Gen[Tree[Nat]] = @qc.Gen::feat_random(10)
  inspect!(
    tg.samples(),
    content="[Leaf(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))), Leaf(Succ(Succ(Succ(Succ(Zero))))), Branch({forest: @list.of([Leaf(Succ(Succ(Zero)))])}), Leaf(Succ(Succ(Succ(Succ(Succ(Zero)))))), Leaf(Succ(Succ(Succ(Zero)))), Branch({forest: @list.of([Branch({forest: @list.of([])})])}), Leaf(Succ(Succ(Zero))), Branch({forest: @list.of([Leaf(Succ(Zero))])}), Leaf(Succ(Succ(Succ(Succ(Succ(Zero)))))), Branch({forest: @list.of([Branch({forest: @list.of([])})])})]",
  )
}

///|
test "feat tree" {
  let fe : @qc.Gen[Tree[Nat]] = @qc.Gen::feat_random(11)
  inspect!(fe.sample(), content="Leaf(Succ(Succ(Succ(Succ(Zero)))))")
  let x = (@feat.Enumerable::enumerate() : @feat.Enumerate[SingleTree]).en_index(
    196606, // Magic Number 196607 will cause crash of BigInt 
  )
  inspect!(
    x,
    content="Node(false, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Leaf(true)))))))))))))))))",
  )
}

///|
test "index large" {
  let eTree : @feat.Enumerate[SingleTree] = @feat.Enumerable::enumerate()
  for i = 100000N; i > 0; i = i - 1 {
    eTree.en_index(i) |> ignore
  }
}

///|
test "nat" {
  inspect!(
    @qc.nat().samples(size=50),
    content="[4, -93, 2, 4, 92, 0, 6, 7, -90, 0, -6, -92, 0, 70, 96, -7, 816, 6, 229, 6, 4, -5, -1, -163, -93, -231, -18, 6, -74, 5, 618, 206, -12, -2, 1, 3, 5, 2, 83, -6, 8, -8, -3, -676, -5, -31, -2, -514, -61, -6]",
  )
}

///|
test "small int" {
  inspect!(
    @qc.small_int().samples(size=50),
    content="[6, -7, 5, 0, 10, -10, 0, 7, -5, -1, -5, -4, 0, 3, 7, -5, 42, 3, 78, 1, 10, -5, -10, -51, -5, -73, -1, 3, -1, 9, 22, 88, -2, -7, 3, 9, 7, 1, 1, -1, 6, -9, -7, -25, -1, -10, -6, -33, -1, -4]",
  )
}

///|
test "frequency int" {
  inspect!(
    @qc.frequency([(4, @qc.pure(42)), (1, @qc.pure(37)), (3, @qc.pure(114))]).samples(
      size=50,
    ),
    content="[42, 114, 114, 42, 42, 42, 114, 37, 42, 42, 114, 42, 114, 42, 42, 42, 114, 42, 42, 42, 114, 37, 42, 42, 114, 114, 114, 42, 114, 42, 37, 42, 42, 114, 42, 114, 42, 37, 37, 114, 42, 42, 114, 42, 37, 42, 114, 42, 42, 42]",
  )
}

///|
test "one of" {
  inspect!(
    @qc.one_of([1, 2, 3, 4].map(@qc.pure)).samples(size=50),
    content="[1, 3, 2, 1, 4, 3, 3, 1, 3, 1, 4, 1, 4, 3, 1, 4, 2, 3, 1, 2, 3, 1, 2, 2, 3, 4, 3, 1, 2, 4, 1, 3, 3, 2, 3, 3, 2, 1, 1, 2, 3, 1, 3, 3, 1, 3, 2, 4, 1, 4]",
  )
}

///|
test "one of array" {
  inspect!(
    @qc.one_of_array(["a", "b", "c"]).samples(size=50),
    content=
      #|["a", "a", "b", "a", "c", "a", "b", "a", "c", "b", "c", "c", "a", "a", "c", "b", "b", "a", "b", "a", "c", "a", "a", "b", "b", "c", "b", "a", "b", "a", "b", "a", "c", "b", "c", "c", "c", "b", "a", "c", "a", "a", "a", "a", "b", "b", "a", "b", "c", "b"]
    ,
  )
}

///|
test "char range" {
  inspect!(
    @qc.char_range('a', 'c').samples(size=20),
    content="['a', 'a', 'b', 'a', 'c', 'a', 'b', 'a', 'c', 'b', 'c', 'c', 'a', 'a', 'c', 'b', 'b', 'a', 'b', 'a']",
  )
}

///|
test "one_of" {
  let gen_bool : @qc.Gen[Bool] = @qc.one_of([@qc.pure(true), @qc.pure(false)])
  inspect!(
    gen_bool.samples(size=10),
    content="[true, true, false, true, false, true, true, true, true, true]",
  )
}

///|
test "frequency" {
  let gen_freq : @qc.Gen[Bool] = @qc.frequency([
    (4, @qc.pure(true)),
    (1, @qc.pure(false)),
  ])
  inspect!(
    gen_freq.samples(size=20),
    content="[true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true]",
  )
}

///|
test "sized trivial" {
  let gen : @qc.Gen[Int] = @qc.sized(@qc.pure)
  let arr = Array::makei(10, fn { i => gen.sample(size=i) })
  inspect!(arr, content="[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]")
}
