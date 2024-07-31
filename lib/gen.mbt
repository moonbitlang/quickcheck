struct Gen[T] {
  gen : (Int, RandomState) -> T
}

pub fn Gen::new[T](gen : (Int, RandomState) -> T) -> Gen[T] {
  { gen, }
}

pub fn Gen::spawn[T : Arbitrary]() -> Gen[T] {
  { gen: T::arbitrary }
}

pub fn feat[T](enumerate : @feat.Enumerate[T], size : Int) -> Gen[T] {
  loop enumerate.parts, size {
    Nil, _ => abort("uniform: empty enumeration")
    ps, maxp => {
      let (incl, rest) = ps.split_at(maxp)
      let fin = incl.fin_mconcat()
      match fin.fCard {
        0 => continue rest, 1
        _ => break int_bound(fin.fCard).fmap(fn(i) { (fin.fIndex)(i) })
      }
    }
  }
}

pub fn Gen::fe[T : @feat.Enumerable](size : Int) -> Gen[T] {
  feat(T::enumerate(), size)
}

test "fe" {
  let fe : Gen[Int] = fe(10)
  inspect!(
    fe.samples(size=50),
    content="[2, 2, -2, 4, 2, 4, -2, 1, -3, -2, -1, 2, 2, -4, 1, -1, -2, -2, -1, 2, -1, 5, 2, 4, -2, 1, -6, -2, 8, 0, 1, 3, 2, 3, -4, 5, 2, 2, 0, 0, 0, 1, 6, 0, -5, 0, 6, -4, -6, 3]",
  )
}

/// Monad
pub fn pure[T](val : T) -> Gen[T] {
  Gen::new(fn(_n, _s) { val })
}

pub fn bind[T, U](self : Gen[T], f : (T) -> Gen[U]) -> Gen[U] {
  Gen::new(
    fn(n, s) {
      let s2 = s.split()
      let t = self.run(n, s)
      f(t).run(n, s2)
    },
  )
}

/// Functor
pub fn fmap[T, U](self : Gen[T], f : (T) -> U) -> Gen[U] {
  Gen::new(fn(n, s) { f(self.run(n, s)) })
}

/// Applicative Functor
pub fn ap[T, U](self : Gen[(T) -> U], v : Gen[T]) -> Gen[U] {
  self.bind(fn(f) { v.bind(fn(x) { pure(f(x)) }) })
}

pub fn liftA2[A, B, C](f : (A, B) -> C, v : Gen[A], w : Gen[B]) -> Gen[C] {
  v.bind(fn(x) { w.bind(fn(y) { pure(f(x, y)) }) })
}

pub fn liftA3[A, B, C, D](
  f : (A, B, C) -> D,
  v : Gen[A],
  w : Gen[B],
  x : Gen[C]
) -> Gen[D] {
  v.bind(fn(a) { w.bind(fn(b) { x.bind(fn(c) { pure(f(a, b, c)) }) }) })
}

pub fn liftA4[A, B, C, D, E](
  f : (A, B, C, D) -> E,
  v : Gen[A],
  w : Gen[B],
  x : Gen[C],
  y : Gen[D]
) -> Gen[E] {
  v.bind(
    fn(a) {
      w.bind(fn(b) { x.bind(fn(c) { y.bind(fn(d) { pure(f(a, b, c, d)) }) }) })
    },
  )
}

pub fn liftA5[A, B, C, D, E, F](
  f : (A, B, C, D, E) -> F,
  v : Gen[A],
  w : Gen[B],
  x : Gen[C],
  y : Gen[D],
  z : Gen[E]
) -> Gen[F] {
  v.bind(
    fn(a) {
      w.bind(
        fn(b) {
          x.bind(
            fn(c) { y.bind(fn(d) { z.bind(fn(e) { pure(f(a, b, c, d, e)) }) }) },
          )
        },
      )
    },
  )
}

pub fn liftA6[A, B, C, D, E, F, G](
  ff : (A, B, C, D, E, F) -> G,
  v : Gen[A],
  w : Gen[B],
  x : Gen[C],
  y : Gen[D],
  z : Gen[E],
  u : Gen[F]
) -> Gen[G] {
  v.bind(
    fn(a) {
      w.bind(
        fn(b) {
          x.bind(
            fn(c) {
              y.bind(
                fn(d) {
                  z.bind(fn(e) { u.bind(fn(f) { pure(ff(a, b, c, d, e, f)) }) })
                },
              )
            },
          )
        },
      )
    },
  )
}

pub fn pair[X, Y](gx : Gen[X], gy : Gen[Y]) -> Gen[(X, Y)] {
  gx.bind(fn(x) { gy.fmap(fn(y) { (x, y) }) })
}

pub fn run[T](self : Gen[T], i : Int, rs : RandomState) -> T {
  (self.gen)(i, rs)
}

pub fn sample[T](self : Gen[T]) -> T {
  let state = RandomState::new()
  let size = state.next_int() % 100
  self.run(size, state)
}

pub fn samples[T](self : Gen[T], ~size : Int = 10) -> Array[T] {
  let state = RandomState::new()
  Array::makei(size, fn(_x) { self.run(size, state) })
}

/// Combinators
pub fn small_int() -> Gen[Int] {
  /// NOTE: double gen can produce value > 0
  /// TODO: Update (along with other)
  Gen::new(
    fn(_i, rs) {
      let p = rs.next_double()
      if p < 0.75 {
        rs.next_int() % 11
      } else {
        rs.next_int() % 97
      }
    },
  )
}

test "small int" {
  inspect!(
    small_int().samples(size=50),
    content="[6, -7, 5, 0, 10, -10, 0, 7, -5, -1, -5, -4, 0, 3, 7, -5, 42, 3, 78, 1, 10, -5, -10, -51, -5, -73, -1, 3, -1, 9, 22, 88, -2, -7, 3, 9, 7, 1, 1, -1, 6, -9, -7, -25, -1, -10, -6, -33, -1, -4]",
  )
}

pub fn nat() -> Gen[Int] {
  Gen::new(
    fn(_i, rs) {
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
    },
  )
}

test "nat" {
  inspect!(
    nat().samples(size=50),
    content="[4, -93, 2, 4, 92, 0, 6, 7, -90, 0, -6, -92, 0, 70, 96, -7, 816, 6, 229, 6, 4, -5, -1, -163, -93, -231, -18, 6, -74, 5, 618, 206, -12, -2, 1, 3, 5, 2, 83, -6, 8, -8, -3, -676, -5, -31, -2, -514, -61, -6]",
  )
}

pub fn bool() -> Gen[Bool] {
  Gen::new(fn(_i, rs) { rs.next_double() < 0.5 })
}

test "bool" {
  inspect!(
    bool().samples(size=50),
    content="[true, true, false, false, false, false, true, false, false, false, true, false, true, true, true, false, false, true, true, false, true, true, false, true, true, false, false, false, false, false, true, false, false, true, true, true, false, true, true, true, true, true, true, true, true, true, false, true, false, true]",
  )
}

pub fn neg_int() -> Gen[Int] {
  Gen::new(fn(_i, rs) { -rs.next_int_abs() })
}

pub fn numeral() -> Gen[Char] {
  Gen::new(fn(_i, rs) { Char::from_int(rs.next_int_abs() % 10 + 48) })
}

pub fn alphabet() -> Gen[Char] {
  Gen::new(fn(_i, rs) { Char::from_int(rs.next_int_abs() % 26 + 65) })
}

pub fn int_bound(bound : Int) -> Gen[Int] {
  Gen::new(fn(_i, rs) { rs.next_int_abs() % bound })
}

pub fn int_range(lo : Int, hi : Int) -> Gen[Int] {
  Gen::new(
    fn(_i, rs) {
      let j = rs.next_int_abs() % (hi - lo)
      j + lo
    },
  )
}

pub fn char_range(lo : Char, hi : Char) -> Gen[Char] {
  int_range(lo.to_int(), hi.to_int() + 1).fmap(Char::from_int)
}

test "char range" {
  inspect!(
    char_range('a', 'c').samples(size=50),
    content="['a', 'a', 'b', 'a', 'c', 'a', 'b', 'a', 'c', 'b', 'c', 'c', 'a', 'a', 'c', 'b', 'b', 'a', 'b', 'a', 'c', 'a', 'a', 'b', 'b', 'c', 'b', 'a', 'b', 'a', 'b', 'a', 'c', 'b', 'c', 'c', 'c', 'b', 'a', 'c', 'a', 'a', 'a', 'a', 'b', 'b', 'a', 'b', 'c', 'b']",
  )
}

pub fn one_of[T](arr : Array[Gen[T]]) -> Gen[T] {
  int_bound(arr.length()).bind(fn(x) { arr[x] })
}

test "one of" {
  inspect!(
    one_of([pure(1), pure(2), pure(3), pure(4)]).samples(size=50),
    content="[1, 3, 2, 1, 4, 3, 3, 1, 3, 1, 4, 1, 4, 3, 1, 4, 2, 3, 1, 2, 3, 1, 2, 2, 3, 4, 3, 1, 2, 4, 1, 3, 3, 2, 3, 3, 2, 1, 1, 2, 3, 1, 3, 3, 1, 3, 2, 4, 1, 4]",
  )
}

pub fn one_of_list[T](lst : @immut/list.T[T]) -> Gen[T] {
  int_bound(lst.length()).fmap(fn(x) { lst.nth_exn(x) })
}

pub fn one_of_array[T](arr : Array[T]) -> Gen[T] {
  int_bound(arr.length()).fmap(fn(x) { arr[x] })
}

test "one of array" {
  inspect!(
    one_of_array(["a", "b", "c"]).samples(size=50),
    content=
      #|["a", "a", "b", "a", "c", "a", "b", "a", "c", "b", "c", "c", "a", "a", "c", "b", "b", "a", "b", "a", "c", "a", "a", "b", "b", "c", "b", "a", "b", "a", "b", "a", "c", "b", "c", "c", "c", "b", "a", "c", "a", "a", "a", "a", "b", "b", "a", "b", "c", "b"]
    ,
  )
}

pub fn frequency[T](arr : Array[(Int, Gen[T])]) -> Gen[T] {
  if arr.is_empty() {
    abort("frequency: empty list")
  } else {
    let sum = arr.map(@tuple.fst).fold_left(Int::op_add, init=0)
    if sum < 1 {
      abort("frequency: total weight is less than 1")
    } else {
      println(sum - 1)
      int_range(1, sum + 1).bind(
        fn(k) {
          for i = 0, acc = 0; i < arr.length(); {
            let (w, g) = arr[i]
            if k <= acc + w {
              break g
            } else {
              continue i + 1, acc + w
            }
          } else {
            abort("frequency: internal error")
          }
        },
      )
    }
  }
}

test "frequency int" {
  inspect!(
    frequency([(1, pure(42)), (2, pure(37)), (3, pure(114))]).samples(size=50),
    content="[114, 42, 114, 37, 114, 42, 37, 114, 114, 42, 114, 37, 114, 42, 114, 37, 114, 114, 37, 114, 114, 37, 114, 114, 114, 114, 114, 37, 37, 114, 114, 42, 37, 37, 42, 37, 37, 114, 42, 114, 114, 37, 37, 114, 114, 37, 37, 37, 42, 114]",
  )
}

pub fn frequency_list[T](lst : @immut/list.T[(Int, T)]) -> Gen[T] {
  lst.to_array().map(
    fn(x) {
      let (w, v) = x
      (w, pure(v))
    },
  )
  |> frequency
}

pub fn frequency_array[T](arr : Array[(Int, T)]) -> Gen[T] {
  arr.map(
    fn(x) {
      let (w, v) = x
      (w, pure(v))
    },
  )
  |> frequency
}

pub fn flatten_list[T](lst : @immut/list.T[Gen[T]]) -> Gen[@immut/list.T[T]] {
  match lst {
    Nil => pure(Nil)
    Cons(x, xs) => liftA2(@immut/list.T::Cons, x, flatten_list(xs))
  }
}

pub fn flatten_array[T](arr : Array[Gen[T]]) -> Gen[Array[T]] {
  Gen::new(
    fn(i, rs) { Array::makei(arr.length(), fn(j) { arr[j].run(i, rs) }) },
  )
}

pub fn flatten_option[T](opt : Gen[T]?) -> Gen[T?] {
  match opt {
    None => pure(None)
    Some(x) => x.fmap(Option::Some)
  }
}

pub fn flatten_result[T, E](res : Result[Gen[T], E]) -> Gen[Result[T, E]] {
  match res {
    Ok(x) => x.fmap(Result::Ok)
    Err(e) => pure(Err(e))
  }
}

pub fn list_with_size[T](size : Int, gen : Gen[T]) -> Gen[@immut/list.T[T]] {
  loop size, pure(@immut/list.Nil) {
    n, acc =>
      if n <= 0 {
        break acc
      } else {
        continue n - 1, liftA2(@immut/list.T::Cons, gen, acc)
      }
  }
}

pub fn sorted_list[T : Compare](
  size : Int,
  gen : Gen[T]
) -> Gen[@immut/list.T[T]] {
  list_with_size(size, gen).fmap(@immut/list.sort)
}

pub fn array_with_size[T](size : Int, gen : Gen[T]) -> Gen[Array[T]] {
  Gen::new(fn(i, rs) { Array::makei(size, fn(_j) { gen.run(i, rs) }) })
}
