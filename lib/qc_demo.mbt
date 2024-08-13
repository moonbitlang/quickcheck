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
  quick_check(add_comm_double).print()
  quick_check(add_assoc_double).print()
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
      @feat.union(
        @feat.singleton(Zero),
        @feat.fmap(Nat::Succ, @feat.Enumerable::enumerate()),
      )
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
    (Succ(a), Succ(b)) => op_equal(a, b)
    _ => false
  }
}

fn add_comm_nat(ab : (Nat, Nat)) -> Bool {
  let (a, b) = ab
  a + b == b + a
}

test "Natural Number" {
  check_verbose(Default::default(), with_law(add_comm_nat)).print()
  check_one(Default::default(), with_law(add_comm_nat)).print()
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
    fn() {
      @feat.fmap(fn { forest => { forest, } }, @feat.Enumerable::enumerate())
    },
  )
}

impl[E : @feat.Enumerable] @feat.Enumerable for Tree[E] with enumerate() {
  @feat.pay(
    fn() {
      @feat.union(
        @feat.fmap(Tree::Leaf, E::enumerate()),
        @feat.fmap(Tree::Branch, @feat.Enumerable::enumerate()),
      )
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
  check_verbose(
    Default::default(),
    with_law(
      fn(xy : (Int, Int)) {
        let (x, y) = xy
        x + y == 100
      },
    ),
  ).print()
  /// With custom generator
  check_verbose(
    Default::default(),
    with_law(
      fn(xy : (Int, Int)) {
        let (x, y) = xy
        x + y == 100
      },
    ).with_generator(tuple(int_bound(10), int_bound(10))),
  ).print()
}



test "json generator" {
  let gj : Gen[Json] = spawn()
  println(gj.samples(size=10))
  quick_check(
    fn(jv : Json) {
      match @result.wrap1(f=@json.parse, @json.stringify(jv)) {
        Err(_) => false
        Ok(jv2) => jv == jv2
      }
    },
  ).print()
}
