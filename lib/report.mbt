// For the report print function
struct Style {
  color : String
  bold: Bool
  italic: Bool
}

struct Report {
  ok: Bool
  count: (Int, Int) // (success, total)
  // The caller will invoke this function to print the report
  print: Option[(Style, Buffer) -> Unit]
}

pub fn summary(report : Report) -> Unit {
  let (succ, total) = report.count
  let succ_text = @chalk.color(total.to_string(), @chalk.Green)
  let failed_text = @chalk.color((total - succ).to_string(), @chalk.Red)
  let msg = "Total tests: \(total), passed: \(succ_text), failed: \(failed_text)"
  println(msg)
}