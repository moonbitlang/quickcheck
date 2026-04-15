///|
/// An infinite binary tree of `UInt` samples. The root node carries
/// the current draw (`Sample`); the two children are the sub-trees
/// consumed by `bind`-like splits. `Minimal` is the end-of-shrink
/// sentinel — treated as "sample zero, children also minimal".
enum SampleTree {
  SampleTree(Sample, @lazy.LazyRef[SampleTree], @lazy.LazyRef[SampleTree])
  Minimal
}

///|
/// A sampled `UInt` tagged with whether the driver picked it
/// untouched from the RNG (`NotShrunk`) or swapped it in as a shrunk
/// alternative (`Shrunk`). The tag is what lets shrink functions
/// recognise "this is already a shrink candidate, don't propose more
/// from here".
enum Sample {
  NotShrunk(UInt)
  Shrunk(UInt)
}

///|
/// Unwrap the payload, discarding the `NotShrunk`/`Shrunk` tag.
pub fn Sample::sample_value(self : Sample) -> UInt {
  match self {
    NotShrunk(x) => x
    Shrunk(x) => x
  }
}

///|
/// Destructure a sample tree into `(sample, left_child, right_child)`.
/// `Minimal` views as `(Shrunk(0), Minimal, Minimal)`, so user code
/// can inspect any node uniformly.
pub fn SampleTree::view(self : SampleTree) -> (Sample, SampleTree, SampleTree) {
  match self {
    Minimal => (Shrunk(0), Minimal, Minimal)
    SampleTree(x, l, r) => (x, l.force(), r.force())
  }
}

// Note that SampleTree is implemented Lense

///|
/// Re-export: downstream callers speak `@falsify.RandomState`.
pub using @splitmix {type RandomState}

///|
/// Build a sample tree backed by a SplitMix `RandomState`. Each node
/// draws one `UInt`, then splits the RNG for its left child and uses
/// the original for its right child — giving each sub-tree an
/// independent stream.
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
/// Seed the tree from a fixed `UInt64` — convenient for writing
/// reproducible tests.
pub fn from_seed(seed : UInt64) -> SampleTree {
  from_rng(@splitmix.new(seed~))
}

///|
/// Every node carries the same fixed value. Handy for unit-testing
/// generators and for the `Shrunk(0)` baseline.
pub fn constant(val : UInt) -> SampleTree {
  SampleTree(
    NotShrunk(val),
    constant(val) |> @lazy.LazyRef::from_value,
    constant(val) |> @lazy.LazyRef::from_value,
  )
}

///|
/// Map `f` over every sample in the tree, preserving the
/// `NotShrunk`/`Shrunk` tag. `SampleTree::mod` is defined in terms of
/// this.
pub fn SampleTree::map(self : SampleTree, f : (UInt) -> UInt) -> SampleTree {
  fn map_shrunk(x : Sample) -> Sample {
    match x {
      NotShrunk(v) => NotShrunk(f(v))
      Shrunk(v) => Shrunk(f(v))
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
/// Clamp every sample to `[0, u)` by taking it modulo `u`. Useful for
/// turning an arbitrary sample tree into one that stays in range.
pub fn SampleTree::mod(self : SampleTree, u : UInt) -> SampleTree {
  self.map(fn(x) { x % u })
}

///|
/// Draw one value from `self` using a fresh splitmix seed. Primarily
/// a convenience for quick manual sampling in tests.
pub fn[T] Gen::sample(self : Gen[T]) -> T {
  let s = @splitmix.new()
  let (x, _shrunk) = self.run_gen(from_rng(s))
  x
}

///|
