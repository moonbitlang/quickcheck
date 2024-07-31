pub trait Enumerable {
  enumerate() -> Enumerate[Self]
}

pub impl Enumerable for Bool with enumerate() {
  pay(fn() { union(singleton(true), singleton(false)) })
}

pub impl Enumerable for Int with enumerate() {
  pay(
    fn() {
      union(
        union(singleton(0), fmap(fn(x) { x + 1 }, Enumerable::enumerate())),
        fmap(fn(x) { x - 1 }, Enumerable::enumerate()),
      )
    },
  )
}

pub impl Enumerable for UInt with enumerate() {
  pay(
    fn() {
      union(singleton(0), fmap(fn(x) { x + 1U }, Enumerable::enumerate()))
    },
  )
}

pub impl[E : Enumerable] Enumerable for @immut/list.T[E] with enumerate() {
  pay(
    fn() {
      union(
        singleton(Nil),
        app(
          fmap(@tuple.curry(@immut/list.Cons), E::enumerate()),
          Enumerable::enumerate(),
        ),
      )
    },
  )
}
