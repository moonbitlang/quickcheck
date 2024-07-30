struct Gen[T] {
  gen : (Int, RandomState) -> T
}

pub fn Gen::new[T](gen : (Int, RandomState) -> T) -> Gen[T] {
  { gen, }
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

pub fn pair[X, Y](gx : Gen[X], gy : Gen[Y]) -> Gen[(X, Y)] {
  {
    gen: fn(n, s) {
      let x = (gx.gen)(n, s)
      let y = (gy.gen)(n, s)
      (x, y)
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

pub fn numeral(_i : Int, rs : RandomState) -> Char {
  let c = rs.rs.gen_int() % 10
  Char::from_int(c + 48)
}

pub fn alphabet(_i : Int, rs : RandomState) -> Char {
  let c = rs.rs.gen_int() % 26
  Char::from_int(c + 65)
}

pub fn int_bound(bound : Int) -> Gen[Int] {
  {
    gen: fn(_i, rs) {
      let j = rs.rs.gen_int() % bound
      j.abs()
    },
  }
}

pub fn int_range(lo : Int, hi : Int) -> Gen[Int] {
  {
    gen: fn(_i, rs) {
      let j = rs.rs.gen_int() % (hi - lo)
      j + lo
    },
  }
}

test "" {
  let a:Array[Int] = sample(1000)
  println(a)
}

test "property testing" {
  
}