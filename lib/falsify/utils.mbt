pub fn deltas(u : UInt) -> @lazy.LazyList[UInt] {
  match u {
    0 => Nil
    1 => Cons(1, fn() { Nil })
    n => {
      let mid = n / 2
      if n % 2 == 0 {
        Cons(mid, fn() { deltas(mid) })
      } else {
        Cons(mid + 1, fn() { deltas(mid) })
      }
    }
  }
}

pub fn binary(u : UInt) -> @lazy.LazyList[UInt] {
  fn go {
    _, @lazy.Nil => @lazy.Nil
    (n : UInt), Cons(x, xs) => @lazy.Cons(n, fn() { go(n + x, xs()) })
  }

  go(0U, deltas(u))
}

pub fn second[A, B, C](f : (B) -> C, v : (A, B)) -> (A, C) {
  let (a, b) = v
  (a, f(b))
}
