///|
/// Simple tests demonstrating systematic testing concepts

// Test enum for demonstration
enum SmallBool {
  True
  False
} derive(Show, Eq)

// Implementation for the built-in Enumerable trait from systematic module

///|
impl Enumerable for SmallBool with enumerate() {
  [True, False]
}

///|
fn bool_value(b : SmallBool) -> Bool {
  match b {
    True => true
    False => false
  }
}

// Test 1: Basic tautology test

///|
test "tautology_always_passes" {
  let result = test_enumerable_property(fn(b : SmallBool) {
    bool_value(b) || not(bool_value(b))
  })
  if result.failures.length() != 0 {
    abort("Expected no failures")
  }
  if result.passed != 2 {
    abort("Expected 2 passed tests")
  }
}

// Test 2: Contradiction test

///|
test "contradiction_always_fails" {
  let result = test_enumerable_property(fn(b : SmallBool) {
    bool_value(b) && not(bool_value(b))
  })
  if result.failures.length() != 2 {
    abort("Expected 2 failures")
  }
  if result.passed != 0 {
    abort("Expected 0 passed tests")
  }
}

// Test 3: Partial failure test

///|
test "partial_property_failure" {
  let result = test_enumerable_property(fn(b : SmallBool) {
    match b {
      True => true
      False => false
    }
  })
  if result.failures.length() != 1 {
    abort("Expected 1 failure")
  }
  if result.passed != 1 {
    abort("Expected 1 passed test")
  }
}

// Test 4: Integer range testing

///|
test "integer_range_testing" {
  let values = enumerate_int_range(-2, 2)
  let result = test_property(
    values,
    fn(x) { x * x >= 0 }, // Squares are non-negative
  )
  if result.failures.length() != 0 {
    abort("Expected no failures for square property")
  }
  if result.passed <= 0 {
    abort("Expected some passed tests")
  }
}

// Test 5: Boolean pairs testing

///|
test "boolean_pairs_testing" {
  let result = test_pairs(fn(a : SmallBool, b : SmallBool) {
    let x = bool_value(a)
    let y = bool_value(b)
    x || y == y || x // Disjunction is commutative
  })
  if result.failures.length() != 0 {
    abort("Expected no failures for commutative property")
  }
  if result.passed != 4 {
    abort("Expected 4 passed tests (2x2 combinations)")
  }
}

// Test 6: Utility functions

///|
test "utility_functions_work" {
  let values = [1, 2, 3, 4, 5]
  if not(all_satisfy(values, fn(x) { x > 0 })) {
    abort("All values should be > 0")
  }
  if all_satisfy(values, fn(x) { x > 3 }) {
    abort("Not all values should be > 3")
  }
  if not(any_satisfy(values, fn(x) { x > 3 })) {
    abort("Some values should be > 3")
  }
  if any_satisfy(values, fn(x) { x > 10 }) {
    abort("No values should be > 10")
  }
}

// Test 7: Test case counting

///|
test "test_case_counting_works" {
  let values = SmallBool::enumerate()
  let count = count_test_cases(values, 2)
  if count != 2 {
    abort("Expected count of 2")
  }
}

// Test 8: Preview functionality

///|
test "preview_functionality_works" {
  let preview = preview_test_cases(3)
  if preview.length() <= 0 {
    abort("Preview should have some entries")
  }
  if preview.length() > 3 {
    abort("Preview should not exceed max limit")
  }
}

// Test 9: Configuration creation

///|
test "test_config_creation" {
  let config = TestConfig::new()
  if config.max_test_cases != 1000 {
    abort("Default config should have 1000 max test cases")
  }
  let custom_config = TestConfig::make(100, true, Some(42))
  if custom_config.max_test_cases != 100 {
    abort("Custom config should have 100 max test cases")
  }
}

// Test 10: Complex property testing with triples

///|
test "complex_property_testing" {
  // Test distributive law: a && (b || c) == (a && b) || (a && c)
  let result = test_triples(fn(a : SmallBool, b : SmallBool, c : SmallBool) {
    let x = bool_value(a)
    let y = bool_value(b)
    let z = bool_value(c)
    (x && (y || z) == (x && y)) || (x && z)
  })
  if result.failures.length() != 0 {
    abort("Expected no failures for distributive law")
  }
  if result.passed != 8 {
    abort("Expected 8 passed tests (2^3 combinations)")
  }
}

// Test 11: Result string conversion

///|
test "result_string_conversion" {
  let result = test_enumerable_property(fn(b : SmallBool) { bool_value(b) })
  let result_str = result.to_string()
  if not(result_str.contains("Total:")) {
    abort("Result string should contain 'Total:'")
  }
}
