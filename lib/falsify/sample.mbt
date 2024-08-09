enum SampleTree {
  SampleTree(Sample, SampleTree, SampleTree)
  Minimal
}

enum Sample {
  NotShrunk(UInt)
  Shrunk(UInt)
}

pub fn sampleValue(self : Sample) -> UInt {
  match self {
    NotShrunk(x) => x
    Shrunk(x) => x
  }
}

pub fn view(self : SampleTree) -> (Sample, SampleTree, SampleTree) {
  match self {
    Minimal => (Shrunk(0), Minimal, Minimal)
    SampleTree(x, l, r) => (x, l, r)
  }
}

// Note that SampleTree is implemented Lense

pub typealias RandomState = @splitmix.RandomState

pub fn from_rng(rs : RandomState) -> SampleTree {
  let n = rs.next_uint()
  let l = rs.split()
  SampleTree(NotShrunk(n), from_rng(l), from_rng(rs))
}

pub fn from_seed(seed : UInt64) -> SampleTree {
  from_rng(@splitmix.new(~seed))
}

pub fn constant(val : UInt) -> SampleTree {
  SampleTree(NotShrunk(val), constant(val), constant(val))
}

pub fn map(self : SampleTree, f : (UInt) -> UInt) -> SampleTree {
  fn mapShrunk(self : Sample) -> Sample {
    match self {
      NotShrunk(x) => NotShrunk(f(x))
      Shrunk(x) => Shrunk(f(x))
    }
  }

  match self {
    Minimal => Minimal
    SampleTree(x, l, r) => SampleTree(mapShrunk(x), l.map(f), r.map(f))
  }
}

pub fn mod(self: SampleTree, u: UInt) -> SampleTree {
  map(self, fn(x) { x % u })
}