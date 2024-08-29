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
    ~coverage : Coverage,
    ~output : String
  )
  Fail(
    ~num_tests : Int,
    ~num_discarded : Int,
    ~num_shrinks : Int,
    ~num_shrink_tries : Int,
    ~num_shrink_final : Int,
    ~replay_info : Replay,
    ~reason : String,
    ~error : Error,
    ~output : String,
    ~failing_case : Array[String],
    ~failing_labels : Array[String],
    ~failing_classes : @sorted_set.T[String]
  )
  NoneExpectedFail(
    ~num_tests : Int,
    ~num_discarded : Int,
    ~coverage : Coverage,
    ~output : String
  )
  GaveUp(
    ~num_tests : Int,
    ~num_discarded : Int,
    ~coverage : Coverage,
    ~output : String
  )
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

pub fn quick_check_fn[A : Arbitrary + Shrink + Show, B : Testable](
  f : (A) -> B
) -> Unit {
  quick_check1(Arrow(f))
}

pub fn quick_check_with[P : Testable](cfg : Args, prop : P) -> Unit {
  quick_check_with_result(cfg, prop) |> ignore
}

pub fn quick_check_with_result[P : Testable](
  cfg : Args,
  prop : P
) -> TotalResult {
  run_test(from_config(cfg), prop.property())
}

pub fn run_test(self : State, prop : PropertyX) -> TotalResult {
  if self.finished_successfully() {
    self.complete_test(prop)
  } else if self.discarded_too_much() {
    self.give_up(prop)
  } else {
    self.run_single_test(prop)
  }
}

pub fn complete_test(self : State, _prop : PropertyX) -> TotalResult {
  // TODO: Print coverage
  if self.expected.not() {
    println("*** Failed! Expected failure, but passed \{self.test_count()}")
    NoneExpectedFail(
      num_tests=self.num_success_tests,
      num_discarded=self.num_discarded_tests,
      coverage=self.collects,
      output=self.static_writer.to_string(),
    )
  } else {
    println("+++ Ok, passed! \{self.test_count()}")
    Success(
      num_tests=self.num_success_tests,
      num_discarded=self.num_discarded_tests,
      coverage=self.collects,
      output=self.static_writer.to_string(),
    )
  }
}

pub fn give_up(self : State, _prop : PropertyX) -> TotalResult {
  println("*** Gave up! Passed only \{self.test_count()} tests.")
  // TODO: Print coverage
  GaveUp(
    num_tests=self.num_success_tests,
    num_discarded=self.num_discarded_tests,
    coverage=self.collects,
    output=self.static_writer.to_string(),
  )
}

pub fn run_single_test(self : State, prop : PropertyX) -> TotalResult {
  let rnd1 = self.random_state.split()
  let rnd2 = self.random_state
  let size = self.compute_size()
  let { val: res, branch: ts } = prop.property.run(size, rnd1).rose
  fn next(end_with, nst : State, p : PropertyX) {
    if res.abort {
      end_with(update_state(nst), p)
    } else {
      run_test(update_state(nst), p)
    }
  }

  fn update_state(st0) {
    add_new_options({ ..st0, random_state: rnd2 })
  }

  fn add_coverages(st0 : State) -> Unit {
    match st0.collects.labels[res.labels] {
      Some(v) => st0.collects.labels[res.labels] = v + 1
      None => st0.collects.labels[res.labels] = 1
    }
  }

  fn add_new_options(st0 : State) {
    {
      ..st0,
      max_success_tests_: res.maybe_num_tests.or(st0.max_success_tests_),
      max_discarded_ratio_: res.maybe_discarded_ratio.or(
        st0.max_discarded_ratio_,
      ),
      max_test_size_: res.maybe_max_test_size.or(st0.max_test_size_),
      max_shrinks_: res.maybe_max_shrinks.or(st0.max_shrinks_),
      expected: res.expect,
    }
  }

  let stc = self.clone()
  add_coverages(stc)
  callback_post_test(self, res)
  match res {
    { ok: Some(true), .. } =>
      next(
        complete_test,
        {
          ..self,
          num_success_tests: self.num_success_tests + 1,
          num_recent_discarded_tests: 0,
        },
        prop,
      )
    { ok: Some(false), .. } => {
      let (n, tf, lf, res) = self.found_failure(res, ts)
      let output = self.static_writer.to_string()
      match res.expect.not() {
        true =>
          Success(
            num_tests=stc.num_success_tests + 1,
            num_discarded=stc.num_discarded_tests,
            coverage=stc.collects,
            ~output,
          )
        false =>
          Fail(
            error=res.error,
            replay_info=Replay::new(stc.random_state, size),
            num_tests=stc.num_success_tests + 1,
            num_discarded=stc.num_discarded_tests,
            num_shrinks=n,
            num_shrink_tries=tf,
            num_shrink_final=lf,
            reason=res.reason,
            ~output,
            failing_case=res.test_case.to_array(),
            failing_labels=res.labels.to_array(),
            failing_classes=@sorted_set.new(), // TODO: Add classes
          )
      }
    }
    { ok: None, .. } =>
      next(
        give_up,
        {
          ..self,
          num_discarded_tests: self.num_discarded_tests + 1,
          num_recent_discarded_tests: self.num_recent_discarded_tests + 1,
        },
        prop,
      )
  }
}

pub fn found_failure(
  self : State,
  res : SingleResult,
  ts : Iter[Rose[SingleResult]]
) -> (Int, Int, Int, SingleResult) {
  local_min({ ..self, num_try_shrinks: 0 }, res, ts)
}

pub fn local_min(
  self : State,
  res : SingleResult,
  ts : Iter[Rose[SingleResult]]
) -> (Int, Int, Int, SingleResult) {
  if self.num_success_shrinks + self.num_to_try_shrinks >= self.max_shrinks_ {
    local_min_found(self, res)
  } else {
    let t = ts.head()
    match t {
      Some({ val, branch }) => {
        self.callback_post_test(val)
        match val.ok {
          Some(false) => {
            self.num_success_shrinks += 1
            self.num_try_shrinks = 0
          }
          _ => {
            self.num_to_try_shrinks += 1
            self.num_try_shrinks += 1
          }
        }
        local_min(self, res, branch)
      }
      None => local_min_found(self, res)
    }
  }
}

pub fn local_min_found(
  st : State,
  res : SingleResult
) -> (Int, Int, Int, SingleResult) {
  // TODO: Print error
  (
    st.num_success_shrinks,
    st.num_to_try_shrinks - st.num_try_shrinks,
    st.num_try_shrinks,
    res,
  )
}


test "quick check" {
  let prop_rev = fn(l : List[Int]) {
    l.rev().rev() == l.rev()
  }
  quick_check_fn(prop_rev)
}