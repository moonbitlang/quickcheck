fn add_comm_double(xy : (Double, Double)) -> Bool {
  let (x, y) = xy
  x + y == y + x
}

fn add_assoc_double(xyz : (Double, Double, Double)) -> Bool {
  let (x, y, z) = xyz
  x + y + z == x + (y + z) // Actually does not hold for Double
}

fn prop_rev(l : List[Int]) -> Bool {
  l.rev().rev() == l
}

test "prop reverse (fail)" {
  let prop_rev = fn(l : List[Int]) { l.rev().rev() == l.rev() }
  quick_check_fn!(prop_rev)
}

test "prop reverse" {
  quick_check_fn!(prop_rev)
}

test "add comm double" {
  quick_check_fn!(add_comm_double)
}

test "modify max tests" {
  quick_check!(Arrow(prop_rev) |> with_max_success(1000))
}

test "add assoc double (expect fail)" {
  quick_check!(Arrow(add_assoc_double) |> expect_fail)
}

test "non empty list (with filter)" {
  let prop_is_non_empty = fn(l : List[Int]) {
    l.is_empty().not() |> filter(l.is_empty().not())
  }
  quick_check!(Arrow(prop_is_non_empty))
}

test "reject all" {
  let prop_reject = fn(_x : Int) { filter(true, false) }
  quick_check!(Arrow(prop_reject))
}

test "label" {
  quick_check!(
    fn(x : List[Int]) { Arrow(prop_rev) |> label("length is \{x.length()}") }
    |> Arrow,
  )
}

test "classes" {
  quick_check_fn!(
    fn(x : List[Int]) {
      Arrow(prop_rev)
      |> classify(x.length() > 5, "long list")
      |> classify(x.length() <= 5, "short list")
    },
  )
}

test "label + classes" {
  quick_check_fn!(
    fn(x : List[String]) {
      Arrow(prop_rev)
      |> classify(x.length() > 5, "long list")
      |> classify(x.length() <= 5, "short list")
      |> label("length is \{x.length()}")
    },
  )
}

test "abort" {
  quick_check!(Arrow(prop_rev) |> terminate)
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
