///|
pub(all) typealias LazyList[T] = @lazy.LazyList[T]

///|
fn sum(a : Array[BigInt]) -> BigInt {
  a.fold(BigInt::op_add, init=0)
}

///|
fn convolution[A, B](
  xs : LazyList[Finite[A]],
  ys : LazyList[Finite[B]]
) -> Finite[(A, B)] {
  let s1 = xs.map(fn(x) { x.fCard })
  let s2 = ys.map(fn(x) { x.fCard })
  let card : BigInt = @lazy.sum(@lazy.zip_with(BigInt::op_mul, s1, s2), init=0)
  let fx = @lazy.zip_with(fin_cart, xs, ys).fold_left(
      fin_union,
      init=fin_empty(),
    ).fIndex
  { fCard: card, fIndex: fx }
}

///|
fn reversals[T](l : LazyList[T]) -> LazyList[LazyList[T]] {
  fn go {
    _, @lazy.Nil => @lazy.Nil
    rev, Cons(x, xs) => {
      let rev1 = @lazy.Cons(x, rev)
      Cons(
        rev1,
        @lazy.LazyRef::from_thunk(fn() {
          go(@lazy.LazyRef::from_value(rev1), xs.force())
        }),
      )
    }
  }

  go(@lazy.LazyRef::from_value(Nil), l)
}
