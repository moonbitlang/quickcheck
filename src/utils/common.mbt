///|
let global_counter : Ref[Int] = @ref.new(0)

// Generate a fresh name

///|
pub fn fresh_name() -> String {
  let counter = global_counter.val
  global_counter.update(fn(x) { x + 1 })
  "test-" + counter.to_string()
}

///|
pub fn[T] removes_list(
  k : Int,
  n : Int,
  xs : @list.List[T],
) -> @list.List[@list.List[T]] {
  if k > n {
    @list.empty()
  } else {
    let xs_drop = xs.drop(k)
    if xs_drop.is_empty() {
      @list.empty()
    } else {
      let xs_take = xs.take(k)
      removes_list(k, n - k, xs_drop)
      .map(fn(x) { xs_take.concat(x) })
      .add(xs_drop)
    }
  }
}

///|
pub fn[T] removes_array(k : Int, n : Int, xs : Array[T]) -> Array[Array[T]] {
  if k > n {
    []
  } else {
    let xs2 = xs[:k].to_array()
    let xs1 = xs[k:].to_array()
    if xs1.is_empty() {
      []
    } else {
      [xs1, ..removes_array(k, n - k, xs1).map(fn(x) { xs2 + x })]
    }
  }
}

///|
pub fn[T] apply_while_list(
  x : T,
  f : (T) -> T,
  cond : (T) -> Bool,
) -> @list.List[T] {
  loop (x, @list.empty()) {
    (acc, lst) => {
      let next = f(acc)
      if cond(next) {
        continue (next, lst.add(next))
      } else {
        break lst
      }
    }
  }
}

///|
pub fn[T] apply_while_array(
  x : T,
  f : (T) -> T,
  cond : (T) -> Bool,
) -> Array[T] {
  loop (x, []) {
    (acc, lst) => {
      let next = f(acc)
      if cond(next) {
        continue (next, [next, ..lst])
      } else {
        break lst
      }
    }
  }
}

///|
pub fn[T] id(x : T) -> T = "%identity"

///|
pub fn[T, U] const_(t : T) -> (U) -> T {
  fn(_) { t }
}

///|
pub fn[A, B, C] pair_function(f : (A, B) -> C) -> ((A, B)) -> C {
  tuple => f(tuple.0, tuple.1)
}

///|
pub fn[M, N, Z] flip(f : (M, N) -> Z) -> (N, M) -> Z {
  fn(x, y) { f(y, x) }
}
