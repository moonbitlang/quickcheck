///|
/// Running tallies of `label(...)` and `classify(...)` hits, built
/// up across the run and handed to the reporter at the end. The only
/// externally-visible operation is `Coverage::to_string`, which
/// renders the tallies as the percentage lines appended to the
/// success / failure report; construction and update happen inside
/// this package.
pub struct Coverage {
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
  match self.labels.get(key) {
    Some(x) => self.labels[key] = x + 1
    None => self.labels[key] = 1
  }
}

///|
/// Bump the per-class counters from one `classify(...)` hit. `true`
/// increments the count; `false` still registers the class so it
/// shows up in the report with 0%.
fn Coverage::class_incr(
  self : Coverage,
  classes : @list.List[(String, Bool)],
) -> Unit {
  classes.each(item => {
    let (s, b) = item
    let i = if b { 1 } else { 0 }
    match self.classes.get(s) {
      Some(x) => self.classes[s] = x + i
      None => self.classes[s] = i
    }
  })
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
  let res = []
  self.labels.each((list, i) => {
    if list.is_empty() {
      return
    } else {
      let l = list.to_array().join(", ")
      res.push("\{format_percent(i, success)} : \{l}")
    }
  })
  res.join("\n")
}

///|
fn Coverage::class_to_string(self : Coverage, success : Int) -> String {
  let res = []
  self.classes.each(fn(s, i) {
    res.push("\{format_percent(i, success)} : \{s}")
  })
  res.join("\n")
}

///|
/// Render the labels + classes tally as percentage lines for the
/// report (normalised against `success`, the number of passing
/// samples). Called by `CheckReport::render` in the root package.
pub fn Coverage::to_string(self : Coverage, success : Int) -> String {
  let res = [
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
    ]
    .filter(x => x != "")
    .join("\n")
  res
}
