struct Report[T] {
  name : String?
  failure_cases : Array[(T, Int)]?
  count : (Int, Int) // (Success, Total)
  distribution : Map[String, Int]? // distribution of the test cases (Label, Count)
}

pub fn is_success[T](self : Report[T]) -> Bool {
  self.count.0 == self.count.1
}

pub fn is_failure[T](self : Report[T]) -> Bool {
  self.is_success().not()
}

pub fn print_distribution[T](self : Report[T]) -> Unit {
  self.distribution.map(
    fn(map) {
      println("Distribution: ")
      map.each(
        fn(k, v) {
          let r = Double::from_int(v) / Double::from_int(self.count.1)
          println("  \(k): \(r)")
        },
      )
    },
  )
  |> ignore
}

pub fn print_failures[T : Show](self : Report[T]) -> Unit {
  match self.failure_cases {
    None => ()
    Some(failed) => {
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

pub fn summary[T : Show](self : Report[T]) -> Unit {
  let (succ, total) = self.count
  let name = self.name
  let succ_text = @chalk.Chalk(total.to_string()).color(@chalk.Green)
  let failed_text = @chalk.Chalk((total - succ).to_string()).color(@chalk.Red)
  let msg = "[\(name)] Total tests: \(total), passed: \(succ_text), failed: \(failed_text)"
  println(msg)
  self.print_distribution()
  self.print_failures()
}
