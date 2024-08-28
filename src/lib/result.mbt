pub enum Outcome[T] {
  Success
  GaveUp
  Fail(T) // Counterexample
}

pub fn to_string[T](self : Outcome[T]) -> String {
  match self {
    Fail(_) => "FAIL"
    Success => "OK"
    GaveUp => "GAVE UP"
  }
}

pub fn to_string_colored[T](self : Outcome[T]) -> String {
  match self {
    Fail(_) => @chalk.chalk().color(@chalk.Red).render("FAIL")
    Success => @chalk.chalk().color(@chalk.Green).render("OK")
    GaveUp => @chalk.chalk().color(@chalk.Yellow).render("GAVE UP")
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
  self.map
  .iter()
  .map(
    fn(si) {
      let (k, v) = si
      let r = Double::from_int(v) / total
      r.to_string() + ": " + k
    },
  )
  .to_array()
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

pub fn to_string[T : Show](self : TestResult[T]) -> String {
  let pc : Printer = Default::default()
  let name = self.name
  pc.print("[\{name}]: " + self.outcome.to_string_colored())
  pc.ident()
  match self.outcome {
    Fail(x) => {
      let ce = @chalk.chalk().color(@chalk.Red).render(x)
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
  pc.buf.to_string()
}

pub fn output[T : Show](self : TestResult[T], logger : Logger) -> Unit {
  logger.write_string(self.to_string())
}
