///|
/// Extensional equality for function.
pub fn[A, B : Eq] ext_equal(f : (A) -> B, g : (A) -> B) -> (A) -> Bool {
  fn(x) { f(x) == g(x) }
}

///|
/// Idempotent function.
pub fn[A : Eq] idempotent(f : (A) -> A) -> (A) -> Bool {
  fn(x) { f(f(x)) == f(x) }
}

///|
/// Involutory function.
pub fn[A : Eq] involutory(f : (A) -> A) -> (A) -> Bool {
  fn(x) { f(f(x)) == x }
}

///|
/// Inverse function.
pub fn[A : Eq, B] inverse(f : (A) -> B, g : (B) -> A) -> (A) -> Bool {
  fn(x) { g(f(x)) == x }
}

///|
/// Monotonic increasing function.
pub fn[A : Compare, B : Compare] mono_increase(
  f : (A) -> B,
) -> ((A, A)) -> Bool {
  fn(t : (A, A)) {
    let (x, y) = t
    x <= y && f(x) <= f(y)
  }
}

///|
/// Monotonic decreasing function.
pub fn[A : Compare, B : Compare] mono_decrease(
  f : (A) -> B,
) -> ((A, A)) -> Bool {
  fn(t : (A, A)) {
    let (x, y) = t
    x <= y && f(x) >= f(y)
  }
}

///|
/// Commutative binary operation.
pub fn[A, B : Eq] commutative(f : (A, A) -> B) -> ((A, A)) -> Bool {
  fn(t : (A, A)) {
    let (x, y) = t
    f(x, y) == f(y, x)
  }
}

///|
/// Associative binary operation.
pub fn[A : Eq] associative(f : (A, A) -> A) -> ((A, A, A)) -> Bool {
  fn(t : (A, A, A)) {
    let (x, y, z) = t
    f(f(x, y), z) == f(x, f(y, z))
  }
}

///|
/// Distributive binary operation over left
pub fn[A : Eq] distributive_left(
  f : (A, A) -> A,
  g : (A, A) -> A,
) -> ((A, A, A)) -> Bool {
  fn(t : (A, A, A)) {
    let (x, y, z) = t
    f(x, g(y, z)) == g(f(x, y), f(x, z))
  }
}

///|
/// Distributive binary operation over right
pub fn[A : Eq] distributive_right(
  f : (A, A) -> A,
  g : (A, A) -> A,
) -> ((A, A, A)) -> Bool {
  fn(t : (A, A, A)) {
    let (x, y, z) = t
    f(g(x, y), z) == g(f(x, z), f(y, z))
  }
}
