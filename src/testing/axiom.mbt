///|
struct Queue {
  f : List[Int]
  r : List[Int]
} derive(Show)

///|
impl @qc.Shrink for Queue

///|
fn build_queue(f : List[Int], r : List[Int]) -> Queue {
  match f {
    Empty => { f: r, r: @list.empty() }
    f => { f, r }
  }
}

///|
pub fn empty_queue() -> Queue {
  { f: @list.empty(), r: @list.empty() }
}

///|
pub fn enqueue(q : Queue, x : Int) -> Queue {
  match q {
    { f, r } => build_queue(f, r.add(x))
  }
}

///|
pub fn Queue::is_empty(self : Queue) -> Bool {
  match self {
    { f, .. } =>
      match f {
        Empty => true
        _ => false
      }
  }
}

///|
fn Queue::front(self : Queue) -> Int {
  self.f.last().unwrap()
}

///|
fn Queue::dequeue(self : Queue) -> Queue {
  let { f, r } = self
  build_queue(f.unsafe_tail(), r)
}

///|
fn Queue::to_list(self : Queue) -> List[Int] {
  self.f.concat(self.r.rev())
}

///|
fn Queue::op_equal(self : Queue, other : Queue) -> Bool {
  self.to_list() == other.to_list()
}

///|
impl @coreqc.Arbitrary for Queue with arbitrary(i, rs) {
  let f : List[Int] = @coreqc.Arbitrary::arbitrary(i, rs)
  let r : List[Int] = @coreqc.Arbitrary::arbitrary(i, rs)
  build_queue(f, r)
}

///|
priv struct EqQueue(@qc.Equivalence[Queue]) derive(Show)

///|
impl @qc.Shrink for EqQueue

///|
impl @coreqc.Arbitrary for EqQueue with arbitrary(i, rs) {
  fn split(xs : List[Int], i) {
    (xs.take(i), xs.drop(i))
  }

  fn from(xs : List[Int]) {
    let n = @qc.int_bound(xs.length() - 1).run(i, rs)
    let (xs1, xs2) = split(xs, n)
    build_queue(xs1, xs2.rev())
  }

  let z : List[Int] = @coreqc.Arbitrary::arbitrary(i, rs)
  let lhs = from(z)
  let rhs = from(z)
  EqQueue({ lhs, rhs })
}

///|
test "queue front and dequeue" {
  let q = enqueue(enqueue(empty_queue(), 1), 2)
  inspect(q.front(), content="1")
  inspect(q.dequeue().to_list(), content="@list.from_array([2])")
  let rebuilt = enqueue(enqueue(empty_queue(), 1), 2)
  inspect(q.op_equal(rebuilt), content="true")
}

///|
test "queue roundtrip property" {
  inspect(
    @qc.quick_check_silence(
      @qc.Arrow(fn(q : Queue) { q.to_list().rev().rev() == q.to_list() }),
    ),
    content="+++ [100/0/100] Ok, passed!",
  )
}

///|
test "queue equivalence property" {
  let prop_eq_queue = fn(eq : EqQueue) {
    match eq {
      EqQueue(equiv) => {
        let lhs = equiv.lhs.to_list().length()
        let rhs = equiv.rhs.to_list().length()
        lhs == rhs
      }
    }
  }

  inspect(
    @qc.quick_check_silence(@qc.Arrow(prop_eq_queue)),
    content="+++ [100/0/100] Ok, passed!",
  )
}
