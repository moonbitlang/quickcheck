///|
/// Generate a value from an enumerable instance (up to a size bound).
/// This is the Feat-backed random-sampling bridge to the standard library's
/// `Generator` type.
/// @alert unsafe "Experimental: May cause stack overflow"
pub fn[T : Enumerable] feat_random(size : Int) -> @coreqc.Generator[T] {
  let seq = T::enumerate().sample_finite(size)
  let len = @ifseq.length(seq)
  guard len != 0 else { abort("feat_random: empty enumeration") }
  Generator((_sample_size, state) => {
    let index = @bigint.BigInt::from_int64(state.next_int64().abs()) % len
    @ifseq.get(seq, index)
  })
}
