///|
/// 
/// 
fn prop_symmetry(x : Array[Int], y : Array[Int]) -> Bool {
  x == y == (y == x)
}

///|
let test_forall : @qc.Property = @qc.forall(@qc.spawn(), fn(x : Array[Int]) {
  @qc.forall(@qc.spawn(), fn(y : Array[Int]) { prop_symmetry(x, y) })
})

///|
let test_curry : @qc.Arrow[Array[Int], @qc.Arrow[Array[Int], Bool]] = prop_symmetry
  |> @tuple.curry
  |> @unsafe.coerce

test "forall" {
  @qc.quick_check!(test_forall)
}

test "curry" {
  @qc.quick_check!(test_curry)
}

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
  let r = crit.run()
  println(r["forall"])
  println(r["curry"])
}
