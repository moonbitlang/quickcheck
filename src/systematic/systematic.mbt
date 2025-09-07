// Systematic Testing Framework for MoonBit
// 
// This module provides systematic testing capabilities for MoonBit programs.
// It supports testing finite domains and collections systematically.

// Trait for types that can be enumerated
///|
pub trait Enumerable {
  enumerate() -> Array[Self]
}

// Configuration for systematic testing

///|
pub struct TestConfig {
  max_test_cases : Int
  verbose : Bool
  seed : Int?
}

// Represents a test result with optional failures

///|
pub struct TestResult[T] {
  total : Int
  failures : Array[(T, String)]
  passed : Int
}

// Create a new test configuration with default values

///|
pub fn TestConfig::new() -> TestConfig {
  { max_test_cases: 1000, verbose: false, seed: None }
}

// Create a new test configuration with custom values

///|
pub fn TestConfig::make(
  max_test_cases : Int,
  verbose : Bool,
  seed : Int?,
) -> TestConfig {
  { max_test_cases, verbose, seed }
}

// Convert test result to string representation

///|
pub fn[T : Show] TestResult::to_string(self : TestResult[T]) -> String {
  let failure_details = if self.failures.length() == 0 {
    ""
  } else {
    "\nFailures:\n" +
    self.failures
    .map(fn(pair : (T, String)) {
      let (value, desc) = pair
      "  " + value.to_string() + ": " + desc
    })
    .join("\n")
  }
  let summary = "Total: " +
    self.total.to_string() +
    ", Passed: " +
    self.passed.to_string() +
    ", Failed: " +
    self.failures.length().to_string()
  summary + failure_details
}

// Helper function to create a successful test result

///|
pub fn[T] TestResult::success(total : Int, passed : Int) -> TestResult[T] {
  { total, failures: [], passed }
}

// Helper function to create a failed test result

///|
pub fn[T] TestResult::failure(
  total : Int,
  passed : Int,
  failure : (T, String),
) -> TestResult[T] {
  { total, failures: [failure], passed }
}

// Combine two test results

///|
pub fn[T] TestResult::combine(
  self : TestResult[T],
  other : TestResult[T],
) -> TestResult[T] {
  {
    total: self.total + other.total,
    failures: self.failures + other.failures,
    passed: self.passed + other.passed,
  }
}

// Basic enumerable implementations

///|
impl Enumerable for Bool with enumerate() {
  [false, true]
}

///|
impl Enumerable for Int with enumerate() {
  // For demonstration, we provide a small range
  // In practice, this might be configurable
  let result : Array[Int] = Array::new(capacity=21)
  for i = 0; i < 21; i = i + 1 {
    result[i] = i - 10
  }
  result
}

// Range-based enumeration for integers

///|
pub fn enumerate_int_range(start : Int, end : Int) -> Array[Int] {
  let size = end - start + 1
  let result : Array[Int] = Array::new(capacity=size)
  for i = 0; i < size; i = i + 1 {
    result[i] = start + i
  }
  result
}

// Test a property over all values in a finite collection

///|
pub fn[T] test_property(
  values : Array[T],
  property : (T) -> Bool,
) -> TestResult[T] {
  let mut passed = 0
  let mut failures = []
  let total = values.length()
  for i = 0; i < total; i = i + 1 {
    let value = values[i]
    if property(value) {
      passed = passed + 1
    } else {
      failures = failures + [(value, "Property failed")]
    }
  }
  { total, failures, passed }
}

// Test a property over an enumerable type

///|
pub fn[T : Enumerable] test_enumerable_property(
  property : (T) -> Bool,
) -> TestResult[T] {
  let values = T::enumerate()
  test_property(values, property)
}

// Systematic testing with depth control and pruning

///|
struct SearchState {
  current_path : Array[Int]
  visited : Set[String]
}

// Helper function to create search state

///|
fn create_search_state() -> SearchState {
  { current_path: [], visited: Set::new() }
}

// Test finite collections with systematic exploration

///|
fn[T] test_finite_collection(
  collection : Array[T],
  property : (T) -> Bool,
  config : TestConfig,
) -> TestResult[T] {
  let mut passed = 0
  let mut failures = []
  let total = collection.length()
  let card = total

  // Calculate effective test limit
  let _test_limit = if config.max_test_cases > 0 && config.max_test_cases < card {
    config.max_test_cases
  } else {
    card
  }

  // Test each element systematically
  for i = 0; i < total; i = i + 1 {
    let value = collection[i]
    if property(value) {
      passed = passed + 1
    } else {
      failures = failures + [(value, "Property failed")]
      if config.verbose {
        // In a real implementation, we might print debug info here
      }
    }
  }
  { total, failures, passed }
}

// Test properties over pairs of values

///|
pub fn[A : Enumerable, B : Enumerable] test_pairs(
  property : (A, B) -> Bool,
) -> TestResult[(A, B)] {
  let a_values = A::enumerate()
  let b_values = B::enumerate()
  let mut passed = 0
  let mut failures = []
  let mut total = 0
  for i = 0; i < a_values.length(); i = i + 1 {
    for j = 0; j < b_values.length(); j = j + 1 {
      let pair = (a_values[i], b_values[j])
      total = total + 1
      if property(a_values[i], b_values[j]) {
        passed = passed + 1
      } else {
        failures = failures + [(pair, "Property failed")]
      }
    }
  }
  { total, failures, passed }
}

// Test properties over triples of values

///|
pub fn[A : Enumerable, B : Enumerable, C : Enumerable] test_triples(
  property : (A, B, C) -> Bool,
) -> TestResult[(A, B, C)] {
  let a_values = A::enumerate()
  let b_values = B::enumerate()
  let c_values = C::enumerate()
  let mut passed = 0
  let mut failures = []
  let mut total = 0
  for i = 0; i < a_values.length(); i = i + 1 {
    for j = 0; j < b_values.length(); j = j + 1 {
      for k = 0; k < c_values.length(); k = k + 1 {
        let triple = (a_values[i], b_values[j], c_values[k])
        total = total + 1
        if property(a_values[i], b_values[j], c_values[k]) {
          passed = passed + 1
        } else {
          failures = failures + [(triple, "Property failed")]
        }
      }
    }
  }
  { total, failures, passed }
}

// Advanced: Test with custom collection generation

///|
pub fn[T] test_with_generator(
  generator : () -> Array[T],
  property : (T) -> Bool,
) -> TestResult[T] {
  let values = generator()
  test_property(values, property)
}

// Utility: Check if all elements satisfy a predicate

///|
pub fn[T] all_satisfy(collection : Array[T], predicate : (T) -> Bool) -> Bool {
  for i = 0; i < collection.length(); i = i + 1 {
    if not(predicate(collection[i])) {
      return false
    }
  }
  true
}

// Utility: Check if any element satisfies a predicate

///|
pub fn[T] any_satisfy(collection : Array[T], predicate : (T) -> Bool) -> Bool {
  for i = 0; i < collection.length(); i = i + 1 {
    if predicate(collection[i]) {
      return true
    }
  }
  false
}

// Count total test cases for a given configuration

///|
pub fn[T] count_test_cases(collection : Array[T], _max_depth : Int) -> Int {
  collection.length()
}

// Preview what test cases would be generated for Bool type

///|
pub fn preview_test_cases(max_cases : Int) -> Array[String] {
  let values = Bool::enumerate()
  let limit = if max_cases < values.length() {
    max_cases
  } else {
    values.length()
  }
  let result : Array[String] = Array::new(capacity=limit)
  for i = 0; i < limit; i = i + 1 {
    result[i] = values[i].to_string()
  }
  result
}
