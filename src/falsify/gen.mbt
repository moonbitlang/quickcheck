///|

///|
struct Gen[T] {
  run_gen : (SampleTree) -> (T, Iter[SampleTree])
}

///|
pub fn[T] new(g : (SampleTree) -> (T, Iter[SampleTree])) -> Gen[T] {
  { run_gen: g }
}

///|
pub fn[T] Gen::run_gen(self : Gen[T], x : SampleTree) -> (T, Iter[SampleTree]) {
  (self.run_gen)(x)
}

///|
pub fn[T, U] Gen::fmap(self : Gen[T], f : (T) -> U) -> Gen[U] {
  new(fn(x) {
    let (v, rest) = self.run_gen(x)
    (f(v), rest)
  })
}

///|
pub fn[T] pure(v : T) -> Gen[T] {
  new(fn(_x) { (v, Iter::empty()) })
}

///|
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
pub fn[T, U] Gen::bind(self : Gen[T], f : (T) -> Gen[U]) -> Gen[U] {
  new(fn(st) {
    let (s, l, r) = st.view()
    let (a, ls) = self.run_gen(l)
    let (b, rs) = f(a).run_gen(r)
    (b, combine_shrunk(s, l, r, ls, rs))
  })
}

///|
pub fn[T, U] Gen::ap(self : Gen[(T) -> U], g : Gen[T]) -> Gen[U] {
  self.bind(fn(f) { g.bind(fn(x) { pure(f(x)) }) })
}

///|
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
pub fn prim() -> Gen[UInt] {
  prim_with(fn(s) { s.sample_value() |> binary() }).fmap(Sample::sample_value)
}
