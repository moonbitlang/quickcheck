# MoonBit QuickCheck

## Introduction
The idea of QuickCheck was originally introduced in John's paper [*QuickCheck: a lightweight tool for random testing of Haskell programs*](https://doi.org/10.1145/351240.351266) and its Haskell derivation QuickCheck, which aimed at simplifying the writing of tests by generating them. The core is to automatically generate tests based on a the signature of the **specification / theorem** (i.e. properties which functions should satisfy) and QuickCheck then tests that the properties hold. The idea spread to other languages and is now implemented in **MoonBit**. Because of the differences in type systems between Haskell and MoonBit, the original idea morphed into something different. There are several differences to this approach:

- We have discarded many ideas in Haskell QuickCheck that have been proven inappropriate by time.
- Some features requires a very fancy type system were removed (Or not considered currently). For instance, the generation of functions requires GADT but MoonBit does not.
- MoonBit QuickCheck brings many modern academic ideas into industrial practice (listed [below](#references)).

## Beginner's Example

Let's start with something very simple. Suppose that we just wrote a function `reverse` which takes an array as argument and returns its reverse. And we want to test its functionality by writing unit tests:
```moonbit
test "reverse" {
  inspect!(reverse(([] : Array[Int])), content="[]")
  inspect!(reverse([1, 2, 3]), content="[3, 2, 1]")
}
```

Is this enough to prove that this function is correct? No, the bugs may lies in the remaining untested code. But if we want more rigorous verification, we may need to write more test cases. For the complicated program, there would never be time to. How can we reduce the cost of testing? The key to doing so must be to generalize the test functions, so that each function covers not only one test case, but many. This is where QuickCheck comes in. We can write a property that `reverse` should hold for any array, and QuickCheck will generate a large number of random array and check that the property holds for all of them.

But what property should we write? We may notice that the reverse of the reverse of an array is the original array. So we can write a property that `reverse` should hold for any array:
```moonbit
fn prop_reverse_identity(arr : Array[Int]) {
  reverse(reverse(arr)) == arr
}
```

We may consider the code logically as:
$$
\forall x: \text{Array[T]}.\space \text{reverse}(\text{reverse}(x)) = x
$$

Looks good, now we can use QuickCheck to test this property (Note that we should wrap the function in `Arrow` to make it a `Testable` though implicit conversion not work now):
```moonbit
test {
  quick_check!(Arrow(prop_reverse_identity))
}
```

The result (The three number in the brackets are the number of passed, discarded and total tests):
```
+++ [100/0/100] Ok, passed!
```

Now let's see another example: Suppose we wrote a function `remove(arr : Array[Int], x : Int) -> Array[Int]` that takes an array and an element and returns a new array with **all** occurrences of `x` removed. The intuitive implementation is to search for `x` in the array and remove it if found:

```moonbit
fn remove(arr : Array[Int], x : Int) -> Array[Int] {
  match arr.search(x) {
    Some(i) => arr.remove(i) |> ignore
    None => ()
  }
  arr
}
```

We may consider the following properties:
- If an element was removed from the array, the length of the array should be less than or equal to the original array
$$
\forall x:\text{T}, a:\text{Array[T]} . \space
\text{length}(\text{remove}(a,x)) \leq \text{length}(a)
$$
- If an element was removed from the array, the element should not exist in the array
$$
\forall x:\text{T}, a:\text{Array[T]} . \space
x\not\in\text{remove}(a,x)
$$

Now we translate the first property into MoonBit code (Note that the property function should have **only one** argument, but we can use tuple to pass multiple arguments):
```moonbit
fn prop_length_is_not_greater(iarr : (Int, Array[Int])) -> Bool {
  let (x, arr) = iarr
  let len = arr.length()
  remove(arr, x).length() <= len
}
```

Run QuickCheck, all tests passed. However, this property is not considered a good property because it is can be fulfilled easily and the test is not very meaningful. Most Bugs may still exist in the function.
```
test {
  quick_check!(Arrow(prop_length_is_not_greater))
}

// +++ [100/0/100] Ok, passed!
```

The later property is considered better (The `with_max_success` function sets the number of tests that should be performed to `1000`):
```moonbit
fn prop_remove_not_presence(iarr : (Int, Array[Int])) -> Bool {
  let (x, arr) = iarr
  remove(arr, x).contains(x).not()
}

test {
  quick_check!(Arrow(prop_remove_not_presence) |> with_max_success(1000))
}
```

The QuickCheck reports a failure with a counterexample in the second line after almost 100 tests:
```
*** [107/0/1000] Failed! Falsified.
(0, [0, 0])
```

When `x = 0` and `arr = [0, 0]` the property does not hold. The `remove` function should remove all occurrences of `x` in the array, but it only removes the first one. In this example, as in many cases, the randomly generated test case contains junk values that have nothing to do with the test failure itself. When QuickCheck finds a failing test case, it tries to simplify it by applying some shrinking strategies. In fact the failing case is much complex but the shrinking algorithm has simplified it to the minimal case and presented it to us.


### Custom Generator

```moonbit
test {
  quick_check!(
    forall(
      spawn(),
      fn(a : Array[Int]) {
        forall(one_of_array(a), 
          fn(y : Int) { remove(a, y).contains(y).not() })
        |> filter(a.length() != 0)
      },
    ),
  )
}
```

## Advanced Topics


## Application
We have applied MoonBit QuickCheck to test the correctness of the MoonBit core. For now we have found several bugs in the core, including:

- [Escaped characters in JSON](https://github.com/moonbitlang/core/pull/812)
- [Invalid JSON in inspect function](https://github.com/moonbitlang/core/issues/819)
- [BigInt.op_sub edge cases](https://github.com/moonbitlang/core/issues/860)
- [Unterminated moon test](https://github.com/moonbitlang/core/issues/875)
- [Incorrect BigInt.op_div due to the ill normalization step](https://github.com/moonbitlang/core/issues/942)

## Roadmap and Future Work

### Testing Strategy

- [x] Randomized property test: Run the test for `N` random elements drawn from the argument type.
  - Similar to Haskell QuickCheck
- [ ] Exhaustive specialized property test: Run the test for each element of a subset of the argument type.
  - Similar to SmallCheck and Feat

### Data Generation

- [x] Functional Enumeration 
- [ ] Falsify (with free shrinkers)
- [x] Random Generation
  - Currently use the SplitMix algorithms

### Property Verification

- [x] Boolean Property
- [x] Test Invariants
- [x] Operation Invariance
- [x] `Testable` Trait
- [ ] Existential Quantification

### Shrinking

- [x] Linear Shrinking
- [ ] Integrated Shrinking 
- [ ] Internal Shrinking

## References

- [OCaml QCheck](https://github.com/c-cube/qcheck)
- [Haskell QuickCheck](https://hackage.haskell.org/package/QuickCheck)
- [Feat: functional enumeration of algebraic types](https://doi.org/10.1145/2430532.2364515)
- [QuickCheck: a lightweight tool for random testing of Haskell programs](https://doi.org/10.1145/351240.351266)
- [SmallCheck and Lazy SmallCheck automatic exhaustive testing for small values](https://doi.org/10.1145/1411286.1411292)
- [Automatic Testing of Operation Invariance](https://ceur-ws.org/Vol-1335/wflp2014_paper9.pdf)
- [Fast Splittable Pseudorandom Number Generators](https://doi.org/10.1145/2660193.2660195)
- [falsify: Internal Shrinking Reimagined for Haskell](https://doi.org/10.1145/3609026.3609733)
- [Selective applicative functors](https://doi.org/10.1145/3342521)