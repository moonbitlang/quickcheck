///|
pub(all) struct Finite[T] {
  fCard : BigInt
  fIndex : (BigInt) -> T
}

///|
pub fn[T] fin_empty() -> Finite[T] {
  { fCard: 0, fIndex: fn(_x) { abort("index empty") } }
}

///|
pub fn[T] fin_union(f1 : Finite[T], f2 : Finite[T]) -> Finite[T] {
  if f1.fCard == 0 {
    f2
  } else if f2.fCard == 0 {
    f1
  } else {
    {
      fCard: f1.fCard + f2.fCard,
      fIndex: fn(i) {
        if i < f1.fCard {
          (f1.fIndex)(i)
        } else {
          (f2.fIndex)(i - f1.fCard)
        }
      },
    }
  }
}

///|
pub fn[T] Finite::op_add(self : Finite[T], other : Finite[T]) -> Finite[T] {
  fin_union(self, other)
}

///|
pub fn[T, U] fin_fmap(f : (T) -> U, f1 : Finite[T]) -> Finite[U] {
  { fCard: f1.fCard, fIndex: fn(i) { f((f1.fIndex)(i)) } }
}

///|
pub fn[T] fin_pure(x : T) -> Finite[T] {
  {
    fCard: 1,
    fIndex: fn(i) {
      guard i == 0 else { abort("index out of bounds") }
      x
    },
  }
}

///|
pub fn[T, U] fin_cart(f1 : Finite[T], f2 : Finite[U]) -> Finite[(T, U)] {
  {
    fCard: f1.fCard * f2.fCard,
    fIndex: fn(i) {
      let j = i / f2.fCard
      let k = i % f2.fCard
      ((f1.fIndex)(j), (f2.fIndex)(k))
    },
  }
}

///|
pub fn[M, N] fin_app(f : Finite[(M) -> N], e : Finite[M]) -> Finite[N] {
  fin_fmap(
    fn(p) {
      let (g, x) = p
      g(x)
    },
    fin_cart(f, e),
  )
}

///|
pub fn[M, N] fin_bind(m : Finite[M], f : (M) -> Finite[N]) -> Finite[N] {
  { fCard: m.fCard, fIndex: fn(i) { (f((m.fIndex)(i)).fIndex)(0) } }
}

///|
fn[M] sum_sel(a : Array[Finite[M]]) -> (BigInt) -> M {
  fn(idx) {
    for j = 0, i = idx; j < a.length(); {
      if i < a[j].fCard {
        break (a[j].fIndex)(i)
      } else {
        continue j + 1, i - a[j].fCard
      }
    } else {
      abort("index out of bounds")
    }
  }
}

///|
pub fn[M] fin_concat(m : Array[Finite[M]]) -> Finite[M] {
  {
    fCard: sum(m.map(fn(x) { x.fCard })),
    fIndex: sum_sel(m.filter(fn(x) { x.fCard > 0 })),
  }
}

///|
pub fn[M] fin_mconcat(val : LazyList[Finite[M]]) -> Finite[M] {
  val.fold_left(fin_union, init=fin_empty())
}

///|
pub fn[T] Finite::to_array(self : Finite[T]) -> (BigInt, @list.List[T]) {
  (
    self.fCard,
    loop (self.fCard, @list.empty()) {
      (0, acc) => acc
      (n, acc) => continue (n - 1, acc.add((self.fIndex)(n)))
    },
  )
}

///|
pub impl[T : Show] Show for Finite[T] with output(self, logger) {
  logger.write_object(self.to_array().1)
}

///|
pub fn fin_finite(i : BigInt) -> Finite[BigInt] {
  if i < 0 {
    fin_empty()
  } else {
    { fCard: i, fIndex: fn(j) { j } }
  }
}
