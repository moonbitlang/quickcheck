///|
struct Queue {
  f : @list.List[Int32]
  r : @list.List[Int32]
} derive(Debug)

///|
pub extend Queue with Debug::{to_repr}

///|
impl @shrink.Shrink for Queue

///|
fn build_queue(f : @list.List[Int32], r : @list.List[Int32]) -> Queue {
  match f {
    Empty => { f: r, r: List([]), }
    f => { f, r, }
  }
}

///|
pub fn empty_queue() -> Queue {
  { f: List([]), r: List([]), }
}

///|
pub fn enqueue(q : Queue, x : Int32) -> Queue {
  match q {
    { f, r, } => build_queue(f, r.prepend(x))
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
fn Queue::front(self : Queue) -> Int32 {
  self.f.last().unwrap()
}

///|
fn Queue::dequeue(self : Queue) -> Queue {
  let { f, r, } = self
  build_queue(f.unsafe_tail(), r)
}

///|
fn Queue::to_list(self : Queue) -> @list.List[Int32] {
  self.f.concat(self.r.rev())
}

///|
fn Queue::op_equal(self : Queue, other : Queue) -> Bool {
  self.to_list() == other.to_list()
}

///|
impl @coreqc.Arbitrary for Queue with fn arbitrary(i, rs) {
  let f : @list.List[Int32] = @coreqc.Arbitrary::arbitrary(i, rs)
  let r : @list.List[Int32] = @coreqc.Arbitrary::arbitrary(i, rs)
  build_queue(f, r)
}

///|
priv struct EqQueue(@laws.Equivalence[Queue]) derive(Debug)

///|
impl @shrink.Shrink for EqQueue

///|
impl @coreqc.Arbitrary for EqQueue with fn arbitrary(i, rs) {
  fn split(xs : @list.List[Int32], i) {
    (xs.take(i), xs.drop(i))
  }

  fn from(xs : @list.List[Int32]) {
    let n = @coreqc.int_range(0, xs.length()).run(i, rs)
    let (xs1, xs2) = split(xs, n)
    build_queue(xs1, xs2.rev())
  }

  let z : @list.List[Int32] = @coreqc.Arbitrary::arbitrary(i, rs)
  let lhs = from(z)
  let rhs = from(z)
  EqQueue({ lhs, rhs, })
}

///|
test "queue front and dequeue" {
  let q = enqueue(enqueue(empty_queue(), 1), 2)
  inspect(q.front(), content="1")
  debug_inspect(
    q.dequeue().to_list(),
    content=(
      #|<List: [2]>
    ),
  )
  let rebuilt = enqueue(enqueue(empty_queue(), 1), 2)
  inspect(q.op_equal(rebuilt), content="true")
}

///|
test "queue roundtrip property" {
  inspect(
    @qc.quick_check_silence(
      @qc.Arrow((q : Queue) => q.to_list().rev().rev() == q.to_list()),
    ),
    content=(
      #|+++ [100/0/100] Ok, passed!
    ),
  )
}

///|
test "queue equivalence property" {
  let prop_eq_queue = (eq : EqQueue) => {
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
    content=(
      #|+++ [100/0/100] Ok, passed!
    ),
  )
}
