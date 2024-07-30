pub trait Arbitrary {
  arbitrary(Int, RandomState) -> Self
  shrink(Self) -> Iter[Self]
}


/// Unit 
impl Arbitrary for Unit with arbitrary(_i, _rs) { () }

/// Boolean
impl Arbitrary for Bool with arbitrary(_i, rs) {
  if rs.rs.gen_double() < 0.5 {
    true
  } else {
    false
  }
}

/// Char
impl Arbitrary for Char with arbitrary(_i, rs) {
  let c = rs.rs.gen_int()
  Char::from_int(c)
}

/// Byte
impl Arbitrary for Byte with arbitrary(_i, rs) {
  let c = rs.rs.gen_int() % 0xFF
  c.to_byte()
}

/// Number
impl Arbitrary for UInt with arbitrary(_i, rs) { rs.rs.gen_int().to_uint() }

impl Arbitrary for Int with arbitrary(_i, rs) { rs.rs.gen_int() }

impl Arbitrary for Int64 with arbitrary(_i, rs) { rs.rs.gen_int64() }

impl Arbitrary for Double with arbitrary(_i, rs) { 
  let r1 = Double::from_int(rs.rs.gen_int())
  let r2 = Double::from_int(rs.rs.gen_int())
  r1 / (r1 + r2)
 }

/// Array
impl[X : Arbitrary] Arbitrary for Array[X] with arbitrary(i, rs) {
  let length = Arbitrary::arbitrary(i, rs)
  Array::makei(length, fn(i) { Arbitrary::arbitrary(i, rs) })
}

impl[X : Arbitrary] Arbitrary for FixedArray[X] with arbitrary(i, rs) {
  let length = Arbitrary::arbitrary(i, rs)
  FixedArray::makei(length, fn(i) { Arbitrary::arbitrary(i, rs) })
}

/// Tuples
impl[A : Arbitrary, B : Arbitrary] Arbitrary for (A, B) with arbitrary(i, rs) {
  (Arbitrary::arbitrary(i, rs), Arbitrary::arbitrary(i, rs))
}

impl[A : Arbitrary, B : Arbitrary, C : Arbitrary] Arbitrary for (A, B, C) with arbitrary(
  i,
  rs
) {
  (
    Arbitrary::arbitrary(i, rs),
    Arbitrary::arbitrary(i, rs),
    Arbitrary::arbitrary(i, rs),
  )
}

impl[A : Arbitrary, B : Arbitrary, C : Arbitrary, D : Arbitrary] Arbitrary for (
  A,
  B,
  C,
  D,
) with arbitrary(i, rs) {
  (
    Arbitrary::arbitrary(i, rs),
    Arbitrary::arbitrary(i, rs),
    Arbitrary::arbitrary(i, rs),
    Arbitrary::arbitrary(i, rs),
  )
}

impl[A : Arbitrary, B : Arbitrary, C : Arbitrary, D : Arbitrary, E : Arbitrary] Arbitrary for (
  A,
  B,
  C,
  D,
  E,
) with arbitrary(i, rs) {
  (
    Arbitrary::arbitrary(i, rs),
    Arbitrary::arbitrary(i, rs),
    Arbitrary::arbitrary(i, rs),
    Arbitrary::arbitrary(i, rs),
    Arbitrary::arbitrary(i, rs),
  )
}

impl[A : Arbitrary, B : Arbitrary, C : Arbitrary, D : Arbitrary, E : Arbitrary, F : Arbitrary] Arbitrary for (
  A,
  B,
  C,
  D,
  E,
  F,
) with arbitrary(i, rs) {
  (
    Arbitrary::arbitrary(i, rs),
    Arbitrary::arbitrary(i, rs),
    Arbitrary::arbitrary(i, rs),
    Arbitrary::arbitrary(i, rs),
    Arbitrary::arbitrary(i, rs),
    Arbitrary::arbitrary(i, rs),
  )
}

/// Result and Option
impl[X : Arbitrary] Arbitrary for X? with arbitrary(i, rs) {
  if rs.rs.gen_double() < 0.5 {
    None
  } else {
    Arbitrary::arbitrary(i, rs)
  }
}

impl[T : Arbitrary, E : Arbitrary] Arbitrary for Result[T, E] with arbitrary(
  i,
  rs
) {
  if rs.rs.gen_double() < 0.5 {
    Ok(Arbitrary::arbitrary(i, rs))
  } else {
    Err(Arbitrary::arbitrary(i, rs))
  }
}
