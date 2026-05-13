///|
/// Types that can enumerate "smaller" variants of a given value for
/// the classical QuickCheck shrinker. Each call to `shrink(x)` returns
/// an `Iter[Self]` of candidates strictly simpler than `x`; the driver
/// walks these candidates after a failure, keeping the first one that
/// still falsifies the property.
///
/// The return type is `Iter[Self]` rather than `Array[Self]` so large
/// or recursive shrink spaces stay lazy. The default body (`= _`)
/// means "no shrinks" — a conservative starting point for types where
/// shrinking isn't meaningful.
///
/// ```mbt check
/// test {
///   // `Int` has a built-in Shrink instance that walks toward 0.
///   let candidates : Array[Int] = Shrink::shrink(100).collect()
///   assert_true(candidates.contains(0))
///   assert_true(candidates.length() > 0)
///   // `Bool` shrinks `true` to `false`, and `false` has no shrinks.
///   @debug.assert_eq(Shrink::shrink(true).collect(), [false])
///   @debug.assert_eq(Shrink::shrink(false).collect(), [])
/// }
/// ```
pub(open) trait Shrink {
  shrink(Self) -> Iter[Self] = _
}

///|
impl Shrink with shrink(_a) {
  Iter::empty()
}

///|
pub impl Shrink for Int with shrink(x) {
  @utils.apply_while_list(x, z => z / 2, z => (x - z).abs() < x.abs())
  .map(i => x - i)
  .iter()
  .concat(Iter::singleton(0))
  .filter(u => u != x)
}

///|
pub impl Shrink for Int64 with shrink(x) {
  @utils.apply_while_list(x, z => z / 2, z => (x - z).abs() < x.abs())
  .map(i => x - i)
  .iter()
  .concat(Iter::singleton(0))
  .filter(u => u != x)
}

///|
pub impl Shrink for UInt with shrink(x) {
  @utils.apply_while_list(x, z => z / 2, z => z > 0)
  .map(i => x - i)
  .iter()
  .concat(Iter::singleton(0))
  .filter(u => u != x)
}

///|
pub impl Shrink for UInt64 with shrink(x) {
  @utils.apply_while_list(x, z => z / 2, z => z > 0)
  .map(i => x - i)
  .iter()
  .concat(Iter::singleton(0))
  .filter(u => u != x)
}

///|
pub impl Shrink for Bool with shrink(b) {
  if !b {
    Iter::empty()
  } else {
    Iter::singleton(false)
  }
}

///|
pub impl Shrink for Byte with shrink(x) {
  let xi = x.to_int()
  @utils.apply_while_list(xi, z => z / 2, z => z > 0)
  .map(i => (xi - i).to_byte())
  .iter()
  .concat(Iter::singleton(Int::to_byte(0)))
  .filter(u => u != x)
}

///|
pub impl Shrink for Char with shrink(c) {
  let ci = c.to_int()
  if ci == 0 {
    return Iter::empty()
  } else {
    let (cl, ch) = (Int::unsafe_to_char(ci - 1), Int::unsafe_to_char(ci + 1))
    [cl, ch, 'a', 'A', '1', '\n', '\t', '\b', '\\', '\'', '\r', ' ']
  }
}

///|
pub impl Shrink for Double with shrink(x) {
  shrink_decimal(x)
}

///|
pub impl Shrink for Float with shrink(x) {
  shrink_decimal(x.to_double()).map(Float::from_double)
}

///|
/// Shrink a floating-point number toward simpler decimal representations.
///
/// Strategy:
/// - NaN shrinks to 0 and a few small numbers.
/// - Infinity shrinks to 0 and a few small numbers.
/// - Negative values shrink to their absolute value, then recurse.
/// - Non-negative finite values are rounded at increasing precisions
///   (1, 10, 100, ..., 100000) and each rounded candidate that is
///   strictly closer to zero is emitted, along with integer-shrink
///   candidates of the scaled mantissa.
fn shrink_decimal(x : Double) -> Iter[Double] {
  guard !x.is_nan() else { [0.0, 1.0, -1.0, 2.0] }
  guard !x.is_inf() else { [0.0, 1.0, -1.0, 1000.0, -1000.0] }
  guard x >= 0.0 else {
    Iter::singleton(-x).concat(shrink_decimal(-x).map(Double::neg))
  }
  guard x != 0.0 else { Iter::empty() }
  [1.0, 10.0, 100.0, 1000.0, 10000.0, 100000.0]
  .iter()
  .flat_map(p => {
    let m = (x * p + 0.5).floor().to_int64()
    if p != 1.0 && m % 10L == 0L {
      return Iter::empty()
    }
    Iter::singleton(m)
    .concat(Shrink::shrink(m))
    .map(n => n.to_double() / p)
    .filter(y => y >= 0.0 && y < x)
  })
}

///|
pub impl Shrink for String

///|
pub impl Shrink for Bytes

///|
pub impl[T : Shrink] Shrink for T? with shrink(x) {
  match x {
    None => Iter::empty()
    Some(v) =>
      Shrink::shrink(v).map(v1 => Some(v1)).concat(Iter::singleton(None))
  }
}

///|
pub impl Shrink for Unit

///|
pub impl[T : Shrink, E : Shrink] Shrink for Result[T, E] with shrink(x) {
  match x {
    Ok(v) => Shrink::shrink(v).map(v1 => Ok(v1))
    Err(e) => Shrink::shrink(e).map(e1 => Err(e1))
  }
}

///|
pub impl[A : Shrink, B : Shrink] Shrink for (A, B) with shrink(x) {
  let (a, b) = x
  Shrink::shrink(a)
  .map(a1 => (a1, b))
  .concat(Shrink::shrink(b).map(b1 => (a, b1)))
}

///|
pub impl[A : Shrink, B : Shrink, C : Shrink] Shrink for (A, B, C) with shrink(x) {
  let (a, b, c) = x
  Shrink::shrink((a, (b, c))).map(y => {
    let (a1, (b1, c1)) = y
    (a1, b1, c1)
  })
}

///|
pub impl[A : Shrink, B : Shrink, C : Shrink, D : Shrink] Shrink for (A, B, C, D) with shrink(
  x,
) {
  let (a, b, c, d) = x
  Shrink::shrink((a, (b, c, d))).map(y => {
    let (a1, (b1, c1, d1)) = y
    (a1, b1, c1, d1)
  })
}

///|
pub impl[A : Shrink, B : Shrink, C : Shrink, D : Shrink, E : Shrink] Shrink for (
  A,
  B,
  C,
  D,
  E,
) with shrink(x) {
  let (a, b, c, d, e) = x
  Shrink::shrink((a, (b, c, d, e))).map(y => {
    let (a1, (b1, c1, d1, e1)) = y
    (a1, b1, c1, d1, e1)
  })
}

///|
pub impl[A : Shrink, B : Shrink, C : Shrink, D : Shrink, E : Shrink, F : Shrink] Shrink for (
  A,
  B,
  C,
  D,
  E,
  F,
) with shrink(x) {
  let (a, b, c, d, e, f) = x
  Shrink::shrink((a, (b, c, d, e, f))).map(y => {
    let (a1, (b1, c1, d1, e1, f1)) = y
    (a1, b1, c1, d1, e1, f1)
  })
}

///|
pub impl[T : Shrink] Shrink for @list.List[T] with shrink(xs) {
  let n = xs.length()
  fn shr_sub_terms(lst : @list.List[T]) {
    match lst {
      Empty => Iter::empty()
      More(x, tail=xs) =>
        T::shrink(x)
        .map(x_ => xs.add(x_))
        .concat(shr_sub_terms(xs).map(xs_ => xs_.add(x)))
    }
  }

  @utils.apply_while_list(n, x => x / 2, x => x > 0)
  .map(k => @utils.removes_list(k, n, xs))
  .flatten()
  .iter()
  .concat(shr_sub_terms(xs))
}

///|
/// Shrink non-empty list without producing the empty list.
///
/// ```mbt check
/// test {
///   let xs : @list.List[Int] = @list.from_array([5])
///   // Default list shrink would produce [], which is filtered out here.
///   assert_true(shrink_non_empty_list(xs).all(ys => !ys.is_empty()))
/// }
/// ```
pub fn[T : Shrink] shrink_non_empty_list(
  xs : @list.List[T],
) -> Iter[@list.List[T]] {
  Shrink::shrink(xs).filter(ys => !ys.is_empty())
}

///|
pub impl[X : Shrink] Shrink for Array[X] with shrink(xs) {
  let view = xs[:]
  let n = view.length()
  fn shr_sub_terms(arr : ArrayView[X]) {
    match arr {
      [] => Iter::empty()
      [x, .. xs] =>
        X::shrink(x)
        .map(x_ => [x_, ..xs])
        .concat(shr_sub_terms(xs).map(xs_ => [x, ..xs_]))
    }
  }

  @utils.apply_while_array(n, x => x / 2, x => x > 0)
  .map(k => @utils.removes_array(k, n, xs))
  .flatten()
  .iter()
  .concat(shr_sub_terms(view))
}

///|
/// Shrink non-empty array without producing the empty array.
///
/// ```mbt check
/// test {
///   assert_true(shrink_non_empty_array([1, 2, 3]).all(ys => ys.length() > 0))
/// }
/// ```
pub fn[X : Shrink] shrink_non_empty_array(xs : Array[X]) -> Iter[Array[X]] {
  Shrink::shrink(xs).filter(ys => ys.length() > 0)
}

///|
pub impl[X : Shrink] Shrink for Iter[X] with shrink(xs) {
  let arr = xs.to_array()
  let its : Array[_] = Array::makei(arr.length(), x => {
    X::shrink(arr[x])
    .map(y => {
      let cp = arr.copy()
      cp[x] = y
      cp.iter()
    })
    .to_array()
  }).flatten()
  let rms : Array[Iter[X]] = arr.mapi((i, _) => {
    let a = arr.copy()
    a.remove(i) |> ignore
    a.iter()
  })
  rms.iter().concat(its.iter())
}

///|
fn[X] shrink_remove_one_array(xs : Array[X]) -> Iter[Array[X]] {
  let l = xs.length() - 1
  Array::makei(l + 1, i => i)
  .iter()
  .flat_map(i => {
    let nv = xs.copy()
    nv.remove(i) |> ignore
    Iter::singleton(nv)
  })
}

///|
/// Shrink sorted array, requires the Array[T] to be sorted.
pub fn[T : Shrink + Compare] shrink_sorted_array(
  xs : Array[T],
  lo~ : T,
  hi~ : T,
) -> Iter[Array[T]] {
  let shrink_one_val = (nv : Array[T]) => {
    let l = nv.length() - 1
    Array::makei(l + 1, i => i)
    .iter()
    .flat_map(i => {
      let lo = if i == 0 { lo } else { nv[i - 1] }
      let hi = if i == l { hi } else { nv[i + 1] }
      Shrink::shrink(nv[i]).flat_map(x => {
        if lo <= x && x <= hi && x != nv[i] {
          let nv1 = nv.copy()
          nv1[i] = x
          Iter::singleton(nv1)
        } else {
          Iter::empty()
        }
      })
    })
  }
  shrink_remove_one_array(xs).concat(shrink_one_val(xs))
}

///|
/// Shrink sorted list, requires the List[T] to be sorted.
pub fn[T : Shrink + Compare] shrink_sorted_list(
  xs : @list.List[T],
  lo~ : T,
  hi~ : T,
) -> Iter[@list.List[T]] {
  shrink_sorted_array(xs.to_array(), lo~, hi~).map(a => @list.from_array(a))
}

///|
/// Shrink distinct array, requires all elements of the Array[X] to be distinct.
pub fn[X : Shrink + Eq] shrink_distinct_array(xs : Array[X]) -> Iter[Array[X]] {
  fn no_duplicate_at(arr : Array[X], i : Int, x : X) -> Bool {
    for j in 0..<arr.length() {
      if j != i && arr[j] == x {
        return false
      }
    }
    true
  }

  let shrink_one_val = Array::makei(xs.length(), i => i)
    .iter()
    .flat_map(i => {
      X::shrink(xs[i]).flat_map(x => {
        if x != xs[i] && no_duplicate_at(xs, i, x) {
          let nv = xs.copy()
          nv[i] = x
          Iter::singleton(nv)
        } else {
          Iter::empty()
        }
      })
    })
  shrink_remove_one_array(xs).concat(shrink_one_val)
}

///|
/// Shrink sorted distinct array, requires the Array[T] to be sorted and distinct.
pub fn[T : Shrink + Compare] shrink_sorted_distinct_array(
  xs : Array[T],
  lo~ : T,
  hi~ : T,
) -> Iter[Array[T]] {
  let shrink_one_val = (nv : Array[T]) => {
    let l = nv.length() - 1
    Array::makei(l + 1, i => i)
    .iter()
    .flat_map(i => {
      let lower_ok = x => if i == 0 { lo <= x } else { nv[i - 1] < x }
      let upper_ok = x => if i == l { x <= hi } else { x < nv[i + 1] }
      T::shrink(nv[i]).flat_map(x => {
        if lower_ok(x) && upper_ok(x) && x != nv[i] {
          let nv1 = nv.copy()
          nv1[i] = x
          Iter::singleton(nv1)
        } else {
          Iter::empty()
        }
      })
    })
  }
  shrink_remove_one_array(xs).concat(shrink_one_val(xs))
}
