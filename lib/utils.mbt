fn removes[T](
  k : Int,
  n : Int,
  xs : @immut/list.T[T]
) -> @immut/list.T[@immut/list.T[T]] {
  if k > n {
    Nil
  } else {
    let xs_drop = xs.drop(k)
    if xs_drop.is_empty() {
      Nil
    } else {
      let xs_take = xs.take(k)
      Cons(xs_drop, removes(k, n - k, xs_drop).map(fn(x) { xs_take.concat(x) }))
    }
  }
}

fn apply_while[T](x : T, f : (T) -> T, cond : (T) -> Bool) -> @immut/list.T[T] {
  loop x, @immut/list.T::Nil {
    acc, lst => {
      let next = f(acc)
      if cond(next) {
        continue next, Cons(next, lst)
      } else {
        break lst
      }
    }
  }
}

fn zw_helper[A, B, C](
  f : (A, B) -> C,
  xs : @feat.LazyList[A],
  ys : @immut/list.T[B]
) -> @immut/list.T[C] {
  match (xs, ys) {
    (Cons(x, xs), Cons(y, ys)) => Cons(f(x, y), zw_helper(f, xs(), ys))
    (_, _) => Nil
  }
}
