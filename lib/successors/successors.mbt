struct Succs[A] {
  current : A
  successor : Iter[A]
} derive(Show)

pub fn fmap[A, B](self : Succs[A], f : (A) -> B) -> Succs[B] {
  { current: f(self.current), successor: self.successor.map(f) }
}

pub fn pure[A](x : A) -> Succs[A] {
  { current: x, successor: Iter::empty() }
}

pub fn ap[A, B](self : Succs[(A) -> B], v : Succs[A]) -> Succs[B] {
  {
    current: (self.current)(v.current),
    successor: self.successor
    .map(fn { f => f(v.current) })
    .concat(v.successor.map(self.current)),
  }
}

pub fn bind[A, B](self : Succs[A], f : (A) -> Succs[B]) -> Succs[B] {
  {
    current: f(self.current).current,
    successor: self.successor
    .map(fn(x) { f(x).current })
    .concat(f(self.current).successor),
  }
}
