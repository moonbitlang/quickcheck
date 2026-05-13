///|
/// A call-by-need list: either empty (`Nil`) or a head value paired
/// with a thunk producing the rest (`Cons(head, LazyRef<tail>)`).
/// Because the tail is a `LazyRef`, infinite lists (`repeat`,
/// `infinite_stream`) are representable and cheap — only the prefix
/// you iterate is forced.
pub(all) enum LazyList[T] {
  Nil
  Cons(T, LazyRef[LazyList[T]])
}

///|
/// The empty lazy list. Alias for `Nil`, provided so `Default`-style
/// callers can write `default()`.
pub fn[X] default() -> LazyList[X] {
  Nil
}

///|
/// Renders the list in the canonical `[a, b, c, ...]` form. **Forces
/// the entire list**, so don't call this on an infinite stream.
pub impl[T : Debug] Debug for LazyList[T] with to_repr(self) {
  let elems = []
  for cur = self {
    match cur {
      Nil => break
      Cons(x, xs) => {
        elems.push(to_repr(x))
        continue xs.force()
      }
    }
  }
  Repr::array(elems)
}

///|
/// Lazy traversal: walks the list head-first, yielding each element
/// as the iterator is pulled. Because MoonBit's `for x in <expr>`
/// desugars to `<expr>.iter()`, this enables
///
///     for x in lazy_list { ... }
///
/// on any `LazyList[T]`.
///
/// Only the cells actually consumed are forced — pairing with `take`
/// or breaking out of the loop early avoids touching the rest. Like
/// every `Iter` in MoonBit it is single-shot.
pub fn[T] LazyList::iter(self : LazyList[T]) -> Iter[T] {
  let mut cur = self
  Iter::new(() => {
    match cur {
      Nil => None
      Cons(x, xs) => {
        cur = xs.force()
        Some(x)
      }
    }
  })
}

///|
/// Return the element at position `i`. **O(n)** — walks the list from
/// the head. Aborts if `i` is negative or past the end.
///
/// ```mbt check
/// test {
///   let xs : LazyList[Int] = from_list(@list.from_array([10, 20, 30]))
///   assert_eq(xs.index(0), 10)
///   assert_eq(xs.index(2), 30)
/// }
/// ```
pub fn[T] LazyList::index(self : LazyList[T], i : Int) -> T {
  if i < 0 {
    abort("index out of bounds")
  } else {
    for cur = self, i = i {
      match (cur, i) {
        (Nil, _) => abort("index out of bounds")
        (Cons(x, _), 0) => break x
        (Cons(_, xs), i) => continue xs.force(), i - 1
      }
    }
  }
}

///|
/// Promote an eager `@list.List[T]` to its lazy counterpart. The
/// resulting `LazyList` has its tails in `LazyRef::from_value` form,
/// so no delayed computation is involved — just a type conversion.
///
/// ```mbt check
/// test {
///   let xs : LazyList[Int] = to_lazy(@list.from_array([1, 2, 3]))
///   @debug.assert_eq(xs.iter().collect(), [1, 2, 3])
/// }
/// ```
pub fn[T] to_lazy(ls : @list.List[T]) -> LazyList[T] {
  match ls {
    Empty => Nil
    More(x, tail=xs) => Cons(x, LazyRef::from_value(to_lazy(xs)))
  }
}

///|
/// All suffixes of the list, starting with `self` itself and ending
/// with `Nil`. The outer result is also a `LazyList`, so `tails` is
/// safe to apply to an infinite input — only the suffixes you inspect
/// are forced.
///
/// ```mbt check
/// test {
///   let xs : LazyList[Int] = from_list(@list.from_array([1, 2, 3]))
///   let lens = xs.tails().iter().map(t => t.length()).collect()
///   @debug.assert_eq(lens, [3, 2, 1, 0])
/// }
/// ```
pub fn[T] LazyList::tails(self : LazyList[T]) -> LazyList[LazyList[T]] {
  fn go(xs) {
    Cons(
      xs,
      match xs {
        Nil => LazyRef::from_value(Nil)
        Cons(_, xs1) => LazyRef::from_thunk(() => go(xs1.force()))
      },
    )
  }

  go(self)
}

///|
/// Lazy append. `(xs.concat(ys)).take(n)` only forces as many cells
/// as are consumed; the right-hand list is not touched until the left
/// runs out.
///
/// ```mbt check
/// test {
///   let xs : LazyList[Int] = from_list(@list.from_array([1, 2]))
///   let ys : LazyList[Int] = from_list(@list.from_array([3, 4]))
///   @debug.assert_eq(xs.concat(ys).iter().collect(), [1, 2, 3, 4])
/// }
/// ```
pub fn[T] LazyList::concat(
  self : LazyList[T],
  other : LazyList[T],
) -> LazyList[T] {
  match self {
    Nil => other
    Cons(x, xs) => Cons(x, LazyRef::from_thunk(() => xs.force().concat(other)))
  }
}

///|
/// `+` as an alias for `concat`.
pub impl[T] Add for LazyList[T] with add(self, other) {
  self.concat(other)
}

///|
/// An infinite stream of a single value: `[x, x, x, ...]`.
///
/// ```mbt check
/// test {
///   @debug.assert_eq(repeat('a').take(4).iter().collect(), ['a', 'a', 'a', 'a'])
/// }
/// ```
pub fn[T] repeat(val : T) -> LazyList[T] {
  Cons(val, LazyRef::from_thunk(() => repeat(val)))
}

///|
/// Apply `f` to every element. Lazy — `map(f, xs).take(n)` only
/// forces the first `n` cells.
///
/// ```mbt check
/// test {
///   let squared = infinite_stream(1, 1).map(x => x * x).take(4)
///   @debug.assert_eq(squared.iter().collect(), [1, 4, 9, 16])
/// }
/// ```
pub fn[T, U] LazyList::map(self : LazyList[T], f : (T) -> U) -> LazyList[U] {
  match self {
    Nil => Nil
    Cons(x, xs) => Cons(f(x), LazyRef::from_thunk(() => xs.force().map(f)))
  }
}

///|
/// Split at index `i`: returns `(take(i), drop(i))` in a single pass.
/// The prefix is eagerly collected; the suffix stays lazy.
///
/// ```mbt check
/// test {
///   let xs : LazyList[Int] = from_list(@list.from_array([1, 2, 3, 4]))
///   let (lhs, rhs) = xs.split_at(2)
///   @debug.assert_eq(lhs.iter().collect(), [1, 2])
///   @debug.assert_eq(rhs.iter().collect(), [3, 4])
/// }
/// ```
pub fn[T] LazyList::split_at(
  self : LazyList[T],
  i : Int,
) -> (LazyList[T], LazyList[T]) {
  if i <= 0 {
    (Nil, self)
  } else {
    let buf : Array[T] = []
    let rest = for cur = self, n = i {
      match (cur, n) {
        (Nil, _) => break Nil
        (Cons(x, xs), n) =>
          if n <= 0 {
            break Cons(x, xs)
          } else {
            buf.push(x)
            continue xs.force(), n - 1
          }
      }
    }
    let prefix = for j = buf.length() - 1, acc = Nil; j >= 0; {
      continue j - 1, Cons(buf[j], LazyRef::from_value(acc))
    } nobreak {
      acc
    }
    (prefix, rest)
  }
}

///|
/// Left fold. **Forces the entire list** before returning — not safe
/// on infinite input.
///
/// ```mbt check
/// test {
///   let xs : LazyList[Int] = from_list(@list.from_array([1, 2, 3, 4]))
///   assert_eq(xs.fold_left((acc, x) => acc + x, init=0), 10)
/// }
/// ```
pub fn[T, U] LazyList::fold_left(
  self : LazyList[T],
  f : (U, T) -> U,
  init~ : U,
) -> U {
  for cur = self, acc = init {
    match cur {
      Nil => break acc
      Cons(x, xs) => continue xs.force(), f(acc, x)
    }
  }
}

///|
/// Right fold. Naive / strict in the accumulator, so also not safe on
/// infinite input without extra care.
pub fn[T, U] LazyList::fold_right(
  self : LazyList[T],
  f : (T, U) -> U,
  init~ : U,
) -> U {
  match self {
    Nil => init
    Cons(y, ys) => f(y, ys.force().fold_right(f, init~))
  }
}

///|
/// First element. **Aborts** on `Nil`.
pub fn[T] LazyList::head(self : LazyList[T]) -> T {
  match self {
    Cons(x, _) => x
    Nil => abort("head of empty list")
  }
}

///|
/// Everything after the first element. **Aborts** on `Nil`.
pub fn[T] LazyList::tail(self : LazyList[T]) -> LazyList[T] {
  match self {
    Cons(_, xs) => xs.force()
    Nil => abort("tail of empty list")
  }
}

///|
/// Number of elements. **Forces the entire list** — don't call on
/// infinite input.
///
/// ```mbt check
/// test {
///   let xs : LazyList[Int] = from_list(@list.from_array([1, 2, 3]))
///   assert_eq(xs.length(), 3)
///   let ys : LazyList[Int] = Nil
///   assert_eq(ys.length(), 0)
/// }
/// ```
pub fn[T] LazyList::length(self : LazyList[T]) -> Int {
  self.fold_left((acc, _x) => acc + 1, init=0)
}

///|
/// Sum via `Add::add`, seeded with `init`. Forces the whole list.
pub fn[X : Add] sum(l : LazyList[X], init~ : X) -> X {
  l.fold_left(Add::add, init~)
}

///|
/// Element-wise combine. Stops when either input ends — the shorter
/// list wins and the rest of the longer one is ignored.
///
/// ```mbt check
/// test {
///   let xs : LazyList[Int] = from_list(@list.from_array([1, 2, 3]))
///   let ys : LazyList[Int] = from_list(@list.from_array([10, 20]))
///   let zs = zip_with((a, b) => a + b, xs, ys)
///   @debug.assert_eq(zs.iter().collect(), [11, 22])
/// }
/// ```
pub fn[A, B, C] zip_with(
  f : (A, B) -> C,
  xs : LazyList[A],
  ys : LazyList[B],
) -> LazyList[C] {
  match (xs, ys) {
    (Cons(x, xs), Cons(y, ys)) =>
      Cons(
        f(x, y),
        LazyRef::from_thunk(() => zip_with(f, xs.force(), ys.force())),
      )
    (_, _) => Nil
  }
}

///|
/// Prefix of the list whose elements satisfy `p`. Stops at the first
/// element that fails; the rest is not forced.
///
/// ```mbt check
/// test {
///   let nats : LazyList[Int] = infinite_stream(0, 1)
///   let small = nats.take_while(x => x < 4)
///   @debug.assert_eq(small.iter().collect(), [0, 1, 2, 3])
/// }
/// ```
pub fn[T] LazyList::take_while(
  self : LazyList[T],
  p : (T) -> Bool,
) -> LazyList[T] {
  match self {
    Nil => Nil
    Cons(x, xs) =>
      if p(x) {
        Cons(x, LazyRef::from_thunk(() => xs.force().take_while(p)))
      } else {
        Nil
      }
  }
}

///|
/// First `n` elements (or fewer, if the list is shorter). Lazy in the
/// tail — subsequent cells aren't forced unless requested.
///
/// ```mbt check
/// test {
///   let nats : LazyList[Int] = infinite_stream(0, 1)
///   @debug.assert_eq(nats.take(3).iter().collect(), [0, 1, 2])
/// }
/// ```
pub fn[T] LazyList::take(self : LazyList[T], n : Int) -> LazyList[T] {
  if n <= 0 {
    Nil
  } else {
    match self {
      Nil => Nil
      Cons(x, xs) => Cons(x, LazyRef::from_thunk(() => xs.force().take(n - 1)))
    }
  }
}

///|
/// Everything after the first `n` elements. Walks the first `n` cells
/// (forcing them) and returns the remaining suspension.
///
/// ```mbt check
/// test {
///   let nats : LazyList[Int] = infinite_stream(0, 1)
///   @debug.assert_eq(nats.drop(3).take(3).iter().collect(), [3, 4, 5])
/// }
/// ```
pub fn[T] LazyList::drop(self : LazyList[T], n : Int) -> LazyList[T] {
  if n <= 0 {
    self
  } else {
    for cur = self, i = n {
      match cur {
        Nil => break Nil
        Cons(_, xs) =>
          if i == 1 {
            break xs.force()
          } else {
            continue xs.force(), i - 1
          }
      }
    }
  }
}

///|
/// Skip the longest prefix where `p` holds and return the rest. Forces
/// cells while `p` is true; the suffix starting at the first failure
/// stays lazy.
pub fn[T] LazyList::drop_while(
  self : LazyList[T],
  p : (T) -> Bool,
) -> LazyList[T] {
  for cur = self {
    match cur {
      Nil => break Nil
      Cons(x, xs) => if p(x) { continue xs.force() } else { break Cons(x, xs) }
    }
  }
}

///|
/// Infinite arithmetic progression: `[start, start + step, start + 2*step, ...]`.
/// `X` must be `Add`-able. Lazy — consume via `take` / `take_while`.
///
/// ```mbt check
/// test {
///   let evens = infinite_stream(0, 2).take(5)
///   @debug.assert_eq(evens.iter().collect(), [0, 2, 4, 6, 8])
/// }
/// ```
pub fn[X : Add] infinite_stream(start : X, step : X) -> LazyList[X] {
  Cons(start, LazyRef::from_thunk(() => infinite_stream(start + step, step)))
}

///|
/// Zip a `LazyList` with an eager `@list.List`, producing an eager
/// `@list.List`. Stops when either runs out. Used internally by
/// `feat`'s convolution: the enumeration's parts live in a
/// `LazyList`, the finite sides live in eager lists.
pub fn[A, B, C] zip_lazy_normal(
  f : (A, B) -> C,
  xs : LazyList[A],
  ys : @list.List[B],
) -> @list.List[C] {
  match (xs, ys) {
    (Cons(x, xs), More(y, tail=ys)) =>
      zip_lazy_normal(f, xs.force(), ys).add(f(x, y))
    (_, _) => @list.empty()
  }
}

///|
/// Element-wise combine that **keeps the longer tail** instead of
/// truncating at the shorter input. Exactly the shape needed to fuse
/// the size-indexed parts of two `Enumerate`s in `feat` — if one
/// enumeration runs out of parts, the other's remaining parts pass
/// through unchanged.
///
/// ```mbt check
/// test {
///   let xs : LazyList[Int] = from_list(@list.from_array([1, 2]))
///   let ys : LazyList[Int] = from_list(@list.from_array([10, 20, 30, 40]))
///   @debug.assert_eq(zip_plus((a, b) => a + b, xs, ys).iter().collect(), [
///     11, 22, 30, 40,
///   ])
/// }
/// ```
pub fn[T] zip_plus(
  f : (T, T) -> T,
  ls1 : LazyList[T],
  ls2 : LazyList[T],
) -> LazyList[T] {
  match (ls1, ls2) {
    (Cons(x, xs), Cons(y, ys)) =>
      Cons(
        f(x, y),
        LazyRef::from_thunk(() => zip_plus(f, xs.force(), ys.force())),
      )
    (xs, ys) => xs.concat(ys)
  }
}

///|
/// Co-inductive dual of `fold_left`: given a step `f : LazyList -> (T, LazyList)?`,
/// produce a lazy list by repeatedly applying `f` to the previous
/// state. `f` returns `None` to terminate, otherwise `Some((elem, next_state))`.
pub fn[T] LazyList::unfold(
  self : LazyList[T],
  f : (LazyList[T]) -> (T, LazyList[T])?,
) -> LazyList[T] {
  match f(self) {
    None => Nil
    Some((x, y)) => Cons(x, LazyRef::from_thunk(() => y.unfold(f)))
  }
}

///|
/// Promote an eager `@list.List[T]` to a `LazyList[T]` whose tails are
/// already computed. Same semantics as `to_lazy`, provided as a
/// top-level function for symmetry.
pub fn[T] from_list(ls : @list.List[T]) -> LazyList[T] {
  match ls {
    Empty => Nil
    More(x, tail=xs) => Cons(x, LazyRef::from_value(from_list(xs)))
  }
}
