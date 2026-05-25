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
fn[A, B] zip_cart_tail(
  xs : @lazy.LazyRef[LazyList[Finite[A]]],
  ys : @lazy.LazyRef[LazyList[Finite[B]]],
) -> LazyList[Finite[(A, B)]] {
  guard ys.force() is Cons(y, ys) else { Nil }
  guard xs.force() is Cons(x, xs) else { Nil }
  Cons(fin_cart(x, y), @lazy.LazyRef::from_thunk(() => zip_cart_tail(xs, ys)))
}

///|
fn[A, B] zip_cart_rhs_bounded(
  xs : LazyList[Finite[A]],
  ys : LazyList[Finite[B]],
) -> LazyList[Finite[(A, B)]] {
  match (xs, ys) {
    (Cons(x, xs), Cons(y, ys)) =>
      Cons(
        fin_cart(x, y),
        @lazy.LazyRef::from_thunk(() => zip_cart_tail(xs, ys)),
      )
    (_, _) => Nil
  }
}

///|
fn[T] reversals(l : LazyList[T]) -> LazyList[LazyList[T]] {
  fn go(
    rev : @lazy.LazyRef[LazyList[T]],
    xs : LazyList[T],
  ) -> LazyList[LazyList[T]] {
    match (rev, xs) {
      (_, Nil) => Nil
      (rev, Cons(x, xs)) => {
        let rev1 = @lazy.Cons(x, rev)
        Cons(
          rev1,
          @lazy.LazyRef::from_thunk(() => {
            go(@lazy.LazyRef::from_value(rev1), xs.force())
          }),
        )
      }
    }
  }

  go(@lazy.LazyRef::from_value(Nil), l)
}
