///|
/// Wraps a `String` guaranteed to contain only printable ASCII characters
/// (codepoints 32–126). Shrinks by shrinking the underlying character
/// array and filtering to keep only ASCII.
pub(all) struct ASCIIString(String) derive(Eq)

///|
pub impl Show for ASCIIString with output(self, logger) {
  self.0.output(logger)
}

///|
impl Debug for ASCIIString with to_repr(self) {
  Debug::to_repr(self.0)
}

///|
pub impl @coreqc.Arbitrary for ASCIIString with arbitrary(size, rs) {
  let len = rs.next_positive_int() % (size + 1)
  let chars = Array::makei(len, _ => {
    Int::unsafe_to_char(rs.next_positive_int() % 95 + 32)
  })
  ASCIIString(String::from_array(chars))
}

///|
pub impl @shrink.Shrink for ASCIIString with shrink(self) {
  let chars = self.0.to_array()
  @shrink.Shrink::shrink(chars)
  .filter(cs => cs.all(c => c.to_int() >= 32 && c.to_int() <= 126))
  .map(cs => ASCIIString(String::from_array(cs)))
}

///|
fn is_ascii_printable(s : String) -> Bool {
  s.to_array().all(c => c.to_int() >= 32 && c.to_int() <= 126)
}

///|
test "ASCIIString generates printable ASCII" {
  let gen : @gen.Gen[ASCIIString] = @gen.Gen::spawn()
  let samples = gen.samples(size=20)
  debug_inspect(
    samples,
    content=(
      #|[
      #|  "[SxW6i",
      #|  "",
      #|  "|eHIgK\"a\\GW+]yO*f",
      #|  "f;va",
      #|  "!:-bF`1+Oj ur]V-6A",
      #|  "X;_/SIB?z=x<",
      #|  "yEH,rb+i\"u\"Ygs",
      #|  "!\"K)}M",
      #|  "Iq-\\p!SYX`N",
      #|  "g]z&d'__-p<^c",
      #|  "0_e1]P",
      #|  "P",
      #|  "O8cS elMJH.",
      #|  "ac^H3i;m4mtoW",
      #|  "J4-[6j]t629.m.mF#-",
      #|  "niKr 6lUI",
      #|  "4",
      #|  "j3{#{:d=qR!s(wgu",
      #|  "bC(aMm?@(I ",
      #|  " PDh_?O&5r#Ff",
      #|]
    ),
  )
  assert_true(samples.all(x => is_ascii_printable(x.0)))
}

///|
test "ASCIIString shrinks within ASCII range" {
  let s = @shrink.Shrink::shrink(ASCIIString("Hello")).to_array()
  assert_true(s.all(x => is_ascii_printable(x.0)))
}

///|
test "ASCIIString empty shrinks to empty" {
  let s = @shrink.Shrink::shrink(ASCIIString("")).to_array()
  assert_eq(s, [])
}
