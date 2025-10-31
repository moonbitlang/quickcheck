///|
pub(open) trait Enumerable {
  enumerate() -> Enumerate[Self]
}

///|
pub impl Enumerable for Bool with enumerate() {
  pay(fn() { singleton(true) + singleton(false) })
}

///|
pub impl Enumerable for Int with enumerate() {
  pay(fn() {
    singleton(0) +
    Enumerable::enumerate().fmap(fn(x) { x + 1 }) +
    Enumerable::enumerate().fmap(fn(x) { x - 1 })
  })
}

///|
pub impl Enumerable for Int64 with enumerate() {
  pay(fn() {
    singleton(0L) +
    Enumerable::enumerate().fmap(fn(x) { x + 1L }) +
    Enumerable::enumerate().fmap(fn(x) { x - 1L })
  })
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
  pay(fn() { singleton(None) + E::enumerate().fmap(Option::Some(_)) })
}

///|
pub impl[T : Enumerable, E : Enumerable] Enumerable for Result[T, E] with enumerate() {
  pay(fn() {
    E::enumerate().fmap(Result::Err(_)) + T::enumerate().fmap(Result::Ok(_))
  })
}

///|
pub impl Enumerable for Unit with enumerate() {
  singleton(())
}
