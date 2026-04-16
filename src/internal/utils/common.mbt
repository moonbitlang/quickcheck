///|
let global_counter : Ref[Int] = @ref.new(0)

// Generate a fresh name

///|
/// Generate a process-global monotonically-unique string of the form
/// `"test-0"`, `"test-1"`, `"test-2"`, … Useful when a test needs *some*
/// unique label and the specific value does not matter (e.g. when
/// creating disposable temp directories or sentinel identifiers).
///
/// The counter is shared across all callers in the same process, so
/// concurrent tests observe interleaved names and the numeric suffix
/// is *not* a stable handle — don't pattern-match on it.
pub fn fresh_name() -> String {
  let counter = global_counter.val
  global_counter.update(fn(x) { x + 1 })
  "test-" + counter.to_string()
}

///|
/// Chunk-wise removal for list shrinkers.
///
/// Given `xs` of length `n`, walk it in blocks of `k` and emit one
/// variant per non-empty tail chunk, each variant formed by
/// concatenating the prefix seen so far with the suffix after the
/// dropped chunk:
///
///     removes_list(2, 6, [1, 2, 3, 4, 5, 6])
///     == [[3, 4, 5, 6], [1, 2, 5, 6]]
///
/// The final chunk is never a variant — removing it would leave the
/// list unchanged on the prefix side. When `k > n` the result is empty.
///
/// Part of the classical QuickCheck list shrinker: combining the
/// outputs for different chunk sizes produces a "halve toward empty"
/// shrinking strategy.
pub fn[T] removes_list(
  k : Int,
  n : Int,
  xs : @list.List[T],
) -> @list.List[@list.List[T]] {
  if k > n {
    @list.empty()
  } else {
    let xs_drop = xs.drop(k)
    if xs_drop.is_empty() {
      @list.empty()
    } else {
      let xs_take = xs.take(k)
      removes_list(k, n - k, xs_drop)
      .map(fn(x) { xs_take.concat(x) })
      .add(xs_drop)
    }
  }
}

///|
/// Array-shaped counterpart of `removes_list`. Same chunk-wise
/// semantics: emit one `xs[:i] ++ xs[i+k:]` per chunk boundary `i`,
/// skipping the trailing chunk whose removal would leave the prefix
/// unchanged.
pub fn[T] removes_array(k : Int, n : Int, xs : Array[T]) -> Array[Array[T]] {
  if k > n {
    []
  } else {
    let xs2 = xs[:k].to_array()
    let xs1 = xs[k:].to_array()
    if xs1.is_empty() {
      []
    } else {
      [xs1, ..removes_array(k, n - k, xs1).map(fn(x) { xs2 + x })]
    }
  }
}

///|
/// Repeatedly apply `f` starting from `x`, collecting every successor
/// for which `cond` still holds. The first value (`x` itself) is *not*
/// included; iteration stops the first time `cond(f(acc))` is false.
///
/// **Order**: results are accumulated by prepending, so the list is
/// returned in *reverse* iteration order — the last kept value first.
/// A `halve-toward-zero` usage looks like
///
///     apply_while_list(16, z => z / 2, z => z > 0)
///     // yields [1, 2, 4, 8]   -- note: 1 is newest, 8 is oldest
pub fn[T] apply_while_list(
  x : T,
  f : (T) -> T,
  cond : (T) -> Bool,
) -> @list.List[T] {
  for acc = x, lst = @list.empty() {
    let next = f(acc)
    if cond(next) {
      continue next, lst.add(next)
    } else {
      break lst
    }
  }
}

///|
/// Array-shaped counterpart of `apply_while_list`. Same reverse-order
/// accumulation: newest-kept value first, oldest last.
pub fn[T] apply_while_array(
  x : T,
  f : (T) -> T,
  cond : (T) -> Bool,
) -> Array[T] {
  for acc = x, lst = [] {
    let next = f(acc)
    if cond(next) {
      continue next, [next, ..lst]
    } else {
      break lst
    }
  }
}

///|
/// The identity function: returns its argument unchanged. Bound to the
/// `%identity` intrinsic, so it compiles to a no-op.
pub fn[T] id(x : T) -> T = "%identity"

///|
/// `const_(t)` is the constant function at `t`: it ignores whatever
/// argument it receives and returns `t`. Typical use is currying away
/// an unused parameter, e.g. `scale(const_(10))` fixes the size at 10.
pub fn[T, U] const_(t : T) -> (U) -> T {
  fn(_) { t }
}

///|
/// Deprecated. Inline as `tuple => f(tuple.0, tuple.1)` at the call
/// site — the helper saves no characters and obscures the shape.
#deprecated("Inline `tuple => f(tuple.0, tuple.1)` at the call site")
pub fn[A, B, C] pair_function(f : (A, B) -> C) -> ((A, B)) -> C {
  tuple => f(tuple.0, tuple.1)
}

///|
/// Swap the argument order of a binary function:
/// `flip(f)(y, x) == f(x, y)`. Used where a combinator takes a binary
/// callback in the "wrong" order for a particular idiom.
pub fn[M, N, Z] flip(f : (M, N) -> Z) -> (N, M) -> Z {
  fn(x, y) { f(y, x) }
}
