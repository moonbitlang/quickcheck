/// Extensional equality for function.
pub fn ext_equal[A, B : Eq](f : (A) -> B, g : (A) -> B) -> (A) -> Bool {
  fn { x => f(x) == g(x) }
}

/// Idempotent function.
pub fn idempotent[A : Eq](f : (A) -> A) -> (A) -> Bool {
  fn { x => f(f(x)) == f(x) }
}

/// Involutory function.
pub fn involutory[A : Eq](f : (A) -> A) -> (A) -> Bool {
  fn { x => f(f(x)) == x }
}

/// Inverse function.
pub fn inverse[A : Eq, B](f : (A) -> B, g : (B) -> A) -> (A) -> Bool {
  fn { x => g(f(x)) == x }
}

/// Monotonic increasing function.
pub fn mono_increase[A : Compare, B : Compare](
  f : (A) -> B
) -> ((A, A)) -> Bool {
  fn { (x, y) => x <= y && f(x) <= f(y) }
}

/// Monotonic decreasing function.
pub fn mono_decrease[A : Compare, B : Compare](
  f : (A) -> B
) -> ((A, A)) -> Bool {
  fn { (x, y) => x <= y && f(x) >= f(y) }
}

/// Commutative binary operation.
pub fn commutative[A, B : Eq](f : (A, A) -> B) -> ((A, A)) -> Bool {
  fn { (x, y) => f(x, y) == f(y, x) }
}

/// Associative binary operation.
pub fn associative[A : Eq](f : (A, A) -> A) -> ((A, A, A)) -> Bool {
  fn { (x, y, z) => f(f(x, y), z) == f(x, f(y, z)) }
}

/// Distributive binary operation over left
pub fn distributive_left[A : Eq](
  f : (A, A) -> A,
  g : (A, A) -> A
) -> ((A, A, A)) -> Bool {
  fn { (x, y, z) => f(x, g(y, z)) == g(f(x, y), f(x, z)) }
}

/// Distributive binary operation over right
pub fn distributive_right[A : Eq](
  f : (A, A) -> A,
  g : (A, A) -> A
) -> ((A, A, A)) -> Bool {
  fn { (x, y, z) => f(g(x, y), z) == g(f(x, z), f(y, z)) }
}
