test "shrink int" {
  let i = Arbitrary::shrink(13200)
  println(i)
}

test "shrink int64" {
  let j = Arbitrary::shrink(1203112112132L)
  println(j)
}