///|
test "one of" {
  inspect(
    @gen.one_of([1, 2, 3, 4].map(@gen.pure)).samples(size=50),
    content="[1, 3, 2, 1, 4, 3, 3, 1, 3, 1, 4, 1, 4, 3, 1, 4, 2, 3, 1, 2, 3, 1, 2, 2, 3, 4, 3, 1, 2, 4, 1, 3, 3, 2, 3, 3, 2, 1, 1, 2, 3, 1, 3, 3, 1, 3, 2, 4, 1, 4]",
  )
}

///|
test "one of array" {
  let result =
    #|["a", "a", "b", "a", "c", "a", "b", "a", "c", "b", "c", "c", "a", "a", "c", "b", "b", "a", "b", "a", "c", "a", "a", "b", "b", "c", "b", "a", "b", "a", "b", "a", "c", "b", "c", "c", "c", "b", "a", "c", "a", "a", "a", "a", "b", "b", "a", "b", "c", "b"]
  inspect(@gen.one_of_array(["a", "b", "c"]).samples(size=50), content=result)
}

///|
test "char range" {
  inspect(
    @gen.char_range('a', 'c').samples(size=20),
    content="['a', 'a', 'b', 'a', 'c', 'a', 'b', 'a', 'c', 'b', 'c', 'c', 'a', 'a', 'c', 'b', 'b', 'a', 'b', 'a']",
  )
}

///|
test "one_of" {
  let gen_bool : @gen.Gen[Bool] = @gen.one_of([
    @gen.pure(true),
    @gen.pure(false),
  ])
  inspect(
    gen_bool.samples(size=10),
    content="[true, true, false, true, false, true, true, true, true, true]",
  )
}

///|
test "frequency" {
  let gen_freq : @gen.Gen[Bool] = @gen.frequency([
    (4, @gen.pure(true)),
    (1, @gen.pure(false)),
  ])
  inspect(
    gen_freq.samples(size=20),
    content="[true, true, true, true, true, true, true, false, true, true, true, true, false, false, true, true, true, true, true, true]",
  )
}

///|
test "backtrack fallback to next generator" {
  let gen : @gen.Gen[Int?] = @gen.backtrack([
    (1, @gen.pure((None : Int?))),
    (1, @gen.pure(Some(42))),
    (1, @gen.pure(Some(100))),
  ])
  inspect(gen.sample(), content="Some(42)")
}

///|
test "backtrack all failed" {
  let gen : @gen.Gen[Int?] = @gen.backtrack([
    (3, @gen.pure((None : Int?))),
    (1, @gen.pure((None : Int?))),
  ])
  inspect(gen.sample(), content="None")
}

///|
test "backtrack empty input" {
  let gen : @gen.Gen[Int?] = @gen.backtrack([])
  inspect(gen.sample(), content="None")
}

///|
test "backtrack ignores zero-weight candidate" {
  let gen : @gen.Gen[Int?] = @gen.backtrack([
    (0, @gen.pure(Some(1))),
    (1, @gen.pure(Some(2))),
  ])
  inspect(gen.sample(), content="Some(2)")
}

///|
test "sized trivial" {
  let gen : @gen.Gen[Int] = @gen.sized(@gen.pure)
  let arr = Array::makei(10, i => gen.sample(size=i))
  inspect(arr, content="[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]")
}

///|
test "nat" {
  inspect(
    @gen.nat().samples(size=50),
    content="[4, -93, 2, 4, 92, 0, 6, 7, -90, 0, -6, -92, 0, 70, 96, -7, 816, 6, 229, 6, 4, -5, -1, -163, -93, -231, -18, 6, -74, 5, 618, 206, -12, -2, 1, 3, 5, 2, 83, -6, 8, -8, -3, -676, -5, -31, -2, -514, -61, -6]",
  )
}

///|
test "small int" {
  inspect(
    @gen.small_int().samples(size=50),
    content="[6, -7, 5, 0, 10, -10, 0, 7, -5, -1, -5, -4, 0, 3, 7, -5, 42, 3, 78, 1, 10, -5, -10, -51, -5, -73, -1, 3, -1, 9, 22, 88, -2, -7, 3, 9, 7, 1, 1, -1, 6, -9, -7, -25, -1, -10, -6, -33, -1, -4]",
  )
}

///|
test "frequency int" {
  inspect(
    @gen.frequency([(4, @gen.pure(42)), (1, @gen.pure(37)), (3, @gen.pure(114))]).samples(
      size=50,
    ),
    content="[42, 114, 114, 42, 42, 114, 42, 37, 42, 42, 42, 42, 42, 42, 42, 114, 114, 114, 42, 42, 42, 37, 114, 42, 42, 114, 42, 42, 42, 114, 37, 114, 42, 114, 114, 42, 114, 37, 37, 114, 42, 42, 114, 114, 37, 114, 114, 114, 42, 114]",
  )
}
