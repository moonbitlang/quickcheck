///|
/// Run the main QuickCheck loop: draw inputs, evaluate the property,
/// book-keep successes and discards, and on failure hand off to
/// `find_failure` for shrinking. Returns the `CheckReport`.
fn @state.State::run_test(
  self : @state.State,
  prop : Property,
) -> @report.CheckReport {
  CheckReport(
    try? (for state = self {
      let rnd1 = state.random_state.split()
      let rnd2 = state.random_state
      let res = prop.0.run(state.compute_size(), rnd1)
      let stc = state.clone()
      stc.add_coverages(res.val) // The failure should not be counted.
      state.callback_post_test(res.val)
      match res.val.status {
        Passed => {
          let ns = {
            ..stc,
            num_success_tests: state.num_success_tests + 1,
            num_recent_discarded_tests: 0,
          }
          state.random_state = rnd2
          ns.update_state_from_res(res.val)
          if res.val.abort || ns.finished_successfully() {
            break ns.complete_test(prop)
          } else if ns.discarded_too_much() {
            break ns.give_up(prop)
          } else {
            continue ns
          }
        }
        Failed => break state.find_failure(res.val, res.branch)
        Rejected => {
          let ns = {
            ..state,
            num_discarded_tests: state.num_discarded_tests + 1,
            num_recent_discarded_tests: state.num_recent_discarded_tests + 1,
          }
          state.random_state = rnd2
          ns.update_state_from_res(res.val)
          if res.val.abort {
            break ns.give_up(prop)
          } else if ns.finished_successfully() {
            break ns.complete_test(prop)
          } else if ns.discarded_too_much() {
            break ns.give_up(prop)
          } else {
            continue ns
          }
        }
      }
    }),
  )
}
