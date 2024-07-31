pub trait Arbitrary {
  arbitrary(Int, RandomState) -> Self
  shrink(Self) -> Iter[Self]
}

/// Unit 
impl Arbitrary for Unit with arbitrary(_i, _rs) { () }

/// Boolean
impl Arbitrary for Bool with arbitrary(_i, rs) {
  if rs.next_double() < 0.5 {
    true
  } else {
    false
  }
}

/// Char
impl Arbitrary for Char with arbitrary(i, rs) {
  int_bound(0x10ffff).fmap(Char::from_int).run(i, rs)
}

/// Byte
impl Arbitrary for Byte with arbitrary(_i, rs) {
  int_bound(0xFF).fmap(fn(x) { x.to_byte() }).run(0, rs)
}

/// String
impl Arbitrary for String with arbitrary(i, rs) {
  small_int().fmap(
    fn(x) {
      let mut str = ""
      for i = 0; i < x; i = i + 1 {
        str = str + (Arbitrary::arbitrary(i, rs) : Char).to_string()
      }
      str
    },
  ).run(i, rs)
}

/// Number
impl Arbitrary for UInt with arbitrary(_i, rs) { rs.next_uint() }

impl Arbitrary for Int with arbitrary(_i, rs) { rs.next_int() }

impl Arbitrary for Int64 with arbitrary(_i, rs) { rs.next_int64() }

impl Arbitrary for Double with arbitrary(_i, rs) { rs.next_double() }

impl Arbitrary for UInt64 with arbitrary(_i, rs) { rs.next_uint64() }

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

/// Result and Option
impl[X : Arbitrary] Arbitrary for X? with arbitrary(i, rs) {
  if rs.next_double() < 0.5 {
    None
  } else {
    Arbitrary::arbitrary(i, rs)
  }
}

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

/// List
impl[T : Arbitrary] Arbitrary for @immut/list.T[T] with arbitrary(i, rs) {
  small_int().bind(fn(x) { list_with_size(x, Gen::spawn()) }).run(i, rs)
}

/// Array
impl[T : Arbitrary] Arbitrary for Array[T] with arbitrary(i, rs) {
  small_int().bind(fn(x) { array_with_size(x, Gen::spawn()) }).run(i, rs)
}

impl[T : Arbitrary] Arbitrary for FixedArray[T] with arbitrary(i, rs) {
  small_int().bind(
    fn(x) { array_with_size(x, Gen::spawn()).fmap(FixedArray::from_array) },
  ).run(i, rs)
}
