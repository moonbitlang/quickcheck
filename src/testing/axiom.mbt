///|
struct Queue {
  f : @list.T[Int]
  r : @list.T[Int]
} derive(Show)

///|
fn build_queue(f : @list.T[Int], r : @list.T[Int]) -> Queue {
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
pub fn is_empty(self : Queue) -> Bool {
  match self {
    { f, .. } =>
      match f {
        Empty => true
        _ => false
      }
  }
}

///|
fn front(self : Queue) -> Int {
  self.f.last().unwrap()
}

///|
fn dequeue(self : Queue) -> Queue {
  let { f, r } = self
  build_queue(f.unsafe_tail(), r)
}

///|
fn to_list(self : Queue) -> @list.T[Int] {
  self.f.concat(self.r.rev())
}

///|
fn op_equal(self : Queue, other : Queue) -> Bool {
  self.to_list() == other.to_list()
}

///|
impl @quickcheck.Arbitrary for Queue with arbitrary(i, rs) {
  let f : @list.T[Int] = @quickcheck.Arbitrary::arbitrary(i, rs)
  let r : @list.T[Int] = @quickcheck.Arbitrary::arbitrary(i, rs)
  build_queue(f, r)
}

///|
priv type EqQueue @qc.Equivalence[Queue]

///|
impl @quickcheck.Arbitrary for EqQueue with arbitrary(i, rs) {
  fn split(xs : @list.T[Int], i) {
    (xs.take(i), xs.drop(i))
  }

  fn from(xs : @list.T[Int]) {
    let n = @qc.int_bound(xs.length() - 1).run(i, rs)
    let (xs1, xs2) = split(xs, n)
    build_queue(xs1, xs2.rev())
  }

  let z : @list.T[Int] = @quickcheck.Arbitrary::arbitrary(i, rs)
  let lhs = from(z)
  let rhs = from(z)
  EqQueue({ lhs, rhs })
}
