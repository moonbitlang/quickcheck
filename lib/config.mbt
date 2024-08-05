struct Config {
  name : String
  seed : UInt64
  max_shrink : Int
  max_test : Int
}

pub fn with_name(self : Config, name : String) -> Config {
  { ..self, name, }
}

pub fn with_max_test(self : Config, max_test : Int) -> Config {
  { ..self, max_test, }
}

pub fn with_max_shrink(self : Config, max_shrink : Int) -> Config {
  { ..self, max_shrink, }
}

impl Default for Config with default() {
  { seed: 37, name: fresh_name(), max_shrink: 100, max_test: 100 }
}
