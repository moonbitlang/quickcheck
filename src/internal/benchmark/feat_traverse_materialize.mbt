///|
fn byte_pair_score(pair : (Byte, Byte)) -> Int {
  pair.0.to_int() + pair.1.to_int()
}

///|
fn byte_triple_score(triple : (Byte, (Byte, Byte))) -> Int {
  triple.0.to_int() + triple.1.0.to_int() + triple.1.1.to_int()
}

///|
test (b : @bench.T) {
  let byte_pairs : @feat.Enumerate[(Byte, Byte)] = @feat.Enumerable::enumerate()
  let byte_pair_part = @feat.part(byte_pairs, 1)
  b.bench(name="quickcheck feat byte-pair count 65536", fn() {
    b.keep(@ifseq.length(byte_pair_part).to_int())
  })
  b.bench(name="quickcheck feat byte-pair each 65536", fn() {
    let mut acc = 0
    @ifseq.each(byte_pair_part, fn(pair) { acc = acc + byte_pair_score(pair) })
    b.keep(acc)
  })
  b.bench(name="quickcheck feat byte-pair materialize 65536", fn() {
    b.keep(@ifseq.to_iter_materialized(byte_pair_part).to_array().length())
  })

  let byte_triples : @feat.Enumerate[(Byte, (Byte, Byte))] = @feat.Enumerable::enumerate()
  let byte_triple_part = @feat.part(byte_triples, 2)
  b.bench(name="quickcheck feat byte-triple count 16777216", fn() {
    b.keep(@ifseq.length(byte_triple_part).to_int())
  })
  b.bench(name="quickcheck feat byte-triple each 16777216", fn() {
    let mut acc = 0
    @ifseq.each(byte_triple_part, fn(triple) {
      acc = acc + byte_triple_score(triple)
    })
    b.keep(acc)
  })
}
