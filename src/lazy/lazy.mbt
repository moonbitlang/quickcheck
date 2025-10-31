///|
priv enum Lazy[T] {
  Thunk(() -> T)
  Value(T)
}

///|
struct LazyRef[T] {
  mut body : Lazy[T]
}

///|
pub fn[T] LazyRef::from_value(val : T) -> LazyRef[T] {
  { body: Value(val) }
}

///|
pub fn[T] LazyRef::from_thunk(f : () -> T) -> LazyRef[T] {
  { body: Thunk(f) }
}

///|
pub fn[T] LazyRef::force(self : LazyRef[T]) -> T {
  match self.body {
    Value(v) => v
    Thunk(f) => {
      let v = f()
      self.body = Value(v)
      v
    }
  }
}
