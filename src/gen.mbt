///|
pub using @splitmix {type RandomState}

///|
/// The Gen type represents a generator of values of type T.
pub struct Gen[T] {
  priv gen : (Int, RandomState) -> T

  fn[T] new(gen : (Int, RandomState) -> T) -> Gen[T]
}

///|
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
  feat_helper(T::enumerate(), size)
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
  Array::makei(size, fn(_x) { self.run(size, state) })
}

///|
/// Helper function for feat_random
fn[T] feat_helper(enumerate : @feat.Enumerate[T], size : Int) -> Gen[T] {
  for parts = enumerate.parts, bound = size {
    match parts {
      Nil => abort("uniform: empty enumeration")
      _ => {
        let (incl, rest) = parts.split_at(bound)
        let fin = @feat.fin_mconcat(incl)
        match fin.fCard {
          0 => continue rest, 1
          _ => break integer_bound(fin.fCard).fmap(fn(i) { (fin.fIndex)(i) })
        }
      }
    }
  }
}

///|
/// Functor instance for Gen[T] (pure)
pub fn[T] pure(val : T) -> Gen[T] {
  Gen(fn(_n, _s) { val })
}

///|
/// Functor instance for Gen[T] (fmap)
pub fn[T, U] Gen::fmap(self : Gen[T], f : (T) -> U) -> Gen[U] {
  Gen(fn(n, s) { f(self.run(n, s)) })
}

///|
/// Applicative Functor instance for Gen[T]
pub fn[T, U] Gen::ap(self : Gen[(T) -> U], v : Gen[T]) -> Gen[U] {
  self.bind(fn(f) { v.bind(fn(x) { pure(f(x)) }) })
}

///|
/// Monad instance for Gen[T]
pub fn[T, U] Gen::bind(self : Gen[T], f : (T) -> Gen[U]) -> Gen[U] {
  Gen(fn(n, s) {
    let s2 = s.split()
    let t = self.run(n, s)
    f(t).run(n, s2)
  })
}

///|
pub fn[T] Gen::join(self : Gen[Gen[T]]) -> Gen[T] {
  self.bind(@utils.id)
}

///|
/// Lift a binary function to generators
pub fn[A, B, C] liftA2(f : (A, B) -> C, v : Gen[A], w : Gen[B]) -> Gen[C] {
  v.bind(fn(x) { w.bind(fn(y) { pure(f(x, y)) }) })
}

///|
/// Lift a ternary function to generators
pub fn[A, B, C, D] liftA3(
  f : (A, B, C) -> D,
  v : Gen[A],
  w : Gen[B],
  x : Gen[C],
) -> Gen[D] {
  v.bind(fn(a) { w.bind(fn(b) { x.bind(fn(c) { pure(f(a, b, c)) }) }) })
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
  v.bind(fn(a) {
    w.bind(fn(b) { x.bind(fn(c) { y.bind(fn(d) { pure(f(a, b, c, d)) }) }) })
  })
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
  v.bind(fn(a) {
    w.bind(fn(b) {
      x.bind(fn(c) {
        y.bind(fn(d) { z.bind(fn(e) { pure(f(a, b, c, d, e)) }) })
      })
    })
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
  v.bind(fn(a) {
    w.bind(fn(b) {
      x.bind(fn(c) {
        y.bind(fn(d) {
          z.bind(fn(e) { u.bind(fn(f) { pure(ff(a, b, c, d, e, f)) }) })
        })
      })
    })
  })
}

///|
fn[T] delay() -> Gen[(Gen[T]) -> T] {
  Gen(fn(n, rs) { fn(g) { g.run(n, rs) } })
}

/// Common Combinators

///|
/// Create tuple generator from two generators
pub fn[T, U] tuple(gen1 : Gen[T], gen2 : Gen[U]) -> Gen[(T, U)] {
  gen1.bind(fn(x) { gen2.fmap(fn(y) { (x, y) }) })
}

///|
/// Create triple generator from three generators
pub fn[T, U, V] triple(
  gen1 : Gen[T],
  gen2 : Gen[U],
  gen3 : Gen[V],
) -> Gen[(T, U, V)] {
  gen1.bind(fn(x) { gen2.bind(fn(y) { gen3.fmap(fn(z) { (x, y, z) }) }) })
}

///|
/// Create quad generator from four generators
pub fn[T, U, V, W] quad(
  gen1 : Gen[T],
  gen2 : Gen[U],
  gen3 : Gen[V],
  gen4 : Gen[W],
) -> Gen[(T, U, V, W)] {
  gen1.bind(fn(x) {
    gen2.bind(fn(y) { gen3.bind(fn(z) { gen4.fmap(fn(w) { (x, y, z, w) }) }) })
  })
}

///|
/// Create sized generators
pub fn[T] sized(f : (Int) -> Gen[T]) -> Gen[T] {
  Gen(fn(i, rs) { f(i).run(i, rs) })
}

///|
/// Adjust the size parameter of a generator
pub fn[T] Gen::scale(self : Gen[T], f : (Int) -> Int) -> Gen[T] {
  Gen(fn(i, rs) { self.run(f(i), rs) })
}

///|
/// Resize a generator to a specific value
pub fn[T] Gen::resize(self : Gen[T], size : Int) -> Gen[T] {
  self.scale(fn(_n) { size })
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
      .bind(fn(x) {
        if pred(x) {
          x |> Some |> pure
        } else {
          attempt(m + 1, n)
        }
      })
    }
  }

  sized(fn(n) { attempt(n, 2 * n) })
}

///|
/// Generate a value that satisfies a predicate
pub fn[T] Gen::such_that(self : Gen[T], pred : (T) -> Bool) -> Gen[T] {
  self
  .such_that_maybe(pred)
  .bind(fn(res) {
    match res {
      None => sized(fn(n) { self.such_that(pred).resize(n + 1) })
      Some(x) => pure(x)
    }
  })
}

///|
fn uint_bound(bound : UInt) -> Gen[UInt] {
  if bound == 0 {
    pure(0)
  } else {
    Gen(fn(_i, rs) { rs.next_uint() % bound })
  }
}

///|
fn[T] sum_backtrack_weights(gs : Array[(UInt, Gen[T?])]) -> UInt {
  gs.map(fn(gw) { gw.0 }).fold(fn(acc, x) { acc + x }, init=0)
}

///|
fn[T] pick(
  def : Gen[T],
  xs : Array[(UInt, Gen[T])],
  n : UInt,
) -> (UInt, Gen[T]) {
  match xs[:] {
    [] => (0, def)
    [head, .. tail] => {
      let (k, x) = head
      if n < k {
        (k, x)
      } else {
        pick(def, tail.to_array(), n - k)
      }
    }
  }
}

///|
fn[T] pick_drop(
  gs : Array[(UInt, Gen[T?])],
  n : UInt,
) -> (UInt, Gen[T?], Array[(UInt, Gen[T?])]) {
  match gs[:] {
    [] => (0, pure(None), [])
    [head, .. tail] => {
      let (k, g) = head
      let tail_arr = tail.to_array()
      if n < k {
        (k, g, tail_arr)
      } else {
        let (k2, g2, tail2) = pick_drop(tail_arr, n - k)
        (k2, g2, [(k, g), ..tail2])
      }
    }
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
    uint_bound(tot).bind(fn(n) {
      let (k, g, rest) = pick_drop(gs, n)
      g.bind(fn(ma) {
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
pub fn[T] frequency(arr : Array[(UInt, Gen[T])]) -> Gen[T] {
  if arr.is_empty() {
    abort("frequency: empty array")
  } else {
    let sum = arr.map(fn(t) { t.0 }).fold(fn(acc, x) { acc + x }, init=0)
    if sum == 0 {
      abort("frequency: total weight is zero")
    } else {
      let def = arr[0].1
      uint_bound(sum).bind(fn(k) {
        let (_w, g) = pick(def, arr, k)
        g
      })
    }
  }
}

///|
/// Chooses one of the given generators, with a weighted random distribution.
/// @alert unsafe "Panics if the list is empty or total weight is zero"
pub fn[T] frequency_list(lst : List[(UInt, T)]) -> Gen[T] {
  lst
  .to_array()
  .map(fn(x) {
    let (w, v) = x
    (w, pure(v))
  })
  |> frequency
}

///|
/// Generate a list of elements from individual generators
pub fn[T] flatten_list(lst : List[Gen[T]]) -> Gen[List[T]] {
  match lst {
    Empty => pure(@list.empty())
    More(x, tail=xs) => liftA2(List::add, flatten_list(xs), x)
  }
}

///|
/// Generate an array of elements from individual generators
pub fn[T] flatten_array(arr : Array[Gen[T]]) -> Gen[Array[T]] {
  Gen(fn(i, rs) { Array::makei(arr.length(), fn(j) { arr[j].run(i, rs) }) })
}

///|
/// Generate an option from an optional generator
pub fn[T] flatten_option(opt : Gen[T]?) -> Gen[T?] {
  match opt {
    None => pure(None)
    Some(x) => x.fmap(fn(v) { Some(v) })
  }
}

///|
/// Generate a result of a generator or return the pure error
pub fn[T, E] flatten_result(res : Result[Gen[T], E]) -> Gen[Result[T, E]] {
  match res {
    Ok(x) => x.fmap(fn(v) { Ok(v) })
    Err(e) => pure(Err(e))
  }
}

///|
/// Randomly uses one of the given generators. 
/// @alert unsafe "Panics if the array is empty"
pub fn[T] one_of(arr : Array[Gen[T]]) -> Gen[T] {
  int_bound(arr.length()).bind(fn(x) { arr[x] })
}

///|
/// Randomly uses one of the given generators in list
/// @alert unsafe "Panics if the list is empty"
pub fn[T] one_of_list(lst : List[T]) -> Gen[T] {
  int_bound(lst.length()).fmap(fn(x) { lst.unsafe_nth(x) })
}

///|
/// Randomly select one element from an array
/// @alert unsafe "Panics if the array is empty"
pub fn[T] one_of_array(val : Array[T]) -> Gen[T] {
  int_bound(val.length()).fmap(fn(x) { val[x] })
}

///|
/// Primitive Generators and Combinators
pub fn small_int() -> Gen[Int] {
  Gen(fn(_i, rs) {
    let p = rs.next_double()
    if p < 0.75 {
      rs.next_int() % 11
    } else {
      rs.next_int() % 97
    }
  })
}

///|
pub fn nat() -> Gen[Int] {
  Gen(fn(_i, rs) {
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
  Gen(fn(_i, rs) { -rs.next_int().abs() })
}

///|
/// Generates a numeral char
pub fn numeral() -> Gen[Char] {
  Gen(fn(_i, rs) { Int::unsafe_to_char(rs.next_int().abs() % 10 + 48) })
}

///|
/// Generates alphabet
pub fn alphabet() -> Gen[Char] {
  Gen(fn(_i, rs) { Int::unsafe_to_char(rs.next_int().abs() % 26 + 65) })
}

///|
/// Generates int within given bound [0, bound)
pub fn int_bound(bound : Int) -> Gen[Int] {
  if bound == 0 {
    pure(0)
  } else {
    Gen(fn(_i, rs) { rs.next_int().abs() % bound })
  }
}

///|
/// Generates integer within given bound [0, bound)
pub fn integer_bound(bound : BigInt) -> Gen[BigInt] {
  if bound == 0 {
    pure(0)
  } else {
    Gen(fn(_i, rs) { BigInt::from_int64(rs.next_int64().abs()) % bound })
  }
}

///|
/// Generates int within given range [lo, hi)
pub fn int_range(lo : Int, hi : Int) -> Gen[Int] {
  guard lo != hi else { pure(lo) }
  Gen(fn(_i, rs) {
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
pub fn[T] Gen::list_with_size(gen : Gen[T], size : Int) -> Gen[List[T]] {
  for n = size, acc = pure(@list.empty()) {
    if n <= 0 {
      break acc
    } else {
      continue n - 1, liftA2(List::add, acc, gen)
    }
  }
}

///|
pub fn[T : Compare] sorted_list(size : Int, gen : Gen[T]) -> Gen[List[T]] {
  gen.list_with_size(size).fmap(List::sort)
}

///|
pub fn[T : Compare] sorted_array(size : Int, gen : Gen[T]) -> Gen[Array[T]] {
  gen.array_with_size(size).fmap(a => a..sort())
}

///|
pub fn[T] Gen::array_with_size(self : Gen[T], size : Int) -> Gen[Array[T]] {
  Gen(fn(i, rs) { Array::makei(size, fn(_j) { self.run(i, rs) }) })
}
