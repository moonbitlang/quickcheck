///|
priv suberror RaisedForTest {
  RaisedForTest
}

///|
fn raise_for_test(_ : Int) -> Bool raise {
  raise RaisedForTest
}

///|
test "raising arrow stores the original error" {
  let property = ArrowError(raise_for_test).property()
  let result = property.run(0, Default::default()).val
  assert_true(result.error is Some(RaisedForTest))
}
