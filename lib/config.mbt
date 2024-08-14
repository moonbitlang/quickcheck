struct Config {
  name : String
  seed : UInt64
  max_shrink : Int
  max_test : Int
}

pub fn with_name(name : String) -> Config {
  { ..Default::default(), name, }
}

pub fn with_max_test(max_test : Int) -> Config {
  { ..Default::default(), max_test, }
}

pub fn with_max_shrink(max_shrink : Int) -> Config {
  { ..Default::default(), max_shrink, }
}

impl Default for Config with default() {
  { seed: 37, name: @utils.fresh_name(), max_shrink: 100, max_test: 100 }
}
