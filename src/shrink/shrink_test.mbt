///|
test "shrink int" {
  json_inspect(@shrink.Shrink::shrink(100), content=[99, 97, 94, 88, 75, 50, 0])
  json_inspect(@shrink.Shrink::shrink(0), content=[])
}

///|
test "shrink int64" {
  json_inspect(@shrink.Shrink::shrink(10000L), content=[
    "9999", "9998", "9996", "9991", "9981", "9961", "9922", "9844", "9688", "9375",
    "8750", "7500", "5000", "0",
  ])
}

///|
test "shrink uint" {
  json_inspect(@shrink.Shrink::shrink(37000U), content=[
    36999, 36998, 36996, 36991, 36982, 36964, 36928, 36856, 36711, 36422, 35844,
    34688, 32375, 27750, 18500, 0,
  ])
}

///|
test "shrink uint64" {
  json_inspect(@shrink.Shrink::shrink((42000 : UInt64)), content=[
    "41999", "41998", "41995", "41990", "41980", "41959", "41918", "41836", "41672",
    "41344", "40688", "39375", "36750", "31500", "21000", "0",
  ])
}

///|
test "shrink boolean" {
  json_inspect(@shrink.Shrink::shrink(true), content=[false])
  json_inspect(@shrink.Shrink::shrink(false), content=[])
}

///|
test "shrink char" {
  json_inspect(@shrink.Shrink::shrink('测'), content=[
    "浊", "浌", "a", "A", "1", "\n", "\t", "\b", "\\", "'", "\r", " ",
  ])
}

///|
test "shrink double: pi" {
  let s = @shrink.Shrink::shrink(3.14159).to_array()
  assert_true(s.contains(3.0))
  assert_true(s.contains(0.0))
  assert_true(s.all(y => y < 3.14159))
}

///|
test "shrink double: exact output for 3.5" {
  json_inspect(@shrink.Shrink::shrink(3.5), content=[
    3, 2, 0, 3.4, 3.3, 3.1, 2.7, 1.8, 0,
  ])
}

///|
test "shrink double: zero" {
  assert_eq(@shrink.Shrink::shrink(0.0).to_array(), [])
}

///|
test "shrink double: negative" {
  let s = @shrink.Shrink::shrink(-5.5).to_array()
  assert_true(s.contains(5.5))
  assert_true(s.any(y => y < 0.0))
}

///|
test "shrink double: nan" {
  let s = @shrink.Shrink::shrink(0.0 / 0.0).to_array()
  assert_true(s.contains(0.0))
}

///|
test "shrink double: infinity" {
  let s = @shrink.Shrink::shrink(1.0 / 0.0).to_array()
  assert_true(s.contains(0.0))
  assert_true(s.contains(1000.0))
}

///|
test "shrink double: small value" {
  let s = @shrink.Shrink::shrink(0.001).to_array()
  assert_true(s.contains(0.0))
  assert_true(s.all(y => y >= 0.0 && y < 0.001))
}

///|
test "shrink float: basic" {
  let s = @shrink.Shrink::shrink((3.14 : Float)).to_array()
  assert_true(s.contains(3.0))
  assert_true(s.contains(0.0))
}

///|
test "shrink option" {
  json_inspect(@shrink.Shrink::shrink((None : Unit?)), content=[])
  json_inspect(@shrink.Shrink::shrink(Some(1000)), content=[
    [999],
    [997],
    [993],
    [985],
    [969],
    [938],
    [875],
    [750],
    [500],
    [0],
    null,
  ])
}

///|
test "shrink result" {
  let b : Result[Bool, Int] = Err(100)
  let x : Result[Bool, Int] = Ok(true)
  json_inspect(@shrink.Shrink::shrink(b), content=[
    { "Err": 99 },
    { "Err": 97 },
    { "Err": 94 },
    { "Err": 88 },
    { "Err": 75 },
    { "Err": 50 },
    { "Err": 0 },
  ])
  json_inspect(@shrink.Shrink::shrink(x), content=[{ "Ok": false }])
}

///|
test "shrink tuple" {
  let x = (120, true)
  json_inspect(@shrink.Shrink::shrink(x), content=[
    [119, true],
    [117, true],
    [113, true],
    [105, true],
    [90, true],
    [60, true],
    [0, true],
    [120, false],
  ])
}

///|
test "shrink 6-tuple" {
  let x = (20, 'A', 30U, true, true, true)
  json_inspect(@shrink.Shrink::shrink(x), content=[
    [19, "A", 30, true, true, true],
    [18, "A", 30, true, true, true],
    [15, "A", 30, true, true, true],
    [10, "A", 30, true, true, true],
    [0, "A", 30, true, true, true],
    [20, "@", 30, true, true, true],
    [20, "B", 30, true, true, true],
    [20, "a", 30, true, true, true],
    [20, "A", 30, true, true, true],
    [20, "1", 30, true, true, true],
    [20, "\n", 30, true, true, true],
    [20, "\t", 30, true, true, true],
    [20, "\b", 30, true, true, true],
    [20, "\\", 30, true, true, true],
    [20, "'", 30, true, true, true],
    [20, "\r", 30, true, true, true],
    [20, " ", 30, true, true, true],
    [20, "A", 29, true, true, true],
    [20, "A", 27, true, true, true],
    [20, "A", 23, true, true, true],
    [20, "A", 15, true, true, true],
    [20, "A", 0, true, true, true],
    [20, "A", 30, false, true, true],
    [20, "A", 30, true, false, true],
    [20, "A", 30, true, true, false],
  ])
}

///|
test "shrink int list" {
  let il : @list.List[Int] = @list.from_array([1, 2, 3, 4, 5, 6])
  let s = @shrink.Shrink::shrink(il)
  json_inspect(s, content=[
    [2, 3, 4, 5, 6],
    [1, 3, 4, 5, 6],
    [1, 2, 4, 5, 6],
    [1, 2, 3, 5, 6],
    [1, 2, 3, 4, 6],
    [4, 5, 6],
    [0, 2, 3, 4, 5, 6],
    [1, 1, 3, 4, 5, 6],
    [1, 0, 3, 4, 5, 6],
    [1, 2, 2, 4, 5, 6],
    [1, 2, 0, 4, 5, 6],
    [1, 2, 3, 3, 5, 6],
    [1, 2, 3, 2, 5, 6],
    [1, 2, 3, 0, 5, 6],
    [1, 2, 3, 4, 4, 6],
    [1, 2, 3, 4, 3, 6],
    [1, 2, 3, 4, 0, 6],
    [1, 2, 3, 4, 5, 5],
    [1, 2, 3, 4, 5, 3],
    [1, 2, 3, 4, 5, 0],
  ])
}

///|
test "shrink non-empty list" {
  let il : @list.List[Int] = @list.from_array([1])
  json_inspect(@shrink.shrink_non_empty_list(il), content=[[0]])
}

///|
test "shrink array" {
  let ar = [1, 2, 3, 4, 5, 6]
  let s = @shrink.Shrink::shrink(ar)
  json_inspect(s, content=[
    [2, 3, 4, 5, 6],
    [1, 3, 4, 5, 6],
    [1, 2, 4, 5, 6],
    [1, 2, 3, 5, 6],
    [1, 2, 3, 4, 6],
    [4, 5, 6],
    [0, 2, 3, 4, 5, 6],
    [1, 1, 3, 4, 5, 6],
    [1, 0, 3, 4, 5, 6],
    [1, 2, 2, 4, 5, 6],
    [1, 2, 0, 4, 5, 6],
    [1, 2, 3, 3, 5, 6],
    [1, 2, 3, 2, 5, 6],
    [1, 2, 3, 0, 5, 6],
    [1, 2, 3, 4, 4, 6],
    [1, 2, 3, 4, 3, 6],
    [1, 2, 3, 4, 0, 6],
    [1, 2, 3, 4, 5, 5],
    [1, 2, 3, 4, 5, 3],
    [1, 2, 3, 4, 5, 0],
  ])
}

///|
test "shrink non-empty array" {
  json_inspect(@shrink.shrink_non_empty_array([1]), content=[[0]])
}

///|
test "shrink iter" {
  let it = [1, 2, 3, 4, 5, 6].iter()
  json_inspect(@shrink.Shrink::shrink(it), content=[
    [2, 3, 4, 5, 6],
    [1, 3, 4, 5, 6],
    [1, 2, 4, 5, 6],
    [1, 2, 3, 5, 6],
    [1, 2, 3, 4, 6],
    [1, 2, 3, 4, 5],
    [0, 2, 3, 4, 5, 6],
    [1, 1, 3, 4, 5, 6],
    [1, 0, 3, 4, 5, 6],
    [1, 2, 2, 4, 5, 6],
    [1, 2, 0, 4, 5, 6],
    [1, 2, 3, 3, 5, 6],
    [1, 2, 3, 2, 5, 6],
    [1, 2, 3, 0, 5, 6],
    [1, 2, 3, 4, 4, 6],
    [1, 2, 3, 4, 3, 6],
    [1, 2, 3, 4, 0, 6],
    [1, 2, 3, 4, 5, 5],
    [1, 2, 3, 4, 5, 3],
    [1, 2, 3, 4, 5, 0],
  ])
}

///|
test "shrink sorted array" {
  let ar = [1, 3, 5, 7, 9]
  let s = @shrink.shrink_sorted_array(ar, lo=0, hi=10)
  let content = s.to_array()
  json_inspect(content, content=[
    [3, 5, 7, 9],
    [1, 5, 7, 9],
    [1, 3, 7, 9],
    [1, 3, 5, 9],
    [1, 3, 5, 7],
    [0, 3, 5, 7, 9],
    [1, 2, 5, 7, 9],
    [1, 3, 4, 7, 9],
    [1, 3, 3, 7, 9],
    [1, 3, 5, 6, 9],
    [1, 3, 5, 7, 8],
    [1, 3, 5, 7, 7],
  ])
}

///|
test "shrink distinct array" {
  let s = @shrink.shrink_distinct_array([1, 3, 5])
  json_inspect(s, content=[
    [3, 5],
    [1, 5],
    [1, 3],
    [0, 3, 5],
    [1, 2, 5],
    [1, 0, 5],
    [1, 3, 4],
    [1, 3, 0],
  ])
}

///|
test "shrink sorted distinct array" {
  let s = @shrink.shrink_sorted_distinct_array([1, 3, 5], lo=0, hi=9)
  json_inspect(s, content=[
    [3, 5],
    [1, 5],
    [1, 3],
    [0, 3, 5],
    [1, 2, 5],
    [1, 3, 4],
  ])
}

///|
test "shrink sorted list" {
  let xs : @list.List[Int] = @list.from_array([1, 3, 5])
  json_inspect(@shrink.shrink_sorted_list(xs, lo=0, hi=9), content=[
    [3, 5],
    [1, 5],
    [1, 3],
    [0, 3, 5],
    [1, 2, 5],
    [1, 3, 4],
    [1, 3, 3],
  ])
}
