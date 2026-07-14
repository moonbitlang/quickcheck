///|
/// Wraps an `Array[T]` guaranteed to be non-empty. Shrinks without
/// producing the empty array.
pub(all) struct NonEmptyArray[T](Array[T]) derive(Eq)

///|
pub impl[T : Debug] Debug for NonEmptyArray[T] with fn to_repr(self) {
  @debug.Repr::opaque_(
    "NonEmptyArray",
    @debug.Repr::array(self.0.map(x => @debug.to_repr(x))),
  )
}

///|
pub impl[T : @coreqc.Arbitrary] @coreqc.Arbitrary for NonEmptyArray[T] with fn arbitrary(
  size,
  rs,
) {
  let n = rs.next_positive_int() % (size + 1) + 1
  NonEmptyArray(Array::makei(n, _ => T::arbitrary(size, rs)))
}

///|
pub impl[T : @shrink.Shrink] @shrink.Shrink for NonEmptyArray[T] with fn shrink(
  self,
) {
  @shrink.shrink_non_empty_array(self.0).map(a => NonEmptyArray(a))
}

///|
test "NonEmptyArray[Int] generates non-empty arrays" {
  let gen : @gen.Gen[NonEmptyArray[Int]] = @gen.Gen::spawn()
  let samples = gen.samples(size=20)
  assert_true(samples.all(x => x.0.length() > 0))
}

///|
test "NonEmptyArray[Int] shrinks without producing empty" {
  let s = @shrink.Shrink::shrink(NonEmptyArray([1, 2, 3])).to_array()
  assert_true(s.all(x => x.0.length() > 0))
}

///|
test "NonEmptyArray[Int] debug output keeps wrapper name" {
  debug_inspect(NonEmptyArray([1, 2]), content="<NonEmptyArray: [1, 2]>")
}

///|
/// Wraps a `List[T]` guaranteed to be non-empty. Shrinks without
/// producing the empty list.
pub(all) struct NonEmptyList[T](@list.List[T]) derive(Eq)

///|
pub impl[T : Debug] Debug for NonEmptyList[T] with fn to_repr(self) {
  @debug.Repr::opaque_(
    "NonEmptyList",
    @debug.Repr::array(self.0.to_array().map(x => @debug.to_repr(x))),
  )
}

///|
pub impl[T : @coreqc.Arbitrary] @coreqc.Arbitrary for NonEmptyList[T] with fn arbitrary(
  size,
  rs,
) {
  let n = rs.next_positive_int() % (size + 1) + 1
  NonEmptyList(List(Array::makei(n, _ => T::arbitrary(size, rs))))
}

///|
pub impl[T : @shrink.Shrink] @shrink.Shrink for NonEmptyList[T] with fn shrink(
  self,
) {
  @shrink.shrink_non_empty_list(self.0).map(l => NonEmptyList(l))
}

///|
test "NonEmptyList[Int] generates non-empty lists" {
  let gen : @gen.Gen[NonEmptyList[Int]] = @gen.Gen::spawn()
  let samples = gen.samples(size=20)
  assert_true(samples.all(x => !x.0.is_empty()))
}

///|
test "NonEmptyList[Int] shrinks without producing empty" {
  let s = @shrink.Shrink::shrink(NonEmptyList(List([1, 2, 3]))).to_array()
  assert_true(s.all(x => !x.0.is_empty()))
}

///|
/// Wraps an `Array[T]` guaranteed to be sorted. Generation produces a
/// random array then sorts it; shrinking preserves the sort invariant.
pub(all) struct SortedArray[T](Array[T]) derive(Eq)

///|
pub impl[T : Debug] Debug for SortedArray[T] with fn to_repr(self) {
  @debug.Repr::opaque_(
    "SortedArray",
    @debug.Repr::array(self.0.map(x => @debug.to_repr(x))),
  )
}

///|
pub impl[T : @coreqc.Arbitrary + Compare] @coreqc.Arbitrary for SortedArray[T] with fn arbitrary(
  size,
  rs,
) {
  let arr : Array[T] = @coreqc.Arbitrary::arbitrary(size, rs)
  arr.sort()
  SortedArray(arr)
}

///|
pub impl @shrink.Shrink for SortedArray[Int] with fn shrink(self) {
  @shrink.shrink_sorted_array(self.0, lo=@int.MIN_VALUE, hi=@int.MAX_VALUE).map(a => {
      SortedArray(a)
    },
  )
}

///|
test "SortedArray[Int] generates sorted arrays" {
  let gen : @gen.Gen[SortedArray[Int]] = @gen.Gen::spawn()
  let samples = gen.samples(size=20)
  assert_true(samples.all(x => x.0.is_sorted()))
}

///|
test "SortedArray[Int] shrinks preserving sort" {
  let s = @shrink.Shrink::shrink(SortedArray([1, 3, 5, 7])).to_array()
  assert_true(s.all(x => x.0.is_sorted()))
  assert_true(s.length() > 0)
}

///|
/// Wraps a `List[T]` guaranteed to be sorted.
pub(all) struct SortedList[T](@list.List[T]) derive(Eq)

///|
pub impl[T : Debug] Debug for SortedList[T] with fn to_repr(self) {
  @debug.Repr::opaque_(
    "SortedList",
    @debug.Repr::array(self.0.to_array().map(x => @debug.to_repr(x))),
  )
}

///|
pub impl[T : @coreqc.Arbitrary + Compare] @coreqc.Arbitrary for SortedList[T] with fn arbitrary(
  size,
  rs,
) {
  let arr : Array[T] = @coreqc.Arbitrary::arbitrary(size, rs)
  arr.sort()
  SortedList(List(arr))
}

///|
pub impl @shrink.Shrink for SortedList[Int] with fn shrink(self) {
  @shrink.shrink_sorted_list(self.0, lo=@int.MIN_VALUE, hi=@int.MAX_VALUE).map(l => {
    SortedList(l)
  })
}

///|
test "SortedList[Int] generates sorted lists" {
  let gen : @gen.Gen[SortedList[Int]] = @gen.Gen::spawn()
  let samples = gen.samples(size=20)
  assert_true(samples.all(x => x.0.to_array().is_sorted()))
}

///|
test "SortedList[Int] shrinks preserving sort" {
  let s = @shrink.Shrink::shrink(SortedList(List([1, 3, 5, 7]))).to_array()
  assert_true(s.all(x => x.0.to_array().is_sorted()))
  assert_true(s.length() > 0)
}

///|
test "SortedList[Int] debug output keeps wrapper name" {
  debug_inspect(SortedList(List([1, 2, 3])), content="<SortedList: [1, 2, 3]>")
}
