// Rose Tree used for shrinking
///|
pub(all) struct Rose[T] {
  val : T
  branch : Iter[Rose[T]]
} derive(Show)

///|
pub fn new[T](val : T, branch : Iter[Rose[T]]) -> Rose[T] {
  { val, branch }
}

///|
pub fn join[T](self : Rose[Rose[T]]) -> Rose[T] {
  let tss = self.branch
  let ts = self.val.branch
  { val: self.val.val, branch: tss.map(join).concat(ts) }
}

///|
pub fn pure[T](val : T) -> Rose[T] {
  { val, branch: Iter::empty() }
}

///|
pub fn fmap[T, U](self : Rose[T], f : (T) -> U) -> Rose[U] {
  { val: f(self.val), branch: self.branch.map(fn(x) { x.fmap(f) }) }
}

///|
pub fn bind[T, U](self : Rose[T], f : (T) -> Rose[U]) -> Rose[U] {
  self.fmap(f).join()
}

///|
pub fn apply[T](self : Rose[T], f : (T, Iter[Rose[T]]) -> Rose[T]) -> Rose[T] {
  f(self.val, self.branch)
}
