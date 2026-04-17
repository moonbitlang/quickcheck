///|
priv enum Nat {
  Zero
  Succ(Nat)
} derive(Debug)

///|
impl @feat.Enumerable for Nat with enumerate() {
  @feat.pay(() => {
    @feat.singleton(Zero) + @feat.Enumerable::enumerate().fmap(n => Succ(n))
  })
}

///|
test (b : @bench.T) {
  let f : @feat.Enumerate[Nat] = @feat.Enumerable::enumerate()
  b.bench(name="feat nat", () => f[200] |> ignore)
}
