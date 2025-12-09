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
pub fn[T : Show] ShrinkTree::draw(
  self : ShrinkTree[T],
  depth : Int,
) -> @list.List[String] {
  if depth == 0 {
    return @list.singleton("limit reach")
  }
  fn shift(first : String, other : String, x : @list.List[String]) {
    @lazy.zip_lazy_normal(
      String::add,
      @lazy.Cons(first, @lazy.LazyRef::from_value(@lazy.repeat(other))),
      x,
    )
  }

  fn draw_sub(l : @list.List[ShrinkTree[T]]) {
    match l {
      Empty => @list.empty()
      More(t, tail=Empty) =>
        shift("└─ ", "   ", t.draw(depth - 1)).add("│")
      More(t, tail=ts) =>
        @list.List::concat(
          shift("├─ ", "   ", t.draw(depth - 1)).add("│"),
          draw_sub(ts),
        )
    }
  }

  draw_sub(@list.from_iter(self.branch)).add(self.leaf.to_string())
}

///|
pub fn[T : Show] ShrinkTree::to_string_with_depth(
  self : ShrinkTree[T],
  depth : Int,
) -> String {
  if depth == 0 {
    return ""
  }
  let s = self.leaf.to_string()
  let child = self.branch
    .map(fn(x) { x.to_string_with_depth(depth - 1) })
    .filter(fn(x) { x != "" })
    .collect()
    .join(", ")
  "Node(\{s}, [\{child}])"
}

///|
pub fn[T] ShrinkTree::from_value(x : T) -> ShrinkTree[T] {
  { leaf: x, branch: Iter::empty() }
}

///|
pub fn[T] ShrinkTree::from_shinker(
  shrink : (T) -> Iter[T],
  x : T,
) -> ShrinkTree[T] {
  fn build(x) {
    { leaf: x, branch: shrink(x).map(build) }
  }

  build(x)
}

///|
pub fn[T, U] ShrinkTree::smap(
  self : ShrinkTree[T],
  f : (T) -> U,
) -> ShrinkTree[U] {
  { leaf: self.leaf |> f, branch: self.branch.map(fn(x) { x.smap(f) }) }
}

///|
pub fn[T] ShrinkTree::join(self : ShrinkTree[ShrinkTree[T]]) -> ShrinkTree[T] {
  let x = self.leaf.leaf
  let ts = self.branch
    .map(_.join())
    .concat(
      match self.leaf {
        { branch: ts, .. } => ts
      },
    )
  { leaf: x, branch: ts }
}

///|
pub fn[T, U] ShrinkTree::bind(
  self : ShrinkTree[T],
  f : (T) -> ShrinkTree[U],
) -> ShrinkTree[U] {
  self.smap(f).join()
}

///|
pub fn[T] ShrinkTree::get_value(
  self : ShrinkTree[T],
) -> (T, Iter[ShrinkTree[T]]) {
  let { leaf, branch } = self
  (leaf, branch)
}
