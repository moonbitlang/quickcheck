# Laws

Auxiliary algebraic law helpers and axiom/equivalence utilities for
`moonbitlang/quickcheck`.

This package is intentionally separate from the root package:

- import `moonbitlang/quickcheck` for generators, drivers, and shrinking
- import `moonbitlang/quickcheck/laws` for reusable laws and axiom helpers

## Import

```json
{
  "import": [
    { "path": "moonbitlang/quickcheck", "alias": "qc" },
    { "path": "moonbitlang/quickcheck/laws", "alias": "laws" }
  ]
}
```

## Invariant Helpers

```mbt check
///|
test "associative helper works on integer addition" {
  let law = associative(Int::add)
  assert_eq(law((1, 2, 3)), true)
}

///|
test "idempotent helper works on a clamp" {
  let clamp = (x : Int) => if x < 0 { 0 } else { x }
  assert_eq(idempotent(clamp)(-5), true)
  assert_eq(idempotent(clamp)(7), true)
}
```

## Axiom Helpers

```mbt check
///|
fn succ_pred_axiom() -> Axiom[Int] {
  Axiom::new(x => Equivalence::new(x + 1 - 1, x))
}

///|
test "axiom converts to a property-shaped function" {
  let prop = succ_pred_axiom().to_property_eq(x => x)
  assert_eq(prop(42), true)
}
```
