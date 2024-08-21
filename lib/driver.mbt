struct Args {
  replay : (RandomState, Int)?
  max_success : Int
  max_discard_ratio : Int
  max_size : Int
  max_shrink : Int
}

impl Default for Args with default() {
  {
    replay: None,
    max_success: 100,
    max_discard_ratio: 10,
    max_size: 100,
    max_shrink: 100,
  }
}

enum TotalResult {
  Success(
    ~num_tests : Int,
    ~num_discarded : Int,
    ~labels : Map[Array[String], Int],
    ~classes : Map[String, Int]
  )
  Fail(~num_tests : Int, ~num_discarded : Int, ~num_shrinks : Int)
  NoneExpectedFail(
    ~num_tests : Int,
    ~num_discarded : Int,
    ~labels : Map[Array[String], Int],
    ~classes : Map[String, Int],
    ~tables : Map[String, Map[String, Int]],
    ~output : String
  )
  GaveUp
}

pub fn success(self : TotalResult) -> Bool {
  match self {
    Success(_) => true
    _ => false
  }
}

pub fn quick_check1[P : Testable](prop : P) -> Unit {
  quick_check_with(Default::default(), prop)
}

pub fn quick_check_with[P : Testable](cfg : Args, prop : P) -> Unit {
  quick_check_with_result(cfg, prop) |> ignore
}

pub fn quick_check_with_result[P : Testable](
  cfg : Args,
  prop : P
) -> TotalResult {
  with_state(cfg, fn(s) { run_test(s, prop.property()) })
}

pub fn with_state[T](cfg : Args, ts : (State) -> T) -> T {
  let rs = match cfg.replay {
    Some((rng, _)) => rng
    None => RandomState::new()
  }
  let state : State = {
    max_test_size: cfg.max_size,
    max_success_tests: cfg.max_success,
    max_discarded_ratio: cfg.max_discard_ratio,
    num_to_max_shrinks: 0,
    replay_start_size: cfg.replay.map(fn(x) { x.1 }),
    num_success_tests: 0,
    num_discarded_tests: 0,
    num_recent_discarded_tests: 0,
    labels: Map::new(),
    classes: Map::new(),
    tables: Map::new(),
    expected: true,
    random_state: rs,
    num_success_shrinks: 0,
    num_try_shrinks: 0,
    num_to_try_shrinks: 0,
  }
  ts(state)
}

pub fn run_test(st : State, prop : PropertyX) -> TotalResult {
  if st.num_success_tests >= st.max_success_tests {
    done_test(st, prop)
  } else if st.num_discarded_tests / st.max_discarded_ratio >=
    @math.maximum(st.num_success_tests, st.max_success_tests) {
    give_up(st, prop)
  } else {
    run_single_test(st, prop)
  }
}

pub fn done_test(st : State, prop : PropertyX) -> TotalResult {
  if st.expected.not() {
    println("*** Failed!")
  } else {
    println("+++ Ok, passed.")
  }
  abort("todo")
}

pub fn give_up(st : State, prop : PropertyX) -> TotalResult {
  println("*** Gave up!")
  abort("todo")
}

pub fn callback_post_test(st : State, res : SingleResult) -> Unit {
  res.callbacks.each(
    fn {
      PostTest(_, f) => f(st, res)
      _ => abort("callback_post_test: internal error")
    },
  )
}

pub fn run_single_test(st : State, prop : PropertyX) -> TotalResult {
  let rnd1 = st.random_state.split()
  let rnd2 = st.random_state
  let size = 1
  let { val: res, branch: ts } = prop.property.run(size, rnd1).rose
  fn next(end_with, nst : State) {
    fn(p) {
      if res.abort {
        end_with(update_state(nst), p)
      } else {
        run_test(update_state(nst), p)
      }
    }
  }

  fn update_state(st0) {
    add_new_options({ ..st0, random_state: rnd2 })
  }

  fn add_new_options(st0 : State) {
    {
      ..st0,
      max_success_tests: res.maybe_num_tests.or(st0.max_success_tests),
      max_discarded_ratio: res.maybe_discarded_ratio.or(st0.max_discarded_ratio),
      max_test_size: res.maybe_max_test_size.or(st0.max_test_size),
      num_to_max_shrinks: res.maybe_max_shrinks.or(st0.num_to_max_shrinks),
      expected: res.expect,
    }
  }

  callback_post_test(st, res)
  match res {
    { ok: Some(true), .. } =>
      next(
        done_test,
        {
          ..st,
          num_success_tests: st.num_success_tests + 1,
          num_recent_discarded_tests: 0,
        },
      )(prop)
    { ok: Some(false), .. } => abort("")
    { ok: None, .. } =>
      next(
        give_up,
        {
          ..st,
          num_discarded_tests: st.num_discarded_tests + 1,
          num_recent_discarded_tests: st.num_recent_discarded_tests + 1,
        },
      )(prop)
  }
}

pub fn found_failure(
  st : State,
  res : SingleResult,
  ts : Iter[SingleResult]
) -> (Int, Int, Int, SingleResult) {
  local_min({ ..st, num_try_shrinks: 0 }, res, ts)
}

pub fn local_min(
  st : State,
  res : SingleResult,
  ts : Iter[SingleResult]
) -> (Int, Int, Int, SingleResult) {
  if st.num_success_shrinks + st.num_to_try_shrinks >= st.num_to_max_shrinks {
    local_min_found(st, res)
  } else {
    abort("todo")
  }
}

pub fn local_min_found(
  st : State,
  res : SingleResult
) -> (Int, Int, Int, SingleResult) {
  // todo 
  (
    st.num_success_shrinks,
    st.num_to_try_shrinks - st.num_try_shrinks,
    st.num_try_shrinks,
    res,
  )
}
