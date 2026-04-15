///|
priv enum Lazy[T] {
  Thunk(() -> T)
  Value(T)
}

///|
/// A mutable cell that memoises a thunk: it holds either an
/// already-computed value or a delayed computation, and caches the
/// result on first `force`. Used to make `LazyList` tails on-demand
/// without recomputing them when traversed repeatedly.
struct LazyRef[T] {
  mut body : Lazy[T]
}

///|
/// Promote an already-evaluated value to a `LazyRef`. `force` on the
/// result returns immediately without computing anything.
pub fn[T] LazyRef::from_value(val : T) -> LazyRef[T] {
  { body: Value(val) }
}

///|
/// Wrap a delayed computation as a `LazyRef`. The thunk runs the first
/// time `force` is called; subsequent forces return the cached value.
pub fn[T] LazyRef::from_thunk(f : () -> T) -> LazyRef[T] {
  { body: Thunk(f) }
}

///|
/// Read the value, running the thunk on first access and caching the
/// result in place. Idempotent and O(1) after the first call.
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
