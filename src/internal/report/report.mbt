///|
/// The aggregated outcome of a QuickCheck run: a `TestSuccess` on the
/// happy path, a `TestError` when the property failed (or was given
/// up on, or unexpectedly passed). Wrapped as a newtype so renderers
/// can hang as methods.
pub(all) struct CheckReport(Result[TestSuccess, TestError])

///|
/// Successful test outcomes — either the property passed
/// `max_success` times, or it gave up but the user `expect`ed that.
pub(all) enum TestSuccess {
  Success(num_tests~ : Int, coverage~ : @state.Coverage, output~ : String)
}

///|
/// Failure outcomes the driver can `raise`. `Fail` carries the
/// shrunk counter-example and shrink tally; `GaveUp` reports a run
/// that exhausted its discard budget; `NoneExpectedFail` is raised
/// when the user `expect=Fail` but the property kept passing.
pub(all) suberror TestError {
  Fail(
    num_tests~ : Int,
    num_discarded~ : Int,
    num_shrinks~ : Int,
    num_shrink_tries~ : Int,
    num_shrink_final~ : Int,
    reason~ : String,
    error~ : Error,
    output~ : String,
    coverage~ : @state.Coverage,
    failing_case~ : Array[String],
    failing_labels~ : Array[String],
    failing_classes~ : @sorted_set.SortedSet[String]
  )
  GaveUp(
    num_tests~ : Int,
    num_discarded~ : Int,
    coverage~ : @state.Coverage,
    output~ : String
  )
  NoneExpectedFail(
    num_tests~ : Int,
    num_discarded~ : Int,
    coverage~ : @state.Coverage,
    output~ : String
  )
}

///|
/// Format the report as a human-readable string. `verbose=true`
/// expands the failure block with labels, classes, shrink counts,
/// and full coverage.
pub fn CheckReport::render(self : Self, verbose? : Bool = false) -> String {
  match self.0 {
    Ok(result) => render_success(result)
    Err(error) => render_error(error, verbose)
  }
}

///|
/// True when the report is a successful outcome.
pub fn CheckReport::is_ok(self : Self) -> Bool {
  self.0 is Ok(_)
}

///|
fn render_block(title : String, lines : Array[String]) -> String {
  guard !lines.is_empty() else { "" }
  let body = lines.join("\n")
  "\{title}:\n\{body}"
}

///|
fn render_success(result : TestSuccess) -> String {
  let lines : Array[String] = []
  match result {
    Success(output~, coverage~, num_tests~) => {
      lines.push(output)
      let rendered = coverage.to_string(num_tests)
      if rendered != "" {
        lines.push(rendered)
      }
    }
  }
  lines.join("\n")
}

///|
fn render_error(error : TestError, verbose : Bool) -> String {
  let lines : Array[String] = []
  match error {
    Fail(
      output~,
      coverage~,
      num_tests~,
      num_shrinks~,
      num_shrink_tries~,
      num_shrink_final~,
      failing_case~,
      failing_labels~,
      failing_classes~,
      ..
    ) => {
      lines.push(output)
      let counterexample = if verbose {
        render_block("Counterexample", failing_case)
      } else {
        failing_case.join("\n")
      }
      if counterexample != "" {
        lines.push(counterexample)
      }
      if verbose {
        let labels = render_block("Labels", failing_labels)
        if labels != "" {
          lines.push(labels)
        }
        let classes = render_block("Classes", failing_classes.to_array())
        if classes != "" {
          lines.push(classes)
        }
        lines.push(
          "Shrinks: \{num_shrinks} successful, \{num_shrink_tries} unsuccessful, \{num_shrink_final} final attempts",
        )
        let rendered = coverage.to_string(num_tests)
        if rendered != "" {
          lines.push("Coverage:\n\{rendered}")
        }
      }
    }
    GaveUp(output~, coverage~, num_tests~, ..) => {
      lines.push(output)
      let rendered = coverage.to_string(num_tests)
      if rendered != "" {
        lines.push(rendered)
      }
    }
    NoneExpectedFail(output~, coverage~, num_tests~, ..) => {
      lines.push(output)
      let rendered = coverage.to_string(num_tests)
      if rendered != "" {
        lines.push(rendered)
      }
    }
  }
  lines.join("\n")
}
