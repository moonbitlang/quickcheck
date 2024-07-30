fn removes[T](
  k : Int,
  n : Int,
  xs : @immut/list.T[T]
) -> @immut/list.T[@immut/list.T[T]] {
  if k > n {
    Nil
  } else {
    let xs = xs.drop(k)
    if xs.is_empty() {
      Nil
    } else {
      let ys = xs.take(k)
      Cons(xs, removes(k, n - k, xs).map(fn(x) { ys.concat(x) }))
    }
  }
}

fn apply_while[T](
  x : T,
  f : (T) -> T,
  cond : (T) -> Bool
) -> @immut/list.T[T] {
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
