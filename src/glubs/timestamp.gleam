import gleam/result
import gleam/string
import gleam/string_builder.{type StringBuilder}
import gleam/int

// Parses the given string to a timestamp.
pub fn parse(input: String, fraction_sep: String) -> Result(Int, Nil) {
  use #(h, m, s_ms) <- result.try({
    case string.split(input, on: ":") {
      [m, s_ms] -> Ok(#("0", m, s_ms))
      [h, m, s_ms] -> Ok(#(h, m, s_ms))
      _ -> Error(Nil)
    }
  })

  use h <- result.try(int.parse(h))
  use m <- result.try(int.parse(m))
  use #(s, ms) <- result.try(split_seconds(s_ms, fraction_sep))

  Ok({ s + m * 60 + h * 60 * 60 } * 1000 + ms)
}

// Parses a timestamp range.
pub fn parse_range(
  line: String,
  fraction_sep: String,
) -> Result(#(Int, Int, String), String) {
  case string.split(line, " --> ") {
    [start, end_with_rest] -> {
      use start <- result.try(
        start
        |> parse(fraction_sep)
        |> result.replace_error("Invalid start timestamp"),
      )

      let #(end, rest) = case string.split_once(end_with_rest, " ") {
        Ok(result) -> result
        Error(Nil) -> #(end_with_rest, "")
      }

      use end <- result.try(
        end
        |> parse(fraction_sep)
        |> result.replace_error("Invalid end timestamp"),
      )

      Ok(#(start, end, rest))
    }
    _other -> Error("Invalid timestamp")
  }
}

// Converts the given ms to a timestamp.
pub fn to_string(ms: Int, fraction_sep: String) -> StringBuilder {
  let hours = pad({ ms / 3_600_000 }, 2)
  let minutes = pad({ { ms % 3_600_000 } / 60_000 }, 2)
  let seconds = pad({ ms % 60_000 } / 1000, 2)
  let ms = pad(ms % 1000, 3)

  string_builder.from_strings([
    hours,
    ":",
    minutes,
    ":",
    seconds,
    fraction_sep,
    ms,
  ])
}

fn split_seconds(
  input: String,
  fraction_sep: String,
) -> Result(#(Int, Int), Nil) {
  case string.split(input, on: fraction_sep) {
    [_s] -> {
      use s <- result.try(int.parse(input))
      Ok(#(s, 0))
    }
    [s, ms] -> {
      use s <- result.try(int.parse(s))
      use ms <- result.try(int.parse(ms))
      Ok(#(s, ms))
    }
    _other -> Error(Nil)
  }
}

fn pad(number: Int, count: Int) -> String {
  number
  |> int.to_string()
  |> string.pad_left(count, "0")
}
