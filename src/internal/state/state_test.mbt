///|
test "new single results do not contain an error" {
  assert_true(@state.failed().error is None)
  assert_true(@state.rejected().error is None)
  assert_true(@state.succeed().error is None)
}

///|
test "config seed initializes and is retained by state" {
  let state = @state.from_config({
    max_success: 1,
    max_discard_ratio: 1,
    max_size: 1,
    max_shrinks: 1,
    seed: 123,
  })
  let expected = @splitmix.new(seed=123)
  assert_eq(state.seed, 123)
  assert_eq(state.random_state.next_uint(), expected.next_uint())
}
