import gleam/option.{None, Option, Some}
import gleam/string
import gleam/result
import gleam/list
import gleam/int

/// Item represents an individual item in a WebVTT file, which can be either a Note or a Cue.
pub type Item {
  Note(String)
  Cue(id: Option(String), start_time: Int, end_time: Int, payload: String)
}

/// Represents a WebVTT file with an optional comment and a list of items.
pub type WebVTT {
  WebVTT(comment: Option(String), items: List(Item))
}

// Parses a WebVTT string and returns a Result containing the parsed WebVTT structure or a parsing error.
pub fn parse(webvtt: String) -> Result(WebVTT, String) {
  let [header, ..cues] =
    webvtt
    |> string.replace("\r\n", "\n")
    |> string.trim_right()
    |> string.split("\n\n")

  // TODO: Metadata still needs to be parsed as soon as the specification is clear
  let [header, ..] = string.split(header, "\n")

  use comment <- result.try(parse_comment(header))
  use items <- result.try(list.try_map(cues, parse_item))

  Ok(WebVTT(comment: comment, items: items))
}

fn parse_comment(header: String) -> Result(Option(String), String) {
  case header {
    "WEBVTT" -> Ok(None)
    "WEBVTT\t" <> comment -> Ok(Some(comment))
    "WEBVTT " <> comment -> Ok(Some(comment))
    "WEBVTT" <> _other -> Error("Header comment must start with space or tab")
    _other -> Error("Must start with \"WEBVTT\"")
  }
}

fn parse_item(item: String) -> Result(Item, String) {
  item
  |> parse_note()
  |> result.try_recover(fn(_) { parse_cue(item) })
}

fn parse_note(note: String) -> Result(Item, String) {
  case note {
    "NOTE\n" <> note -> Ok(Note(note))
    "NOTE " <> note -> Ok(Note(note))
    _other -> Error("Invalid note")
  }
}

fn parse_cue(cue: String) -> Result(Item, String) {
  use #(id, rest) <- result.try(parse_cue_id(cue))

  case string.split_once(rest, "\n") {
    Ok(#(line, payload)) -> {
      use #(start, end) <- result.try(parse_timestamps(line))
      Ok(Cue(id: id, payload: payload, start_time: start, end_time: end))
    }
    Error(Nil) -> Error("Invalid cue")
  }
}

fn parse_cue_id(cue: String) -> Result(#(Option(String), String), String) {
  case string.split_once(cue, "\n") {
    Ok(#(id, rest)) -> {
      case string.contains(id, "-->") {
        True -> Ok(#(None, cue))
        False -> Ok(#(Some(id), rest))
      }
    }
    Error(Nil) -> Error("Invalid cue")
  }
}

fn parse_timestamps(line: String) -> Result(#(Int, Int), String) {
  case string.split(line, " --> ") {
    [start, end] -> {
      use start <- result.try(
        start
        |> parse_timestamp()
        |> result.replace_error("Invalid start timestamp"),
      )

      use end <- result.try(
        end
        |> parse_timestamp()
        |> result.replace_error("Invalid end timestamp"),
      )

      Ok(#(start, end))
    }
    _other -> Error("Invalid timestamp")
  }
}

/// Token represents individual tokens that can be generated during the tokenization of WebVTT cue payload.
pub type Token {
  StartTag(tag: String, classes: List(String), annotation: Option(String))
  Text(content: String)
  Timestamp(ms: Int)
  EndTag(tag: String)
}

/// TokenizationError represents errors that may occur during the tokenization process.
pub type TokenizationError {
  InvalidStartToken
  InvalidEndToken
}

pub fn tokenize(payload: String) -> Result(List(Token), TokenizationError) {
  payload
  |> do_tokenize([])
  |> result.map(list.reverse)
}

/// Tokenizes the given cue payload and returns a Result containing the list of generated tokens or a tokenization error.
fn do_tokenize(
  payload: String,
  acc: List(Token),
) -> Result(List(Token), TokenizationError) {
  case payload {
    "" -> Ok(acc)
    "</" <> rest -> {
      case string.split_once(rest, on: ">") {
        Ok(#(tag, rest)) -> {
          do_tokenize(rest, [EndTag(tag: tag), ..acc])
        }
        Error(Nil) -> {
          Error(InvalidEndToken)
        }
      }
    }
    "<" <> rest -> {
      case string.split_once(rest, on: ">") {
        Ok(#(tag, rest)) -> {
          case parse_timestamp(tag) {
            Ok(ts) -> do_tokenize(rest, [Timestamp(ts), ..acc])
            Error(_) -> do_tokenize(rest, [parse_start_tag(tag), ..acc])
          }
        }
        Error(Nil) -> {
          Error(InvalidStartToken)
        }
      }
    }
    text -> {
      case string.split_once(text, on: "<") {
        Ok(#(content, rest)) -> {
          do_tokenize("<" <> rest, [Text(content), ..acc])
        }
        Error(Nil) -> Ok([Text(text), ..acc])
      }
    }
  }
}

fn parse_start_tag(input: String) -> Token {
  case string.split_once(input, on: " ") {
    Ok(#(tag_and_classes, annotation)) -> {
      let #(tag, classes) = parse_tag_and_classes(tag_and_classes)
      StartTag(tag: tag, classes: classes, annotation: Some(annotation))
    }
    Error(_) -> {
      let #(tag, classes) = parse_tag_and_classes(input)
      StartTag(tag: tag, classes: classes, annotation: None)
    }
  }
}

fn parse_tag_and_classes(input: String) -> #(String, List(String)) {
  let [tag, ..classes] = string.split(input, on: ".")
  #(tag, classes)
}

fn parse_timestamp(input: String) -> Result(Int, Nil) {
  use #(h, m, s_ms) <- result.try({
    case string.split(input, on: ":") {
      [m, s_ms] -> Ok(#("0", m, s_ms))
      [h, m, s_ms] -> Ok(#(h, m, s_ms))
      _ -> Error(Nil)
    }
  })

  use h <- result.try(int.parse(h))
  use m <- result.try(int.parse(m))
  use #(s, ms) <- result.try(split_seconds(s_ms))

  Ok({ s + m * 60 + h * 60 * 60 } * 1000 + ms)
}

fn split_seconds(input: String) -> Result(#(Int, Int), Nil) {
  case string.split(input, on: ".") {
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
