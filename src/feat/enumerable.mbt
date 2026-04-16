///|
/// Types that can enumerate all of their values in size-indexed order.
///
/// `enumerate()` returns an `Enumerate[Self]`: a lazy stream of parts
/// where the `k`-th part contains every value of size `k`. Primitive
/// types already implement this trait; algebraic composites (sums,
/// products, recursive types) compose via `singleton` / `+` /
/// `product` / `unary` wrapped in a single `pay`.
///
/// See the package README for the full contract, the built-in
/// instance table, and the recipe for implementing `Enumerable` on a
/// user-defined recursive type.
pub(open) trait Enumerable {
  enumerate() -> Enumerate[Self]
}

///|
pub impl Enumerable for Bool with enumerate() {
  pay(() => singleton(true) + singleton(false))
}

///|

///|
pub impl Enumerable for Int with enumerate() {
  letrec int_parts_from: (Int) -> @lazy.LazyList[Finite[Int]] = n => {
    Cons(
      fin_pure(n),
      @lazy.LazyRef::from_thunk(() => {
        Cons(
          fin_pure(-n),
          @lazy.LazyRef::from_thunk(() => int_parts_from(n + 1)),
        )
      }),
    )
  }

  {
    parts: Cons(fin_pure(0), @lazy.LazyRef::from_thunk(() => int_parts_from(1))),
  }
}

///|
pub impl Enumerable for Int64 with enumerate() {
  letrec int64_parts_from: (Int64) -> @lazy.LazyList[Finite[Int64]] = n => {
    Cons(
      fin_pure(n),
      @lazy.LazyRef::from_thunk(() => {
        Cons(
          fin_pure(-n),
          @lazy.LazyRef::from_thunk(() => int64_parts_from(n + 1)),
        )
      }),
    )
  }

  {
    parts: Cons(
      fin_pure(0L),
      @lazy.LazyRef::from_thunk(() => int64_parts_from(1L)),
    ),
  }
}

///|
pub impl Enumerable for UInt with enumerate() {
  pay(() => singleton(0U) + Enumerable::enumerate().fmap(x => x + 1U))
}

///|
pub impl Enumerable for UInt64 with enumerate() {
  pay(() => singleton(0UL) + Enumerable::enumerate().fmap(x => x + 1UL))
}

///|
pub impl Enumerable for Byte with enumerate() {
  let byte_card : BigInt = 256
  let byte_from_index = (i : BigInt) => Int::to_byte(i.to_int())
  {
    parts: Cons(
      { fCard: byte_card, fIndex: byte_from_index },
      @lazy.LazyRef::from_value(Nil),
    ),
  }
}

///|
pub impl Enumerable for Char with enumerate() {
  let char_card : BigInt = 1112064
  let char_from_index = (i : BigInt) => {
    let idx = i.to_int()
    let cp = if idx < 55296 { idx } else { idx + 2048 }
    Int::unsafe_to_char(cp)
  }
  {
    parts: Cons(
      { fCard: char_card, fIndex: char_from_index },
      @lazy.LazyRef::from_value(Nil),
    ),
  }
}

///|
pub impl[E : Enumerable] Enumerable for @moonbitlang/core/list.List[E] with enumerate() {
  consts(
    @list.from_array([
      singleton(@list.empty()),
      unary((pair : (E, @moonbitlang/core/list.List[E])) => pair.1.add(pair.0)),
    ]),
  )
}

///|
pub impl[A : Enumerable, B : Enumerable] Enumerable for (A, B) with enumerate() {
  pay(() => product(A::enumerate(), B::enumerate()))
}

///|
pub impl[E : Enumerable] Enumerable for E? with enumerate() {
  pay(() => singleton(None) + E::enumerate().fmap(x => Some(x)))
}

///|
pub impl[T : Enumerable, E : Enumerable] Enumerable for Result[T, E] with enumerate() {
  pay(() => E::enumerate().fmap(x => Err(x)) + T::enumerate().fmap(x => Ok(x)))
}

///|
pub impl Enumerable for Unit with enumerate() {
  singleton(())
}
