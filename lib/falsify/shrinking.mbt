enum ShrinkHistroy[P, N] {
  ShrinkTo(P, ShrinkHistroy[P, N])
  ShrinkDone(@lazy.LazyList[N])
  ShrinkStopped
} derive(Show)

struct ShrinkExplain[P, N] {
  initial : P
  history : ShrinkHistroy[P, N]
} derive(Show)

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

pub fn shrink_outcome[P, N](
  self : ShrinkExplain[P, N]
) -> (P, @lazy.LazyList[N]?) {
  loop self.initial, self.history {
    _, ShrinkTo(p, h) => continue p, h
    p, ShrinkDone(ns) => (p, Some(ns))
    p, ShrinkStopped => (p, None)
  }
}

// Shrinking

enum IsValidShrink[P, N] {
  Valid(P)
  Invalid(N)
}

fn either[A, B, C](f : (A) -> C, g : (B) -> C) -> (Result[A, B]) -> C {
  fn {
    Ok(x) => f(x)
    Err(y) => g(y)
  }
}

typealias Ret[T, E] = ((LazyList[T], LazyList[E])) -> (LazyList[T], LazyList[E])

fn partition_result[T, E](
  val : LazyList[Result[T, E]]
) -> (LazyList[T], LazyList[E]) {
  fn left(a : T) -> Ret[T, E] {
    fn { (l, r) => (@lazy.Cons(a, fn() { l }), r) }
  }

  fn right(a : E) -> Ret[T, E] {
    fn { (l, r) => (l, @lazy.Cons(a, fn() { r })) }
  }

  let r = either(left, right)
  @lazy.fold_right(val, @tuple.uncurry(r), init=(Nil, Nil))
}

pub fn shrink_from[A, P, N](
  self : Gen[A],
  prop : (A) -> IsValidShrink[P, N],
  ps : (P, LazyList[SampleTree])
) -> ShrinkExplain[P, N] {
  let (p, shrunk) = ps
  fn go(shrunk : @lazy.LazyList[SampleTree]) -> ShrinkHistroy[P, N] {
    let candidates = shrunk.map(fn(x) { self.run_gen(x) |> consider })
    match partition_result(candidates) {
      (Nil, rej) => ShrinkDone(rej)
      (Cons((p, shrunk), _), _) => ShrinkTo(p, go(shrunk))
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

pub fn shrink_to_list[T](val : T, xs : @lazy.LazyList[T]) -> Gen[T] {
  fn shrinker {
    Shrunk(_) => @lazy.Nil
    NotShrunk(_) =>
      @lazy.zip_with(fn(x, y) { x }, @lazy.infinite_uint(0, 1), xs)
  }

  fn aux {
    NotShrunk(_) => val
    Shrunk(i) => xs.index(i.to_int())
  }

  prim_with(shrinker).fmap(aux)
}
