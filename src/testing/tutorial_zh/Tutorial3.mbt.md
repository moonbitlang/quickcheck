# QuickCheck 教程 Part 3

本篇是 QuickCheck 系列的最后一部分，重点关注 PBT 的后半程：
当性质失败时，框架到底如何把一个随机失败样本压缩成更小的反例；
当失败样本已经足够小之后，我们又如何判断它是不是「真的说明了问题」，
而不是某个偶然结构或无意义噪声。

在很多工程场景里，随机测试能否真正落地，取决的并不是它能生成多少数据，
而是它在失败时能否交付一个足够短、足够稳定、足够有解释力的反例。
如果一个性质失败后只能给出一大段杂乱输入，那么测试本身虽然发现了问题，
却未必降低了定位成本；相反，如果失败样本能够被迅速缩减到缺陷真正依赖的最小结构，
那么反例几乎就是一段直接可执行的调试线索。

当然，缩减并不是第三篇唯一关心的主题。
当我们继续推进 PBT，就会发现另一个问题：受限输入一旦变复杂，单靠手写生成器与手写 shrinker
很容易变得脆弱且难以维护。于是我们自然会走向更系统的方法，例如小规模穷举、functional enumeration，
甚至把「规格本身」转化为生成器与判定器的归纳关系方法。

## 反例与缩减

在 QuickCheck 中，失败从来不是终点，而是分析的起点。
一个性质失败以后，我们真正关心的问题通常不是「它有没有失败」，
而是「它为什么失败」、「最小失败条件是什么」以及「当前反例里哪些部分只是噪声」。
随机测试若只给出一个庞大而偶然的输入，调试成本依然很高；
缩减策略的作用，就是在保持失败事实不变的前提下，把这个输入压缩到更接近缺陷本质的形式。

从执行流程上看，QuickCheck 会先生成样本、找到失败，再沿着 shrink 树继续搜索更小的失败样本。
这个过程并不会改变性质本身，却会显著改变我们理解 bug 的速度。
很多时候，一个「失败但很大」的反例几乎没有帮助，而一个「更小但语义完整」的反例，
已经足够直接指向实现错误。
因此 shrink 并不是 QuickCheck 的边角功能，它和生成器一样，决定了整个测试体系的可用性。
接下来我们先从 trait `Shrink` 开始，
了解框架如何抽象这一过程。

### 默认 Shrink

`Shrink` 是 QuickCheck 中负责「把一个值变简单」的 trait。
从签名上看，它的核心方法 `shrink` 接受一个值，返回一个迭代器，产出一系列「更小的」候选值。
这里使用迭代器是因为我们期望一种「惰性搜索」的语义，
很可能在某个候选值上就能找到一个更小的失败样本，而不需要把所有候选值都枚举出来。

```mbt nocheck
///|
pub trait Shrink {
  shrink(Self) -> Iter[Self]
}
```

对于大多数基础类型与常见容器，框架已经提供了默认实例，因此只要我们使用
`@qc.quick_check_fn` 或 `@qc.Arrow` 这类入口，就会自动启用对应的 shrink 逻辑。
整数会倾向于向 `0` 靠拢，布尔值会朝 `false` 收缩，数组与列表则会同时尝试
「删元素」与「缩元素」，元组会按分量继续递归缩减。

先看一个最简单的例子。对整数而言，默认 shrink 的方向并不是盲目枚举所有更小的数，
而是用较少的候选点快速逼近「更简单」的值。

```mbt check
///|
test "shrink int sample" {
  json_inspect(@qc.Shrink::shrink(100), content=[99, 97, 94, 88, 75, 50, 0])
}
```

这表明 shrink 在设计上并不是期望一种随意扰动，
而期望朝着更接近极小值的方向组织搜索。
其中的直觉是：我们有一个值，它本身也是由很多更小的组件构成的，
那么如果它失败了，我们就希望先看看「更小的组件」能不能失败，而不是直接跳到一个完全不同的值。
这种偏序在容器类型上会变得更明显：数组会优先尝试移除一部分元素，
如果删除元素还不足以保留失败，再继续缩减每个位置上的子项。
因此默认 shrink 往往天然适合「找出最小必需上下文」这类任务。

我们回到一个更贴近真实 bug 的例子。假设我们写了一个有缺陷的删除函数，
它只删除数组中第一次出现的元素，而不是删掉全部出现位置：

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
  let x = @qc.quick_check_fn_silence(prop_remove_all)
  inspect(
    x,
    content=(
      #|*** [8/0/100] Failed! Falsified.
      #|(0, [0, 0, -1])
    ),
  )
}
```

这个性质失败并不令人意外，真正重要的是它会如何失败。
由于 `quick_check_fn` 自动要求参数类型具备 `Arbitrary`、`Shrink` 与 `Show`，
所以这里的 `(Int, Array[Int])` 会自动启用「元组 shrink + 数组 shrink + 整数 shrink」的组合策略。
直观地说，`Int` 会不断尝试向 `0` 靠拢，数组则会优先删去与失败无关的元素，
最后才继续缩减仍然必要的那些位置。我们观察到的最终反例是 `(0, [0, 0, -1])`，
它已经被压缩到一个非常小的规模了。并且直接指出了问题的核心：
这个 `remove_first_only` 函数没有正确处理数组里多个 `0` 的情况。

默认 shrink 在大多数基础场景已经足够好，但它也不是无限制运行的。
`@qc.quick_check` 与 `@qc.quick_check_fn` 都提供了 `max_shrink` / `max_shrinks`
用于限制缩减预算，这在输入结构很大、缩减树很宽时尤其重要。
换句话说，缩减本身也是一种搜索，我们同样需要在「更小的反例」与「更快的反馈」之间做工程上的权衡。

### 自定义 Shrink

默认 shrink 的优势在于通用，但通用的代价是它并不了解业务不变量。
一旦输入带有额外语义，例如「必须是偶数」、「必须非负」和「必须保持有序」，
默认 shrink 就可能把样本缩到一个类型上合法、但业务上并不成立的值。
这时我们就需要显式接管 shrink 过程。

QuickCheck 提供了两个直接相关的接口：

```mbt nocheck
fn[T : Testable, A : Show] @qc.forall_shrink(
  gen : @qc.Gen[A],
  shrinker : (A) -> Iter[A],
  f : (A) -> T,
) -> @qc.Property

fn[P : Testable, T] @qc.shrinking(
  shrinker : (T) -> Iter[T],
  x0 : T,
  pf : (T) -> P,
) -> @qc.Property
```

`forall_shrink` 的角色是「给定生成器之后，再显式指定如何缩减生成值」；
而 `shrinking` 则更底层一些，它不依赖随机生成，而是从一个给定值出发，
直接沿着 shrinker 生成的候选值向下搜索。
前者适合日常性质测试，后者则很适合我们单独调试 shrink 逻辑本身。

下面看一个简单但典型的例子。假设我们的输入域被限定为「非负偶数」，
那么 shrink 时如果跑出奇数，其实就已经偏离了测试对象的语义边界。
这时我们可以在默认 `Int` shrink 的基础上再加一层过滤：

```mbt check
///|
fn shrink_even_nat(x : Int) -> Iter[Int] {
  @qc.Shrink::shrink(x).filter(fn(y) { y >= 0 && y % 2 == 0 })
}

///|
test "forall_shrink keeps even invariant" {
  let gen = @qc.int_range(0, 100).fmap(fn(x) { x * 2 })
  let prop = @qc.forall_shrink(gen, shrink_even_nat, fn(x) { x < 20 })
  @qc.quick_check(prop, expect=Fail)
}
```

这里生成器只会产生偶数，而自定义 shrinker 也保证缩减过程中仍然停留在这个域里。
如果我们直接使用默认 `Int` shrink，框架虽然同样能找到更小的反例，
但中间会穿过大量奇数值，它们在类型上合法，却并不属于我们真正关心的输入语义。
这类「缩得更小但缩偏了」的反例，往往会降低失败的可解释性。

`shrinking` 则适合做更局部的检查。
当我们怀疑某个 shrinker 的行为不稳定时，可以绕过随机生成，直接从一个具体值开始缩减：

```mbt check
///|
test "shrinking starts from explicit value" {
  let prop = @qc.shrinking(shrink_even_nat, 84, fn(x) { x < 20 })
  @qc.quick_check(prop, expect=Fail)
}
```

这类写法的妙处在于，它把「生成问题」和「缩减问题」拆开了。
如果一个性质本身已经能稳定失败，那么我们完全可以先固定一个已知失败值，
单独调试 shrinker 是否真的在朝着我们期望的业务极小值逼近。
这在设计复杂结构的 shrinker 时尤其有帮助，因为很多时候最难调的不是 generator，
而是「为什么最终反例还不够小」。当然，在实践中我们还是 `forall_shrink` 用的多，
或者使用 newtype 方式来用 trait 传参。

### 结构保持 Shrink

到了受限结构场景，问题会进一步升级。
Part 2 我们已经看到，`sorted array`、BST、平衡树这类输入都带有明显的不变量。
如果 shrink 过程破坏了这些不变量，那么一个原本很好的失败样本，
就可能被缩成一个根本不该出现的非法输入，进而让失败原因变得模糊。

以 `sorted array` 为例，默认数组 shrink 会做两类事情：删除元素，以及缩小元素值。
这对普通数组很合理，但对「必须有序」的数组而言，第二类操作可能会破坏全局顺序。
并且使用过滤器的话会导致大量案例被浪费，效率也很差。
面对这种情况最好的思路就是直接在 shrink 过程中维护有序性不变量，
这需要我们自己编写 shrink 函数，来同时考虑「删除元素」和「缩小元素值」的合法性：

```mbt check
///|
pub fn[T : @qc.Shrink + Compare] shrink_sorted_array(
  xs : Array[T],
  lo~ : T,
  hi~ : T,
) -> Iter[Array[T]] {
  let shrink_one_val = (nv : Array[T]) => {
    let l = nv.length() - 1
    Array::makei(l + 1, i => i)
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
  let remove_one_val = (v : Array[T]) => {
    let l = v.length() - 1
    Array::makei(l + 1, i => i)
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

这段代码体现了一个很重要的原则：对受限结构而言，「更小」并不足够，
「更小且仍然合法」才是我们真正需要的目标。
否则 shrink 虽然降低了字面规模，却把问题从「算法在合法输入上失败」
悄悄变成了「算法在非法输入上失败」，这种反例对定位 bug 的帮助会明显下降。

```mbt check
///|
test "shrink sorted array" {
  let s = shrink_sorted_array([1, 3, 5], lo=0, hi=9)
  inspect(
    s,
    content=(
      #|[[3, 5], [1, 5], [1, 3], [0, 3, 5], [1, 2, 5], [1, 3, 4], [1, 3, 3]]
    ),
  )
}
```

把这个 shrinker 接到性质测试上，就能得到一个始终保持有序性的缩减流程：

```mbt check
///|
test "forall_shrink for sorted array" {
  let gen = @qc.sorted_array(6, @qc.int_range(0, 9))
  let prop = @qc.forall_shrink(gen, x => shrink_sorted_array(x, lo=0, hi=10), fn(
    xs,
  ) {
    xs.length() < 3
  })
  let r = @qc.quick_check_silence(prop)
  inspect(
    r,
    content=(
      #|*** [0/0/100] Failed! Falsified.
      #|[0, 0, 0]
    ),
  )
}
```

这个性质本身非常简单，却足以说明结构保持 shrink 的意义。
生成器总是产生长度为 `6` 的有序数组，而 shrink 过程会继续尝试删除元素与缩小元素值，
直到逼近某个更小、但仍然有序的失败样本。
此处的 `[0, 0, 0]` 就是一个非常小的反例了，它直接指出了「有序数组长度限制」这个性质的核心问题。

同样的思想也适用于 Part 2 里的 BST 例子。
若 BST 是通过「数组 -> 插入 -> 树」这条路径构造出来的，那么更稳妥的 shrink 往往不是直接缩树节点，
而是回到其原始表示，先 shrink 数组，再重新执行 `from_array` 或 `from_sorted`。
这样做的好处是：生成与缩减共享同一份结构语义，不变量更容易维持，反例也更容易解释。

## 失败与分布

### 失败信息

缩减让我们拿到更小的反例，但一个更小的反例不一定就更好读。
很多时候真正困难的并不是「找到 bug」，而是「知道这个反例在业务语义里意味着什么」。
例如我们看到一个数组或树失败了，仍然可能不知道它失败前后的关键状态是什么，
也不知道失败究竟是由哪个派生条件触发的。
这时如果只打印原始输入，调试者仍然要把很多中间信息重新手算一遍。

QuickCheck 为此提供了 `counterexample` 这个组合子。
它并不会改变性质的真假，而只是把一段附加信息挂到失败输出上。
于是我们可以把「输入之外、但对解释失败很关键」的派生量，
例如中间结果、规格输出、归一化形式、路径标签等，一并打印出来。

```mbt check
///|
test "counterexample adds derived information" {
  let prop = @qc.forall(@qc.pure((0, [0, 0, -1])), fn(iarr) {
    let (x, arr) = iarr
    let out = remove_first_only(arr.copy(), x)
    @qc.counterexample(!out.contains(x), "after remove: \{out}")
  })
  let r = @qc.quick_check_silence(prop)
  inspect(
    r,
    content=(
      #|*** [0/0/100] Failed! Falsified.
      #|(0, [0, 0, -1])
      #|after remove: [0, -1]
    ),
  )
}
```

在这个例子里，原始输入 `(0, [0, 0, -1])` 已经足够小，
但如果没有 `after remove: [0, -1]` 这条补充信息，
读者仍然需要自己执行一次函数，才能意识到「数组里还残留了一个 `0`」。
换句话说，`counterexample` 的作用不是让失败变小，而是让失败变可解释。

这种手法在模型对照与编译器测试里尤其重要。
我们常常会同时打印 `expected` / `actual`、归一化后的状态、
或者某段解释器轨迹的摘要信息。
当性质已经足够复杂时，失败输出本身其实就是一种局部调试报告，
而不是单纯的一组输入值。

### 分类统计

失败信息解决的是单个反例如何解释的问题，而分类统计解决的是「整体样本分布长什么样」的问题。
即便一个性质一直通过，我们也不能立刻放心，因为生成器可能把大部分预算都花在了某一类平庸样本上，
或者根本没有覆盖到我们真正关心的分支。
如果这些分布信息不可见，那么所谓随机覆盖很容易退化成一种心理安慰。

QuickCheck 提供了 `label`、`classify` 与 `collect` 三个常用接口来观察测试数据。
`label` 适合给每个样本贴一个单独的标签，
`classify` 适合把样本划入若干业务类别，
`collect` 则更通用，它会把某个 `Show` 值直接当作标签收集起来。
在实践中，最常见的入口是先用 `classify` 观察几个关键类别是否真的出现过。

```mbt check
///|
fn t3_prop_rev_list(xs : @list.List[Int]) -> Bool {
  xs.rev().rev() == xs
}

///|
test "classify list distribution" {
  let r = @qc.quick_check_silence(
    @qc.Arrow(fn(xs : @list.List[Int]) {
      @qc.Arrow(t3_prop_rev_list)
      |> @qc.classify(xs.length() > 5, "long list")
      |> @qc.classify(xs.length() <= 5, "short list")
    }),
  )
  inspect(
    r,
    content=(
      #|+++ [100/0/100] Ok, passed!
      #|21% : short list
      #|79% : long list
    ),
  )
}
```

这个输出传达的信息并不在于性质通过了，而在于：
当前默认生成器明显更偏向较长的列表。
如果我们真正关心的是空列表、单元素列表、极短列表上的边界行为，
那这份统计就已经说明，单靠默认分布可能并不够，需要进一步调 generator。

`label` 与 `collect` 的用法也类似，只是粒度不同。
例如说我们可以直接用 `label("length is \{xs.length()}")`
观察每个长度桶的分布，也可以用 `collect(xs.length())`
把长度这个量本身收集起来。
经验上，`classify` 更适合写教程和日常回归，因为类别更稳定、输出更容易读；
而 `label` / `collect` 更适合调生成器时做精细诊断。

### Discard 分析

分布问题里最容易被忽略的一类，是 discard。
当我们使用 `@qc.filter`、前置条件或者部分函数保护时，
很多样本可能会在真正执行性质之前就被丢弃。
少量 discard 是正常的，但如果 discard 数量持续偏高，
那往往说明我们把约束输入的工作推迟到了性质内部过滤的方法不适用。

先看一个温和的例子。我们只想测试非空列表，于是对默认生成器生成的列表再加一层过滤：

```mbt check
///|
test "discard on non-empty lists" {
  let prop_non_empty = fn(xs : @list.List[Int]) -> @qc.Property {
    (!xs.is_empty()) |> @qc.filter(!xs.is_empty())
  }
  inspect(
    @qc.quick_check_silence(@qc.Arrow(prop_non_empty)),
    content="+++ [100/40/100] Ok, passed!",
  )
}
```

这里测试虽然通过了，但我们仍然看到有 `40` 个样本被直接丢弃。
这意味着框架为了得到 `100` 个有效样本，实际上做了更多无用工作。
若这个前置条件再稀疏一些，浪费会迅速放大。

极端情况下，测试甚至会直接 `gave up`：

```mbt check
///|
test "reject all gives up" {
  let prop_reject = fn(_x : Int) { @qc.filter(true, false) }
  inspect(
    @qc.quick_check_silence(@qc.Arrow(prop_reject), expect=GaveUp),
    content="+++ [0/1000/100] Ok, gave up!",
  )
}
```

这个例子当然是刻意构造出来的，但它准确揭示了 discard 的语义：
QuickCheck 并不是测试失败了，而是根本拿不到足够多的有效样本，
于是只能放弃。
因此一旦我们在真实项目里看到 `gave up`，或者发现 discard 数量长期偏高，
首先应该怀疑的不是性质本身，而是 generator 与前置条件之间是否存在结构性错位，
若遇到这种情况，第一步的修复往往是把约束条件尽量写进生成器，而不是写进过滤器。
这也正是为什么 Part 2 一直强调「尽量把约束写进生成器，而不是写进过滤器」。

## SmallCheck

### 小规模穷举

到目前为止，我们主要讨论的还是 QuickCheck 风格的随机测试：
框架不断采样，再把失败样本通过 shrink 压小。
但这并不是 PBT 的唯一工作方式。
如果某类输入天然存在一个比较好的「从小到大」顺序，
那么我们也可以反过来，不做随机采样，而是系统地把这一前缀全部测完。
这正是 SmallCheck 的基本思想：不给概率留余地，而是把测试预算投入到一个可复现、可穷尽、可解释的小规模搜索空间里。

在 MoonBit QuickCheck 里，`small_check` 的入口和 `quick_check` 长得很像，
但它依赖的能力完全不同：

```mbt nocheck
pub fn[A : @feat.Enumerable + Show, B : Testable] @qc.small_check(
  f : (A) -> B,
  max_size? : Int,
  expect? : Expected,
  abort? : Bool,
) -> Unit raise Failure
```

这里约束的不是 `Arbitrary + Shrink`，而是 `Enumerable`。
这意味着 SmallCheck 关心的核心问题不再是「如何随机生成一个值」，
而是「如何把一个类型的所有值组织成一个从小到大的可遍历顺序」。
一旦这个顺序设计得当，测试就是确定性的：同样的 `max_size`、同样的性质，
总会访问同样的前缀，因此也总会得到同样的第一个反例。

```mbt check
///|
test "small check fails on first non-zero int" {
  let r = @qc.small_check_silence(fn(x : Int) { x == 0 }, max_size=5)
  inspect(
    r,
    content=(
      #|*** [1/0/5] Failed! Falsified.
      #|1
    ),
  )
}
```

这个结果很能说明 SmallCheck 的工作方式。
它没有像 QuickCheck 那样先随机生成一个较大的整数，再尝试 shrink；
而是直接按枚举顺序测试前缀。
对于 `Int` 的默认 `Enumerable` 实例，最前面的值依次是 `0, 1, -1, 2, -2, ...`，
所以性质 `x == 0` 会在第二个样本 `1` 处立即失败。
从这里也能看出，SmallCheck 之所以常常不需要 shrink，
并不是因为它「不会失败」，而是因为它从一开始就在访问比较小的值。

需要额外说明的是，经典 SmallCheck 往往以「深度上界」来描述其搜索范围；
而这里的实现更接近一个「枚举前缀」模型：`max_size` 控制本轮最多测试多少个值，
这些值来自 `Enumerable` 给出的有序枚举。
因此 SmallCheck 是否真正「从小到大」地覆盖了搜索空间，
本质上取决于 enumerator 的设计质量。

### 枚举器设计

既然 SmallCheck 的核心是「枚举小值」，那么最重要的问题自然就变成：
什么才算一个设计良好的 enumerator。
从实现角度看，MoonBit 用 `Enumerable` trait 来承载这个信息：

```mbt nocheck
pub(open) trait Enumerable {
  enumerate() -> @feat.Enumerate[Self]
}

pub fn[T] @feat.Enumerate::en_index(Self[T], BigInt) -> T
```

一个好的 enumerator 至少要满足三点。第一，枚举结果不应重复，
否则所谓「穷举前缀」就会浪费预算在同一个值上；第二，每个「大小层级」都必须是有限的，
否则 SmallCheck 会在某一层卡死，永远走不到更大的值；
第三，枚举顺序最好能反映我们对「复杂度」的直觉，
让越靠前的值越接近我们真正想要的「小样本」。

对递归数据类型而言，第二点尤其关键。
如果递归调用不额外增加任何代价，那么像自然数这样的类型会把无限多个值全塞进同一层，
从而破坏 part-finiteness，让我们的枚举进入无限循环。
因此 Feat 风格的枚举都会显式维护一个「付费」动作 `pay`，
表示每经过一层递归构造，值就进入下一层。

```mbt check
///|
enum Nat {
  Zero
  Succ(Nat)
} derive(Show, Eq)

///|
impl @feat.Enumerable for Nat with enumerate() {
  @feat.pay(fn() {
    @feat.singleton(Zero) +
    @feat.Enumerable::enumerate().fmap(fn(n) { Nat::Succ(n) })
  })
}

///|
test "nat enumerate order" {
  let e : @feat.Enumerate[Nat] = @feat.Enumerable::enumerate()
  let xs = [0N, 1, 2, 3, 4].map(fn(i) { e.en_index(i) })
  inspect(
    xs,
    content="[Zero, Succ(Zero), Succ(Succ(Zero)), Succ(Succ(Succ(Zero))), Succ(Succ(Succ(Succ(Zero))))]",
  )
}
```

这个定义看似很短，但已经体现了设计 enumerator 时最核心的原则。
`@feat.singleton(Zero)` 给出基例；
递归分支通过 `fmap` 把「更小的自然数」映射为 `Succ(n)`；
而最外层的 `pay` 则保证每多套一层构造子，值就会被推迟到下一层。
如果去掉 `pay`，那么 `Zero, Succ(Zero), Succ(Succ(Zero)), ...` 就会落在同一个 part 里，
SmallCheck 在理论上甚至无法完成这一层的枚举。

对更复杂的类型，写法也基本遵循同样的机械结构。
空构造器通常用 `singleton`；
单参数构造器可以直接 `fmap`；
多参数构造器则先借助 tuple/product 得到参数的枚举，再映射成真正的构造器；
若一个类型有多个构造器，就用 `consts` 或 `union` 把它们合并起来。
这里最关键的不是「把代码写短」，而是保持构造方式与数据语义一一对应，
确保枚举是无重复且按复杂度分层的。

### Feat 风格

上面的 `Enumerable` 接口并不是随意设计出来的，它基本上就是论文
《Feat: Functional Enumeration of Algebraic Types》中的「函数式枚举」思想在 MoonBit 里的落地。
论文的核心观点是：与其把一个类型看成一条线性的值列表，
不如把它看成一组按大小分层的有限划分 (parts) 。
每个 part 都有两个核心信息：其一是基数 (cardinality)，也就是这一层有多少值；
其二是索引函数，也就是给定层内下标后，如何直接取出对应的值。

MoonBit 当前的实现也正是这样组织的。
`Enumerate[T]` 内部是一条惰性的 parts 序列，而每个 `Finite[T]`
则携带 `fCard` 与 `fIndex` 两个消费者。
于是全局索引 `en_index` 的语义就很清楚了：
它不是从头把所有值一个个生成出来，而是先根据各 part 的基数跳过整层，
再在命中的那一层里直接做索引。
这正是论文所谓的 function view，它和 SmallCheck 常见的 list view 有本质差异。

这样设计的直接好处有两个。
其一，枚举不再局限于「从头扫到尾」，而是具备了随机访问能力；
理论上我们甚至可以直接取出一个非常靠后的大值，而不需要先展开前面的所有部分。
其二，同一份 enumerator 可以同时支撑多种测试策略：
既可以像 SmallCheck 那样系统枚举前缀，
也可以像 `@qc.Gen::feat_random` 那样，在某个 size 上界内做均匀随机采样。
换句话说，Feat 并不是「另一个单独的测试框架」，
而是一种把枚举、随机和规模控制统一起来的数据生成基础设施。

从论文角度看，Feat 对传统 SmallCheck 的修正也主要在这里。
经典 SmallCheck 更依赖构造深度这一概念，但深度并不总能准确刻画值的真实复杂度；
而 functional enumeration 会把「什么是小值」编码进 part 的构造过程里。
对于互递归 AST、语法树、类型系统中大量和与积交织的结构，这种分层通常比单纯的深度界更稳定，
也更容易被机械组合。

### 实践 SmallCheck

理解了 enumerator 的设计之后，SmallCheck 的使用就会变得很自然：
我们先决定「什么叫小」，把这种次序写进 `Enumerable`，
再用 `small_check` 顺着这个顺序去检验前缀。
在这个过程中，测试质量很大程度上不再由随机种子决定，而由枚举顺序决定。

```mbt check
///|
test "small check on nat prefix" {
  let r = @qc.small_check_silence(fn(n : Nat) { n == Zero }, max_size=5)
  inspect(
    r,
    content=(
      #|*** [1/0/5] Failed! Falsified.
      #|Succ(Zero)
    ),
  )
}
```

这个例子与前面的整数版本形成了一个很好的对照。
由于 `Nat` 的 enumerator 是我们自己定义的，
SmallCheck 所访问的「小值前缀」也完全由这份定义决定。
在这里，`Zero` 是第一个值，`Succ(Zero)` 是第二个值，
所以性质 `n == Zero` 会立刻在最小的非零自然数上失败。
这类反例几乎不需要后处理，因为「枚举顺序本身」已经承担了缩减的作用。

实际工程里，我们一般不会只为了找一个 `Succ(Zero)` 这样简单的反例去写 enumerator，
真正有价值的是更复杂的递归结构。
当一个类型包含多层递归、多个构造器，或者多组互递归定义时，
QuickCheck 风格的手写 generator 往往会变得越来越像待测程序本身；
而 Feat 风格的 enumerator 通常仍然保持机械、局部、可组合。
这也是论文特别强调它适合大规模互递归语法树的原因。

总的来说，我们可以把 SmallCheck 理解为一种很好的「前缀验证器」：
先用它系统扫过足够小、足够典型的值，尽快排除浅层错误；
如果这一前缀已经稳定通过，再把同一份 `Enumerable` 交给 `feat_random`
或其他随机策略，继续向更大的空间扩展。
这样一来，穷举与随机不再是两套彼此割裂的技术，
而是共享同一份结构规格的两种访问方式。

## 总结

到这里，这个 QuickCheck 教程系列的正文就算完整结束了。
回头看去，第一篇主要讨论的是「如何设计性质」：
我们从代数性质、操作不变量与模型对照出发，试图回答「到底该测什么」。
第二篇讨论的是「如何设计输入」：
从基础生成器、分布控制、规模参数，到受限结构的专门构造器，核心问题变成了「到底该怎么造数据」。
而这一篇补上的，则是 PBT 的后半程：
当性质失败之后，我们如何把失败样本缩减成真正有解释力的反例，
又如何借助 SmallCheck 与 functional enumeration，在某些场景下改用更系统的方式来覆盖小值空间。

此外，QuickCheck、SmallCheck、functional enumeration 也并不是非此即彼的关系。
如果输入空间巨大、结构复杂、只靠穷举根本无法推进，那么随机生成与 shrink 往往是第一选择；
如果类型本身有一个很自然的从小到大顺序，而且我们更关心浅层反例，那么 SmallCheck 的确定性前缀会更直接；
而当我们已经为一个类型写出了质量足够高的 `Enumerable`，
同一份定义又可以同时服务于穷举与随机，这时就不必再人为地把两套技术拆开来看了。
真正需要避免的不是「用了哪一种工具」，而是过早地固化测试入口，
使得性质、生成器与失败解释彼此脱节。
