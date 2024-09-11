type! InternalError String

type Arrow[A, B] (A) -> B

typealias RoseRes = Rose[SingleResult]

typealias TestableArrow[P] = (P) -> Property

typealias CallbackFn = (State, SingleResult) -> Unit

typealias Rose[T] = @rose.Rose[T]

enum Callback {
  PostTest(Kind, CallbackFn)
  PostFinalFailure(Kind, CallbackFn)
} derive(Show)

enum Kind {
  CounterExample
  Nothing
} derive(Show)

fn promote_rose[T](s : Rose[Gen[T]]) -> Gen[Rose[T]] {
  delay().fmap(fn(m) { s.fmap(m) })
}

struct Property {
  property : Gen[RoseRes]
}

pub fn Property::make(property : Gen[RoseRes]) -> Property {
  { property, }
}

pub fn Property::run_prop(self : Property) -> Gen[RoseRes] {
  self.property
}

pub trait Testable {
  property(Self) -> Property
}

enum Discard {
  Discard
}

impl Testable for Property with property(self) { self }

impl Testable for Discard with property(_self) {
  rejected() |> Testable::property
}

impl Testable for Unit with property(_self) { succeed() |> Testable::property }

impl Testable for RoseRes with property(self) { { property: pure(self) } }

impl Testable for SingleResult with property(self) {
  { property: pure(@rose.pure(self)) }
}

impl Testable for Bool with property(self) {
  lift_bool(self) |> Testable::property
}

impl[P : Testable] Testable for Gen[P] with property(self) {
  Property::make(self.bind(fn(p) { p.property().property }))
}

impl[P : Testable] Testable for P? with property(self) { lift_option(self) }

impl[P : Testable, A : Arbitrary + Shrink + Show] Testable for Arrow[A, P] with property(
  self
) {
  forall_show(self._)
}

pub fn map_prop[P : Testable](prop : P, f : (RoseRes) -> RoseRes) -> Property {
  prop.property().property.fmap(f) |> Property::make
}

pub fn map_rose_result[P : Testable](
  prop : P,
  f : (Rose[SingleResult]) -> Rose[SingleResult]
) -> Property {
  map_prop(prop, f)
}

pub fn map_total_result[P : Testable](
  prop : P,
  f : (SingleResult) -> SingleResult
) -> Property {
  map_rose_result(prop, fn { rose => rose.fmap(f) })
}

fn lift_bool(b : Bool) -> SingleResult {
  match b {
    true => succeed()
    false => { ..failed(), reason: "Falsified." }
  }
}

fn lift_option[T : Testable](opt : T?) -> Property {
  match opt {
    None => rejected() |> Testable::property
    Some(x) => x.property()
  }
}

pub fn map_size[P : Testable](p : P, f : (Int) -> Int) -> Property {
  p.property().property.scale(f) |> Property::make
}

pub fn shrinking[P : Testable, T](
  shrinker : (T) -> Iter[T],
  x0 : T,
  pf : (T) -> P
) -> Property {
  fn props(x) -> Rose[Gen[RoseRes]] {
    @rose.new(pf(x).property().property, shrinker(x).map(props))
  }

  promote_rose(props(x0)).fmap(fn(x) { x.join() }) |> Property::make
}

pub fn callback[P : Testable](p : P, cb : Callback) -> Property {
  map_total_result(p, fn(res) { { ..res, callbacks: Cons(cb, res.callbacks) } })
}

/// Attaches a label to a test case
pub fn label[P : Testable](p : P, s : String) -> Property {
  map_total_result(p, fn(res) { { ..res, labels: Cons(s, res.labels) } })
}

/// Attaches a label (Show) to a test case
pub fn collect[P : Testable, T : Show](p : P, t : T) -> Property {
  p |> label(t.to_string())
}

/// Classifies a test case based on a condition
pub fn classify[P : Testable](p : P, cond : Bool, s : String) -> Property {
  map_total_result(
    p,
    fn(res) { { ..res, classes: Cons((s, cond), res.classes) } },
  )
}

/// Adds a string to the counterexample if the property fails
pub fn counterexample[P : Testable](p : P, s : String) -> Property {
  let cb = callback(p, PostFinalFailure(CounterExample, fn(_st, _res) {  }))
  map_total_result(cb, fn(res) { { ..res, test_case: Cons(s, res.test_case) } })
}

/// Filters a property based on a condition
pub fn filter[P : Testable](p : P, cond : Bool) -> Property {
  match cond {
    true => p.property()
    false => Testable::property(Discard)
  }
}

/// Run with an explicit generator
pub fn forall[T : Testable, A : Arbitrary + Shrink](f : (A) -> T) -> Property {
  spawn().bind(fn(x) { shrinking(A::shrink, x, f).property }) |> Property::make
}

/// Run with an explicit generator and show counterexamples
pub fn forall_show[T : Testable, A : Arbitrary + Shrink + Show](
  f : (A) -> T
) -> Property {
  forall(fn(x : A) { counterexample(f(x), x.to_string()) })
}

/// Adds a callback that will be called if the property fails
pub fn if_fail[P : Testable](p : P, f : () -> Unit) -> Property {
  callback(
    p,
    PostTest(
      Nothing,
      fn(_st, res) {
        match res.ok {
          Some(false) => f()
          _ => ()
        }
      },
    ),
  )
}

/// Modifies a property to make it terminate after the first test
pub fn terminate[P : Testable](p : P) -> Property {
  map_total_result(p, fn(res) { { ..res, abort: true } })
}

pub fn expect_fail[P : Testable](p : P) -> Property {
  map_total_result(p, fn(res) { { ..res, expect: false } })
}

pub fn with_max_success[P : Testable](p : P, n : Int) -> Property {
  map_total_result(p, fn(res) { { ..res, maybe_num_tests: Some(n) } })
}

pub fn with_discarded_ratio[P : Testable](p : P, n : Int) -> Property {
  map_total_result(p, fn(res) { { ..res, maybe_discarded_ratio: Some(n) } })
}

pub fn with_max_shrinks[P : Testable](p : P, n : Int) -> Property {
  map_total_result(p, fn(res) { { ..res, maybe_max_shrinks: Some(n) } })
}

pub fn with_max_size[P : Testable](p : P, n : Int) -> Property {
  map_total_result(p, fn(res) { { ..res, maybe_max_test_size: Some(n) } })
}
