typealias List[T] = @immut/list.T[T]

/// Number Laws ///

fn add_comm_double(xy : (Double, Double)) -> Bool {
  let (x, y) = xy
  x + y == y + x
}

fn add_assoc_double(xyz : (Double, Double, Double)) -> Bool {
  let (x, y, z) = xyz
  x + y + z == x + (y + z) // Actually does not hold for Double
}

test {
  inspect!(quick_check(add_comm_double).outcome, content="OK")
  inspect!(quick_check(add_assoc_double).outcome, content="FAIL")
}

/// Custom Data Types (especially recursive) using Functional Enumeration
/// We have basic instances for builtin types like bool / list / int

/// Natural Numbers ///
enum Nat {
  Zero
  Succ(Nat)
} derive(Show)

impl @feat.Enumerable for Nat with enumerate() {
  @feat.pay(
    fn() {
      @feat.singleton(Zero) + @feat.Enumerable::enumerate().fmap(Nat::Succ)
    },
  )
}

impl Arbitrary for Nat with arbitrary(i, rs) { Gen::feat(i).run(i, rs) }

fn op_add(self : Nat, other : Nat) -> Nat {
  match self {
    Zero => other
    Succ(n) => Succ(n.op_add(other))
  }
}

fn op_equal(self : Nat, other : Nat) -> Bool {
  match (self, other) {
    (Zero, Zero) => true
    (Succ(a), Succ(b)) => a == b
    _ => false
  }
}

fn add_comm_nat(ab : (Nat, Nat)) -> Bool {
  let (a, b) = ab
  a + b == b + a
}

test "Natural Number" {
  inspect!(
    check_one(Default::default(), with_law(add_comm_nat)).outcome,
    content="OK",
  )
  inspect!(
    check_one(Default::default(), with_law(add_comm_nat)).outcome,
    content="OK",
  )
}

/// Tree ///

enum Tree[T] {
  Leaf(T)
  Branch(Forest[T])
} derive(Show)

struct Forest[T] {
  forest : @immut/list.T[Tree[T]]
} derive(Show)

impl[E : @feat.Enumerable] @feat.Enumerable for Forest[E] with enumerate() {
  @feat.pay(
    fn() { @feat.Enumerable::enumerate().fmap(fn { forest => { forest, } }) },
  )
}

impl[E : @feat.Enumerable] @feat.Enumerable for Tree[E] with enumerate() {
  @feat.pay(
    fn() {
      E::enumerate().fmap(Tree::Leaf) +
      @feat.Enumerable::enumerate().fmap(Tree::Branch)
    },
  )
}

test "Tree" {
  let tg : Gen[Tree[Nat]] = Gen::feat(10)
  inspect!(
    tg.samples(),
    content="[Branch({forest: @list.of([Leaf(Zero)])}), Branch({forest: @list.of([Branch({forest: @list.of([])})])}), Leaf(Succ(Zero)), Leaf(Succ(Succ(Zero))), Leaf(Succ(Succ(Succ(Succ(Zero))))), Leaf(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))), Branch({forest: @list.of([Leaf(Zero), Leaf(Zero)])}), Branch({forest: @list.of([Branch({forest: @list.of([])})])}), Leaf(Succ(Succ(Succ(Succ(Zero))))), Leaf(Succ(Succ(Succ(Succ(Succ(Zero))))))]",
  )
}

/// Custom Generators ///

test "int ranged" {
  /// With default generator
  inspect!(
    check_one(
      Default::default(),
      with_law(
        fn(xy : (Int, Int)) {
          let (x, y) = xy
          x + y == 100
        },
      ),
    ).outcome,
    content="FAIL",
  )
  /// With custom generator
  inspect!(
    check_one(
      Default::default(),
      with_law(
        fn(xy : (Int, Int)) {
          let (x, y) = xy
          x + y == 100
        },
      ).with_generator(tuple(int_bound(10), int_bound(10))),
    ).outcome,
    content="FAIL",
  )
}
