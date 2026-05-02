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
///
/// ```mbt check
/// test {
///   let r = LazyRef::from_value(7)
///   assert_eq(r.force(), 7)
/// }
/// ```
pub fn[T] LazyRef::from_value(val : T) -> LazyRef[T] {
  { body: Value(val) }
}

///|
/// Wrap a delayed computation as a `LazyRef`. The thunk runs the first
/// time `force` is called; subsequent forces return the cached value.
///
/// ```mbt check
/// test {
///   let runs = Ref(0)
///   let r = LazyRef::from_thunk(() => {
///     runs.val = runs.val + 1
///     "hi"
///   })
///   assert_eq(runs.val, 0)
///   assert_eq(r.force(), "hi")
///   assert_eq(r.force(), "hi")
///   assert_eq(runs.val, 1)
/// }
/// ```
pub fn[T] LazyRef::from_thunk(f : () -> T) -> LazyRef[T] {
  { body: Thunk(f) }
}

///|
/// Read the value, running the thunk on first access and caching the
/// result in place. Idempotent and O(1) after the first call.
///
/// ```mbt check
/// test {
///   let r = LazyRef::from_thunk(() => 1 + 2)
///   assert_eq(r.force(), 3)
/// }
/// ```
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
