///|
priv enum RecursiveProductTree {
  Leaf
  Node(RecursiveProductTree, RecursiveProductTree)
}

///|
fn recursive_product_node(
  pair : (RecursiveProductTree, RecursiveProductTree),
) -> RecursiveProductTree {
  Node(pair.0, pair.1)
}

///|
impl Enumerable for RecursiveProductTree with fn enumerate() {
  @feat.pay(() => {
    @feat.singleton(Leaf) +
    @feat.product(@feat.Enumerable::enumerate(), @feat.Enumerable::enumerate()).fmap(
      recursive_product_node,
    )
  })
}

///|
test "minimal recursive product repro" {
  let trees : @feat.Enumerate[RecursiveProductTree] = @feat.Enumerable::enumerate()
  assert_eq(@ifseq.length(@feat.part(trees, 1)), 1)
  match trees[0] {
    Leaf => ()
    _ => abort("expected Leaf")
  }
  match trees[1] {
    Node(Leaf, Leaf) => ()
    _ => abort("expected Node(Leaf, Leaf)")
  }
}
