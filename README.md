# MoonBit QuickCheck

## Introduction

The idea of QuickCheck was originally introduced in John's paper [_QuickCheck: a lightweight tool for random testing of Haskell programs_](https://doi.org/10.1145/351240.351266) and its Haskell derivation QuickCheck, which aimed at simplifying the writing of tests by generating them. The core is to automatically generate tests based on a the signature of the **specification / theorem** (i.e. properties which functions should satisfy) and QuickCheck then tests that the properties hold. The idea spread to other languages and is now implemented in **MoonBit**. Because of the differences in type systems between Haskell and MoonBit, the original idea morphed into something different. There are several differences to this approach:

- We have discarded many ideas in Haskell QuickCheck that have been proven inappropriate by time.
- Some features requires a very fancy type system were removed (Or not considered currently). For instance, the generation of functions requires GADT but MoonBit does not.
- MoonBit QuickCheck brings many modern academic ideas into industrial practice (listed [below](#references)).

---

## Table of Contents

- [MoonBit QuickCheck](#moonbit-quickcheck)
  - [Introduction](#introduction)
  - [Table of Contents](#table-of-contents)
  - [Quick Start](#quick-start)
    - [Installation](#installation)
    - [First Look](#first-look)
    - [Failure Diagnosis](#failure-diagnosis)
    - [Traits](#traits)
      - [Testable](#testable)
      - [Arbitrary](#arbitrary)
      - [Shrink](#shrink)
  - [Advanced Topics](#advanced-topics)
    - [QuickCheck Invalid Case](#quickcheck-invalid-case)
    - [Generators](#generators)
      - [Choosing between alternatives](#choosing-between-alternatives)
      - [Size parameter](#size-parameter)
      - [Default Generators](#default-generators)
    - [Custom Generator](#custom-generator)
    - [Conditional Properties](#conditional-properties)
    - [Classifying Data](#classifying-data)
  - [Application](#application)
  - [Roadmap and Future Work](#roadmap-and-future-work)
    - [Data Generation](#data-generation)
    - [Property Verification](#property-verification)
    - [Shrinking](#shrinking)
  - [References](#references)

## Quick Start

### Installation

Firstly, you need to install the MoonBit QuickCheck library. 
You can do this by executing the following command:

```sh
moon add moonbitlang/quickcheck
moon install
```

To use the library, you need to import it in your `moon.pkg.json` file,
and for convenience we give an alias `qc` to the library:

```json
{
  "import": [{ "path": "moonbitlang/quickcheck", "alias": "qc" }]
}
```

### First Look

Let's start with something very simple. Suppose that we just wrote a function `reverse` which takes an array as argument and returns its reverse. We want to test its functionality by writing unit tests:

```moonbit
test "reverse" {
  inspect!(reverse(([] : Array[Int])), content="[]")
  inspect!(reverse([1, 2, 3]), content="[3, 2, 1]")
}
```

Is this enough to prove that this function is correct? No, the bugs may lies in the remaining untested code. But if we want more rigorous verification, we may need to write more test cases. For the complicated program, there would never be time to. How can we reduce the cost of testing? The key to doing so must be to generalize the test functions, so that each function covers not only one test case, but many. This is where QuickCheck comes in. We can write a property that `reverse` should hold for any array, and QuickCheck will generate a large number of random array and check that the property holds for all of them.

But what property should we write? We may notice that the reverse of the reverse of an array is the original array. So we can write a **property** (you can roughly think of it as a function `(T) -> Bool`) that `reverse` should hold for any array:

```moonbit
fn prop_reverse_identity(arr : Array[Int]) -> Bool {
  reverse(reverse(arr)) == arr
}
```

We may consider the code logically as:

$$
\forall x: \text{Array[T]}.\space \text{reverse}(\text{reverse}(x)) = x
$$

Looks good, now we can use QuickCheck to test this property,
this is easily archived by the `quick_check_fn` function:

```moonbit
test {
  @qc.quick_check_fn!(prop_reverse_identity)
  // equivalent to quick_check!(Arrow(prop_reverse_identity))
}
```

The `quick_check_fn` function takes a `f: (T) -> Bool`,
where `T` satisfies some constraints (We will discuss this later),
the function first generates a bunch of random values with
type `T` and then calling the property function `f` with these values.
The results are then collected and will be reported later.
In this example, the input value `T = Array[Int]` and the boolean
value `true` implies that the property holds for some particular values,
and the `false` implies that the property does not hold for some values.
When finding a counterexample, the QuickCheck will try to simplify it
and then print it to the console. If all the tests passed, the following
sentence will be printed to the console:

```
+++ [100/0/100] Ok, passed!
```

The three number in the brackets are the number of passed, discarded and total tests
(the default value of total tests is `100`).

### Failure Diagnosis

Now let's see another example: suppose we want to write a function
`remove(arr : Array[Int], x : Int) -> Array[Int]` that takes
an array and an element and returns a new array with **all**
occurrences of `x` removed. The intuitive implementation is to
search for `x` in the array and remove it if found:

```moonbit
fn remove(arr : Array[Int], x : Int) -> Array[Int] {
  match arr.search(x) {
    Some(i) => arr.remove(i) |> ignore
    None => ()
  }
  arr
}
```

Now let's use QuickCheck to test this function.
The first thing we need to do is to write a property.
We may consider the following properties:

- If an element was removed from the array, the length of the array should be less than or equal to the original array

$$
\forall x:\text{T}, a:\text{Array[T]} . \space
\text{length}(\text{remove}(a,x)) \leq \text{length}(a)
$$

- If an element was removed from the array, the element should not exist in the array anymore

$$
\forall x:\text{T}, a:\text{Array[T]} . \space
x\not\in\text{remove}(a,x)
$$

Now we translate the first property into a MoonBit function (Note that the property function should have exactly **one** argument, but we can use tuple to pass multiple arguments):

```moonbit
fn prop_length_is_not_greater(iarr : (Int, Array[Int])) -> Bool {
  let (x, arr) = iarr
  let len = arr.length()
  remove(arr, x).length() <= len
}
```

Run QuickCheck, all tests passed. However, this property is not considered a _good_ property because it is can be fulfilled easily and hence the test is not very meaningful. Most Bugs may still exist in the function.

```moonbit
test {
  @qc.quick_check_fn!(prop_length_is_not_greater)
}

// +++ [100/0/100] Ok, passed!
```

The later property is considered better,
similarly we implement it in MoonBit:

```moonbit
fn prop_remove_not_presence(iarr : (Int, Array[Int])) -> Bool {
  let (x, arr) = iarr
  remove(arr, x).contains(x).not()
}

test {
  @qc.quick_check_fn!(prop_remove_not_presence)
}
```

The QuickCheck reports a failure with a counterexample in the second line after 8 tests:

```
*** [8/0/100] Failed! Falsified.
(0, [0, 0])
```

When `x = 0` and `arr = [0, 0]` the property does not hold.
The `remove` function should remove all occurrences of
`x` in the array, but it only removes the first one.
QuickCheck finds us a succinct counterexample that
directly reveals the core of the problem.
How does it do this?
In practice QuickCheck generates a lot of complex samples
and inputs them into the property function to test them,
and if it finds a counterexample it **doesn't** report it immediately,
but **shrinks** accordingly to try to find a simpler counterexample.
In this example, as in many cases, the randomly generated test case
contains junk values that have nothing to do with the test failure itself.
When the counterexample is found, qc will apply some predefined shrinkers
to this counterexample and try to explore downwards for smaller counterexamples.

### Traits

We've already discussed generation and shrinking,
and this section will discuss how these functions are attached to a type.
Remind the `quick_check_fn` function we used before, it is defined as follows
in the MoonBit QuickCheck library:

```moonbit
///| path: src/driver.mbt
pub fn quick_check_fn[A : Arbitrary + Shrink + Show, B : Testable](
  f : (A) -> B
) -> Unit!Failure {
  quick_check!(Arrow(f))
}
```

Let's look at the type signature first.
The `quick_check_fn` function takes a function `f: (A) -> B` as argument,
where `A` should have implemented the `Arbitrary`, `Shrink` and `Show` traits,
and `B` should have implemented the `Testable` trait.
In our examples `B` is fixed to a `Bool`, this is because Booleans
implement the `Testable` trait, which can actually be more flexible,
we will discuss this later, for now we focus on the constraints of `A`:

- `Arbitrary` is a trait that generates random values of a type.
- `Shrink` is a trait that allows a value of particular type to be shrunk to simpler ones.
- `Show` is used for printing the counterexample when a test fails.

The function body
It takes a value of type that implemented `Testable` as argument and runs the test. This is an effectful function that may throw an failure to the MoonBit test driver when a test fails (Or give up). If success, it simply returns `Unit` with the sentence `Ok, passed!` printed to the console.

The body of the function contains a call to `quick_check` and wraps `f` in `Arrow`.
According to the definition of `quick_check`, it requires a value `prop` of a type
`P` that implements `Testable` as an argument, and under certain conditions:
For any type `P` implementing `Testable`,
and `A` implementing `Arbitrary`, `Shrink` and `Show`,
the `Arrow[A, P]` type can be implemented as `Testable` as well.
The reader may wonder why we don't directly implement `(A) -> P` as `Testable`
but instead use `Arrow[A, P]` as a wrapper.
The reason is simple: The MoonBit type system does not allow us to do so.

```moonbit
pub fn quick_check[P : Testable](prop : P) -> Unit!Failure

type Arrow[A, P] (A) -> P

impl[P : Testable, A : Arbitrary + Shrink + Show] Testable for Arrow[A, P]
```

#### Testable

Another advantage of using `Arrow` is that it constructs a `Testable`,
and QuickCheck provides a number of `Testable` combinators that can be
used to modify a test's properties, such as `with_max_success`
to modify the maximum number of successes:

```moonbit
test {
  @qc.quick_check!(
    @qc.Arrow(prop_remove_not_presence) |> @qc.with_max_success(1000),
  )
}

///| Output: +++ [1000/0/1000] Ok, passed!
```

There are many other combinators that can be used to modify the properties of a
test, check the document for `src/testable.mbt` for more details.

#### Arbitrary

`Arbitrary` is a trait indicating that a type has the ability
to generate random values for given size and random number generator,
which is defined in the MoonBit Core library with compiler level support.
It has a method `arbitrary` that takes a size and a random number
generator and then returns a random value of the type.

```moonbit
pub trait Arbitrary {
  arbitrary(Int, RandomState) -> Self
}
```

The vast majority of types in the core library already implement the
`Arbitrary` trait, and users can also write specific instance for
their own defined types or use the compiler's automatic derivation.
For example, we can derive the `Arbitrary` trait for our own `Nat` type:

```moonbit
enum Nat {
  Zero
  Succ(Nat)
} derive(Arbitrary, Show)

test {
  let nat_gen : @qc.Gen[Nat] = @qc.Gen::spawn()
  let nats = nat_gen.samples(size=4)
  inspect!(
    nats,
    content="[Succ(Succ(Succ(Zero))), Succ(Succ(Succ(Succ(Zero)))), Succ(Zero), Succ(Succ(Succ(Zero)))]",
  )
}
```

For any type that implements `Arbitrary`,
you can use the `Gen::spawn` function to get its generator.
Calling the generator's method `samples` will generate some values of that type.
Note that `Gen` is an internal type of QuickCheck,
which will be automatically called by the `quick_check` function,
normally do not require the user to access it,
here we use it to show the behavior of `Arbitrary`.

#### Shrink

`Shrink` is a trait that shrinks a value to a simpler one.
It has a method `shrink` that takes a value and returns a iter
of simpler values (lazily).

```moonbit
pub trait Shrink {
  shrink(Self) -> Iter[Self]
}
```

If QuickCheck finds a set of values that fails a given property,
it will try to make that value simpler than the original value by
getting the shrinks for the value and trying each one in turn to
check that the property is still false. If it is, the smaller
value becomes the new counterexample and the shrinking process
continues with that value.

## Advanced Topics

### QuickCheck Invalid Case

This section summarizes some common mistakes in using QuickCheck:

- Testing with external effects: If a property requires an external state, for example, the user's input, the global mutable and etc, you should pass the state as an argument to the property function. Otherwise, the property is not a pure function and the test is not repeatable.
- Mutable arguments was unexpectedly modified: You should keep the arguments **immutable** in the property function. If you need to modify the arguments, you should make a copy of them.

### Generators

Test data is produced by test data generators. QuickCheck defines default generators for some often used types, but you can use your own, and will need to define your own generators for any new types you introduce (Or for simple types we can use the trivial definition by `derive(Arbitrary)`).

Generators have types of the form `Gen[T]`, which is a generator for values of type `T`. It was defined as a struct, it contains single field named `gen`, with type `(Int, RandomState) -> T` (The first parameter is the size of the generated value, and the second is the random number generator), notice that this is similar to the `arbitrary` method in the `Arbitrary` trait:

```moonbit
struct Gen[T] {
  gen : (Int, RandomState) -> T
}
```

QuickCheck defines a series of useful methods for `Gen[T]`, for the most basic ones, we can use `Gen::new(f: (Int, RandomState) -> T)` to create a generator from a function and run it by invoking the `run` method:

```moonbit
let g : Gen[Int] = Gen::new(..) // Suppose we have a generator for Int
let x : Int = g.run(100, RandomState::new()) // Generate a random Int at size 100
```

`Gen[T]` was implemented as functor, applicative and monad which means you can compose it in many ways.

```moonbit
fn pure[T](val : T) -> Gen[T]
fn fmap[T, U](self : Gen[T], f : (T) -> U) -> Gen[U]
fn ap[T, U](self : Gen[(T) -> U], v : Gen[T]) -> Gen[U]
fn bind[T, U](self : Gen[T], f : (T) -> Gen[U]) -> Gen[U]
```

For instance, you can use the `fmap` method to transform the generated value:

```moonbit
let g : Gen[Int] = Gen::new(..)
let g2 : Gen[Int] = g.fmap(fn(x) { x + 1 })
let g3 : Gen[String] = g.fmap(fn(x) { x.to_string() })
```

Or create a dependent generator:

```moonbit
let g : Gen[Int] = Gen::new(..)
let g2 : Gen[Int] = g.bind(fn(x : Int) {
  if x == 0 {
    Gen::pure(100)
  } else {
    Gen::pure(200)
  }
})
```

The following documents explains some useful combinators for `Gen[T]`.

#### Choosing between alternatives

A generator may take the form `one_of` which chooses among the generators in the array with equal probability. For example, this generates a random boolean which is true with probability one half:

```moonbit
let gen_bool : Gen[Bool] = one_of([pure(true), pure(false)])
```

If you want to control the distribution of results using frequency instead. We have `frequency` which chooses a generator from the array randomly, but weighs the probability of choosing each alternative by the factor given. For example, this generates true in the probability of $4/5$.

```moonbit
let gen_freq : Gen[Bool] = frequency([(4, pure(true)), (1, pure(false))])
```

#### Size parameter

We have pointed that test data generators have an size parameter. QuickCheck begins by generating small test cases, and gradually increases the size as testing progresses. Different test data generators interpret the size parameter in different ways: some _ignore_ it, some interprets it as an upper bound on the size of containers. Most generators defined in `Arbitrary` trait depends on the size parameter but most separated generator combinators does not.

You can obtain the value of the size parameter using `sized` combinator.

```moonbit
pub fn sized[T](f : (Int) -> Gen[T]) -> Gen[T]
```

For example, we can make a trivial generator for a list of integers with a given length:

```moonbit
let gen : Gen[Int] = sized(fn { size => pure(size) })
let arr = Array::makei(20, fn { i => gen.sample(size=i) })
inspect!(arr, content="[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]")
```

The purpose of size control is to ensure that test cases are large enough to reveal errors, while remaining small enough to test fast. Sometimes the default size control does not achieve this. So we have provided some tool functions like `resize` and `scale` (check the document for details) for this purpose.

#### Default Generators

QuickCheck defines default test data generators and shrinkers for some often used types (By trait `Arbitrary` and `Shrink`). You do not need to define or apply these explicitly for every property because QuickCheck can provide a property with appropriate generators and shrinkers for the property's arguments. But if you are required to do so, you can use the `forall` for explicitly universal quantification.

```moonbit
quick_check!(forall(spawn(), fn(x : List[Int]) { x.rev().rev() == x }))
```

Note that the `spawn` function is useful for creating `Gen[T]` from its arbitrary instance, in this example the type checker infers the type of the first argument in `forall` to be `Gen[List[T]]` from the type of the property function.

```moonbit
fn Gen::spawn[T : Arbitrary]() -> Gen[T]
```

### Custom Generator

Recall the `remove` function we want to test before. The QuickCheck do report an error for us, but the generator is quite random and the tuple element `(x, arr): (Int, Array[Int])` is independent. In most cases, the `x` is not in the array, so the test is not very meaningful (falls to the branch `None => ()`). Now we use the `one_of_array` combinator to generate a random element from a generated non-empty array, which makes the test more meaningful.

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

We admit the following facts:

- The first `spawn` evaluates to a generator of `Array[Int]`.
- The `forall` function can be nested.
- There is a `filter` function that filters out the test cases that do not satisfy the condition, non-empty array is required in this case.
- The `one_of_array` function selects a random element from a non-empty array.

```
*** [4/33/100] Failed! Falsified.
[0, 0]
0
```

We find that there are 33 cases that do not satisfy the condition, and the counterexample is `[0, 0]` and `0`, which points out the issue clearly. The `one_of_array` function selects a random element from the array, so the `y` is always `0` in this case. The `remove` function only removes the first one, so the property does not hold.

### Conditional Properties

Now let's further verify our hypothesis: The function `remove` only removes the first one but not all. So if we instead formulate a conditional property which restricts the input array contains no duplicated elements, then our tests should pass. Use the function `filter` can filter out unwanted test cases:

```moonbit
test {
  fn no_duplicate(x : Array[Int]) -> Bool {
    @sorted_set.from_iter(x.iter()).size() == x.length().to_int64()
  }

  quick_check!(
    forall(
      spawn(),
      fn(iarr : (Int, Array[Int])) {
        let (x, arr) = iarr
        filter(remove(arr.copy(), x).contains(x).not(), no_duplicate(arr))
      },
    ),
  )
}
```

- Notice that we use `arr.copy()` to make a copy of the array, because the `remove` function may modify the argument array.
- The `no_duplicate` function checks whether the input array contains no duplicated elements.
- As discussed above, the `filter` combinator filters out the test cases that do not satisfy the condition.

Running this test, we find that all tests passed. Now we have strong evidence that the `remove` function only removes the first one but not all.

### Classifying Data

We may interest in the distribution of the generated data: sometimes the generator may produce trivial data that does not help us to find the bugs. We want to find out what data is generated and how often in order to improve the generator. QuickCheck provides functions like `label`, `collect` and `classify` to achieve this.

```moonbit
test "classes" {
  quick_check_fn!(
    fn(x : List[Int]) {
      Arrow(prop_rev)
      |> classify(x.length() > 5, "long list")
      |> classify(x.length() <= 5, "short list")
    },
  )
}
```

The `classify` function takes a boolean and a string, and if the boolean is true, the test case is classified with the string.

```
+++ [100/0/100] Ok, passed!
22% : short list
78% : long list
```

The `label` function takes a string and classifies the test case with the string.

```moonbit
test "label" {
  quick_check_fn!(
    fn(x : List[Int]) {
      Arrow(prop_rev)
      |> label(if x.is_empty() { "trivial" } else { "non-trivial" })
    }
  )
}
```

The result is as follows:

```
+++ [100/0/100] Ok, passed!
8% : trivial
92% : non-trivial
```

The `collect` function is a generalization of `label`. The difference is that the `collect` takes an argument implementing the `Show` trait, and the `label` takes a string directly. The `collect` function is useful when you want to classify the test case with a complex value.

## Application

We have applied MoonBit QuickCheck to test the correctness of the MoonBit core. For now we have found several bugs in the core, including:

- [Escaped characters in JSON](https://github.com/moonbitlang/core/pull/812)
- [Invalid JSON in inspect function](https://github.com/moonbitlang/core/issues/819)
- [BigInt.op_sub edge cases](https://github.com/moonbitlang/core/issues/860)
- [Unterminated moon test](https://github.com/moonbitlang/core/issues/875)
- [Incorrect BigInt.op_div due to the ill normalization step](https://github.com/moonbitlang/core/issues/942)

## Roadmap and Future Work

### Data Generation

- [x] Functional Enumeration
- [x] Random Generation
  - Currently use the SplitMix algorithms
- [ ] Falsify (with free shrinkers)
  - [x] Basic Implementation
  - [x] Test driver adaption

### Property Verification

- [x] Boolean Property
- [x] Test Invariants
- [x] Operation Invariance
- [x] `Testable` Trait
- [ ] Existential Quantification

### Shrinking

- [x] Linear Shrinking
- [x] Internal Shrinking
- [ ] Integrated Shrinking

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
