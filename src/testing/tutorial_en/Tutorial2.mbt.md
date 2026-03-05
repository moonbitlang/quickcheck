# QuickCheck Tutorial Part 2

## The Challenge of Constrained Generators

One of the biggest challenges in property-based testing (PBT) is **constrained random generation**. Real-world inputs are often not something a simple structural generator can handle. We can automatically derive generators for simple types, but once a type has internal invariants—or values must satisfy a predicate—this approach quickly runs out of steam. A naïve idea is: "generate values from a large domain first, then filter out the ones that don’t satisfy the condition inside the property." But that often makes testing extremely inefficient, or even yields no valid samples at all, because valid inputs are typically very sparse.

Consider a classic constrained PBT scenario:

$$
\forall x,\forall t, \text{isBST}(t) \implies \text{isBST}(\text{insert}(t, x))
$$

This says: if a tree $t$ is a valid binary search tree (BST), then inserting a new value $x$ into $t$ produces another valid BST.

To test this property, the framework repeatedly samples `(x, t)`. If `t` is not a BST, the sample is discarded immediately; only samples that meet the precondition will proceed to `insert` and then check the result. The problem is that the probability of a random tree being a BST is very low, so a naïve generator will waste most test iterations on discards. In such cases, we have to design a specialized generator that directly produces trees satisfying `isBST`. In this article, we’ll gradually explore how to design custom generators and implement them using QuickCheck’s API, so we can efficiently test constrained properties.

## Simple Generators

Let’s start with a class of simple generators—the building blocks of more complex ones. They mainly handle things like restricting the domain of primitive values, mixing container types, combining product types, and so on.

### Range Control

In PBT, the commonest starting point is modeling the range of values for primitive types—more precisely, constraining the domain of an ordered type. For integers, we might only care about a certain interval; for characters, we might focus on a specific range or category. In QuickCheck, we have functions such as `@qc.int_range`, `@qc.small_int`, `@qc.nat`, and `@qc.neg_int` to express different integer domains, as well as `@qc.char_range`, `@qc.alphabet`, and `@qc.numeral` for constraining character domains. In practice, we usually use these generators to restrict inputs to the range allowed by the intended semantics, and then rely on the property to validate higher-level relationships.

```mbt check
///|
test "gen @qc.int_range invariant" {
  let gen = @qc.int_range(-10, 10)
  let prop = @qc.forall(gen, fn(x) { x >= -10 && x <= 10 })
  @qc.quick_check(prop)
}
```

Generators are not always "random". We can also construct a constant generator with `@qc.pure`, which is useful for representing boundary cases or fixing certain preconditions. This kind of generator is crucial when composing generators: it lets us hold some inputs steady so we can focus on variation in the rest.

```mbt check
///|
test "gen @qc.pure value" {
  let gen = @qc.pure(7)
  let prop = @qc.forall(gen, fn(x) { x == 7 })
  @qc.quick_check(prop)
}
```

### Deriving Generators with Arbitrary

`Arbitrary` is an important trait in QuickCheck: it defines how to generate random values for a given type. The MoonBit compiler has built-in support for automatically deriving `Arbitrary` instances, producing a default random generator for simplest types. You only need to write `derive(Arbitrary)`.

```mbt check
///|
enum Color {
  Red
  Green
  Blue
} derive(Arbitrary, Show)
```

If a type already has an `Arbitrary` instance, then `@qc.Gen::spawn` can produce a generator with the default distribution. This matches the implicit generation logic used by `@qc.quick_check_fn`, but it also allows us to insert the generator explicitly into `@qc.forall`. That keeps generator composition structurally clear, and still lets us layer additional constraints on top.

```mbt check
///|
test "gen spawn for arbitrary" {
  let gc : @qc.Gen[Color] = @qc.Gen::spawn()
  let gen : @qc.Gen[Int] = @qc.Gen::spawn()
  inspect(
    gc.samples(size=5),
    content=(
      #|[Green, Green, Green, Blue, Red]
    ),
  )
  inspect(
    gen.samples(),
    content=(
      #|[6, 4, -6, -3, 0, 2, -8, 4, 5, 2]
    ),
  )
}
```

### Collections and Multi-Argument Composition

When a task involves collection structures, a basic generator needs to express both "length" and "where elements come from". `@qc.Gen::array_with_size` generates fixed-length arrays, and `@qc.list_with_size` constructs lists of a specified length. Fixed length is not just for convenience; it often corresponds directly to preconditions in protocols, formats, or algorithms.

```mbt check
///|
test "gen array_with_size" {
  let gen = @qc.int_range(0, 9).array_with_size(5)
  json_inspect(gen.samples(size=5), content=[
    [0, 6, 4, 3, 8],
    [0, 4, 6, 5, 7],
    [5, 2, 0, 0, 2],
    [4, 1, 0, 4, 3],
    [5, 3, 3, 1, 4],
  ])
}

///|
test "gen @qc.list_with_size sample" {
  let gen = @qc.char_range('a', 'f').list_with_size(3)
  json_inspect(gen.sample(), content=["a", "b", "f"])
}
```

Multi-argument functions are the norm in real systems. `@qc.tuple`, `@qc.triple`, and `@qc.quad` let us combine multiple generators into a single input, so we can keep the uniform "single-argument property" execution model. This not only simplifies the property itself, but also allows shrinking to consider interactions between multiple parameters at the same time.

```mbt check
///|
test "gen @qc.tuple for two args" {
  let gen = @qc.tuple(@qc.int_range(-20, 20), @qc.int_range(-20, 20))
  let prop = @qc.forall(gen, fn(p) {
    let (a, b) = p
    a - b + b == a
  })
  @qc.quick_check(prop)
}
```

The last key step in these building blocks is transformation. `@qc.Gen::fmap` lets us apply a pure function to certain results, mapping an existing domain into a new one. This capability looks simple, but it’s central to building business-specific inputs; later distribution control and conditional filtering will also be built on top of this layer.

```mbt check
///|
test "gen fmap transform" {
  let gen = @qc.int_range(0, 50).fmap(fn(x) { x * 2 })
  let prop = @qc.forall(gen, fn(x) { x % 2 == 0 })
  @qc.quick_check(prop)
}
```

With these basic structures, we can already cover the commonest input shapes in real-world testing: constrained numeric, fixed-length collections, and multi-parameter combinations. From here, the next problem is whether our distribution is "reasonable"—that is, how to get closer to real-world data while staying within a controllable design space. That will be the focus of the next section.

## Statistical Distribution Control

Once we can generate inputs with "valid shapes", the next question is: do those inputs appear with frequencies that resemble the real world? That’s where distribution control comes in. Real data is often multimodal, skewed, or structurally biased. If we rely on a single range generator, coverage will feel thin. We need composition and weighting to bring the input distribution closer to realistic scenarios, while keeping properties concise.

When the domain has multiple categories or paths, `@qc.one_of` is the directest combinator. It chooses uniformly among several generators. This is useful for placing boundary samples alongside normal cases, so a property can hit extreme conditions while still covering ordinary variations.

```mbt check
///|
test "gen @qc.one_of mix" {
  let gen = @qc.one_of([@qc.pure(0), @qc.pure(1), @qc.int_range(-10, 10)])
  let prop = @qc.forall(gen, fn(x) { x >= -10 && x <= 10 })
  @qc.quick_check(prop)
}
```

Uniform choice is often not ideal: real data usually has clear mainstream ranges or "hot" values. In that case, we can use `@qc.frequency` to weight branches. This lets us express a distribution like "most cases come from one range; a few come from another," concentrating test budget where bugs are likelier, while still keeping coverage of rare paths.

```mbt check
///|
test "gen @qc.frequency weighted" {
  let gen = @qc.frequency([
    (6, @qc.int_range(-3, 3)),
    (1, @qc.int_range(-30, 30)),
  ])
  let prop = @qc.forall(gen, fn(x) { x >= -30 && x <= 30 })
  @qc.quick_check(prop)
}
```

For discrete enumerations, `@qc.one_of_array` and `@qc.one_of_list` are more natural: they sample directly from a given set, without requiring overly elaborate generator construction. We often use them to simulate protocol fields, status codes, or configuration values from a fixed set, making properties closer to real inputs.

```mbt check
///|
test "gen @qc.one_of_array enum" {
  let methods : Array[String] = ["GET", "POST", "PUT"]
  let gen = @qc.one_of_array(methods)
  let prop = @qc.forall(gen, fn(m) { methods.contains(m) })
  @qc.quick_check(prop)
}
```

When multiple fields have dependencies, `@qc.Gen::bind` allows us to encode those dependencies during generation. It lets us generate one value first, then generate subsequent fields based on it—satisfying constraints at the data level and avoiding large stacks of precondition checks inside the property.

> `bind` is a powerful monadic operation. It allows us to dynamically adjust distributions and structure during generation, producing inputs that satisfy complex relationships directly. At the same time, it’s harder to understand and debug, so we should keep the structure layered and clear—avoiding excessive nesting or relying on `bind` as a catch-all way to express complicated logic.

```mbt check
///|
test "gen bind dependent" {
  let gen = @qc.int_range(-10, 10).bind(fn(base) {
    @qc.int_range(0, 5).fmap(fn(delta) { (base, base + delta) })
  })
  let prop = @qc.forall(gen, fn(p) {
    let (a, b) = p
    a <= b && b - a <= 5
  })
  @qc.quick_check(prop)
}
```

We already introduced `@qc.Gen::fmap`, and it remains a fundamental tool for composition: without changing branch probabilities, it maps generated values into a business-level structure. This mapping preserves the shape of the distribution while making the data better match interface semantics, so it’s commonly used to construct identifiers, normalized inputs, or derived fields.

In practice, we often use `@qc.one_of` or `@qc.frequency` to set the "macro distribution", and then use `bind` and `fmap` to handle "micro structure" constraints and derivations. This two-level structure balances coverage and realism while keeping generators readable. Composition and distribution do not change the property itself, but they can significantly affect test effectiveness. Distribution design should follow the intended semantics: avoid being overly uniform, and avoid being overly biased, so that random testing can discover defects more reliably under a limited budget.

On top of that, we still need to control size and complexity. That involves how the `size` parameter evolves and how we scale generators—this will be the focus of the next section.

## Size and Complexity

This section discusses how the `size` parameter affects data size and test complexity. Random testing is not "bigger is always better": inputs that are too large can obscure the essence of a bug, while inputs that are too small may not provide meaningful coverage. We should treat `size` as a knob that trades off cost and benefit, and use configuration and generator strategies to approximate real complexity within a controllable budget.

`@qc.quick_check` provides `max_size` to cap overall size. This is the most direct control mechanism. We often use it when algorithmic complexity is high or the input domain can grow exponentially, to prevent test time from blowing up while still checking the property thoroughly within a reasonable range.

```mbt check
///|
test "@qc.quick_check max_size" {
  let gen = @qc.sized(fn(n) { @qc.small_int().list_with_size(n) })
  let prop = @qc.forall(gen, fn(xs) { xs.length() >= 0 })
  @qc.quick_check(prop, max_size=30)
}
```

When we want "data structures to grow in sync with `size`", `@qc.sized` is the most explicit tool. It passes `size` into the generation logic, letting us encode size constraints inside the generator and avoid dealing with size-related preconditions in the property. This is especially effective for arrays, lists, trees, and similar structures, because it internalizes complexity control into the construction rules of the input domain.

```mbt check
///|
test "@qc.sized array with explicit length" {
  let gen = @qc.sized(fn(n) {
    let len = if n < 0 { 0 } else { n }
    @qc.tuple(@qc.pure(len), @qc.int_range(0, 9).array_with_size(len))
  })
  inspect(
    gen.sample(),
    content=(
      #|(100, [5, 5, 0, 2, 0, 5, 4, 6, 4, 2, 1, 3, 3, 3, 0, 8, 2, 4, 2, 3, 5, 6, 5, 8, 8, 6, 2, 1, 7, 3, 6, 6, 1, 3, 8, 3, 4, 7, 4, 8, 7, 4, 0, 7, 2, 5, 4, 6, 5, 5, 8, 8, 5, 6, 5, 6, 2, 3, 5, 7, 3, 3, 0, 3, 7, 4, 0, 4, 0, 7, 6, 6, 2, 5, 1, 5, 3, 3, 2, 7, 8, 8, 8, 1, 4, 2, 8, 0, 8, 8, 4, 2, 6, 5, 0, 2, 5, 2, 0, 6])
    ),
  )
}
```

When we want to restrict size without changing the generator’s structure, we can use `@qc.Gen::resize`. It fixes `size` to a specific value, making complexity stable and predictable. This is often useful during debugging or regression testing, where we want counterexamples to be more concentrated and runtime more consistent.

```mbt check
///|
test "resize clamps size" {
  let gen = @qc.sized(fn(n) { @qc.int_range(0, 9).list_with_size(n) })
  let small = gen.resize(5)
  let prop = @qc.forall(small, fn(xs) { xs.length() == 5 })
  @qc.quick_check(prop)
}
```

If we want size to vary with `size` but grow less steeply, we can use `@qc.Gen::scale` to adjust the size mapping. This effectively adds a function on top of the "complexity growth curve", letting input size grow more gradually as test rounds progress, resulting in more stable coverage and more controllable runtime within a limited budget.

```mbt check
///|
test "scale slows growth" {
  let gen = @qc.sized(fn(n) { @qc.int_range(0, 9).list_with_size(n) })
  let scaled = gen.scale(fn(n) { n / 2 })
  let prop = @qc.forall(scaled, fn(xs) { xs.length() <= 20 })
  @qc.quick_check(prop, max_size=40)
}
```

Size control affects not only performance but also failure explanation. Structures that are too large increase shrinking time, add noise to counterexamples, and can even hide the critical path. That’s why we should treat `max_size`, `resize`, and `scale` as one coherent strategy: use different growth curves at different stages so that properties can reach complex cases while keeping failures readable and diagnosable.

## Combinator Constructors

At this point we have range constraints, distribution control, and size control. The remaining difficulty is **structural constraints**. For example, binary search or interval merging typically requires the input array to be sorted—something a basic generator like `int_range` cannot express directly as a precondition. A straightforward approach is to generate an array first, then use `@qc.filter` to keep only sorted samples; this is a common entry point to combinator-based construction.

```mbt check
///|
test "combinator sorted array with filter" {
  fn is_non_decreasing(xs : Array[Int]) -> Bool {
    fn go(i : Int) -> Bool {
      if i + 1 >= xs.length() {
        true
      } else {
        xs[i] <= xs[i + 1] && go(i + 1)
      }
    }

    go(0)
  }

  let base = @qc.int_range(-8, 8).array_with_size(3)
  let prop = @qc.forall(base, fn(arr) {
    @qc.forall(@qc.one_of_array(arr), fn(x) {
      arr[0] <= x && x <= arr[arr.length() - 1]
    })
    |> @qc.filter(is_non_decreasing(arr))
  })

  @qc.quick_check(prop, discard_ratio=20)
}
```

This example has three layers of composition: first, `array_with_size` fixes the structure; then, nested `forall + one_of_array` sets up a dependency between an element and its container; finally, `filter` enforces the "sorted" constraint. The style is intuitive and works well for quickly validating an idea, but it still discards some samples.

When the discard rate is high, it’s usually better to move constraints into the construction phase. QuickCheck already provides `@qc.sorted_array`, which we can use directly:

```mbt check
///|
test "combinator sorted array constructor" {
  let gen = @qc.sorted_array(5, @qc.int_range(-30, 30))
  let prop = @qc.forall(gen, fn(arr) {
    @qc.forall(@qc.one_of_array(arr), fn(x) {
      arr[0] <= x && x <= arr[arr.length() - 1]
    })
  })
  @qc.quick_check(prop)
}
```

`filter` is good for expressing temporary preconditions; constructors like `sorted_array` are better for stable structural invariants. In engineering practice, we usually start with a filter to locate the right property, then gradually replace it with specialized constructors to make tests both readable and efficient.

## A Case Study: Constructing Constrained Structures

After introducing these combinators, it’s time to get to the main topic: designing generators that satisfy a specific property—sorted arrays, balanced trees, protocol-specific formats, and so on. Of course, this is not easy. This section can only offer a rough framework; complex situations still require creative design and iterative debugging from the tester.

At the core, writing QuickCheck generators by hand boils down to two goals:

* Encode the "valid input space" into generation—don’t rely on filtering.
* Keep distribution and size (`size`) controllable, so tests can run efficiently while still covering the structural corners you care about.

### Size as a First-Class Parameter

QuickCheck’s `Gen` has an implicit `size` parameter: as the number of tests increases, `size` gradually grows. When writing generators for recursive structures, the most important thing is that each recursive layer must consume `size`. Otherwise, you either get infinite recursion or structures that explode in size and slow tests to a crawl.

```mbt nocheck
fn gen_t() -> @qc.Gen[T] {
  letrec go = (s : Int) => {
    match s {
      0 => base case
      n => recursive case, can call go(n - 1) for smaller substructures
    }
  }
  @qc.sized(go)
}
```

If you don’t want to "subtract 1 at every level", you can also split `n` into left and right sub-sizes (this is the standard pattern for trees, graphs, and ASTs): `let k = int_range(0, n - 1)`, use `k` on the left and `n - 1 - k` on the right. This tends to produce a more natural shape than always growing one-sided in depth. Alternatively, you can use `go(n / 2)` to slow growth.

### The Binary Search Tree Example

First, define the BST data structure:

```mbt check
///|
enum Tree[T] {
  Leaf
  Node(Tree[T], T, Tree[T])
} derive(Debug, Show)
```

If the property does not strongly depend on the "shape distribution" of trees, the first approach is to define an `insert` function that inserts arbitrary values into a BST, and then use `from_array` to build a BST from an array. That way, we can generate a plain array with `@qc.int_range().array_with_size()`, convert it into a tree with `from_array`, and obtain a tree that naturally satisfies the BST invariant. Shrinking is also straightforward (shrink the list).

```mbt check
///|
fn[T : Compare] Tree::insert(t : Tree[T], v : T) -> Tree[T] {
  match t {
    Leaf => Node(Leaf, v, Leaf)
    Node(l, x, r) if v < x => Node(l.insert(v), x, r)
    Node(l, x, r) if v > x => Node(l, x, r.insert(v))
    Node(l, x, r) => Node(l, x, r) // v == x, no duplicates
  }
}

///|
fn[T : Compare] Tree::from_array(arr : Array[T]) -> Tree[T] {
  arr.fold(init=Leaf, Tree::insert)
}

///|
/// inorder traversal should be sorted
fn[T] inorder(tree : Tree[T]) -> Array[T] {
  match tree {
    Leaf => []
    Node(l, x, r) => inorder(l) + [x] + inorder(r)
  }
}

///|
test "generate BST" {
  let int_arr = @qc.int_range(-100, 100).array_with_size(10)
  let gen_bst = int_arr.fmap(Tree::from_array)
  let prop = @qc.forall(gen_bst, fn(t) {
    let arr = inorder(t)
    arr == arr.copy()..sort()
  })
  @qc.quick_check(prop)
}
```

However, this requires us to understand BST insertion well enough to implement `Tree::insert` correctly. If `insert` itself is wrong, test results can become confusing. This approach can also be inefficient, because `from_array` may produce very unbalanced trees. So a natural next optimization is to generate "more balanced" trees, making it easier to cover diverse shapes.

A BST has a natural representation: its in order traversal is a sorted sequence. So we can generate a list, sort and deduplicate it, and then build an approximately balanced tree by repeatedly choosing the midpoint:

```mbt check
///|
fn[T] from_sorted(arr : ArrayView[T]) -> Tree[T] {
  guard !arr.is_empty() else { Leaf }
  let m = arr.length() / 2
  let (l, x, r) = (arr[:m], arr[m], arr[m + 1:])
  Node(from_sorted(l), x, from_sorted(r))
}

///|
test "generate balanced BST" {
  let int_arr = @qc.int_range(-100, 100).array_with_size(10)
  let gen_bst = int_arr.fmap(fn(arr) { arr..sort()..dedup() |> from_sorted })
  let prop = @qc.forall(gen_bst, fn(t) {
    let arr = inorder(t)
    arr == arr.copy()..sort()
  })
  @qc.quick_check(prop)
}
```

The advantage here is that most trees are more balanced: it becomes easier to hit cases where both left and right subtrees are non-empty, and we reduce performance issues caused by extreme depth.

The next approach is **range-based recursive generation**, where we grow the tree according to BST semantics directly. The key is to maintain a value interval `(lo, hi)` during recursion: values in the left subtree must be `(< root)`, and values in the right subtree must be `(> root)`. This gives us fine-grained control. Below we use `Tree[Int]` as the example (since QuickCheck provides `int_range` out of the box):

```mbt check
///|
fn gen_bst_ranged(min: Int, max: Int) -> @qc.Gen[Tree[Int]] {
  letrec go = (n : Int, lo : Int, hi : Int) => {
    guard lo <= hi && n > 0 else { @qc.pure(Leaf) }
    @qc.frequency([
      (1, @qc.pure(Leaf)),
      (
        4,
        @qc.Gen::new((i, rs) => {
          let x = @qc.int_range(lo, hi).run(i, rs)
          let nL = @qc.int_range(0, n - 1).run(i, rs)
          let nR = n - 1 - nL
          let l = go(nL, lo, x - 1).run(i, rs)
          let r = go(nR, x + 1, hi).run(i, rs)
          Node(l, x, r)
        })
      ),
    ])
  }
  @qc.sized(n => go(n, min, max))
}

test "generate ranged BST" {
  let gen_bst = gen_bst_ranged(-100, 100)
  let prop = @qc.forall(gen_bst, fn(t) {
    let arr = inorder(t)
    arr == arr.copy()..sort()
  })
  @qc.quick_check(prop)
}
```

Note that to avoid duplicates, we use the "discrete domain" trick `x - 1` / `x + 1`. If you allow duplicates, you need to change the intervals to `(lo, x)` for `l` and `(x, hi)` for `r`, and decide consistently which side duplicates go to (the convention must be uniform, e.g. `<=` or `>=`).

The real value of the range-based approach is that, when your structural constraints are more complex (e.g. red-black trees, AVL trees, or ASTs with additional tags), you can carry the "constraint state" all the way down so generation is always valid—instead of gambling on filtering. In other words, this method is the most extensible, because it encodes the semantic invariants directly into the generation logic.

## Summary

Designing constrained generators is one of the core challenges in PBT. By composing basic generators carefully, controlling distribution and size, and internalizing semantic constraints into the generation process, we can efficiently test most constrained properties. Of course, we hope to make this more automated in the future—for example, letting users write only the property and deriving a generator that satisfies its preconditions—lowering the barrier to PBT and expanding its reach. This is quite feasible, and in the next article we’ll discuss more of these frontier techniques (such as [inductive relations](https://github.com/moonbit-community/inrel) and functional enumeration).
