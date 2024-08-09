pub enum Outcome[T] {
  Success
  GaveUp
  Fail(T) // Counterexample
}

pub fn to_string[T](self : Outcome[T]) -> String {
  match self {
    Fail(_) => @chalk.Chalk("FAIL").color(@chalk.Red).to_string()
    Success => @chalk.Chalk("OK").color(@chalk.Green).to_string()
    GaveUp => @chalk.Chalk("GAVE UP").color(@chalk.Yellow).to_string()
  }
}

pub fn output[T](self : Outcome[T], logger : Logger) -> Unit {
  logger.write_string(self.to_string())
}

pub struct Replay {
  rand_state : RandomState
}

struct LabelRecord[T] {
  classify : (T) -> String
  map : Map[String, Int]
}

pub fn LabelRecord::make[T](f : (T) -> String) -> LabelRecord[T] {
  { classify: f, map: Map::new() }
}

pub fn classify[T](self : LabelRecord[T], v : T) -> Unit {
  let label = (self.classify)(v)
  self.map[label] = self.map.get(label).map_or(1, fn(x) { x + 1 })
}

pub fn to_string[T : Show](self : LabelRecord[T]) -> Array[String] {
  let total = self.map.iter().fold(init=0, fn(acc, si) { acc + si.1 })
    |> Double::from_int
  self.map.iter().map(
    fn(si) {
      let (k, v) = si
      let r = Double::from_int(v) / total
      r.to_string() + ": " + k
    },
  ).to_array()
}

struct Printer {
  mut ident : Int
}

impl Default for Printer with default() { { ident: 0 } }

pub fn ident(self : Printer, ~size : Int = 2) -> Unit {
  self.ident += size
}

pub fn unident(self : Printer) -> Unit {
  self.ident -= 1
}

pub fn format(self : Printer, str : String) -> String {
  let mut s = ""
  for i = 0; i < self.ident; i = i + 1 {
    s += " "
  }
  s + str
}

pub fn print(self : Printer, str : String) -> Unit {
  println(self.format(str))
}

struct TestResult[T] {
  name : String
  success_count : Int
  total_test_count : Int
  shrink_count : Int
  outcome : Outcome[T]
  label : LabelRecord[T]
  replay : Replay?
}

pub fn print[T : Show](
  self : TestResult[T],
  ~pc : Printer = Default::default()
) -> Unit {
  let name = self.name
  pc.print("[\{name}]: " + self.outcome.to_string())
  pc.ident()
  match self.outcome {
    Fail(x) => {
      let ce = @chalk.Chalk(x.to_string()).color(@chalk.Red)
      let seed = self.replay.unwrap().rand_state
      let shrink_count = self.shrink_count
      pc.print(
        "There exist \{ce} (State=\{seed}) such that condition is false (after \{shrink_count} shrink(s))",
      )
    }
    Success => {
      let test_count = self.success_count
      let total_count = self.total_test_count
      pc.print("\{test_count}/\{total_count} tests completed")
    }
    GaveUp => pc.print("Gave up: no tests completed")
  }
  pc.ident()
  pc.print("Distribution: ")
  pc.ident()
  self.label.to_string().map(fn(x) { pc.print(x) }) |> ignore
  pc.unident()
}
