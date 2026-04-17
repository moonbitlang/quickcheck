///|
type CheckReport = Result[TestSuccess, TestError]

///|
fn render_block(title : String, lines : Array[String]) -> String {
  guard !lines.is_empty() else { "" }
  let body = lines.join("\n")
  "\{title}:\n\{body}"
}

///|
fn render_coverage(coverage : Coverage, num_tests : Int) -> String {
  coverage.to_string(num_tests)
}

///|
fn render_success(result : TestSuccess) -> String {
  let lines : Array[String] = []
  match result {
    Success(output~, coverage~, num_tests~) => {
      lines.push(output)
      let rendered = render_coverage(coverage, num_tests)
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
      replay_info~,
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
        lines.push(replay_info.to_string())
        lines.push(
          "Shrinks: \{num_shrinks} successful, \{num_shrink_tries} unsuccessful, \{num_shrink_final} final attempts",
        )
        let rendered = render_coverage(coverage, num_tests)
        if rendered != "" {
          lines.push("Coverage:\n\{rendered}")
        }
      }
    }
    GaveUp(output~, coverage~, num_tests~, ..) => {
      lines.push(output)
      let rendered = render_coverage(coverage, num_tests)
      if rendered != "" {
        lines.push(rendered)
      }
    }
    NoneExpectedFail(output~, coverage~, num_tests~, ..) => {
      lines.push(output)
      let rendered = render_coverage(coverage, num_tests)
      if rendered != "" {
        lines.push(rendered)
      }
    }
  }
  lines.join("\n")
}

///|
fn render_report(report : CheckReport, verbose? : Bool = false) -> String {
  match report {
    Ok(result) => render_success(result)
    Err(error) => render_error(error, verbose)
  }
}
