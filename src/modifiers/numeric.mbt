///|
/// Wraps a value guaranteed to be `>= 0`. Generation is biased toward
/// small values; shrinking stays non-negative.
pub(all) struct NonNegative[T](T) derive(Eq)

///|
pub extend NonNegative with Eq::{not_equal, equal}

///|
pub impl[T : Debug] Debug for NonNegative[T] with fn to_repr(self) {
  @debug.Repr::opaque_("NonNegative", Repr(self.0))
}

///|
pub extend NonNegative with Debug::{to_repr}

///|
pub impl @coreqc.Arbitrary for NonNegative[Int] with fn arbitrary(size, rs) {
  let p = rs.next_double()
  let v = if p < 0.5 {
    rs.next_positive_int() % 10
  } else if p < 0.75 {
    rs.next_positive_int() % 100
  } else if p < 0.95 {
    rs.next_positive_int() % 1000
  } else {
    rs.next_positive_int() % (size + 1)
  }
  NonNegative(v)
}

///|
pub extend NonNegative with @coreqc.Arbitrary::{arbitrary}

///|
pub impl @shrink.Shrink for NonNegative[Int] with fn shrink(self) {
  @shrink.Shrink::shrink(self.0).filter(v => v >= 0).map(v => NonNegative(v))
}

///|
pub extend NonNegative with @shrink.Shrink::{shrink}

///|
test "NonNegative[Int] generates non-negative values" {
  let gen : @coreqc.Generator[NonNegative[Int]] = arbitrary_generator()
  let samples = gen.samples(size=50)
  assert_true(samples.all(x => x.0 >= 0))
}

///|
test "NonNegative[Int] shrinks within bounds" {
  let s = @shrink.Shrink::shrink(NonNegative(100)).to_array()
  assert_true(s.all(x => x.0 >= 0))
  assert_true(s.contains(NonNegative(0)))
}

///|
test "NonNegative[Int] debug output keeps wrapper name" {
  debug_inspect(NonNegative(42), content="<NonNegative: 42>")
}

///|
/// Wraps a value guaranteed to be `> 0`. Shrinks toward 1.
pub(all) struct Positive[T](T) derive(Eq)

///|
pub extend Positive with Eq::{not_equal, equal}

///|
pub impl[T : Debug] Debug for Positive[T] with fn to_repr(self) {
  @debug.Repr::opaque_("Positive", Repr(self.0))
}

///|
pub extend Positive with Debug::{to_repr}

///|
pub impl @coreqc.Arbitrary for Positive[Int] with fn arbitrary(size, rs) {
  let p = rs.next_double()
  let v = if p < 0.5 {
    rs.next_positive_int() % 10
  } else if p < 0.75 {
    rs.next_positive_int() % 100
  } else if p < 0.95 {
    rs.next_positive_int() % 1000
  } else {
    rs.next_positive_int() % (size + 1)
  }
  Positive(v + 1)
}

///|
pub extend Positive with @coreqc.Arbitrary::{arbitrary}

///|
pub impl @shrink.Shrink for Positive[Int] with fn shrink(self) {
  @shrink.Shrink::shrink(self.0).filter(v => v > 0).map(v => Positive(v))
}

///|
pub extend Positive with @shrink.Shrink::{shrink}

///|
test "Positive[Int] generates positive values" {
  let gen : @coreqc.Generator[Positive[Int]] = arbitrary_generator()
  let samples = gen.samples(size=50)
  assert_true(samples.all(x => x.0 > 0))
}

///|
test "Positive[Int] shrinks within bounds" {
  let s = @shrink.Shrink::shrink(Positive(100)).to_array()
  assert_true(s.all(x => x.0 > 0))
  assert_true(s.length() > 0)
  let s2 = @shrink.Shrink::shrink(Positive(2)).to_array()
  assert_true(s2.contains(Positive(1)))
}

///|
/// Wraps a value guaranteed to be `< 0`. Shrinks toward -1.
pub(all) struct Negative[T](T) derive(Eq)

///|
pub extend Negative with Eq::{not_equal, equal}

///|
pub impl[T : Debug] Debug for Negative[T] with fn to_repr(self) {
  @debug.Repr::opaque_("Negative", Repr(self.0))
}

///|
pub extend Negative with Debug::{to_repr}

///|
pub impl @coreqc.Arbitrary for Negative[Int] with fn arbitrary(size, rs) {
  let p = rs.next_double()
  let v = if p < 0.5 {
    rs.next_positive_int() % 10
  } else if p < 0.75 {
    rs.next_positive_int() % 100
  } else if p < 0.95 {
    rs.next_positive_int() % 1000
  } else {
    rs.next_positive_int() % (size + 1)
  }
  Negative(-(v + 1))
}

///|
pub extend Negative with @coreqc.Arbitrary::{arbitrary}

///|
pub impl @shrink.Shrink for Negative[Int] with fn shrink(self) {
  @shrink.Shrink::shrink(self.0).filter(v => v < 0).map(v => Negative(v))
}

///|
pub extend Negative with @shrink.Shrink::{shrink}

///|
test "Negative[Int] generates negative values" {
  let gen : @coreqc.Generator[Negative[Int]] = arbitrary_generator()
  let samples = gen.samples(size=50)
  assert_true(samples.all(x => x.0 < 0))
}

///|
test "Negative[Int] shrinks within bounds" {
  let s = @shrink.Shrink::shrink(Negative(-100)).to_array()
  assert_true(s.all(x => x.0 < 0))
  assert_true(s.length() > 0)
  let s2 = @shrink.Shrink::shrink(Negative(-2)).to_array()
  assert_true(s2.contains(Negative(-1)))
}

///|
/// Wraps a value guaranteed to be non-zero. Generation is biased toward
/// small absolute values; shrinking never produces zero.
pub(all) struct NonZero[T](T) derive(Eq)

///|
pub extend NonZero with Eq::{not_equal, equal}

///|
pub impl[T : Debug] Debug for NonZero[T] with fn to_repr(self) {
  @debug.Repr::opaque_("NonZero", Repr(self.0))
}

///|
pub extend NonZero with Debug::{to_repr}

///|
pub impl @coreqc.Arbitrary for NonZero[Int] with fn arbitrary(size, rs) {
  let bound = if size <= 0 { 1 } else { size }
  let magnitude = rs.next_positive_int() % bound + 1
  let value = if rs.next_double() < 0.5 { magnitude } else { -magnitude }
  NonZero(value)
}

///|
pub extend NonZero with @coreqc.Arbitrary::{arbitrary}

///|
pub impl @shrink.Shrink for NonZero[Int] with fn shrink(self) {
  @shrink.Shrink::shrink(self.0).filter_map(v => {
    if v != 0 {
      Some(NonZero(v))
    } else {
      None
    }
  })
}

///|
pub extend NonZero with @shrink.Shrink::{shrink}

///|
test "NonZero[Int] generates non-zero values" {
  let gen : @coreqc.Generator[NonZero[Int]] = arbitrary_generator()
  let samples = gen.samples(size=50)
  assert_true(samples.all(x => x.0 != 0))
}

///|
test "NonZero[Int] shrinks within bounds" {
  let s = @shrink.Shrink::shrink(NonZero(100)).to_array()
  assert_true(s.all(x => x.0 != 0))
  assert_true(s.length() > 0)
  let s2 = @shrink.Shrink::shrink(NonZero(2)).to_array()
  assert_true(s2.contains(NonZero(1)))
  let s3 = @shrink.Shrink::shrink(NonZero(-2)).to_array()
  assert_true(s3.contains(NonZero(-1)))
}

///|
/// Wraps a value generated with a distribution biased toward small
/// absolute values. Shrinks normally.
pub(all) struct Small[T](T) derive(Eq)

///|
pub extend Small with Eq::{not_equal, equal}

///|
pub impl[T : Debug] Debug for Small[T] with fn to_repr(self) {
  @debug.Repr::opaque_("Small", Repr(self.0))
}

///|
pub extend Small with Debug::{to_repr}

///|
pub impl @coreqc.Arbitrary for Small[Int] with fn arbitrary(_size, rs) {
  let p = rs.next_double()
  let mag = if p < 0.75 {
    rs.next_positive_int() % 11
  } else {
    rs.next_positive_int() % 97
  }
  let sign = if rs.next_double() < 0.5 { 1 } else { -1 }
  Small(mag * sign)
}

///|
pub extend Small with @coreqc.Arbitrary::{arbitrary}

///|
pub impl @shrink.Shrink for Small[Int] with fn shrink(self) {
  @shrink.Shrink::shrink(self.0).map(v => Small(v))
}

///|
pub extend Small with @shrink.Shrink::{shrink}

///|
test "Small[Int] generates values" {
  let gen : @coreqc.Generator[Small[Int]] = arbitrary_generator()
  let samples = gen.samples(size=50)
  assert_true(samples.length() > 0)
}

///|
test "Small[Int] debug output keeps wrapper name" {
  debug_inspect(Small(-3), content="<Small: -3>")
}
