///|
enum SampleTree {
  SampleTree(Sample, @lazy.LazyRef[SampleTree], @lazy.LazyRef[SampleTree])
  Minimal
}

///|
enum Sample {
  NotShrunk(UInt)
  Shrunk(UInt)
}

///|
pub fn sample_value(self : Sample) -> UInt {
  match self {
    NotShrunk(x) => x
    Shrunk(x) => x
  }
}

///|
pub fn view(self : SampleTree) -> (Sample, SampleTree, SampleTree) {
  match self {
    Minimal => (Shrunk(0), Minimal, Minimal)
    SampleTree(x, l, r) => (x, l.force(), r.force())
  }
}

// Note that SampleTree is implemented Lense

///|
pub(all) typealias RandomState = @quickcheck/splitmix.RandomState

///|
pub fn from_rng(rs : RandomState) -> SampleTree {
  let n = rs.next_uint()
  let l = rs.split()
  SampleTree(
    NotShrunk(n),
    from_rng(l) |> @lazy.LazyRef::from_value,
    from_rng(rs) |> @lazy.LazyRef::from_value,
  )
}

///|
pub fn from_seed(seed : UInt64) -> SampleTree {
  from_rng(@quickcheck/splitmix.new(seed~))
}

///|
pub fn constant(val : UInt) -> SampleTree {
  SampleTree(
    NotShrunk(val),
    constant(val) |> @lazy.LazyRef::from_value,
    constant(val) |> @lazy.LazyRef::from_value,
  )
}

///|
pub fn map(self : SampleTree, f : (UInt) -> UInt) -> SampleTree {
  fn map_shrunk(self : Sample) -> Sample {
    match self {
      NotShrunk(x) => NotShrunk(f(x))
      Shrunk(x) => Shrunk(f(x))
    }
  }

  match self {
    Minimal => Minimal
    SampleTree(x, l, r) =>
      SampleTree(
        map_shrunk(x),
        l.force().map(f) |> @lazy.LazyRef::from_value,
        r.force().map(f) |> @lazy.LazyRef::from_value,
      )
  }
}

///|
pub fn mod(self : SampleTree, u : UInt) -> SampleTree {
  map(self, fn(x) { x % u })
}

///|
pub fn sample[T](self : Gen[T]) -> T {
  let s = RandomState::new()
  let (x, _shrunk) = self.run_gen(from_rng(s))
  x
}
