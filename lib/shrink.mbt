impl Arbitrary with shrink(_a) { Iter::empty() }

impl Arbitrary for Int with shrink(x) {
  apply_while(x, fn(z) { z / 2 }, fn(z) { (x - z).abs() < x.abs() }).map(
    fn(i) { x - i },
  ).iter().append(0)
}

test "shrink int" {
  inspect!(Arbitrary::shrink(100), content="[99, 97, 94, 88, 75, 50, 0]")
}

impl Arbitrary for Int64 with shrink(x) {
  apply_while(x, fn(z) { z / 2 }, fn(z) { (x - z).abs() < x.abs() }).map(
    fn(i) { x - i },
  ).iter().append(0)
}

test "shrink int64" {
  inspect!(
    Arbitrary::shrink(10000L),
    content="[9999, 9998, 9996, 9991, 9981, 9961, 9922, 9844, 9688, 9375, 8750, 7500, 5000, 0]",
  )
}

impl Arbitrary for UInt with shrink(x) {
  apply_while(x, fn(z) { z / 2 }, fn(z) { z > 0 }).map(fn(i) { x - i }).iter().append(
    0,
  )
}

test "shrink uint" {
  inspect!(
    Arbitrary::shrink(37000U),
    content="[36999, 36998, 36996, 36991, 36982, 36964, 36928, 36856, 36711, 36422, 35844, 34688, 32375, 27750, 18500, 0]",
  )
}

impl Arbitrary for UInt64 with shrink(x) {
  apply_while(x, fn(z) { z / 2 }, fn(z) { z > 0 }).map(fn(i) { x - i }).iter().append(
    0,
  )
}

test "shrink uint64" {
  inspect!(
    Arbitrary::shrink((42000 : UInt64)),
    content="[41999, 41998, 41995, 41990, 41980, 41959, 41918, 41836, 41672, 41344, 40688, 39375, 36750, 31500, 21000, 0]",
  )
}

impl Arbitrary for Bool with shrink(b) {
  Iter::new(
    fn(yield) {
      match b {
        true => yield(false)
        false => IterEnd
      }
    },
  )
}

test "shrink boolean" {
  inspect!(Arbitrary::shrink(true), content="[false]")
  inspect!(Arbitrary::shrink(false), content="[]")
}

impl Arbitrary for Char with shrink(c) {
  let ci = c.to_int()
  if ci == 0 {
    return Iter::empty()
  } else {
    let (cl, ch) = (Char::from_int(ci - 1), Char::from_int(ci + 1))
    [cl, ch, 'a', 'A', '1', '\n', '\t', '\b', '\\', '\'', '\r', ' '].iter()
  }
}

test "shrink char" {
  inspect!(
    Arbitrary::shrink('测'),
    content="['浊', '浌', 'a', 'A', '1', '\\n', '\\t', '\\b', '\\\\', '\\'', '\\r', ' ']",
  )
}

impl[T : Arbitrary] Arbitrary for T? with shrink(x) {
  match x {
    None => Iter::empty()
    Some(v) => Iter::append(Arbitrary::shrink(v).map(Option::Some), None)
  }
}

test "shrink option" {
  inspect!(Arbitrary::shrink((None : Unit?)), content="[]")
  inspect!(
    Arbitrary::shrink(Some(1000)),
    content="[Some(999), Some(997), Some(993), Some(985), Some(969), Some(938), Some(875), Some(750), Some(500), Some(0), None]",
  )
}

impl[T : Arbitrary, E : Arbitrary] Arbitrary for Result[T, E] with shrink(x) {
  match x {
    Ok(v) => Arbitrary::shrink(v).map(Result::Ok)
    Err(e) => Arbitrary::shrink(e).map(Result::Err)
  }
}

test "shrink result" {
  let b : Result[Bool, Int] = Err(100)
  let x : Result[Bool, Int] = Ok(true)
  inspect!(Arbitrary::shrink(b), content="[Err(99), Err(97), Err(94), Err(88), Err(75), Err(50), Err(0)]")
  inspect!(Arbitrary::shrink(x), content="[Ok(false)]")
}

impl[A : Arbitrary, B : Arbitrary] Arbitrary for (A, B) with shrink(x) {
  let (a, b) = x
  Arbitrary::shrink(a).map(fn(a1) { (a1, b) }).concat(
    Arbitrary::shrink(b).map(fn(b1) { (a, b1) }),
  )
}

test "shrink tuple" {
  let x = (120, true)
  inspect!(Arbitrary::shrink(x), content="[(119, true), (117, true), (113, true), (105, true), (90, true), (60, true), (0, true), (120, false)]")
}

impl[A : Arbitrary, B : Arbitrary, C : Arbitrary] Arbitrary for (A, B, C) with shrink(
  x
) {
  let (a, b, c) = x
  Arbitrary::shrink((a, (b, c))).map(
    fn(y) {
      let (a1, (b1, c1)) = y
      (a1, b1, c1)
    },
  )
}

impl[A : Arbitrary, B : Arbitrary, C : Arbitrary, D : Arbitrary] Arbitrary for (
  A,
  B,
  C,
  D,
) with shrink(x) {
  let (a, b, c, d) = x
  Arbitrary::shrink((a, (b, c, d))).map(
    fn(y) {
      let (a1, (b1, c1, d1)) = y
      (a1, b1, c1, d1)
    },
  )
}

impl[A : Arbitrary, B : Arbitrary, C : Arbitrary, D : Arbitrary, E : Arbitrary] Arbitrary for (
  A,
  B,
  C,
  D,
  E,
) with shrink(x) {
  let (a, b, c, d, e) = x
  Arbitrary::shrink((a, (b, c, d, e))).map(
    fn(y) {
      let (a1, (b1, c1, d1, e1)) = y
      (a1, b1, c1, d1, e1)
    },
  )
}

impl[A : Arbitrary, B : Arbitrary, C : Arbitrary, D : Arbitrary, E : Arbitrary, F : Arbitrary] Arbitrary for (
  A,
  B,
  C,
  D,
  E,
  F,
) with shrink(x) {
  let (a, b, c, d, e, f) = x
  Arbitrary::shrink((a, (b, c, d, e, f))).map(
    fn(y) {
      let (a1, (b1, c1, d1, e1, f1)) = y
      (a1, b1, c1, d1, e1, f1)
    },
  )
}

test "shrink 6-tuple" {
  let x = (20, 'A', 30U, true, true, true)
  inspect!(Arbitrary::shrink(x), content="[(19, 'A', 30, true, true, true), (18, 'A', 30, true, true, true), (15, 'A', 30, true, true, true), (10, 'A', 30, true, true, true), (0, 'A', 30, true, true, true), (20, '@', 30, true, true, true), (20, 'B', 30, true, true, true), (20, 'a', 30, true, true, true), (20, 'A', 30, true, true, true), (20, '1', 30, true, true, true), (20, '\\n', 30, true, true, true), (20, '\\t', 30, true, true, true), (20, '\\b', 30, true, true, true), (20, '\\\\', 30, true, true, true), (20, '\\'', 30, true, true, true), (20, '\\r', 30, true, true, true), (20, ' ', 30, true, true, true), (20, 'A', 29, true, true, true), (20, 'A', 27, true, true, true), (20, 'A', 23, true, true, true), (20, 'A', 15, true, true, true), (20, 'A', 0, true, true, true), (20, 'A', 30, false, true, true), (20, 'A', 30, true, false, true), (20, 'A', 30, true, true, false)]")
}

impl[T : Arbitrary + Show] Arbitrary for @immut/list.T[T] with shrink(xs) {
  let n = xs.length()
  fn shr_subterms(lst : @immut/list.T[T]) -> Iter[@immut/list.T[T]] {
    match lst {
      Nil => Iter::empty()
      Cons(x, xs) =>
        T::shrink(x).map(fn(x_) { @immut/list.T::Cons(x_, xs) }).concat(
          shr_subterms(xs).map(fn(xs_) { Cons(x, xs_) }),
        )
    }
  }

  apply_while(n, fn(x) { x / 2 }, fn(x) { x > 0 }).map(
    fn(k) {
      println(removes(k, n, xs))
      removes(k, n, xs)
    },
  ).flatten().iter().concat(shr_subterms(xs))
}

test "shrink int list" {
  let il : @immut/list.T[Int] = @immut/list.of([1, 2, 3, 4, 5, 6])
  let s = Arbitrary::shrink(il)
  println(s)
}
