pub fn run[T](self : Cell[T]) -> Report[T] {
  let state = RandomState::new()
  let failed = []
  let distribution : Map[String, Int] = Map::new()
  for i = 0; i < self.count; i = i + 1 {
    let v = (self.generator.gen)(i, state)
    self.classify.map(
      fn(x) {
        let label = x(v)
        distribution[label] = distribution.get(label).map_or(1, fn(y) { y + 1 })
      },
    )
    |> ignore
    if (self.property)(v).not() {
      for i = 0; i < self.max_shrink; i = i + 1 {
        let v = (self.shrinker)(v).find_first(
          fn { x => (self.property)(x).not() },
        )
        match v {
          Some(w) => break failed.push((w, i))
          None => ()
        }
      } else {
        failed.push((v, 0))
      }
    }
  }
  let success = failed.length()
  {
    failure_cases: if success == 0 {
      None
    } else {
      Some(failed)
    },
    count: (success, self.count),
    distribution: if self.classify.is_empty().not() {
      Some(distribution)
    } else {
      None
    },
    name: self.name
  }
}

pub fn sample_with_gen[T](self : Gen[T], count : Int) -> Array[T] {
  let state = RandomState::new()
  Array::makei(count, fn(i) { self.run(i, state) })
}

pub fn samples_[T : Arbitrary](count : Int) -> Array[T] {
  let state = RandomState::new()
  Array::makei(count, fn(i) { Arbitrary::arbitrary(i, state) })
}