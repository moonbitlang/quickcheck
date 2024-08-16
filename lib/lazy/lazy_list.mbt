pub typealias Lazy[T] = () -> T

pub enum LazyList[T] {
  Nil
  Cons(T, Lazy[LazyList[T]])
}

pub trait Monoid {
  op_add(Self, Self) -> Self
}

pub fn default[X : Default]() -> LazyList[X] {
  Nil
}

pub fn to_string[T : Show](self : LazyList[T]) -> String {
  match self {
    Nil => "Nil"
    Cons(x, xs) => "Cons(" + x.to_string() + ", " + xs().to_string() + ")"
  }
}

pub fn output[T : Show](self : LazyList[T], logger : Logger) -> Unit {
  logger.write_string(self.to_string())
}

pub fn index[T](self : LazyList[T], i : Int) -> T {
  match (self, i) {
    (Cons(x, _), 0) => x
    (Nil, _) => abort("index out of bounds")
    (Cons(_, xs), i) => xs().index(i - 1)
  }
}

pub fn to_lazy[T](ls : @immut/list.T[T]) -> LazyList[T] {
  match ls {
    Nil => Nil
    Cons(x, xs) => Cons(x, fn() { to_lazy(xs) })
  }
}

pub fn concat[T](self : LazyList[T], other : LazyList[T]) -> LazyList[T] {
  match self {
    Nil => other
    Cons(x, xs) => Cons(x, fn() { concat(xs(), other) })
  }
}

pub fn op_add[T](self : LazyList[T], other : LazyList[T]) -> LazyList[T] {
  self.concat(other)
}

pub fn repeat[T](val : T) -> LazyList[T] {
  Cons(val, fn() { repeat(val) })
}

pub fn map[T, U](self : LazyList[T], f : (T) -> U) -> LazyList[U] {
  match self {
    Nil => Nil
    Cons(x, xs) => Cons(f(x), fn() { map(xs(), f) })
  }
}

pub fn split_at[T](self : LazyList[T], i : Int) -> (LazyList[T], LazyList[T]) {
  match (self, i) {
    (Cons(_), 0) => (Nil, self)
    (Cons(x, xs), i) => {
      let (l, r) = xs().split_at(i - 1)
      (Cons(x, fn() { l }), r)
    }
    (Nil, _) => (Nil, Nil)
  }
}

pub fn fold_left[T, U](self : LazyList[T], f : (U, T) -> U, ~init : U) -> U {
  match self {
    Nil => init
    Cons(x, xs) => fold_left(xs(), f, init=f(init, x))
  }
}

pub fn fold_right[T, U](self : LazyList[T], f : (T, U) -> U, ~init : U) -> U {
  match self {
    Nil => init
    Cons(y, ys) => f(y, ys().fold_right(f, ~init))
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
    Cons(_, xs) => xs()
    Nil => abort("tail of empty list")
  }
}

pub fn length[T](self : LazyList[T]) -> Int {
  self.fold_left(fn(acc, _x) { acc + 1 }, init=0)
}

pub fn sum[X : Monoid](l : LazyList[X], ~init : X) -> X {
  l.fold_left(Monoid::op_add, ~init)
}

pub fn zip_with[A, B, C](
  f : (A, B) -> C,
  xs : LazyList[A],
  ys : LazyList[B]
) -> LazyList[C] {
  match (xs, ys) {
    (Cons(x, xs), Cons(y, ys)) =>
      Cons(f(x, y), fn() { zip_with(f, xs(), ys()) })
    (_, _) => Nil
  }
}

pub fn take_while[T](self : LazyList[T], p : (T) -> Bool) -> LazyList[T] {
  match self {
    Nil => Nil
    Cons(x, xs) =>
      if p(x) {
        Cons(x, fn() { take_while(xs(), p) })
      } else {
        Nil
      }
  }
}

pub fn drop_while[T](self : LazyList[T], p : (T) -> Bool) -> LazyList[T] {
  match self {
    Nil => Nil
    Cons(x, xs) => if p(x) { drop_while(xs(), p) } else { self }
  }
}

pub fn infinite_stream[X : Monoid](start : X, step : X) -> LazyList[X] {
  Cons(start, fn() { infinite_stream(start + step, step) })
}

pub fn zip_lazy_normal[A, B, C](
  f : (A, B) -> C,
  xs : LazyList[A],
  ys : @immut/list.T[B]
) -> @immut/list.T[C] {
  match (xs, ys) {
    (Cons(x, xs), Cons(y, ys)) => Cons(f(x, y), zip_lazy_normal(f, xs(), ys))
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
      Cons(f(x, y), fn() { zip_plus(f, xs(), ys()) })
    (xs, ys) => xs.concat(ys)
  }
}

pub fn unfold[T](
  self : LazyList[T],
  f : (LazyList[T]) -> (T, LazyList[T])?
) -> LazyList[T] {
  match f(self) {
    None => Nil
    Some((x, y)) => Cons(x, fn() { y.unfold(f) })
  }
}
