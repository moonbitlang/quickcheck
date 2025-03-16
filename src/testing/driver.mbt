///|
typealias List[T] = @immut/list.T[T]

///|
typealias Arrow[A, B] = @qc.Arrow[A, B]

///|
fn add_comm_double(xy : (Double, Double)) -> Bool {
  let (x, y) = xy
  x + y == y + x
}

///|
fn add_assoc_double(xyz : (Double, Double, Double)) -> Bool {
  let (x, y, z) = xyz
  x + y + z == x + (y + z) // Actually does not hold for Double
}

///|
fn prop_rev(l : List[Int]) -> Bool {
  l.rev().rev() == l
}

///|
test "prop reverse (fail)" {
  let prop_rev = fn(l : List[Int]) { l.rev().rev() == l.rev() }
  @qc.quick_check!(prop_rev |> @qc.Arrow |> @qc.expect_fail)
}

///|
test "prop reverse" {
  @qc.quick_check_fn!(prop_rev)
}

///|
test "add comm double" {
  @qc.quick_check_fn!(add_comm_double)
}

///|
test "modify max tests" {
  @qc.quick_check!(@qc.Arrow(prop_rev) |> @qc.with_max_success(2000))
}

///|
test "large max tests" {
  @qc.quick_check!(() |> @qc.with_max_success(10000))
}

///|
test "larger max tests" {
  @qc.quick_check!(() |> @qc.with_max_success(100000))
}

///|
test "add assoc double (expect fail)" {
  @qc.quick_check!(@qc.Arrow(add_assoc_double) |> @qc.expect_fail)
}

///|
test "non empty list (with filter)" {
  let prop_is_non_empty = fn(l : List[Int]) {
    not(l.is_empty()) |> @qc.filter(not(l.is_empty()))
  }
  @qc.quick_check!(@qc.Arrow(prop_is_non_empty))
}

///|
test "reject all" {
  let prop_reject = fn(_x : Int) { @qc.filter(true, false) }
  @qc.quick_check!(@qc.Arrow(prop_reject) |> @qc.expect_gave_up)
}

///|
test "label" {
  @qc.quick_check!(
    @qc.Arrow(fn(x : List[Int]) {
      @qc.Arrow(prop_rev)
      |> @qc.label(if x.is_empty() { "trivial" } else { "non-trivial" })
    }),
  )
}

///|
test "classes" {
  @qc.quick_check_fn!(fn(x : List[Int]) {
    @qc.Arrow(prop_rev)
    |> @qc.classify(x.length() > 5, "long list")
    |> @qc.classify(x.length() <= 5, "short list")
  })
}

///|
test "label + classes" {
  @qc.quick_check_fn!(fn(x : List[String]) {
    @qc.Arrow(prop_rev)
    |> @qc.classify(x.length() > 5, "long list")
    |> @qc.classify(x.length() <= 5, "short list")
    |> @qc.label("length is \{x.length()}")
  })
}

///|
test "abort" {
  @qc.quick_check!(@qc.Arrow(prop_rev) |> @qc.terminate)
}

///| Natural Numbers
enum Nat {
  Zero
  Succ(Nat)
} derive(Show)

///|
impl @feat.Enumerable for Nat with enumerate() {
  @feat.pay(fn() {
    @feat.singleton(Zero) + @feat.Enumerable::enumerate().fmap(Nat::Succ)
  })
}

///|
impl @quickcheck.Arbitrary for Nat with arbitrary(i, rs) {
  @qc.Gen::feat_random(i).run(i, rs)
}

///|
fn op_add(self : Nat, other : Nat) -> Nat {
  match self {
    Zero => other
    Succ(n) => Succ(n.op_add(other))
  }
}

///|
fn Nat::op_equal(self : Nat, other : Nat) -> Bool {
  match (self, other) {
    (Zero, Zero) => true
    (Succ(a), Succ(b)) => a == b
    _ => false
  }
}

///|
fn add_comm_nat(ab : (Nat, Nat)) -> Bool {
  let (a, b) = ab
  a + b == b + a
}

///|
test "add comm nat" {
  @qc.quick_check_fn!(add_comm_nat)
}

///|
fn reverse[T](lst : Array[T]) -> Array[T] {
  lst.rev()
}

///|
test "reverse" {
  inspect!(reverse(([] : Array[Int])), content="[]")
  inspect!(reverse([1, 2, 3]), content="[3, 2, 1]")
}

///|
test "prop_reverse_identity" {
  fn prop_reverse_identity(arr : Array[Int]) {
    reverse(reverse(arr)) == arr
  }

  @qc.quick_check!(@qc.Arrow(prop_reverse_identity))
}

///|
fn remove(arr : Array[Int], x : Int) -> Array[Int] {
  match arr.search(x) {
    Some(i) => arr.remove(i) |> ignore
    None => ()
  }
  arr
}

///|
fn prop_remove_not_presence(iarr : (Int, Array[Int])) -> Bool {
  let (x, arr) = iarr
  not(remove(arr, x).contains(x))
}

///|
fn prop_length_is_not_greater(iarr : (Int, Array[Int])) -> Bool {
  let (x, arr) = iarr
  let len = arr.length()
  remove(arr, x).length() <= len
}

///|
test "prop length is not greater" {
  @qc.quick_check!(@qc.Arrow(prop_length_is_not_greater))
}

///|
test "prop remove not presence with max success" {
  @qc.quick_check!(
    @qc.Arrow(prop_remove_not_presence)
    |> @qc.with_max_success(1000)
    |> @qc.expect_fail,
  )
}

///|
test "custom generator" {
  @qc.quick_check!(
    @qc.forall(@qc.Gen::spawn(), fn(i_arr : (Int, Array[Int])) {
      let (x, arr) = i_arr
      not(remove(arr, x).contains(x))
    })
    |> @qc.expect_fail,
  )
}

///|
test "no_duplicate" {
  fn no_duplicate(x : Array[Int]) -> Bool {
    @sorted_set.from_iter(x.iter()).size() == x.length()
  }

  @qc.quick_check!(
    @qc.forall(@qc.Gen::spawn(), fn(iarr : (Int, Array[Int])) {
      let (x, arr) = iarr
      not(remove(arr.copy(), x).contains(x)) |> @qc.filter(no_duplicate(arr))
    })
    |> @qc.expect_gave_up,
  )
}

///|
test "use one_of" {
  @qc.quick_check!(
    @qc.forall(@qc.Gen::spawn(), fn(a : Array[Int]) {
      @qc.forall(@qc.one_of_array(a), fn(y : Int) {
        not(remove(a, y).contains(y))
      })
      |> @qc.filter(a.length() != 0)
    })
    |> @qc.expect_fail,
  )
}

///|
test "explicit universal qualification" {
  @qc.quick_check!(
    @qc.forall(@qc.Gen::spawn(), fn(x : List[Int]) { x.rev().rev() == x }),
  )
}
