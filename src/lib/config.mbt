/// Configuration for initializing a test runner.
struct Config {
  replay : (RandomState, Int)?
  max_success : Int
  max_discard_ratio : Int
  max_size : Int
  max_shrink : Int
}

impl Default for Config with default() {
  {
    replay: None,
    max_success: 100,
    max_discard_ratio: 10,
    max_size: 100,
    max_shrink: 100,
  }
}
