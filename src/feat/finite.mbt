///|
/// A finite chunk of `T` values, represented compactly as a
/// cardinality plus an indexer rather than as a stored collection.
/// No values are materialised until `fIndex` is called.
///
/// Fields:
/// - `fCard`: number of elements (≥ 0). Zero denotes the empty chunk.
/// - `fIndex`: `(i : BigInt) -> T`, total on `[0, fCard)`.
///
/// `Finite[T]` is the basic building block used by `Enumerate[T]`:
/// one part per size class. The combinators below give it a ring-like
/// algebra (disjoint union, Cartesian product, maps, fmap).
pub(all) struct Finite[T] {
  fCard : BigInt
  fIndex : (BigInt) -> T
}

///|
/// The empty chunk: cardinality zero, indexer that aborts. Identity
/// for `fin_union`; absorbing element for `fin_cart`.
pub fn[T] fin_empty() -> Finite[T] {
  { fCard: 0, fIndex: _ => abort("index empty") }
}

///|
/// Disjoint union: append `f2` after `f1`. Elements of `f1` keep
/// their positions `[0, f1.fCard)`; elements of `f2` move up to
/// `[f1.fCard, f1.fCard + f2.fCard)`. Empty operands short-circuit.
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
#deprecated
pub fn[T] Finite::op_add(self : Finite[T], other : Finite[T]) -> Finite[T] {
  fin_union(self, other)
}

///|
/// `+` as an alias for `fin_union`. Not an `Add` trait impl, because
/// it's defined directly as a method on `Finite[T]` for `T` generic
/// over any type (not constrained to `Add`).
pub impl[T] Add for Finite[T] with add(self, other) {
  fin_union(self, other)
}

///|
/// Map `f` over the indexer: same cardinality, each element rewritten.
pub fn[T, U] fin_fmap(f : (T) -> U, f1 : Finite[T]) -> Finite[U] {
  { fCard: f1.fCard, fIndex: fn(i) { f((f1.fIndex)(i)) } }
}

///|
/// One-element chunk carrying exactly `x`. Indexer accepts `0`, aborts
/// otherwise.
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
/// Cartesian product: cardinality is the product, index decomposes
/// `i` into `(i / f2.fCard, i % f2.fCard)` so the result walks `f1`
/// in the outer loop and `f2` in the inner loop.
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
/// Applicative apply on `Finite`: combine a chunk of functions with a
/// chunk of arguments into a chunk of results. Cardinality multiplies.
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
/// Monadic bind on `Finite`: unlike `fin_cart`, this collapses to a
/// single element per `m` (it uses `f((m.fIndex)(i)).fIndex(0)`), so
/// the cardinality stays equal to `m.fCard`. Used by internal feat
/// machinery that needs to sequence a computation without multiplying
/// the chunk size.
pub fn[M, N] fin_bind(m : Finite[M], f : (M) -> Finite[N]) -> Finite[N] {
  { fCard: m.fCard, fIndex: fn(i) { (f((m.fIndex)(i)).fIndex)(0) } }
}

///|
fn[M] sum_sel(a : Array[Finite[M]]) -> (BigInt) -> M {
  fn(idx) {
    for j = 0, i = idx {
      if i < a[j].fCard || j >= a.length() {
        break (a[j].fIndex)(i)
      } else {
        continue j + 1, i - a[j].fCard
      }
    }
  }
}

///|
/// Concatenate an `Array` of chunks end-to-end. Empty chunks are
/// filtered before indexing so the resulting selector skips them.
pub fn[M] fin_concat(m : Array[Finite[M]]) -> Finite[M] {
  {
    fCard: sum(m.map(fn(x) { x.fCard })),
    fIndex: sum_sel(m.filter(fn(x) { x.fCard > 0 })),
  }
}

///|
/// Concatenate a `LazyList` of chunks end-to-end. Forces the spine of
/// the list, so only safe on finite inputs.
pub fn[M] fin_mconcat(val : LazyList[Finite[M]]) -> Finite[M] {
  let acc : Array[Finite[M]] = []
  for cur = val {
    match cur {
      Nil => break
      Cons(x, xs) => {
        acc.push(x)
        continue xs.force()
      }
    }
  }
  let fin = fin_concat(acc)
  if fin.fCard == 0 {
    fin_empty()
  } else {
    fin
  }
}

///|
/// Lazy traversal over the chunk: walks indices `0, 1, 2, …, fCard-1`
/// and yields `fIndex(i)` at each step. Because MoonBit's
/// `for x in <expr>` desugars to `<expr>.iter()`, this is what lets
/// you use a `Finite[T]` directly with the loop sugar.
///
/// The traversal is lazy: early `break` stops calling `fIndex`.
/// Like every `Iter` in MoonBit it is single-shot.
pub fn[T] Finite::iter(self : Finite[T]) -> Iter[T] {
  let card = self.fCard
  let fi = self.fIndex
  let mut i : BigInt = 0
  Iter::new(() => {
    if i < card {
      let v = fi(i)
      i = i + 1
      Some(v)
    } else {
      None
    }
  })
}

///|
test "iter walks 0..fCard" {
  assert_eq(fin_finite(5).iter().collect(), [0, 1, 2, 3, 4])
  let f : Finite[Int] = fin_empty()
  assert_eq(f.iter().collect(), [])
}

///|
test "for x in finite walks every element" {
  let acc : Array[BigInt] = []
  for x in fin_finite(3) {
    acc.push(x)
  }
  assert_eq(acc, [0, 1, 2])
}

///|
test "iter is lazy — early break stops walking" {
  let calls = Ref::new(0)
  let probe : Finite[Int] = {
    fCard: 1000,
    fIndex: fn(_i) {
      calls.val = calls.val + 1
      42
    },
  }
  for _x in probe {
    if calls.val == 3 {
      break
    }
  }
  assert_eq(calls.val, 3)
}

///|
/// Materialise a `Finite` to `(cardinality, list of all elements)`.
/// Eagerly evaluates every element — only suitable for small chunks.
pub fn[T] Finite::to_array(self : Finite[T]) -> (BigInt, @list.List[T]) {
  (
    self.fCard,
    for n = self.fCard, acc = @list.empty() {
      match n {
        0 => break acc
        _ => continue n - 1, acc.add((self.fIndex)(n - 1))
      }
    },
  )
}

///|
/// `Show` renders the full element list (via `to_array`). Don't call
/// on a very large chunk — it forces everything.
pub impl[T : Show] Show for Finite[T] with output(self, logger) {
  logger.write_object(self.to_array().1)
}

///|
/// The interval `[0, i)` as a `Finite[BigInt]`: cardinality `i`,
/// `fIndex(j) = j`. Negative `i` collapses to `fin_empty`.
pub fn fin_finite(i : BigInt) -> Finite[BigInt] {
  if i < 0 {
    fin_empty()
  } else {
    { fCard: i, fIndex: fn(j) { j } }
  }
}

///|
test "to_array" {
  inspect(
    fin_finite(5).to_array(),
    content="(5, @list.from_array([0, 1, 2, 3, 4]))",
  )
  inspect(
    (fin_empty() : Finite[Unit]).to_array(),
    content="(0, @list.from_array([]))",
  )
}
