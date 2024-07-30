struct Report[T] {
  name : String?
  failure_cases : Array[(T, Int)]?
  count : (Int, Int) // (Success, Total)
  distribution : Map[String, Int]? // distribution of the test cases (Label, Count)
}

pub fn summary[T : Show](self : Report[T]) -> Unit {
  let (succ, total) = self.count
  let name = self.name
  let succ_text = @chalk.color(total.to_string(), @chalk.Green)
  let failed_text = @chalk.color((total - succ).to_string(), @chalk.Red)
  let msg = "[\(name)] Total tests: \(total), passed: \(succ_text), failed: \(failed_text)"
  self.distribution.map(
    fn(map) {
      println("Distribution:")
      map.each(
        fn(k, v) {
          let r = Double::from_int(v) / Double::from_int(total)
          println("  \(k): \(r)")
        },
      )
    },
  )
  |> ignore
  match self.failure_cases {
    None => println(msg)
    Some(failed) => {
      println(msg)
      println("Failed cases:")
      failed.each(
        fn(x) {
          let (v, i) = x
          println("After \(i) shrinking: \(v)")
        },
      )
    }
  }
}
