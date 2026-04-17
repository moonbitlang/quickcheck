///|
struct Success[T] {
  result : T
  seed : RandomState
  run : TestRun
}

///|
impl[T : Show] Show for Success[T] with output(self, logger) {
  logger
  ..write_string("{result: ")
  ..write_object(self.result)
  ..write_string(", seed: ")
  ..write_object(self.seed)
  ..write_string(", run: ")
  ..write_object(self.run)
  .write_string("}")
}

///|
struct Failure[E] {
  seed : RandomState
  run : ShrinkExplain[(E, TestRun), TestRun]
}

///|
impl[E : Show] Show for Failure[E] with output(self, logger) {
  logger
  ..write_string("{seed: ")
  ..write_object(self.seed)
  ..write_string(", run: ")
  ..write_object(self.run)
  .write_string("}")
}

///|
struct Config {
  tests : Int
  max_shrinks : Int
  replay : RandomState?
  max_ratio : Int
  verbose : Bool
  expect_failure : Bool
}

///|
impl Show for Config with output(self, logger) {
  logger
  ..write_string("{tests: ")
  ..write_object(self.tests)
  ..write_string(", max_shrinks: ")
  ..write_object(self.max_shrinks)
  ..write_string(", replay: ")
  ..write_object(self.replay)
  ..write_string(", max_ratio: ")
  ..write_object(self.max_ratio)
  ..write_string(", verbose: ")
  ..write_object(self.verbose)
  ..write_string(", expect_failure: ")
  ..write_object(self.expect_failure)
  .write_string("}")
}

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
/// Seed a `DriverState[T]` from the configuration: fresh RNG (or the
/// replay seed if one was supplied), no successes yet, `todo` equal
/// to the target test count, and no discards.
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
/// Run `prop` under `opt` and return the outcome:
///
/// - the seed that was used (so callers can replay),
/// - the list of successful runs observed (one entry per passing test),
/// - the total number of discards encountered,
/// - `Some(failure)` if a counter-example was found and shrunk,
///   `None` otherwise.
///
/// This is Falsify's top-level entry point. The loop stops on the
/// first of:
/// - a failing test (then `shrink_from` minimises it before
///   returning),
/// - `opt.tests` successes,
/// - an exhausted discard budget,
/// - a *single* successful deterministic run — properties whose
///   result is fully determined by the sample tree short-circuit
///   after one pass (no point re-running them).
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
          let explain = sf.e_fmap(t => t.1).limit_steps(Some(opt.max_shrinks))
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

///|
test "show impls" {
  let _ : (Config) -> String = Show::to_string
  let _ : (Success[Int]) -> String = Show::to_string
  let _ : (Failure[Int]) -> String = Show::to_string
}
