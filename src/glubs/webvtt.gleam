import gleam/option.{None, Some}
import gleam/string
import gleam/result
import gleam/list
import gleam/int

pub type Cue {
  Cue(
    id: option.Option(String),
    start_time: Int,
    end_time: Int,
    payload: String,
  )
}

pub type WebVTT {
  WebVTT(comment: option.Option(String), cues: List(Cue))
}

pub type ParserError {
  ParserError(String)
}

pub fn parse(webvtt: String) -> Result(WebVTT, ParserError) {
  let [header, ..cues] =
    webvtt
    |> string.replace("\r\n", "\n")
    |> string.split("\n\n")

  // TODO: Metadata still needs to be parsed
  let [header, ..] = string.split(header, "\n")

  use comment <- result.try(parse_comment(header))
  use cues <- result.try(list.try_map(cues, parse_cue))

  Ok(WebVTT(comment: comment, cues: cues))
}

pub fn to_string(_webvtt: WebVTT) -> String {
  todo
}

fn parse_comment(header: String) -> Result(option.Option(String), ParserError) {
  case header {
    "WEBVTT" -> Ok(None)
    "WEBVTT\t" <> comment -> Ok(Some(comment))
    "WEBVTT " <> comment -> Ok(Some(comment))
    "WEBVTT" <> _other ->
      Error(ParserError("Header comment must start with space or tab"))
    _other -> Error(ParserError("Must start with \"WEBVTT\""))
  }
}

fn parse_cue(cue: String) -> Result(Cue, ParserError) {
  use #(id, rest) <- result.try(parse_cue_id(cue))

  case string.split_once(rest, "\n") {
    Ok(#(line, payload)) -> {
      use #(start, end) <- result.try(parse_timestamps(line))
      Ok(Cue(id: id, payload: payload, start_time: start, end_time: end))
    }
    Error(Nil) -> Error(ParserError("Invalid cue"))
  }
}

fn parse_cue_id(
  cue: String,
) -> Result(#(option.Option(String), String), ParserError) {
  case string.split_once(cue, "\n") {
    Ok(#(id, rest)) -> {
      case string.contains(id, "-->") {
        True -> Ok(#(None, cue))
        False -> Ok(#(Some(id), rest))
      }
    }
    Error(Nil) -> Error(ParserError("Invalid cue"))
  }
}

fn parse_timestamps(line: String) -> Result(#(Int, Int), ParserError) {
  case string.split(line, " --> ") {
    [start, end] -> {
      use start <- result.try(
        start
        |> parse_timestamp()
        |> result.replace_error(ParserError("Invalid start timestamp")),
      )

      use end <- result.try(
        end
        |> parse_timestamp()
        |> result.replace_error(ParserError("Invalid end timestamp")),
      )

      Ok(#(start, end))
    }
    _other -> Error(ParserError("Invalid timestamp"))
  }
}

pub type Token {
  StartTag(
    tag: String,
    classes: List(String),
    annotation: option.Option(String),
  )
  Text(content: String)
  Timestamp(ms: Int)
  EndTag(tag: String)
}

pub type TokenizationError {
  InvalidStartToken
  InvalidEndToken
}

pub fn tokenize(payload: String) -> Result(List(Token), TokenizationError) {
  payload
  |> do_tokenize([])
  |> result.map(list.reverse)
}

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
  case string.split(input, on: ":") {
    [hours, minutes, seconds_and_ms] -> {
      use hours <- result.try(int.parse(hours))
      use minutes <- result.try(int.parse(minutes))
      use #(seconds, ms) <- result.try(split_seconds(seconds_and_ms))

      Ok({ seconds + minutes * 60 + hours * 60 * 60 } * 1000 + ms)
    }

    [minutes, seconds_and_ms] -> {
      use minutes <- result.try(int.parse(minutes))
      use #(seconds, ms) <- result.try(split_seconds(seconds_and_ms))

      Ok({ seconds + minutes * 60 } * 1000 + ms)
    }

    [_] -> Error(Nil)
  }
}

fn split_seconds(input: String) -> Result(#(Int, Int), Nil) {
  case string.split_once(input, on: ".") {
    Ok(#(seconds, ms)) -> {
      use seconds <- result.try(int.parse(seconds))
      use ms <- result.try(int.parse(ms))
      Ok(#(seconds, ms))
    }
    Error(_) -> {
      use seconds <- result.try(int.parse(input))
      Ok(#(seconds, 0))
    }
  }
}
