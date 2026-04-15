# `moonbitlang/quickcheck/internal/testing` — in-repo test & tutorial corpus

> **Not a public API.** This package is declared in the top-level
> `moon.mod.json` `exclude` list, so it is **not shipped** when
> `moonbitlang/quickcheck` is published. Nothing outside this directory
> imports it.

## Why it exists

Two parallel jobs, both in one place so the tutorial examples and the
regression suite stay in lockstep:

### 1. End-to-end regression suite

The four `.mbt` files here exercise the library's public API by name
and **pin its observable output**:

| File | Count | What it locks in |
|------|------|-----------------|
| `gen.mbt` | 13 tests | Deterministic sample sequences from `one_of`, `frequency`, `char_range`, `int_range`, … given a fixed seed. |
| `driver.mbt` | 25 tests | The exact string printed by `quick_check_silence` for representative pass / fail / give-up runs, including `label` / `classify` histograms. |
| `feat.mbt` | 10 tests | Enumeration offsets and random samples for user-defined recursive types (trees, `Nat`). |
| `axiom.mbt` | 3 tests | `Equivalence` laws on a small persistent queue, covering the "write a law, check it holds" path. |

If someone changes the RNG wiring, tweaks reporting format, or breaks
the enumeration convolution in `feat`, these tests go red and tell you
the moment it happens. They are **black-box tests**: they can only see
the public API surface, which is exactly the guarantee they protect.

### 2. Tutorial fixture

The subdirectories `tutorial_en/` and `tutorial_zh/` hold the full
English and Chinese tutorials (`Tutorial1.mbt.md`, `Tutorial2.mbt.md`,
`Tutorial3.mbt.md`, plus an English `README.mbt.md`). They are written
as executable `.mbt.md` files and pull the exact same helper types
defined in the parent package (`Queue`, `SingleTree`, `Tree`, `Nat`, …)
— so **the examples the user reads in the tutorial are the very
examples the regression suite runs against the real library.**

## Public surface

Tiny, and only exposed because the tutorial markdown imports it:

```moonbit nocheck
pub fn empty_queue() -> Queue
pub fn enqueue(Queue, Int) -> Queue
pub fn Queue::is_empty(Self) -> Bool
```

`Queue` is a worked example of "how to implement `Shrink` for a
user-defined type"; that implementation lives in `axiom.mbt`.

## Sibling internal packages

Three packages live under `src/internal/`. All are excluded from the
published module.

| Package | Purpose |
|---------|---------|
| `internal/testing` *(this one)* | Black-box regression suite + tutorial fixture |
| `internal/benchmark` | Microbenchmarks for the enumeration / generator pipelines |
| `internal/shrinking` | Experimental `ShrinkTree[T]` pretty-printer used when exploring shrink traces |

If you add a fourth non-public package, put it here so the "not
shipped" boundary stays uniform: one entry in `moon.mod.json`'s
`exclude` list (`src/internal`) covers everything below.

## Conventions

- **Test names are descriptive.** We use `inspect(..., content=...)`
  for string-shaped assertions so a broken output produces a readable
  diff instead of an opaque boolean.
- **Seeds are explicit** when determinism matters. The defaults on
  `Gen::samples` produce reproducible output across platforms.
- **Flaky tests are caught by CI** on three OSes × three toolchains;
  if a change here ever becomes non-deterministic, the matrix catches
  it before release.

## Moving / removing

Because this package has no external importers, you can rename it,
restructure it, or delete it without breaking downstream users. Do
remember to update the `exclude` list in the root `moon.mod.json` if
the path changes, otherwise the package will accidentally ship.

## License

Apache-2.0.
