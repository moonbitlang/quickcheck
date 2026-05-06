///|
test "gen subpackage composes with root property api" {
  let prop = @qc.forall(@gen.int_range(-3, 3), x => x >= -3 && x < 3)
  inspect(
    @qc.quick_check_silence(prop),
    content=(
      #|+++ [100/0/100] Ok, passed!
    ),
  )
}
