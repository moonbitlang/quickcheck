pub trait Arbitrary {
  arbitrary(Int, RandomState) -> Self
  shrink(Self) -> Array[Self]
}

fn shrink[T](val: T) -> Array[T] {
  [val]
}

