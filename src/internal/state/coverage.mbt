///|
/// Running tallies of `label(...)` and `classify(...)` hits, built
/// up across the run and handed to the reporter at the end. The only
/// externally-visible operation is `Coverage::to_string`, which
/// renders the tallies as the percentage lines appended to the
/// success / failure report; construction and update happen inside
/// this package.
struct Coverage {
  labels : @sorted_map.SortedMap[@list.List[String], Int]
  classes : @sorted_map.SortedMap[String, Int]
}

///|
/// Fresh, empty `Coverage` — seeded into `State.collects` by
/// `from_config`.
fn Coverage::new() -> Coverage {
  { labels: @sorted_map.new(), classes: @sorted_map.new() }
}

///|
/// Record one occurrence of the given label stack (as
/// attached by `label(...)`).
fn Coverage::label_incr(self : Coverage, key : @list.List[String]) -> Unit {
  // FIXME(upstream): use self.labels.update_or_init(key, 1, x=> x + 1) once that's available
  self.labels[key] = self.labels.get_or_default(key, 0) + 1
}

///|
/// Bump the per-class counters from one `classify(...)` hit. `true`
/// increments the count; `false` still registers the class so it
/// shows up in the report with 0%.
fn Coverage::class_incr(
  self : Coverage,
  classes : @list.List[(String, Bool)],
) -> Unit {
  for item in classes {
    let (s, b) = item
    let i = if b { 1 } else { 0 }
    // FIXME(upstream): use self.classes.update_or_init(s, i, x => x + i) once that's available
    self.classes[s] = self.classes.get_or_default(s, 0) + i
  }
}

///|
fn format_percent(count : Int, total : Int) -> String {
  guard total > 0 else { "0%" }
  let scaled = count * 10000
  let whole = scaled / total / 100
  let frac = scaled / total % 100
  if frac == 0 {
    "\{whole}%"
  } else if frac % 10 == 0 {
    "\{whole}.\{frac / 10}%"
  } else if frac < 10 {
    "\{whole}.0\{frac}%"
  } else {
    "\{whole}.\{frac}%"
  }
}

///|
fn Coverage::label_to_string(self : Coverage, success : Int) -> String {
  [
    for list, i in self.labels if !list.is_empty() => {
      format_percent(i, success) + " : " + list.to_array().join(", ")
    }
  ].join("\n")
}

///|
fn Coverage::class_to_string(self : Coverage, success : Int) -> String {
  [
    for s, i in self.classes => "\{format_percent(i, success)} : \{s}"
  ].join("\n")
}

///|
/// Render the labels + classes tally as percentage lines for the
/// report (normalised against `success`, the number of passing
/// samples). Called by `CheckReport::render` in the root package.
pub fn Coverage::to_array(self : Coverage, success : Int) -> Array[String] {
  [
    if self.labels.length() == 0 {
      ""
    } else {
      self.label_to_string(success)
    },
    if self.classes.length() == 0 {
      ""
    } else {
      self.class_to_string(success)
    },
  ].filter(x => x != "")
}
