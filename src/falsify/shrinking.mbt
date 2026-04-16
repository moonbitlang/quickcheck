///|
priv enum ShrinkHistory[P, N] {
  ShrinkTo(P, ShrinkHistory[P, N])
  ShrinkDone(Iter[N])
  ShrinkStopped
}

///|
impl[P : Show, N : Show] Show for ShrinkHistory[P, N] with output(self, logger) {
  match self {
    ShrinkTo(p, rest) => {
      logger.write_string("ShrinkTo(")
      p.output(logger)
      logger.write_string(", ")
      rest.output(logger)
      logger.write_string(")")
    }
    ShrinkDone(iter) => {
      logger.write_string("ShrinkDone(")
      iter.output(logger)
      logger.write_string(")")
    }
    ShrinkStopped => logger.write_string("ShrinkStopped")
  }
}

///|
struct ShrinkExplain[P, N] {
  initial : P
  history : ShrinkHistory[P, N]
}

///|
impl[P : Show, N : Show] Show for ShrinkExplain[P, N] with output(self, logger) {
  logger
  ..write_string("{initial: ")
  ..write_object(self.initial)
  ..write_string(", history: ")
  ..write_object(self.history)
  .write_string("}")
}

///|
/// Truncate the shrink history to at most `n` steps. Replaces any
/// `ShrinkTo(_, …)` beyond that depth with `ShrinkStopped`. Used by
/// the driver to cap the amount of shrink work reported. Passing
/// `None` is a no-op (keep the full history).
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
/// Flatten the shrink record to just the sequence of visited values,
/// starting with the initial counter-example and ending with the
/// last successfully-shrunk value. Useful for logging a minimal
/// trace of the shrink search.
pub fn[P, N] ShrinkExplain::shrink_history(
  self : ShrinkExplain[P, N],
) -> Array[P] {
  let arr = [self.initial]
  for cur = self.history {
    match cur {
      ShrinkTo(x, xs) => {
        arr.push(x)
        continue xs
      }
      _ => break
    }
  }
  arr
}

///|
/// Reduce the shrink record to its endpoint: the final value and
/// — if the search ran to exhaustion — the iter of candidates that
/// were rejected at that step. A `None` second component means the
/// search was cut short (`limit_steps`) rather than finishing
/// naturally.
pub fn[P, N] ShrinkExplain::shrink_outcome(
  self : ShrinkExplain[P, N],
) -> (P, Iter[N]?) {
  for p = self.initial, h = self.history {
    match h {
      ShrinkTo(next_p, next_h) => continue next_p, next_h
      ShrinkDone(ns) => break (p, Some(ns))
      ShrinkStopped => break (p, None)
    }
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
  (result : Result[A, B]) => {
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
    p => {
      let (l, r) = p
      (Iter::concat(Iter::singleton(a), l), r)
    }
  }

  fn right(a : E) -> ((Iter[T], Iter[E])) -> (Iter[T], Iter[E]) {
    p => {
      let (l, r) = p
      (l, Iter::concat(Iter::singleton(a), r))
    }
  }

  let r = either(left, right)
  Iter::fold(
    val,
    (acc, item) => r(item)(acc),
    init=(Iter::empty(), Iter::empty()),
  )
}

///|
/// The shrink-search driver: starting from counter-example `p` and
/// the candidate sample trees `shrunk`, re-run `self` against every
/// candidate, partition the results into valid / invalid shrinks,
/// and step to the *head* of the valid set (whose order is
/// determined by `partition_result`'s prepending fold — effectively
/// "last valid shrink explored is stepped to"). Recurse until no
/// valid shrink remains. The full trail is recorded in the returned
/// `ShrinkExplain`.
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
    let candidates = shrunk.map(x => self.run_gen(x) |> consider)
    let res = partition_result(candidates)
    match res.0.head() {
      None => ShrinkDone(res.1)
      Some((p, shrunk)) => ShrinkTo(p, go(shrunk))
    }
  }

  { initial: p, history: go(shrunk) }
}

///|
/// Build a generator whose only value is `val` and whose shrink set
/// is the fixed `xs`. Useful when you need a hand-picked shrink
/// sequence rather than the default "binary towards zero" one.
///
/// **Caveat**: the `NotShrunk` branch is currently an unimplemented
/// `todo` — the generator only exposes the shrink set via the
/// `Shrunk(i)` path. Stick to `prim` / `pure` / `bind` if you need
/// full coverage.
pub fn[T] shrink_to_list(val : T, xs : Iter[T]) -> Gen[T] {
  let shrinker = s => {
    match s {
      Shrunk(_) => Iter::empty()
      NotShrunk(_) => abort("todo")
      // @lazy.zip_with((x, _y) => x, @lazy.infinite_stream(0U, 1), xs)
    }
  }
  let aux = s => {
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
