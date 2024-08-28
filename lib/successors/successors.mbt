struct Succs[A] {
  current : A
  successor : Iter[A]
} derive(Show)

pub fn new[A](current : A, iter : Iter[A]) -> Succs[A] {
  { current, successor: iter }
}

pub fn fmap[A, B](self : Succs[A], f : (A) -> B) -> Succs[B] {
  { current: f(self.current), successor: self.successor.map(f) }
}

pub fn pure[A](x : A) -> Succs[A] {
  { current: x, successor: Iter::empty() }
}

pub fn ap[A, B](self : Succs[A], f : Succs[(A) -> B]) -> Succs[B] {
  {
    current: (f.current)(self.current),
    successor: f.successor
    .map(fn { f => f(self.current) })
    .concat(self.successor.map(f.current)),
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
