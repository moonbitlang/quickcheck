enum SampleTree {
  SampleTree(Sample, () -> SampleTree, () -> SampleTree)
  Minimal
}

enum Sample {
  NotShrunk(UInt)
  Shrunk(UInt)
}

pub fn sample_value(self : Sample) -> UInt {
  match self {
    NotShrunk(x) => x
    Shrunk(x) => x
  }
}

pub fn view(self : SampleTree) -> (Sample, SampleTree, SampleTree) {
  match self {
    Minimal => (Shrunk(0), Minimal, Minimal)
    SampleTree(x, l, r) => (x, l(), r())
  }
}

// Note that SampleTree is implemented Lense

pub typealias RandomState = @random/splitmix.RandomState

pub fn from_rng(rs : RandomState) -> SampleTree {
  let n = rs.next_uint()
  let l = rs.split()
  SampleTree(NotShrunk(n), fn() { from_rng(l) }, fn() { from_rng(rs) })
}

pub fn from_seed(seed : UInt64) -> SampleTree {
  from_rng(@random/splitmix.new(~seed))
}

pub fn constant(val : UInt) -> SampleTree {
  SampleTree(NotShrunk(val), fn() { constant(val) }, fn() { constant(val) })
}

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
      SampleTree(map_shrunk(x), fn() { l().map(f) }, fn() { r().map(f) })
  }
}

pub fn mod(self : SampleTree, u : UInt) -> SampleTree {
  map(self, fn(x) { x % u })
}

pub fn sample[T](self : Gen[T]) -> T {
  let s = RandomState::new()
  let (x, _shrunk) = self.run_gen(from_rng(s))
  x
}
