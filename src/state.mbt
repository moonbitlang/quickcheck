///|
typealias List[T] = @immut/list.T[T]

///|
struct Printer {
  buf : &Logger
  mut ident : Int
}

///|
impl Default for Printer with default() {
  { buf: @buffer.new(), ident: 0 }
}

///|
pub fn Printer::from_buffer(buf : @buffer.T) -> Printer {
  { buf, ident: 0 }
}

///|
pub fn ident(self : Printer, size~ : Int = 2) -> Unit {
  self.ident += size
}

///|
pub fn unident(self : Printer) -> Unit {
  self.ident -= 1
}

///|
pub fn format(self : Printer, str : String) -> String {
  let mut s = ""
  for i = 0; i < self.ident; i = i + 1 {
    s += " "
  }
  s + str
}

///|
pub fn write_string(self : Printer, str : String) -> Unit {
  self.buf.write_string(self.format(str) + "\n")
}

///| Internal State of Compiler
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
  mut expected : Bool?
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
fn format_name(self : State, loc~ : ArgsLoc = _) -> String {
  "[\{self.name}] \{loc}"
}

///|
fn from_config(cfg : Config) -> State {
  let rs = match cfg.replay {
    Some((rng, _)) => rng
    None => @quickcheck/splitmix.new()
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
    expected: Some(true),
    random_state: rs,
    num_success_shrinks: 0,
    num_try_shrinks: 0,
    num_to_try_shrinks: 0,
  }
}

// Deep copy of the state
///|
fn clone(self : State) -> State {
  { ..self }
}

// Computes the test size from the state
///|
fn compute_size(self : State) -> Int {
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
      fn clamp {
        x, l, h => @math.maximum(l, @math.minimum(x, h))
      }

      let dDenom = if mdr > 0 { clamp(mss * mdr / 3, 1, 10) } else { 1 }
      fn round_to {
        n, m => n / m * m
      }

      if round_to(n, mts) + mts <= mss || n >= mss || mss % mts == 0 {
        @math.minimum(n % mts + d / dDenom, mts)
      } else {
        (n % mts * mts / (mss % mts) + d / dDenom) % mts
      }
    }
  }
}

///|
fn add_coverages(self : State, res : SingleResult) -> Unit {
  self.collects.label_incr(res.labels)
  self.collects.class_incr(res.classes)
}

///|
fn update_state_from_res(self : State, result : SingleResult) -> Unit {
  self.max_success_tests_ = result.maybe_num_tests.or(self.max_success_tests_)
  self.max_discarded_ratio_ = result.maybe_discarded_ratio.or(
    self.max_discarded_ratio_,
  )
  self.max_test_size_ = result.maybe_max_test_size.or(self.max_test_size_)
  self.max_shrinks_ = result.maybe_max_shrinks.or(self.max_shrinks_)
  self.expected = result.expect
}

///|
fn finished_successfully(self : State) -> Bool {
  self.num_success_tests >= self.max_success_tests_
}

///|
fn discarded_too_much(self : State) -> Bool {
  if self.max_discarded_ratio_ > 0 {
    self.num_discarded_tests / self.max_discarded_ratio_ >=
    @math.maximum(self.num_success_tests, self.max_success_tests_)
  } else {
    false
  }
}

///|
fn callback_post_test(self : State, res : SingleResult) -> Unit {
  res.callbacks.each(fn {
    PostTest(_, f) => f(self, res)
    _ => ()
  })
}

///|
fn callback_post_final_failure(self : State, res : SingleResult) -> Unit {
  res.callbacks.each(fn {
    PostFinalFailure(_, f) => f(self, res)
    _ => ()
  })
}

///|
fn counts(self : State) -> String {
  "[\{self.num_success_tests}/\{self.num_discarded_tests}/\{self.max_success_tests_}]"
}

///|
type ListCompare[T] List[T] derive(Eq, Show)

///|
impl[T : Compare] Compare for ListCompare[T] with compare(self, other) {
  match (self._, other._) {
    (Cons(x, xs), Cons(y, ys)) => {
      let res = T::compare(x, y)
      if res == 0 {
        Compare::compare(ListCompare(xs), ListCompare(ys))
      } else {
        res
      }
    }
    (Cons(_), Nil) => 1
    (Nil, Cons(_)) => -1
    (Nil, Nil) => 0
  }
}

// Labels / Classes / Tables are used to collect statistics of the test
// TODO : Maybe a more general way to collect infos (use typeclass?)

///|
struct Coverage {
  // Note that List[String] is not hashable, so we use ListCompare[String]
  // and sorted_map instead
  labels : @sorted_map.T[ListCompare[String], Int]
  classes : Map[String, Int]
}

///|
fn Coverage::new() -> Coverage {
  { labels: @sorted_map.new(), classes: Map::new() }
}

///|
fn label_incr(self : Coverage, key : List[String]) -> Unit {
  match self.labels[key] {
    Some(x) => self.labels[key] = x + 1
    None => self.labels[key] = 1
  }
}

///|
fn class_incr(self : Coverage, classes : List[(String, Bool)]) -> Unit {
  classes.each(fn {
    (s, b) => {
      let i = if b { 1 } else { 0 }
      match self.classes[s] {
        Some(x) => self.classes[s] = x + i
        None => self.classes[s] = i
      }
    }
  })
}

///|
fn label_to_string(self : Coverage, success : Int) -> String {
  let res = []
  self.labels.each(fn(list, i) {
    if list._.is_empty() {
      return
    } else {
      let l = String::concat(list._.to_array(), separator=", ")
      res.push("\{i.to_double() / success.to_double () * 100}% : \{l}")
    }
  })
  String::concat(res, separator="\n")
}

///|
fn class_to_string(self : Coverage, success : Int) -> String {
  let res = []
  self.classes.each(fn(s, i) {
    res.push("\{i.to_double() / success.to_double() * 100}% : \{s}")
  })
  String::concat(res, separator="\n")
}

///|
fn to_string(self : Coverage, success : Int) -> String {
  String::concat(
    [
      if self.labels.size() == 0 {
        ""
      } else {
        self.label_to_string(success)
      },
      if self.classes.size() == 0 {
        ""
      } else {
        self.class_to_string(success)
      },
    ].filter(fn(x) { x != "" }),
    separator="\n",
  )
}
