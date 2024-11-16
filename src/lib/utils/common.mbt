let global_counter : Ref[Int] = @ref.new(0)

// Generate a fresh name
pub fn fresh_name() -> String {
  let counter = global_counter.val
  @ref.update(global_counter, fn(x) { x + 1 })
  "test-" + counter.to_string()
}

// Curry a function of arity 3
pub fn curry3[A, B, C, D](f : (A, B, C) -> D) -> (A) -> (B) -> (C) -> D {
  fn { a => fn { b => fn { c => f(a, b, c) } } }
}

// Curry a function of arity 4
pub fn curry4[A, B, C, D, E](
  f : (A, B, C, D) -> E
) -> (A) -> (B) -> (C) -> (D) -> E {
  fn { a => fn { b => fn { c => fn { d => f(a, b, c, d) } } } }
}

pub fn removes[T](
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
      Cons(xs_drop, removes(k, n - k, xs_drop).map(fn(x) { xs_take.concat(x) }))
    }
  }
}

pub fn apply_while[T](
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

pub fn id[T](x : T) -> T = "%identity"

pub fn const_[T, U](t : T) -> (U) -> T {
  fn { _ => t }
}

pub fn pair_function[A, B, C](f : (A, B) -> C) -> ((A, B)) -> C {
  fn { (x, y) => f(x, y) }
}

pub fn flip[M, N, Z](f : (M, N) -> Z) -> (N, M) -> Z {
  fn(x, y) { f(y, x) }
}
