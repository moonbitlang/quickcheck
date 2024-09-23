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
    Arrow(
      fn(x : List[Int]) {
        Arrow(prop_rev)
        |> label(if x.is_empty() { "trivial" } else { "non-trivial" })
      },
    ),
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

impl @quickcheck.Arbitrary for Nat with arbitrary(i, rs) {
  Gen::feat_random(i).run(i, rs)
}

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

fn reverse[T](lst : Array[T]) -> Array[T] {
  lst.rev()
}

test "reverse" {
  inspect!(reverse(([] : Array[Int])), content="[]")
  inspect!(reverse([1, 2, 3]), content="[3, 2, 1]")
}

test "prop_reverse_identity" {
  fn prop_reverse_identity(arr : Array[Int]) {
    reverse(reverse(arr)) == arr
  }

  quick_check!(Arrow(prop_reverse_identity))
}

fn remove(arr : Array[Int], x : Int) -> Array[Int] {
  match arr.search(x) {
    Some(i) => arr.remove(i) |> ignore
    None => ()
  }
  arr
}

fn prop_remove_not_presence(iarr : (Int, Array[Int])) -> Bool {
  let (x, arr) = iarr
  remove(arr, x).contains(x).not()
}

fn prop_length_is_not_greater(iarr : (Int, Array[Int])) -> Bool {
  let (x, arr) = iarr
  let len = arr.length()
  remove(arr, x).length() <= len
}

test {
  quick_check!(Arrow(prop_length_is_not_greater))
}

test {
  quick_check!(Arrow(prop_remove_not_presence) |> with_max_success(1000))
}

test "custom generator" {
  quick_check!(
    forall(
      spawn(),
      fn(iarr : (Int, Array[Int])) {
        let (x, arr) = iarr
        remove(arr, x).contains(x).not()
      },
    ),
  )
}

test "no_duplicate" {
  fn no_duplicate(x : Array[Int]) -> Bool {
    @sorted_set.from_iter(x.iter()).size() == x.length().to_int64()
  }

  quick_check!(
    forall(
      spawn(),
      fn(iarr : (Int, Array[Int])) {
        let (x, arr) = iarr
        remove(arr.copy(), x).contains(x).not() |> filter(no_duplicate(arr))
      },
    ),
  )
}

test "use one_of" {
  quick_check!(
    forall(
      spawn(),
      fn(a : Array[Int]) {
        forall(one_of_array(a), fn(y : Int) { remove(a, y).contains(y).not() })
        |> filter(a.length() != 0)
      },
    ),
  )
}

test "explicit universal qualification" {
  quick_check!(forall(spawn(), fn(x : List[Int]) { x.rev().rev() == x }))
}
