pub(all) enum LazyList[T] {
  Nil
  Cons(T, LazyRef[LazyList[T]])
}

pub(open) trait Monoid {
  op_add(Self, Self) -> Self
}

pub fn default[X : Default]() -> LazyList[X] {
  Nil
}

pub fn to_string[T : Show](self : LazyList[T]) -> String {
  match self {
    Nil => "Nil"
    Cons(x, xs) => "Cons(" + x.to_string() + ", " + force(xs).to_string() + ")"
  }
}

pub fn output[T : Show](self : LazyList[T], logger : Logger) -> Unit {
  logger.write_string(self.to_string())
}

pub fn index[T](self : LazyList[T], i : Int) -> T {
  match (self, i) {
    (Cons(x, _), 0) => x
    (Nil, _) => abort("index out of bounds")
    (Cons(_, xs), i) => force(xs).index(i - 1)
  }
}

pub fn to_lazy[T](ls : @immut/list.T[T]) -> LazyList[T] {
  match ls {
    Nil => Nil
    Cons(x, xs) => Cons(x, LazyRef::from_value(to_lazy(xs)))
  }
}

pub fn tails[T](self : LazyList[T]) -> LazyList[LazyList[T]] {
  fn go(xs) {
    Cons(
      xs,
      match xs {
        Nil => from_value(Nil)
        Cons(_, xs1) => from_thunk(fn() { go(force(xs1)) })
      },
    )
  }

  go(self)
}

pub fn concat[T](self : LazyList[T], other : LazyList[T]) -> LazyList[T] {
  match self {
    Nil => other
    Cons(x, xs) => Cons(x, from_thunk(fn() { concat(force(xs), other) }))
  }
}

pub fn op_add[T](self : LazyList[T], other : LazyList[T]) -> LazyList[T] {
  self.concat(other)
}

pub fn repeat[T](val : T) -> LazyList[T] {
  Cons(val, from_thunk(fn() { repeat(val) }))
}

pub fn map[T, U](self : LazyList[T], f : (T) -> U) -> LazyList[U] {
  match self {
    Nil => Nil
    Cons(x, xs) => Cons(f(x), from_thunk(fn() { map(xs.force(), f) }))
  }
}

pub fn split_at[T](self : LazyList[T], i : Int) -> (LazyList[T], LazyList[T]) {
  match (self, i) {
    (Cons(_), 0) => (Nil, self)
    (Cons(x, xs), i) => {
      let (l, r) = xs.force().split_at(i - 1)
      (Cons(x, from_thunk(fn() { l })), r)
    }
    (Nil, _) => (Nil, Nil)
  }
}

pub fn fold_left[T, U](self : LazyList[T], f : (U, T) -> U, init~ : U) -> U {
  match self {
    Nil => init
    Cons(x, xs) => fold_left(xs.force(), f, init=f(init, x))
  }
}

pub fn fold_right[T, U](self : LazyList[T], f : (T, U) -> U, init~ : U) -> U {
  match self {
    Nil => init
    Cons(y, ys) => f(y, ys.force().fold_right(f, init~))
  }
}

pub fn head[T](self : LazyList[T]) -> T {
  match self {
    Cons(x, _) => x
    Nil => abort("head of empty list")
  }
}

pub fn tail[T](self : LazyList[T]) -> LazyList[T] {
  match self {
    Cons(_, xs) => xs.force()
    Nil => abort("tail of empty list")
  }
}

pub fn length[T](self : LazyList[T]) -> Int {
  self.fold_left(fn(acc, _x) { acc + 1 }, init=0)
}

pub fn sum[X : Monoid](l : LazyList[X], init~ : X) -> X {
  l.fold_left(Monoid::op_add, init~)
}

pub fn zip_with[A, B, C](
  f : (A, B) -> C,
  xs : LazyList[A],
  ys : LazyList[B]
) -> LazyList[C] {
  match (xs, ys) {
    (Cons(x, xs), Cons(y, ys)) =>
      Cons(f(x, y), from_thunk(fn() { zip_with(f, xs.force(), ys.force()) }))
    (_, _) => Nil
  }
}

pub fn take_while[T](self : LazyList[T], p : (T) -> Bool) -> LazyList[T] {
  match self {
    Nil => Nil
    Cons(x, xs) =>
      if p(x) {
        Cons(x, from_thunk(fn() { take_while(xs.force(), p) }))
      } else {
        Nil
      }
  }
}

pub fn drop_while[T](self : LazyList[T], p : (T) -> Bool) -> LazyList[T] {
  match self {
    Nil => Nil
    Cons(x, xs) => if p(x) { drop_while(xs.force(), p) } else { self }
  }
}

pub fn infinite_stream[X : Monoid](start : X, step : X) -> LazyList[X] {
  Cons(start, from_thunk(fn() { infinite_stream(start + step, step) }))
}

pub fn zip_lazy_normal[A, B, C](
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

pub fn zip_plus[T](
  f : (T, T) -> T,
  ls1 : LazyList[T],
  ls2 : LazyList[T]
) -> LazyList[T] {
  match (ls1, ls2) {
    (Cons(x, xs), Cons(y, ys)) =>
      Cons(f(x, y), from_thunk(fn() { zip_plus(f, xs.force(), ys.force()) }))
    (xs, ys) => xs.concat(ys)
  }
}

pub fn unfold[T](
  self : LazyList[T],
  f : (LazyList[T]) -> (T, LazyList[T])?
) -> LazyList[T] {
  match f(self) {
    None => Nil
    Some((x, y)) => Cons(x, from_thunk(fn() { y.unfold(f) }))
  }
}
