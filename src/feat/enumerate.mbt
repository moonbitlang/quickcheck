///|
/// A size-indexed enumeration backed by an implicit finite sequence for each
/// size. This is the feat_moon representation: `run(size)` returns the part
/// of all values whose constructor-cost is exactly `size`.
struct Enumerate[T] {
  run : (Int) -> @ifseq.Seq[T]
  prefix_totals : Array[BigInt]
}

///|
fn[T] delay(thunk : () -> T) -> () -> T {
  let cache : Array[T] = []
  fn() {
    if cache.length() == 0 {
      let value = thunk()
      cache.push(value)
      value
    } else {
      cache[0]
    }
  }
}

///|
fn[T] make(run : (Int) -> @ifseq.Seq[T]) -> Enumerate[T] {
  let cache : Map[Int, @ifseq.Seq[T]] = Map([])
  fn memoized(size : Int) -> @ifseq.Seq[T] {
    match cache.get(size) {
      Some(seq) => seq
      None => {
        let seq = run(size)
        cache.set(size, seq)
        seq
      }
    }
  }
  { run: memoized, prefix_totals: [0] }
}

///|
/// Return the finite sequence for one exact size.
pub fn[T] part(e : Enumerate[T], size : Int) -> @ifseq.Seq[T] {
  (e.run)(size)
}

///|
/// Empty enumeration.
pub fn[T] empty() -> Enumerate[T] {
  make(fn(_size) { @ifseq.empty() })
}

///|
/// Enumeration containing one value at size zero.
pub fn[T] singleton(x : T) -> Enumerate[T] {
  make(fn(size) { if size == 0 { @ifseq.singleton(x) } else { @ifseq.empty() } })
}

///|
/// Lift one implicit finite sequence into the size-zero part.
pub fn[T] of_seq(xs : @ifseq.Seq[T]) -> Enumerate[T] {
  make(fn(size) { if size == 0 { xs } else { @ifseq.empty() } })
}

///|
/// Shift all parts by one size unit. Recursive `Enumerable` instances should
/// guard self references with `pay`.
pub fn[T] pay(e : () -> Enumerate[T]) -> Enumerate[T] {
  let force = delay(e)
  make(fn(size) {
    if size == 0 {
      @ifseq.empty()
    } else {
      part(force(), size - 1)
    }
  })
}

///|
/// Pointwise disjoint union of two enumerations.
pub fn[T] sum(e1 : Enumerate[T], e2 : Enumerate[T]) -> Enumerate[T] {
  make(fn(size) { @ifseq.sum(part(e1, size), part(e2, size)) })
}

///|
pub impl[T] Add for Enumerate[T] with fn add(self, other) {
  sum(self, other)
}

///|
/// Existential choice over a finite list: union all enumerations from `xs`.
pub fn[A, B] exists(
  xs : @list.List[A],
  f : (A) -> Enumerate[B],
) -> Enumerate[B] {
  make(fn(size) {
    xs.fold(init=@ifseq.empty(), fn(acc, x) {
      @ifseq.sum(acc, part(f(x), size))
    })
  })
}

///|
/// Cartesian product by size convolution.
pub fn[A, B] product(e1 : Enumerate[A], e2 : Enumerate[B]) -> Enumerate[(A, B)] {
  make(fn(size) {
    if size < 0 {
      @ifseq.empty()
    } else {
      let parts = Array::makei(size + 1, fn(left) {
        let right = size - left
        @ifseq.product(part(e1, left), part(e2, right))
      })
      @ifseq.bigsum(parts)
    }
  })
}

///|
/// Product variant that only pairs equal or adjacent component sizes.
pub fn[A, B] balanced_product(
  e1 : Enumerate[A],
  e2 : Enumerate[B],
) -> Enumerate[(A, B)] {
  make(fn(size) {
    if size < 0 {
      @ifseq.empty()
    } else if size % 2 == 0 {
      let half = size / 2
      @ifseq.product(part(e1, half), part(e2, half))
    } else {
      let half = size / 2
      @ifseq.sum(
        @ifseq.product(part(e1, half), part(e2, half + 1)),
        @ifseq.product(part(e1, half + 1), part(e2, half)),
      )
    }
  })
}

///|
/// Map a function over every value without changing part sizes.
pub fn[A, B] map(f : (A) -> B, e : Enumerate[A]) -> Enumerate[B] {
  make(fn(size) { @ifseq.map(f, part(e, size)) })
}

///|
/// Method form of `map`.
pub fn[A, B] Enumerate::fmap(self : Enumerate[A], f : (A) -> B) -> Enumerate[B] {
  map(f, self)
}

///|
/// Enumerate a unary constructor over its argument type.
pub fn[A : Enumerable, B] unary(f : (A) -> B) -> Enumerate[B] {
  A::enumerate().fmap(f)
}

///|
/// Pay one size unit for a list of constructor alternatives.
pub fn[T] consts(xs : @list.List[Enumerate[T]]) -> Enumerate[T] {
  pay(fn() { xs.fold(init=empty(), fn(acc, x) { sum(acc, x) }) })
}

///|
/// Enumerate a finite list of values at size zero.
pub fn[T] finite(xs : @list.List[T]) -> Enumerate[T] {
  xs.fold(init=empty(), fn(acc, x) { sum(acc, singleton(x)) })
}

///|
/// Explicit memoized fixpoint helper for recursive enumerations.
pub fn[T] fix(f : (Enumerate[T]) -> Enumerate[T]) -> Enumerate[T] {
  let cache : Map[Int, @ifseq.Seq[T]] = Map([])
  let body_cache : Array[Enumerate[T]] = []
  fn run(size : Int) -> @ifseq.Seq[T] {
    match cache.get(size) {
      Some(seq) => seq
      None => {
        let body = if body_cache.length() == 0 {
          let e = f(make(run))
          body_cache.push(e)
          e
        } else {
          body_cache[0]
        }
        let seq = part(body, size)
        cache.set(size, seq)
        seq
      }
    }
  }
  make(run)
}

///|
fn[T] Enumerate::ensure_prefix_covers(
  self : Enumerate[T],
  idx : BigInt,
) -> Unit {
  for total = self.prefix_totals[self.prefix_totals.length() - 1] {
    if idx < total {
      break
    } else {
      let size = self.prefix_totals.length() - 1
      let next = total + @ifseq.length(part(self, size))
      self.prefix_totals.push(next)
      continue next
    }
  }
}

///|
fn find_part(prefix_totals : Array[BigInt], idx : BigInt) -> Int {
  for low = 0, high = prefix_totals.length() - 1 {
    if low + 1 >= high {
      break low
    } else {
      let mid = low + (high - low) / 2
      if prefix_totals[mid] <= idx {
        continue mid, high
      } else {
        continue low, mid
      }
    }
  }
}

///|
/// Return the `idx`-th value globally, skipping whole size parts by length.
#alias("_[_]")
#alias(en_index, deprecated="Use `_[_]` instead")
pub fn[T] Enumerate::at(self : Enumerate[T], idx : BigInt) -> T {
  if idx < 0 {
    abort("index out of bounds")
  } else {
    self.ensure_prefix_covers(idx)
    let size = find_part(self.prefix_totals, idx)
    @ifseq.get(part(self, size), idx - self.prefix_totals[size])
  }
}

///|
/// Sampling domain used by `feat_random`. It aggregates parts below
/// the bound; if all are empty, it expands until the first non-empty prefix.
pub fn[T] Enumerate::sample_finite(
  self : Enumerate[T],
  size : Int,
) -> @ifseq.Seq[T] {
  fn aggregate(start : Int, stop : Int) -> @ifseq.Seq[T] {
    if start < stop {
      @ifseq.sum(part(self, start), aggregate(start + 1, stop))
    } else {
      @ifseq.empty()
    }
  }
  for bound = (if size < 0 { 0 } else { size }) {
    let seq = aggregate(0, bound)
    if @ifseq.length(seq) == 0 {
      continue bound + 1
    } else {
      break seq
    }
  }
}
