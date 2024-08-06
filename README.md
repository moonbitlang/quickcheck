# MoonBit QuickCheck

QuickCheck is a library for random testing of program properties. The programmer provides a **specification / theorem** of the program, in the form of properties which functions should satisfy, and QuickCheck then tests that the properties hold in a large number of randomly generated cases.

## Features

MoonBit QuickCheck brings many modern academic ideas into industrial practice.

## Demo

Check file `lib/qc_demo.mbt` for usages. The following example reports an error of `@json.stringify` in [core](https://github.com/moonbitlang/core/pull/811).

```moonbit
test "json generator" {
  quick_check(
    fn(jv : JValue) {
      match @result.wrap1(f=@json.parse, @json.stringify(jv)) {
        Err(_) => false
        Ok(jv2) => jv == jv2
      }
    },
  ).print()
}
```

Output:

```
[test-0]: FAIL
  There exist Object({"\x0c": True}) (State={seed: 1941323925062528825, gamma: 16934044424796929712}) such that condition is false (after 0 shrink(s))
    Distribution: 
      1.0: trivial
```

### Testing Strategy

- Test randomly
- Test all finite values up to some depth

### Data Generation

- Functional Enumeration 
- Random Generation

### Property Verification

- Existential Quantification
- Algebraic Invariant
- Boolean Property

## References

- [OCaml QCheck](https://github.com/c-cube/qcheck)
- [Haskell QuickCheck](https://hackage.haskell.org/package/QuickCheck)
- [Feat: functional enumeration of algebraic types](https://doi.org/10.1145/2430532.2364515)
- [QuickCheck: a lightweight tool for random testing of Haskell programs](https://doi.org/10.1145/351240.351266)
- [SmallCheck and Lazy SmallCheck automatic exhaustive testing for small values](https://doi.org/10.1145/1411286.1411292)
- [Automatic Testing of Operation Invariance](https://ceur-ws.org/Vol-1335/wflp2014_paper9.pdf)
- [Fast Splittable Pseudorandom Number Generators](https://doi.org/10.1145/2660193.2660195)