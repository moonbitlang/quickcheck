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
