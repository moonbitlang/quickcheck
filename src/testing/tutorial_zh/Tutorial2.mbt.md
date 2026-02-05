# QuickCheck 教程

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
  inspect(
    gen.samples(),
    content="[[0, 6], [4, 3], [8, 0], [4, 6], [5, 7], [5, 2], [0, 0], [2, 4], [1, 0], [4, 3]]",
  )
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
  inspect(
    gen.sample(),
    content="(100, [5, 5, 0, 2, 0, 5, 4, 6, 4, 2, 1, 3, 3, 3, 0, 8, 2, 4, 2, 3, 5, 6, 5, 8, 8, 6, 2, 1, 7, 3, 6, 6, 1, 3, 8, 3, 4, 7, 4, 8, 7, 4, 0, 7, 2, 5, 4, 6, 5, 5])",
  )
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
