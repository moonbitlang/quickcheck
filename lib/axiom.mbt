struct Equivalence[T] {
  lhs : T
  rhs : T
} derive(Show)

pub fn Equivalence::new[T](lhs : T, rhs : T) -> Equivalence[T] {
  { lhs, rhs }
}

pub fn Equivalence::fmap[T, U](
  self : Equivalence[T],
  f : (T) -> U
) -> Equivalence[U] {
  { lhs: f(self.lhs), rhs: f(self.rhs) }
}

pub fn Equivalence::bind[T, U](
  self : Equivalence[T],
  f : (T) -> Equivalence[U]
) -> Equivalence[U] {
  let lhs = f(self.lhs).lhs
  let rhs = f(self.rhs).rhs
  { lhs, rhs }
}

pub fn Equivalence::ap[T, U](
  self : Equivalence[(T) -> U],
  other : Equivalence[T]
) -> Equivalence[U] {
  let lhs = (self.lhs)(other.lhs)
  let rhs = (self.rhs)(other.rhs)
  { lhs, rhs }
}

pub fn pure_eq[T](x : T) -> Equivalence[T] {
  { lhs: x, rhs: x }
}

pub fn is_equal[T : Eq](self : Equivalence[T]) -> Bool {
  self.lhs == self.rhs
}

pub fn equal_by[T](self : Equivalence[T], eq : (T, T) -> Bool) -> Bool {
  eq(self.lhs, self.rhs)
}

struct Axiom[T] {
  run_axiom : (T) -> Equivalence[T]
}

pub fn Axiom::new[T](run_axiom : (T) -> Equivalence[T]) -> Axiom[T] {
  { run_axiom, }
}

pub fn Axiom::run[T](self : Axiom[T], x : T) -> Equivalence[T] {
  (self.run_axiom)(x)
}


pub fn to_property[T, U](
  self : Axiom[T],
  cong : (T) -> U,
  eq : (U, U) -> Bool
) -> (T) -> Bool {
  fn(x : T) { self.run(x).fmap(cong).equal_by(eq) }
}

pub fn to_property_eq[T, U : Eq](
  self : Axiom[T],
  cong : (T) -> U
) -> (T) -> Bool {
  self.to_property(cong, Eq::op_equal)
}

pub fn to_property_parametric[T, M, N](
  self : Axiom[T],
  cong : (T, M) -> N,
  eq : (N, N) -> Bool
) -> ((T, M)) -> Bool {
  fn(x : (T, M)) { self.run(x.0).fmap(fn(y) { cong(y, x.1) }).equal_by(eq) }
}

pub fn to_property_parametric_eq[T, M, N : Eq](
  self : Axiom[T],
  cong : (T, M) -> N
) -> ((T, M)) -> Bool {
  self.to_property_parametric(cong, Eq::op_equal)
}
