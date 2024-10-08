test "feat int" {
  let fe : Gen[Int] = feat_random(10)
  inspect!(
    fe.samples(size=50),
    content="[-3, 2, 3, -1, 2, -1, -4, 5, 0, 2, -4, 2, -2, -2, -5, 2, -3, 0, 1, 0, 1, -4, -2, -1, 2, -2, -2, -4, 0, 1, 0, 3, 0, 2, 3, 0, -2, -2, 1, -1, -1, -4, -1, 0, -2, -4, 0, 0, -2, -1]",
  )
}

test "feat nat" {
  let fe : Gen[Nat] = feat_random(21)
  inspect!(
    fe.samples(size=20),
    content="[Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))))), Zero, Succ(Succ(Succ(Succ(Zero)))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))))))))))))), Succ(Succ(Zero)), Succ(Succ(Zero)), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))), Succ(Succ(Succ(Succ(Zero)))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))))))))))), Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))), Succ(Succ(Succ(Zero))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))))))))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))))), Succ(Succ(Succ(Succ(Zero))))]",
  )
}

enum SingleTree {
  Leaf(Bool)
  Node(Bool, SingleTree)
} derive(Show)

impl @feat.Enumerable for SingleTree with enumerate() {
  @feat.consts(
    @immut/list.of(
      [
        @feat.Enumerable::enumerate().fmap(SingleTree::Leaf),
        @feat.unary(@utils.pair_function(SingleTree::Node)),
      ],
    ),
  )
}

enum Tree[T] {
  Leaf(T)
  Branch(Forest[T])
} derive(Show)

struct Forest[T] {
  forest : @immut/list.T[Tree[T]]
} derive(Show)

impl[E : @feat.Enumerable] @feat.Enumerable for Forest[E] with enumerate() {
  @feat.pay(
    fn() { @feat.Enumerable::enumerate().fmap(fn { forest => { forest, } }) },
  )
}

impl[E : @feat.Enumerable] @feat.Enumerable for Tree[E] with enumerate() {
  @feat.pay(
    fn() {
      E::enumerate().fmap(Tree::Leaf) +
      @feat.Enumerable::enumerate().fmap(Tree::Branch)
    },
  )
}

test "feat tree random" {
  let tg : Gen[Tree[Nat]] = Gen::feat_random(10)
  inspect!(
    tg.samples(),
    content="[Leaf(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))), Leaf(Succ(Succ(Succ(Succ(Zero))))), Branch({forest: @list.of([Leaf(Succ(Succ(Zero)))])}), Leaf(Succ(Succ(Succ(Succ(Succ(Zero)))))), Leaf(Succ(Succ(Succ(Zero)))), Branch({forest: @list.of([Branch({forest: @list.of([])})])}), Leaf(Succ(Succ(Zero))), Branch({forest: @list.of([Leaf(Succ(Zero))])}), Leaf(Succ(Succ(Succ(Succ(Succ(Zero)))))), Branch({forest: @list.of([Branch({forest: @list.of([])})])})]",
  )
}

test "feat tree" {
  let fe : Gen[Tree[Nat]] = feat_random(11)
  inspect!(fe.sample(), content="Leaf(Succ(Succ(Succ(Succ(Zero)))))")
  let x = (@feat.Enumerable::enumerate() : @feat.Enumerate[SingleTree]).en_index(
    196606, // Magic Number 196607 will cause crash of BigInt 
  )
  inspect!(
    x,
    content="Node(false, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Leaf(true)))))))))))))))))",
  )
}

test "nat" {
  inspect!(
    nat().samples(size=50),
    content="[4, -93, 2, 4, 92, 0, 6, 7, -90, 0, -6, -92, 0, 70, 96, -7, 816, 6, 229, 6, 4, -5, -1, -163, -93, -231, -18, 6, -74, 5, 618, 206, -12, -2, 1, 3, 5, 2, 83, -6, 8, -8, -3, -676, -5, -31, -2, -514, -61, -6]",
  )
}

test "small int" {
  inspect!(
    small_int().samples(size=50),
    content="[6, -7, 5, 0, 10, -10, 0, 7, -5, -1, -5, -4, 0, 3, 7, -5, 42, 3, 78, 1, 10, -5, -10, -51, -5, -73, -1, 3, -1, 9, 22, 88, -2, -7, 3, 9, 7, 1, 1, -1, 6, -9, -7, -25, -1, -10, -6, -33, -1, -4]",
  )
}

test "frequency int" {
  inspect!(
    frequency([(4, pure(42)), (1, pure(37)), (3, pure(114))]).samples(size=50),
    content="[42, 114, 114, 42, 42, 42, 114, 37, 42, 42, 114, 42, 114, 42, 42, 42, 114, 42, 42, 42, 114, 37, 42, 42, 114, 114, 114, 42, 114, 42, 37, 42, 42, 114, 42, 114, 42, 37, 37, 114, 42, 42, 114, 42, 37, 42, 114, 42, 42, 42]",
  )
}

test "one of" {
  inspect!(
    one_of([pure(1), pure(2), pure(3), pure(4)]).samples(size=50),
    content="[1, 3, 2, 1, 4, 3, 3, 1, 3, 1, 4, 1, 4, 3, 1, 4, 2, 3, 1, 2, 3, 1, 2, 2, 3, 4, 3, 1, 2, 4, 1, 3, 3, 2, 3, 3, 2, 1, 1, 2, 3, 1, 3, 3, 1, 3, 2, 4, 1, 4]",
  )
}

test "one of array" {
  inspect!(
    one_of_array(["a", "b", "c"]).samples(size=50),
    content=
      #|["a", "a", "b", "a", "c", "a", "b", "a", "c", "b", "c", "c", "a", "a", "c", "b", "b", "a", "b", "a", "c", "a", "a", "b", "b", "c", "b", "a", "b", "a", "b", "a", "c", "b", "c", "c", "c", "b", "a", "c", "a", "a", "a", "a", "b", "b", "a", "b", "c", "b"]
    ,
  )
}

test "char range" {
  inspect!(
    char_range('a', 'c').samples(size=20),
    content="['a', 'a', 'b', 'a', 'c', 'a', 'b', 'a', 'c', 'b', 'c', 'c', 'a', 'a', 'c', 'b', 'b', 'a', 'b', 'a']",
  )
}

test "one_of" {
  let gen_bool : Gen[Bool] = one_of([pure(true), pure(false)])
  inspect!(
    gen_bool.samples(size=10),
    content="[true, true, false, true, false, true, true, true, true, true]",
  )
}

test "frequency" {
  let gen_freq : Gen[Bool] = frequency([(4, pure(true)), (1, pure(false))])
  inspect!(
    gen_freq.samples(size=20),
    content="[true, true, true, true, true, true, true, true, true, true, true, true, true, false, true, true, true, true, true, true]",
  )
}

test "sized trivial" {
  let gen : Gen[Int] = sized(fn { size => pure(size) })
  let arr = Array::makei(10, fn { i => gen.sample(size=i) })
  inspect!(arr, content="[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]")
}
