# Quick Check Property 设计教程

本文面向工程实践与可维护性目标，系统性阐述如何在 MoonBit 中将需求规格转译为可执行的
QuickCheck property，并以生成器设计、规模控制、缩减机制与分类标注为核心手段建立可重复、
可诊断、可演化的性质测试流程。文中强调从语义约束到代数规律的抽取方法，说明如何利用分布建模
与组合生成器覆盖典型路径与边界场景，并在失败时以最小反例与结构化上下文提升问题定位效率。
全文以教程式推进，逐步连接概念、接口与工程实践，力求在有限测试预算下获得更高的缺陷发现率与
更稳定的回归保障。

## 基本概念解释

本章旨在建立我们对「性质测试」的统一理解，不急着讨论复杂生成器或者属性 ，而是从最直观的角度
确认 QuickCheck 在 MoonBit 中到底验证了什么。这里的 property 不是一组样例，而是一段描述规则的程序，
它会被反复运行在大量随机数据上，从而让我们以更低成本覆盖更大行为空间。

当我们把一个性质交给 QuickCheck 时，框架需要先判断它是不是可执行的，为此 QuickCheck 提供了 Testable
这一抽象，它能把 Bool、Function、甚至 Generator 统一成可运行的 Property。换句话说，我们写的不一定是
「测试」，而是一个能被转译成测试流程的值，这个值会被运行、统计、收集并最终给出结论。

```mbt nocheck
fn[P : @qc.Testable] @qc.quick_check(prop : P, max_shrink? : Int, ...) -> Unit raise Failure
```

上面的函数签名展示了 QuickCheck 的核心入口 `@qc.quick_check`。它接受一个 Testable 值，将其转成 Property 并运行测试。`max_shrink` 参数控制缩减的最大步数，防止缩减过程过长。若性质失败，函数会抛出 Failure 异常，并打印失败样本。

```mbt check
///|
test "@qc.quick_check minimal" {
  @qc.quick_check(true)
}
```

这个最小示例几乎没有业务信息，却能帮助我们准确把握接口形态。`@qc.quick_check` 接受任何 Testable 值，
因此布尔值也可以直接作为性质，若为 false 就会失败。这样的调用虽然极简，但清晰揭示了
QuickCheck 的入口语义，即它只关心「这段可执行的性质最终是否成立」。

当性质来自一个函数时，最便捷的入口是 `@qc.quick_check_fn`。它要求输入类型具备 `Arbitrary`、`Shrink`
与 `Show` 能力，从而能自动生成测试数据、缩减反例并打印失败样本。我们可以把它理解为「我们提供规则，
系统替我们提供数据」的默认模式，在简单模型上非常高效。

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
这不是权宜之计，而是语言层面的标准做法，它让 QuickCheck 仍然保持「单参性质」的统一执行流程，同时
也便于缩减时生成更小的反例组合。

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

当我们需要主动决定数据分布时，就需要显式生成器，这个入口是 `@qc.forall`。`@qc.forall` 的含义是「对生成器给出的每一个值，都让性质成立」，它把生成器与性质函数粘合成 Property，是后续复杂设计的基础。
在这里我们先给出一个小范围的整数生成器，让性质更容易直观地理解。

```mbt check
///|
test "@qc.forall with @qc.int_range" {
  let gen = @qc.int_range(-10, 10)
  let prop = @qc.forall(gen, fn(x) { x + 1 > x })
  @qc.quick_check(prop)
}
```

生成器并非神秘黑箱，它是一个由 size 与随机种子驱动的确定性函数。虽然 `@qc.quick_check` 会帮我们
自动管理这些参数，但在设计性质时，我们仍然可以用 `@qc.Gen::sample` 先窥视生成器的行为，帮助我们校准
数据分布是否符合预期。

```mbt check
///|
test "peek generator" {
  let gen = @qc.int_range(-3, 3)
  inspect(gen.sample(size=5, seed=1), content="-2")
}
```

从执行流程上看，Testable 会被转成 Property，Property 内部再被展开成可遍历的测试树，QuickCheck
沿着这棵树运行、记录、缩减并最终决定结果。我们暂时不需要理解这些结构细节，但要清楚性质是「可执行」
的对象，而不是静态文档，这一层理解会决定我们之后如何组织属性与生成器。

失败的处理也是接口语义的一部分，`@qc.quick_check` 会在性质失败时抛出 Failure 并打印反例，而
`@qc.quick_check_silence` 则返回一段报告字符串，方便我们在工具链中做二次处理。理解这一点有助于我们在
调试和持续集成中选择合适的入口。

```mbt check
///|
test "@qc.quick_check_silence" {
  let prop = @qc.forall(@qc.int_range(0, 5), fn(x) { x >= 0 })
  let _ : String = @qc.quick_check_silence(prop)

}
```

到这里我们已经能把一个直观规则写成可运行的性质，并通过默认生成器或显式生成器运行它。我们会发现
QuickCheck 并不要求我们先理解复杂的缩减细节，而是提供了一条从「规则」到「执行」的清晰通路，
这也是 property-based testing 真正降低测试成本的原因。

接下来的章节我们会逐步打开这一通路的更深层结构，例如如何让生成器分布贴近现实、如何设计缩减以得到
更小反例、如何用分类与标签让失败更具可读性。但无论走到哪一步，我们都可以回到本章的心智模型，
把性质理解成一个可执行的规则，并以此验证我们写下的每一条设计。

## Property 设计导论

本章关注如何从需求文本中抽取可验证的性质，我们不急于讨论复杂生成器，而是把注意力放在
「关系」与「不变量」上。需求常以自然语言表达，它隐藏了不变量与代数规律，我们要做的就是把这些规律
转化为可执行的 property，并让随机测试去检验它们是否稳定成立。

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
  let prop = @qc.forall(gen, @qc.associative(fn(a, b) { a + b }))
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
  let prop = @qc.forall(
    gen,
    @qc.distributive_left(fn(a, b) { a * b }, fn(a, b) { a + b }),
  )
  @qc.quick_check(prop)
}
```

除了代数律，很多业务需求本质上是「重复应用不会继续改变结果」。这类需求适合用幂等性刻画，
如归一化、去噪、裁剪等操作。我们可以先写出一个简单的非负裁剪函数，再用 `@qc.idempotent` 验证其性质。

```mbt check
///|
fn clamp_nonneg(x : Int) -> Int {
  if x < 0 {
    0
  } else {
    x
  }
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
fn neg(x : Int) -> Int {
  -x
}

///|
test "@qc.involutory neg" {
  let prop = @qc.forall(@qc.int_range(-100, 100), @qc.involutory(neg))
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

集合（Set）是最常见的模型类型之一。它能自然表达「无序且不重复」的语义，
假设我们实现了一个简单的集合类型，现在我们想要分析它是否正确地实现了插入与删除操作。
可以考虑用列表作为模型，列表天然支持插入与删除，并且我们可以通过排序与去重来模拟集合的行为。

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

## 生成器的美学

本章聚焦生成器的基本构造方式，我们将从最小的值域描述出发，逐步构建出可用于多参函数与集合结构的输入。
生成器既是「取值范围」的形式化描述，也是 QuickCheck 与现实需求之间的桥梁，因此我们需要先把基础结构
掌握扎实，后续的分布控制与缩减策略才有可落脚的空间。

在 QuickCheck 中，最常用的起点是对基础类型的取值范围进行建模。`@qc.int_range`、`@qc.small_int`、`@qc.nat`、
`@qc.neg_int` 这些函数分别用于表达不同的整数域，`@qc.char_range`、`@qc.alphabet`、`@qc.numeral` 则用于字符域的
约束表达。我们通常先用这些生成器把输入限制在需求语义允许的范围内，再由性质去验证更高层的关系。

```mbt check
///|
test "gen @qc.int_range invariant" {
  let gen = @qc.int_range(-10, 10)
  let prop = @qc.forall(gen, fn(x) { x >= -10 && x <= 10 })
  @qc.quick_check(prop)
}
```

生成器并不总是「随机」的，我们也可以通过 `@qc.pure` 构造一个恒定值生成器，用来表达边界场景或固定前置条件。
这类生成器在组合时非常重要，它们能稳定地把某些输入固定住，从而让我们聚焦于另一部分输入的变化。

```mbt check
///|
test "gen @qc.pure value" {
  let gen = @qc.pure(7)
  let prop = @qc.forall(gen, fn(x) { x == 7 })
  @qc.quick_check(prop)
}
```

如果我们已经为某个类型定义了 `Arbitrary` 实例，那么 `@qc.Gen::spawn` 可以直接生成默认分布的生成器。
它与 `@qc.quick_check_fn` 的隐式生成逻辑一致，但允许我们显式地插入到 `@qc.forall` 之中，从而在组合生成器时
保持结构清晰，且能够继续叠加其他约束。

```mbt check
///|
test "gen spawn for arbitrary" {
  let gen : @qc.Gen[Int] = @qc.Gen::spawn()
  let prop = @qc.forall(gen, fn(x) { x - x == 0 })
  @qc.quick_check(prop)
}
```

当需求涉及集合结构时，基础生成器需要能够表达「长度」与「元素来源」。`@qc.Gen::array_with_size` 提供了
固定长度数组的生成能力，`@qc.list_with_size` 则用于构造指定长度的列表。固定长度并非只为了便于测试，
它往往直接对应了协议、格式或算法的前提条件。

```mbt check
///|
test "gen array_with_size" {
  let gen = @qc.int_range(0, 9).array_with_size(5)
  let prop = @qc.forall(gen, fn(arr) { arr.length() == 5 })
  @qc.quick_check(prop)
}

///|
test "gen @qc.list_with_size sample" {
  let gen = @qc.list_with_size(3, @qc.char_range('a', 'f'))
  let _ : @list.List[Char] = gen.sample()

}
```

多参数函数是实际业务的常态，而 `@qc.tuple`、`@qc.triple`、`@qc.quad` 让我们可以将多个生成器合成为一个输入，
从而保持「单参性质」的统一执行模型。这样做不仅让性质更简洁，也让缩减过程能够同时关注多个参数之间
的相互作用。

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

基础结构的最后一个关键环节是「变换」。`@qc.Gen::fmap` 允许我们在生成结果之上进行纯函数变换，从而把
已有的值域映射为新的域。这个能力看似简单，却是我们构造业务特化输入的核心手段，后续的分布控制与
条件过滤也会建立在这一层结构之上。

```mbt check
///|
test "gen fmap transform" {
  let gen = @qc.int_range(0, 50).fmap(fn(x) { x * 2 })
  let prop = @qc.forall(gen, fn(x) { x % 2 == 0 })
  @qc.quick_check(prop)
}
```

通过这些基础结构，我们已经可以覆盖大量现实需求中最常见的输入形态：受限数值、固定长度集合以及多参组合。
在此基础上，我们下一步要解决的是「分布是否合理」的问题，也就是如何在可控的前提下更接近真实数据形态，
这将是下一章的核心内容。

## 统计分布控制

本章讨论生成器的组合与分布控制。现实数据往往呈现多峰、偏态或结构性特征，若只依赖单一范围生成器，
测试覆盖会显得单薄。我们需要通过组合与加权，让输入分布更贴近真实场景，同时保持性质表达的简洁性。

当需求存在多种类别或路径时，`@qc.one_of` 是最直接的组合手段。它在若干生成器之间做均匀选择，适合把
边界样本与常规样本并置，让性质既能触及极端情况，也能覆盖正常区间的变化。

```mbt check
///|
test "gen @qc.one_of mix" {
  let gen = @qc.one_of([@qc.pure(0), @qc.pure(1), @qc.int_range(-10, 10)])
  let prop = @qc.forall(gen, fn(x) { x >= -10 && x <= 10 })
  @qc.quick_check(prop)
}
```

均匀选择在很多场景并不理想，业务数据往往有明显的主流区间或热点值。此时我们可以使用 `@qc.frequency`
对分支赋权，表达「多数情况来自某个范围，少数情况来自另一个范围」的分布设计，从而把测试资源集中到
更可能出错的区域，同时仍保留稀有路径的覆盖。

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

对离散枚举值而言，`@qc.one_of_array` 与 `@qc.one_of_list` 更加自然，它们直接从给定集合中取值，避免构造
过度复杂的生成器。我们通常用它来模拟协议字段、状态码或固定集合的配置值，从而使性质更接近真实输入。

```mbt check
///|
test "gen @qc.one_of_array enum" {
  let methods : Array[String] = ["GET", "POST", "PUT"]
  let gen = @qc.one_of_array(methods)
  let prop = @qc.forall(gen, fn(m) { methods.contains(m) })
  @qc.quick_check(prop)
}
```

当多个字段存在依赖关系时，`@qc.Gen::bind` 可以将这种依赖编码进生成阶段。它允许我们先生成一个值，
再根据该值生成后续字段，从而在数据层面满足约束，避免在性质内部叠加大量前置判断。

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

`@qc.Gen::fmap` 仍然是组合中的基础能力，它可以在不改变分支概率的前提下，把生成结果映射为业务结构。
这种映射保持了分布的形状，却让数据更贴合接口语义，因而常被用于构造标识符、规范化输入或衍生字段。

在实践中，我们通常先用 `@qc.one_of` 或 `@qc.frequency` 设定「宏观分布」，再用 `bind` 与 `fmap` 完成
「微观结构」的约束与衍生。这样的两层结构能够同时兼顾覆盖面与真实性，并且保持生成器的可读性。

组合与分布并不会改变性质本身，但会显著影响测试的有效性。分布设计应当围绕需求语义展开，避免过度平均，
也避免过度偏置，从而使随机测试在有限预算内提供更可靠的缺陷发现能力。

在此基础之上，我们还需要进一步控制规模与复杂度，这涉及 size 参数的演化与生成器的尺度策略，
这将是下一章讨论的重点。

## 规模与复杂度

本章讨论 size 参数如何影响数据规模与测试复杂度。随机测试并不是越大越好，规模过大会掩盖问题本质，
规模过小又会失去覆盖价值。我们需要把 size 当作成本与收益之间的调节器，通过配置与生成器策略让测试
在可控的预算内逼近真实复杂度。

`@qc.quick_check` 提供了 `max_size` 用于限制整体规模，这是最直接的控制方式。我们常在算法复杂度较高、
或输入域可能指数增长的场景中使用它，以避免测试时间失控，同时确保性质仍能在合理范围内被充分检验。

```mbt check
///|
test "@qc.quick_check max_size" {
  let gen = @qc.sized(fn(n) { @qc.list_with_size(n, @qc.small_int()) })
  let prop = @qc.forall(gen, fn(xs) { xs.length() >= 0 })
  @qc.quick_check(prop, max_size=30)
}
```

当我们希望「数据结构与 size 同步增长」时，`@qc.sized` 是更明确的表达。它将 size 作为参数传入生成逻辑，
从而把规模约束写在生成器内部，避免在性质中处理尺寸相关的前置条件。这种方式对数组、列表、树等结构
尤其有效，因为它将复杂度控制内化为输入域的构造规则。

```mbt check
///|
test "@qc.sized array with explicit length" {
  let gen = @qc.sized(fn(n) {
    let len = if n < 0 { 0 } else { n }
    @qc.tuple(@qc.pure(len), @qc.int_range(0, 9).array_with_size(len))
  })
  let prop = @qc.forall(gen, fn(p) {
    let (len, arr) = p
    arr.length() == len
  })
  @qc.quick_check(prop, max_size=20)
}
```

当我们需要在不修改生成器结构的前提下限制规模时，可以使用 `@qc.Gen::resize`。它会把 size 固定为指定值，
从而将复杂度稳定在一个可预期的水平。我们常在调试或回归阶段使用它，让反例更集中、运行时间更稳定。

```mbt check
///|
test "resize clamps size" {
  let gen = @qc.sized(fn(n) { @qc.list_with_size(n, @qc.int_range(0, 9)) })
  let small = gen.resize(5)
  let prop = @qc.forall(small, fn(xs) { xs.length() == 5 })
  @qc.quick_check(prop)
}
```

如果我们希望规模随 size 变化，但增长速度不那么陡峭，则可以使用 `@qc.Gen::scale` 调整 size 的映射关系。
这相当于在「生成复杂度曲线」上加一层函数，使数据规模随测试轮次增长得更平缓，从而在有限预算中
获得更稳定的覆盖与更可控的运行时间。

```mbt check
///|
test "scale slows growth" {
  let gen = @qc.sized(fn(n) { @qc.list_with_size(n, @qc.int_range(0, 9)) })
  let scaled = gen.scale(fn(n) { n / 2 })
  let prop = @qc.forall(scaled, fn(xs) { xs.length() <= 20 })
  @qc.quick_check(prop, max_size=40)
}
```

规模控制不仅影响性能，也影响失败解释。过大的结构会导致缩减时间增加，反例噪声加重，甚至掩盖关键路径。
因此我们需要把 `max_size`、`resize` 与 `scale` 作为统一策略使用，在不同阶段选择不同的规模曲线，
让性质既能触及复杂情形，又能保持失败信息的可读性与可诊断性。

<!-- 在完成规模与复杂度管理之后，我们就可以把注意力转向缩减策略本身。下一章将讨论 shrink 的理念与实现，
说明如何把「最小反例」从抽象概念变成可操作的工程流程。 -->
