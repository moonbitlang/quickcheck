struct Gen[T] {
  gen : (Int, RandomState) -> T
}

/// Monad
pub fn pure[T](val : T) -> Gen[T] {
  { gen: fn(_n, _s) { val } }
}

pub fn bind[T, U](gen : Gen[T], f : (T) -> Gen[U]) -> Gen[U] {
  {
    gen: fn(n, s) {
      let s2 = s.split()
      let t = (gen.gen)(n, s)
      (f(t).gen)(n, s2)
    },
  }
}

/// Combinators
pub fn small_int(_i : Int, rs : RandomState) -> Int {
  let p = rs.rs.gen_double()
  if p < 0.75 {
    rs.rs.gen_int() % 10
  } else {
    rs.rs.gen_int() % 100
  }
}

pub fn nat(_i : Int, rs : RandomState) -> Int {
  let p = rs.rs.gen_double()
  if p < 0.5 {
    rs.rs.gen_int() % 10
  } else if p < 0.75 {
    rs.rs.gen_int() % 100
  } else if p < 0.95 {
    rs.rs.gen_int() % 1000
  } else {
    rs.rs.gen_int() % 10000
  }
}

pub fn bool(_i : Int, rs : RandomState) -> Bool {
  rs.rs.gen_double() < 0.5
}

pub fn neg_int(_i : Int, rs : RandomState) -> Int {
  -rs.rs.gen_int()
}

pub fn pair[X, Y](gx : Gen[X], gy : Gen[Y]) -> Gen[(X, Y)] {
  {
    gen: fn(n, s) {
      let x = (gx.gen)(n, s)
      let y = (gy.gen)(n, s)
      (x, y)
    },
  }
}