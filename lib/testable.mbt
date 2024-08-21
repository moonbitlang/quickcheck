/// Internal State of Compiler
struct State {
  max_test_size : Int
  max_success_tests : Int
  max_discarded_ratio : Int
  num_to_max_shrinks : Int
  replay_start_size : Int?
  num_success_tests : Int
  num_discarded_tests : Int
  num_recent_discarded_tests : Int
  labels : Map[Array[String], Int]
  classes : Map[String, Int]
  tables : Map[String, Map[String, Int]]
  expected : Bool
  random_state : RandomState
  num_success_shrinks : Int
  num_try_shrinks : Int
  num_to_try_shrinks : Int
}

type! InternalError

enum Callback {
  PostTest(Kind, (State, SingleResult) -> Unit)
  PostFinalFailure(Kind, (State, SingleResult) -> Unit)
}

enum Kind {
  CounterExample
  Nothing
}

struct Rose[T] {
  val : T
  branch : Iter[Rose[T]]
}

pub fn join_rose[T](self : Rose[Rose[T]]) -> Rose[T] {
  let tss = self.branch
  let ts = self.val.branch
  { val: self.val.val, branch: tss.map(join_rose).concat(ts) }
}

pub fn pure_rose[T](val : T) -> Rose[T] {
  { val, branch: Iter::empty() }
}

pub fn promote_rose[T](self : Rose[Gen[T]]) -> Gen[Rose[T]] {
  delay().fmap(fn(m) { fmap_rose(self, m) })
}

pub fn fmap_rose[T, U](self : Rose[T], f : (T) -> U) -> Rose[U] {
  { val: f(self.val), branch: self.branch.map(fn(x) { fmap_rose(x, f) }) }
}

pub fn bind_rose[T, U](self : Rose[T], f : (T) -> Rose[U]) -> Rose[U] {
  join_rose(fmap_rose(self, f))
}

pub fn on_rose[T](self : Rose[T], f : (T, Iter[Rose[T]]) -> Rose[T]) -> Rose[T] {
  f(self.val, self.branch)
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
  labels : Array[String]
  classes : Array[(String, Bool)]
  tables : Array[(String, String)]
  test_case : @immut/array.T[String]
  error : Error
  callbacks : @immut/list.T[Callback]
}

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

type Arrow[A, B] (A) -> B

enum Discard {}

impl Testable for PropertyX with property(self) { self }

impl Testable for Discard with property(_self) {
  rejected() |> Testable::property
}

impl Testable for Unit with property(_self) { succeed() |> Testable::property }

impl Testable for Prop with property(self) { { property: pure(self) } }

impl Testable for SingleResult with property(self) {
  { property: pure(Prop::make(pure_rose(self))) }
}

impl Testable for Bool with property(self) {
  lift_bool(self) |> Testable::property
}

impl[P : Testable] Testable for Gen[P] with property(self) {
  PropertyX::make(self.bind(fn(p) { p.property().property }))
}

impl[P : Testable] Testable for P? with property(self) { lift_option(self) }

impl[P : Testable, A : Arbitrary + Shrink] Testable for Arrow[A, P] with property(
  self
) {
  forall(self.0)
}

pub fn map_prop[P : Testable](prop : P, f : (Prop) -> Prop) -> PropertyX {
  prop.property().property.fmap(f) |> PropertyX::make
}

pub fn map_rose_result[P : Testable](
  prop : P,
  f : (Rose[SingleResult]) -> Rose[SingleResult]
) -> PropertyX {
  map_prop(prop, fn { { rose: un_prop } => Prop::make(un_prop) })
}

pub fn map_total_result[P : Testable](
  prop : P,
  f : (SingleResult) -> SingleResult
) -> PropertyX {
  map_rose_result(prop, fn { rose => fmap_rose(rose, f) })
}

impl Default for SingleResult with default() {
  {
    ok: None,
    expect: false,
    reason: "dunno",
    abort: false,
    maybe_num_tests: None,
    maybe_discarded_ratio: None,
    maybe_max_shrinks: None,
    maybe_max_test_size: None,
    labels: [],
    classes: [],
    tables: [],
    test_case: @immut/array.new(),
    error: InternalError,
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

pub fn lift_bool(b : Bool) -> SingleResult {
  match b {
    true => succeed()
    false => { ..failed(), reason: "Falsified" }
  }
}

pub fn lift_option[T : Testable](opt : T?) -> PropertyX {
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
    { val: pf(x).property().property, branch: shrinker(x).map(props) }
  }

  let x = promote_rose(props(x0))
  x.fmap(
    fn(x) { x.fmap_rose(fn { { rose } => rose }) |> join_rose |> Prop::make },
  )
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

pub fn counterexample[P : Testable](s : String) -> (P) -> PropertyX {
  fn(p) {
    let cb = callback(PostFinalFailure(CounterExample, fn(st, _res) {  }))
    map_total_result(
      cb(p),
      fn(res) { { ..res, test_case: res.test_case.push(s) } },
    )
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
