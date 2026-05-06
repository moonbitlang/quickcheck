///|
/// Wraps a value while hiding it from `Show` output. Generation and
/// shrinking behave like the underlying value.
pub(all) struct Blind[T](T) derive(Eq)

///|
pub impl[T] Show for Blind[T] with output(_self, logger) {
  logger.write_string("(*)")
}

///|
pub impl[T : @coreqc.Arbitrary] @coreqc.Arbitrary for Blind[T] with arbitrary(
  size,
  rs,
) {
  Blind(T::arbitrary(size, rs))
}

///|
pub impl[T : @shrink.Shrink] @shrink.Shrink for Blind[T] with shrink(self) {
  @shrink.Shrink::shrink(self.0).map(v => Blind(v))
}

///|
test "Blind[Int] hides Show output" {
  inspect(Blind(42), content="(*)")
}

///|
test "Blind[Int] generates underlying values" {
  let gen : @gen.Gen[Blind[Int]] = @gen.Gen::spawn()
  let samples = gen.samples(size=50)
  assert_true(samples.length() > 0)
}

///|
test "Blind[Int] shrinks underlying value" {
  let s = @shrink.Shrink::shrink(Blind(100)).to_array()
  assert_true(s.length() > 0)
  assert_true(s.contains(Blind(0)))
}

///|
/// Wraps a value that should be generated normally but not shrunk.
pub(all) struct NoShrink[T](T) derive(Eq)

///|
pub impl[T : Show] Show for NoShrink[T] with output(self, logger) {
  self.0.output(logger)
}

///|
pub impl[T : @coreqc.Arbitrary] @coreqc.Arbitrary for NoShrink[T] with arbitrary(
  size,
  rs,
) {
  NoShrink(T::arbitrary(size, rs))
}

///|
pub impl[T] @shrink.Shrink for NoShrink[T] with shrink(_self) {
  Iter::empty()
}

///|
test "NoShrink[Int] shows underlying value" {
  inspect(NoShrink(42), content="42")
}

///|
test "NoShrink[Int] generates underlying values" {
  let gen : @gen.Gen[NoShrink[Int]] = @gen.Gen::spawn()
  let samples = gen.samples(size=50)
  assert_true(samples.length() > 0)
}

///|
test "NoShrink[Int] does not shrink" {
  let s = @shrink.Shrink::shrink(NoShrink(100))
  assert_eq(s.count(), 0)
}
