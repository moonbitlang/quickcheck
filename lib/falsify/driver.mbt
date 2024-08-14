struct Success[T] {
  result : T
  seed : RandomState
  run : TestRun
} derive(Show)

struct Failure[E] {
  seed : RandomState
  run : ShrinkExplain[(E, TestRun), TestRun]
} derive(Show)

struct Config {
  tests : Int
  max_shrinks : Int
  replay : RandomState?
  max_ratio : Int
  verbose : Bool
  expect_failure : Bool
} derive(Show)

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

struct DriverState[T] {
  rng : RandomState
  success : List[Success[T]]
  todo : Int
  discarded : Int
  total_discard : Int
}

fn append_success[T](
  rng : RandomState,
  success : Success[T],
  acc : DriverState[T]
) -> DriverState[T] {
  {
    ..acc,
    rng,
    success: Cons(success, acc.success),
    todo: acc.todo - 1,
    discarded: 0,
  }
}

pub fn init_state[T](opt : Config) -> DriverState[T] {
  {
    rng: opt.replay.or(RandomState::new()),
    success: Nil,
    todo: opt.tests,
    discarded: 0,
    total_discard: 0,
  }
}

fn result_is_valid_shrink[T, E](
  ra : (TestResult[T, E], TestRun)
) -> IsValidShrink[(E, TestRun), (T?, TestRun)] {
  let (res, run) = ra
  match res {
    TestFailed(e) => Valid((e, run))
    TestDiscarded => Invalid((None, run))
    TestPassed(a) => Invalid((Some(a), run))
  }
}

// (replay, total discarded, failed?)
pub fn falsify[T, E](
  opt : Config,
  prop : Property[T, E]
) -> (RandomState, List[Success[T]], Int, Failure[E]?) {
  let st : DriverState[T] = init_state(opt)
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
              (Nil, 0) => (Cons(success, Nil), 0, None)
              _ => abort("impossible")
            }
          } else {
            go(append_success(later, success, acc))
          }
        }
        TestFailed(e) => {
          let sf = shrink_from(
            run_property(prop),
            result_is_valid_shrink,
            ((e, run), shrunk),
          )
          let explain = limit_steps(
            sf.e_fmap(@tuple.snd),
            Some(opt.max_shrinks),
          )
          let failure = { seed: acc.rng.clone(), run: explain }
          (acc.success, acc.total_discard, Some(failure))
        }
        _ => abort("todo: discard")
      }
    }
  }

  let (success, discarded, failed) = go(st)
  (st.rng, success, discarded, failed)
}
