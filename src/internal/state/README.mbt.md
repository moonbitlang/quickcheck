# `internal/state` — driver-internal state cluster

This package holds the mutable bookkeeping the test driver keeps
across a single `quick_check` / `small_check` run: the configuration
caps, the counters, the accumulated coverage tally, the per-sample
verdict, and the callback hooks combinators attach along the way.

Everything in here is an implementation detail of the root
`moonbitlang/quickcheck` package. Because it lives under `internal/`,
nothing leaks to downstream users — the `pub(all)` and `pub` markers
on these types are only so the root package (which lives in a
separate compilation unit) can see them.

## Why the bundle

These types are *mutually* recursive, so they had to move together to
keep the package graph acyclic:

```
   State  ←──┐
     │       │ expects
     │       │
     v       │
   SingleResult ──── carries ────► Callback
     ▲                                │
     │                                │ closes over
     │                                │
     └────────────── State ◄──────────┘
```

- `State` has a field `expected : Expected` and (indirectly via
  `SingleResult.callbacks`) hands itself to every callback.
- `SingleResult` carries an `@list.List[Callback]`.
- `Callback` is a pair of function pointers, both typed as
  `(State, SingleResult) -> Unit`.

If `State` moved but `SingleResult` stayed in root, each would need
to import the other; the cycle blocks compilation. Putting them in
one package dissolves the cycle.

## What's exposed

The `pub` surface is deliberately narrow:

- Values: `from_config`, `succeed`, `failed`, `rejected` — the
  constructors the driver / combinators call to build fresh state and
  per-sample verdicts.
- Types: `State`, `Config`, `SingleResult` (all `pub(all)` — the
  driver reads their fields directly), `Callback`, `Kind`, `Status`,
  `Expected` (all `pub(all)` — the driver pattern-matches their
  variants), and `Coverage` (`pub`, fields hidden — the only
  externally visible method is `Coverage::to_string`).
- Methods on `State`: the thin layer of pure state-machine
  transitions (`clone`, `compute_size`, `add_coverages`,
  `update_state_from_res`, `finished_successfully`,
  `discarded_too_much`, `callback_post_test`,
  `callback_post_final_failure`, `counts`). The heavier driver-side
  methods (`run_test`, `find_failure`, `local_min`, …) live in
  `driver.mbt` in the root package; MoonBit's orphan rule accepts
  this because the type is `pub(all)`.

Private helpers — `Coverage::new`, `Coverage::label_incr`,
`Coverage::class_incr`, `Coverage::label_to_string`,
`Coverage::class_to_string`, `format_percent`, the `InternalError`
placeholder suberror, and the `ListCompare` key wrapper — stay
package-private; they're only called from this file.

## Re-exporting `Expected`

`Expected` is the one type in this cluster that *is* user-facing:
external callers write `@quickcheck.quick_check(..., expect=Fail)`.
The root package keeps that name reachable via

```moonbit nocheck
// in src/types.mbt

///|
pub using @state {type Expected}
```

so `@quickcheck.Expected` continues to resolve to the same enum
defined here.
