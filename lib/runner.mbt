pub fn run[T](cell : Cell[T]) -> Report {
  let state = new()
  let mut succ = 0
  for i = 0; i < cell.count; i = i + 1 {
    let v = (cell.generator.gen)(i, state)
    if (cell.property)(v).not() {
      succ += 1
    }
  }
  { ok: succ == cell.count, print: None, count: (succ, cell.count) }
}
