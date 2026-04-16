///|
/// Re-export: downstream callers speak `@falsify.List`.
pub using @list {type List}

///|
/// The per-run state a `Property` threads through its evaluation:
/// a free-form log, a deterministic flag, and the `label` histograms
/// that the driver aggregates across passing runs.
///
/// Fields:
/// - `log`: `info(...)` messages produced during this run.
/// - `deterministic`: `true` when the property's result is fully
///   determined by the sample tree (no internal RNG), so shrinking is
///   safe to replay.
/// - `labels`: named buckets populated by `label` / `collect`.
struct TestRun {
  log : List[String]
  deterministic : Bool
  labels : @immut_hashmap.HashMap[String, @sorted_set.SortedSet[String]]
}

///|
impl Show for TestRun with output(self, logger) {
  logger
  ..write_string("{log: ")
  ..write_object(self.log)
  ..write_string(", deterministic: ")
  ..write_object(self.deterministic)
  ..write_string(", labels: ")
  ..write_object(self.labels)
  .write_string("}")
}

///|
/// Starting `TestRun`: empty log, deterministic, no labels. The
/// driver seeds every run with this.
pub fn init_test_run() -> TestRun {
  { log: @list.empty(), deterministic: true, labels: @immut_hashmap.new() }
}

///|
/// The verdict a property reports for a single input:
/// - `TestPassed(t)`: the input held, `t` is the observed value.
/// - `TestFailed(e)`: the input falsified the property; `e` carries
///   the counter-example metadata.
/// - `TestDiscarded`: the input didn't apply (e.g. a precondition
///   was false); the driver tries another.
enum TestResult[T, E] {
  TestPassed(T)
  TestFailed(E)
  TestDiscarded
}

///|
/// A property in Falsify: a `TestRun -> Gen<TestResult + TestRun>`
/// function. Given an incoming run state, the property returns a
/// generator that, when driven with a sample tree, yields the verdict
/// plus the updated run state (log, labels, etc).
struct Property[T, E] {
  run : (TestRun) -> Gen[(TestResult[T, E], TestRun)]
}

///|
/// Evaluate the property against `tr`. Rarely called by users
/// directly — the driver does this in its main loop.
pub fn[T, E] Property::run(
  self : Property[T, E],
  tr : TestRun,
) -> Gen[(TestResult[T, E], TestRun)] {
  (self.run)(tr)
}

///|
/// Low-level escape hatch: build a `Property[T, E]` from a raw `run`
/// function. Most users stay at the `gen` / `test_gen` / combinators
/// level.
pub fn[T, E] mk_property(
  run : (TestRun) -> Gen[(TestResult[T, E], TestRun)],
) -> Property[T, E] {
  { run, }
}

///|
/// Apply a property against the starting `TestRun`, yielding the
/// generator the driver will actually run.
pub fn[T, E] run_property(
  p : Property[T, E],
) -> Gen[(TestResult[T, E], TestRun)] {
  p.run(init_test_run())
}

///|
/// A property that always discards its current input, asking the
/// driver to try another. Useful inside `bind` where a precondition
/// doesn't hold.
pub fn[T, E] discard() -> Property[T, E] {
  mk_property(run => pure((TestDiscarded, run)))
}

///|
/// Emit a diagnostic message to the run log. The property still
/// "passes" at this step — `info` is orthogonal to the verdict.
pub fn info(msg : String) -> Property[Unit, String] {
  mk_property(run => pure((TestPassed(()), { ..run, log: run.log.add(msg) })))
}

///|
/// Classify the current run under `label`, adding the given values
/// to the label's histogram bucket. Used for post-run distribution
/// reporting (à la classical QuickCheck's `classify`).
pub fn[E] label(label : String, vals : List[String]) -> Property[Unit, E] {
  fn add_values(
    x : @sorted_set.SortedSet[String]?,
  ) -> @sorted_set.SortedSet[String] {
    let s = x.unwrap_or(@sorted_set.new())
    s.union(@sorted_set.from_iter(vals.iter()))
  }

  mk_property(r => {
    let set = r.labels.get(label)
    pure(
      (TestPassed(()), { ..r, labels: r.labels.add(label, add_values(set)) }),
    )
  })
}

///|
/// Like `label`, but accepts any `Show`-able values and renders them
/// with `Show::to_string` before inserting into the bucket.
pub fn[T : Show, E] collect(l : String, ls : List[T]) -> Property[Unit, E] {
  label(l, ls.map(Show::to_string))
}

// Running Generators

///|
/// Wrap a generator as a property that always passes, with `f`
/// producing an optional log line per input. Returning `None` marks
/// the run as non-deterministic (the property depended on the sample
/// in a way the driver can't re-play); returning `Some(msg)` adds
/// `msg` to the run log.
pub fn[T, E] gen(f : (T) -> String?, g : Gen[T]) -> Property[T, E] {
  fn aux(run : TestRun) -> (T) -> (TestResult[T, E], TestRun) {
    x => {
      match f(x) {
        None => (TestPassed(x), { ..run, deterministic: false })
        Some(msg) => (TestPassed(x), { ..run, log: run.log.add(msg) })
      }
    }
  }

  mk_property(run => g.fmap(aux(run)))
}

///|
/// Wrap a generator plus a boolean predicate as a `Property`: returns
/// `TestPassed(a)` when `f(a)` holds, `TestFailed("Falsified")`
/// otherwise. The quickest way to hand a generator to `falsify`.
pub fn[T] test_gen(f : (T) -> Bool, gen : Gen[T]) -> Property[T, String] {
  fn aux(run : TestRun) {
    a => {
      (
        match f(a) {
          true => TestPassed(a)
          false => TestFailed("Falsified")
        },
        { ..run, deterministic: false },
      )
    }
  }

  { run: r => gen.fmap(aux(r)) }
}
