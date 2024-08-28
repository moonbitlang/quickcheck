struct Printer {
  buf : Buffer
  mut ident : Int
}

impl Default for Printer with default() { { buf: Buffer::new(), ident: 0 } }

pub fn Printer::from_buffer(buf : Buffer) -> Printer {
  { buf, ident: 0 }
}

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
  self.buf.write_string(self.format(str) + "\n")
}

/// Internal State of Compiler
struct State {
  // Printer that collects output of the test
  static_writer : Printer
  // Top bound of test size (immutable, the argument of the Gen)
  max_test_size_ : Int
  // Maximum number of successful tests (immutable)
  max_success_tests_ : Int
  // Maximum ratio of discarded tests (immutable)
  // For instance if max_success_tests is 100 and max_discarded_ratio is 0.1
  // then the maximum number of discarded tests is 10
  max_discarded_ratio_ : Int
  // Maximum number of shrinks (immutable)
  max_shrinks_ : Int
  // Size of the test to start replaying from (immutable, the argument of the Gen)
  replay_start_size_ : Int?

  // Number of tests that have succeeded (mutable)
  mut num_success_tests : Int
  // Number of tests that have been discarded (mutable, total)
  mut num_discarded_tests : Int
  // Since last successful test, number of discarded tests (mutable)
  mut num_recent_discarded_tests : Int

  // Note that Map provides inner mutability hence we don't need to use mut tag.

  collects : Collects
  // Expected result of the test
  mut expected : Bool
  // Current random state
  mut random_state : RandomState
  // Number of successful shrinks
  mut num_success_shrinks : Int
  // Number of shrinks tried since last successful shrink
  mut num_try_shrinks : Int
  // Number of shrinks failed (total)
  mut num_to_try_shrinks : Int
}

// Labels / Classes / Tables are used to collect statistics of the test
// TODO : Maybe a more general way to collect infos (use typeclass?)

struct Collects {
  labels : Map[Array[String], Int]
  classes : Map[String, Int]
  tables : Map[String, Map[String, Int]]
}
