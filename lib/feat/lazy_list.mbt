pub enum LazyList[T] {
  Nil
  Cons(T, () -> LazyList[T])
}

pub fn to_string[T : Show](self : LazyList[T]) -> String {
  match self {
    Nil => "Nil"
    Cons(x, xs) => "Cons(" + x.to_string() + ", " + xs().to_string() + ")"
  }
}

pub fn output[T : Show](self : LazyList[T], logger: Logger) -> Unit {
  logger.write_string(self.to_string())
}

pub fn index[T](self : LazyList[T], i : Int) -> T {
  match (self, i) {
    (Cons(x, _), 0) => x
    (Nil, _) => abort("index out of bounds")
    (Cons(_, xs), i) => xs().index(i - 1)
  }
}

pub fn concat[T](self : LazyList[T], other : LazyList[T]) -> LazyList[T] {
  match self {
    Nil => other
    Cons(x, xs) => Cons(x, fn() { concat(xs(), other) })
  }
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

fn sum_list(l : LazyList[Int]) -> Int {
  l.fold_left(Int::op_add, init=0)
}

fn zip_with[A, B, C](
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
