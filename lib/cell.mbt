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

pub fn quick_check[T](self : Cell[T]) -> Report[T] {
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

pub fn verbose_check[T: Show](_self: Cell[T]) -> Report[T] {
  abort("not implemented")
}