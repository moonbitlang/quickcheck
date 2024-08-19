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

pub fn fmap_rose[T, U](self : Rose[T], f : (T) -> U) -> Rose[U] {
  { val: f(self.val), branch: self.branch.map(fn(x) { fmap_rose(x, f) }) }
}

pub fn bind_rose[T, U](self : Rose[T], f : (T) -> Rose[U]) -> Rose[U] {
  join_rose(fmap_rose(self, f))
}

pub fn on_rose[T](self : Rose[T], f : (T, Iter[Rose[T]]) -> Rose[T]) -> Rose[T] {
  f(self.val, self.branch)
}

struct QRes {
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
  test_case : Array[String]
}

struct Prop {
  rose : Rose[QRes]
}

pub fn Prop::make(rose : Rose[QRes]) -> Prop {
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

impl Testable for Prop with property(self) { { property: pure(self) } }

impl Testable for QRes with property(self) {
  { property: pure(Prop::make(pure_rose(self))) }
}

impl Testable for Bool with property(self) {
  lift_bool(self) |> Testable::property
}

impl[P : Testable] Testable for Gen[P] with property(self) {
  PropertyX::make(self.bind(fn(p) { p.property().property }))
}

impl[P : Testable] Testable for P? with property(self) { lift_option(self) }

pub fn map_prop[P : Testable](prop : P, f : (Prop) -> Prop) -> PropertyX {
  prop.property().property.fmap(f) |> PropertyX::make
}

pub fn map_rose_result[P : Testable](
  prop : P,
  f : (Rose[QRes]) -> Rose[QRes]
) -> PropertyX {
  map_prop(prop, fn { { rose: un_prop } => Prop::make(un_prop) })
}

pub fn map_total_result[P : Testable](
  prop : P,
  f : (QRes) -> QRes
) -> PropertyX {
  map_rose_result(prop, fn { rose => fmap_rose(rose, f) })
}

impl Default for QRes with default() {
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
    test_case: [],
  }
}

pub fn succeed() -> QRes {
  { ..Default::default(), ok: Some(true) }
}

pub fn failed() -> QRes {
  { ..Default::default(), ok: Some(false) }
}

pub fn rejected() -> QRes {
  { ..Default::default(), ok: None }
}

pub fn lift_bool(b : Bool) -> QRes {
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
