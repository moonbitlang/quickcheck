///|
pub(all) enum LazyList[T] {
  Nil
  Cons(T, LazyRef[LazyList[T]])
}

///|
pub fn[X : Default] default() -> LazyList[X] {
  Nil
}

///|
pub impl[T : Show] Show for LazyList[T] with output(self, logger) {
  logger.write_string("[")
  loop self {
    Nil => break
    Cons(x, xs) => {
      let next = xs.force()
      logger.write_object(x)
      match next {
        Nil => break
        _ => {
          logger.write_string(", ")
          continue next
        }
      }
    }
  }
  logger.write_string("]")
}

///|
pub fn[T] index(self : LazyList[T], i : Int) -> T {
  match (self, i) {
    (Cons(x, _), 0) => x
    (Nil, _) => abort("index out of bounds")
    (Cons(_, xs), i) => force(xs).index(i - 1)
  }
}

///|
pub fn[T] to_lazy(ls : @immut/list.T[T]) -> LazyList[T] {
  match ls {
    Nil => Nil
    Cons(x, xs) => Cons(x, LazyRef::from_value(to_lazy(xs)))
  }
}

///|
pub fn[T] tails(self : LazyList[T]) -> LazyList[LazyList[T]] {
  fn go(xs) {
    Cons(
      xs,
      match xs {
        Nil => LazyRef::from_value(Nil)
        Cons(_, xs1) => LazyRef::from_thunk(fn() { go(force(xs1)) })
      },
    )
  }

  go(self)
}

///|
pub fn[T] concat(self : LazyList[T], other : LazyList[T]) -> LazyList[T] {
  match self {
    Nil => other
    Cons(x, xs) =>
      Cons(x, LazyRef::from_thunk(fn() { concat(force(xs), other) }))
  }
}

///|
pub impl[T] Add for LazyList[T] with op_add(self, other) {
  self.concat(other)
}

///|
pub fn[T] repeat(val : T) -> LazyList[T] {
  Cons(val, LazyRef::from_thunk(fn() { repeat(val) }))
}

///|
pub fn[T, U] map(self : LazyList[T], f : (T) -> U) -> LazyList[U] {
  match self {
    Nil => Nil
    Cons(x, xs) => Cons(f(x), LazyRef::from_thunk(fn() { map(xs.force(), f) }))
  }
}

///|
pub fn[T] split_at(self : LazyList[T], i : Int) -> (LazyList[T], LazyList[T]) {
  if i <= 0 {
    (Nil, self)
  } else {
    fn split_at_prime(m, xs) {
      match (m, xs) {
        (_, Nil) => (Nil, Nil)
        (1, Cons(x, xs)) => (Cons(x, LazyRef::from_value(Nil)), xs.force())
        (m, Cons(x, xs)) => {
          let (xs1, xs2) = split_at_prime(m - 1, xs.force())
          (Cons(x, xs1 |> LazyRef::from_value), xs2)
        }
      }
    }

    split_at_prime(i, self)
  }
}

///|
pub fn[T, U] fold_left(self : LazyList[T], f : (U, T) -> U, init~ : U) -> U {
  match self {
    Nil => init
    Cons(x, xs) => fold_left(xs.force(), f, init=f(init, x))
  }
}

///|
pub fn[T, U] fold_right(self : LazyList[T], f : (T, U) -> U, init~ : U) -> U {
  match self {
    Nil => init
    Cons(y, ys) => f(y, ys.force().fold_right(f, init~))
  }
}

///|
pub fn[T] head(self : LazyList[T]) -> T {
  match self {
    Cons(x, _) => x
    Nil => abort("head of empty list")
  }
}

///|
pub fn[T] tail(self : LazyList[T]) -> LazyList[T] {
  match self {
    Cons(_, xs) => xs.force()
    Nil => abort("tail of empty list")
  }
}

///|
pub fn[T] length(self : LazyList[T]) -> Int {
  self.fold_left(fn(acc, _x) { acc + 1 }, init=0)
}

///|
pub fn[X : Add] sum(l : LazyList[X], init~ : X) -> X {
  l.fold_left(Add::op_add, init~)
}

///|
pub fn[A, B, C] zip_with(
  f : (A, B) -> C,
  xs : LazyList[A],
  ys : LazyList[B]
) -> LazyList[C] {
  match (xs, ys) {
    (Cons(x, xs), Cons(y, ys)) =>
      Cons(
        f(x, y),
        LazyRef::from_thunk(fn() { zip_with(f, xs.force(), ys.force()) }),
      )
    (_, _) => Nil
  }
}

///|
pub fn[T] take_while(self : LazyList[T], p : (T) -> Bool) -> LazyList[T] {
  match self {
    Nil => Nil
    Cons(x, xs) =>
      if p(x) {
        Cons(x, LazyRef::from_thunk(fn() { take_while(xs.force(), p) }))
      } else {
        Nil
      }
  }
}

///|
pub fn[T] take(self : LazyList[T], n : Int) -> LazyList[T] {
  if n <= 0 {
    Nil
  } else {
    match self {
      Nil => Nil
      Cons(x, xs) => Cons(x, LazyRef::from_value(take(xs.force(), n - 1)))
    }
  }
}

///|
pub fn[T] drop(self : LazyList[T], n : Int) -> LazyList[T] {
  if n <= 0 {
    self
  } else {
    match self {
      Nil => Nil
      Cons(_, xs) => drop(xs.force(), n - 1)
    }
  }
}

///|
pub fn[T] drop_while(self : LazyList[T], p : (T) -> Bool) -> LazyList[T] {
  match self {
    Nil => Nil
    Cons(x, xs) => if p(x) { drop_while(xs.force(), p) } else { self }
  }
}

///|
pub fn[X : Add] infinite_stream(start : X, step : X) -> LazyList[X] {
  Cons(start, LazyRef::from_thunk(fn() { infinite_stream(start + step, step) }))
}

///|
pub fn[A, B, C] zip_lazy_normal(
  f : (A, B) -> C,
  xs : LazyList[A],
  ys : @immut/list.T[B]
) -> @immut/list.T[C] {
  match (xs, ys) {
    (Cons(x, xs), Cons(y, ys)) =>
      Cons(f(x, y), zip_lazy_normal(f, xs.force(), ys))
    (_, _) => Nil
  }
}

///|
pub fn[T] zip_plus(
  f : (T, T) -> T,
  ls1 : LazyList[T],
  ls2 : LazyList[T]
) -> LazyList[T] {
  match (ls1, ls2) {
    (Cons(x, xs), Cons(y, ys)) =>
      Cons(
        f(x, y),
        LazyRef::from_thunk(fn() { zip_plus(f, xs.force(), ys.force()) }),
      )
    (xs, ys) => xs.concat(ys)
  }
}

///|
pub fn[T] unfold(
  self : LazyList[T],
  f : (LazyList[T]) -> (T, LazyList[T])?
) -> LazyList[T] {
  match f(self) {
    None => Nil
    Some((x, y)) => Cons(x, LazyRef::from_thunk(fn() { y.unfold(f) }))
  }
}

///|
pub fn[T] from_list(ls : @immut/list.T[T]) -> LazyList[T] {
  match ls {
    Nil => Nil
    Cons(x, xs) => Cons(x, LazyRef::from_value(from_list(xs)))
  }
}
