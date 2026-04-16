///|
/// A lazy list of `Finite[T]` parts, one part per size class.
///
/// Conceptually: `Enumerate[T]` partitions the type `T` by a user-
/// chosen notion of "size" (usually one unit per constructor, charged
/// via `pay`). Part `k` is a `Finite[T]` — a cardinality plus an
/// indexer — covering every value of size `k`. The outer `LazyList`
/// can be infinite: `T = List[E]` has parts at every size, no bound.
///
/// Invariants (preserved by the provided combinators):
/// - every part has `fCard >= 0`;
/// - recursive references are guarded by `pay` so forcing the outer
///   list is productive;
/// - each part's `fIndex` is total on `[0, fCard)`.
pub(all) struct Enumerate[T] {
  parts : LazyList[Finite[T]]
}

///|
/// Expose the underlying size-indexed parts. Callers typically use
/// this together with `Finite::to_array` to materialise every value
/// of a specific size.
pub fn[T] Enumerate::eval(self : Enumerate[T]) -> LazyList[Finite[T]] {
  self.parts
}

///|
/// The empty enumeration: no values at any size. Identity for `union`.
pub fn[T] empty() -> Enumerate[T] {
  { parts: Nil }
}

///|
/// One-value enumeration at size 0. Building block for `Enumerable`
/// instances of leaf constructors.
pub fn[T] singleton(val : T) -> Enumerate[T] {
  { parts: Cons(fin_pure(val), @lazy.LazyRef::from_value(Nil)) }
}

///|
/// Return the `i`-th value overall: walk parts from size 0 upward,
/// subtracting each part's cardinality from `idx` until `idx` falls
/// inside the current part, then read the value via `fIndex`.
///
/// **Aborts** on out-of-range indices (reaches `Nil`).
#alias("_[_]")
#alias(en_index,deprecated = "Use `_[_]` instead")
pub fn[T] Enumerate::at(self : Enumerate[T], idx : BigInt) -> T {
  for parts = self.parts, i = idx {
    match parts {
      Nil => abort("index out of bounds")
      Cons(f, rest) =>
        if i < f.fCard {
          break (f.fIndex)(i)
        } else {
          continue rest.force(), i - f.fCard
        }
    }
  }
}

///|
/// Finite sampling domain used by `Gen::feat_random`. It aggregates
/// the first `size` parts; if they are all empty, it continues to the
/// next non-empty part so the result is still finite.
pub fn[T] Enumerate::sample_finite(
  self : Enumerate[T],
  size : Int,
) -> Finite[T] {
  for parts = self.parts, bound = size {
    match parts {
      Nil => break fin_empty()
      _ => {
        let (incl, rest) = parts.split_at(bound)
        let fin = fin_mconcat(incl)
        if fin.fCard == 0 {
          continue rest, 1
        } else {
          break fin
        }
      }
    }
  }
}

///|
/// Interleave two enumerations by size: the `k`-th part of `union(a, b)`
/// is `fin_union(a.parts[k], b.parts[k])`. If one enumeration runs out
/// of parts, the other's remaining parts carry through unchanged.
fn[T] union(e1 : Enumerate[T], e2 : Enumerate[T]) -> Enumerate[T] {
  { parts: @lazy.zip_plus(fin_union, e1.parts, e2.parts) }
}

///|
/// `+` as an alias for `union`.
pub impl[T] Add for Enumerate[T] with add(self, other) {
  union(self, other)
}

///|
/// Rewrite every element without changing the structure: part shapes
/// stay the same, only the inhabitants are relabelled via `f`.
pub fn[T, U] Enumerate::fmap(self : Enumerate[T], f : (T) -> U) -> Enumerate[U] {
  { parts: self.parts.map(fn(x) { fin_fmap(f, x) }) }
}

///|
/// Shift every size class up by one: part `k` of `pay(f)` equals part
/// `k - 1` of `f()`. The outer part `0` becomes empty. **This is the
/// productivity knob** for recursive `Enumerable` instances — every
/// recursive self-reference must be wrapped in `pay` or the fixpoint
/// diverges.
pub fn[T] pay(f : () -> Enumerate[T]) -> Enumerate[T] {
  { parts: Cons(fin_empty(), @lazy.LazyRef::from_thunk(fn() { f().parts })) }
}

///|
/// Cartesian product, keyed by sum of sizes: part `k` of `product(a, b)`
/// contains every pair whose component sizes add to `k`. Order inside
/// a part follows the diagonalisation convention
/// (first by decreasing `a`-size, then by increasing `b`-size).
pub fn[T, U] product(e1 : Enumerate[T], e2 : Enumerate[U]) -> Enumerate[(T, U)] {
  { parts: prod_helper(e1.parts, reversals(e2.parts)) }
}

///|
fn[T, U] prod_helper(
  xs : LazyList[Finite[T]],
  rys : LazyList[LazyList[Finite[U]]],
) -> LazyList[Finite[(T, U)]] {
  rys.map(fn(y) { convolution(xs, y) })
}

///|
/// `pay`-wrapped union of a list of sub-enumerations. Typical use:
/// write one `Enumerate` per constructor of a sum type, then combine
/// with `consts`. The outer `pay` charges one size unit for the
/// constructor tag.
pub fn[T] consts(ls : @list.List[Enumerate[T]]) -> Enumerate[T] {
  pay(fn() { ls.fold(union, init=empty()) })
}

///|
/// Apply a unary constructor: `unary(f) == T::enumerate().fmap(f)`.
/// For multi-argument constructors, wrap via `pair_function` so `f`
/// takes a single tuple argument — then `unary(f)` goes through the
/// built-in pair `Enumerable` instance which inserts the required
/// `pay`.
pub fn[T : Enumerable, U] unary(f : (T) -> U) -> Enumerate[U] {
  T::enumerate().fmap(f)
}
