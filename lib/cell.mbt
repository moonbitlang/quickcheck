// represent a test cell

struct Cell[T] {
  generator : Gen[T]
  property : (T) -> Bool
  count : Int
  name : Option[String]
}

pub fn make[T : Arbitrary](property : (T) -> Bool) -> Cell[T] {
  { generator: { gen: T::arbitrary }, property, count: 100, name: None }
}

