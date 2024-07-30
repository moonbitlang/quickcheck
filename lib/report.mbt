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
  match report.ok {
    true => {
      println("All tests passed")
    }
    false => {
      let (succ, total) = report.count
      let style = { color: "red", bold: true, italic: false }
      let buffer = Buffer::new()
      println("Success \(succ) out of \(total)")
      (report.print.unwrap())(style, buffer)
      println(buffer.to_string())
    }
  }
}