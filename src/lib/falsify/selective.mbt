// Selective Applicative Functor
///|
enum Either[L, R] {
  Left(L)
  Right(R)
}

///|
fn Either::fmap[L, R, S](self : Either[L, R], f : (R) -> S) -> Either[L, S] {
  match self {
    Right(r) => Right(f(r))
    Left(l) => Left(l)
  }
}

///|
pub fn select[T, U](self : Gen[(T) -> U], e : Gen[Either[T, U]]) -> Gen[U] {
  new(fn(st) {
    let (s, l, r) = st.view()
    let (ma, ls) = e.run_gen(l)
    match ma {
      Left(a) => {
        let (f1, rs) = self.run_gen(r)
        (f1(a), combine_shrunk(s, l, r, ls, rs))
      }
      Right(b) => (b, combine_shrunk(s, l, r, ls, Iter::empty()))
    }
  })
}

///|
fn branch[A, B, C](
  self : Gen[Either[A, B]],
  l : Gen[(A) -> C],
  r : Gen[(B) -> C]
) -> Gen[C] {
  let left = self.fmap(fn(x) { x.fmap(Either::Left) })
  let right = l.fmap(fn(g) { fn(x) { Right(g(x)) } })
  select(r, select(right, left))
}

///|
pub fn ifS[T](self : Gen[Bool], t : Gen[T], e : Gen[T]) -> Gen[T] {
  let const_ = fn(x) { fn(_y) { x } }
  branch(
    self.fmap(fn(x) { if x { Left(()) } else { Right(()) } }),
    t.fmap(const_),
    e.fmap(const_),
  )
}

///|
pub fn apS[A, B](self : Gen[(A) -> B], x : Gen[A]) -> Gen[B] {
  x.fmap(fn(y) { fn(g) { g(y) } }).select(self.fmap(Either::Left))
}
