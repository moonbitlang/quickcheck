///|
/// Types that can enumerate all of their values in size-indexed order.
pub(open) trait Enumerable {
  fn enumerate() -> Enumerate[Self]
}

///|
pub impl Enumerable for Bool with fn enumerate() {
  pay(fn() { sum(singleton(true), singleton(false)) })
}

///|
pub impl Enumerable for Int with fn enumerate() {
  make(fn(size) {
    if size < 0 {
      @ifseq.empty()
    } else if size == 0 {
      @ifseq.singleton(0)
    } else {
      @ifseq.sum(@ifseq.singleton(size), @ifseq.singleton(-size))
    }
  })
}

///|
pub impl Enumerable for Int64 with fn enumerate() {
  make(fn(size) {
    if size < 0 {
      @ifseq.empty()
    } else if size == 0 {
      @ifseq.singleton(0L)
    } else {
      let n = Int64::from_int(size)
      @ifseq.sum(@ifseq.singleton(n), @ifseq.singleton(-n))
    }
  })
}

///|
pub impl Enumerable for UInt with fn enumerate() {
  pay(() => singleton(0U) + Enumerable::enumerate().fmap(x => x + 1U))
}

///|
pub impl Enumerable for UInt64 with fn enumerate() {
  pay(() => singleton(0UL) + Enumerable::enumerate().fmap(x => x + 1UL))
}

///|
pub impl Enumerable for Byte with fn enumerate() {
  of_seq(@ifseq.map(Int::to_byte, @ifseq.up(0, 256)))
}

///|
fn char_from_index(idx : Int) -> Char {
  let cp = if idx < 55296 { idx } else { idx + 2048 }
  Int::unsafe_to_char(cp)
}

///|
pub impl Enumerable for Char with fn enumerate() {
  of_seq(@ifseq.map(char_from_index, @ifseq.up(0, 1112064)))
}

///|
pub impl[E : Enumerable] Enumerable for @moonbitlang/core/list.List[E] with fn enumerate() {
  consts(
    List([
      singleton(@list.empty()),
      unary((pair : (E, @moonbitlang/core/list.List[E])) => pair.1.add(pair.0)),
    ]),
  )
}

///|
pub impl[A : Enumerable, B : Enumerable] Enumerable for (A, B) with fn enumerate() {
  pay(() => product(A::enumerate(), B::enumerate()))
}

///|
pub impl[E : Enumerable] Enumerable for E? with fn enumerate() {
  pay(() => singleton(None) + E::enumerate().fmap(x => Some(x)))
}

///|
pub impl[T : Enumerable, E : Enumerable] Enumerable for Result[T, E] with fn enumerate() {
  pay(() => E::enumerate().fmap(x => Err(x)) + T::enumerate().fmap(x => Ok(x)))
}

///|
pub impl Enumerable for Unit with fn enumerate() {
  singleton(())
}
