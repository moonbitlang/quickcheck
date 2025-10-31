///|
pub(all) struct Enumerate[T] {
  parts : LazyList[Finite[T]]
}

///|
pub fn[T] Enumerate::eval(self : Enumerate[T]) -> LazyList[Finite[T]] {
  self.parts
}

///|
pub fn[T] empty() -> Enumerate[T] {
  { parts: Nil }
}

///|
pub fn[T] default() -> Enumerate[T] {
  empty()
}

///|
pub fn[T] singleton(val : T) -> Enumerate[T] {
  { parts: Cons(fin_pure(val), @lazy.LazyRef::from_value(Nil)) }
}

///|
pub fn[T] Enumerate::en_index(self : Enumerate[T], idx : BigInt) -> T {
  loop (self.parts, idx) {
    (Nil, _) => abort("index out of bounds")
    (Cons(f, rest), i) =>
      if i < f.fCard {
        (f.fIndex)(i)
      } else {
        continue (rest.force(), i - f.fCard)
      }
  }
}

///|
pub fn[T] union(e1 : Enumerate[T], e2 : Enumerate[T]) -> Enumerate[T] {
  { parts: @lazy.zip_plus(fin_union, e1.parts, e2.parts) }
}

///|
pub impl[T] Add for Enumerate[T] with add(self, other) {
  union(self, other)
}

///|
pub fn[T, U] Enumerate::fmap(self : Enumerate[T], f : (T) -> U) -> Enumerate[U] {
  { parts: self.parts.map(fn(x) { fin_fmap(f, x) }) }
}

///|
pub fn[T] pay(f : () -> Enumerate[T]) -> Enumerate[T] {
  { parts: Cons(fin_empty(), @lazy.LazyRef::from_thunk(fn() { f().parts })) }
}

///|
pub fn[T, U] product(e1 : Enumerate[T], e2 : Enumerate[U]) -> Enumerate[(T, U)] {
  { parts: prod_helper(e1.parts, reversals(e2.parts)) }
}

///|
fn[T, U] prod_helper(
  xs : LazyList[Finite[T]],
  rys : LazyList[LazyList[Finite[U]]],
) -> LazyList[Finite[(T, U)]] {
  rys.map(fn(y) { convolution(xs, y) })
}

///|
pub fn[T, U] app(f : Enumerate[(T) -> U], e : Enumerate[T]) -> Enumerate[U] {
  product(f, e).fmap(fn(t) { (t.0)(t.1) })
}

///|
pub fn[T] consts(ls : @list.List[Enumerate[T]]) -> Enumerate[T] {
  pay(fn() { ls.fold(union, init=empty()) })
}

///|
pub fn[T : Enumerable, U] unary(f : (T) -> U) -> Enumerate[U] {
  T::enumerate().fmap(f)
}
