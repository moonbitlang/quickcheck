///|
fn deltas(u : UInt) -> Iter[UInt] {
  match u {
    0 => Iter::empty()
    1 => Iter::singleton(1)
    n => {
      let mid = n / 2
      if n % 2 == 0 {
        Iter::concat(Iter::singleton(mid), deltas(mid))
      } else {
        Iter::concat(Iter::singleton(mid + 1), deltas(mid))
      }
    }
  }
}

///|
fn binary(u : UInt) -> Iter[UInt] {
  fn go(n : UInt, xs : Iter[_]) {
    match xs.head() {
      None => Iter::empty()
      Some(x) => Iter::singleton(n) + go(n + x, xs.drop(1))
    }
  }

  go(0U, deltas(u))
}

///|
pub fn[A, B, C] second(f : (B) -> C, v : (A, B)) -> (A, C) {
  let (a, b) = v
  (a, f(b))
}
