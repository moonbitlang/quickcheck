typealias List[T] = @immut/list.T[T]

/// Number Laws ///

fn add_comm_double(xy : (Double, Double)) -> Bool {
  let (x, y) = xy
  x + y == y + x
}

fn add_assoc_double(xyz : (Double, Double, Double)) -> Bool {
  let (x, y, z) = xyz
  x + y + z == x + (y + z) // Actually does not hold for Double
}

test {
  quick_check(add_comm_double).print()
  quick_check(add_assoc_double).print()
}

/// Custom Data Types (especially recursive) using Functional Enumeration
/// We have basic instances for builtin types like bool / list / int

/// Natural Numbers ///
enum Nat {
  Zero
  Succ(Nat)
} derive(Show)

impl @feat.Enumerable for Nat with enumerate() {
  @feat.pay(
    fn() {
      @feat.union(
        @feat.singleton(Zero),
        @feat.fmap(Nat::Succ, @feat.Enumerable::enumerate()),
      )
    },
  )
}

impl Arbitrary for Nat with arbitrary(i, rs) { Gen::fe(i).run(i, rs) }

fn op_add(self : Nat, other : Nat) -> Nat {
  match self {
    Zero => other
    Succ(n) => Succ(n.op_add(other))
  }
}

fn op_equal(self : Nat, other : Nat) -> Bool {
  match (self, other) {
    (Zero, Zero) => true
    (Succ(a), Succ(b)) => op_equal(a, b)
    _ => false
  }
}

fn add_comm_nat(ab : (Nat, Nat)) -> Bool {
  let (a, b) = ab
  a + b == b + a
}

test "Natural Number" {
  check_verbose(Default::default(), with_law(add_comm_nat)).print()
  check_one(Default::default(), with_law(add_comm_nat)).print()
}

/// Tree ///

enum Tree[T] {
  Leaf(T)
  Branch(Forest[T])
} derive(Show)

struct Forest[T] {
  forest : @immut/list.T[Tree[T]]
} derive(Show)

impl[E : @feat.Enumerable] @feat.Enumerable for Forest[E] with enumerate() {
  @feat.pay(
    fn() {
      @feat.fmap(fn { forest => { forest, } }, @feat.Enumerable::enumerate())
    },
  )
}

impl[E : @feat.Enumerable] @feat.Enumerable for Tree[E] with enumerate() {
  @feat.pay(
    fn() {
      @feat.union(
        @feat.fmap(Tree::Leaf, E::enumerate()),
        @feat.fmap(Tree::Branch, @feat.Enumerable::enumerate()),
      )
    },
  )
}

test "Tree" {
  let tg : Gen[Tree[Nat]] = Gen::fe(10)
  inspect!(
    tg.samples(),
    content="[Branch({forest: @list.of([Leaf(Zero)])}), Branch({forest: @list.of([Branch({forest: @list.of([])})])}), Leaf(Succ(Zero)), Leaf(Succ(Succ(Zero))), Leaf(Succ(Succ(Succ(Succ(Zero))))), Leaf(Succ(Succ(Succ(Succ(Succ(Succ(Succ(Zero)))))))), Branch({forest: @list.of([Leaf(Zero), Leaf(Zero)])}), Branch({forest: @list.of([Branch({forest: @list.of([])})])}), Leaf(Succ(Succ(Succ(Succ(Zero))))), Leaf(Succ(Succ(Succ(Succ(Succ(Zero))))))]",
  )
}

/// Custom Generators ///

test "int ranged" {
  /// With default generator
  check_verbose(
    Default::default(),
    with_law(
      fn(xy : (Int, Int)) {
        let (x, y) = xy
        x + y == 100
      },
    ),
  ).print()
  /// With custom generator
  check_verbose(
    Default::default(),
    with_law(
      fn(xy : (Int, Int)) {
        let (x, y) = xy
        x + y == 100
      },
    ).with_generator(tuple(int_bound(10), int_bound(10))),
  ).print()
}

pub typealias JValue = @json.JsonValue

pub fn jnull() -> Gen[JValue] {
  pure(Null)
}

pub fn jbool() -> Gen[JValue] {
  one_of([pure(True), pure(False)])
}

pub fn jnumber() -> Gen[JValue] {
  spawn().fmap(JValue::Number)
}

pub fn jarray() -> Gen[JValue] {
  spawn()
}

pub fn jstring() -> Gen[JValue] {
  spawn().fmap(JValue::String)
}

pub fn jobject() -> Gen[JValue] {
  spawn().bind(
    fn(x) {
      array_with_size(x, tuple(spawn(), jGen())).fmap(
        fn(x) {
          let map = Map::new()
          x.each(
            fn(kv) {
              let (k, v) = kv
              map[k] = v
            },
          )
          JValue::Object(map)
        },
      )
    },
  )
}

pub fn jGen() -> Gen[JValue] {
  let composite = [jarray(), jobject()]
  let scalar = [jnull(), jbool(), jnumber(), jstring()]
  Gen::new(
    fn(size, rs) {
      if size < 4 {
        if size > 0 {
          frequency([(4, one_of(scalar)), (1, one_of(composite))]).run(
            size / 2,
            rs,
          )
        } else {
          one_of(scalar).run(size, rs)
        }
      } else {
        frequency([(1, one_of(scalar)), (4, one_of(composite))]).run(
          size / 2,
          rs,
        )
      }
    },
  )
}

impl Arbitrary for JValue with arbitrary(i, rs) { jGen().run(i, rs) }

test "json generator" {
  quick_check(
    fn(jv : JValue) {
      match @result.wrap1(f=@json.parse, @json.stringify(jv)) {
        Err(_) => false
        Ok(jv2) => jv == jv2
      }
    },
  ).print()
}
