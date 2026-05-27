///|
pub type Index = BigInt

///|
pub struct Seq[T] {
  length : Index
  get : (Index) -> T
  foreach : (Bool, (T) -> Unit) -> Unit
}

///|
fn[T] make(
  length : Index,
  get : (Index) -> T,
  foreach : (Bool, (T) -> Unit) -> Unit,
) -> Seq[T] {
  { length, get, foreach }
}

///|
pub fn[T] empty() -> Seq[T] {
  make(0, fn(_i) { abort("Index is out of bounds.") }, fn(_sense, _k) { () })
}

///|
pub fn[T] singleton(x : T) -> Seq[T] {
  make(1, fn(i) { if i == 0 { x } else { abort("Index is out of bounds.") } }, fn(
    _sense,
    k,
  ) {
    k(x)
  })
}

///|
pub fn[T] is_empty(s : Seq[T]) -> Bool {
  s.length == 0
}

///|
pub fn[T] length(s : Seq[T]) -> Index {
  s.length
}

///|
pub fn[T] get(s : Seq[T], i : Index) -> T {
  (s.get)(i)
}

///|
pub fn[T] each(s : Seq[T], k : (T) -> Unit) -> Unit {
  (s.foreach)(true, k)
}

///|
pub fn[T] rev(s : Seq[T]) -> Seq[T] {
  if is_empty(s) || s.length == 1 {
    s
  } else {
    make(s.length, fn(i) { get(s, s.length - 1 - i) }, fn(sense, k) {
      (s.foreach)(!sense, k)
    })
  }
}

///|
pub fn[T] sum(s1 : Seq[T], s2 : Seq[T]) -> Seq[T] {
  if is_empty(s1) {
    s2
  } else if is_empty(s2) {
    s1
  } else {
    let n1 = s1.length
    make(
      n1 + s2.length,
      fn(i) { if i < n1 { get(s1, i) } else { get(s2, i - n1) } },
      fn(sense, k) {
        if sense {
          each(s1, k)
          each(s2, k)
        } else {
          (s2.foreach)(sense, k)
          (s1.foreach)(sense, k)
        }
      },
    )
  }
}

///|
pub fn[T, U] product(s1 : Seq[T], s2 : Seq[U]) -> Seq[(T, U)] {
  if is_empty(s1) || is_empty(s2) {
    empty()
  } else {
    let n2 = s2.length
    make(
      s1.length * n2,
      fn(i) {
        let q = i / n2
        let r = i % n2
        (get(s1, q), get(s2, r))
      },
      fn(sense, k) {
        (s1.foreach)(sense, fn(x1) {
          (s2.foreach)(sense, fn(x2) { k((x1, x2)) })
        })
      },
    )
  }
}

///|
pub fn[T, U] map(f : (T) -> U, s : Seq[T]) -> Seq[U] {
  if is_empty(s) {
    empty()
  } else {
    make(s.length, fn(i) { f(get(s, i)) }, fn(sense, k) {
      (s.foreach)(sense, fn(x) { k(f(x)) })
    })
  }
}

///|
pub fn up(a : Int, b : Int) -> Seq[Int] {
  if a >= b {
    empty()
  } else {
    make(
      BigInt::from_int(b - a),
      fn(i) {
        let offset = i.to_int()
        let x = a + offset
        if x < a || x >= b {
          abort("Index is out of bounds.")
        } else {
          x
        }
      },
      fn(sense, k) {
        if sense {
          for x in a..<b {
            k(x)
          }
        } else {
          for x in (a + 1)..<=b {
            k(b - (x - a))
          }
        }
      },
    )
  }
}

///|
pub fn[T] bigsum(parts : Array[Seq[T]]) -> Seq[T] {
  parts.fold(init=empty(), fn(acc, part) { sum(acc, part) })
}

///|
pub fn[A, B] exists(xs : Array[A], f : (A) -> Seq[B]) -> Seq[B] {
  bigsum(xs.map(f))
}

///|
pub fn[T] to_iter(s : Seq[T]) -> Iter[T] {
  let mut i : BigInt = 0
  Iter::new(fn() -> T? {
    if i < s.length {
      let x = get(s, i)
      i = i + 1
      Some(x)
    } else {
      None
    }
  })
}

///|
pub fn[T] to_iter_materialized(s : Seq[T]) -> Iter[T] {
  let values : Array[T] = []
  each(s, fn(x) { values.push(x) })
  let mut i = 0
  Iter::new(fn() -> T? {
    if i < values.length() {
      let x = values[i]
      i = i + 1
      Some(x)
    } else {
      None
    }
  })
}

///|
pub fn[T] to_array(s : Seq[T]) -> Array[T] {
  let values : Array[T] = []
  each(s, fn(x) { values.push(x) })
  values
}
