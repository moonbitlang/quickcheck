# Systematic/Exhaustive Testing Implementation

This document describes the implementation of systematic/exhaustive testing for MoonBit using enumeration-based property testing inspired by @feat.

## Overview

Systematic testing provides exhaustive coverage within bounded domains by enumerating all possible inputs up to a given depth limit. This complements traditional property-based testing (like QuickCheck) by ensuring complete coverage within finite spaces.

## Implementation

### Core Components

1. **Enumerable Trait** (`src/systematic/systematic.mbt`)
   - Defines types that can be systematically enumerated
   - Provides implementations for basic types (Bool, Int ranges)
   - Supports composite types through tuple enumeration

2. **Test Framework** 
   - `test_enumerable_property`: Test properties on enumerable types
   - `test_pairs`: Test binary properties on pairs of enumerable types  
   - `test_triples`: Test ternary properties on triples of enumerable types
   - `test_property`: Test properties on finite collections

3. **Configuration and Results**
   - `TestConfig`: Controls test execution (limits, verbosity, etc.)
   - `TestResult`: Captures test outcomes with detailed failure information
   - Utilities for counting and previewing test cases

### Key Features

- **Exhaustive Enumeration**: Tests all possible values within specified bounds
- **Systematic Coverage**: Ensures no edge cases are missed in finite domains
- **Configurable Limits**: Control depth, test case counts, and verbosity
- **Detailed Results**: Comprehensive failure reporting with context
- **Composable**: Support for testing properties on multiple argument types

## Usage Examples

### Basic Property Testing

```moonbit
// Define an enumerable type
enum SmallBool {
  True
  False
}

impl Enumerable for SmallBool with enumerate() {
  [True, False]
}

// Test a tautology (should always pass)
let result = test_enumerable_property(
  fn(b : SmallBool) { bool_value(b) || not(bool_value(b)) }
)
// Result: 0 failures, 2 passed
```

### Binary Property Testing

```moonbit
// Test commutativity of boolean disjunction
let result = test_pairs(
  fn(a : SmallBool, b : SmallBool) {
    let x = bool_value(a)
    let y = bool_value(b)
    x || y == y || x // Should always be true
  }
)
// Result: 0 failures, 4 passed (2×2 combinations)
```

### Integer Range Testing

```moonbit
// Test mathematical properties on bounded integers
let values = enumerate_int_range(-5, 5)
let result = test_property(
  values,
  fn(x) { x * x >= 0 } // Squares are non-negative
)
// Result: 0 failures, 11 passed
```

## Integration with @feat Style Enumeration

The implementation follows the @feat enumeration pattern:

1. **Depth-wise Generation**: Values are generated level by level
2. **Lazy Evaluation**: Only generates values as needed
3. **Compositional**: Complex types built from simpler enumerations
4. **Bounded**: Explicit control over enumeration depth and size

## Benefits

1. **Complete Coverage**: Tests all values in finite domains
2. **Predictable**: Deterministic test case generation
3. **Efficient**: Focused testing on relevant input spaces
4. **Debuggable**: Clear mapping from failures to specific inputs
5. **Composable**: Easy to extend to new types and properties

## Limitations

1. **Finite Domains Only**: Cannot handle infinite types directly
2. **Exponential Growth**: Test case counts grow exponentially with tuple arity
3. **Memory Usage**: Large enumerations may consume significant memory
4. **Performance**: Exhaustive testing can be slower than random sampling

## Best Practices

1. **Start Small**: Begin with small enumerable types (≤10 values)
2. **Use Depth Limits**: Control enumeration depth to manage test case counts  
3. **Combine Approaches**: Use systematic testing for small domains, random testing for larger ones
4. **Monitor Performance**: Set appropriate limits for test execution time
5. **Design Bounded Types**: Create finite versions of larger types for testing

## Files

- `src/systematic/systematic.mbt`: Core systematic testing framework
- `src/systematic/test.mbt`: Comprehensive test suite demonstrating usage
- `src/systematic/README.md`: Detailed documentation and examples

## Testing Results

The implementation passes comprehensive tests covering:
- Basic property testing (tautologies, contradictions)
- Multi-argument properties (pairs, triples)
- Utility functions (counting, previewing)
- Configuration and error handling
- Complex logical properties (distributive laws, commutativity)

This systematic testing framework provides a powerful complement to traditional property-based testing, ensuring thorough coverage within bounded domains and helping discover edge cases that random testing might miss.