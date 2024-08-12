let global_counter : Ref[Int] = @ref.new(0)

fn fresh_name() -> String {
  let counter = global_counter.val
  @ref.update(global_counter, fn(x) { x + 1 })
  "test-" + counter.to_string()
}

pub fn check_one[T : Eq](config : Config, prop : Property[T]) -> TestResult[T] {
  let state = RandomState::new(seed=config.seed)
  let distribution = LabelRecord::make(prop.classify)
  let law = prop.law
  let mut test_ran = 0
  for c = 0; c < config.max_test; c = c + 1 {
    let arb = prop.generator.run(c, state)
    distribution.classify(arb) |> ignore
    if (prop.filter)(arb).not() {
      continue
    } else {
      let res = law(arb)
      test_ran += 1
      if res.not() {
        let shrunk = linear_shrink(
          config.max_shrink,
          prop.shrinker,
          law,
          init=arb,
        )
        break {
            name: config.name,
            success_count: test_ran,
            total_test_count: config.max_test,
            shrink_count: if shrunk.1 == arb {
              0
            } else {
              shrunk.0
            },
            outcome: Fail(shrunk.1),
            label: distribution,
            replay: Some({ rand_state: state }),
          }
      }
    }
  } else {
    {
      name: config.name,
      success_count: test_ran,
      total_test_count: config.max_test,
      shrink_count: 0,
      outcome: if test_ran == 0 {
        GaveUp
      } else {
        Success
      },
      label: distribution,
      replay: None,
    }
  }
}

pub fn quick_check[T : Arbitrary + Shrink + Eq](
  law : (T) -> Bool
) -> TestResult[T] {
  let prop = with_law(law)
  let config : Config = Default::default()
  check_one(config, prop)
}

pub fn check_verbose[T : Eq + Show](
  config : Config,
  prop : Property[T]
) -> TestResult[T] {
  let state = RandomState::new(seed=config.seed)
  let distribution = LabelRecord::make(prop.classify)
  let law = prop.law
  let mut test_ran = 0
  for c = 0; c < config.max_test; c = c + 1 {
    let arb = prop.generator.run(c, state)
    distribution.classify(arb) |> ignore
    if (prop.filter)(arb).not() {
      println("\{arb} filtered")
      continue
    } else {
      let res = law(arb)
      test_ran += 1
      if res.not() {
        println("\{arb} failed")
        let shrunk = linear_shrink(
          config.max_shrink,
          prop.shrinker,
          law,
          init=arb,
        )
        break {
            name: config.name,
            success_count: test_ran,
            total_test_count: config.max_test,
            shrink_count: if shrunk.1 == arb {
              0
            } else {
              shrunk.0
            },
            outcome: Fail(shrunk.1),
            label: distribution,
            replay: Some({ rand_state: state }),
          }
      } else {
        println("\{arb} passed")
      }
    }
  } else {
    {
      name: config.name,
      success_count: test_ran,
      total_test_count: config.max_test,
      shrink_count: 0,
      outcome: if test_ran == 0 {
        GaveUp
      } else {
        Success
      },
      label: distribution,
      replay: None,
    }
  }
}

pub fn quick_check_verbose[T : Arbitrary + Eq + Shrink + Show](
  law : (T) -> Bool
) -> TestResult[T] {
  let prop = with_law(law)
  let config : Config = Default::default()
  check_verbose(config, prop)
}

test "simple shrink" {
  quick_check(fn(x : Int) { x + 1 == x + 2 }).print()
  quick_check(fn(x : @immut/list.T[Int]) { @immut/list.Cons(1, x) == x }).print()
}

test "simple pass" {
  quick_check(fn(x : @immut/list.T[Int]) { x.rev().rev() == x }).print()
  // quick_check_verbose(fn(x : @immut/list.T[Int]) { x.rev().rev() == x }).print()
}

test "with classify" {
  check_verbose(
    with_name("reverse . reverse == id"),
    with_law(fn(x : @immut/list.T[Int]) { x.rev().rev() == x }).with_classify(
      fn(x) {
        match x {
          Nil => "nil"
          _ => "trivial"
        }
      },
    ),
  ).print()
}

test "all rejected" {
  check_verbose(
    with_max_test(10000),
    with_law(fn(x) { x == 1 }).with_filter(fn(_x) { false }),
  ).print()
}

test "with filter" {
  check_one(
    { ..Default::default(), max_test: 1000 },
    with_law(fn(x : @immut/list.T[Int]) { x.rev().rev() == x }).with_filter(
      fn(x) {
        match x {
          Nil => false
          _ => true
        }
      },
    ),
  ).print()
}
