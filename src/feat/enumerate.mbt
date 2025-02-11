///|
pub(all) struct Enumerate[T] {
  parts : LazyList[Finite[T]]
}

///|
pub fn eval[T](self : Enumerate[T]) -> LazyList[Finite[T]] {
  self.parts
}

///|
pub fn empty[T]() -> Enumerate[T] {
  { parts: Nil }
}

///|
pub fn default[T]() -> Enumerate[T] {
  empty()
}

///|
pub fn singleton[T](val : T) -> Enumerate[T] {
  { parts: Cons(fin_pure(val), @lazy.LazyRef::from_value(Nil)) }
}

///|
pub fn en_index[T](self : Enumerate[T], idx : BigInt) -> T {
  loop self.parts, idx {
    Nil, _ => abort("index out of bounds")
    Cons(f, rest), i =>
      if i < f.fCard {
        (f.fIndex)(i)
      } else {
        continue rest.force(), i - f.fCard
      }
  }
}

///|
pub fn union[T](e1 : Enumerate[T], e2 : Enumerate[T]) -> Enumerate[T] {
  { parts: @lazy.zip_plus(fin_union, e1.parts, e2.parts) }
}

///|
pub fn op_add[T](self : Enumerate[T], other : Enumerate[T]) -> Enumerate[T] {
  union(self, other)
}

///|
pub fn fmap[T, U](self : Enumerate[T], f : (T) -> U) -> Enumerate[U] {
  { parts: self.parts.map(fn { x => fin_fmap(f, x) }) }
}

///|
pub fn pay[T](f : () -> Enumerate[T]) -> Enumerate[T] {
  { parts: Cons(fin_empty(), @lazy.LazyRef::from_thunk(fn() { f().parts })) }
}

///|
pub fn product[T, U](e1 : Enumerate[T], e2 : Enumerate[U]) -> Enumerate[(T, U)] {
  { parts: prod_helper(e1.parts, reversals(e2.parts)) }
}

///|
fn prod_helper[T, U](
  xs : LazyList[Finite[T]],
  rys : LazyList[LazyList[Finite[U]]]
) -> LazyList[Finite[(T, U)]] {
  rys.map(fn(y) { convolution(xs, y) })
}

///|
pub fn app[T, U](f : Enumerate[(T) -> U], e : Enumerate[T]) -> Enumerate[U] {
  product(f, e).fmap(fn { (ff, x) => ff(x) })
}

///|
pub fn consts[T](ls : @immut/list.T[Enumerate[T]]) -> Enumerate[T] {
  pay(fn() { ls.fold(union, init=empty()) })
}

///|
pub fn unary[T : Enumerable, U](f : (T) -> U) -> Enumerate[U] {
  T::enumerate().fmap(f)
}
