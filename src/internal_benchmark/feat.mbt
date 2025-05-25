///|
priv enum Nat {
  Zero
  Succ(Nat)
} derive(Show)

///|
impl @feat.Enumerable for Nat with enumerate() {
  @feat.pay(fn() {
    @feat.singleton(Zero) + @feat.Enumerable::enumerate().fmap(Nat::Succ(_))
  })
}

///|
test (b : @bench.T) {
  let f : @feat.Enumerate[Nat] = @feat.Enumerable::enumerate()
  b.bench(name="feat nat", fn() { f.en_index(200) |> ignore })
}
