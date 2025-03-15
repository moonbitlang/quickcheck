///|
struct ShrinkTree[T] {
  leaf : T
  branch : Iter[ShrinkTree[T]]
}

///|
pub impl[T : Show] Show for ShrinkTree[T] with output(self, logger) {
  logger.write_iter(self.draw(100).iter(), sep="\n")
}

///|
pub fn draw[T : Show](
  self : ShrinkTree[T],
  depth : Int
) -> @immut/list.T[String] {
  if depth == 0 {
    return Cons("limit reach", Nil)
  }
  fn shift(first : String, other : String, x : @immut/list.T[String]) {
    @lazy.zip_lazy_normal(
      String::op_add,
      @lazy.Cons(first, @lazy.LazyRef::from_value(@lazy.repeat(other))),
      x,
    )
  }

  fn draw_sub(l) {
    match l {
      @immut/list.Nil => @immut/list.Nil
      Cons(t, Nil) => Cons("│", shift("└─ ", "   ", draw(t, depth - 1)))
      Cons(t, ts) =>
        @immut/list.concat(
          Cons("│", shift("├─ ", "│  ", draw(t, depth - 1))),
          draw_sub(ts),
        )
    }
  }

  Cons(self.leaf.to_string(), draw_sub(@immut/list.from_iter(self.branch)))
}

///|
fn to_string_with_depth[T : Show](self : ShrinkTree[T], depth : Int) -> String {
  if depth == 0 {
    return ""
  }
  let s = self.leaf.to_string()
  let child = self.branch
    .map(fn(x) { x.to_string_with_depth(depth - 1) })
    .filter(fn(x) { x != "" })
    .collect()
    |> String::concat(separator=", ")
  "Node(\{s}, [\{child}])"
}

///|
pub fn ShrinkTree::from_value[T](x : T) -> ShrinkTree[T] {
  { leaf: x, branch: Iter::empty() }
}

///|
pub fn ShrinkTree::from_shinker[T](
  shrink : (T) -> Iter[T],
  x : T
) -> ShrinkTree[T] {
  fn build(x) {
    { leaf: x, branch: shrink(x).map(build) }
  }

  build(x)
}

///|
pub fn smap[T, U](self : ShrinkTree[T], f : (T) -> U) -> ShrinkTree[U] {
  { leaf: self.leaf |> f, branch: self.branch.map(fn(x) { smap(x, f) }) }
}

///|
pub fn join[T](tr : ShrinkTree[ShrinkTree[T]]) -> ShrinkTree[T] {
  let x = tr.leaf.leaf
  let ts = tr.branch
    .map(join)
    .concat(
      match tr.leaf {
        { branch: ts, .. } => ts
      },
    )
  { leaf: x, branch: ts }
}

///|
pub fn bind[T, U](
  self : ShrinkTree[T],
  f : (T) -> ShrinkTree[U]
) -> ShrinkTree[U] {
  self.smap(f) |> join
}

///|
pub fn get_value[T](self : ShrinkTree[T]) -> (T, Iter[ShrinkTree[T]]) {
  let { leaf, branch } = self
  (leaf, branch)
}
