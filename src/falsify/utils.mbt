///|
fn deltas(u : UInt) -> Iter[UInt] {
  match u {
    0 => Iter::empty()
    1 => Iter::singleton(1)
    n => {
      let mid = n / 2
      if n % 2 == 0 {
        deltas(mid).prepend(mid)
      } else {
        deltas(mid).prepend(mid + 1)
      }
    }
  }
}

///|
fn binary(u : UInt) -> Iter[UInt] {
  fn go(n : UInt, xs : Iter[_]) {
    match xs.head() {
      None => Iter::empty()
      Some(x) => go(n + x, xs.drop(1)).prepend(n)
    }
  }

  go(0U, deltas(u))
}

///|
pub fn[A, B, C] second(f : (B) -> C, v : (A, B)) -> (A, C) {
  let (a, b) = v
  (a, f(b))
}
