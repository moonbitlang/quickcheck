pub struct Finite[T] {
  fCard : Int
  fIndex : (Int) -> T
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
  fin_fmap(
    fn(in) {
      let (g, x) = in
      g(x)
    },
    fin_cart(f, e),
  )
}

fn sum_sel[M](a : Array[Finite[M]]) -> (Int) -> M {
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

pub fn fin_mconcat[M](val: LazyList[Finite[M]]) -> Finite[M] {
  val.fold_left(fin_union, init=fin_empty())
}

pub fn to_array[T](self : Finite[T]) -> (Int, Array[T]) {
  (self.fCard, Array::makei(self.fCard, self.fIndex))
}

pub fn to_string[T : Show](self : Finite[T]) -> String {
  to_array(self).1.to_string()
}

pub fn fin_finite(i : Int) -> Finite[Int] {
  if i < 0 {
    fin_empty()
  } else {
    { fCard: i, fIndex: fn(j) { j } }
  }
}
