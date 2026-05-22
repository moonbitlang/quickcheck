///|
/// Generate a value from an enumerable instance (up to a size bound).
/// This is the Feat-backed random-sampling bridge: `gen` stays unaware
/// of `Enumerable`, while `feat` can still produce ordinary generators.
/// @alert unsafe "Experimental: May cause stack overflow"
pub fn[T : Enumerable] feat_random(size : Int) -> @gen.Gen[T] {
  let { fCard, fIndex } = T::enumerate().sample_finite(size)
  guard fCard != 0 else { abort("feat_random: empty enumeration") }
  @gen.integer_bound(fCard).fmap(fIndex)
}
