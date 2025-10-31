// Selective Applicative Functor

///|
enum Either[L, R] {
  Left(L)
  Right(R)
}

///|
fn[L, R, S] Either::fmap(self : Either[L, R], f : (R) -> S) -> Either[L, S] {
  match self {
    Right(r) => Right(f(r))
    Left(l) => Left(l)
  }
}

///|
pub fn[T, U] Gen::select(self : Gen[(T) -> U], e : Gen[Either[T, U]]) -> Gen[U] {
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
pub fn[A, B, C] Gen::branch(
  self : Gen[Either[A, B]],
  l : Gen[(A) -> C],
  r : Gen[(B) -> C],
) -> Gen[C] {
  let left = self.fmap(fn(x) { x.fmap(Either::Left(_)) })
  let right = l.fmap(fn(g) { fn(x) { Right(g(x)) } })
  r.select(right.select(left))
}

///|
pub fn[T] Gen::ifS(self : Gen[Bool], t : Gen[T], e : Gen[T]) -> Gen[T] {
  let const_ = fn(x) { fn(_y : Unit) { x } }
  self
  .fmap(fn(x) { if x { Left(()) } else { Right(()) } })
  .branch(t.fmap(const_), e.fmap(const_))
}

///|
pub fn[A, B] Gen::apS(self : Gen[(A) -> B], x : Gen[A]) -> Gen[B] {
  x.fmap(fn(y) { fn(g) { g(y) } }).select(self.fmap(Either::Left(_)))
}
