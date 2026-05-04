///|
/// Run a single test and return the Ok(result) if ended successfully, or Err(state) if it should continue.
fn @state.State::run_single_test(
  self : @state.State,
  prop : Property,
) -> Result[@report.TestSuccess, @state.State] raise @report.TestError {
  let rnd1 = self.random_state.split()
  let rnd2 = self.random_state
  let { val: res, branch: ts } = prop.0.run(self.compute_size(), rnd1)
  fn update_state(st0 : @state.State) {
    self.random_state = rnd2
    st0.update_state_from_res(res)
  }

  fn next(
    end_with : (@state.State, Property) -> @report.TestSuccess raise @report.TestError,
    next_state : @state.State,
    p : Property,
  ) raise @report.TestError {
    update_state(next_state)
    if res.abort {
      Ok(end_with(next_state, p))
    } else {
      Err(next_state)
    }
  }

  let stc = self.clone()
  stc.add_coverages(res) // The failure should not be counted.
  self.callback_post_test(res)
  match res.status {
    Passed =>
      next(
        @state.State::complete_test,
        {
          ..stc,
          num_success_tests: self.num_success_tests + 1,
          num_recent_discarded_tests: 0,
        },
        prop,
      )
    Failed => Ok(self.find_failure(res, ts))
    Rejected =>
      next(
        @state.State::give_up,
        {
          ..self,
          num_discarded_tests: self.num_discarded_tests + 1,
          num_recent_discarded_tests: self.num_recent_discarded_tests + 1,
        },
        prop,
      )
  }
}

///|
/// Run the main QuickCheck loop: draw inputs, evaluate the property,
/// book-keep successes and discards, and on failure hand off to
/// `find_failure` for shrinking. Returns the aggregated
/// `TestSuccess` or raises `TestError`.
fn @state.State::run_test(
  self : @state.State,
  prop : Property,
) -> @report.TestSuccess raise @report.TestError {
  for cur = self.run_single_test(prop) {
    match cur {
      Ok(res) => break res
      Err(ns) =>
        if ns.finished_successfully() {
          break ns.complete_test(prop)
        } else if ns.discarded_too_much() {
          break ns.give_up(prop)
        } else {
          continue ns.run_single_test(prop)
        }
    }
  }
}
