pub typealias LazyList[T] = @lazy.LazyList[T]

struct Gen[T] {
  run_gen : (SampleTree) -> (T, LazyList[SampleTree])
}

pub fn new[T](g : (SampleTree) -> (T, LazyList[SampleTree])) -> Gen[T] {
  { run_gen: g }
}

pub fn run_gen[T](self : Gen[T], x : SampleTree) -> (T, LazyList[SampleTree]) {
  (self.run_gen)(x)
}

pub fn fmap[T, U](self : Gen[T], f : (T) -> U) -> Gen[U] {
  new(
    fn(x) {
      let (v, rest) = self.run_gen(x)
      (f(v), rest)
    },
  )
}

pub fn pure[T](v : T) -> Gen[T] {
  new(fn(_x) { (v, Nil) })
}

pub fn combine_shrunk(
  s : Sample,
  l : SampleTree,
  r : SampleTree,
  ls : @lazy.LazyList[SampleTree],
  rs : @lazy.LazyList[SampleTree]
) -> @lazy.LazyList[SampleTree] {
  fn shortcut(st : @lazy.LazyList[SampleTree]) -> @lazy.LazyList[SampleTree] {
    match st {
      Nil => Nil
      ts => Cons(Minimal, fn() { ts })
    }
  }

  fn unless_minimal(
    st : SampleTree,
    l : @lazy.LazyList[SampleTree]
  ) -> @lazy.LazyList[SampleTree] {
    match (st, l) {
      (Minimal, _) => Nil
      (_, ts) => ts
    }
  }

  unless_minimal(l, ls)
  .map(fn(l1) { SampleTree(s, fn() { l1 }, fn() { r }) })
  .concat(
    unless_minimal(r, rs).map(fn(r1) { SampleTree(s, fn() { l }, fn() { r1 }) }),
  )
  |> shortcut
}

pub fn bind[T, U](self : Gen[T], f : (T) -> Gen[U]) -> Gen[U] {
  new(
    fn(st) {
      let (s, l, r) = st.view()
      let (a, ls) = self.run_gen(l)
      let (b, rs) = f(a).run_gen(r)
      (b, combine_shrunk(s, l, r, ls, rs))
    },
  )
}

pub fn ap[T, U](self : Gen[(T) -> U], g : Gen[T]) -> Gen[U] {
  self.bind(fn(f) { g.bind(fn(x) { pure(f(x)) }) })
}

pub fn prim_with(f : (Sample) -> @lazy.LazyList[UInt]) -> Gen[Sample] {
  new(
    fn(x) {
      let (s, l, r) = x.view()
      (s, f(s).map(fn(s1) { SampleTree(Shrunk(s1), fn() { l }, fn() { r }) }))
    },
  )
}

pub fn prim() -> Gen[UInt] {
  prim_with(fn(s) {
    sample_value(s) |> binary
  }).fmap(sample_value)
}