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
fn prop_rev(l : @list.List[Int32]) -> Bool {
  l.rev().rev() == l
}

///|
test "prop reverse (fail)" {
  let prop_rev = (l : @list.List[Int32]) => l.rev().rev() == l.rev()
  @qc.quick_check(prop_rev |> @qc.Arrow, expect=Fail)
}

///|
test "prop reverse" {
  inspect(
    @qc.quick_check_silence(prop_rev |> @qc.Arrow),
    content=(
      #|+++ [100/0/100] Ok, passed!
    ),
  )
}

///|
test "add comm double" {
  inspect(
    @qc.quick_check_silence(add_comm_double |> @qc.Arrow),
    content=(
      #|+++ [100/0/100] Ok, passed!
    ),
  )
}

///|
test "modify max tests" {
  inspect(
    @qc.quick_check_silence(@qc.Arrow(prop_rev), max_success=1000),
    content=(
      #|+++ [1000/0/1000] Ok, passed!
    ),
  )
}

///|
test "quick_check uses the max_shrinks option name" {
  inspect(
    @qc.quick_check_silence(true, max_shrinks=0),
    content=(
      #|+++ [100/0/100] Ok, passed!
    ),
  )
}

///|
test "invalid max_size is rejected" {
  let result = @qc.quick_check_silence(true, max_size=0) catch {
    Failure(message) => message
  }
  inspect(result, content="quickcheck: max_size must be greater than 0")
}

///|
test "invalid max_success is rejected" {
  let result = @qc.quick_check_silence(true, max_success=-1) catch {
    Failure(message) => message
  }
  inspect(
    result,
    content="quickcheck: max_success must be greater than or equal to 0",
  )
}

///|
test "zero max_success runs no properties" {
  inspect(
    @qc.quick_check_silence(false, max_success=0),
    content=(
      #|+++ [0/0/0] Ok, passed!
    ),
  )
}

///|
test "zero max_success preserves the expected outcome" {
  inspect(
    @qc.quick_check_silence(false, max_success=0, expect=Fail),
    content=(
      #|*** [0/0/0] Failed! Expected failure, but passed!
    ),
  )
}

///|
test "invalid max_shrinks is rejected" {
  let result = @qc.quick_check_silence(false, max_shrinks=-1) catch {
    Failure(message) => message
  }
  inspect(
    result,
    content="quickcheck: max_shrinks must be greater than or equal to 0",
  )
}

///|
test "large max tests" {
  inspect(
    @qc.quick_check_silence((), max_success=2000),
    content=(
      #|+++ [2000/0/2000] Ok, passed!
    ),
  )
}

///|
test "larger max tests" {
  inspect(
    @qc.quick_check_silence((), max_success=10000),
    content=(
      #|+++ [10000/0/10000] Ok, passed!
    ),
  )
}

///|
test "add assoc double (expect fail)" {
  @qc.quick_check(add_assoc_double |> @qc.Arrow, expect=Fail)
}

///|
test "small check pass" {
  let prop = (x : Int32) => x + 0 == x
  inspect(
    @feat.small_check_silence(prop, max_size=1000000),
    content=(
      #|+++ [1000000/0/1000000] Ok, passed!
    ),
  )
}

///|
test "small check expect fail" {
  let prop = (x : Int32) => x == 0
  inspect(
    @feat.small_check_silence(prop, max_size=5, expect=Fail),
    content=(
      #|+++ [1/0/5] Ok! Failed as expected.
    ),
  )
}

///|
test "non empty list (with filter)" {
  let prop_is_non_empty = (l : @list.List[Int32]) => {
    @qc.property(!l.is_empty()).filter(!l.is_empty())
  }
  @qc.quick_check(@qc.Arrow(prop_is_non_empty))
}

///|
test "reject all" {
  let prop_reject = (_x : Int32) => @qc.property(true).filter(false)
  inspect(
    @qc.quick_check_silence(@qc.Arrow(prop_reject), expect=GaveUp),
    content=(
      #|+++ [0/1000/100] Ok, gave up!
    ),
  )
}

///|
test "label" {
  let ar : @qc.Arrow[@list.List[Int32], Bool] = Arrow(prop_rev)
  inspect(
    @qc.quick_check_silence(
      @qc.forall(coverage_lists(), (x : @list.List[Int32]) => {
        @qc.property(ar).label(
          if x.is_empty() {
            "trivial"
          } else {
            "non-trivial"
          },
        )
      }),
    ),
    content=(
      #|+++ [100/0/100] Ok, passed!
      #|Coverage:
      #|50% : trivial
      #|50% : non-trivial
    ),
  )
}

///|
test "collect" {
  inspect(
    @feat.small_check_silence(
      fn(x : Int32) { @qc.property(true).collect(x) },
      max_size=2,
    ),
    content=(
      #|+++ [2/0/2] Ok, passed!
      #|Coverage:
      #|50% : 0
      #|50% : 1
    ),
  )
}

///|
test "nested arrow uses fresh sample" {
  // The outer forall fixes x = 0, but the nested Arrow quantifies a fresh Int.
  // If Arrow reused x, then y == x would always pass. The expected failure shows
  // that nested Arrow does not share the outer sample.
  inspect(
    @qc.quick_check_silence(
      @qc.forall(@coreqc.pure(0), x => @qc.Arrow((y : Int32) => y == x)),
      expect=Fail,
    ),
    content=(
      #|+++ [0/0/100] Ok! Failed as expected.
    ),
  )
}

///|
test "classes" {
  inspect(
    @qc.quick_check_silence(
      @qc.forall(coverage_lists(), (x : @list.List[Int32]) => {
        @qc.property(prop_rev(x))
        .classify(x.length() > 5, "long list")
        .classify(x.length() <= 5, "short list")
      }),
    ),
    content=(
      #|+++ [100/0/100] Ok, passed!
      #|Coverage:
      #|50% : long list
      #|50% : short list
    ),
  )
}

///|
test "classes can overlap" {
  inspect(
    @feat.small_check_silence(
      fn(x : Int32) {
        @qc.property(true)
        .classify(x != 0, "non-zero")
        .classify(x >= 0, "non-negative")
      },
      max_size=3,
    ),
    content=(
      #|+++ [3/0/3] Ok, passed!
      #|Coverage:
      #|66.66% : non-zero
      #|66.66% : non-negative
    ),
  )
}

///|
test "label + classes" {
  inspect(
    @qc.quick_check_silence(
      @qc.forall(coverage_lists(), x => {
        @qc.property(prop_rev(x))
        .classify(x.length() > 5, "long list")
        .classify(x.length() <= 5, "short list")
        .label("length is \{x.length()}")
      }),
    ),
    content=(
      #|+++ [100/0/100] Ok, passed!
      #|Coverage:
      #|50% : length is 0
      #|50% : length is 6
      #|50% : long list
      #|50% : short list
    ),
  )
}

///|
test "failure report is concise by default" {
  let prop = @qc.forall(@coreqc.pure((0, [0, 0, -1])), fn(iarr) {
    let (x, arr) = iarr
    let out = remove(arr.copy(), x)
    @qc.property(!out.contains(x)).counterexample("after remove: \{Repr(out)}")
  })
  inspect(
    @qc.quick_check_silence(prop),
    content=(
      #|*** [0/0/100] Failed! Falsified.
      #|(0, [0, 0, -1])
      #|after remove: [0, -1]
    ),
  )
}

///|
test "verbose failure report includes the reproduction seed" {
  inspect(
    @qc.quick_check_silence(false, seed=123, verbose=true),
    content=(
      #|*** [0/0/100] Failed! Falsified.
      #|Seed: 123
      #|Shrinks: 0 successful, 0 unsuccessful, 0 final attempts
    ),
  )
}

///|
test "failure report renders details" {
  let prop = @qc.forall(@coreqc.pure((0, [0, 0, -1])), fn(iarr) {
    let (x, arr) = iarr
    let out = remove(arr.copy(), x)
    @qc.property(!out.contains(x)).counterexample("after remove: \{Repr(out)}")
  })
  inspect(
    @qc.quick_check_silence(prop, verbose=true),
    content=(
      #|*** [0/0/100] Failed! Falsified.
      #|Seed: 37
      #|Counterexample:
      #|(0, [0, 0, -1])
      #|after remove: [0, -1]
      #|Shrinks: 0 successful, 0 unsuccessful, 0 final attempts
    ),
  )
}

///|
test "failure coverage excludes the failing sample" {
  inspect(
    @feat.small_check_silence(
      fn(x : Int32) {
        @qc.property(x != 1).collect(if x == 0 { "zero" } else { "non-zero" })
      },
      max_size=3,
      verbose=true,
    ),
    content=(
      #|*** [1/0/3] Failed! Falsified.
      #|Seed: 37
      #|Counterexample:
      #|1
      #|Labels:
      #|non-zero
      #|Shrinks: 0 successful, 0 unsuccessful, 0 final attempts
      #|Coverage:
      #|100% : zero
    ),
  )
}

///|
test "abort" {
  inspect(
    @qc.quick_check_silence(@qc.Arrow(prop_rev), abort=true),
    content=(
      #|+++ [1/0/100] Ok, passed!
    ),
  )
}

///|
/// Natural Numbers
priv enum Nat {
  Zero
  Succ(Nat)
} derive(Debug)

///|
impl @feat.Enumerable for Nat with fn enumerate() {
  @feat.pay(() => {
    @feat.singleton(Zero) + @feat.Enumerable::enumerate().fmap(n => Succ(n))
  })
}

///|
impl @coreqc.Arbitrary for Nat with fn arbitrary(i, rs) {
  @feat.feat_random(i).run(i, rs)
}

///|
impl Add for Nat with fn add(self, other) {
  match self {
    Zero => other
    Succ(n) => Succ(Add::add(n, other))
  }
}

///|
impl Eq for Nat with fn equal(self, other) {
  match (self, other) {
    (Zero, Zero) => true
    (Succ(a), Succ(b)) => a == b
    _ => false
  }
}

///|
impl @shrink.Shrink for Nat

///|
fn add_comm_nat(ab : (Nat, Nat)) -> Bool {
  let (a, b) = ab
  a + b == b + a
}

///|
test "add comm nat" {
  inspect(
    @qc.quick_check_silence(add_comm_nat |> @qc.Arrow),
    content=(
      #|+++ [100/0/100] Ok, passed!
    ),
  )
}

///|
fn[T] reverse(lst : Array[T]) -> Array[T] {
  lst.rev()
}

///|
test "reverse" {
  debug_inspect(reverse(([] : Array[Int32])), content="[]")
  debug_inspect(reverse([1, 2, 3]), content="[3, 2, 1]")
}

///|
test "prop_reverse_identity" {
  fn prop_reverse_identity(arr : Array[Int32]) {
    reverse(reverse(arr)) == arr
  }

  inspect(
    @qc.quick_check_silence(@qc.Arrow(prop_reverse_identity)),
    content=(
      #|+++ [100/0/100] Ok, passed!
    ),
  )
}

///|
fn remove(arr : Array[Int32], x : Int32) -> Array[Int32] {
  match arr.search(x) {
    Some(i) => arr.remove(i) |> ignore
    None => ()
  }
  arr
}

///|
fn prop_remove_not_presence(iarr : (Int32, Array[Int32])) -> Bool {
  let (x, arr) = iarr
  !remove(arr, x).contains(x)
}

///|
fn prop_length_is_not_greater(iarr : (Int32, Array[Int32])) -> Bool {
  let (x, arr) = iarr
  let len = arr.length()
  remove(arr, x).length() <= len
}

///|
test "prop length is not greater" {
  inspect(
    @qc.quick_check_silence(@qc.Arrow(prop_length_is_not_greater)),
    content=(
      #|+++ [100/0/100] Ok, passed!
    ),
  )
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
    @qc.forall(
      Generator((size, state) => @coreqc.Arbitrary::arbitrary(size, state)),
      (i_arr : (Int32, Array[Int32])) => {
        let (x, arr) = i_arr
        !remove(arr, x).contains(x)
      },
    ),
    expect=Fail,
  )
}

///|
test "no_duplicate" {
  fn no_duplicate(x : Array[Int32]) -> Bool {
    @sorted_set.from_iter(x.iter()).length() == x.length()
  }

  @qc.quick_check(
    @qc.forall(
      Generator((size, state) => @coreqc.Arbitrary::arbitrary(size, state)),
      (iarr : (Int32, Array[Int32])) => {
        let (x, arr) = iarr
        @qc.property(!remove(arr.copy(), x).contains(x)).filter(
          no_duplicate(arr),
        )
      },
    ),
    expect=Success,
  )
}

///|
test "use one_of" {
  @qc.quick_check(
    @qc.forall(
      Generator((size, state) => @coreqc.Arbitrary::arbitrary(size, state)),
      (a : Array[Int32]) => {
        if a.is_empty() {
          @qc.filter(true, false)
        } else {
          @qc.forall(@coreqc.elements(a), (y : Int32) => {
            !remove(a, y).contains(y)
          })
        }
      },
    ),
    expect=Fail,
  )
}

///|
test "explicit universal qualification" {
  inspect(
    @qc.quick_check_silence(
      @qc.forall(
        Generator((size, state) => @coreqc.Arbitrary::arbitrary(size, state)),
        (x : @list.List[Int32]) => x.rev().rev() == x,
      ),
    ),
    content=(
      #|+++ [100/0/100] Ok, passed!
    ),
  )
}

///|
priv struct DebugOnly(Int32) derive(Eq, Debug)

///|
impl @feat.Enumerable for DebugOnly with fn enumerate() {
  (@feat.Enumerable::enumerate() : @feat.Enumerate[Int32]).fmap(x => {
    DebugOnly(x)
  })
}

///|
impl @coreqc.Arbitrary for DebugOnly with fn arbitrary(size, rs) {
  DebugOnly(@coreqc.Arbitrary::arbitrary(size, rs))
}

///|
impl @shrink.Shrink for DebugOnly with fn shrink(self) {
  @shrink.Shrink::shrink(self.0).map(x => DebugOnly(x))
}

///|
test "forall accepts Debug-only samples" {
  inspect(
    @qc.quick_check_silence(@qc.forall(@coreqc.pure(DebugOnly(1)), x => x == x)),
    content=(
      #|+++ [100/0/100] Ok, passed!
    ),
  )
}

///|
test "quick_check_fn accepts Debug-only input" {
  inspect(
    @qc.quick_check_fn_silence((x : DebugOnly) => x == x),
    content=(
      #|+++ [100/0/100] Ok, passed!
    ),
  )
}

///|
test "small_check accepts Debug-only input" {
  inspect(
    @feat.small_check_silence((x : DebugOnly) => x == x, max_size=2),
    content=(
      #|+++ [2/0/2] Ok, passed!
    ),
  )
}

///|
test "collect accepts Debug-only labels" {
  inspect(
    @feat.small_check_silence(
      fn(x : DebugOnly) { @qc.property(true).collect(@debug.repr(x)) },
      max_size=2,
    ),
    content=(
      #|+++ [2/0/2] Ok, passed!
      #|Coverage:
      #|50% : DebugOnly(0)
      #|50% : DebugOnly(1)
    ),
  )
}

///|
fn coverage_lists() -> @coreqc.Generator[@list.List[Int32]] {
  let index = Ref(0)
  Generator((_, _) => {
    index.val += 1
    if index.val % 2 == 0 {
      List([1, 2, 3, 4, 5, 6])
    } else {
      List([])
    }
  })
}
