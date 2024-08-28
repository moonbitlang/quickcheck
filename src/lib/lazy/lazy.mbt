priv enum Lazy[T] {
  Thunk(() -> T)
  Value(T)
}

struct LazyRef[T] {
  mut body : Lazy[T]
}

pub fn LazyRef::from_value[T](val : T) -> LazyRef[T] {
  { body: Value(val) }
}

pub fn LazyRef::from_thunk[T](f : () -> T) -> LazyRef[T] {
  { body: Thunk(f) }
}

pub fn force[T](self : LazyRef[T]) -> T {
  match self.body {
    Value(v) => v
    Thunk(f) => {
      let v = f()
      self.body = Value(v)
      v
    }
  }
}
