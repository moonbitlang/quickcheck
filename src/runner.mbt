///|
/// Run a single test and return the Ok(result) if ended successfully, or Err(state) if it should continue.
fn @state.State::run_single_test(
  self : @state.State,
  prop : Property,
) -> Result[@report.TestSuccess, @state.State] raise @report.TestError {
  let rnd1 = self.random_state.split()
  let rnd2 = self.random_state
  let { val: res, branch: ts } = prop.0.run(self.compute_size(), rnd1)

  fn next(
    next_state : @state.State,
    p : Property,    
    end_with : (@state.State, Property) -> @report.TestSuccess raise @report.TestError,

  ) raise @report.TestError {
    self.random_state = rnd2
    next_state.update_state_from_res(res)
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
        {
          ..stc,
          num_success_tests: self.num_success_tests + 1,
          num_recent_discarded_tests: 0,
        },
        prop,
        @state.State::complete_test,
      )
    Failed => Ok(self.find_failure(res, ts))
    Rejected =>
      next(
        {
          ..self,
          num_discarded_tests: self.num_discarded_tests + 1,
          num_recent_discarded_tests: self.num_recent_discarded_tests + 1,
        },        
        prop,        
        @state.State::give_up,
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
