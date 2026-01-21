///|
using @list {type List}

///|
struct Printer {
  buf : &Logger
  mut ident : Int
}

///|
pub impl Default for Printer with default() {
  { buf: @buffer.new(), ident: 0 }
}

///|
pub fn Printer::from_buffer(buf : @buffer.Buffer) -> Printer {
  { buf, ident: 0 }
}

///|
pub fn Printer::ident(self : Printer, size? : Int = 2) -> Unit {
  self.ident += size
}

///|
pub fn Printer::unident(self : Printer) -> Unit {
  self.ident -= 1
}

///|
pub fn Printer::format(self : Printer, str : String) -> String {
  let mut s = ""
  for i = 0; i < self.ident; i = i + 1 {
    s += " "
  }
  s + str
}

///|
pub fn Printer::write_string(self : Printer, str : String) -> Unit {
  self.buf.write_string(self.format(str) + "\n")
}

///|
/// Internal State of Compiler
struct State {
  // Name of the test
  name : String
  // Printer that collects output of the test
  // static_writer : Printer
  // Top bound of test size (immutable, the argument of the Gen)
  mut max_test_size_ : Int
  // Maximum number of successful tests (immutable)
  mut max_success_tests_ : Int
  // Maximum ratio of discarded tests (immutable)
  // For instance if max_success_tests is 100 and max_discarded_ratio is 0.1
  // then the maximum number of discarded tests is 10
  mut max_discarded_ratio_ : Int
  // Maximum number of shrinks (immutable)
  mut max_shrinks_ : Int
  // Size of the test to start replaying from (immutable, the argument of the Gen)
  replay_start_size_ : Int?

  // Number of tests that have succeeded (mutable)
  num_success_tests : Int
  // Number of tests that have been discarded (mutable, total)
  num_discarded_tests : Int
  // Since last successful test, number of discarded tests (mutable)
  num_recent_discarded_tests : Int

  // Note that Map provides inner mutability hence we don't need to use mut tag.

  collects : Coverage
  // Expected result of the test
  mut expected : Expected
  // Current random state
  mut random_state : RandomState
  // Number of successful shrinks
  mut num_success_shrinks : Int
  // Number of shrinks tried since last successful shrink
  mut num_try_shrinks : Int
  // Number of shrinks failed (total)
  mut num_to_try_shrinks : Int
}

///|
fn from_config(cfg : Config) -> State {
  let rs = match cfg.replay {
    Some((rng, _)) => rng
    None => @splitmix.new()
  }
  {
    name: @utils.fresh_name(),
    // static_writer: Default::default(),
    max_test_size_: cfg.max_size,
    max_success_tests_: cfg.max_success,
    max_discarded_ratio_: cfg.max_discard_ratio,
    max_shrinks_: cfg.max_shrink,
    replay_start_size_: cfg.replay.map(fn(x) { x.1 }),
    num_success_tests: 0,
    num_discarded_tests: 0,
    num_recent_discarded_tests: 0,
    collects: Coverage::new(),
    expected: Success,
    random_state: rs,
    num_success_shrinks: 0,
    num_try_shrinks: 0,
    num_to_try_shrinks: 0,
  }
}

// Deep copy of the state

///|
fn State::clone(self : State) -> State {
  { ..self }
}

// Computes the test size from the state

///|
fn State::compute_size(self : State) -> Int {
  match self {
    {
      replay_start_size_: Some(x),
      num_success_tests: 0,
      num_recent_discarded_tests: 0,
      ..,
    } => x
    {
      max_success_tests_: mss,
      max_test_size_: mts,
      max_discarded_ratio_: mdr,
      num_success_tests: n,
      num_recent_discarded_tests: d,
      ..,
    } => {
      fn clamp(x, l, h) {
        @cmp.maximum(l, @cmp.minimum(x, h))
      }

      let dDenom = if mdr > 0 { clamp(mss * mdr / 3, 1, 10) } else { 1 }
      fn round_to(n, m) {
        n / m * m
      }

      if round_to(n, mts) + mts <= mss || n >= mss || mss % mts == 0 {
        @cmp.minimum(n % mts + d / dDenom, mts)
      } else {
        (n % mts * mts / (mss % mts) + d / dDenom) % mts
      }
    }
  }
}

///|
fn State::add_coverages(self : State, res : SingleResult) -> Unit {
  self.collects.label_incr(res.labels)
  self.collects.class_incr(res.classes)
}

///|
fn State::update_state_from_res(self : State, result : SingleResult) -> Unit {
  self.max_success_tests_ = result.maybe_num_tests.unwrap_or(
    self.max_success_tests_,
  )
  self.max_discarded_ratio_ = result.maybe_discarded_ratio.unwrap_or(
    self.max_discarded_ratio_,
  )
  self.max_test_size_ = result.maybe_max_test_size.unwrap_or(
    self.max_test_size_,
  )
  self.max_shrinks_ = result.maybe_max_shrinks.unwrap_or(self.max_shrinks_)
  self.expected = result.expect
}

///|
fn State::finished_successfully(self : State) -> Bool {
  self.num_success_tests >= self.max_success_tests_
}

///|
fn State::discarded_too_much(self : State) -> Bool {
  if self.max_discarded_ratio_ > 0 {
    self.num_discarded_tests / self.max_discarded_ratio_ >=
    @cmp.maximum(self.num_success_tests, self.max_success_tests_)
  } else {
    false
  }
}

///|
fn State::callback_post_test(self : State, res : SingleResult) -> Unit {
  res.callbacks.each(fn(cb) {
    match cb {
      PostTest(_, f) => f(self, res)
      _ => ()
    }
  })
}

///|
fn State::callback_post_final_failure(self : State, res : SingleResult) -> Unit {
  res.callbacks.each(fn(cb) {
    match cb {
      PostFinalFailure(_, f) => f(self, res)
      _ => ()
    }
  })
}

///|
fn State::counts(self : State) -> String {
  "[\{self.num_success_tests}/\{self.num_discarded_tests}/\{self.max_success_tests_}]"
}

///|
priv struct ListCompare[T](List[T]) derive(Eq)

///|
impl[T : Compare] Compare for ListCompare[T] with compare(self, other) {
  match (self.0, other.0) {
    (More(x, tail=xs), More(y, tail=ys)) => {
      let res = T::compare(x, y)
      if res == 0 {
        Compare::compare(ListCompare(xs), ListCompare(ys))
      } else {
        res
      }
    }
    (More(_), Empty) => 1
    (Empty, More(_)) => -1
    (Empty, Empty) => 0
  }
}

// Labels / Classes / Tables are used to collect statistics of the test
// TODO : Maybe a more general way to collect infos (use typeclass?)

///|
priv struct Coverage {
  // Note that List[String] is not hashable, so we use ListCompare[String]
  // and sorted_map instead
  labels : @sorted_map.SortedMap[ListCompare[String], Int]
  classes : Map[String, Int]
}

///|
fn Coverage::new() -> Coverage {
  { labels: @sorted_map.new(), classes: Map::new() }
}

///|
fn Coverage::label_incr(self : Coverage, key : List[String]) -> Unit {
  match self.labels.get(key) {
    Some(x) => self.labels[key] = x + 1
    None => self.labels[key] = 1
  }
}

///|
fn Coverage::class_incr(
  self : Coverage,
  classes : List[(String, Bool)],
) -> Unit {
  classes.each(item => {
    let (s, b) = item
    let i = if b { 1 } else { 0 }
    match self.classes.get(s) {
      Some(x) => self.classes[s] = x + i
      None => self.classes[s] = i
    }
  })
}

///|
fn Coverage::label_to_string(self : Coverage, success : Int) -> String {
  let res = []
  self.labels.each(fn(list, i) {
    if list.0.is_empty() {
      return
    } else {
      let l = list.0.to_array().join(", ")
      res.push("\{i.to_double() / success.to_double () * 100}% : \{l}")
    }
  })
  res.join("\n")
}

///|
fn Coverage::class_to_string(self : Coverage, success : Int) -> String {
  let res = []
  self.classes.each(fn(s, i) {
    res.push("\{i.to_double() / success.to_double() * 100}% : \{s}")
  })
  res.join("\n")
}

///|
fn Coverage::to_string(self : Coverage, success : Int) -> String {
  let res = [
      if self.labels.length() == 0 {
        ""
      } else {
        self.label_to_string(success)
      },
      if self.classes.length() == 0 {
        ""
      } else {
        self.class_to_string(success)
      },
    ]
    .filter(x => x != "")
    .join("\n")
  guard res != "" else { "" }
  "\n\{res}"
}

///|
/// Configuration for initializing a test runner.
struct Config {
  replay : (RandomState, Int)?
  max_success : Int
  max_discard_ratio : Int
  max_size : Int
  max_shrink : Int
}
