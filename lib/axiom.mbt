struct Axiom[T] {
  lhs : T
  rhs : T
} derive(Show)

pub fn Axiom::new[T](lhs : T, rhs : T) -> Axiom[T] {
  { lhs, rhs }
}
