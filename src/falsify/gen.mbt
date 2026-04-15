///|

///|
/// A Falsify generator: a function from a `SampleTree` (the source of
/// randomness) to `(value, shrunk alternatives)`. The deterministic
/// mapping is what makes shrinking "free" — to minimise a failing
/// case, the driver mutates the sample tree and re-runs the same
/// `Gen`, so every shrunk value is guaranteed to be in the
/// generator's support.
struct Gen[T] {
  run_gen : (SampleTree) -> (T, Iter[SampleTree])
}

///|
/// Build a `Gen[T]` from a raw `SampleTree -> (T, Iter[SampleTree])`
/// function. Escape hatch — prefer the high-level combinators
/// (`pure`, `fmap`, `bind`, `prim`) when possible; using `new`
/// directly means you take on responsibility for threading shrink
/// trees correctly.
pub fn[T] new(g : (SampleTree) -> (T, Iter[SampleTree])) -> Gen[T] {
  { run_gen: g }
}

///|
/// Drive the generator against a sample tree: returns `(value, shrunk)`
/// where `shrunk` is the iter of alternative sample trees the driver
/// should try if this value falsifies the property.
pub fn[T] Gen::run_gen(self : Gen[T], x : SampleTree) -> (T, Iter[SampleTree]) {
  (self.run_gen)(x)
}

///|
/// Functor `fmap`: transform the generated value without touching the
/// shrink set. Shrinks go through unchanged.
pub fn[T, U] Gen::fmap(self : Gen[T], f : (T) -> U) -> Gen[U] {
  new(fn(x) {
    let (v, rest) = self.run_gen(x)
    (f(v), rest)
  })
}

///|
/// The constant generator: always yields `v`, never shrinks.
pub fn[T] pure(v : T) -> Gen[T] {
  new(fn(_x) { (v, Iter::empty()) })
}

///|
/// Compose two shrink-tree iters under the current sample. The
/// left-branch candidates are wrapped into new `SampleTree` nodes
/// that replace the left child with each shrunk variant (keeping the
/// original right child); the right-branch candidates are currently
/// only used as *signals* that further shrinking is possible — the
/// emitted tree keeps the original right child regardless. A
/// `Minimal` short-cut is prepended when either side has at least
/// one candidate so the driver can jump to the all-minimal case
/// quickly. Used internally by `bind`, `ap`, and the selective
/// combinators.
pub fn combine_shrunk(
  s : Sample,
  l : SampleTree,
  r : SampleTree,
  ls : Iter[SampleTree],
  rs : Iter[SampleTree],
) -> Iter[SampleTree] {
  fn shortcut(st : Iter[SampleTree]) -> Iter[SampleTree] {
    match st.head() {
      None => Iter::empty()
      _ => Iter::concat(Iter::singleton(Minimal), st)
    }
  }

  fn unless_minimal(st : SampleTree, l : Iter[SampleTree]) -> Iter[SampleTree] {
    match (st, l) {
      (Minimal, _) => Iter::empty()
      (_, ts) => ts
    }
  }

  unless_minimal(l, ls)
  .map(fn(l1) {
    SampleTree(s, @lazy.LazyRef::from_value(l1), @lazy.LazyRef::from_value(r))
  })
  .concat(
    unless_minimal(r, rs).map(fn(_r1) {
      SampleTree(s, @lazy.LazyRef::from_value(l), @lazy.LazyRef::from_value(r))
    }),
  )
  |> shortcut
}

///|
/// Monadic bind: pass the generated value through `f` to pick the
/// next generator. The sample tree is split (via `view`) so each
/// stage draws from an independent sub-tree, and the returned shrink
/// set is composed with `combine_shrunk`.
pub fn[T, U] Gen::bind(self : Gen[T], f : (T) -> Gen[U]) -> Gen[U] {
  new(fn(st) {
    let (s, l, r) = st.view()
    let (a, ls) = self.run_gen(l)
    let (b, rs) = f(a).run_gen(r)
    (b, combine_shrunk(s, l, r, ls, rs))
  })
}

///|
/// Applicative apply: analogue of `Gen[(T) -> U].ap(Gen[T])`. Uses
/// `bind` under the hood, so it inherits the same sample-tree
/// splitting and shrink composition.
pub fn[T, U] Gen::ap(self : Gen[(T) -> U], g : Gen[T]) -> Gen[U] {
  self.bind(fn(f) { g.bind(fn(x) { pure(f(x)) }) })
}

///|
/// Low-level primitive with a custom shrink function. `f` receives
/// the current `Sample` and returns the iter of shrink values to try;
/// those get wrapped in `Shrunk(u)` sub-trees so the driver can
/// distinguish them from the original draw.
pub fn prim_with(f : (Sample) -> Iter[UInt]) -> Gen[Sample] {
  new(fn(x) {
    let (s, l, r) = x.view()
    (
      s,
      f(s).map(fn(s1) {
        SampleTree(
          Shrunk(s1),
          @lazy.LazyRef::from_value(l),
          @lazy.LazyRef::from_value(r),
        )
      }),
    )
  })
}

///|
/// The canonical primitive generator: draw one `UInt` from the root
/// of the sample tree and expose the standard "binary towards zero"
/// shrink sequence.
pub fn prim() -> Gen[UInt] {
  prim_with(fn(s) { s.sample_value() |> binary() }).fmap(Sample::sample_value)
}
