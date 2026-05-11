///|
/// Wraps a value while hiding it from display/debug output. Generation and
/// shrinking behave like the underlying value.
pub(all) struct Blind[T](T) derive(Eq)

///|
pub impl[T] Debug for Blind[T] with to_repr(_self) {
  @debug.Repr::opaque_("Blind", @debug.Repr::omitted())
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
test "Blind[Int] hides debug output" {
  debug_inspect(Blind(42), content="<Blind: ...>")
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
pub impl[T : Debug] Debug for NoShrink[T] with to_repr(self) {
  @debug.Repr::opaque_("NoShrink", @debug.to_repr(self.0))
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
test "NoShrink[Int] preserves wrapper name in debug output" {
  debug_inspect(NoShrink(42), content="<NoShrink: 42>")
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
