impl Arbitrary for Int with shrink(x) {
  Iter::new(
    fn {
      yield => {
        let mut y = x
        while y < -2 || y > 2 {
          y = y / 2
          if yield(x - y) == IterEnd {
            break IterEnd
          }
        } else {
          /// Aggressive shrink
          if x > 0 {
            for i = x - 1; i > 0; i = i - 1 {
              if yield(i) == IterEnd {
                break IterEnd
              }
            } else {
              IterEnd
            }
          } else {
            for i = x + 1; i > 0; i = i + 1 {
              if yield(i) == IterEnd {
                break IterEnd
              }
            } else {
              IterEnd
            }
          }
        }
      }
    },
  )
}

impl Arbitrary for Int64 with shrink(x) {
  Iter::new(
    fn {
      yield => {
        let mut y = x
        while y < -2 || y > 2 {
          y = y / 2
          match yield(x - y) {
            IterEnd => break IterEnd
            IterContinue => ()
          }
        } else {
          if x == 1 || (x > 0 && y != 1) {
            yield(x - 1)
          } else if x == -1 || (x < 0 && y != -1) {
            yield(x + 1)
          } else {
            IterEnd
          }
        }
      }
    },
  )
}