///|
enum ShrinkHistory[P, N] {
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
pub fn limit_steps[P, N](
  self : ShrinkExplain[P, N],
  n : Int?
) -> ShrinkExplain[P, N] {
  fn go {
    0, ShrinkTo(_) => ShrinkStopped
    n, ShrinkTo(x, xs) => ShrinkTo(x, go(n - 1, xs))
    _, ShrinkDone(xs) => ShrinkDone(xs)
    _, ShrinkStopped => ShrinkStopped
  }

  match n {
    None => self
    Some(n) => { ..self, history: go(n, self.history) }
  }
}

///|
pub fn shrink_history[P, N](self : ShrinkExplain[P, N]) -> Array[P] {
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
pub fn shrink_outcome[P, N](self : ShrinkExplain[P, N]) -> (P, Iter[N]?) {
  loop self.initial, self.history {
    _, ShrinkTo(p, h) => continue p, h
    p, ShrinkDone(ns) => (p, Some(ns))
    p, ShrinkStopped => (p, None)
  }
}

// Shrinking

///|
enum IsValidShrink[P, N] {
  Valid(P)
  Invalid(N)
}

///|
fn either[A, B, C](f : (A) -> C, g : (B) -> C) -> (Result[A, B]) -> C {
  fn {
    Ok(x) => f(x)
    Err(y) => g(y)
  }
}

///|
typealias Ret[T, E] = ((Iter[T], Iter[E])) -> (Iter[T], Iter[E])

///|
fn partition_result[T, E](val : Iter[Result[T, E]]) -> (Iter[T], Iter[E]) {
  fn left(a : T) -> Ret[T, E] {
    fn { (l, r) => (l.prepend(a), r) }
  }

  fn right(a : E) -> Ret[T, E] {
    fn { (l, r) => (l, r.prepend(a)) }
  }

  let r = either(left, right)
  Iter::fold(val, fn(x, y) { r(y)(x) }, init=(Iter::empty(), Iter::empty()))
}

///|
pub fn shrink_from[A, P, N](
  self : Gen[A],
  prop : (A) -> IsValidShrink[P, N],
  ps : (P, Iter[SampleTree])
) -> ShrinkExplain[P, N] {
  let (p, shrunk) = ps
  fn go(shrunk : Iter[SampleTree]) -> ShrinkHistory[P, N] {
    let candidates = shrunk.map(fn(x) { self.run_gen(x) |> consider })
    let res = partition_result(candidates)
    match res.0.head() {
      None => ShrinkDone(res.1)
      Some((p, shrunk)) => ShrinkTo(p, go(shrunk))
    }
  }

  fn consider(ak) {
    let (a, shrunk) = ak
    match prop(a) {
      Valid(p) => Ok((p, shrunk))
      Invalid(n) => Err(n)
    }
  }

  { initial: p, history: go(shrunk) }
}

///|
pub fn shrink_to_list[T](val : T, xs : Iter[T]) -> Gen[T] {
  fn shrinker {
    Shrunk(_) => Iter::empty()
    NotShrunk(_) => abort("todo")
    // @lazy.zip_with(fn(x, _y) { x }, @lazy.infinite_stream(0U, 1), xs)
  }

  fn aux {
    NotShrunk(_) => val
    Shrunk(i) => xs.drop(i.reinterpret_as_int()).head().unwrap()
  }

  prim_with(shrinker).fmap(aux)
}

///| (a -> b) -> ShrinkExplanation p a -> ShrinkExplanation p b
fn h_fmap[P, M, N](
  self : ShrinkHistory[P, M],
  f : (M) -> N
) -> ShrinkHistory[P, N] {
  match self {
    ShrinkStopped => ShrinkStopped
    ShrinkDone(x) => ShrinkDone(x.map(f))
    ShrinkTo(p, xs) => ShrinkTo(p, xs.h_fmap(f))
  }
}

///|
fn e_fmap[P, M, N](
  self : ShrinkExplain[P, M],
  f : (M) -> N
) -> ShrinkExplain[P, N] {
  { initial: self.initial, history: self.history.h_fmap(f) }
}
