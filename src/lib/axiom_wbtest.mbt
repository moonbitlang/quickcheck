struct Queue {
  f : @immut/list.T[Int]
  r : @immut/list.T[Int]
} derive(Show)

fn build_queue(f : @immut/list.T[Int], r : @immut/list.T[Int]) -> Queue {
  match f {
    Nil => { f: r, r: Nil }
    f => { f, r }
  }
}

pub fn empty_queue() -> Queue {
  { f: Nil, r: Nil }
}

pub fn enqueue(q : Queue, x : Int) -> Queue {
  match q {
    { f, r } => build_queue(f, Cons(x, r))
  }
}

pub fn is_empty(self : Queue) -> Bool {
  match self {
    { f, .. } =>
      match f {
        Nil => true
        _ => false
      }
  }
}

fn front(self : Queue) -> Int {
  self.f.last()
}

fn dequeue(self : Queue) -> Queue {
  let { f, r } = self
  build_queue(f.tail(), r)
}

fn to_list(self : Queue) -> @immut/list.T[Int] {
  self.f.concat(self.r.rev())
}

fn op_equal(self : Queue, other : Queue) -> Bool {
  self.to_list() == other.to_list()
}

impl Arbitrary for Queue with arbitrary(i, rs) {
  let f : @immut/list.T[Int] = Arbitrary::arbitrary(i, rs)
  let r : @immut/list.T[Int] = Arbitrary::arbitrary(i, rs)
  build_queue(f, r)
}

impl Arbitrary for Equivalence[Queue] with arbitrary(i, rs) {
  fn split(xs : @immut/list.T[Int], i) {
    (xs.take(i), xs.drop(i))
  }

  fn from(xs : @immut/list.T[Int]) {
    let n = int_bound(xs.length() - 1).run(i, rs)
    let (xs1, xs2) = split(xs, n)
    build_queue(xs1, xs2.rev())
  }

  let z : @immut/list.T[Int] = Arbitrary::arbitrary(i, rs)
  let lhs = from(z)
  let rhs = from(z)
  { lhs, rhs }
}
