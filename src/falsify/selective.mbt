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
/// Selective applicative `select`: if `e` yields `Left(a)`, apply the
/// function from `self` to `a`; if it yields `Right(b)`, skip `self`
/// entirely and return `b`. This is what lets Falsify shrink only the
/// sample-tree branches that actually influenced the result.
///
/// Reference: Andrey Mokhov et al., _Selective applicative functors_,
/// ICFP 2019. DOI 10.1145/3342521.
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
/// Selective `branch`: pick between two continuations based on which
/// side of `Either` the scrutinee produces. `self` picks the side,
/// `l` / `r` are the two continuations — only the taken branch is
/// influenced by the sample tree when shrinking.
pub fn[A, B, C] Gen::branch(
  self : Gen[Either[A, B]],
  l : Gen[(A) -> C],
  r : Gen[(B) -> C],
) -> Gen[C] {
  let left = self.fmap(fn(x) { x.fmap(fn(v) { Either::Left(v) }) })
  let right = l.fmap(fn(g) { fn(x) { Right(g(x)) } })
  r.select(right.select(left))
}

///|
/// Selective `if`: run `self`, then run `t` if it was `true` or `e`
/// if it was `false`. Only the chosen branch's sample tree is
/// considered during shrinking.
pub fn[T] Gen::ifS(self : Gen[Bool], t : Gen[T], e : Gen[T]) -> Gen[T] {
  let const_ = fn(x) { fn(_y : Unit) { x } }
  self
  .fmap(fn(x) { if x { Left(()) } else { Right(()) } })
  .branch(t.fmap(const_), e.fmap(const_))
}

///|
/// Selective applicative-apply: like `ap`, but expressed via
/// `select`, so it participates in the same "only shrink the branch
/// that influenced the result" optimisation.
pub fn[A, B] Gen::apS(self : Gen[(A) -> B], x : Gen[A]) -> Gen[B] {
  x.fmap(fn(y) { fn(g) { g(y) } }).select(self.fmap(fn(v) { Left(v) }))
}
