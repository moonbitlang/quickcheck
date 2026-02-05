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
  fin_mconcat(@lazy.zip_with(fin_cart, xs, ys))
}

///|
fn[T] reversals(l : LazyList[T]) -> LazyList[LazyList[T]] {
  fn go(
    rev : @lazy.LazyRef[LazyList[T]],
    xs : LazyList[T],
  ) -> LazyList[LazyList[T]] {
    match (rev, xs) {
      (_, @lazy.Nil) => @lazy.Nil
      (rev, @lazy.Cons(x, xs)) => {
        let rev1 = @lazy.Cons(x, rev)
        @lazy.Cons(
          rev1,
          @lazy.LazyRef::from_thunk(fn() {
            go(@lazy.LazyRef::from_value(rev1), xs.force())
          }),
        )
      }
    }
  }

  go(@lazy.LazyRef::from_value(@lazy.Nil), l)
}
