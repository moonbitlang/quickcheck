type! InternalError String

type Arrow[A, B] (A) -> B

type ArrowEffect[A, B] (A) -> B!Error

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

pub fn promote_rose[T](s : Rose[Gen[T]]) -> Gen[Rose[T]] {
  delay().fmap(fn(m) { s.fmap(m) })
}

struct SingleResult {
  ok : Bool?
  expect : Bool
  reason : String
  abort : Bool
  maybe_num_tests : Int?
  maybe_discarded_ratio : Int?
  maybe_max_shrinks : Int?
  maybe_max_test_size : Int?
  labels : List[String]
  classes : List[(String, Bool)]
  tables : List[(String, String)]
  test_case : @immut/array.T[String]
  error : Error
  callbacks : @immut/list.T[Callback]
} derive(Show)

struct Prop {
  rose : Rose[SingleResult]
}

pub fn Prop::make(rose : Rose[SingleResult]) -> Prop {
  { rose, }
}

struct PropertyX {
  property : Gen[Prop]
}

pub fn PropertyX::make(property : Gen[Prop]) -> PropertyX {
  { property, }
}

pub trait Testable {
  property(Self) -> PropertyX
}

enum Discard {
  Discard
}

impl Testable for PropertyX with property(self) { self }

impl Testable for Discard with property(_self) {
  rejected() |> Testable::property
}

impl Testable for Unit with property(_self) { succeed() |> Testable::property }

impl Testable for Prop with property(self) { { property: pure(self) } }

impl Testable for SingleResult with property(self) {
  { property: pure(Prop::make(@rose.pure(self))) }
}

impl Testable for Bool with property(self) {
  lift_bool(self) |> Testable::property
}

impl[P : Testable] Testable for Gen[P] with property(self) {
  PropertyX::make(self.bind(fn(p) { p.property().property }))
}

impl[P : Testable] Testable for P? with property(self) { lift_option(self) }

impl[P : Testable, A : Arbitrary + Shrink + Show] Testable for Arrow[A, P] with property(
  self
) {
  forall_show(self.0)
}

pub fn map_prop[P : Testable](prop : P, f : (Prop) -> Prop) -> PropertyX {
  prop.property().property.fmap(f) |> PropertyX::make
}

pub fn map_rose_result[P : Testable](
  prop : P,
  f : (Rose[SingleResult]) -> Rose[SingleResult]
) -> PropertyX {
  map_prop(prop, fn { { rose: un_prop } => Prop::make(f(un_prop)) })
}

pub fn map_total_result[P : Testable](
  prop : P,
  f : (SingleResult) -> SingleResult
) -> PropertyX {
  map_rose_result(prop, fn { rose => rose.fmap(f) })
}

impl Default for SingleResult with default() {
  {
    ok: None,
    expect: true,
    reason: "unknown",
    abort: false,
    maybe_num_tests: None,
    maybe_discarded_ratio: None,
    maybe_max_shrinks: None,
    maybe_max_test_size: None,
    labels: Nil,
    classes: Nil,
    tables: Nil,
    test_case: @immut/array.new(),
    error: InternalError("none"),
    callbacks: Nil,
  }
}

pub fn succeed() -> SingleResult {
  { ..Default::default(), ok: Some(true) }
}

pub fn failed() -> SingleResult {
  { ..Default::default(), ok: Some(false) }
}

pub fn rejected() -> SingleResult {
  { ..Default::default(), ok: None }
}

fn lift_bool(b : Bool) -> SingleResult {
  match b {
    true => succeed()
    false => { ..failed(), reason: "Falsified" }
  }
}

fn lift_option[T : Testable](opt : T?) -> PropertyX {
  match opt {
    None => rejected() |> Testable::property
    Some(x) => x.property()
  }
}

pub fn map_size[P : Testable](f : (Int) -> Int) -> (P) -> PropertyX {
  fn(p) { p.property().property.scale(f) |> PropertyX::make }
}

pub fn shrinking[P : Testable, T](
  shrinker : (T) -> Iter[T],
  x0 : T,
  pf : (T) -> P
) -> PropertyX {
  fn props(x) -> Rose[Gen[Prop]] {
    @rose.new(pf(x).property().property, shrinker(x).map(props))
  }

  let x = promote_rose(props(x0))
  x.fmap(fn(x) { x.fmap(fn { { rose } => rose }).join() |> Prop::make })
  |> PropertyX::make
}

pub fn callback[P : Testable](cb : Callback) -> (P) -> PropertyX {
  fn(p) {
    map_total_result(
      p,
      fn(res) { { ..res, callbacks: Cons(cb, res.callbacks) } },
    )
  }
}

pub fn label[P : Testable](s : String) -> (P) -> PropertyX {
  fn(p) {
    map_total_result(p, fn(res) { { ..res, labels: Cons(s, res.labels) } })
  }
}

pub fn collect[P : Testable, T : Show](t : T) -> (P) -> PropertyX {
  label(t.to_string())
}

pub fn classify[P : Testable](cond : Bool, s : String) -> (P) -> PropertyX {
  fn(p) {
    map_total_result(
      p,
      fn(res) { { ..res, classes: Cons((s, cond), res.classes) } },
    )
  }
}

pub fn counterexample[P : Testable](s : String) -> (P) -> PropertyX {
  fn(p) {
    let cb = callback(PostFinalFailure(CounterExample, fn(_st, _res) {  }))
    map_total_result(
      cb(p),
      fn(res) { { ..res, test_case: res.test_case.push(s) } },
    )
  }
}

pub fn implies[P : Testable](cond : Bool) -> (P) -> PropertyX {
  fn(p) {
    match cond {
      true => p.property()
      false => Testable::property(Discard)
    }
  }
}

pub fn forall[T : Testable, A : Arbitrary + Shrink](f : (A) -> T) -> PropertyX {
  spawn().bind(fn(x) { shrinking(A::shrink, x, f).property }) |> PropertyX::make
}

pub fn forall_show[T : Testable, A : Arbitrary + Shrink + Show](
  f : (A) -> T
) -> PropertyX {
  forall(fn(x : A) { counterexample(x.to_string())(f(x)) })
}

pub fn if_fail[P : Testable](f : () -> Unit) -> (P) -> PropertyX {
  callback(
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

// Modifies a property to make it terminate after the first test
pub fn terminate[P : Testable](p : P) -> PropertyX {
  map_total_result(p, fn(res) { { ..res, abort: true } })
}

pub fn with_max_successs[P : Testable](n : Int) -> (P) -> PropertyX {
  fn(p) { map_total_result(p, fn(res) { { ..res, maybe_num_tests: Some(n) } }) }
}

pub fn with_discarded_ratio[P : Testable](n : Int) -> (P) -> PropertyX {
  fn(p) {
    map_total_result(p, fn(res) { { ..res, maybe_discarded_ratio: Some(n) } })
  }
}

pub fn with_max_shrinks[P : Testable](n : Int) -> (P) -> PropertyX {
  fn(p) {
    map_total_result(p, fn(res) { { ..res, maybe_max_shrinks: Some(n) } })
  }
}

pub fn with_max_size[P : Testable](n : Int) -> (P) -> PropertyX {
  fn(p) {
    map_total_result(p, fn(res) { { ..res, maybe_max_test_size: Some(n) } })
  }
}
