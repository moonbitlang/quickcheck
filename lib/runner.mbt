

pub fn sample_with_gen[T](self : Gen[T], count : Int) -> Array[T] {
  let state = RandomState::new()
  Array::makei(count, fn(i) { self.run(i, state) })
}

pub fn samples_[T : Arbitrary](count : Int) -> Array[T] {
  let state = RandomState::new()
  Array::makei(count, fn(i) { Arbitrary::arbitrary(i, state) })
}