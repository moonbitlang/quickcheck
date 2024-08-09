pub typealias LazyList[T] = @lazy.LazyList[T]
fn sum(a : Array[Int]) -> Int {
  a.fold_left(Int::op_add, init=0)
}

fn convolution[A, B](
  xs : LazyList[Finite[A]],
  ys : LazyList[Finite[B]]
) -> Finite[(A, B)] {
  let s1 = xs.map(fn(x) { x.fCard })
  let s2 = ys.map(fn(x) { x.fCard })
  let card = @lazy.sum_list(@lazy.zip_with(Int::op_mul, s1, s2))
  let fx = @lazy.zip_with(fin_cart, xs, ys).fold_left(fin_union, init=fin_empty()).fIndex
  { fCard: card, fIndex: fx }
}

fn zip_plus[T](
  f : (T, T) -> T,
  ls1 : LazyList[T],
  ls2 : LazyList[T]
) -> LazyList[T] {
  match (ls1, ls2) {
    (Cons(x, xs), Cons(y, ys)) =>
      Cons(f(x, y), fn() { zip_plus(f, xs(), ys()) })
    (xs, ys) => xs.concat(ys)
  }
}

fn reversals[T](l : LazyList[T]) -> LazyList[LazyList[T]] {
  fn go {
    _, @lazy.Nil => @lazy.Nil
    rev, Cons(x, xs) => {
      let rev1 = @lazy.Cons(x, rev)
      Cons(rev1, fn() { go(fn() { rev1 }, xs()) })
    }
  }

  go(fn() { Nil }, l)
}

pub fn curry3[A, B, C, D](f : (A, B, C) -> D) -> (A) -> (B) -> (C) -> D {
  fn { a => fn { b => fn { c => f(a, b, c) } } }
}

pub fn curry4[A, B, C, D, E](
  f : (A, B, C, D) -> E
) -> (A) -> (B) -> (C) -> (D) -> E {
  fn { a => fn { b => fn { c => fn { d => f(a, b, c, d) } } } }
}
