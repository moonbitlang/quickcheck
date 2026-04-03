# QuickCheck 教程 Part 2

## 受限生成器的挑战

基于属性测试（PBT）中最大的挑战之一是受限随机生成问题，现实场景往往不是简单的结构化生成器可以应对的，
我们可以自动 derive 简单类型的生成器，但是对于具有内部不变量的复杂类型，或者是受谓词约束的值，
此种手段就显得力不从心了。一个天真的想法是「先生成一个大范围的值，再在性质里过滤掉不满足条件的」，
但这会导致测试效率极低，甚至无法得到任何有效样本，因为满足条件的值分布往往非常稀疏。

考虑一个经典的受限 PBT 场景：

$$
\forall x,\forall t, \text{isBST}(t) \implies \text{isBST}(\text{insert}(t, x))
$$

这表明，如果一棵树 $t$ 是有效的二叉搜索树（BST），那么在 $t$ 中插入一个新值 $x$ 会得到另一个有效的 BST。

为了测试这条性质，框架会反复采样 `(x, t)`。
如果 `t` 不是 BST，就会被直接丢弃；
只有通过前置条件的样本才会进入 `insert` 并检查结果。问题在于：
随机树成为 BST 的概率很低，
朴素生成器会让测试大部分轮次都浪费在 discard 上。
因此，在这种情况下我们可能不得不自己设计一个专门的生成器来直接生成满足 isBST 条件的树。
本文我们将由浅入深探讨自定义生成器的设计思路，并通过 QuickCheck 的 API 来实现它们，从而让我们能够高效地测试受限性质。

## 简单生成器

我们先聚焦一类简单的生成器，它们是复杂生成器的基础构件，
主要负责对基础类型的值域进行约束、混合容器类型、积类型等等。

### 值范围控制

在 PBT 中，最常用的起点是对基础类型的取值范围进行建模，
更确切的说，是对与有序类型的值域进行约束。对于整数，我们可能只关心某个区间内的值；对于字符，我们可能只关注特定范围或类别的字符。
在 QuickCheck 中，我们有
`@qc.int_range`、`@qc.small_int`、`@qc.nat`、
`@qc.neg_int` 这些函数用于表达不同的整数域，
也有 `@qc.char_range`、`@qc.alphabet`、`@qc.numeral`
用于字符域的约束表达。
我们通常先用这些生成器把输入限制在需求语义允许的范围内，再由性质去验证更高层的关系。

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

### Arbitrary 导出生成器

`Arbitrary` 是 QuickCheck 中一个重要的 trait，它定义了如何为某个类型生成随机值。
MoonBit 编译器内置了 `Arbitrary` 实例的自动派生机制，能够为大多数简单类型生成默认的随机值。
只需要直接写 `derive(Arbitrary)` 即可。

```mbt check
///|
enum Color {
  Red
  Green
  Blue
} derive(Arbitrary)

///|
impl Show for Color with output(self, logger) {
  match self {
    Red => logger.write_string("Red")
    Green => logger.write_string("Green")
    Blue => logger.write_string("Blue")
  }
}
```

如果我们已经为某个类型定义了 `Arbitrary` 实例，
那么 `@qc.Gen::spawn` 可以直接生成默认分布的生成器。
它与 `@qc.quick_check_fn` 的隐式生成逻辑一致，但允许我们显式地插入到 `@qc.forall` 之中，
从而在组合生成器时保持结构清晰，且能够继续叠加其他约束。

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

### 集合结构与多参组合

当需求涉及集合结构时，基础生成器需要能够表达「长度」与「元素来源」。
`@qc.Gen::array_with_size` 提供了固定长度数组的生成能力，
`@qc.list_with_size` 则用于构造指定长度的列表。固定长度并非只为了便于测试，
它往往直接对应了协议、格式或算法的前提条件。

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

多参数函数是实际业务的常态，
而 `@qc.tuple`、`@qc.triple`、`@qc.quad` 让我们可以将多个生成器合成为一个输入，
从而保持「单参性质」的统一执行模型。这样做不仅让性质更简洁，
也让缩减过程能够同时关注多个参数之间的相互作用。

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

基础结构的最后一个关键环节是「变换」。`@qc.Gen::fmap` 允许我们在生成结果之上进行纯函数变换，
从而把已有的值域映射为新的域。这个能力看似简单，却是我们构造业务特化输入的核心手段，
后续的分布控制与条件过滤也会建立在这一层结构之上。

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

有了「合法形状」的输入后，下一个问题是：
这些输入出现得是否像真实世界一样频繁？
这就需要我们控制分布。现实数据往往呈现多峰、偏态或结构性特征，若只依赖单一范围生成器，
测试覆盖会显得单薄。我们需要通过组合与加权，让输入分布更贴近真实场景，同时保持性质表达的简洁性。

当需求存在多种类别或路径时，`@qc.one_of` 是最直接的组合手段。它在若干生成器之间做均匀选择，
适合把边界样本与常规样本并置，让性质既能触及极端情况，也能覆盖正常区间的变化。

```mbt check
///|
test "gen @qc.one_of mix" {
  let gen = @qc.one_of([@qc.pure(0), @qc.pure(1), @qc.int_range(-10, 10)])
  let prop = @qc.forall(gen, fn(x) { x >= -10 && x <= 10 })
  @qc.quick_check(prop)
}
```

均匀选择在很多场景并不理想，现实数据往往有明显的主流区间或热点值。此时我们可以使用 `@qc.frequency`
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

对离散枚举值而言，`@qc.one_of_array` 与 `@qc.one_of_list` 更加自然，
它们直接从给定集合中取值，避免构造过度复杂的生成器。
我们通常用它来模拟协议字段、状态码或固定集合的配置值，从而使性质更接近真实输入。

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

> `bind` 是非常强大的单子操作，它让我们能够在生成过程中动态地调整分布与结构，从而直接生成满足复杂关系的输入。
> 当然它也更加难以理解与调试，因此我们需要在使用时保持清晰的层次结构，避免过度嵌套或过度依赖 `bind` 来表达复杂逻辑，

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

此前已经介绍过了 `@qc.Gen::fmap` ，它仍然是组合中的基础能力，可在不改变分支概率的前提下，把生成结果映射为业务结构。
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
  let gen = @qc.sized(fn(n) { @qc.small_int().list_with_size(n) })
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
    content=(
      #|(100, [5, 5, 0, 2, 0, 5, 4, 6, 4, 2, 1, 3, 3, 3, 0, 8, 2, 4, 2, 3, 5, 6, 5, 8, 8, 6, 2, 1, 7, 3, 6, 6, 1, 3, 8, 3, 4, 7, 4, 8, 7, 4, 0, 7, 2, 5, 4, 6, 5, 5, 8, 8, 5, 6, 5, 6, 2, 3, 5, 7, 3, 3, 0, 3, 7, 4, 0, 4, 0, 7, 6, 6, 2, 5, 1, 5, 3, 3, 2, 7, 8, 8, 8, 1, 4, 2, 8, 0, 8, 8, 4, 2, 6, 5, 0, 2, 5, 2, 0, 6])
    ),
  )
}
```

当我们需要在不修改生成器结构的前提下限制规模时，可以使用 `@qc.Gen::resize`。它会把 size 固定为指定值，
从而将复杂度稳定在一个可预期的水平。我们常在调试或回归阶段使用它，让反例更集中、运行时间更稳定。

```mbt check
///|
test "resize clamps size" {
  let gen = @qc.sized(fn(n) { @qc.int_range(0, 9).list_with_size(n) })
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
  let gen = @qc.sized(fn(n) { @qc.int_range(0, 9).list_with_size(n) })
  let scaled = gen.scale(fn(n) { n / 2 })
  let prop = @qc.forall(scaled, fn(xs) { xs.length() <= 20 })
  @qc.quick_check(prop, max_size=40)
}
```

规模控制不仅影响性能，也影响失败解释。过大的结构会导致缩减时间增加，反例噪声加重，甚至掩盖关键路径。
因此我们需要把 `max_size`、`resize` 与 `scale` 作为统一策略使用，在不同阶段选择不同的规模曲线，
让性质既能触及复杂情形，又能保持失败信息的可读性与可诊断性。

## 组合构造器

到这里我们已经有了范围、分布与规模控制，剩下的难点是「结构性约束」。
例如二分查找、区间合并等逻辑都要求输入数组有序，单靠 `int_range` 这类基础生成器无法直接表达这个前置条件。
一个直接做法是先生成数组，再用 `@qc.filter` 过滤为有序样本，这正是组合构造器最常见的入口。

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

这个例子里有三个组合层次：先用 `array_with_size` 固定结构，再用嵌套 `forall + one_of_array` 建立元素与容器的依赖，
最后用 `filter` 施加「有序」约束。写法直观，适合快速验证想法，但它仍然会丢弃一部分样本。

当过滤比例偏高时，我们更推荐把约束提前到「构造阶段」。
QuickCheck 已经提供 `@qc.sorted_array`，我们可以直接利用它：

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

`filter` 适合表达「临时前置条件」，`sorted_array` 这类构造器适合表达「稳定结构不变量」。
在工程实践中通常先用过滤器快速定位性质，再逐步替换为专门构造器，让测试既可读又高效。

## 受限结构的构造器案例

在介绍完上述的各种组合子之后，是时候进入我们的正题：
设计一个满足特定性质的生成器，例如有序数组、平衡树、特定协议格式等。
当然，这并非易事，本节也只能提供一个大致的思路框架，
复杂情况仍然需要测试者进行创造性的设计与调试。

手写 QuickCheck 生成器的核心目标其实就两件事：

- 把「有效输入空间」编码进生成过程，别靠过滤；
- 让分布与规模（size）可控，这样测试既跑得动又能覆盖到你真正关心的结构角落

### 规模作为一等公民

QuickCheck 的 `Gen` 有一个隐含的 `size` 参数：
随着测试次数增长， `size` 会逐步变大。手写递归结构生成器时，
最重要的是每一层递归都要消耗 `size`，否则要么无限递归，
要么结构大得离谱导致测试变慢。

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

如果你不想「每层都减 1」，
也可以把 n 拆成左右子规模
（树、图、AST 都是这个套路）：
`let k = int_range(0, n - 1)`，
左用 `k`，右用 `n-1-k`。这样平均会更自然，
而不是总在深度上单边生长，当然也可以直接 `go(n / 2)`，让规模指数级增长。

### 二叉搜索树的例子

先定义 BST 的数据结构：

```mbt check
///|
enum Tree[T] {
  Leaf
  Node(Tree[T], T, Tree[T])
} derive(Debug)

///|
impl[T : Show] Show for Tree[T] with output(self, logger) {
  match self {
    Leaf => logger.write_string("Leaf")
    Node(left, val, right) => {
      logger.write_string("Node(")
      left.output(logger)
      logger.write_string(", ")
      val.output(logger)
      logger.write_string(", ")
      right.output(logger)
      logger.write_string(")")
    }
  }
}
```

如果性质测试不强依赖「树形分布」，
第一个方案是，我们可以先定义一个「插入」函数，来把任意值插入到 BST 中，
然后用 `from_array` 来把一个数组转成 BST。
这样我们就能直接利用 `@qc.int_range().array_with_size()` 来先生成一个普通数组，
再通过 `from_array` 来得到一棵树，
这样天然满足 BST 不变量，
而且 shrink 也很好做（缩列表即可）。

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

然而，这需要我们理解 BST 的插入逻辑，才能正确地实现 `Tree::insert`，
如果这个函数也实现错误，那我们的测试结果会非常混乱。
并且这个方案的效率也不高，因为 `from_array` 可能会生成非常不平衡的树，
因此我们的下一个优化目标可能是「让树更加平衡」，从而更快地覆盖到不同的树形结构。

BST 的一个天然表示是中序遍历是有序序列，
所以我们可以先生成一个列表，排序去重，
然后用「取中点」方式建近似平衡树：

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

这个方案的优势是：大多数树更平衡，
能更容易覆盖到「左右子树都非空」的情形，
也能减小极端深度带来的性能问题。

下一个方案叫做区间递归生成，直接按照 BST 的语义来生长，
关键点是在递归时维护值域区间 `(lo, hi)`：
左子树只能取 `(< root)`，右子树只能取 `(> root)`。
这能控制很多细节，下面我们以 `Tree[Int]` 为例
（因为 QuickCheck 天然提供了 `int_range`）：

```mbt check
///|
fn gen_bst_ranged(min : Int, max : Int) -> @qc.Gen[Tree[Int]] {
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
        }),
      ),
    ])
  }
  @qc.sized(n => go(n, min, max))
}

///|
test "generate ranged BST" {
  let gen_bst = gen_bst_ranged(-100, 100)
  let prop = @qc.forall(gen_bst, fn(t) {
    let arr = inorder(t)
    arr == arr.copy()..sort()
  })
  @qc.quick_check(prop)
}
```

注意这里为了避免重复，
用了 `x-1/x+1` 这样的「离散域」技巧；
如果你允许重复值，
就要改成 `l` 用 `(lo, x)`，`r` 用 `(x, hi)` 并决定重复放哪边（`<=` 或 `>=` 的约定必须统一）。

区间法的真实价值在于：
当你的结构约束更复杂（比如红黑树、AVL、带额外标签的 AST），
你可以把「约束状态」一路带下去，让生成永远有效，而不是靠过滤赌概率。
换句话说，这种方法永远是最具扩展性的，因为它把「语义不变量」直接编码在生成逻辑里了。

## 总结

受限生成器的设计是 PBT 中的核心挑战之一。
通过合理地组合基础生成器、控制分布与规模，并把语义约束内化到生成过程中，
确实可以满足大多数受限性质的测试需求。当然，未来我们希望让它更加自动化，
例如用户只需要编写性质，就可以推导出满足性质前置条件的生成器，
从而让 PBT 的使用门槛更低，覆盖更广。
这是相当具有可行性的，我们将在下一篇文章更多讨论这些前沿技术 ([inductive relations](https://github.com/moonbit-community/inrel) / functional enumeration 等等)。
