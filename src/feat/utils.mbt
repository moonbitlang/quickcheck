///|
pub using @lazy {type LazyList}

///|
fn sum(a : Array[BigInt]) -> BigInt {
  a.fold(BigInt::add, init=0)
}

///|
fn[A, B] convolution(
  xs : LazyList[Finite[A]],
  ys : LazyList[Finite[B]],
) -> Finite[(A, B)] {
  fin_mconcat(zip_cart_rhs_bounded(xs, ys))
}

///|
fn[T] lazy_tail_or_empty(xs : LazyList[T]) -> LazyList[T] {
  match xs.tail() {
    Some(rest) => rest
    None => @lazy.empty()
  }
}

///|
fn[T] lazy_split_at(xs : LazyList[T], i : Int) -> (LazyList[T], LazyList[T]) {
  if i <= 0 {
    (@lazy.empty(), xs)
  } else {
    let prefix : Array[T] = []
    let rest = for cur = xs, n = i {
      if n <= 0 {
        break cur
      } else {
        match cur.head() {
          None => break @lazy.empty()
          Some(x) => {
            prefix.push(x)
            continue lazy_tail_or_empty(cur), n - 1
          }
        }
      }
    }
    (@lazy.from_iter(prefix.iter()), rest)
  }
}

///|
fn[T] lazy_zip_plus(
  f : (T, T) -> T,
  xs : LazyList[T],
  ys : LazyList[T],
) -> LazyList[T] {
  match (xs.head(), ys.head()) {
    (Some(x), Some(y)) =>
      @lazy.lazy_cons(f(x, y), () => {
        lazy_zip_plus(f, lazy_tail_or_empty(xs), lazy_tail_or_empty(ys))
      })
    (None, _) => ys
    (_, None) => xs
  }
}

///|
fn[A, B] zip_cart_rhs_bounded(
  xs : LazyList[Finite[A]],
  ys : LazyList[Finite[B]],
) -> LazyList[Finite[(A, B)]] {
  match (xs.head(), ys.head()) {
    (Some(x), Some(y)) =>
      @lazy.lazy_cons(fin_cart(x, y), () => {
        let ys_tail = lazy_tail_or_empty(ys)
        if ys_tail.is_empty() {
          @lazy.empty()
        } else {
          zip_cart_rhs_bounded(lazy_tail_or_empty(xs), ys_tail)
        }
      })
    _ => @lazy.empty()
  }
}

///|
fn[T] reversals(l : LazyList[T]) -> LazyList[LazyList[T]] {
  fn go(rev : LazyList[T], xs : LazyList[T]) -> LazyList[LazyList[T]] {
    match xs.head() {
      None => @lazy.empty()
      Some(x) => {
        let rev1 = @lazy.lazy_cons(x, () => rev)
        @lazy.lazy_cons(rev1, () => go(rev1, lazy_tail_or_empty(xs)))
      }
    }
  }

  go(@lazy.empty(), l)
}
