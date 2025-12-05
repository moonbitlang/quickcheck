///|
pub(all) struct Equivalence[T] {
  lhs : T
  rhs : T
} derive(Show)

///|
pub fn[T] Equivalence::new(lhs : T, rhs : T) -> Equivalence[T] {
  { lhs, rhs }
}

///|
pub fn[T, U] Equivalence::fmap(
  self : Equivalence[T],
  f : (T) -> U,
) -> Equivalence[U] {
  { lhs: f(self.lhs), rhs: f(self.rhs) }
}

///|
pub fn[T, U] Equivalence::bind(
  self : Equivalence[T],
  f : (T) -> Equivalence[U],
) -> Equivalence[U] {
  let lhs = f(self.lhs).lhs
  let rhs = f(self.rhs).rhs
  { lhs, rhs }
}

///|
pub fn[T, U] Equivalence::ap(
  self : Equivalence[(T) -> U],
  other : Equivalence[T],
) -> Equivalence[U] {
  let lhs = (self.lhs)(other.lhs)
  let rhs = (self.rhs)(other.rhs)
  { lhs, rhs }
}

///|
pub fn[T] pure_eq(x : T) -> Equivalence[T] {
  { lhs: x, rhs: x }
}

///|
pub fn[T : Eq] Equivalence::is_equal(self : Equivalence[T]) -> Bool {
  self.lhs == self.rhs
}

///|
pub fn[T] Equivalence::equal_by(
  self : Equivalence[T],
  eq : (T, T) -> Bool,
) -> Bool {
  eq(self.lhs, self.rhs)
}

///|
struct Axiom[T] {
  run_axiom : (T) -> Equivalence[T]
}

///|
pub fn[T] Axiom::new(run_axiom : (T) -> Equivalence[T]) -> Axiom[T] {
  { run_axiom, }
}

///|
pub fn[T] Axiom::run(self : Axiom[T], x : T) -> Equivalence[T] {
  (self.run_axiom)(x)
}

///|
pub fn[T, U] Axiom::to_property(
  self : Axiom[T],
  cong : (T) -> U,
  eq : (U, U) -> Bool,
) -> (T) -> Bool {
  fn(x : T) { self.run(x).fmap(cong).equal_by(eq) }
}

///|
pub fn[T, U : Eq] Axiom::to_property_eq(
  self : Axiom[T],
  cong : (T) -> U,
) -> (T) -> Bool {
  self.to_property(cong, Eq::equal)
}

///|
pub fn[T, M, N] Axiom::to_property_parametric(
  self : Axiom[T],
  cong : (T, M) -> N,
  eq : (N, N) -> Bool,
) -> ((T, M)) -> Bool {
  fn(x : (T, M)) { self.run(x.0).fmap(fn(y) { cong(y, x.1) }).equal_by(eq) }
}

///|
pub fn[T, M, N : Eq] Axiom::to_property_parametric_eq(
  self : Axiom[T],
  cong : (T, M) -> N,
) -> ((T, M)) -> Bool {
  self.to_property_parametric(cong, Eq::equal)
}
