pub trait Arbitrary {
  // (Size, RNG) -> T
  arbitrary(Int, RandomState) -> Self
}

/// Unit 
impl Arbitrary for Unit with arbitrary(_i, _rs) { () }

/// Boolean
impl Arbitrary for Bool with arbitrary(_i, rs) { rs.next_double() < 0.5 }

/// Char
impl Arbitrary for Char with arbitrary(i, rs) {
  let planes = [
    (60, unicode_ascii()),
    (10, unicode_plane0()),
    (10, unicode_plane1()),
    (5, unicode_plane2()),
    (5, unicode_plane14()),
  ]
  frequency(planes).such_that(reserved).fmap(Char::from_int).run(i, rs)
}

/// Byte
impl Arbitrary for Byte with arbitrary(_i, rs) {
  int_bound(0xFF).fmap(fn(x) { x.to_byte() }).run(0, rs)
}

/// String
impl Arbitrary for String with arbitrary(size, rs) {
  spawn()
  .bind(
    fn(x) {
      list_with_size(x, spawn()).fmap(
        fn(x) {
          x.fold_left(init="", fn(x, acc : Char) { x + acc.to_string() })
        },
      )
    },
  )
  .run(size, rs)
}

/// Number
impl Arbitrary for UInt with arbitrary(size, rs) {
  if size == 0 {
    0
  } else {
    rs.next_uint() % size.to_uint()
  }
}

impl Arbitrary for Int with arbitrary(size, rs) {
  if size == 0 {
    0
  } else {
    rs.next_int() % size
  }
}

impl Arbitrary for Int64 with arbitrary(size, rs) {
  if size == 0 {
    0
  } else {
    rs.next_int64() % size.to_int64()
  }
}

impl Arbitrary for Double with arbitrary(_i, rs) { rs.next_double() }

impl Arbitrary for UInt64 with arbitrary(size, rs) {
  if size == 0 {
    0
  } else {
    rs.next_uint64() % size.to_uint().to_uint64()
  }
}

/// Tuples
impl[A : Arbitrary, B : Arbitrary] Arbitrary for (A, B) with arbitrary(i, rs) {
  liftA2(fn(x, y) { (x, y) }, spawn(), spawn()).run(i, rs)
}

impl[A : Arbitrary, B : Arbitrary, C : Arbitrary] Arbitrary for (A, B, C) with arbitrary(
  i,
  rs
) {
  liftA3(fn(x, y, z) { (x, y, z) }, spawn(), spawn(), spawn()).run(i, rs)
}

impl[A : Arbitrary, B : Arbitrary, C : Arbitrary, D : Arbitrary] Arbitrary for (
  A,
  B,
  C,
  D,
) with arbitrary(i, rs) {
  liftA4(fn(x, y, z, w) { (x, y, z, w) }, spawn(), spawn(), spawn(), spawn()).run(
    i, rs,
  )
}

impl[A : Arbitrary, B : Arbitrary, C : Arbitrary, D : Arbitrary, E : Arbitrary] Arbitrary for (
  A,
  B,
  C,
  D,
  E,
) with arbitrary(i, rs) {
  liftA5(
    fn(x, y, z, w, v) { (x, y, z, w, v) },
    spawn(),
    spawn(),
    spawn(),
    spawn(),
    spawn(),
  ).run(i, rs)
}

impl[A : Arbitrary, B : Arbitrary, C : Arbitrary, D : Arbitrary, E : Arbitrary, F : Arbitrary] Arbitrary for (
  A,
  B,
  C,
  D,
  E,
  F,
) with arbitrary(i, rs) {
  liftA6(
    fn(x, y, z, w, v, u) { (x, y, z, w, v, u) },
    spawn(),
    spawn(),
    spawn(),
    spawn(),
    spawn(),
    spawn(),
  ).run(i, rs)
}

/// Option
impl[X : Arbitrary] Arbitrary for X? with arbitrary(i, rs) {
  if rs.next_double() < 0.5 {
    None
  } else {
    Arbitrary::arbitrary(i, rs)
  }
}

/// Result
impl[T : Arbitrary, E : Arbitrary] Arbitrary for Result[T, E] with arbitrary(
  i,
  rs
) {
  if rs.next_double() < 0.5 {
    Ok(Arbitrary::arbitrary(i, rs))
  } else {
    Err(Arbitrary::arbitrary(i, rs))
  }
}

/// Array
impl[T : Arbitrary] Arbitrary for Array[T] with arbitrary(size, rs) {
  spawn().bind(fn(x) { spawn().array_with_size(x) }).run(size, rs)
}

/// FixedArray
impl[T : Arbitrary] Arbitrary for FixedArray[T] with arbitrary(size, rs) {
  spawn()
  .bind(fn(x) { spawn().array_with_size(x).fmap(FixedArray::from_array) })
  .run(size, rs)
}

impl[K : Arbitrary + Eq + Hash, V : Arbitrary] Arbitrary for Map[K, V] with arbitrary(
  size,
  rs
) {
  spawn().fmap(Map::from_array).run(size, rs)
}

impl[T : Arbitrary] Arbitrary for Iter[T] with arbitrary(size, rs) {
  spawn().fmap(Array::iter).run(size, rs)
}

impl[T : Arbitrary] Arbitrary for Ref[T] with arbitrary(size, rs) {
  spawn().fmap(Ref::new).run(size, rs)
}

impl[T : Arbitrary] Arbitrary for @deque.T[T] with arbitrary(size, rs) {
  spawn().fmap(@deque.from_array).run(size, rs)
}

impl[T : Arbitrary] Arbitrary for @immut/array.T[T] with arbitrary(size, rs) {
  spawn().fmap(@immut/array.from_array).run(size, rs)
}

impl[K : Arbitrary + Eq + Hash, V : Arbitrary] Arbitrary for @immut/hashmap.T[
  K,
  V,
] with arbitrary(size, rs) {
  spawn().fmap(@immut/hashmap.from_array).run(size, rs)
}

impl[T : Arbitrary + Eq + Hash] Arbitrary for @immut/hashset.T[T] with arbitrary(
  size,
  rs
) {
  spawn().fmap(@immut/hashset.from_array).run(size, rs)
}

impl[T : Arbitrary] Arbitrary for @immut/list.T[T] with arbitrary(size, rs) {
  spawn().bind(fn(x) { list_with_size(x, Gen::spawn()) }).run(size, rs)
}

impl[T : Arbitrary + Compare] Arbitrary for @immut/priority_queue.T[T] with arbitrary(
  size,
  rs
) {
  spawn().fmap(@immut/priority_queue.from_array).run(size, rs)
}

impl[V : Arbitrary, K : Arbitrary + Compare] Arbitrary for @immut/sorted_map.T[
  K,
  V,
] with arbitrary(size, rs) {
  spawn().fmap(@immut/sorted_map.from_array).run(size, rs)
}

impl[T : Arbitrary + Compare] Arbitrary for @immut/sorted_set.T[T] with arbitrary(
  size,
  rs
) {
  spawn().fmap(@immut/sorted_set.from_array).run(size, rs)
}

impl Arbitrary for Json with arbitrary(i, rs) {
  let composite = [spawn().fmap(Json::Object), spawn().fmap(Json::Array)]
  let scalar = [
    pure(Null),
    one_of([pure(True), pure(False)]),
    spawn().fmap(Json::Number),
    spawn().fmap(Json::String),
  ]
  Gen::new(
    fn(size, rs) {
      match size {
        0 => one_of(scalar).run(0, rs)
        n =>
          frequency([(1, one_of(scalar)), (4, one_of(composite))]).run(
            n / 2,
            rs,
          )
      }
    },
  ).run(i, rs)
}
