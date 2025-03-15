///|
/// 
/// 
fn prop_symmetry(x : Array[Int], y : Array[Int]) -> Bool {
  x == y == (y == x)
}

///|
let test_forall : @qc.Property = @qc.forall(@qc.Gen::spawn(), fn(
  x : Array[Int]
) {
  @qc.forall(@qc.Gen::spawn(), fn(y : Array[Int]) { prop_symmetry(x, y) })
})

///|
fn coerce[A, B](x : A) -> B = "%identity"

///|
let test_curry : @qc.Arrow[Array[Int], @qc.Arrow[Array[Int], Bool]] = prop_symmetry
  |> @tuple.curry
  |> coerce

///|
let test_tuple : @qc.Arrow[(Array[Int], Array[Int]), Bool] = fn(p) {
    let (x, y) = p
    prop_symmetry(x, y)
  }
  |> @qc.Arrow

///|
test "forall" {
  @qc.quick_check!(test_forall)
}

///|
test "curry" {
  @qc.quick_check!(test_curry)
}

///|
test "tuple" {
  @qc.quick_check!(test_tuple)
}

///|
test {
  let crit = @bm.Criterion::new()
  crit.add(
    @bm.Task::new("forall", fn() {
      try {
        @qc.quick_check!(test_forall)
      } catch {
        _ => ()
      }
    }),
  )
  crit.add(
    @bm.Task::new("curry", fn() {
      try {
        @qc.quick_check!(test_curry)
      } catch {
        _ => ()
      }
    }),
  )
  crit.add(
    @bm.Task::new("tuple", fn() {
      try {
        @qc.quick_check!(test_tuple)
      } catch {
        _ => ()
      }
    }),
  )
  let r = crit.run()
  println(r["forall"])
  println(r["curry"])
  println(r["tuple"])
}
