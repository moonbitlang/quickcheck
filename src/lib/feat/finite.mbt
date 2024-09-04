pub struct Finite[T] {
  fCard : BigInt
  fIndex : (BigInt) -> T
}

pub fn fin_empty[T]() -> Finite[T] {
  { fCard: 0, fIndex: fn(_x) { abort("index empty") } }
}

pub fn fin_union[T](f1 : Finite[T], f2 : Finite[T]) -> Finite[T] {
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

pub fn op_add[T](self : Finite[T], other : Finite[T]) -> Finite[T] {
  fin_union(self, other)
}

pub fn fin_fmap[T, U](f : (T) -> U, f1 : Finite[T]) -> Finite[U] {
  { fCard: f1.fCard, fIndex: fn(i) { f((f1.fIndex)(i)) } }
}

pub fn fin_pure[T](x : T) -> Finite[T] {
  {
    fCard: 1,
    fIndex: fn(i) { if i == 0 { x } else { abort("index out of bounds") } },
  }
}

pub fn fin_cart[T, U](f1 : Finite[T], f2 : Finite[U]) -> Finite[(T, U)] {
  {
    fCard: f1.fCard * f2.fCard,
    fIndex: fn(i) {
      let j = i / f2.fCard
      let k = i % f2.fCard
      ((f1.fIndex)(j), (f2.fIndex)(k))
    },
  }
}

pub fn fin_app[M, N](f : Finite[(M) -> N], e : Finite[M]) -> Finite[N] {
  fin_fmap(fn { (g, x) => g(x) }, fin_cart(f, e))
}

pub fn fin_bind[M, N](m : Finite[M], f : (M) -> Finite[N]) -> Finite[N] {
  { fCard: m.fCard, fIndex: fn(i) { (f((m.fIndex)(i)).fIndex)(0) } }
}

fn sum_sel[M](a : Array[Finite[M]]) -> (BigInt) -> M {
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

pub fn fin_concat[M](m : Array[Finite[M]]) -> Finite[M] {
  {
    fCard: sum(m.map(fn(x) { x.fCard })),
    fIndex: sum_sel(m.filter(fn(x) { x.fCard > 0 })),
  }
}

pub fn fin_mconcat[M](val : LazyList[Finite[M]]) -> Finite[M] {
  val.fold_left(fin_union, init=fin_empty())
}

pub fn to_array[T](self : Finite[T]) -> (BigInt, LazyList[T]) {
  (
    self.fCard,
    loop self.fCard, @lazy.Nil {
      0, acc => break acc
      n, acc =>
        continue n - 1, @lazy.Cons((self.fIndex)(n), @lazy.from_value(acc))
    },
  )
}

pub fn to_string[T : Show](self : Finite[T]) -> String {
  to_array(self).1.to_string()
}

pub fn output[T : Show](self : Finite[T], logger : Logger) -> Unit {
  logger.write_string(self.to_string())
}

pub fn fin_finite(i : BigInt) -> Finite[BigInt] {
  if i < 0 {
    fin_empty()
  } else {
    { fCard: i, fIndex: fn(j) { j } }
  }
}
