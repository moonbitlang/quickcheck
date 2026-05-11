///|
let unicode_scalar_count : Int = 0x110000 - 0x800

///|
fn string_length(size : Int, rs : @splitmix.RandomState) -> Int {
  rs.next_positive_int() % (size + 1)
}

///|
fn string_with(
  size : Int,
  rs : @splitmix.RandomState,
  next_char : (@splitmix.RandomState) -> Char,
) -> String {
  let len = string_length(size, rs)
  String::from_array(Array::makei(len, _ => next_char(rs)))
}

///|
fn arbitrary_ascii_char(rs : @splitmix.RandomState) -> Char {
  Int::unsafe_to_char(rs.next_positive_int() % 128)
}

///|
fn arbitrary_unicode_char(rs : @splitmix.RandomState) -> Char {
  let idx = rs.next_positive_int() % unicode_scalar_count
  let codepoint = if idx < 0xD800 { idx } else { idx + 0x800 }
  Int::unsafe_to_char(codepoint)
}

///|
/// Wraps a `String` whose characters are ASCII codepoints (`0..127`)
pub(all) struct ASCIIString(String) derive(Eq)

///|
pub impl Debug for ASCIIString with to_repr(self) {
  @debug.Repr::string(self.0)
}

///|
pub impl @coreqc.Arbitrary for ASCIIString with arbitrary(size, rs) {
  ASCIIString(string_with(size, rs, arbitrary_ascii_char))
}

///|
pub impl @shrink.Shrink for ASCIIString with shrink(self) {
  @shrink.Shrink::shrink(self.0.to_array())
  .filter(chars => chars.all(is_ascii_char))
  .map(chars => ASCIIString(String::from_array(chars)))
}

///|
/// Wraps a `String` whose characters are Unicode scalar values. The generated
/// string never contains UTF-16 surrogate codepoints.
pub(all) struct UnicodeString(String) derive(Eq)

///|
pub impl Debug for UnicodeString with to_repr(self) {
  @debug.Repr::string(self.0)
}

///|
pub impl @coreqc.Arbitrary for UnicodeString with arbitrary(size, rs) {
  UnicodeString(string_with(size, rs, arbitrary_unicode_char))
}

///|
pub impl @shrink.Shrink for UnicodeString with shrink(self) {
  @shrink.Shrink::shrink(self.0.to_array())
  .filter(chars => chars.all(is_unicode_scalar))
  .map(chars => UnicodeString(String::from_array(chars)))
}

///|
/// Wraps a printable Unicode `String`, corresponding to Haskell
/// QuickCheck's printable string modifier under the MoonBit name
/// `PrintableString`.
pub(all) struct PrintableString(String) derive(Eq)

///|
pub impl Debug for PrintableString with to_repr(self) {
  @debug.Repr::string(self.0)
}

///|
pub impl @coreqc.Arbitrary for PrintableString with arbitrary(size, rs) {
  PrintableString(
    string_with(size, rs, rst => {
      let gen_char : @gen.Gen[Char] = @gen.Gen::spawn()
      gen_char.such_that(c => c.is_printable()).run(size, rst)
    }),
  )
}

///|
pub impl @shrink.Shrink for PrintableString with shrink(self) {
  @shrink.Shrink::shrink(self.0.to_array())
  .filter(chars => chars.all(c => c.is_printable()))
  .map(chars => PrintableString(String::from_array(chars)))
}

///|
fn is_ascii_char(c : Char) -> Bool {
  c.to_int() >= 0 && c.to_int() <= 0x7F
}

///|
fn is_unicode_scalar(c : Char) -> Bool {
  let codepoint = c.to_int()
  codepoint >= 0 &&
  codepoint <= 0x10FFFF &&
  !(codepoint >= 0xD800 && codepoint <= 0xDFFF)
}

///|
fn is_ascii_string(s : String) -> Bool {
  s.to_array().all(is_ascii_char)
}

///|
fn is_unicode_string(s : String) -> Bool {
  s.to_array().all(is_unicode_scalar)
}

///|
fn is_printable_string(s : String) -> Bool {
  s.to_array().all(c => c.is_printable())
}

///|
test "ASCIIString generates ASCII" {
  let gen : @gen.Gen[ASCIIString] = @gen.Gen::spawn()
  let samples = gen.samples(size=50)
  assert_true(samples.all(x => is_ascii_string(x.0)))
}

///|
test "ASCIIString shrinks within ASCII range" {
  let s = @shrink.Shrink::shrink(ASCIIString("Hello")).to_array()
  assert_true(s.all(x => is_ascii_string(x.0)))
}

///|
test "ASCIIString empty shrinks to empty" {
  let s = @shrink.Shrink::shrink(ASCIIString("")).to_array()
  assert_eq(s.length(), 0)
}

///|
test "ASCIIString debug output keeps wrapper name" {
  debug_inspect(
    ASCIIString("Hello"),
    content=(
      #|"Hello"
    ),
  )
}

///|
test "UnicodeString generates Unicode scalar strings" {
  let gen : @gen.Gen[UnicodeString] = @gen.Gen::spawn()
  let samples = gen.samples(size=10)
  assert_true(samples.all(x => is_unicode_string(x.0)))
}

///|
test "UnicodeString shrinks within Unicode scalar range" {
  let s = @shrink.Shrink::shrink(UnicodeString("a\u{e000}\u{10000}")).to_array()
  assert_true(s.all(x => is_unicode_string(x.0)))
}

///|
test "UnicodeString empty shrinks to empty" {
  let s = @shrink.Shrink::shrink(UnicodeString("")).to_array()
  assert_eq(s.length(), 0)
}

///|
test "PrintableString generates printable Unicode" {
  let gen : @gen.Gen[PrintableString] = @gen.Gen::spawn()
  let samples = gen.samples(size=50)
  assert_true(samples.all(x => is_printable_string(x.0)))
}

///|
test "PrintableString shrinks within printable range" {
  let s = @shrink.Shrink::shrink(PrintableString("Hello \u{4e16}\u{754c}")).to_array()
  assert_true(s.all(x => is_printable_string(x.0)))
}

///|
test "PrintableString empty shrinks to empty" {
  let s = @shrink.Shrink::shrink(PrintableString("")).to_array()
  assert_eq(s.length(), 0)
}
