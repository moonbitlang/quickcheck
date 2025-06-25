///|
/// 
fn prop_symmetry(x : Array[Int], y : Array[Int]) -> Bool {
  (x == y) == (y == x)
}

///|
let test_forall : @qc.Property = @qc.forall(@qc.Gen::spawn(), fn(
  x : Array[Int]
) {
  @qc.forall(@qc.Gen::spawn(), fn(y : Array[Int]) { prop_symmetry(x, y) })
})

///|
fn[A, B] coerce(x : A) -> B = "%identity"

///|
let test_curry : @qc.Arrow[Array[Int], @qc.Arrow[Array[Int], Bool]] = (fn(a) {
    fn(b) { prop_symmetry(a, b) }
  })
  |> coerce

///|
let test_tuple : @qc.Arrow[(Array[Int], Array[Int]), Bool] = (fn(p) {
    let (x, y) = p
    prop_symmetry(x, y)
  })
  |> @qc.Arrow

///|
test (b : @bench.T) {
  b.bench(name="forall", fn() { b.keep(try? @qc.quick_check(test_forall)) })
}

///|
test (b : @bench.T) {
  b.bench(name="curry", fn() { b.keep(try? @qc.quick_check(test_curry)) })
}

///|
test (b : @bench.T) {
  b.bench(name="tuple", fn() { b.keep(try? @qc.quick_check(test_tuple)) })
}
