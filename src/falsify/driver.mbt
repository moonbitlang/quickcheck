///|
struct Success[T] {
  result : T
  seed : RandomState
  run : TestRun
} derive(Show)

///|
struct Failure[E] {
  seed : RandomState
  run : ShrinkExplain[(E, TestRun), TestRun]
} derive(Show)

///|
struct Config {
  tests : Int
  max_shrinks : Int
  replay : RandomState?
  max_ratio : Int
  verbose : Bool
  expect_failure : Bool
} derive(Show)

///|
pub impl Default for Config with default() {
  {
    tests: 100,
    max_shrinks: 100,
    replay: None,
    max_ratio: 10,
    verbose: false,
    expect_failure: false,
  }
}

///|
struct DriverState[T] {
  rng : RandomState
  success : List[Success[T]]
  todo : Int
  discarded : Int
  total_discard : Int
}

///|
fn[T] append_success(
  rng : RandomState,
  success : Success[T],
  acc : DriverState[T],
) -> DriverState[T] {
  {
    ..acc,
    rng,
    success: acc.success.add(success),
    todo: acc.todo - 1,
    discarded: 0,
  }
}

///|
pub fn[T] init_state(opt : Config) -> DriverState[T] {
  {
    rng: opt.replay.unwrap_or(@splitmix.new()),
    success: @list.empty(),
    todo: opt.tests,
    discarded: 0,
    total_discard: 0,
  }
}

///|
fn[T, E] result_is_valid_shrink(
  ra : (TestResult[T, E], TestRun),
) -> IsValidShrink[(E, TestRun), (T?, TestRun)] {
  let (res, run) = ra
  match res {
    TestFailed(e) => Valid((e, run))
    TestDiscarded => Invalid((None, run))
    TestPassed(a) => Invalid((Some(a), run))
  }
}

///|
pub fn[T, E] falsify(
  opt : Config,
  prop : Property[T, E],
) -> (RandomState, List[Success[T]], Int, Failure[E]?) {
  let st : DriverState[T] = init_state(opt)

  // Local function defined properly
  fn go(acc : DriverState[T]) -> (List[Success[T]], Int, Failure[E]?) {
    if acc.todo == 0 {
      (acc.success, acc.total_discard, None)
    } else {
      let later = acc.rng.split()
      let now = acc.rng
      let st = from_rng(now)
      let ((res, run), shrunk) = run_property(prop).run_gen(st)
      match res {
        TestPassed(x) => {
          let success : Success[T] = { result: x, seed: now.clone(), run }
          if run.deterministic {
            match (acc.success, acc.total_discard) {
              (Empty, 0) => (@list.singleton(success), 0, None)
              _ => abort("impossible")
            }
          } else {
            go(append_success(later, success, acc))
          }
        }
        TestFailed(e) => {
          let sf = run_property(prop).shrink_from(
            result_is_valid_shrink,
            ((e, run), shrunk),
          )
          // Correctly accessing tuple second element
          let explain = sf
            .e_fmap(fn(t) { t.1 })
            .limit_steps(Some(opt.max_shrinks))
          let failure = { seed: acc.rng.clone(), run: explain }
          (acc.success, acc.total_discard, Some(failure))
        }
        TestDiscarded => {
          let discarded = acc.discarded + 1
          let total_discard = acc.total_discard + 1
          let next = { ..acc, rng: later, discarded, total_discard }
          go(next)
        }
      }
    }
  }

  let (success, discarded, failed) = go(st)
  (st.rng, success, discarded, failed)
}
