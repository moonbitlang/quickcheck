// ========================================================================
//  Chainable `Property` methods.
//
//  These are the canonical, dot-callable form of the library's
//  decoration combinators:
//
//      forall(gen, prop)
//        .counterexample("after shrink")
//        .classify(n > 100, "big")
//        .collect(category)
//        .label("first pass")
//
//  Because `forall` and friends return `Property`, chains can start
//  right from a constructor. For a non-`Property` start (e.g. a bare
//  `Bool` or a `Gen[Bool]`), add an explicit `.property()` hop first:
//
//      some_bool.property().classify(...).label(...)
//
//  MoonBit doesn't yet allow dot-call on trait methods for concrete
//  types, so the methods live on `Property` rather than on the
//  `Testable` trait itself.
// ========================================================================

///|
/// Attach a label to the current test run. See the deprecated `label`
/// free function for the raw-expression form.
pub fn Property::label(self : Property, s : String) -> Property {
  Property(
    run_prop(self).fmap(rose => {
      rose.fmap(res => { ..res, labels: res.labels.add(s) })
    }),
  )
}

///|
/// Attach a `Show`-formatted label to the current test run. Shorthand
/// for `self.label(t.to_string())`.
pub fn[T : Show] Property::collect(self : Property, t : T) -> Property {
  self.label(t.to_string())
}

///|
/// Classify the current test run by a boolean condition.
pub fn Property::classify(self : Property, cond : Bool, s : String) -> Property {
  Property(
    run_prop(self).fmap(rose => {
      rose.fmap(res => { ..res, classes: res.classes.add((s, cond)) })
    }),
  )
}

///|
/// Append to the counter-example report that the driver prints when
/// the property's shrink-minimised witness fails.
pub fn Property::counterexample(self : Property, s : String) -> Property {
  let with_cb = self.callback(
    PostFinalFailure(CounterExample, (_st, _res) => ()),
  )
  Property(
    run_prop(with_cb).fmap(rose => {
      rose.fmap(res => { ..res, test_case: res.test_case.add(s) })
    }),
  )
}

///|
/// Discard the current input unless `cond` holds — short-circuits the
/// property to `Discard::default()` when `cond` is false.
pub fn Property::filter(self : Property, cond : Bool) -> Property {
  match cond {
    true => self
    false => Discard::default().property()
  }
}

///|
/// Attach a driver callback (post-test or post-final-failure hook).
pub fn Property::callback(self : Property, cb : Callback) -> Property {
  Property(
    run_prop(self).fmap(rose => {
      rose.fmap(res => { ..res, callbacks: res.callbacks.add(cb) })
    }),
  )
}

///|
/// Register a function to run when this property fails (post-final-failure).
pub fn Property::if_fail(self : Property, f : () -> Unit) -> Property {
  self.callback(
    PostTest(Nothing, (_st, res) => {
      guard res.status is Failed else { () }
      f()
    }),
  )
}

///|
/// Scale the size parameter threaded through the underlying generator.
pub fn Property::map_size(self : Property, f : (Int) -> Int) -> Property {
  Property(run_prop(self).scale(f))
}

///|
/// Demonstrate the chainable form on a `Property` returned by `forall`.
test "Property decorator methods chain in dot-call style" {
  let prop = forall(@gen.int_range(0, 100), (x : Int) => x >= 0)
    .counterexample("x should be non-negative")
    .classify(true, "checked")
    .label("range-0-100")
  quick_check(prop)
}
