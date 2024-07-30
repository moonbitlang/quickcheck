// represent a test cell

struct Cell[T] {
  generator : Gen[T]
  shrinker : (T) -> Iter[T]
  property : (T) -> Bool
  classify : Option[(T) -> String]
  count : Int
  max_shrink : Int
  name : String?
}

pub fn make[T : Arbitrary](property : (T) -> Bool) -> Cell[T] {
  {
    generator: { gen: T::arbitrary },
    shrinker: T::shrink,
    classify: None,
    property,
    max_shrink: 10,
    count: 100,
    name: None,
  }
}
