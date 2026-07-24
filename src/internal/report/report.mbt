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
    error~ : Error?,
    output~ : String,
    coverage~ : @state.Coverage,
    failing_case~ : Array[String],
    failing_labels~ : Array[String],
    failing_classes~ : @sorted_set.SortedSet[String],
    seed~ : UInt64
  )
  GaveUp(
    num_tests~ : Int,
    num_discarded~ : Int,
    coverage~ : @state.Coverage,
    output~ : String,
    seed~ : UInt64
  )
  NoneExpectedFail(
    num_tests~ : Int,
    num_discarded~ : Int,
    coverage~ : @state.Coverage,
    output~ : String,
    seed~ : UInt64
  )
}

///|
/// Format the report as a human-readable string. `verbose=true`
/// expands the failure block with its seed, labels, classes, shrink
/// counts, and full coverage.
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
      let coverage = render_block("Coverage", coverage.to_array(num_tests))
      lines.push(coverage)
    }
  }
  lines.filter(x => !x.is_empty()).join("\n")
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
      seed~,
      ..
    ) =>
      lines.append(
        [
          output,
          ..if verbose {
            [
              "Seed: \{seed}",
              render_block("Counterexample", failing_case),
              render_block("Labels", failing_labels), // labels
              render_block("Classes", failing_classes.to_array()), // classes
              "Shrinks: \{num_shrinks} successful, \{num_shrink_tries} unsuccessful, \{num_shrink_final} final attempts",
              render_block("Coverage", coverage.to_array(num_tests)),
            ]
          } else {
            failing_case
          },
        ],
      )
    GaveUp(output~, coverage~, num_tests~, seed~, ..) =>
      lines.append(
        [
          output,
          ..if verbose {
            ["Seed: \{seed}"]
          },
          render_block("Coverage", coverage.to_array(num_tests)),
        ],
      )
    NoneExpectedFail(output~, coverage~, num_tests~, seed~, ..) =>
      lines.append(
        [
          output,
          ..if verbose {
            ["Seed: \{seed}"]
          },
          render_block("Coverage", coverage.to_array(num_tests)),
        ],
      )
  }
  lines.filter(x => !x.is_empty()).join("\n")
}
