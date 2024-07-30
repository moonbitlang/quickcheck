// Gen is a Monad

struct RandomState {
  rs : @random.RandomState
}

pub fn new() -> RandomState {
  { rs: @random.init_state(seed=37) }
}

pub fn split(self : RandomState) -> RandomState {
  { rs: @random.init_state(seed=self.rs.gen_int()) }
}

pub fn next(self : RandomState) -> Int {
  self.rs.gen_int()
}

pub fn bounds(self : RandomState) -> (Int, Int) {
  (0, 100)
}
