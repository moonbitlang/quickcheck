///|
priv enum ShrinkHistory[P, N] {
  ShrinkTo(P, ShrinkHistory[P, N])
  ShrinkDone(Iter[N])
  ShrinkStopped
} derive(Show)

///|
struct ShrinkExplain[P, N] {
  initial : P
  history : ShrinkHistory[P, N]
} derive(Show)

///|
pub fn[P, N] ShrinkExplain::limit_steps(
  self : ShrinkExplain[P, N],
  n : Int?,
) -> ShrinkExplain[P, N] {
  fn go(n : Int, history : ShrinkHistory[P, N]) -> ShrinkHistory[P, N] {
    match (n, history) {
      (0, ShrinkTo(_, _)) => ShrinkStopped
      (n, ShrinkTo(x, xs)) => ShrinkTo(x, go(n - 1, xs))
      (_, ShrinkDone(xs)) => ShrinkDone(xs)
      (_, ShrinkStopped) => ShrinkStopped
    }
  }

  match n {
    None => self
    Some(n) => { ..self, history: go(n, self.history) }
  }
}

///|
pub fn[P, N] ShrinkExplain::shrink_history(
  self : ShrinkExplain[P, N],
) -> Array[P] {
  let arr = [self.initial]
  loop self.history {
    ShrinkTo(x, xs) => {
      arr.push(x)
      continue xs
    }
    _ => ()
  }
  arr
}

///|
pub fn[P, N] ShrinkExplain::shrink_outcome(
  self : ShrinkExplain[P, N],
) -> (P, Iter[N]?) {
  loop (self.initial, self.history) {
    (_, ShrinkTo(p, h)) => continue (p, h)
    (p, ShrinkDone(ns)) => (p, Some(ns))
    (p, ShrinkStopped) => (p, None)
  }
}

// Shrinking

///|
enum IsValidShrink[P, N] {
  Valid(P)
  Invalid(N)
}

///|
fn[A, B, C] either(f : (A) -> C, g : (B) -> C) -> (Result[A, B]) -> C {
  fn(result : Result[A, B]) -> C {
    match result {
      Ok(x) => f(x)
      Err(y) => g(y)
    }
  }
}

///|

///|
fn[T, E] partition_result(val : Iter[Result[T, E]]) -> (Iter[T], Iter[E]) {
  fn left(a : T) -> ((Iter[T], Iter[E])) -> (Iter[T], Iter[E]) {
    fn(p) {
      let (l, r) = p
      (Iter::concat(Iter::singleton(a), l), r)
    }
  }

  fn right(a : E) -> ((Iter[T], Iter[E])) -> (Iter[T], Iter[E]) {
    fn(p) {
      let (l, r) = p
      (l, Iter::concat(Iter::singleton(a), r))
    }
  }

  let r = either(left, right)
  Iter::fold(
    val,
    fn(acc, item) { r(item)(acc) },
    init=(Iter::empty(), Iter::empty()),
  )
}

///|
pub fn[A, P, N] Gen::shrink_from(
  self : Gen[A],
  prop : (A) -> IsValidShrink[P, N],
  ps : (P, Iter[SampleTree]),
) -> ShrinkExplain[P, N] {
  let (p, shrunk) = ps
  fn consider(ak) {
    let (a, shrunk) = ak
    match prop(a) {
      Valid(p) => Ok((p, shrunk))
      Invalid(n) => Err(n)
    }
  }

  fn go(shrunk : Iter[SampleTree]) -> ShrinkHistory[P, N] {
    let candidates = shrunk.map(fn(x) { self.run_gen(x) |> consider })
    let res = partition_result(candidates)
    match res.0.head() {
      None => ShrinkDone(res.1)
      Some((p, shrunk)) => ShrinkTo(p, go(shrunk))
    }
  }

  { initial: p, history: go(shrunk) }
}

///|
pub fn[T] shrink_to_list(val : T, xs : Iter[T]) -> Gen[T] {
  let shrinker = fn(s) {
    match s {
      Shrunk(_) => Iter::empty()
      NotShrunk(_) => abort("todo")
      // @lazy.zip_with(fn(x, _y) { x }, @lazy.infinite_stream(0U, 1), xs)
    }
  }
  let aux = fn(s) {
    match s {
      NotShrunk(_) => val
      Shrunk(i) => xs.drop(i.reinterpret_as_int()).head().unwrap()
    }
  }
  prim_with(shrinker).fmap(aux)
}

///|
/// (a -> b) -> ShrinkExplanation p a -> ShrinkExplanation p b
fn[P, M, N] ShrinkHistory::h_fmap(
  self : ShrinkHistory[P, M],
  f : (M) -> N,
) -> ShrinkHistory[P, N] {
  match self {
    ShrinkStopped => ShrinkStopped
    ShrinkDone(x) => ShrinkDone(x.map(f))
    ShrinkTo(p, xs) => ShrinkTo(p, xs.h_fmap(f))
  }
}

///|
fn[P, M, N] ShrinkExplain::e_fmap(
  self : ShrinkExplain[P, M],
  f : (M) -> N,
) -> ShrinkExplain[P, N] {
  { initial: self.initial, history: self.history.h_fmap(f) }
}
