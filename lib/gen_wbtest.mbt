test "feat int" {
  let fe : Gen[Int] = feat_random(10)
  inspect!(
    fe.samples(size=50),
    content="[-3, 2, -6, 0, -3, -2, -4, 6, -1, -4, -4, 4, -2, -2, -5, -3, 2, 0, 1, -1, 1, -4, 1, -1, 2, 1, 0, 2, 1, -2, 0, -2, -1, 2, 3, 0, -2, -2, 1, -1, -1, -4, -1, 0, -2, -4, -2, 0, -2, -1]",
  )
}

test "feat nat" {
  let fe : Gen[Nat] = feat_random(20)
  inspect!(
    fe.samples(size=20),
    content="[Succ(Succ(Succ(Zero))), Zero, Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))))))), Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))))))))))), Succ(Succ(Succ(Zero))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))), Succ(Succ(Succ(Succ(Succ(Zero))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero))))))))))))))))), Succ(Zero), Zero, Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))), Zero, Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))), Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))))))), Succ(Zero), Succ(Succ(Zero))]",
  )
}

test "feat tree" {
  let fe : Gen[Tree[Nat]] = feat_random(11)
  inspect!(fe.sample(), content="Leaf(Zero)")
  // feat_bounded((@feat.Enumerable::enumerate() : @feat.Enumerate[List[Nat]]), 1000)
  let x = (@feat.Enumerable::enumerate() : @feat.Enumerate[SingleTree]).en_index(
    10,
  )
  inspect!(
    x,
    content="Node(false, Node(true, Node(false, Node(true, Node(false, Node(false, Node(false, Node(false, Node(true, Node(true, Node(false, Node(false, Node(true, Node(true, Node(true, Node(false, Node(true, Node(true, Node(true, Node(true, Node(true, Node(false, Node(false, Node(false, Node(false, Node(true, Node(false, Node(true, Node(true, Node(false, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(true, Node(false, Node(false, Node(false, Node(true, Node(true, Node(true, Leaf(Succ(Succ(Zero))))))))))))))))))))))))))))))))))))))))))))))",
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
