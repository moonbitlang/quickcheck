///|
using @list {type List}

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
  inspect(
    @qc.quick_check_silence(prop_rev |> @qc.Arrow, expect=Fail),
    content="+++ [9/0/100] Ok! Failed as expected.",
  )
}

///|
test "prop reverse" {
  inspect(
    @qc.quick_check_silence(prop_rev |> @qc.Arrow),
    content="+++ [100/0/100] Ok, passed!",
  )
}

///|
test "add comm double" {
  inspect(
    @qc.quick_check_silence(add_comm_double |> @qc.Arrow),
    content="+++ [100/0/100] Ok, passed!",
  )
}

///|
test "modify max tests" {
  inspect(
    @qc.quick_check_silence(@qc.Arrow(prop_rev), max_success=1000),
    content="+++ [1000/0/1000] Ok, passed!",
  )
}

///|
test "large max tests" {
  inspect(
    @qc.quick_check_silence((), max_success=2000),
    content="+++ [2000/0/2000] Ok, passed!",
  )
}

///|
test "larger max tests" {
  inspect(
    @qc.quick_check_silence((), max_success=10000),
    content="+++ [10000/0/10000] Ok, passed!",
  )
}

///|
test "add assoc double (expect fail)" {
  inspect(
    @qc.quick_check_silence(add_assoc_double |> @qc.Arrow, expect=Fail),
    content="+++ [10/0/100] Ok! Failed as expected.",
  )
}

///|
test "small check pass" {
  let prop = fn(x : Int) { x + 0 == x }
  inspect(
    @qc.small_check_silence(prop, max_size=1000000),
    content="+++ [1000000/0/1000000] Ok, passed!",
  )
}

///|
test "small check expect fail" {
  let prop = fn(x : Int) { x == 0 }
  inspect(
    @qc.small_check_silence(prop, max_size=5, expect=Fail),
    content="+++ [1/0/5] Ok! Failed as expected.",
  )
}

///|
test "non empty list (with filter)" {
  let prop_is_non_empty = fn(l : List[Int]) -> @qc.Property {
    not(l.is_empty()) |> @qc.filter(not(l.is_empty()))
  }
  inspect(
    @qc.quick_check_silence(@qc.Arrow(prop_is_non_empty)),
    content="+++ [100/40/100] Ok, passed!",
  )
}

///|
test "reject all" {
  let prop_reject = fn(_x : Int) { @qc.filter(true, false) }
  inspect(
    @qc.quick_check_silence(@qc.Arrow(prop_reject), expect=GaveUp),
    content="+++ [0/1000/100] Ok, gave up!",
  )
}

///|
test "label" {
  let ar : @qc.Arrow[List[Int], Bool] = @qc.Arrow(prop_rev)
  inspect(
    @qc.quick_check_silence(
      @qc.Arrow(fn(x : List[Int]) {
        @qc.label(ar, if x.is_empty() { "trivial" } else { "non-trivial" })
      }),
    ),
    content=(
      #|+++ [100/0/100] Ok, passed!
      #|8% : trivial
      #|92% : non-trivial
    ),
  )
}

///|
test "classes" {
  inspect(
    @qc.quick_check_silence(
      @qc.Arrow(fn(x : List[Int]) {
        @qc.Arrow(prop_rev)
        |> @qc.classify(x.length() > 5, "long list")
        |> @qc.classify(x.length() <= 5, "short list")
      }),
    ),
    content=(
      #|+++ [100/0/100] Ok, passed!
      #|21% : short list
      #|79% : long list
    ),
  )
}

///|
test "label + classes" {
  inspect(
    @qc.quick_check_silence(
      @qc.Arrow(fn(x : List[String]) {
        @qc.Arrow(prop_rev)
        |> @qc.classify(x.length() > 5, "long list")
        |> @qc.classify(x.length() <= 5, "short list")
        |> @qc.label("length is \{x.length()}")
      }),
    ),
    content=(
      #|+++ [100/0/100] Ok, passed!
      #|8% : length is 0
      #|4% : length is 1
      #|2% : length is 2
      #|3% : length is 3
      #|1% : length is 4
      #|3% : length is 5
      #|2% : length is 6
      #|2% : length is 7
      #|7.000000000000001% : length is 8
      #|1% : length is 9
      #|1% : length is 10
      #|1% : length is 11
      #|1% : length is 12
      #|1% : length is 13
      #|5% : length is 14
      #|1% : length is 15
      #|2% : length is 16
      #|1% : length is 17
      #|1% : length is 18
      #|2% : length is 20
      #|2% : length is 21
      #|1% : length is 23
      #|2% : length is 24
      #|4% : length is 25
      #|2% : length is 26
      #|1% : length is 27
      #|1% : length is 28
      #|4% : length is 29
      #|1% : length is 30
      #|2% : length is 31
      #|2% : length is 32
      #|3% : length is 33
      #|1% : length is 34
      #|2% : length is 35
      #|2% : length is 36
      #|1% : length is 40
      #|2% : length is 41
      #|1% : length is 42
      #|1% : length is 43
      #|1% : length is 44
      #|1% : length is 47
      #|1% : length is 48
      #|1% : length is 49
      #|2% : length is 52
      #|1% : length is 53
      #|1% : length is 56
      #|1% : length is 62
      #|1% : length is 64
      #|1% : length is 67
      #|1% : length is 71
      #|1% : length is 85
      #|1% : length is 89
      #|1% : length is 93
      #|1% : length is 97
      #|21% : short list
      #|79% : long list
    ),
  )
}

///|
test "abort" {
  inspect(
    @qc.quick_check_silence(@qc.Arrow(prop_rev), abort=true),
    content="+++ [1/0/100] Ok, passed!",
  )
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
impl @coreqc.Arbitrary for Nat with arbitrary(i, rs) {
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
  inspect(
    @qc.quick_check_silence(add_comm_nat |> @qc.Arrow),
    content="+++ [100/0/100] Ok, passed!",
  )
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

  inspect(
    @qc.quick_check_silence(@qc.Arrow(prop_reverse_identity)),
    content="+++ [100/0/100] Ok, passed!",
  )
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
  inspect(
    @qc.quick_check_silence(@qc.Arrow(prop_length_is_not_greater)),
    content="+++ [100/0/100] Ok, passed!",
  )
}

///|
test "prop remove not presence with max success" {
  inspect(
    @qc.quick_check_silence(
      @qc.Arrow(prop_remove_not_presence),
      max_success=1000,
      expect=Fail,
    ),
    content="+++ [8/0/1000] Ok! Failed as expected.",
  )
}

///|
test "custom generator" {
  inspect(
    @qc.quick_check_silence(
      @qc.forall(@qc.Gen::spawn(), fn(i_arr : (Int, Array[Int])) {
        let (x, arr) = i_arr
        not(remove(arr, x).contains(x))
      }),
      expect=Fail,
    ),
    content="+++ [8/0/100] Ok! Failed as expected.",
  )
}

///|
test "no_duplicate" {
  fn no_duplicate(x : Array[Int]) -> Bool {
    @sorted_set.from_iter(x.iter()).length() == x.length()
  }

  inspect(
    @qc.quick_check_silence(
      @qc.forall(@qc.Gen::spawn(), fn(iarr : (Int, Array[Int])) {
        let (x, arr) = iarr
        not(remove(arr.copy(), x).contains(x)) |> @qc.filter(no_duplicate(arr))
      }),
      expect=GaveUp,
    ),
    content="+++ [60/1000/100] Ok, gave up!",
  )
}

///|
test "use one_of" {
  inspect(
    @qc.quick_check_silence(
      @qc.forall(@qc.Gen::spawn(), fn(a : Array[Int]) {
        @qc.forall(@qc.one_of_array(a), fn(y : Int) {
          not(remove(a, y).contains(y))
        })
        |> @qc.filter(a.length() != 0)
      }),
      expect=Fail,
    ),
    content="+++ [3/35/100] Ok! Failed as expected.",
  )
}

///|
test "explicit universal qualification" {
  inspect(
    @qc.quick_check_silence(
      @qc.forall(@qc.Gen::spawn(), fn(x : List[Int]) { x.rev().rev() == x }),
    ),
    content="+++ [100/0/100] Ok, passed!",
  )
}
