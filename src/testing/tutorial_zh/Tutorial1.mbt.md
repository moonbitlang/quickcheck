# Quick Check 教程 Part 1

这是一个长系列，目标是系统介绍 MoonBit 中的 QuickCheck 框架及其在工程实践中的应用，
向广大开发者介绍「基于属性的测试设计」理念与方法论。
整个系列将分为 3 个大部分，第一部分，也就是本文，
关注 QuickCheck 的核心概念和『属性』的设计方法论，
后面部分将介绍生成器的高级设计与缩减策略和统计分布控制等技巧。

## 基本概念解释

本章旨在建立我们对「性质测试」的直观理解，我们不急着讨论复杂生成器或者属性，
而是从最直观的角度确认 QuickCheck 在 MoonBit 中到底验证了什么。
这里的性质 (property) 不是一组样例，而是一段描述规则的程序，
它会被反复运行在大量随机数据上（在程序上可以体现为一个函数或者一个可执行的表达式），
从而让我们以更低成本覆盖更大行为空间。

当我们把一个性质交给 QuickCheck 时，框架需要先判断它是不是可执行的，为此 QuickCheck 提供了 Testable
这一抽象，它能把 Bool、Function、甚至 Generator 统一成可运行的 Property。换句话说，我们写的不一定是
「测试」，而是一个能被转译成测试流程的值，这个值会被运行、统计、收集并最终给出结论。

```mbt nocheck
fn[P : @qc.Testable] @qc.quick_check(prop : P, max_success? : Int, ...) -> Unit raise Failure
```

上面的函数签名展示了 QuickCheck 的核心入口 `@qc.quick_check`。它接受一个 Testable 值，将其转成 Property 并运行测试。`max_success` 参数控制测试样例数量，默认值为 100。若性质在所有样例上成立，测试通过；否则抛出 Failure 并打印反例，当然它不止 `max_success` 这个可配置参数，之后的章节中，我们将按需引入不同的配置项。

```mbt check
///|
test "@qc.quick_check minimal" {
  @qc.quick_check(true)
}
```

这个最小示例几乎没有任何信息，却能帮助我们准确把握接口形态。
`@qc.quick_check` 接受任何 Testable 值，
因此布尔值也可以直接作为性质 (因为它实现了这个 trait)，
若为 `false` 就会失败。这样的调用虽然极简，但清晰揭示了
QuickCheck 的入口语义，即它只关心「这段可执行的性质最终是否成立」。

当性质是一个函数时，最便捷的入口是 `@qc.quick_check_fn`。
它要求函数的参数类型具备 `Arbitrary`、`Shrink` 与 `Show` 能力，
从而能自动生成测试数据、缩减反例并打印失败样本，在后面我们会更多解释这些 trait 的含义，
但现在你只需要知道对于标准库的基础类型，QuickCheck 都实现了这些 trait。
我们可以把它理解为「我们提供规则，系统替我们提供数据」的测试模式，在简单模型上非常高效。
下面的例子也很简单，验证了「整数加零不变」的性质，生成器会从小到大生成 100 个整数样例并运行该性质，
并检查结果是否全部为真，如果是，则测试通过，否则打印出第一个失败的样例。

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

实际业务函数往往是多参的，而 property 又只能接收一个参数，因此我们用元组把多个输入打包起来。
这不是权宜之计，而是语言层面的标准做法，它让 QuickCheck 仍然保持「单参性质」的统一执行流程，
同时也便于缩减时生成更小的反例组合。

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

当我们需要主动决定数据分布时，或者 Arbitrary 实例并不适用时，
就需要显式生成器，这个入口是 `@qc.forall`。`@qc.forall` 的含义是「对生成器给出的每一个值，
都让性质成立」，它把生成器与性质函数粘合成 Property，是后续复杂设计的基础。
在这里我们先给出一个小范围的整数生成器，让性质更容易直观地理解。

```mbt check
///|
test "@qc.forall with @qc.int_range" {
  let gen = @qc.int_range(-10, 10)
  let prop = @qc.forall(gen, fn(x) { x + 1 > x })
  @qc.quick_check(prop)
}
```

生成器并非神秘黑箱，它是一个由 size 与随机种子驱动的确定性函数。
虽然 `@qc.quick_check` 会帮我们自动管理这些参数，但在设计性质时，
我们仍然可以用 `@qc.Gen::sample` 先窥视生成器的行为，帮助我们校准
数据分布是否符合预期。

```mbt check
///|
test "peek generator" {
  let gen = @qc.int_range(-3, 3)
  inspect(gen.sample(size=5, seed=1), content="-2")
}
```

在这里我们可以讨论一些 QuickCheck 内部的结构细节：

> 
> 从执行流程上看，Testable 会被转成 Property，Property 内部再被展开成可遍历的测试树，QuickCheck
> 沿着这棵树运行、记录、缩减并最终决定结果。我们暂时不需要理解这些结构细节，但要清楚性质是「可执行」
> 的对象，而不是静态文档，这一层理解会决定我们之后如何组织属性与生成器。
> 
> 当然读者无需担心这些细节会妨碍我们使用 QuickCheck，框架已经帮我们封装好了这些复杂性，
> 我们只需专注于「写性质」与「选生成器」即可。

失败的处理也是接口语义的一部分，`@qc.quick_check` 会在性质失败时抛出 Failure 并打印反例，而
`@qc.quick_check_silence` 则返回一段报告字符串，方便我们在工具链中做二次处理。理解这一点有助于我们在
调试和持续集成中选择合适的入口。

```mbt check
///|
test "@qc.quick_check_silence" {
  let prop = @qc.forall(@qc.int_range(0, 5), fn(x) { x >= 0 })
  inspect(@qc.quick_check_silence(prop), content="+++ [100/0/100] Ok, passed!")
}
```

到这里我们已经能把一个直观规则写成可运行的性质，并通过默认生成器或显式生成器运行它。我们会发现
QuickCheck 并不要求我们先理解复杂的缩减细节，而是提供了一条从「规则」到「执行」的清晰通路，
这也是 property-based testing 真正降低测试成本的原因。

## Property 设计导论

本章关注如何从需求/代码中抽取可验证的性质，我们不急于讨论复杂生成器，
而是把注意力放在「关系」与「不变量」上。
需求常以自然语言或数学公司表达，它蕴含了不变量与代数规律，
我们要做的就是把这些规律转化为可执行的 property，
并让随机测试去检验它们是否稳定成立。

### 代数性质

在性质测试中，最可靠的起点是「关系式」，它描述输入与输出之间应当长期成立的约束。相比样例断言，
关系式具有普适性，能够覆盖更大范围的输入组合。我们可以把「应该相等」、「应当保持顺序」或
「重复应用后不再变化」这样的语义转化为函数层面的规律，并将其交给 QuickCheck 执行。

QuickCheck 收集了常见的代数规律作为内置性质，这些规律直接对应了需求中常见的模式。例如，
当需求暗含交换性时，我们可以直接采用 `@qc.commutative` 来表达等式关系。这里我们用整数加法作为示例，
并限制输入范围以避免溢出干扰性质本身。这样的范围设置不是削弱测试，而是帮助我们聚焦在需求语义上。

```mbt check
///|
test "@qc.commutative for add" {
  let gen = @qc.tuple(@qc.int_range(-200, 200), @qc.int_range(-200, 200))
  let prop = @qc.forall(gen, @qc.commutative(fn(a, b) { a + b }))
  @qc.quick_check(prop)
}
```

需求中常见的「合并不依赖分组方式」可以用结合律表达，这类规律尤其适用于聚合、拼接、合并等函数。
我们借助 `@qc.associative` 直接表达结合律，并用三元组生成器将多参输入统一为单参性质。

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

当需求包含「分配」的语义时，我们通常需要把两个运算的关系固定下来。分配律不仅揭示了运算组合的结构，
也能快速检验实现是否正确地遵守数学规则。我们在这里选用乘法对加法的左分配律来表达这一类需求。

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

除了代数律，很多业务需求本质上是「重复应用不会继续改变结果」。这类需求适合用幂等性刻画，
如归一化、去噪、裁剪等操作。我们可以先写出一个简单的非负裁剪函数，再用 `@qc.idempotent` 验证其性质。

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

另一个常见模式是「反演回到原处」，也就是自反或对合性质。许多编码与解码、加密与解密、开关与还原
都可以用这一结构来建模。我们在此用取负作为最简示例，并用 `@qc.involutory` 表达「再应用一次即可回原值」。

```mbt check
///|
test "@qc.involutory neg" {
  let prop = @qc.forall(@qc.int_range(-100, 100), @qc.involutory(Int::neg))
  @qc.quick_check(prop)
}
```

当需求描述的是「不同实现应给出相同结果」时，`@qc.ext_equal` 是更直接的表达。它并不关心内部算法，
而只要求两个实现对所有输入给出相同输出，这一点非常适合重构或优化后的回归验证。

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

有些需求体现的是「可逆」的含义，这时我们也可以用 `@qc.inverse` 来描述它。我们通过一个增量和减量函数
来表达可逆性，并在受控的输入范围内验证这一关系。注意这里我们仍用生成器限制输入，避免超出语义前提。

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

从这些例子可以看到，性质设计的关键并不在于「写更多断言」，而在于选择正确的结构来表达需求。
当我们将需求映射为代数规律或等价关系时，测试就不再是碎片化的样例，而是对整个输入空间的系统抽样。
此外，性质并非越强越好。过强的性质可能隐含不真实的假设，过弱的性质又难以约束实现。
因此我们在设计时需要让性质可解释、可证伪，同时尽量与需求文本保持可追溯的对应关系。

#### 易错点

代数性质很常见，但它并非银弹，在设计时更需注意以下易错点：

- **部分函数**：当性质涉及除零、下标越界等部分函数时，需确保生成器避免这些输入，或在性质中处理异常情况。
- **浮点数**：浮点数的精度与特殊值（NaN、Infinity）可能导致性质失效，需谨慎设计生成器与性质逻辑，并且不应该
  直接用等式比较浮点数，考虑误差界 $\mid x - y \mid < \epsilon$。
- **分布问题**：性质设计时需考虑生成器的分布是否合理，过于均匀或偏态的分布可能导致测试覆盖不足，
  在后面的生成器章节我们将详细讨论这一点。

### 操作不变量

本节讨论为何「仅测试公理」在抽象数据类型的语境中可能产生误判的经典情况，
以及如何通过操作不变性测试来弥补这一缺口。我们尤其关注那些隐藏了内部表示的抽象数据类型，
用户只能通过公开操作观察行为。
举个例子，我们考虑 FIFO 队列，给出操作签名与公理 Q1–Q6，并展示了一个具有内部不变量的实现。

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

公理：

- Q1: `is_empty(empty()) == true`
- Q2: `is_empty(enqueue(x, q)) == false`
- Q3: `front(enqueue(x, empty())) == x`
- Q4: `!is_empty(q) => front(enqueue(x, q)) == front(q)`
- Q5: `dequeue(enqueue(x, empty())) == empty()`
- Q6: `!is_empty(q) => dequeue(enqueue(x, q)) == enqueue(x, dequeue(q))`

一个很天真的测试方法就是写好 Queue 之后我们直接使用这组签名进行测试：

```mbt check
///|
/// `gen_queue()` 是一个生成随机 Queue 实例的生成器
test "property Q2" {
  let prop = @qc.forall(@qc.tuple(@qc.small_int(), gen_queue()), fn(p) {
    let (x, q) = p
    is_empty(enqueue(x, q)) == false
  })
  @qc.quick_check(prop)
}
```

这些测试甚至可以在用户对 Queue 内部实现一无所知的情况下写出。
然而，在 Queue 上使用 `==` 蕴涵了一个合理 Eq 的假设。
假设测试者写出了合适的生成器 `gen_queue` 并且完成了上面 6 个性质的测试，
这是否能保证 Queue 的实现是完全正确的呢？很遗憾这并不一定。
下面我们考虑如下构造：

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

熟悉算法的读者可以注意到这里的 `front` 实现是错误的：它取了 `f` 的尾部而非头部。
接下来我们再给 `==` 给出定义：

```mbt check
///|
impl Eq for Queue with equal(self, other) {
  let to_list = (q : Queue) => q.f.concat(q.r.rev())
  to_list(self) == to_list(other)
}

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

由于 `==` 被定义为「转换为列表再比较」，也就是一种「语义相等」，
所以 Q1 ~ Q6 公理性质会成立，可以使用下面代码验证之：

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

上面的测试在随机意义上会「全部通过」，因为它们只约束 `==` 的等价类行为，而该等价恰好
与错误实现保持一致。我们可以在语义层面看出问题：对于 FIFO 队列，连续入队 1、2、3 后再出队，
前端元素应当是 2，但错误实现因为把 `front` 写成取尾部而返回 3。由此可见，仅依赖公理性质并不
等价于验证了「可观察行为」的正确性。

这是因为我们在用公理做等式推理时，
隐含假设了操作对相等是**同余**；而测试只测了公理，没有测这个隐含假设。
这一问题本质上是「可观察等价」与「程序等价」之间的错位。
用户只能通过公开操作观察行为，因此当两个
值在 `==` 意义下被视为等价时，我们期待任何观察操作都给出等价结果。
若这一点不成立，则实现对外行为已经偏离规范，即便所有基本公理仍然为真。

为弥补上述不足，我们引入「操作不变性」测试，即当两个值在 `==` 意义下等价时，任何观察操作的结果
也应当等价。直接用随机 `q` 与 `q1` 测试这一点往往会失败于「等价样本稀少」，
因此我们考虑等价对的生成器（`@qc.Equivalence`），
并在此基础上定义兼容性性质：

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
  @qc.quick_check(prop, expect=Fail)
}
```

这类测试能够更直接地暴露 `front` 的实现错误，但同时也显露出一个现实约束：等价对的生成依赖于对
内部表示的「扰动方式」，而这通常不由使用者掌握，换句话说，它依赖于对内部表示的深入理解与等价对的构造能力。
甚至如果等价对生成器写得过于保守，测试仍可能给出「全部通过」的假象。因此我们需要一种更系统、更自动化的生成机制。

为此，我们进一步提出第二条路径，
通过「单步公理重写」来系统派生测试。具体做法是把某条公理的左、右两侧分别代入
某个操作的某个参数位置，其余参数用随机值填充，并在必要时补充前置条件，从而获得可执行的操作不变性
性质集合。该方法牺牲了完备性，却显著降低了生成难度与测试成本。

这个方法的核心观察是，若要验证 `==` 对所有操作是同余的，原则上我们是想要验证对于每个操作 `f` 我们有：

$$
t \equiv t' \implies f(\ldots, t, \ldots) \equiv f(\ldots, t', \ldots)
$$

不过问题是我们很难生成足够好的等价对 `t ≡ t'`。我们可以注意到：
只要这个属性真的会失败，那么沿着从 `t` 到 `t'` 的重写序列，
总存在某一步「单次公理应用」已经导致外层操作结果不同
（否则全链条都相等，靠传递性会推出最终也相等，导致矛盾）。

所以我们最终的测试方案是：对于某个我们期望测试的操作 `f` 和一个参数位置 `i`，以及公理 `lhs = rhs`，
我们可以构造如下性质：

$$
f(x_1, \cdots, \text{lhs}(y_1,\cdots, y_m), \cdots, x_n) = f(x_1, \cdots, \text{rhs}(y_1,\cdots, y_m), \cdots, x_n)
$$

- $y_j$ 是公理中出现的变量，我们可以简单生成它们的随机值
- $x_k$ 是操作 `f` 中其他参数位置的变量，可以用简单随机值填充，并且左右两边保持一致，因为我们只关心 `lhs` 和 `rhs` 的替换效果

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

这些函数名称与约定一致，明确标识了「操作位置 + 公理编号」的组合，例如 `enqueue_1_q3`
表示把公理 Q3 的左右项分别代入 `enqueue` 的第一个参数位置；`front_1_q6` 则表示把 Q6 的左右项
代入 `front` 的唯一参数位置 (1)。我们可以将它们视为「系统自动生成测试」的目标形态：
每条测试都围绕一个局部等价替换展开，而不是试图枚举完整的等价对，
从而把难度从「生成等价输入」转化为「生成可用前置条件的随机参数」。
现在，这个测试能够成功捕获 `front` 实现中的错误。

我们可以看到操作不变性测试的核心价值在于：它并不要求测试者了解实现内部结构，
却能在「等价输入的观察一致性」这一层面提供更强的保障。该方法在理论上并不完备，
因为它只考虑单步公理重写而非任意深度的嵌套重写，
但在工程实践中，这种权衡显著降低了测试成本，
并在队列示例中成功暴露了 `front` 的实现缺陷。

### 模型对照

那么模型对照（model-based testing）则更像是「从语义出发」的规格：
你先写一个更简单、更可信的参考模型（model/specification），再声
明真实实现（system under test, SUT）在可观察行为上与模型一致。
不要直接测试复杂系统本身，而是给它配一个可以被穷举/推理/解释的影子世界。
当 SUT 失败时，模型往往不仅告诉你错了，还告诉你具体的语义错误。

#### 何时使用 Model ?

- SUT 具有复杂状态（缓存、连接池、并发队列、LRU、索引等），直接写等式规律很难。
- 你有一个朴素但可信的版本（慢一点、用列表/Map 表示、甚至直接用规范描述）
  - 例如说我们有一个朴素的冒泡排序实现，可以用来测试更复杂的快速排序
  - 或者我们在搬运软件到 MoonBit 中时，可以用原有实现作为模型
  - 编译器设计也可以用「解释器」作为模型，测试「编译 + 运行」的结果

#### Set 模型

集合（Set）是最常见的数据类型之一。它能自然表达「无序且不重复」的语义，
假设我们实现了一个简单的集合类型，现在我们想要分析它是否正确地实现了插入与删除操作。
可以考虑用**列表**作为模型，列表天然支持插入与删除，并且我们可以通过排序与去重来模拟集合的行为。

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

接下来我们定义一组命令，表示对集合的操作序列：

```mbt check
///|
enum Cmd {
  Insert(Int)
  Remove(Int)
  Contains(Int)
} derive(Show, @coreqc.Arbitrary)

///|
struct Trace(@list.List[Bool]) derive(Eq) // 记录 contains 的结果

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

对应的 SUTSet 上会运行同样的命令序列，然后我们对比两者的最终状态与 Trace 结果是否一致：

```mbt check
///|
type SUTSet[T] = @immut/sorted_set.SortedSet[T] // 假设这是我们要测试的复杂实现

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

注意到此处我们此处还考虑了 `SortedSet` 内部的排序行为，不仅通过 Trace 对比查询结果，
还对比了最终集合的内容是否一致且有序，这种双重验证确保了 SUT 在所有操作后都与模型的一致性。

> 上面仅提到了尤其简单的一种情况，实际中模型可以更复杂，在编程语言的设计与实现中我们也常见
> 一种「解释器 + 编译器」的组合测试模式。其中解释器由「抽象机」实现，直接执行源代码，
> 编译器则把源代码翻译为目标代码并运行。我们可以用解释器作为模型，验证编译器生成的代码在所有输入下与解释器行为一致。
> 不过在这种情况下，设计输入生成并非易事，感兴趣的读者可以考虑查阅 program synthesis 相关文献。
