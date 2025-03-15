///|
pub(open) trait Shrink {
  shrink(Self) -> Iter[Self]
}

///|
impl Shrink with shrink(_a) {
  Iter::empty()
}

///|
impl Shrink for Int with shrink(x) {
  @utils.apply_while_list(x, fn(z) { z / 2 }, fn(z) { (x - z).abs() < x.abs() })
  .map(fn(i) { x - i })
  .iter()
  .append(0)
  .filter(fn(u) { u != x })
}

///|
test "shrink int" {
  inspect!(Shrink::shrink(100), content="[99, 97, 94, 88, 75, 50, 0]")
  inspect!(Shrink::shrink(0), content="[]")
}

///|
impl Shrink for Int64 with shrink(x) {
  @utils.apply_while_list(x, fn(z) { z / 2 }, fn(z) { (x - z).abs() < x.abs() })
  .map(fn(i) { x - i })
  .iter()
  .append(0)
  .filter(fn(u) { u != x })
}

///|
test "shrink int64" {
  inspect!(
    Shrink::shrink(10000L),
    content="[9999, 9998, 9996, 9991, 9981, 9961, 9922, 9844, 9688, 9375, 8750, 7500, 5000, 0]",
  )
}

///|
impl Shrink for UInt with shrink(x) {
  @utils.apply_while_list(x, fn(z) { z / 2 }, fn(z) { z > 0 })
  .map(fn(i) { x - i })
  .iter()
  .append(0)
  .filter(fn(u) { u != x })
}

///|
test "shrink uint" {
  inspect!(
    Shrink::shrink(37000U),
    content="[36999, 36998, 36996, 36991, 36982, 36964, 36928, 36856, 36711, 36422, 35844, 34688, 32375, 27750, 18500, 0]",
  )
}

///|
impl Shrink for UInt64 with shrink(x) {
  @utils.apply_while_list(x, fn(z) { z / 2 }, fn(z) { z > 0 })
  .map(fn(i) { x - i })
  .iter()
  .append(0)
  .filter(fn(u) { u != x })
}

///|
test "shrink uint64" {
  inspect!(
    Shrink::shrink((42000 : UInt64)),
    content="[41999, 41998, 41995, 41990, 41980, 41959, 41918, 41836, 41672, 41344, 40688, 39375, 36750, 31500, 21000, 0]",
  )
}

///|
impl Shrink for Bool with shrink(b) {
  Iter::new(fn(yield_) {
    match b {
      true => yield_(false)
      false => IterEnd
    }
  })
}

///|
test "shrink boolean" {
  inspect!(Shrink::shrink(true), content="[false]")
  inspect!(Shrink::shrink(false), content="[]")
}

///|
impl Shrink for Char with shrink(c) {
  let ci = c.to_int()
  if ci == 0 {
    return Iter::empty()
  } else {
    let (cl, ch) = (Char::from_int(ci - 1), Char::from_int(ci + 1))
    [cl, ch, 'a', 'A', '1', '\n', '\t', '\b', '\\', '\'', '\r', ' '].iter()
  }
}

///|
test "shrink char" {
  inspect!(
    Shrink::shrink('测'),
    content="['浊', '浌', 'a', 'A', '1', '\\n', '\\t', '\\b', '\\\\', '\\'', '\\r', ' ']",
  )
}

///|
impl[T : Shrink] Shrink for T? with shrink(x) {
  match x {
    None => Iter::empty()
    Some(v) => Iter::append(Shrink::shrink(v).map(Option::Some), None)
  }
}

///|
test "shrink option" {
  inspect!(Shrink::shrink((None : Unit?)), content="[]")
  inspect!(
    Shrink::shrink(Some(1000)),
    content="[Some(999), Some(997), Some(993), Some(985), Some(969), Some(938), Some(875), Some(750), Some(500), Some(0), None]",
  )
}

///|
impl[T : Shrink, E : Shrink] Shrink for Result[T, E] with shrink(x) {
  match x {
    Ok(v) => Shrink::shrink(v).map(Result::Ok)
    Err(e) => Shrink::shrink(e).map(Result::Err)
  }
}

///|
test "shrink result" {
  let b : Result[Bool, Int] = Err(100)
  let x : Result[Bool, Int] = Ok(true)
  inspect!(
    Shrink::shrink(b),
    content="[Err(99), Err(97), Err(94), Err(88), Err(75), Err(50), Err(0)]",
  )
  inspect!(Shrink::shrink(x), content="[Ok(false)]")
}

///|
impl[A : Shrink, B : Shrink] Shrink for (A, B) with shrink(x) {
  let (a, b) = x
  Shrink::shrink(a)
  .map(fn(a1) { (a1, b) })
  .concat(Shrink::shrink(b).map(fn(b1) { (a, b1) }))
}

///|
test "shrink tuple" {
  let x = (120, true)
  inspect!(
    Shrink::shrink(x),
    content="[(119, true), (117, true), (113, true), (105, true), (90, true), (60, true), (0, true), (120, false)]",
  )
}

///|
impl[A : Shrink, B : Shrink, C : Shrink] Shrink for (A, B, C) with shrink(x) {
  let (a, b, c) = x
  Shrink::shrink((a, (b, c))).map(fn(y) {
    let (a1, (b1, c1)) = y
    (a1, b1, c1)
  })
}

///|
impl[A : Shrink, B : Shrink, C : Shrink, D : Shrink] Shrink for (A, B, C, D) with shrink(
  x
) {
  let (a, b, c, d) = x
  Shrink::shrink((a, (b, c, d))).map(fn(y) {
    let (a1, (b1, c1, d1)) = y
    (a1, b1, c1, d1)
  })
}

///|
impl[A : Shrink, B : Shrink, C : Shrink, D : Shrink, E : Shrink] Shrink for (
  A,
  B,
  C,
  D,
  E,
) with shrink(x) {
  let (a, b, c, d, e) = x
  Shrink::shrink((a, (b, c, d, e))).map(fn(y) {
    let (a1, (b1, c1, d1, e1)) = y
    (a1, b1, c1, d1, e1)
  })
}

///|
impl[A : Shrink, B : Shrink, C : Shrink, D : Shrink, E : Shrink, F : Shrink] Shrink for (
  A,
  B,
  C,
  D,
  E,
  F,
) with shrink(x) {
  let (a, b, c, d, e, f) = x
  Shrink::shrink((a, (b, c, d, e, f))).map(fn(y) {
    let (a1, (b1, c1, d1, e1, f1)) = y
    (a1, b1, c1, d1, e1, f1)
  })
}

///|
test "shrink 6-tuple" {
  let x = (20, 'A', 30U, true, true, true)
  inspect!(
    Shrink::shrink(x),
    content="[(19, 'A', 30, true, true, true), (18, 'A', 30, true, true, true), (15, 'A', 30, true, true, true), (10, 'A', 30, true, true, true), (0, 'A', 30, true, true, true), (20, '@', 30, true, true, true), (20, 'B', 30, true, true, true), (20, 'a', 30, true, true, true), (20, 'A', 30, true, true, true), (20, '1', 30, true, true, true), (20, '\\n', 30, true, true, true), (20, '\\t', 30, true, true, true), (20, '\\b', 30, true, true, true), (20, '\\\\', 30, true, true, true), (20, '\\'', 30, true, true, true), (20, '\\r', 30, true, true, true), (20, ' ', 30, true, true, true), (20, 'A', 29, true, true, true), (20, 'A', 27, true, true, true), (20, 'A', 23, true, true, true), (20, 'A', 15, true, true, true), (20, 'A', 0, true, true, true), (20, 'A', 30, false, true, true), (20, 'A', 30, true, false, true), (20, 'A', 30, true, true, false)]",
  )
}

///|
impl[T : Shrink + Show] Shrink for @immut/list.T[T] with shrink(xs) {
  let n = xs.length()
  fn shr_sub_terms(lst : @immut/list.T[T]) {
    match lst {
      Nil => Iter::empty()
      Cons(x, xs) =>
        T::shrink(x)
        .map(fn(x_) { @immut/list.Cons(x_, xs) })
        .concat(shr_sub_terms(xs).map(fn(xs_) { Cons(x, xs_) }))
    }
  }

  @utils.apply_while_list(n, fn(x) { x / 2 }, fn(x) { x > 0 })
  .map(fn(k) { @utils.removes_list(k, n, xs) })
  .flatten()
  .iter()
  .concat(shr_sub_terms(xs))
}

///|
test "shrink int list" {
  let il : @immut/list.T[Int] = @immut/list.of([1, 2, 3, 4, 5, 6])
  let s = Shrink::shrink(il)
  inspect!(
    s,
    content="[@list.of([2, 3, 4, 5, 6]), @list.of([1, 3, 4, 5, 6]), @list.of([1, 2, 4, 5, 6]), @list.of([1, 2, 3, 5, 6]), @list.of([1, 2, 3, 4, 6]), @list.of([4, 5, 6]), @list.of([0, 2, 3, 4, 5, 6]), @list.of([1, 1, 3, 4, 5, 6]), @list.of([1, 0, 3, 4, 5, 6]), @list.of([1, 2, 2, 4, 5, 6]), @list.of([1, 2, 0, 4, 5, 6]), @list.of([1, 2, 3, 3, 5, 6]), @list.of([1, 2, 3, 2, 5, 6]), @list.of([1, 2, 3, 0, 5, 6]), @list.of([1, 2, 3, 4, 4, 6]), @list.of([1, 2, 3, 4, 3, 6]), @list.of([1, 2, 3, 4, 0, 6]), @list.of([1, 2, 3, 4, 5, 5]), @list.of([1, 2, 3, 4, 5, 3]), @list.of([1, 2, 3, 4, 5, 0])]",
  )
}

///|
impl[X : Shrink] Shrink for Array[X] with shrink(xs) {
  let view = xs[:]
  let n = view.length()
  fn shr_sub_terms(arr : ArrayView[X]) {
    match arr {
      [] => Iter::empty()
      [x, .. xs] =>
        X::shrink(x)
        .map(fn(x_) { [x_, ..xs] })
        .concat(shr_sub_terms(xs).map(fn(xs_) { [x, ..xs_] }))
    }
  }

  @utils.apply_while_array(n, fn(x) { x / 2 }, fn(x) { x > 0 })
  .map(fn(k) { @utils.removes_array(k, n, xs) })
  .flatten()
  .iter()
  .concat(shr_sub_terms(view))
}

///|
test "shrink array" {
  let ar = [1, 2, 3, 4, 5, 6]
  let s = Shrink::shrink(ar)
  inspect!(
    s,
    content="[[2, 3, 4, 5, 6], [1, 3, 4, 5, 6], [1, 2, 4, 5, 6], [1, 2, 3, 5, 6], [1, 2, 3, 4, 6], [4, 5, 6], [0, 2, 3, 4, 5, 6], [1, 1, 3, 4, 5, 6], [1, 0, 3, 4, 5, 6], [1, 2, 2, 4, 5, 6], [1, 2, 0, 4, 5, 6], [1, 2, 3, 3, 5, 6], [1, 2, 3, 2, 5, 6], [1, 2, 3, 0, 5, 6], [1, 2, 3, 4, 4, 6], [1, 2, 3, 4, 3, 6], [1, 2, 3, 4, 0, 6], [1, 2, 3, 4, 5, 5], [1, 2, 3, 4, 5, 3], [1, 2, 3, 4, 5, 0]]",
  )
}

///|
impl[X : Shrink] Shrink for Iter[X] with shrink(xs) {
  let arr = xs.to_array()
  let its : Array[_] = Array::makei(arr.length(), fn(x) {
    X::shrink(arr[x])
    .map(fn(y) {
      let cp = arr.copy()
      cp[x] = y
      cp.iter()
    })
    .to_array()
  }).flatten()
  let rms : Array[Iter[X]] = arr.mapi(fn(i, _) {
    let a = arr.copy()
    a.remove(i) |> ignore
    a.iter()
  })
  rms.iter().concat(its.iter())
}

///|
test "shrink iter" {
  let it = [1, 2, 3, 4, 5, 6].iter()
  inspect!(
    it.shrink(),
    content="[[2, 3, 4, 5, 6], [1, 3, 4, 5, 6], [1, 2, 4, 5, 6], [1, 2, 3, 5, 6], [1, 2, 3, 4, 6], [1, 2, 3, 4, 5], [0, 2, 3, 4, 5, 6], [1, 1, 3, 4, 5, 6], [1, 0, 3, 4, 5, 6], [1, 2, 2, 4, 5, 6], [1, 2, 0, 4, 5, 6], [1, 2, 3, 3, 5, 6], [1, 2, 3, 2, 5, 6], [1, 2, 3, 0, 5, 6], [1, 2, 3, 4, 4, 6], [1, 2, 3, 4, 3, 6], [1, 2, 3, 4, 0, 6], [1, 2, 3, 4, 5, 5], [1, 2, 3, 4, 5, 3], [1, 2, 3, 4, 5, 0]]",
  )
}
