/// Configuration for the test runner.
struct Config {
  // Name of the test
  name : String
  // Seed for the initial number generator
  seed : UInt64
  // Maximum number of shrink steps
  max_shrink : Int
  // Maximum number of tests
  max_test : Int
  // Whether to classify the test by a given classifier
}

impl Default for Config with default() {
  {
    seed: 37,
    name: @utils.fresh_name(),
    max_shrink: 100,
    max_test: 100,
  }
}

/// Create a new configuration with the given seed.
pub fn with_seed(seed : UInt64, ~cfg : Config = Default::default()) -> Config {
  { ..cfg, seed, }
}

/// Create a new configuration with the given name.
pub fn with_name(name : String, ~cfg : Config = Default::default()) -> Config {
  { ..cfg, name, }
}

/// Create a new configuration with the given maximum number of tests.
pub fn with_max_test(
  max_test : Int,
  ~cfg : Config = Default::default()
) -> Config {
  { ..cfg, max_test, }
}

/// Create a new configuration with the given maximum number of shrinks.
pub fn with_max_shrink(
  max_shrink : Int,
  ~cfg : Config = Default::default()
) -> Config {
  { ..cfg, max_shrink, }
}