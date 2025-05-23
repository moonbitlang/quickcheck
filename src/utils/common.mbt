///|
let global_counter : Ref[Int] = @ref.new(0)

// Generate a fresh name
///|
pub fn fresh_name() -> String {
  let counter = global_counter.val
  @ref.update(global_counter, fn(x) { x + 1 })
  "test-" + counter.to_string()
}

///|
pub fn removes_list[T](
  k : Int,
  n : Int,
  xs : @immut/list.T[T]
) -> @immut/list.T[@immut/list.T[T]] {
  if k > n {
    Nil
  } else {
    let xs_drop = xs.drop(k)
    if xs_drop.is_empty() {
      Nil
    } else {
      let xs_take = xs.take(k)
      Cons(
        xs_drop,
        removes_list(k, n - k, xs_drop).map(fn(x) { xs_take.concat(x) }),
      )
    }
  }
}

///|
pub fn removes_array[T](k : Int, n : Int, xs : Array[T]) -> Array[Array[T]] {
  if k > n {
    []
  } else {
    let (xs2, xs1) = xs.split_at(k)
    if xs1.is_empty() {
      []
    } else {
      [xs1, ..removes_array(k, n - k, xs1).map(fn(x) { xs2 + x })]
    }
  }
}

///|
pub fn apply_while_list[T](
  x : T,
  f : (T) -> T,
  cond : (T) -> Bool
) -> @immut/list.T[T] {
  loop x, @immut/list.T::Nil {
    acc, lst => {
      let next = f(acc)
      if cond(next) {
        continue next, Cons(next, lst)
      } else {
        break lst
      }
    }
  }
}

///|
pub fn apply_while_array[T](
  x : T,
  f : (T) -> T,
  cond : (T) -> Bool
) -> Array[T] {
  loop x, [] {
    acc, lst => {
      let next = f(acc)
      if cond(next) {
        continue next, [next, ..lst]
      } else {
        break lst
      }
    }
  }
}

///|
pub fn id[T](x : T) -> T = "%identity"

///|
pub fn const_[T, U](t : T) -> (U) -> T {
  fn { _ => t }
}

///|
pub fn pair_function[A, B, C](f : (A, B) -> C) -> ((A, B)) -> C {
  fn { (x, y) => f(x, y) }
}

///|
pub fn flip[M, N, Z](f : (M, N) -> Z) -> (N, M) -> Z {
  fn(x, y) { f(y, x) }
}
