///|
pub(open) trait Enumerable {
  enumerate() -> Enumerate[Self]
}

///|
pub impl Enumerable for Bool with enumerate() {
  pay(fn() { singleton(true) + singleton(false) })
}

///|

///|
pub impl Enumerable for Int with enumerate() {
  letrec int_parts_from: (Int) -> @lazy.LazyList[Finite[Int]] = n => @lazy.Cons(
    fin_pure(n),
    @lazy.LazyRef::from_thunk(fn() {
      @lazy.Cons(
        fin_pure(-n),
        @lazy.LazyRef::from_thunk(fn() { int_parts_from(n + 1) }),
      )
    }),
  )

  {
    parts: @lazy.Cons(
      fin_pure(0),
      @lazy.LazyRef::from_thunk(fn() { int_parts_from(1) }),
    ),
  }
}

///|
pub impl Enumerable for Int64 with enumerate() {
  letrec int64_parts_from: (Int64) -> @lazy.LazyList[Finite[Int64]] = n => @lazy.Cons(
    fin_pure(n),
    @lazy.LazyRef::from_thunk(fn() {
      @lazy.Cons(
        fin_pure(-n),
        @lazy.LazyRef::from_thunk(fn() { int64_parts_from(n + 1) }),
      )
    }),
  )

  {
    parts: @lazy.Cons(
      fin_pure(0L),
      @lazy.LazyRef::from_thunk(fn() { int64_parts_from(1L) }),
    ),
  }
}

///|
pub impl Enumerable for UInt with enumerate() {
  pay(fn() { singleton(0U) + Enumerable::enumerate().fmap(fn(x) { x + 1U }) })
}

///|
pub impl Enumerable for UInt64 with enumerate() {
  pay(fn() { singleton(0UL) + Enumerable::enumerate().fmap(fn(x) { x + 1UL }) })
}

///|
pub impl[E : Enumerable] Enumerable for @moonbitlang/core/list.List[E] with enumerate() {
  consts(
    @list.from_array([
      singleton(@list.empty()),
      unary(
        @utils.pair_function(fn(e : E, lst : @moonbitlang/core/list.List[E]) {
          lst.add(e)
        }),
      ),
    ]),
  )
}

///|
pub impl[A : Enumerable, B : Enumerable] Enumerable for (A, B) with enumerate() {
  pay(fn() { product(A::enumerate(), B::enumerate()) })
}

///|
pub impl[E : Enumerable] Enumerable for E? with enumerate() {
  pay(fn() { singleton(None) + E::enumerate().fmap(x => Option::Some(x)) })
}

///|
pub impl[T : Enumerable, E : Enumerable] Enumerable for Result[T, E] with enumerate() {
  pay(fn() {
    E::enumerate().fmap(x => Err(x)) + T::enumerate().fmap(x => Ok(x))
  })
}

///|
pub impl Enumerable for Unit with enumerate() {
  singleton(())
}
