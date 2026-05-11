///|
/// Wraps a value guaranteed to be `>= 0`. Generation is biased toward
/// small values; shrinking stays non-negative.
pub(all) struct NonNegative[T](T) derive(Eq)

///|
pub impl[T : Debug] Debug for NonNegative[T] with to_repr(self) {
  @debug.Repr::opaque_("NonNegative", @debug.to_repr(self.0))
}

///|
pub impl @coreqc.Arbitrary for NonNegative[Int] with arbitrary(size, rs) {
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
pub impl @shrink.Shrink for NonNegative[Int] with shrink(self) {
  @shrink.Shrink::shrink(self.0).filter(v => v >= 0).map(v => NonNegative(v))
}

///|
test "NonNegative[Int] generates non-negative values" {
  let gen : @gen.Gen[NonNegative[Int]] = @gen.Gen::spawn()
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
pub impl[T : Debug] Debug for Positive[T] with to_repr(self) {
  @debug.Repr::opaque_("Positive", @debug.to_repr(self.0))
}

///|
pub impl @coreqc.Arbitrary for Positive[Int] with arbitrary(size, rs) {
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
pub impl @shrink.Shrink for Positive[Int] with shrink(self) {
  @shrink.Shrink::shrink(self.0).filter(v => v > 0).map(v => Positive(v))
}

///|
test "Positive[Int] generates positive values" {
  let gen : @gen.Gen[Positive[Int]] = @gen.Gen::spawn()
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
pub impl[T : Debug] Debug for Negative[T] with to_repr(self) {
  @debug.Repr::opaque_("Negative", @debug.to_repr(self.0))
}

///|
pub impl @coreqc.Arbitrary for Negative[Int] with arbitrary(size, rs) {
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
pub impl @shrink.Shrink for Negative[Int] with shrink(self) {
  @shrink.Shrink::shrink(self.0).filter(v => v < 0).map(v => Negative(v))
}

///|
test "Negative[Int] generates negative values" {
  let gen : @gen.Gen[Negative[Int]] = @gen.Gen::spawn()
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
pub impl[T : Debug] Debug for NonZero[T] with to_repr(self) {
  @debug.Repr::opaque_("NonZero", @debug.to_repr(self.0))
}

///|
pub impl @coreqc.Arbitrary for NonZero[Int] with arbitrary(size, rs) {
  let gen : @gen.Gen[Int] = @gen.Gen::spawn()
  gen.such_that(v => v != 0).run(size, rs)
}

///|
pub impl @shrink.Shrink for NonZero[Int] with shrink(self) {
  @shrink.Shrink::shrink(self.0).filter_map(v => {
    if v != 0 {
      Some(NonZero(v))
    } else {
      None
    }
  })
}

///|
test "NonZero[Int] generates non-zero values" {
  let gen : @gen.Gen[NonZero[Int]] = @gen.Gen::spawn()
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
pub impl[T : Debug] Debug for Small[T] with to_repr(self) {
  @debug.Repr::opaque_("Small", @debug.to_repr(self.0))
}

///|
pub impl @coreqc.Arbitrary for Small[Int] with arbitrary(_size, rs) {
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
pub impl @shrink.Shrink for Small[Int] with shrink(self) {
  @shrink.Shrink::shrink(self.0).map(v => Small(v))
}

///|
test "Small[Int] generates values" {
  let gen : @gen.Gen[Small[Int]] = @gen.Gen::spawn()
  let samples = gen.samples(size=50)
  assert_true(samples.length() > 0)
}

///|
test "Small[Int] debug output keeps wrapper name" {
  debug_inspect(Small(-3), content="<Small: -3>")
}
