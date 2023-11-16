import gleam/option.{None, Some}
import gleam/string
import gleam/result
import gleam/list
import gleam/int

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
