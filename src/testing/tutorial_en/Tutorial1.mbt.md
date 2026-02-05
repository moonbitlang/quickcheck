# QuickCheck Tutorial Part 1

This is a long-form series intended to systematically introduce the QuickCheck framework in MoonBit and its use in real-world engineering practice, with the goal of presenting the concepts and methodology of **property-based testing** to a broad developer audience.

The series will be divided into three major parts. The first part—this article—focuses on QuickCheck’s core concepts and on the methodology of designing **properties**. Later parts will cover advanced generator design, shrinking strategies, and techniques for controlling statistical distributions.

## Core Concepts

This chapter aims to build an intuitive understanding of property-based testing. We will not rush into complex generators or sophisticated properties. Instead, we begin from the most straightforward perspective: what exactly does QuickCheck in MoonBit verify?

A _property_ is not a collection of examples, but a program that describes a rule. It is executed repeatedly against a large amount of randomly generated data (in code, this typically appears as a function or an executable expression), allowing us to cover a much larger behavioral space at a lower cost.

When we submit a property to QuickCheck, the framework must first determine whether it is executable. For this purpose, QuickCheck provides the abstraction `Testable`, which unifies `Bool`, functions, and even generators into a runnable `Property`. In other words, what we write is not necessarily a single _test_, but a value that can be translated into a test workflow and being executed, measured, collected, and finally concluded.

```mbt nocheck
fn[P : @qc.Testable] @qc.quick_check(prop : P, max_success? : Int, ...) -> Unit raise Failure
```

The signature above shows QuickCheck’s primary entry point, `@qc.quick_check`. It accepts a `Testable` value, converts it into a `Property`, and runs the test. The `max_success` parameter controls the number of generated samples, defaulting to 100. If the property holds for all samples, the test passes; otherwise, it raises `Failure` and prints a counterexample. Of course, the configuration surface is not limited to `max_success`; later chapters will introduce additional options as needed.

```mbt check
///|
test "@qc.quick_check minimal" {
  @qc.quick_check(true)
}
```

This minimal example contains almost no information, yet it helps us precisely grasp the interface shape. Since `@qc.quick_check` accepts any `Testable` value, a boolean can be used directly as a property (because it implements the trait): if it is `false`, the test fails. Although extremely small, this example clearly reveals the entry semantics: QuickCheck only cares whether “this executable property ultimately holds”.

When the property is a function, the most convenient entry point is `@qc.quick_check_fn`. It requires the function’s argument types to support `Arbitrary`, `Shrink`, and `Show`, so that QuickCheck can automatically generate test data, shrink counterexamples, and print failing samples. We will explain these traits in more detail later; for now, it is enough to know that QuickCheck provides instances for the standard library’s basic types.

You can think of this as a testing mode where “we provide the rule, and the system provides the data”, which is highly efficient for simple models. The example below checks the property “adding zero does not change an integer”. The generator produces 100 integer samples (from small to large) and runs the property; if all results are true, the test passes, otherwise it prints the first failing sample.

```mbt check
///|
fn prop_add_zero(x : Int) -> Bool {
  x + 0 == x
}

///|
test "@qc.quick_check_fn" {
  @qc.quick_check_fn(prop_add_zero)
}
```

Real-world business functions are often multi-argument, while a property accepts only one argument. We therefore bundle multiple inputs into a tuple. This is not a workaround—it is the idiomatic, language-level approach. It allows QuickCheck to preserve a uniform “single-argument property” execution model, while also making it easier to shrink toward smaller counterexample combinations.

```mbt check
///|
fn prop_add_comm(pair : (Int, Int)) -> Bool {
  let (a, b) = pair
  a + b == b + a
}

///|
test "@qc.tuple property" {
  @qc.quick_check_fn(prop_add_comm)
}
```

When we need to actively control the data distribution—or when the default `Arbitrary` instance is not suitable—we should use explicit generators. The corresponding entry point is `@qc.forall`. The meaning of `@qc.forall` is: “for every value produced by the generator, the property must hold”. It binds a generator and a property function into a `Property`, and is the foundation for more advanced designs later. Here we begin with a small-range integer generator so the idea remains easy to grasp.

```mbt check
///|
test "@qc.forall with @qc.int_range" {
  let gen = @qc.int_range(-10, 10)
  let prop = @qc.forall(gen, fn(x) { x + 1 > x })
  @qc.quick_check(prop)
}
```

A generator is not a mysterious black box. It is a deterministic function driven by `size` and a random seed. While `@qc.quick_check` manages these parameters automatically, during property design it is still useful to “peek” at the generator using `@qc.Gen::sample` to calibrate whether the distribution matches expectations.

```mbt check
///|
test "peek generator" {
  let gen = @qc.int_range(-3, 3)
  inspect(gen.sample(size=5, seed=1), content="-2")
}
```

At this point we can briefly mention some internal structural details of QuickCheck:

> From an execution perspective, `Testable` is converted into a `Property`, and a `Property` is further expanded into a traversable test tree. QuickCheck traverses this tree, runs tests, records results, shrinks counterexamples, and ultimately decides the outcome. We do not need to understand these internals right now, but we should recognize that a property is an _executable_ object rather than static documentation. This understanding will influence how we organize properties and generators later.
>
> Readers need not worry that these details will get in the way: the framework encapsulates the complexity. We only need to focus on “writing properties” and “choosing generators”.

Failure handling is also part of the interface semantics: `@qc.quick_check` raises `Failure` and prints a counterexample when the property fails, whereas `@qc.quick_check_silence` returns a report string, making it easier to integrate into toolchains for secondary processing. Understanding this distinction helps us choose the right entry point for debugging and CI.

```mbt check
///|
test "@qc.quick_check_silence" {
  let prop = @qc.forall(@qc.int_range(0, 5), fn(x) { x >= 0 })
  inspect(@qc.quick_check_silence(prop), content="+++ [100/0/100] Ok, passed!")
}
```

By now we can already express an intuitive rule as an executable property and run it with either default or explicit generators. QuickCheck does not require us to master shrinking details upfront. Instead, it provides a clear path from “rule” to “execution”—which is why property-based testing can dramatically reduce testing costs.

## An Introduction to Property Design

This chapter focuses on how to extract verifiable properties from requirements or code. We again avoid complex generators and concentrate on **relations** and **invariants**.

Requirements are often expressed in natural language or mathematical notation; they implicitly contain invariants and algebraic laws. Our job is to translate these laws into executable properties and let randomized testing check whether they hold robustly.

### Algebraic Properties

In property-based testing, the most reliable starting point is an equation-like relationship: it describes constraints between inputs and outputs that should hold over time. Compared to example-based assertions, such relationships are universal and can cover a much larger set of input combinations. We can translate semantics such as “should be equal”, “should preserve order”, or “stops changing after repeated application” into functional laws and hand them to QuickCheck.

QuickCheck provides built-in properties for common algebraic laws, which directly correspond to patterns frequently implied by requirements. For example, when a requirement implies commutativity, we can express it with `@qc.commutative`. Here we use integer addition as an example, and restrict the input range to avoid overflow contaminating the intended semantics. This range restriction does not weaken the test; it helps us stay focused on the property we actually care about.

```mbt check
///|
test "@qc.commutative for add" {
  let gen = @qc.tuple(@qc.int_range(-200, 200), @qc.int_range(-200, 200))
  let prop = @qc.forall(gen, @qc.commutative(fn(a, b) { a + b }))
  @qc.quick_check(prop)
}
```

A common requirement is that merging is independent of grouping, which is naturally captured by associativity—especially relevant for aggregation, concatenation, and merge functions. We use `@qc.associative` to state associativity directly, and use a triple generator to keep the property single-argument.

```mbt check
///|
test "@qc.associative for add" {
  let gen = @qc.triple(
    @qc.int_range(-20, 20),
    @qc.int_range(-20, 20),
    @qc.int_range(-20, 20),
  )
  let prop = @qc.forall(gen, @qc.associative(Int::add))
  @qc.quick_check(prop)
}
```

When a requirement involves distribution, we typically need to fix the relationship between two operations. Distributivity not only reveals structure, but also quickly checks whether an implementation respects mathematical rules. Here we use left distributivity of multiplication over addition.

```mbt check
///|
test "@qc.distributive_left for mul/add" {
  let gen = @qc.triple(
    @qc.int_range(-12, 12),
    @qc.int_range(-12, 12),
    @qc.int_range(-12, 12),
  )
  let prop = @qc.forall(gen, @qc.distributive_left(Int::mul, Int::add))
  @qc.quick_check(prop)
}
```

Beyond algebraic laws, many business requirements amount to “reapplying this operation doesn’t change the result further”. This fits idempotence, common in normalization, denoising, clamping, and similar operations. We first define a simple non-negative clamp and then verify idempotence with `@qc.idempotent`.

```mbt check
///|
fn clamp_nonneg(x : Int) -> Int {
  guard x < 0 else { x }
  0
}

///|
test "@qc.idempotent clamp" {
  let prop = @qc.forall(@qc.int_range(-50, 50), @qc.idempotent(clamp_nonneg))
  @qc.quick_check(prop)
}
```

Another common pattern is “apply an operation twice and return to the original”, i.e. an involution. Many encode/decode, encrypt/decrypt, toggle/restore patterns can be modeled this way. We use negation as the simplest example and express this with `@qc.involutory`.

```mbt check
///|
test "@qc.involutory neg" {
  let prop = @qc.forall(@qc.int_range(-100, 100), @qc.involutory(Int::neg))
  @qc.quick_check(prop)
}
```

When a requirement says “different implementations should yield the same result”, `@qc.ext_equal` gives a direct expression. It does not care about internal algorithms; it only requires both implementations to produce identical outputs for all inputs. This is especially useful for regression tests during refactoring or optimization.

```mbt check
///|
fn double1(x : Int) -> Int {
  x + x
}

///|
fn double2(x : Int) -> Int {
  x * 2
}

///|
test "@qc.ext_equal for double" {
  let prop = @qc.forall(
    @qc.int_range(-100, 100),
    @qc.ext_equal(double1, double2),
  )
  @qc.quick_check(prop)
}
```

Some requirements express invertibility. In that case, we can use `@qc.inverse`. We express invertibility with increment and decrement, verifying this relationship within a controlled range. Note that we again restrict the generator to avoid leaving the semantic precondition domain.

```mbt check
///|
fn inc(x : Int) -> Int {
  x + 1
}

///|
fn dec(x : Int) -> Int {
  x - 1
}

///|
test "@qc.inverse for inc/dec" {
  let prop = @qc.forall(@qc.int_range(-100, 100), @qc.inverse(inc, dec))
  @qc.quick_check(prop)
}
```

These examples show that the key to property design is not “writing more assertions”, but selecting the right structure to express requirements. When we map requirements to algebraic laws or equivalence relations, testing becomes systematic sampling over the input space rather than fragmented example checks.

Also, properties are not “the stronger the better”. Overly strong properties may smuggle in unrealistic assumptions; overly weak properties may fail to constrain the implementation. In practice, properties should be explainable, falsifiable, and traceable back to the requirements text.

#### Common Pitfalls

Algebraic properties are ubiquitous, but not a silver bullet. In practice, watch for:

- **Partial functions**: If a property involves division by zero, out-of-bounds indexing, etc., ensure the generator avoids such inputs, or handle exceptional cases in the property itself.
- **Floating-point numbers**: Precision and special values (NaN, Infinity) can break properties. Avoid direct equality; instead consider an error bound such as ( \mid x - y \mid < \epsilon ).
- **Distribution issues**: Consider whether the generator’s distribution is reasonable. Overly uniform or overly skewed distributions may reduce effective coverage. Later chapters will address this in detail.

### Operational Invariants

This section explains the classic failure mode where “testing axioms only” can lead to false confidence for abstract data types, and how operational invariance tests mitigate this gap. We focus on abstract data types that hide internal representation, where users can only observe behavior through public operations.

As an example, consider a FIFO queue. We specify operation signatures and axioms Q1–Q6, and then present an implementation with an internal invariant.

```mbt check
///|
declare fn empty() -> Queue

///|
declare fn enqueue(x : Int, q : Queue) -> Queue

///|
declare fn is_empty(q : Queue) -> Bool

///|
declare fn front(q : Queue) -> Int

///|
declare fn dequeue(q : Queue) -> Queue
```

Axioms:

- Q1: `is_empty(empty()) == true`
- Q2: `is_empty(enqueue(x, q)) == false`
- Q3: `front(enqueue(x, empty())) == x`
- Q4: `!is_empty(q) => front(enqueue(x, q)) == front(q)`
- Q5: `dequeue(enqueue(x, empty())) == empty()`
- Q6: `!is_empty(q) => dequeue(enqueue(x, q)) == enqueue(x, dequeue(q))`

A very naive testing strategy is to implement `Queue` and test these axioms directly:

```mbt check
///|
/// `gen_queue()` is a generator that produces random Queue instances
test "property Q2" {
  let prop = @qc.forall(@qc.tuple(@qc.small_int(), gen_queue()), fn(p) {
    let (x, q) = p
    is_empty(enqueue(x, q)) == false
  })
  @qc.quick_check(prop)
}
```

These tests can even be written without knowing the internal representation of `Queue`. However, using `==` on `Queue` implies a reasonable `Eq` instance. Suppose the tester writes an appropriate generator `gen_queue` and verifies all six axioms—does that guarantee full correctness? Unfortunately, not necessarily. Consider the following construction:

```mbt check
///|
struct Queue {
  f : @list.List[Int]
  r : @list.List[Int]
} derive(Show)

///|
fn bq(f : @list.List[Int], r : @list.List[Int]) -> Queue {
  match f {
    Empty => { f: r.rev(), r: @list.empty() }
    _ => { f, r }
  }
}

///|
fn enqueue(x : Int, q : Queue) -> Queue {
  bq(q.f, q.r.prepend(x))
}

///|
fn empty() -> Queue {
  bq(@list.empty(), @list.empty())
}

///|
fn is_empty(q : Queue) -> Bool {
  q.f.is_empty()
}

///|
fn front(q : Queue) -> Int {
  q.f.unsafe_last()
}

///|
fn dequeue(q : Queue) -> Queue {
  let { f, r } = q
  bq(f.unsafe_tail(), r)
}
```

Readers familiar with the algorithm will notice that `front` is incorrect: it takes the _last_ element of `f` rather than the head. Now define `==` as follows:

```mbt check
///|
impl Eq for Queue with equal(self, other) {
  let to_list = (q : Queue) => q.f.concat(q.r.rev())
  to_list(self) == to_list(other)
}
```

Along with:

```mbt check
///|
fn q1() -> Bool {
  is_empty(empty()) == true
}

///|
fn q2(xq : (Int, Queue)) -> Bool {
  let (x, q) = xq
  is_empty(enqueue(x, q)) == false
}

///|
fn q3(x : Int) -> Bool {
  front(enqueue(x, empty())) == x
}

///|
fn q4(xq : (Int, Queue)) -> Bool {
  let (x, q) = xq
  guard !is_empty(q) else { true }
  front(enqueue(x, q)) == front(q)
}

///|
fn q5(x : Int) -> Bool {
  dequeue(enqueue(x, empty())) == empty()
}

///|
fn q6(xq : (Int, Queue)) -> Bool {
  let (x, q) = xq
  guard !is_empty(q) else { true }
  dequeue(enqueue(x, q)) == enqueue(x, dequeue(q))
}
```

Because `==` is defined as “convert to lists and compare”—i.e. a form of **semantic equality**—the axioms Q1–Q6 will hold. This can be validated with:

```mbt check
///|
fn gen_int_list() -> @qc.Gen[@list.List[Int]] {
  @qc.sized(fn(n) { @qc.list_with_size(n, @qc.small_int()) })
}

///|
fn gen_queue() -> @qc.Gen[Queue] {
  let gl = gen_int_list()
  gl.bind(fn(f) { gl.bind(fn(r) { @qc.pure(bq(f, r)) }) })
}

///|
test "queue axioms q1-q6" {
  let gen_xq = @qc.tuple(@qc.small_int(), gen_queue())
  let gen_x = @qc.small_int()
  @qc.quick_check(q1())
  @qc.quick_check(@qc.forall(gen_xq, q2))
  @qc.quick_check(@qc.forall(gen_x, q3))
  @qc.quick_check(@qc.forall(gen_xq, q4))
  @qc.quick_check(@qc.forall(gen_x, q5))
  @qc.quick_check(@qc.forall(gen_xq, q6))
}
```

In a randomized sense, the tests above will “all pass”, because they constrain only the behavior of `==` over equivalence classes—and that equality happens to be consistent with the faulty implementation. Semantically, the issue is visible: for a FIFO queue, enqueueing 1, 2, 3 and then dequeuing should yield a front element of 2. But the buggy implementation returns 3 because `front` takes the tail element.

This shows that relying solely on axiom properties is not equivalent to verifying correct **observable behavior**.

The reason is that in equational reasoning over axioms, we implicitly assume that operations are **congruent** with respect to equality; the tests checked only the axioms, not this hidden assumption. Fundamentally, this is a mismatch between **observational equivalence** and **program equivalence**. Users can observe behavior only through public operations. Therefore, when two values are considered equivalent under `==`, we expect any observation operation to produce equivalent results. If this fails, then the external behavior has deviated from the specification, even if the base axioms remain true.

To mitigate this, we introduce **operational invariance** testing: when two values are equivalent under `==`, any observation operation should also yield equivalent results. Testing this directly with random `q` and `q'` often fails due to the scarcity of equivalent pairs. Therefore, we construct a generator for equivalence pairs (`@qc.Equivalence`) and define a compatibility property on top of it:

```mbt check
///|
fn from_list(xs : @list.List[Int]) -> @qc.Gen[Queue] {
  let len = xs.length()
  let gen_i = if len <= 0 { @qc.pure(0) } else { @qc.int_range(0, len + 1) }
  gen_i.fmap(fn(i) {
    let xs1 = xs.take(i)
    let xs2 = xs.drop(i)
    bq(xs1, xs2.rev())
  })
}

///|
fn gen_equiv_queue() -> @qc.Gen[@qc.Equivalence[Queue]] {
  gen_int_list().bind(fn(z) {
    from_list(z).bind(fn(x) { from_list(z).fmap(fn(y) { { lhs: x, rhs: y } }) })
  })
}

///|
test "queue invariance" {
  let prop = @qc.forall(gen_equiv_queue(), eqv => {
    let { lhs, rhs } = eqv
    guard !is_empty(lhs) else { true }
    front(lhs) == front(rhs)
  })
  @qc.quick_check(prop, expect=@qc.Expected::Fail)
}
```

Such tests more directly expose the incorrect `front` implementation. However, they also reveal a practical constraint: generating equivalent pairs depends on knowing how to “perturb” the internal representation, which is typically not available to users. In other words, it relies on a deep understanding of the representation and the ability to construct equivalence pairs. Even worse, if the equivalence-pair generator is too conservative, the test may still produce a misleading “all passed” result. We therefore need a more systematic, more automated mechanism.

To that end, we propose a second approach: systematically deriving tests through **single-step axiom rewriting**. Concretely, we take the left and right sides of an axiom and substitute them into a chosen operation’s argument position; we fill the remaining arguments with random values; and when necessary, we add preconditions—thus obtaining an executable family of operational invariance properties. This approach sacrifices completeness but substantially reduces generation complexity and test cost.

The key observation is: if we want `==` to be a congruence for all operations, in principle we want to verify that for every operation `f`:

[
t \equiv t' \implies f(\ldots, t, \ldots) \equiv f(\ldots, t', \ldots)
]

The difficulty is that it is hard to generate sufficiently rich equivalence pairs (t \equiv t'). But notice: if the property truly fails, then along any rewrite sequence from (t) to (t'), there must exist some step—some **single axiom application**—that already causes the outer operation’s results to differ. Otherwise, if all intermediate results were equal, transitivity would imply the final results are also equal, contradicting the failure.

Therefore, our eventual testing strategy is: for a chosen operation `f`, an argument position `i`, and an axiom `lhs = rhs`, we construct the property:

[
f(x_1, \cdots, \text{lhs}(y_1,\cdots, y_m), \cdots, x_n) = f(x_1, \cdots, \text{rhs}(y_1,\cdots, y_m), \cdots, x_n)
]

- (y_j) are variables appearing in the axiom; we can generate random values for them.
- (x_k) are the variables for other argument positions of `f`; we fill them with random values and keep them identical on both sides, because we only care about the substitution effect between `lhs` and `rhs`.

```mbt check
///|
fn enqueue_1_q3(xq : (Int, Queue)) -> Bool {
  let (x, q) = xq
  let lhs = front(enqueue(x, empty()))
  let rhs = x
  enqueue(lhs, q) == enqueue(rhs, q)
}

///|
fn enqueue_1_q4(xqp : (Int, Queue, Queue)) -> Bool {
  let (x, q, p) = xqp
  guard !is_empty(q) else { true }
  let lhs = front(enqueue(x, q))
  let rhs = front(q)
  enqueue(lhs, p) == enqueue(rhs, p)
}

///|
fn front_1_q6(xq : (Int, Queue)) -> Bool {
  let (x, q) = xq
  guard !is_empty(q) else { true }
  let lhs = dequeue(enqueue(x, q))
  let rhs = enqueue(x, dequeue(q))
  front(lhs) == front(rhs)
}

///|
test "operation invariance tests" {
  let gen_xq = @qc.tuple(@qc.small_int(), gen_queue())
  let gen_xqp = @qc.triple(@qc.small_int(), gen_queue(), gen_queue())
  @qc.quick_check(@qc.forall(gen_xq, enqueue_1_q3))
  @qc.quick_check(@qc.forall(gen_xqp, enqueue_1_q4))
  @qc.quick_check(@qc.forall(gen_xq, front_1_q6), expect=Fail)
}
```

These function names follow a consistent convention that clearly identifies the “operation position + axiom number” combination. For example, `enqueue_1_q3` means substituting the left/right sides of axiom Q3 into the first argument position of `enqueue`; `front_1_q6` means substituting the two sides of Q6 into `front`’s sole argument position (1). We can treat them as the target shape for “systematically generated tests”: each test revolves around a local equivalence substitution rather than enumerating full equivalence pairs, shifting the difficulty from “generating equivalent inputs” to “generating random parameters under usable preconditions”. This test suite successfully detects the error in `front`.

We can see the core value of operational invariance testing: it can provide stronger guarantees at the level of “observational consistency over equivalent inputs” without requiring the tester to understand internal representations. The method is not theoretically complete, because it considers only single-step axiom rewrites rather than arbitrary-depth nested rewrites. In engineering practice, however, this tradeoff substantially reduces cost and, in the queue example, successfully exposes the defect in `front`.

### Model-Based Testing

Model-based testing is closer to a semantics-driven specification approach: you first write a simpler, more trustworthy reference model (the model/specification), then assert that the real implementation (the system under test, SUT) matches the model in observable behavior.

Rather than testing a complex system directly, you equip it with a “shadow world” that can be enumerated, reasoned about, and explained. When the SUT fails, the model often tells you not only that something is wrong, but what the semantic mistake is.

#### When to Use a Model

- The SUT has complex state (caches, connection pools, concurrent queues, LRU, indices, etc.), making equational laws difficult to write directly.
- You have a naive but trustworthy version (slower, based on lists/Maps, or even a direct specification).
  - For example, you can test a more complex quicksort against a trusted bubble sort.
  - Or when porting software to MoonBit, you can use the original implementation as a model.
  - In compiler construction, an “interpreter as model” is common: test that “compile + run” matches the interpreter.

#### A Set Model

Set is one of the most common data types. It naturally expresses “unordered, no duplicates” semantics. Suppose we implement a set type and want to validate insertion and deletion. A common approach is to use a **list** as the model: lists make insertion/removal easy, and we can simulate set behavior by sorting and deduplicating.

```mbt check
///|
struct ModelSet[T](@list.List[T])

///|
fn[T] ModelSet::empty() -> ModelSet[T] {
  ModelSet(@list.empty())
}

///|
fn[T : Eq] ModelSet::contains(self : ModelSet[T], x : T) -> Bool {
  self.0.contains(x)
}

///|
fn[T : Eq] ModelSet::insert(self : ModelSet[T], x : T) -> ModelSet[T] {
  guard not(self.contains(x)) else { self }
  self.0.prepend(x)
}

///|
fn[T : Eq] ModelSet::remove(self : ModelSet[T], x : T) -> ModelSet[T] {
  ModelSet(self.0.filter(fn(y) { y != x }))
}
```

Next we define a set of commands representing an operation sequence on the set:

```mbt check
///|
enum Cmd {
  Insert(Int)
  Remove(Int)
  Contains(Int)
} derive(Show, @coreqc.Arbitrary)

///|
struct Trace(@list.List[Bool]) derive(Eq) // records results of contains
```

We then execute the command sequence on the model:

```mbt check
///|
pub fn run_model(cmds : @list.List[Cmd]) -> (ModelSet[Int], Trace) {
  let step = (str : (ModelSet[Int], Trace), cmd : Cmd) => {
    let (st, tr) = str
    match cmd {
      Insert(x) => (st.insert(x), tr)
      Remove(x) => (st.remove(x), tr)
      Contains(x) => (st, Trace(tr.0.prepend(st.contains(x))))
    }
  }
  @list.List::fold(cmds, init=(ModelSet::empty(), Trace(@list.empty())), step)
}
```

We run the same command sequence on the SUTSet and compare final state and trace:

```mbt check
///|
type SUTSet[T] = @immut/sorted_set.SortedSet[T] // assume this is the complex implementation under test

///|
pub fn run_sut(cmds : @list.List[Cmd]) -> (SUTSet[Int], Trace) {
  let step = (str : (SUTSet[Int], Trace), cmd : Cmd) => {
    let (st, tr) = str
    match cmd {
      Insert(x) => (st.add(x), tr)
      Remove(x) => (st.remove(x), tr)
      Contains(x) => (st, Trace(tr.0.prepend(st.contains(x))))
    }
  }
  @list.List::fold(cmds, init=(SUTSet::new(), Trace(@list.empty())), step)
}

///|
test "model-based testing for Set" {
  let gen = @qc.list_with_size(20, @qc.Gen::spawn())
  let prop = @qc.forall(gen, fn(cmds) {
    let (model_set, model_trace) = run_model(cmds)
    let (sut_set, sut_trace) = run_sut(cmds)
    let model_set_arr = model_set.0.sort()
    let sut_set = @list.from_array(sut_set.to_array())
    model_trace == sut_trace && model_set_arr == sut_set
  })
  @qc.quick_check(prop)
}
```

Note that we also account for the internal ordering behavior of `SortedSet`: we compare query results via `Trace`, and we also compare the final contents to ensure they are consistent and ordered. This dual verification helps ensure the SUT matches the model across all operations.

> The above covers only a particularly simple case. In practice, models can be more complex. In programming language design and implementation, a common pattern is “interpreter + compiler”: the interpreter (often implemented as an abstract machine) directly executes source code, while the compiler translates source code into target code and runs it. One can use the interpreter as a model to verify that compiled code behaves identically for all inputs. In such cases, however, input generation is nontrivial; interested readers may consult the program synthesis literature.
