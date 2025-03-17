///|

///|
struct Gen[T] {
  run_gen : (SampleTree) -> (T, Iter[SampleTree])
}

///|
pub fn new[T](g : (SampleTree) -> (T, Iter[SampleTree])) -> Gen[T] {
  { run_gen: g }
}

///|
pub fn run_gen[T](self : Gen[T], x : SampleTree) -> (T, Iter[SampleTree]) {
  (self.run_gen)(x)
}

///|
pub fn fmap[T, U](self : Gen[T], f : (T) -> U) -> Gen[U] {
  new(fn(x) {
    let (v, rest) = self.run_gen(x)
    (f(v), rest)
  })
}

///|
pub fn pure[T](v : T) -> Gen[T] {
  new(fn(_x) { (v, Iter::empty()) })
}

///|
pub fn combine_shrunk(
  s : Sample,
  l : SampleTree,
  r : SampleTree,
  ls : Iter[SampleTree],
  rs : Iter[SampleTree]
) -> Iter[SampleTree] {
  fn shortcut(st : Iter[SampleTree]) -> Iter[SampleTree] {
    match st.head() {
      None => Iter::empty()
      _ => st.prepend(Minimal)
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
pub fn bind[T, U](self : Gen[T], f : (T) -> Gen[U]) -> Gen[U] {
  new(fn(st) {
    let (s, l, r) = st.view()
    let (a, ls) = self.run_gen(l)
    let (b, rs) = f(a).run_gen(r)
    (b, combine_shrunk(s, l, r, ls, rs))
  })
}

///|
pub fn ap[T, U](self : Gen[(T) -> U], g : Gen[T]) -> Gen[U] {
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
  prim_with(fn(s) { sample_value(s) |> binary }).fmap(sample_value)
}
