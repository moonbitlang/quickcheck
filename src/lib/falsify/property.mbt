pub typealias List[T] = @immut/list.T[T]

pub typealias Map[K, V] = @immut/hashmap.T[K, V]

struct TestRun {
  log : List[String]
  deterministic : Bool
  labels : Map[String, @sorted_set.T[String]]
} derive(Show)

pub fn init_test_run() -> TestRun {
  { log: Nil, deterministic: true, labels: Map::new() }
}

enum TestResult[T, E] {
  TestPassed(T)
  TestFailed(E)
  TestDiscarded
}

struct Property[T, E] {
  run : (TestRun) -> Gen[(TestResult[T, E], TestRun)]
}

pub fn Property::run[T, E](
  self : Property[T, E],
  tr : TestRun
) -> Gen[(TestResult[T, E], TestRun)] {
  (self.run)(tr)
}

pub fn mk_property[T, E](
  run : (TestRun) -> Gen[(TestResult[T, E], TestRun)]
) -> Property[T, E] {
  { run, }
}

pub fn run_property[T, E](
  p : Property[T, E]
) -> Gen[(TestResult[T, E], TestRun)] {
  p.run(init_test_run())
}

pub fn discard[T, E]() -> Property[T, E] {
  mk_property(fn(run) { pure((TestDiscarded, run)) })
}

pub fn info(msg : String) -> Property[Unit, String] {
  mk_property(
    fn(run) { pure((TestPassed(()), { ..run, log: Cons(msg, run.log) })) },
  )
}

pub fn label[E](label : String, vals : List[String]) -> Property[Unit, E] {
  fn add_values(x : @sorted_set.T[String]?) -> @sorted_set.T[String] {
    let s = x.or(@sorted_set.new())
    s.union(@sorted_set.from_iter(vals.iter()))
  }

  mk_property(
    fn(r) {
      let set = r.labels[label]
      pure(
        (TestPassed(()), { ..r, labels: r.labels.add(label, add_values(set)) }),
      )
    },
  )
}

pub fn collect[T : Show, E](l : String, ls : List[T]) -> Property[Unit, E] {
  label(l, ls.map(Show::to_string))
}

// Running Generators
pub fn gen[T, E](f : (T) -> String?, g : Gen[T]) -> Property[T, E] {
  fn aux(run : TestRun) -> (T) -> (TestResult[T, E], TestRun) {
    fn {
      x =>
        match f(x) {
          None => (TestPassed(x), { ..run, deterministic: false })
          Some(msg) => (TestPassed(x), { ..run, log: Cons(msg, run.log) })
        }
    }
  }

  mk_property(fn(run) { g.fmap(aux(run)) })
}

pub fn test_gen[T](f : (T) -> Bool, gen : Gen[T]) -> Property[T, String] {
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
