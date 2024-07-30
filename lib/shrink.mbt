impl Arbitrary with shrink(_a) { Iter::empty() }

impl Arbitrary for Int with shrink(x) {
  apply_while(x, fn(z) { z / 2 }, fn(z) { (x - z).abs() < x.abs() }).map(
    fn(i) { x - i },
  ).iter().append(0)
}

impl Arbitrary for Int64 with shrink(x) {
  apply_while(x, fn(z) { z / 2 }, fn(z) { (x - z).abs() < x.abs() }).map(
    fn(i) { x - i },
  ).iter().append(0)
}

impl Arbitrary for UInt with shrink(x) {
  apply_while(x, fn(z) { z / 2 }, fn(z) { z > 0 }).map(fn(i) { x - i }).iter().append(
    0,
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

impl Arbitrary for Char with shrink(c) {
  let ci = c.to_int()
  if ci == 0 {
    return Iter::empty()
  } else {
    let (cl, ch) = (Char::from_int(ci - 1), Char::from_int(ci + 1))
    [cl, ch, 'a', 'A', '1', '\n', '\t', '\b', '\\', '\'', '\r', ' '].iter()
  }
}

impl[T : Arbitrary] Arbitrary for T? with shrink(x) {
  match x {
    None => Iter::empty()
    Some(v) => Iter::append(Arbitrary::shrink(v).map(Option::Some), None)
  }
}

impl[T : Arbitrary, E : Arbitrary] Arbitrary for Result[T, E] with shrink(x) {
  match x {
    Ok(v) => Arbitrary::shrink(v).map(Result::Ok)
    Err(e) => Arbitrary::shrink(e).map(Result::Err)
  }
}

impl[A : Arbitrary, B : Arbitrary] Arbitrary for (A, B) with shrink(x) {
  let (a, b) = x
  Arbitrary::shrink(a).map(fn(a1) { (a1, b) }).concat(
    Arbitrary::shrink(b).map(fn(b1) { (a, b1) }),
  )
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

impl[T : Arbitrary + Show] Arbitrary for @immut/list.T[T] with shrink(xs) {
  let n = xs.length()
  fn shr_subterms(lst : @immut/list.T[T]) -> Iter[@immut/list.T[T]] {
    match lst {
      Nil => Iter::empty()
      Cons(x, xs) => {
        println(T::shrink(x).collect())
        T::shrink(x).map(fn(x_) { @immut/list.T::Cons(x_, xs) }).concat(
          shr_subterms(xs).map(fn(xs_) { Cons(x, xs_) }),
        )
      }
    }
  }

  apply_while(n, fn(x) { x / 2 }, fn(x) { x > 0 }).map(
    fn(k) { removes(k, n, xs) },
  ).flatten().iter().concat(shr_subterms(xs))
}