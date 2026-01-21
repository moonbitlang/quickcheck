///|
pub using @list {type List}

///|
struct TestRun {
  log : List[String]
  deterministic : Bool
  labels : @immut_hashmap.HashMap[String, @sorted_set.SortedSet[String]]
} derive(Show)

///|
pub fn init_test_run() -> TestRun {
  { log: @list.empty(), deterministic: true, labels: @immut_hashmap.new() }
}

///|
enum TestResult[T, E] {
  TestPassed(T)
  TestFailed(E)
  TestDiscarded
}

///|
struct Property[T, E] {
  run : (TestRun) -> Gen[(TestResult[T, E], TestRun)]
}

///|
pub fn[T, E] Property::run(
  self : Property[T, E],
  tr : TestRun,
) -> Gen[(TestResult[T, E], TestRun)] {
  (self.run)(tr)
}

///|
pub fn[T, E] mk_property(
  run : (TestRun) -> Gen[(TestResult[T, E], TestRun)],
) -> Property[T, E] {
  { run, }
}

///|
pub fn[T, E] run_property(
  p : Property[T, E],
) -> Gen[(TestResult[T, E], TestRun)] {
  p.run(init_test_run())
}

///|
pub fn[T, E] discard() -> Property[T, E] {
  mk_property(fn(run) { pure((TestDiscarded, run)) })
}

///|
pub fn info(msg : String) -> Property[Unit, String] {
  mk_property(fn(run) {
    pure((TestPassed(()), { ..run, log: run.log.add(msg) }))
  })
}

///|
pub fn[E] label(label : String, vals : List[String]) -> Property[Unit, E] {
  fn add_values(
    x : @sorted_set.SortedSet[String]?,
  ) -> @sorted_set.SortedSet[String] {
    let s = x.unwrap_or(@sorted_set.new())
    s.union(@sorted_set.from_iter(vals.iter()))
  }

  mk_property(fn(r) {
    let set = r.labels.get(label)
    pure(
      (TestPassed(()), { ..r, labels: r.labels.add(label, add_values(set)) }),
    )
  })
}

///|
pub fn[T : Show, E] collect(l : String, ls : List[T]) -> Property[Unit, E] {
  label(l, ls.map(Show::to_string))
}

// Running Generators

///|
pub fn[T, E] gen(f : (T) -> String?, g : Gen[T]) -> Property[T, E] {
  fn aux(run : TestRun) -> (T) -> (TestResult[T, E], TestRun) {
    fn(x) {
      match f(x) {
        None => (TestPassed(x), { ..run, deterministic: false })
        Some(msg) => (TestPassed(x), { ..run, log: run.log.add(msg) })
      }
    }
  }

  mk_property(fn(run) { g.fmap(aux(run)) })
}

///|
pub fn[T] test_gen(f : (T) -> Bool, gen : Gen[T]) -> Property[T, String] {
  fn aux(run : TestRun) {
    fn(a) {
      (
        match f(a) {
          true => TestPassed(a)
          false => TestFailed("Falsified")
        },
        { ..run, deterministic: false },
      )
    }
  }

  { run: fn(r) { gen.fmap(aux(r)) } }
}
