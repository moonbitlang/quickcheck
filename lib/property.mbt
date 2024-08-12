struct Property[T] {
  law : (T) -> Bool
  generator : Gen[T]
  shrinker : (T) -> Iter[T]
  classify : (T) -> String
  filter : (T) -> Bool
}

pub fn with_law[T : Arbitrary](law : (T) -> Bool) -> Property[T] {
  {
    law,
    generator: spawn(),
    shrinker: Arbitrary::shrink,
    classify: fn(_v) { "trivial" },
    filter: fn(_p) { true },
  }
}

pub fn with_law_fe[T : @feat.Enumerable](
  law : (T) -> Bool,
  card : Int
) -> Property[T] {
  {
    law,
    generator: Gen::fe(card),
    shrinker: fn(_x) { Iter::empty() },
    classify: fn(_v) { "trivial" },
    filter: fn(_p) { true },
  }
}

pub fn with_classify[T](
  self : Property[T],
  classify : (T) -> String
) -> Property[T] {
  { ..self, classify, }
}

pub fn with_filter[T](self : Property[T], filter : (T) -> Bool) -> Property[T] {
  { ..self, filter, }
}

pub fn with_generator[T](self : Property[T], generator : Gen[T]) -> Property[T] {
  { ..self, generator, }
}

pub fn with_shrinker[T](
  self : Property[T],
  shrinker : (T) -> Iter[T]
) -> Property[T] {
  { ..self, shrinker, }
}