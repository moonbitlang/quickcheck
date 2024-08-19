struct Rose[T] {
  val : T
  arr : Array[Rose[T]]
}

pub fn join_rose[T](self : Rose[Rose[T]]) -> Rose[T] {
  let tss = self.arr
  let ts = self.val.arr
  {
    val: self.val.val,
    arr: {
      let x = tss.map(join_rose)
      x.append(ts)
      x
    },
  }
}

pub fn fmap_rose[T,U](self : Rose[T], f : (T) -> U) -> Rose[U] {
  {
    val: f(self.val),
    arr: self.arr.map(fn(x) { fmap_rose(x, f) }),
  }
}

struct QRes {}

struct Prop {
  un_prop : QRes
}

trait Testable {
  property(Self) -> Prop
}
