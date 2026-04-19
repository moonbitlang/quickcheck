///|
pub using @splitmix {type RandomState}

///|
/// The Gen type represents a generator of values of type T.
pub struct Gen[T] {
  priv gen : (Int, RandomState) -> T

  fn[T] new(gen : (Int, RandomState) -> T) -> Gen[T]
}

///|
/// Build a `Gen[T]` from a `(size, rng) -> T` function. In most cases
/// you can use the primary constructor syntax `Gen(f)` instead — both
/// produce an identical generator.
pub fn[T] Gen::new(gen : (Int, RandomState) -> T) -> Gen[T] {
  { gen, }
}

///|
/// Spawn a new generator from an arbitrary instance
pub fn[T : @coreqc.Arbitrary] Gen::spawn() -> Gen[T] {
  Gen(T::arbitrary)
}

///|
/// Generate a value from an enumerable instance (up to a size bound)
/// @alert unsafe "Experimental: May cause stack overflow"
pub fn[T : @feat.Enumerable] Gen::feat_random(size : Int) -> Gen[T] {
  let { fCard, fIndex } = T::enumerate().sample_finite(size)
  guard fCard != 0 else { abort("uniform: empty enumeration") }
  integer_bound(fCard).fmap(fIndex)
}

///|
/// Run a generator with a size and random state
pub fn[T] Gen::run(self : Gen[T], i : Int, rs : RandomState) -> T {
  (self.gen)(i, rs)
}

///|
/// Generate a value from a generator
pub fn[T] Gen::sample(
  self : Gen[T],
  size? : Int = 100,
  seed? : UInt64 = 37,
) -> T {
  let state = @splitmix.new(seed~)
  self.run(size, state)
}

///|
/// Generate an array of samples from a generator
pub fn[T] Gen::samples(
  self : Gen[T],
  size? : Int = 10,
  seed? : UInt64 = 37,
) -> Array[T] {
  let state = @splitmix.new(seed~)
  Array::makei(size, _ => self.run(size, state))
}

///|
/// Functor instance for Gen[T] (pure)
///
/// ```mbt check
/// test {
///   // A pure generator ignores size and rng and always yields the value.
///   assert_eq(pure(42).sample(), 42)
///   assert_eq(pure("hi").sample(), "hi")
/// }
/// ```
pub fn[T] pure(val : T) -> Gen[T] {
  Gen((_, _) => val)
}

///|
/// Functor instance for Gen[T] (fmap)
///
/// ```mbt check
/// test {
///   let doubled = pure(21).fmap(x => x * 2)
///   assert_eq(doubled.sample(), 42)
/// }
/// ```
pub fn[T, U] Gen::fmap(self : Gen[T], f : (T) -> U) -> Gen[U] {
  Gen((n, s) => f(self.run(n, s)))
}

///|
/// Applicative Functor instance for Gen[T]
pub fn[T, U] Gen::ap(self : Gen[(T) -> U], v : Gen[T]) -> Gen[U] {
  self.bind(f => v.bind(x => pure(f(x))))
}

///|
/// Monad instance for Gen[T]
///
/// ```mbt check
/// test {
///   // Use bind to sequence generators: first pick `n`, then draw an
///   // `n`-element list of the fixed value 0.
///   let g = pure(3).bind(n => pure(0).list_with_size(n))
///   inspect(g.sample(), content="@list.from_array([0, 0, 0])")
/// }
/// ```
pub fn[T, U] Gen::bind(self : Gen[T], f : (T) -> Gen[U]) -> Gen[U] {
  Gen((n, s) => {
    let s2 = s.split()
    let t = self.run(n, s)
    f(t).run(n, s2)
  })
}

///|
/// Monadic `join`: collapse `Gen[Gen[T]]` to `Gen[T]` by running the
/// outer generator to produce an inner generator, then running the
/// inner one.
pub fn[T] Gen::join(self : Gen[Gen[T]]) -> Gen[T] {
  self.bind(x => x)
}

///|
/// Lift a binary function to generators
pub fn[A, B, C] liftA2(f : (A, B) -> C, v : Gen[A], w : Gen[B]) -> Gen[C] {
  v.bind(x => w.bind(y => pure(f(x, y))))
}

///|
/// Lift a ternary function to generators
pub fn[A, B, C, D] liftA3(
  f : (A, B, C) -> D,
  v : Gen[A],
  w : Gen[B],
  x : Gen[C],
) -> Gen[D] {
  v.bind(a => w.bind(b => x.bind(c => pure(f(a, b, c)))))
}

///|
/// Lift a quaternary function to generators
pub fn[A, B, C, D, E] liftA4(
  f : (A, B, C, D) -> E,
  v : Gen[A],
  w : Gen[B],
  x : Gen[C],
  y : Gen[D],
) -> Gen[E] {
  v.bind(a => w.bind(b => x.bind(c => y.bind(d => pure(f(a, b, c, d))))))
}

///|
/// Lift a quinary function to generators
pub fn[A, B, C, D, E, F] liftA5(
  f : (A, B, C, D, E) -> F,
  v : Gen[A],
  w : Gen[B],
  x : Gen[C],
  y : Gen[D],
  z : Gen[E],
) -> Gen[F] {
  v.bind(a => {
    w.bind(b => x.bind(c => y.bind(d => z.bind(e => pure(f(a, b, c, d, e))))))
  })
}

///|
/// Lift a senary function to generators
pub fn[A, B, C, D, E, F, G] liftA6(
  ff : (A, B, C, D, E, F) -> G,
  v : Gen[A],
  w : Gen[B],
  x : Gen[C],
  y : Gen[D],
  z : Gen[E],
  u : Gen[F],
) -> Gen[G] {
  v.bind(a => {
    w.bind(b => {
      x.bind(c => {
        y.bind(d => z.bind(e => u.bind(f => pure(ff(a, b, c, d, e, f)))))
      })
    })
  })
}

/// Common Combinators

///|
/// Create tuple generator from two generators
///
/// ```mbt check
/// test {
///   let g : Gen[(Int, String)] = tuple(pure(7), pure("x"))
///   assert_eq(g.sample(), (7, "x"))
/// }
/// ```
pub fn[T, U] tuple(gen1 : Gen[T], gen2 : Gen[U]) -> Gen[(T, U)] {
  gen1.bind(x => gen2.fmap(y => (x, y)))
}

///|
/// Create triple generator from three generators
pub fn[T, U, V] triple(
  gen1 : Gen[T],
  gen2 : Gen[U],
  gen3 : Gen[V],
) -> Gen[(T, U, V)] {
  gen1.bind(x => gen2.bind(y => gen3.fmap(z => (x, y, z))))
}

///|
/// Create quad generator from four generators
pub fn[T, U, V, W] quad(
  gen1 : Gen[T],
  gen2 : Gen[U],
  gen3 : Gen[V],
  gen4 : Gen[W],
) -> Gen[(T, U, V, W)] {
  gen1.bind(x => gen2.bind(y => gen3.bind(z => gen4.fmap(w => (x, y, z, w)))))
}

///|
/// Create sized generators
pub fn[T] sized(f : (Int) -> Gen[T]) -> Gen[T] {
  Gen((i, rs) => f(i).run(i, rs))
}

///|
/// Adjust the size parameter of a generator
pub fn[T] Gen::scale(self : Gen[T], f : (Int) -> Int) -> Gen[T] {
  Gen((i, rs) => self.run(f(i), rs))
}

///|
/// Resize a generator to a specific value
pub fn[T] Gen::resize(self : Gen[T], size : Int) -> Gen[T] {
  self.scale(_ => size)
}

///|
/// Attempt to generate a value that satisfies a predicate
/// If failures reach the maximum size, return None
pub fn[T] Gen::such_that_maybe(self : Gen[T], pred : (T) -> Bool) -> Gen[T?] {
  fn attempt(m, n) {
    if m > n {
      pure(None)
    } else {
      self
      .resize(m)
      .bind(x => if pred(x) { x |> Some |> pure } else { attempt(m + 1, n) })
    }
  }

  sized(n => attempt(n, 2 * n))
}

///|
/// Generate a value that satisfies a predicate
pub fn[T] Gen::such_that(self : Gen[T], pred : (T) -> Bool) -> Gen[T] {
  self
  .such_that_maybe(pred)
  .bind(res => {
    match res {
      None => sized(n => self.such_that(pred).resize(n + 1))
      Some(x) => pure(x)
    }
  })
}

///|
fn uint_bound(bound : UInt) -> Gen[UInt] {
  if bound == 0 {
    pure(0)
  } else {
    Gen((_, rs) => rs.next_uint() % bound)
  }
}

///|
fn[T] sum_backtrack_weights(gs : Array[(UInt, Gen[T?])]) -> UInt {
  // gs.map(gw => gw.0).fold((acc, x) => acc + x, init=0)
  for pair in gs; acc = 0U {
    let (w, _) = pair
    continue acc + w
  } nobreak {
    acc
  }
}

///|
/// Pick one weighted bucket from `xs` given the threshold `n`.
///
/// Think of `xs` as a stack of intervals laid end-to-end on the number
/// line: element `i` occupies `[S_i, S_i + k_i)` where
/// `S_i = k_0 + k_1 + ... + k_{i-1}` and `k_i = xs[i].0`. Iterates in
/// order, subtracting `k` from `n` until `n < k` — at that point `n`
/// falls inside the current bucket and we return `(k, x)`.
///
/// If `n >= sum(k_i)` (threshold past the end) or `xs` is empty, falls
/// through to `(0, def)`. The weight `0` doubles as a sentinel meaning
/// "ran off the end, `def` used".
///
/// Buckets with `k_i == 0` are transparently skipped: `n < 0` is false
/// for `UInt`, so the loop advances with `n` unchanged.
///
/// Complexity: O(i+1) comparisons for the landing index `i`, no
/// allocation (iterating an `ArrayView` is in-place).
fn[T] pick(
  def : Gen[T],
  xs : ArrayView[(UInt, Gen[T])],
  n : UInt,
) -> (UInt, Gen[T]) {
  for pair in xs; n = n {
    let (k, x) = pair
    if n < k {
      break (k, x)
    }
    continue n - k
  } nobreak {
    (0, def)
  }
}

///|
/// Weighted pick *with* removal: returns the picked bucket plus the
/// remaining buckets, in original order. Used by `backtrack` to retry
/// the unused generators when the picked one discards its sample.
///
/// Selection semantics are identical to `pick`: given `gs` of length
/// `m` and threshold `n`, walk `gs` from left to right, subtracting each
/// `k_i` from `n` until `n < k_i`. Suppose that happens at index `i`;
/// the result is
///
///     (k_i, g_i, [..gs[:i], ..gs[i+1:]])
///
/// — the picked bucket plus everything else in original order, built
/// from two `ArrayView` slices in a single array-literal allocation.
///
/// Edge cases:
/// - `m == 1`, `n < k_0`: both spread slices are empty, `rest = []`.
/// - `i == 0`: the `gs[:0]` slice is empty, `rest = gs[1:]`.
/// - `i == m - 1`: the `gs[m:]` slice is empty, `rest = gs[:m-1]`.
/// - Zero-weight buckets are skipped for the same reason as `pick`.
/// - `n` past the total (or `gs` empty): falls through to
///   `(0, pure(None), [])`.
///
/// Complexity: O(m) — one scan to locate `i`, one array-literal
/// allocation of length `m - 1` for `rest`. The previous recursive
/// version was O(m²) because it called `tail.to_array()` at every
/// recursive step and then re-prepended the head on the way up.
fn[T] pick_drop(
  gs : Array[(UInt, Gen[T?])],
  n : UInt,
) -> (UInt, Gen[T?], Array[(UInt, Gen[T?])]) {
  for i, pair in gs; n = n {
    let (k, g) = pair
    if n < k {
      let rest = [..gs[:i], ..gs[i + 1:]]
      break (k, g, rest)
    }
    continue n - k
  } nobreak {
    (0, pure(None), [])
  }
}

///|
fn[T] backtrack_fuel(
  fuel : Int,
  tot : UInt,
  gs : Array[(UInt, Gen[T?])],
) -> Gen[T?] {
  if fuel <= 0 || tot == 0 {
    pure(None)
  } else {
    uint_bound(tot).bind(n => {
      let (k, g, rest) = pick_drop(gs, n)
      g.bind(ma => {
        match ma {
          Some(a) => pure(Some(a))
          None => backtrack_fuel(fuel - 1, tot - k, rest)
        }
      })
    })
  }
}

///|
/// Tries weighted optional generators without replacement until one succeeds.
pub fn[T] backtrack(gs : Array[(UInt, Gen[T?])]) -> Gen[T?] {
  backtrack_fuel(gs.length(), sum_backtrack_weights(gs), gs)
}

///|
/// Chooses one of the given generators, with a weighted random distribution.
/// @alert unsafe "Panics if the array is empty or total weight is zero"
///
/// ```mbt check
/// test {
///   // 90% chance of "common", 10% chance of "rare". With a fixed seed
///   // the draws are deterministic — over 10 samples we expect mostly
///   // "common".
///   let g = frequency([(9U, pure("common")), (1U, pure("rare"))])
///   for x in g.samples() {
///     assert_true(x == "common" || x == "rare")
///   }
/// }
/// ```
pub fn[T] frequency(arr : Array[(UInt, Gen[T])]) -> Gen[T] {
  if arr.is_empty() {
    abort("frequency: empty array")
  } else {
    let sum = for pair in arr; acc = 0U {
      let (w, _) = pair
      continue acc + w
    } nobreak {
      acc
    }
    if sum == 0 {
      abort("frequency: total weight is zero")
    } else {
      let def = arr[0].1
      uint_bound(sum).bind(k => {
        let (_w, g) = pick(def, arr, k)
        g
      })
    }
  }
}

///|
/// Chooses one of the given generators, with a weighted random distribution.
/// @alert unsafe "Panics if the list is empty or total weight is zero"
pub fn[T] frequency_list(lst : @list.List[(UInt, T)]) -> Gen[T] {
  // Single-pass build instead of `.to_array().map(...)` (two arrays).
  let arr : Array[(UInt, Gen[T])] = []
  for pair in lst {
    let (w, v) = pair
    arr.push((w, pure(v)))
  }
  frequency(arr)
}

///|
/// Generate a list of elements from individual generators
pub fn[T] flatten_list(lst : @list.List[Gen[T]]) -> Gen[@list.List[T]] {
  match lst {
    Empty => pure(@list.empty())
    More(x, tail=xs) => liftA2(@list.List::add, flatten_list(xs), x)
  }
}

///|
/// Generate an array of elements from individual generators
pub fn[T] flatten_array(arr : Array[Gen[T]]) -> Gen[Array[T]] {
  Gen((i, rs) => Array::makei(arr.length(), j => arr[j].run(i, rs)))
}

///|
/// Generate an option from an optional generator
pub fn[T] flatten_option(opt : Gen[T]?) -> Gen[T?] {
  match opt {
    None => pure(None)
    Some(x) => x.fmap(v => Some(v))
  }
}

///|
/// Generate a result of a generator or return the pure error
pub fn[T, E] flatten_result(res : Result[Gen[T], E]) -> Gen[Result[T, E]] {
  match res {
    Ok(x) => x.fmap(v => Ok(v))
    Err(e) => pure(Err(e))
  }
}

///|
/// Randomly uses one of the given generators.
/// @alert unsafe "Panics if the array is empty"
///
/// ```mbt check
/// test {
///   let g = one_of([pure(1), pure(2), pure(3)])
///   for x in g.samples() {
///     assert_true(x == 1 || x == 2 || x == 3)
///   }
/// }
/// ```
pub fn[T] one_of(arr : Array[Gen[T]]) -> Gen[T] {
  int_bound(arr.length()).bind(x => arr[x])
}

///|
/// Randomly uses one of the given generators in list
/// @alert unsafe "Panics if the list is empty"
pub fn[T] one_of_list(lst : @list.List[T]) -> Gen[T] {
  int_bound(lst.length()).fmap(x => lst.unsafe_nth(x))
}

///|
/// Randomly select one element from an array
/// @alert unsafe "Panics if the array is empty"
pub fn[T] one_of_array(val : Array[T]) -> Gen[T] {
  int_bound(val.length()).fmap(x => val[x])
}

///|
/// Primitive Generators and Combinators
pub fn small_int() -> Gen[Int] {
  Gen((_, rs) => {
    let p = rs.next_double()
    if p < 0.75 {
      rs.next_int() % 11
    } else {
      rs.next_int() % 97
    }
  })
}

///|
/// Generate a small natural number with heavier weight on smaller
/// values: 50% draw in `[0, 10)`, 25% in `[10, 100)`, 20% in
/// `[100, 1000)`, 5% in `[1000, 10_000)`.
pub fn nat() -> Gen[Int] {
  Gen((_, rs) => {
    let p = rs.next_double()
    if p < 0.5 {
      rs.next_int() % 10
    } else if p < 0.75 {
      rs.next_int() % 100
    } else if p < 0.95 {
      rs.next_int() % 1000
    } else {
      rs.next_int() % 10000
    }
  })
}

///|
/// Generates a negative integer
pub fn neg_int() -> Gen[Int] {
  Gen((_, rs) => -rs.next_int().abs())
}

///|
/// Generates a numeral char
pub fn numeral() -> Gen[Char] {
  Gen((_, rs) => Int::unsafe_to_char(rs.next_int().abs() % 10 + 48))
}

///|
/// Generates alphabet
pub fn alphabet() -> Gen[Char] {
  Gen((_, rs) => Int::unsafe_to_char(rs.next_int().abs() % 26 + 65))
}

///|
/// Generates int within given bound [0, bound)
///
/// ```mbt check
/// test {
///   for x in int_bound(100).samples() {
///     assert_true(x >= 0 && x < 100)
///   }
/// }
/// ```
pub fn int_bound(bound : Int) -> Gen[Int] {
  if bound == 0 {
    pure(0)
  } else {
    Gen((_, rs) => rs.next_int().abs() % bound)
  }
}

///|
/// Generates integer within given bound [0, bound)
pub fn integer_bound(bound : BigInt) -> Gen[BigInt] {
  if bound == 0 {
    pure(0)
  } else {
    Gen((_, rs) => BigInt::from_int64(rs.next_int64().abs()) % bound)
  }
}

///|
/// Generates int within given range [lo, hi)
///
/// ```mbt check
/// test {
///   let g = int_range(10, 20)
///   for x in g.samples() {
///     assert_true(x >= 10 && x < 20)
///   }
/// }
/// ```
pub fn int_range(lo : Int, hi : Int) -> Gen[Int] {
  guard lo != hi else { pure(lo) }
  Gen((_, rs) => {
    let j = rs.next_int().abs() % (hi - lo)
    j + lo
  })
}

///|
/// Generate char within given range [lo, hi]
pub fn char_range(lo : Char, hi : Char) -> Gen[Char] {
  int_range(lo.to_int(), hi.to_int() + 1).fmap(Int::unsafe_to_char)
}

///|
/// Lift a per-element generator to a generator of lists with exactly
/// `size` elements (fixed length, independent draws).
///
/// ```mbt check
/// test {
///   let g = pure(42).list_with_size(3)
///   inspect(g.sample(), content="@list.from_array([42, 42, 42])")
/// }
/// ```
pub fn[T] Gen::list_with_size(gen : Gen[T], size : Int) -> Gen[@list.List[T]] {
  for n = size, acc = pure(@list.empty()) {
    if n <= 0 {
      break acc
    } else {
      continue n - 1, liftA2(@list.List::add, acc, gen)
    }
  }
}

///|
/// Generate a sorted `List[T]` of exactly `size` elements — draws
/// `size` independent values from `gen`, then sorts.
pub fn[T : Compare] sorted_list(size : Int, gen : Gen[T]) -> Gen[@list.List[T]] {
  gen.list_with_size(size).fmap(@list.List::sort)
}

///|
/// Generate a sorted `Array[T]` of exactly `size` elements. Array
/// counterpart of `sorted_list`.
pub fn[T : Compare] sorted_array(size : Int, gen : Gen[T]) -> Gen[Array[T]] {
  gen.array_with_size(size).fmap(a => a..sort())
}

///|
/// Lift a per-element generator to a generator of arrays with exactly
/// `size` elements. Each element is drawn independently from the same
/// sample tree.
///
/// ```mbt check
/// test {
///   let g = pure(0).array_with_size(4)
///   assert_eq(g.sample(), [0, 0, 0, 0])
/// }
/// ```
pub fn[T] Gen::array_with_size(self : Gen[T], size : Int) -> Gen[Array[T]] {
  Gen((i, rs) => Array::makei(size, _ => self.run(i, rs)))
}

// --- boundary tests for pick / pick_drop -----------------------------------

///|
test "pick selects first element when weight < first k" {
  let gs : Array[(UInt, Gen[Int])] = [
    (1, pure(10)),
    (2, pure(20)),
    (3, pure(30)),
  ]
  let (k, _g) = pick(pure(-1), gs, 0)
  assert_eq(k, 1)
}

///|
test "pick selects last element at upper boundary" {
  let gs : Array[(UInt, Gen[Int])] = [
    (1, pure(10)),
    (2, pure(20)),
    (3, pure(30)),
  ]
  // 0, 1, 2 exhaust the first two; 3 lands in the third (card 3).
  let (k, _g) = pick(pure(-1), gs, 3)
  assert_eq(k, 3)
}

///|
test "pick falls through to default when weight exceeds total" {
  let gs : Array[(UInt, Gen[Int])] = [(1, pure(10)), (2, pure(20))]
  let (k, _g) = pick(pure(-1), gs, 100)
  assert_eq(k, 0)
}

///|
test "pick on empty view returns default with zero weight" {
  let gs : Array[(UInt, Gen[Int])] = []
  let (k, _g) = pick(pure(-1), gs, 0)
  assert_eq(k, 0)
}

///|
test "pick_drop picks first element and keeps the tail" {
  let gs : Array[(UInt, Gen[Int?])] = [
    (1, pure(Some(10))),
    (2, pure(Some(20))),
    (3, pure(Some(30))),
  ]
  let (k, _g, rest) = pick_drop(gs, 0)
  assert_eq(k, 1)
  assert_eq(rest.length(), 2)
  // Rest preserves the original order, sans the picked element.
  assert_eq(rest[0].0, 2)
  assert_eq(rest[1].0, 3)
}

///|
test "pick_drop picks last element and keeps the prefix" {
  let gs : Array[(UInt, Gen[Int?])] = [
    (1, pure(Some(10))),
    (2, pure(Some(20))),
    (3, pure(Some(30))),
  ]
  let (k, _g, rest) = pick_drop(gs, 3)
  assert_eq(k, 3)
  assert_eq(rest.length(), 2)
  assert_eq(rest[0].0, 1)
  assert_eq(rest[1].0, 2)
}

///|
test "pick_drop picks middle element and splices the rest" {
  let gs : Array[(UInt, Gen[Int?])] = [
    (1, pure(Some(10))),
    (2, pure(Some(20))),
    (3, pure(Some(30))),
  ]
  let (k, _g, rest) = pick_drop(gs, 1)
  assert_eq(k, 2)
  assert_eq(rest.length(), 2)
  assert_eq(rest[0].0, 1)
  assert_eq(rest[1].0, 3)
}

///|
test "pick_drop on a singleton array leaves rest empty" {
  let gs : Array[(UInt, Gen[Int?])] = [(5, pure(Some(10)))]
  let (k, _g, rest) = pick_drop(gs, 0)
  assert_eq(k, 5)
  assert_eq(rest.length(), 0)
}

///|
test "pick_drop falls through when weight exceeds total" {
  let gs : Array[(UInt, Gen[Int?])] = [(1, pure(Some(10))), (2, pure(Some(20)))]
  let (k, _g, rest) = pick_drop(gs, 100)
  assert_eq(k, 0)
  assert_eq(rest.length(), 0)
}
