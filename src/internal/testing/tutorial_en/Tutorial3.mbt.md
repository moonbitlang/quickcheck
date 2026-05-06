# QuickCheck Tutorial Part 3

This is the final installment in the QuickCheck tutorial series. It focuses on what happens after a property fails: how QuickCheck shrinks a raw failing sample, and how to tell whether the final counterexample really explains the bug.

In practice, randomized testing is only as useful as the failures it produces. A huge failing input may reveal a real defect without making it much easier to debug. A small, stable counterexample often does.

Shrinking is only part of the story. Once constrained inputs get more complicated, hand-written generators and shrinkers become harder to maintain. That leads naturally to more systematic techniques: small-scale exhaustive search, functional enumeration, and eventually inductive-relation-based approaches.

## Counterexamples and Shrinking

In QuickCheck, failure is where analysis begins. Once a property fails, the question is no longer whether it failed, but why, and what the smallest failing condition is. Shrinking keeps the failure intact while compressing the sample toward the core defect.

Operationally, QuickCheck generates samples, finds a failure, and then searches for smaller failing values along a shrink tree. The property does not change, but the speed of understanding often does. A counterexample can be technically correct and still be too large to help. By contrast, a smaller counterexample that still preserves the relevant structure often points almost directly at the bug. Shrinking is therefore not a side feature of QuickCheck. Like the generator, it determines whether the testing workflow is actually usable. We will start with the `Shrink` trait and see how the framework models this process.

### Default Shrink

`Shrink` is the QuickCheck trait for simplifying a value. Its core method, `shrink`, takes a value and returns an iterator of smaller candidates. The iterator matters because shrinking is meant to support lazy search. In many cases, we can find a smaller failing sample after checking only a few candidates, without having to enumerate all of them up front.

```mbt nocheck
///|
pub trait Shrink {
  shrink(Self) -> Iter[Self]
}
```

For most primitive types and common container types, QuickCheck already provides default instances. So as soon as we use APIs such as `@qc.quick_check_fn` or `@qc.Arrow`, the matching shrink logic is enabled automatically. Integers tend to move toward `0`, booleans shrink toward `false`, arrays and lists try both removing elements and shrinking elements, and tuples shrink component by component.

Let us start with the simplest case. For integers, default shrinking does not blindly enumerate every smaller value. Instead, it probes a small set of candidates that move quickly toward simpler values.

```mbt check
///|
test "shrink int sample" {
  json_inspect(@qc.Shrink::shrink(100), content=[99, 97, 94, 88, 75, 50, 0])
}
```

This already reveals the basic idea. Shrinking is guided search toward simpler values. For container types, the same pattern becomes structural: an array first tries to remove elements, and only then shrinks the entries that still matter.

Now consider a more realistic example. Suppose we write a broken removal function that deletes only the first occurrence of an element instead of removing all occurrences:

```mbt check
///|
fn remove_first_only(arr : Array[Int], x : Int) -> Array[Int] {
  guard arr.search(x) is Some(i) else { arr }
  arr.remove(i) |> ignore
  arr
}

///|
fn prop_remove_all(iarr : (Int, Array[Int])) -> Bool {
  let (x, arr) = iarr
  !remove_first_only(arr, x).contains(x)
}

///|
test "default shrink for tuple and array" {
  let x = @qc.quick_check_fn_silence(prop_remove_all, verbose=true)
  inspect(
    x,
    content=(
      #|*** [8/0/100] Failed! Falsified.
      #|Counterexample:
      #|(0, [0, 0, -1])
      #|Shrinks: 1 successful, 1 unsuccessful, 1 final attempts
    ),
  )
}
```

Here `quick_check_fn` combines the default strategies for tuples, arrays, and integers automatically. The integer moves toward `0`, while the array tries to drop irrelevant elements before shrinking the ones that still matter. The final counterexample is `(0, [0, 0, -1])`. That is already quite small, and it points straight at the issue: `remove_first_only` does not handle repeated `0`s correctly.

Default shrinking works well in many common cases, but it is still a search process and cannot run forever. Both `@qc.quick_check` and `@qc.quick_check_fn` expose `max_shrink` / `max_shrinks` to cap the shrinking budget. This matters most when inputs are large and the shrink tree is wide. As always, there is an engineering trade-off between finding a smaller counterexample and getting feedback quickly.

### Custom Shrink

The strength of default shrinking is that it is generic. Its weakness is the same: it knows nothing about domain invariants. As soon as an input carries extra meaning, such as "must be even", "must be non-negative", or "must stay sorted", default shrinking may produce values that are type-correct but outside the domain we actually want to test. In those cases, we need to take control of shrinking ourselves.

QuickCheck provides two directly relevant APIs:

```mbt nocheck
fn[T : Testable, A : Show] @qc.forall_shrink(
  gen : @gen.Gen[A],
  shrinker : (A) -> Iter[A],
  f : (A) -> T,
) -> @qc.Property

fn[P : Testable, T] @qc.shrinking(
  shrinker : (T) -> Iter[T],
  x0 : T,
  pf : (T) -> P,
) -> @qc.Property
```

`forall_shrink` means: once a generator is fixed, explicitly define how generated values should shrink. `shrinking` is lower-level. It does not use random generation at all; instead, it starts from a concrete value and searches downward through the candidates produced by a shrinker. The former is the usual tool for day-to-day property testing. The latter is useful when we want to debug the shrinker itself.

Here is a simple example. Suppose the input domain is "non-negative even integers". If shrinking starts producing odd numbers, then it has already left the intended domain. One easy fix is to start from the default integer shrinker and filter it back into that domain:

```mbt check
///|
fn shrink_even_nat(x : Int) -> Iter[Int] {
  @qc.Shrink::shrink(x).filter(y => y >= 0 && y % 2 == 0)
}

///|
test "forall_shrink keeps even invariant" {
  let gen = @gen.int_range(0, 100).fmap(x => x * 2)
  let prop = @qc.forall_shrink(gen, shrink_even_nat, x => x < 20)
  @qc.quick_check(prop, expect=Fail)
}
```

Here the generator only produces even numbers, and the custom shrinker ensures that shrinking never leaves that domain. If we used the default `Int` shrinker directly, QuickCheck would still find smaller counterexamples, but it would walk through many odd values on the way. Those values are type-valid, but they are not part of the input space we care about. A counterexample can be smaller and still be harder to interpret.

`shrinking` is useful for more local inspection. If we suspect a shrinker is behaving badly, we can bypass random generation and start from a concrete failing value:

```mbt check
///|
test "shrinking starts from explicit value" {
  // FIXME: newline is not preserved after moon fmt
  let prop = @qc.shrinking(shrink_even_nat, 84, x => x < 20)

  inspect(
    @qc.quick_check_silence(prop, verbose=true),
    content=(
      #|*** [0/0/100] Failed! Falsified.
      #|Shrinks: 11 successful, 0 unsuccessful, 1 final attempts
    ),
  )
}
```

The value of this style is that it separates generation from shrinking. Once a property is already known to fail, we can pin down a concrete failing sample and ask whether the shrinker really drives it toward the business-level minimum we expect. This matters most for complex structures. Often the hard part is not the generator, but understanding why the final counterexample is still larger than it should be. In practice, `forall_shrink` is the API we use most often, or we pass the trait instance explicitly through a newtype wrapper.

### Structure-Preserving Shrink

Constrained structures make the problem harder again. In Part 2, we already saw examples such as sorted arrays, BSTs, and balanced trees. These inputs come with explicit invariants. If shrinking breaks those invariants, a perfectly good failing sample can be reduced into an input that should never have existed at all. When that happens, the counterexample becomes much less informative.

Take a `sorted array`. Default array shrinking does two things: it removes elements and shrinks element values. That is sensible for ordinary arrays. But for sorted arrays, shrinking a value can easily break the global ordering invariant. We could try to patch this with filters, but that usually wastes many candidates and performs badly. The better approach is to preserve sortedness directly inside the shrinker, so both "remove an element" and "make an element smaller" are checked for legality as part of the shrink process:

```mbt check
///|
pub fn[T : @qc.Shrink + Compare] shrink_sorted_array(
  xs : Array[T],
  lo~ : T,
  hi~ : T,
) -> Iter[Array[T]] {
  // Shrinks individual element values while preserving sortedness.
  // For each position i, it applies the default shrinker to xs[i], then
  // keeps only candidates that stay within the legal range [lo, hi]
  // where lo is xs[i-1] (or the global lower bound) and hi is xs[i+1]
  // (or the global upper bound).
  let shrink_one_val = (nv : Array[T]) => {
    let l = nv.length() - 1
    Array::makei(nv.length(), i => i)
    .iter()
    .flat_map(i => {
      let lo = if i == 0 { lo } else { nv[i - 1] }
      let hi = if i == l { hi } else { nv[i + 1] }
      @qc.Shrink::shrink(nv[i]).flat_map(x => {
        if lo <= x && x <= hi && x != nv[i] {
          let nv1 = nv.copy()
          nv1[i] = x
          Iter::singleton(nv1)
        } else {
          Iter::empty()
        }
      })
    })
  }
  // Removes one element at a time from the array.
  // Removing any single element from a sorted array always preserves
  // sortedness, so no additional filtering is needed.
  let remove_one_val = (v : Array[T]) => {
    Array::makei(v.length(), i => i)
    .iter()
    .flat_map(i => {
      let nv = v.copy()
      nv.remove(i) |> ignore
      Iter::singleton(nv)
    })
  }
  remove_one_val(xs).concat(shrink_one_val(xs))
}
```

This code illustrates an important principle. For constrained structures, "smaller" is not enough. What we actually need is "smaller and still valid". Otherwise the shrinker may reduce the literal size of the sample while silently changing the question from "the algorithm fails on a legal input" to "the algorithm fails on an illegal input". That kind of counterexample is much less useful.

```mbt check
///|
test "shrink sorted array" {
  let s = shrink_sorted_array([1, 3, 5], lo=0, hi=9)
  debug_inspect(
    [..s],
    content=(
      #|[[3, 5], [1, 5], [1, 3], [0, 3, 5], [1, 2, 5], [1, 3, 4], [1, 3, 3]]
    ),
  )
}
```

Once we attach this shrinker to a property, we get a shrinking process that preserves sortedness all the way down:

```mbt check
///|
test "forall_shrink for sorted array" {
  let gen = @gen.int_range(0, 9).array_with_size(6).fmap(a => a..sort())
  let prop = @qc.forall_shrink(gen, x => shrink_sorted_array(x, lo=0, hi=10), xs => {
    xs.length() < 3
  })
  let r = @qc.quick_check_silence(prop, verbose=true)
  inspect(
    r,
    content=(
      #|*** [0/0/100] Failed! Falsified.
      #|Counterexample:
      #|[0, 0, 0]
      #|Shrinks: 9 successful, 12 unsuccessful, 2 final attempts
    ),
  )
}
```

The property here is intentionally simple, but it still shows why structure-preserving shrinking matters. The generator always produces sorted arrays of length `6`, and the shrinker keeps trying to remove elements and shrink values until it reaches a smaller failing sample that is still sorted. In this case, `[0, 0, 0]` is already a very small counterexample, and it points directly at the core issue in the property: the length bound on sorted arrays.

The same idea applies to the BST example from Part 2. If a BST is built through a path such as "array -> insert -> tree", then the most robust shrink strategy is often not to shrink tree nodes directly. Instead, we go back to the original representation, shrink the array, and rebuild the tree with `from_array` or `from_sorted`. The advantage is that generation and shrinking now share the same structural meaning, which makes invariants easier to preserve and counterexamples easier to explain.

## Failure and Distribution

### Failure Messages

Shrinking gives us a smaller counterexample, but smaller does not automatically mean clearer. In many cases, the hard part is not finding the bug. It is understanding what the counterexample means in domain terms. We may see that an array or a tree fails, yet still have no idea which state transition mattered or which derived condition triggered the failure. If we only print the raw input, the reader still has to reconstruct those facts by hand.

QuickCheck provides the combinator `counterexample` for exactly this reason. It does not change whether the property holds. It only attaches extra information to the failure output. That lets us print derived values alongside the input itself: intermediate results, specification outputs, normalized forms, path tags, or anything else that makes the failure easier to read.

```mbt check
///|
test "counterexample adds derived information" {
  let prop = @qc.forall(@gen.pure((0, [0, 0, -1])), iarr => {
    let (x, arr) = iarr
    let out = remove_first_only(arr.copy(), x)
    @qc.counterexample(!out.contains(x), "after remove: \{out}")
  })
  let r = @qc.quick_check_silence(prop, verbose=true)
  inspect(
    r,
    content=(
      #|*** [0/0/100] Failed! Falsified.
      #|Counterexample:
      #|(0, [0, 0, -1])
      #|after remove: [0, -1]
      #|Shrinks: 0 successful, 0 unsuccessful, 0 final attempts
    ),
  )
}
```

In this example, the raw input `(0, [0, 0, -1])` is already small. But without the extra line `after remove: [0, -1]`, the reader still has to simulate the function mentally before noticing that one `0` remains.

This technique is especially useful in model-based testing and compiler testing. We often want to print both `expected` and `actual`, a normalized state, or a compact summary of an interpreter trace. Once a property becomes complicated enough, the failure output is really a small debugging report rather than a bare input sample.

### Classification Statistics

Failure messages help us interpret a single counterexample. Classification statistics answer a different question: what does the overall sample distribution look like? Even if a property keeps passing, we should not relax too early. The generator may be spending most of its budget on a dull class of inputs, or it may be missing the branches we actually care about. If that distribution stays invisible, "random coverage" can easily become wishful thinking.

QuickCheck provides three common tools for inspecting sampled data: `label`, `classify`, and `collect`. `label` is useful when each sample should carry a single textual tag. `classify` is useful when we want to split samples into a few domain-level categories. `collect` is more general: it takes any `Show` value and records it as a tag. In practice, `classify` is often the best starting point because it quickly shows whether the categories we care about are appearing at all.

```mbt check
///|
fn t3_prop_rev_list(xs : @list.List[Int]) -> Bool {
  xs.rev().rev() == xs
}

///|
test "classify list distribution" {
  let r = @qc.quick_check_silence(
    @qc.Arrow((xs : @list.List[Int]) => {
      t3_prop_rev_list(xs)
      |> @qc.classify(xs.length() > 5, "long list")
      |> @qc.classify(xs.length() <= 5, "short list")
    }),
  )
  inspect(
    r,
    content=(
      #|+++ [100/0/100] Ok, passed!
      #|Coverage:
      #|79% : long list
      #|21% : short list
    ),
  )
}
```

One subtle point matters here. `@qc.Arrow(f)` is not just a convenient wrapper around an existing value; it introduces a fresh quantified sample for `f`. So if we write `@qc.Arrow(t3_prop_rev_list)` inside another `@qc.Arrow`, the inner property will test a different list from the outer `xs`. That means the classification labels would describe one sample while the property itself runs on another. When we want to classify or label the sample already bound by the outer property, we should call the property function directly on that value, as in `t3_prop_rev_list(xs)`.

The interesting part of this output is not that the property passed. It is that the default generator is clearly biased toward longer lists. If we care about edge cases on empty, singleton, or very short lists, then this output already tells us that the default distribution is probably not enough and the generator needs adjustment.

`label` and `collect` work in the same general way, but at a different level of granularity. For example, we could use `label("length is \{xs.length()}")` to track a textual bucket for each length, or `collect(xs.length())` to gather the raw length value directly. As a rule of thumb, `classify` is better for tutorials and routine regression tests because the categories are stable and easy to read. `label` and `collect` are more useful when we are actively tuning a generator and want a finer view of its behavior.

### Discard Analysis

One distribution issue that is especially easy to miss is discard. When we use `@qc.filter`, preconditions, or guards around partial functions, many samples may be thrown away before the property is even evaluated. A small amount of discard is normal. But if discard remains high, it usually means we pushed constrained-input generation into the property body, and filtering is often the wrong tool for that job.

Consider a mild example. Suppose we only want to test non-empty lists, so we add a filter on top of the default list generator:

```mbt check
///|
test "discard on non-empty lists" {
  let prop_non_empty = (xs : @list.List[Int]) => {
    (!xs.is_empty()) |> @qc.filter(!xs.is_empty())
  }
  inspect(
    @qc.quick_check_silence(@qc.Arrow(prop_non_empty)),
    content=(
      #|+++ [100/40/100] Ok, passed!
    ),
  )
}
```

The property passes, but `40` samples were thrown away. That means the framework had to do extra useless work just to obtain `100` valid samples. If the precondition were any sparser, the waste would grow quickly.

In the extreme case, the test may give up entirely:

```mbt check
///|
test "reject all gives up" {
  let prop_reject = (_x : Int) => @qc.filter(true, false)
  inspect(
    @qc.quick_check_silence(@qc.Arrow(prop_reject), expect=GaveUp),
    content=(
      #|+++ [0/1000/100] Ok, gave up!
    ),
  )
}
```

This example is obviously artificial, but it captures the meaning of discard precisely. QuickCheck is not saying the property failed. It is saying that it could not obtain enough valid samples to run the test in a meaningful way, so it had to stop. So when we see `gave up` in a real project, or when discard stays high for a long time, the first thing to question is usually not the property itself. The real issue is often a structural mismatch between the generator and the precondition. In those cases, the first fix is usually to move as much of the constraint as possible into the generator instead of encoding it as a filter. That is exactly why Part 2 kept stressing the same point: put constraints in the generator whenever possible, not in the filter.

## SmallCheck

### Small-Scale Exhaustive Search

So far, most of the discussion has stayed inside the QuickCheck model of randomized testing: sample values, then shrink the failing ones. SmallCheck takes a different route. If a class of inputs has a natural small-to-large order, we can test a small prefix of that space directly. The goal is not probabilistic coverage, but a search space that is reproducible, exhaustible, and easy to explain.

In MoonBit QuickCheck, the entry point `small_check` looks similar to `quick_check`, but it relies on a completely different capability:

```mbt nocheck
pub fn[A : @feat.Enumerable + Show, B : Testable] @qc.small_check(
  f : (A) -> B,
  max_size? : Int,
  expect? : Expected,
  abort? : Bool,
) -> Unit raise Failure
```

The constraint here is not `Arbitrary + Shrink`, but `Enumerable`. SmallCheck is not asking how to sample one random value. It is asking how to arrange all values of a type in a small-to-large order. Once that order is well designed, the test becomes deterministic: the same `max_size` and the same property always explore the same prefix.

```mbt check
///|
test "small check fails on first non-zero int" {
  let r = @qc.small_check_silence((x : Int) => x == 0, max_size=5, verbose=true)
  inspect(
    r,
    content=(
      #|*** [1/0/5] Failed! Falsified.
      #|Counterexample:
      #|1
      #|Shrinks: 0 successful, 0 unsuccessful, 0 final attempts
    ),
  )
}
```

This result shows the workflow directly. For the default `Enumerable` instance of `Int`, the earliest values are `0, 1, -1, 2, -2, ...`, so the property `x == 0` fails immediately on the second sample, `1`. That is also why SmallCheck often produces useful counterexamples without a separate shrinking phase.

One extra detail matters here. Classical SmallCheck is often presented in terms of a depth bound. The implementation here is closer to an enumeration-prefix model: `max_size` controls how many values are tested in the current run, and those values come from the ordered enumeration defined by `Enumerable`. Whether SmallCheck really explores the space from small to large therefore depends on the quality of the enumerator.

### Enumerator Design

If SmallCheck is about enumerating small values, then the central question becomes obvious: what makes an enumerator well designed? In MoonBit, that information lives in the `Enumerable` trait:

```mbt nocheck
pub(open) trait Enumerable {
  enumerate() -> @feat.Enumerate[Self]
}

pub fn[T] @feat.Enumerate::at(Self[T], BigInt) -> T
```

A good enumerator should satisfy at least three conditions. First, it should avoid duplicates. Otherwise the supposedly exhaustive prefix wastes budget revisiting the same values. Second, each size layer should be finite. Otherwise SmallCheck can get stuck on one layer forever and never reach larger values. Third, the enumeration order should track a reasonable notion of complexity, so that early values really do look like the small samples we want to prioritize.

The second point is especially important for recursive data types. If recursion does not increase cost, then a type such as the natural numbers collapses infinitely many values into the same layer. That breaks part-finiteness and can make enumeration diverge. This is exactly why Feat-style enumerators include an explicit `pay` operation: each recursive constructor application moves the value into the next layer.

```mbt check
///|
enum PeanoNat {
  PZero
  PSucc(PeanoNat)
} derive(Eq, Debug)

///|
impl Show for PeanoNat with output(self, logger) {
  logger.write_string("\{to_repr(self)}")
}

///|
impl @feat.Enumerable for PeanoNat with enumerate() {
  @feat.pay <| () => {
    @feat.singleton(PZero) + @feat.Enumerable::enumerate().fmap(n => PSucc(n))
  }
}

///|
test "peano enumerate order" {
  let e : @feat.Enumerate[PeanoNat] = @feat.Enumerable::enumerate()
  let xs = [0N, 1, 2, 3, 4].map(i => e[i])
  debug_inspect(
    xs,
    content=(
      #|[
      #|  PZero,
      #|  PSucc(PZero),
      #|  PSucc(PSucc(PZero)),
      #|  PSucc(PSucc(PSucc(PZero))),
      #|  PSucc(PSucc(PSucc(PSucc(PZero)))),
      #|]
    ),
  )
}
```

Although this definition is short, it already shows the basic discipline of enumerator design. `@feat.singleton(PZero)` gives the base case. The recursive branch maps smaller naturals to `PSucc(n)` with `fmap`. The outer `pay` ensures that each extra constructor layer is deferred to the next part. Without `pay`, `PZero, PSucc(PZero), PSucc(PSucc(PZero)), ...` would all collapse into the same part, and SmallCheck would not be able to finish enumerating that layer in principle.

For more complicated data types, the overall pattern is still fairly mechanical. Nullary constructors are usually expressed with `singleton`. Unary constructors often use `fmap` directly. Multi-argument constructors are built by enumerating tuples or products and then mapping them back to the real constructor. If a type has multiple constructors, `consts` or `union` can combine them. The goal is not to make the code short. It is to keep the construction process aligned with the meaning of the data, so the enumeration remains duplicate-free and layered by complexity.

### The Feat Style

The `Enumerable` interface above is not ad hoc. It is essentially MoonBit’s realization of the functional-enumeration approach from _Feat: Functional Enumeration of Algebraic Types_. Instead of treating a type as one long linear list of values, Feat represents it as a sequence of finite parts grouped by size. Each part carries two key pieces of information: its cardinality and an indexing function.

MoonBit’s current implementation follows exactly that shape. Internally, `Enumerate[T]` is a lazy stream of parts, and each `Finite[T]` carries two consumers, `fCard` and `fIndex`. That makes the behavior of global indexing via `Enumerate::at` (the `_[_]` operator) quite clear. The implementation does not generate every earlier value one by one. Instead, it skips whole parts using their cardinalities, then indexes directly inside the part that contains the requested value. This is the "function view" from the paper, and it is fundamentally different from the list view used in many SmallCheck-style implementations.

That design has two immediate benefits. First, enumeration is not limited to scanning from the front; it also supports random access. Second, the same enumerator can support multiple testing strategies, including prefix enumeration and size-bounded random sampling through APIs such as `@gen.Gen::feat_random`. In that sense, Feat is not a separate testing framework. It is a shared data-generation substrate.

From the paper’s perspective, this is also the main way Feat improves on traditional SmallCheck. Classical SmallCheck often relies on constructor depth, but depth is not always a good proxy for semantic complexity. Functional enumeration instead encodes "smallness" directly into the construction of parts. For mutually recursive ASTs, syntax trees, and the sum-of-products structures common in type-system tooling, that style of layering is usually more stable and easier to compose mechanically than a plain depth bound.

### Using SmallCheck in Practice

Once the enumerator is in place, using SmallCheck is straightforward. We decide what should count as "small", encode that order into `Enumerable`, and then let `small_check` verify a prefix of the sequence. At that point, test quality depends far less on the random seed and far more on the enumeration order.

```mbt check
///|
test "small check on peano prefix" {
  let r = @qc.small_check_silence(
    fn(n : PeanoNat) { n == PZero },
    max_size=5,
    verbose=true,
  )
  inspect(
    r,
    content=(
      #|*** [1/0/5] Failed! Falsified.
      #|Counterexample:
      #|PSucc(PZero)
      #|Shrinks: 0 successful, 0 unsuccessful, 0 final attempts
    ),
  )
}
```

This makes a useful contrast with the earlier integer example. Since the enumerator for `PeanoNat` is one we wrote ourselves, the prefix of small values visited by SmallCheck is entirely determined by that definition. Here `PZero` is the first value and `PSucc(PZero)` is the second, so the property `n == PZero` fails immediately on the smallest non-zero natural number. Counterexamples like this need almost no post-processing, because the enumeration order is already doing much of the work that shrinking would otherwise have to do.

In real engineering work, we would not write an enumerator just to find a tiny counterexample like `PSucc(PZero)`. The real value appears with more complicated recursive structures. Once a type has several recursive layers, multiple constructors, or mutually recursive definitions, a hand-written QuickCheck generator often starts to resemble the implementation under test. A Feat-style enumerator, by contrast, often stays mechanical, local, and compositional. That is also why the paper puts so much emphasis on large mutually recursive syntax trees.

Overall, SmallCheck works well as a prefix validator. We can first sweep through sufficiently small and representative values to eliminate shallow bugs early, then move on to `feat_random` or another randomized strategy if we need to explore further.

## Summary

This brings the main QuickCheck tutorial series to a close. Part 1 was about properties. Part 2 was about generators. Part 3 was about counterexamples, failure diagnosis, and systematic small-value coverage.

QuickCheck, SmallCheck, and functional enumeration are complementary tools. Use randomized generation plus shrinking when the input space is huge. Use SmallCheck when a type has a natural small-to-large order and you care about shallow counterexamples. Use a good `Enumerable` instance when you want one definition to support both styles. The main mistake is not choosing the wrong tool, but letting properties, generators, and failure explanations drift apart.
