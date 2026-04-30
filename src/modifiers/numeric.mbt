///|
/// Wraps a value guaranteed to be `>= 0`. Generation is biased toward
/// small values; shrinking stays non-negative.
pub struct NonNegative[T](T) derive(Eq)

///|
pub impl[T : Show] Show for NonNegative[T] with output(self, logger) {
  self.0.output(logger)
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
/// Wraps a value guaranteed to be `> 0`. Shrinks toward 1.
pub(all) struct Positive[T](T) derive(Eq)

///|
pub impl[T : Show] Show for Positive[T] with output(self, logger) {
  self.0.output(logger)
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
pub impl[T : Show] Show for Negative[T] with output(self, logger) {
  self.0.output(logger)
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
/// Wraps a value generated with a distribution biased toward small
/// absolute values. Shrinks normally.
pub(all) struct Small[T](T) derive(Eq)

///|
pub impl[T : Show] Show for Small[T] with output(self, logger) {
  self.0.output(logger)
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
