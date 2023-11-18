import gleam/string
import gleam/list
import gleam/result
import gleam/int
import gleam/string_builder.{StringBuilder}
import glubs/timestamp

pub type Srt {
  Srt(cues: List(Cue))
}

// Cue represents a single cue in a srt file.
pub type Cue {
  Cue(id: Int, start_time: Int, end_time: Int, payload: String)
}

// Parses a Srt string and returns a Result containing the parsed Srt structure or a parsing error.
pub fn parse(input: String) -> Result(Srt, String) {
  input
  |> string.replace("\r\n", "\n")
  |> string.trim_right()
  |> string.split("\n\n")
  |> list.try_map(parse_cue)
  |> result.map(Srt(cues: _))
}

/// Converts a Srt type to a string.
pub fn to_string(srt: Srt) -> String {
  srt.cues
  |> list.map(cue_to_string)
  |> string_builder.join("\n\n")
  |> string_builder.append("\n")
  |> string_builder.to_string()
}

fn cue_to_string(cue: Cue) -> StringBuilder {
  let start_time = timestamp.to_string(cue.start_time, ",")
  let end_time = timestamp.to_string(cue.end_time, ",")

  [
    string_builder.from_string(int.to_string(cue.id)),
    start_time
    |> string_builder.append(" --> ")
    |> string_builder.append_builder(end_time),
    string_builder.from_string(cue.payload),
  ]
  |> string_builder.join("\n")
}

fn parse_cue(input: String) -> Result(Cue, String) {
  let [id, ts, ..lines] = string.split(input, "\n")

  use id <- result.try(
    id
    |> int.parse()
    |> result.replace_error("Cannot parse identifier"),
  )

  use #(start_time, end_time) <- result.try(timestamp.parse_range(ts, ","))

  Ok(Cue(
    id: id,
    start_time: start_time,
    end_time: end_time,
    payload: string.join(lines, "\n"),
  ))
}
