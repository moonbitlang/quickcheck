///|
typealias @list.List

///|
typealias @qc.Arrow

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
  @qc.quick_check(prop_rev |> @qc.Arrow, expect=Fail)
}

///|
test "prop reverse" {
  @qc.quick_check_fn(prop_rev)
}

///|
test "add comm double" {
  @qc.quick_check_fn(add_comm_double)
}

///|
test "modify max tests" {
  // Use the quick_check function directly without the @ annotation
  // This addresses the warning about traits with only default implementation
  @qc.quick_check(@qc.Arrow(prop_rev), max_success=1000)
}

///|
test "large max tests" {
  @qc.quick_check((), max_success=2000)
}

///|
test "larger max tests" {
  @qc.quick_check((), max_success=10000)
}

///|
test "add assoc double (expect fail)" {
  @qc.quick_check(@qc.Arrow(add_assoc_double), expect=Fail)
}

///|
test "non empty list (with filter)" {
  let prop_is_non_empty = fn(l : List[Int]) -> @qc.Property {
    not(l.is_empty()) |> @qc.filter(not(l.is_empty()))
  }
  @qc.quick_check(@qc.Arrow(prop_is_non_empty))
}

///|
test "reject all" {
  let prop_reject = fn(_x : Int) { @qc.filter(true, false) }
  @qc.quick_check(@qc.Arrow(prop_reject), expect=GaveUp)
}

///|
test "label" {
  let ar : @qc.Arrow[List[Int], Bool] = @qc.Arrow(prop_rev)
  @qc.quick_check(
    @qc.Arrow(fn(x : List[Int]) {
      @qc.label(ar, if x.is_empty() { "trivial" } else { "non-trivial" })
    }),
  )
}

///|
test "classes" {
  @qc.quick_check_fn(fn(x : List[Int]) {
    @qc.Arrow(prop_rev)
    |> @qc.classify(x.length() > 5, "long list")
    |> @qc.classify(x.length() <= 5, "short list")
  })
}

///|
test "label + classes" {
  @qc.quick_check_fn(fn(x : List[String]) {
    @qc.Arrow(prop_rev)
    |> @qc.classify(x.length() > 5, "long list")
    |> @qc.classify(x.length() <= 5, "short list")
    |> @qc.label("length is \{x.length()}")
  })
}

///|
test "abort" {
  @qc.quick_check(@qc.Arrow(prop_rev), abort=true)
}

///|
/// Natural Numbers
priv enum Nat {
  Zero
  Succ(Nat)
} derive(Show)

///|
impl @feat.Enumerable for Nat with enumerate() {
  @feat.pay(fn() {
    @feat.singleton(Zero) + @feat.Enumerable::enumerate().fmap(Nat::Succ(_))
  })
}

///|
impl @quickcheck.Arbitrary for Nat with arbitrary(i, rs) {
  @qc.Gen::feat_random(i).run(i, rs)
}

///|
impl Add for Nat with add(self, other) {
  match self {
    Zero => other
    Succ(n) => Succ(n.add(other))
  }
}

///|
impl Eq for Nat with equal(self, other) {
  match (self, other) {
    (Zero, Zero) => true
    (Succ(a), Succ(b)) => a == b
    _ => false
  }
}

///|
impl @qc.Shrink for Nat

///|
fn add_comm_nat(ab : (Nat, Nat)) -> Bool {
  let (a, b) = ab
  a + b == b + a
}

///|
test "add comm nat" {
  @qc.quick_check_fn(add_comm_nat)
}

///|
fn[T] reverse(lst : Array[T]) -> Array[T] {
  lst.rev()
}

///|
test "reverse" {
  inspect(reverse(([] : Array[Int])), content="[]")
  inspect(reverse([1, 2, 3]), content="[3, 2, 1]")
}

///|
test "prop_reverse_identity" {
  fn prop_reverse_identity(arr : Array[Int]) {
    reverse(reverse(arr)) == arr
  }

  @qc.quick_check(@qc.Arrow(prop_reverse_identity))
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
  @qc.quick_check(@qc.Arrow(prop_length_is_not_greater))
}

///|
test "prop remove not presence with max success" {
  @qc.quick_check(
    @qc.Arrow(prop_remove_not_presence),
    max_success=1000,
    expect=Fail,
  )
}

///|
test "custom generator" {
  @qc.quick_check(
    @qc.forall(@qc.Gen::spawn(), fn(i_arr : (Int, Array[Int])) {
      let (x, arr) = i_arr
      not(remove(arr, x).contains(x))
    }),
    expect=Fail,
  )
}

///|
test "no_duplicate" {
  fn no_duplicate(x : Array[Int]) -> Bool {
    @sorted_set.from_iter(x.iter()).size() == x.length()
  }

  @qc.quick_check(
    @qc.forall(@qc.Gen::spawn(), fn(iarr : (Int, Array[Int])) {
      let (x, arr) = iarr
      not(remove(arr.copy(), x).contains(x)) |> @qc.filter(no_duplicate(arr))
    }),
    expect=GaveUp,
  )
}

///|
test "use one_of" {
  @qc.quick_check(
    @qc.forall(@qc.Gen::spawn(), fn(a : Array[Int]) {
      @qc.forall(@qc.one_of_array(a), fn(y : Int) {
        not(remove(a, y).contains(y))
      })
      |> @qc.filter(a.length() != 0)
    }),
    expect=Fail,
  )
}

///|
test "explicit universal qualification" {
  @qc.quick_check(
    @qc.forall(@qc.Gen::spawn(), fn(x : List[Int]) { x.rev().rev() == x }),
  )
}
