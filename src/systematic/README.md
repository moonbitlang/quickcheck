# Systematic/Exhaustive Testing Module

This module provides systematic enumeration-based testing using @feat for property-based testing. It systematically enumerates all possible inputs up to a given depth limit, ensuring exhaustive coverage within the specified bounds.

## Overview

Traditional property-based testing (like QuickCheck) uses random generation to test properties. While effective, it may miss edge cases or provide incomplete coverage. Systematic testing complements this by exhaustively enumerating all possible inputs within a bounded domain.

## Key Features

- **Exhaustive enumeration**: Test all possible values up to a specified depth
- **Configurable limits**: Control maximum depth, test cases, and timeout
- **Integration with @feat**: Leverages the existing @feat enumeration infrastructure  
- **Depth-wise testing**: Process test cases level by level for controlled resource usage
- **Comprehensive reporting**: Detailed results with counterexamples and coverage information

## Core Types

### SystematicConfig
Configuration for systematic testing:
```moonbit
struct SystematicConfig {
  max_depth : Int           // Maximum enumeration depth
  max_test_cases : Int      // Maximum total test cases (0 = unlimited)
  show_progress : Bool      // Whether to show progress during enumeration
  stop_on_first_failure : Bool  // Stop on first counterexample or collect all
}
```

### SystematicResult[T]
Result of systematic testing:
```moonbit
enum SystematicResult[T] {
  AllPassed(Int)                        // All tests passed (count)
  FoundCounterExamples(Array[(T, String)])  // Counterexamples found
  Incomplete(Int, String)               // Testing incomplete (count, reason)
}
```

## Basic Usage

### Simple Property Testing
```moonbit
// Test a tautology
let result = systematic_check(fn(b : Bool) { b || not(b) })
match result {
  AllPassed(count) => println("Passed all \{count} tests")
  FoundCounterExamples(failures) => println("Found failures: \{failures}")
  Incomplete(count, reason) => println("Incomplete: \{count} tests, \{reason}")
}
```

### Testing with Configuration
```moonbit
let config = {
  max_depth: 5,
  max_test_cases: 1000,
  show_progress: true,
  stop_on_first_failure: false,
}

let result = systematic_check(
  fn(n : SmallNat) { n == n }, // reflexivity
  config?=Some(config),
)
```

### Custom Error Descriptions
```moonbit
let result = systematic_check_with_description(
  fn(x : Int) { x >= 0 },  // property
  fn(x) { "Negative number found: \{x}" },  // error description
  config,
)
```

## Advanced Features

### Multi-argument Properties
```moonbit
// Test binary properties
let result = systematic_check2(
  fn(a : Int, b : Int) { a + b == b + a },  // commutativity
  config,
)

// Test ternary properties  
let result = systematic_check3(
  fn(a : Int, b : Int, c : Int) { (a + b) + c == a + (b + c) },  // associativity
  config,
)
```

### Custom Enumeration
```moonbit
// Use custom enumeration instead of default
let custom_enum = my_custom_enumeration()
let result = systematic_check_custom(
  custom_enum,
  property,
  config,
)
```

### Utility Functions
```moonbit
// Count total test cases that would be run
let count = count_test_cases[Bool](max_depth=3)
println("Would test \{count} cases")

// Preview test cases at specific depth
let preview = preview_test_cases[SmallNat](depth=1, max_preview?=Some(10))
println("Preview: \{preview}")
```

## Integration with @feat

The systematic testing module integrates seamlessly with the @feat enumeration framework:

### Custom Enumerable Types
```moonbit
enum SmallNat {
  Zero
  One  
  Two
} derive(Show, Eq)

impl @feat.Enumerable for SmallNat with enumerate() {
  @feat.pay(fn() {
    @feat.singleton(Zero) +
    @feat.singleton(One) +
    @feat.singleton(Two)
  })
}

// Now can use systematic testing
let result = systematic_check(fn(n : SmallNat) { ... }, config)
```

### Composite Types
```moonbit
// Tuples are automatically enumerable if components are
impl[A : @feat.Enumerable, B : @feat.Enumerable] @feat.Enumerable for (A, B) with enumerate() {
  @feat.product(A::enumerate(), B::enumerate())
}

// Lists with bounded size
impl[T : @feat.Enumerable] @feat.Enumerable for SmallList[T] with enumerate() {
  @feat.consts([
    @feat.singleton(Empty),
    @feat.unary(fn(x : T) { Single(x) }),
    @feat.product(T::enumerate(), T::enumerate()).fmap(fn((x, y)) { Pair(x, y) }),
  ])
}
```

## Practical Examples

### Testing Arithmetic Properties
```moonbit
// Commutativity of addition
systematic_check2(
  fn(a : BoundedInt, b : BoundedInt) {
    a.to_int() + b.to_int() == b.to_int() + a.to_int()
  },
  config,
)

// Associativity of addition  
systematic_check3(
  fn(a : BoundedInt, b : BoundedInt, c : BoundedInt) {
    let (x, y, z) = (a.to_int(), b.to_int(), c.to_int())
    (x + y) + z == x + (y + z)
  },
  config,
)
```

### Testing List Properties
```moonbit
// Reverse is involutive
systematic_check(
  fn(lst : SmallList[T]) { lst.reverse().reverse() == lst },
  config,
)

// Length preservation under reverse
systematic_check(
  fn(lst : SmallList[T]) { lst.length() == lst.reverse().length() },
  config,
)
```

### Testing Logical Laws
```moonbit
// De Morgan's laws
systematic_check2(
  fn(p : Prop, q : Prop) {
    p.and(q).not() == p.not().or(q.not())
  },
  config,
)

// Distributive law
systematic_check3(
  fn(p : Prop, q : Prop, r : Prop) {
    p.and(q.or(r)) == p.and(q).or(p.and(r))
  },
  config,
)
```

## Performance Considerations

### Depth Management
- Start with small depths (1-3) and increase gradually
- Monitor test case counts using `count_test_cases`
- Use `max_test_cases` to bound resource usage

### Memory Usage
- Enumeration is lazy, processing one depth level at a time
- Large depths can still consume significant memory
- Consider breaking large problems into smaller domains

### Timeout Handling
- Set appropriate `timeout_ms` for complex properties
- Use `stop_on_first_failure` for faster debugging
- Enable `show_progress` for long-running tests

## Best Practices

1. **Start Small**: Begin with small enumerable types and shallow depths
2. **Combine Approaches**: Use systematic testing for small domains, random testing for larger ones
3. **Property Selection**: Choose properties that are computationally cheap to verify
4. **Domain Modeling**: Design bounded types that capture the essence of larger domains
5. **Resource Monitoring**: Always set appropriate limits to prevent resource exhaustion

## Error Handling

The module provides comprehensive error reporting:
- **Property failures**: Detailed counterexamples with custom descriptions
- **Enumeration errors**: Issues with @feat enumeration at specific depths
- **Resource limits**: Clear indication when limits are reached
- **Incomplete coverage**: Notification when testing couldn't complete

## Integration Examples

### Mixed Testing Strategy
```moonbit
// Combine systematic and random testing
let systematic_result = systematic_check(property, small_config)
let random_result = quickcheck(property, large_config)

match (systematic_result, random_result) {
  (AllPassed(_), Passed) => "High confidence in property"
  _ => "Need to investigate failures"
}
```

### Test Suites
```moonbit
let properties = [
  ("reflexivity", fn(x) { x == x }),
  ("commutativity", fn((x, y)) { x + y == y + x }),
  ("associativity", fn((x, y, z)) { (x + y) + z == x + (y + z) }),
]

let results = test_suite("arithmetic", properties, config)
// Analyze results for comprehensive property verification
```

This systematic testing approach provides a powerful complement to traditional property-based testing, ensuring thorough coverage within bounded domains and helping discover edge cases that random testing might miss.