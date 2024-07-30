struct Gen[T] {
  gen : (Int, RandomState) -> T
}

pub fn Gen::new[T](gen : (Int, RandomState) -> T) -> Gen[T] {
  { gen, }
}

pub fn Gen::spawn[T : Arbitrary]() -> Gen[T] {
  { gen: T::arbitrary }
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
  Gen::new(
    fn(n, s) {
      let x = gx.run(n, s)
      let y = gy.run(n, s)
      (x, y)
    },
  )
}

pub fn run[T](self : Gen[T], i : Int, rs : RandomState) -> T {
  (self.gen)(i, rs)
}

pub fn sample[T](self : Gen[T]) -> T {
  let state = RandomState::new()
  let size = state.rs.gen_int() % 100
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
      let p = rs.rs.gen_double()
      if p < 0.75 {
        rs.rs.gen_int() % 10
      } else {
        rs.rs.gen_int() % 100
      }
    },
  )
}

pub fn nat() -> Gen[Int] {
  Gen::new(
    fn(_i, rs) {
      let p = rs.rs.gen_double()
      if p < 0.5 {
        rs.rs.gen_int() % 10
      } else if p < 0.75 {
        rs.rs.gen_int() % 100
      } else if p < 0.95 {
        rs.rs.gen_int() % 1000
      } else {
        rs.rs.gen_int() % 10000
      }
    },
  )
}

pub fn bool() -> Gen[Bool] {
  Gen::new(fn(_i, rs) { rs.rs.gen_double() < 0.5 })
}

pub fn neg_int() -> Gen[Int] {
  Gen::new(fn(_i, rs) { -rs.rs.gen_int() })
}

pub fn numeral() -> Gen[Char] {
  Gen::new(fn(_i, rs) { Char::from_int(rs.rs.gen_int() % 10 + 48) })
}

pub fn alphabet() -> Gen[Char] {
  Gen::new(fn(_i, rs) { Char::from_int(rs.rs.gen_int() % 26 + 65) })
}

pub fn int_bound(bound : Int) -> Gen[Int] {
  Gen::new(
    fn(_i, rs) {
      let j = rs.rs.gen_int() % bound
      j.abs()
    },
  )
}

pub fn int_range(lo : Int, hi : Int) -> Gen[Int] {
  Gen::new(
    fn(_i, rs) {
      let j = rs.rs.gen_int() % (hi - lo)
      j + lo
    },
  )
}

pub fn char_range(lo : Char, hi : Char) -> Gen[Char] {
  int_range(lo.to_int(), hi.to_int()).fmap(Char::from_int)
}

pub fn one_of[T](arr : Array[Gen[T]]) -> Gen[T] {
  int_bound(arr.length() - 1).bind(fn(x) { arr[x] })
}

pub fn one_of_list[T](lst : @immut/list.T[T]) -> Gen[T] {
  int_bound(lst.length() - 1).fmap(fn(x) { lst.nth_exn(x) })
}

pub fn one_of_array[T](arr : Array[T]) -> Gen[T] {
  int_bound(arr.length() - 1).fmap(fn(x) { arr[x] })
}

pub fn frequency[T](arr : Array[(Int, Gen[T])]) -> Gen[T] {
  if arr.is_empty() {
    abort("frequency: empty list")
  } else {
    let sum = arr.map(@tuple.fst).fold_left(Int::op_add, init=0)
    if sum < 1 {
      abort("frequency: total weight is less than 1")
    } else {
      int_bound(sum - 1).bind(
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