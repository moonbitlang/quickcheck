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
而是用较少的候选点快速逼近“更简单”的值。

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
  inspect(s, content=(
    #|[[3, 5], [1, 5], [1, 3], [0, 3, 5], [1, 2, 5], [1, 3, 4], [1, 3, 3]]
  ))
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
  inspect(r, content=(
    #|*** [0/0/100] Failed! Falsified.
    #|[0, 0, 0]
  ))
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

### 分类统计

### discard 分析

## SmallCheck

### 小规模穷举

### 随机与穷举

### 规模控制

## Functional Enumeration

### 枚举模型

### Feat 风格

### 覆盖基线

## 归纳关系

### 关系规格

### 自动生成

### 自动枚举

## 案例分析

### 小语言

### 生成器对比

### 反例对比

## 总结

### 工程取舍

### 未来方向
