struct Property_Old[T] {
  law : (T) -> Bool
  generator : Gen[T]
  shrinker : (T) -> Iter[T]
  classify : (T) -> String
  filter : (T) -> Bool
}

pub fn with_law[T : Arbitrary + Shrink](law : (T) -> Bool) -> Property_Old[T] {
  {
    law,
    generator: spawn(),
    shrinker: Shrink::shrink,
    classify: fn(_v) { "trivial" },
    filter: fn(_p) { true },
  }
}

pub fn with_law_fe[T : @feat.Enumerable](
  law : (T) -> Bool,
  card : Int
) -> Property_Old[T] {
  {
    law,
    generator: Gen::feat_random(card),
    shrinker: fn(_x) { Iter::empty() },
    classify: fn(_v) { "trivial" },
    filter: fn(_p) { true },
  }
}

pub fn with_classify[T](
  self : Property_Old[T],
  classify : (T) -> String
) -> Property_Old[T] {
  { ..self, classify, }
}

pub fn with_filter[T](self : Property_Old[T], filter : (T) -> Bool) -> Property_Old[T] {
  { ..self, filter, }
}

pub fn with_generator[T](self : Property_Old[T], generator : Gen[T]) -> Property_Old[T] {
  { ..self, generator, }
}

pub fn with_shrinker[T](
  self : Property_Old[T],
  shrinker : (T) -> Iter[T]
) -> Property_Old[T] {
  { ..self, shrinker, }
}