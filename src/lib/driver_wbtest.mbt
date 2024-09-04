fn add_comm_double(xy : (Double, Double)) -> Bool {
  let (x, y) = xy
  x + y == y + x
}

fn add_assoc_double(xyz : (Double, Double, Double)) -> Bool {
  let (x, y, z) = xyz
  x + y + z == x + (y + z) // Actually does not hold for Double
}

test "prop reverse wrong" {
  let prop_rev = fn(l : List[Int]) { l.rev().rev() == l.rev() }
  quick_check_fn!(prop_rev)
}

test "prop reverse" {
  let prop_rev = fn(l : List[Int]) { l.rev().rev() == l }
  quick_check_fn!(prop_rev)
}

test "add comm double" {
  quick_check_fn!(add_comm_double)
}

test "add assoc double (fail)" {
  quick_check!(Arrow(add_assoc_double) |> expect_fail)
}

/// Natural Numbers
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

impl Arbitrary for Nat with arbitrary(i, rs) { Gen::feat_random(i).run(i, rs) }

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

test "add comm nat" {
  quick_check_fn!(add_comm_nat)
}
