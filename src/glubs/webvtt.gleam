import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/result
import gleam/list
import gleam/string_builder.{type StringBuilder}
import glubs/timestamp

/// Item represents an individual item in a WebVTT file, which can be either a Note or a Cue.
pub type Item {
  Note(String)
  Style(String)
  Cue(
    id: Option(String),
    start_time: Int,
    end_time: Int,
    payload: String,
    settings: List(#(String, String)),
  )
}

/// Represents a WebVTT file with an optional comment and a list of items.
pub type WebVTT {
  WebVTT(
    metadata: List(#(String, String)),
    comment: Option(String),
    items: List(Item),
  )
}

/// Parses a WebVTT string and returns a Result containing the parsed WebVTT structure or a parsing error.
pub fn parse(webvtt: String) -> Result(WebVTT, String) {
  let [header, ..body] =
    webvtt
    |> string.replace("\r\n", "\n")
    |> string.trim_right()
    |> string.split("\n\n")

  let [header, ..metadata] = string.split(header, "\n")

  use comment <- result.try(parse_comment(header))
  use metadata <- result.try(parse_metadata(metadata))
  use items <- result.try(list.try_map(body, parse_item))

  Ok(WebVTT(metadata: metadata, comment: comment, items: items))
}

/// Converts a WebVTT type to a string.
pub fn to_string(webvtt: WebVTT) -> String {
  let assert WebVTT(metadata: metadata, comment: comment, items: items) = webvtt

  [
    header_to_string(comment),
    metadata_to_string(metadata),
    items_to_string(items),
  ]
  |> list.filter(fn(b) { string_builder.is_empty(b) == False })
  |> string_builder.join("\n")
  |> string_builder.append("\n")
  |> string_builder.to_string()
}

fn header_to_string(comment: Option(String)) -> StringBuilder {
  case comment {
    Some(comment) -> string_builder.from_strings(["WEBVTT ", comment])
    None -> string_builder.from_string("WEBVTT")
  }
}

fn metadata_to_string(metadata: List(#(String, String))) -> StringBuilder {
  case list.is_empty(metadata) {
    True -> string_builder.new()
    False ->
      metadata
      |> list.map(fn(item) {
        let separator = case item.0 == "X-TIMESTAMP-MAP" {
          True -> "="
          False -> ": "
        }

        string_builder.from_strings([item.0, separator, item.1])
      })
      |> string_builder.join("\n")
  }
}

fn items_to_string(items: List(Item)) -> StringBuilder {
  case list.is_empty(items) {
    True -> string_builder.new()
    False -> {
      items
      |> list.map(item_to_string)
      |> string_builder.join("\n\n")
      |> string_builder.prepend("\n")
    }
  }
}

fn item_to_string(item: Item) -> StringBuilder {
  case item {
    Note(content) ->
      case string.contains(content, "\n") {
        True -> string_builder.from_strings(["NOTE\n", content])
        False -> string_builder.from_strings(["NOTE ", content])
      }
    Style(content) -> string_builder.from_strings(["STYLE\n", content])
    Cue(
      id: id,
      start_time: start_time,
      end_time: end_time,
      payload: payload,
      settings: settings,
    ) -> {
      let start_time = timestamp.to_string(start_time, ".")
      let end_time = timestamp.to_string(end_time, ".")
      let settings_builder = settings_to_string(settings)
      let timestamp =
        start_time
        |> string_builder.append(" --> ")
        |> string_builder.append_builder(end_time)
        |> string_builder.append_builder(settings_builder)

      case id {
        Some(id) -> {
          string_builder.from_string(id)
          |> string_builder.append("\n")
          |> string_builder.append_builder(timestamp)
        }
        None -> timestamp
      }
      |> string_builder.append("\n")
      |> string_builder.append(payload)
    }
  }
}

fn settings_to_string(settings: List(#(String, String))) -> StringBuilder {
  case settings {
    [] -> string_builder.new()
    settings ->
      settings
      |> list.map(fn(item) {
        string_builder.from_strings([item.0, ":", item.1])
      })
      |> string_builder.join(" ")
      |> string_builder.prepend(" ")
  }
}

fn parse_metadata(
  metadata: List(String),
) -> Result(List(#(String, String)), String) {
  metadata
  |> list.try_map(fn(meta) {
    case meta {
      "X-TIMESTAMP-MAP=" <> header -> Ok(#("X-TIMESTAMP-MAP", header))
      _other -> {
        case string.split_once(meta, ": ") {
          Ok(entry) -> Ok(entry)
          Error(Nil) -> Error("Invalid metadata item")
        }
      }
    }
  })
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
  |> result.try_recover(fn(_) { parse_style(item) })
  |> result.try_recover(fn(_) { parse_cue(item) })
}

fn parse_note(note: String) -> Result(Item, String) {
  case note {
    "NOTE\n" <> note -> Ok(Note(note))
    "NOTE " <> note -> Ok(Note(note))
    _other -> Error("Invalid note")
  }
}

fn parse_style(style: String) -> Result(Item, String) {
  case style {
    "STYLE\n" <> style -> Ok(Style(style))
    _other -> Error("Invalid style")
  }
}

fn parse_cue(cue: String) -> Result(Item, String) {
  use #(id, rest) <- result.try(parse_cue_id(cue))

  case string.split_once(rest, "\n") {
    Ok(#(line, payload)) -> {
      use #(start, end, rest) <- result.try(timestamp.parse_range(line, "."))
      use settings <- result.try(parse_settings(rest))

      Ok(Cue(
        id: id,
        payload: payload,
        start_time: start,
        end_time: end,
        settings: settings,
      ))
    }
    Error(Nil) -> Error("Invalid cue")
  }
}

fn parse_settings(settings: String) -> Result(List(#(String, String)), String) {
  case settings != "" {
    True ->
      settings
      |> string.split(" ")
      |> list.try_map(fn(setting) {
        case string.split_once(setting, ":") {
          Ok(item) -> Ok(item)
          Error(Nil) -> Error("Invalid cue settings")
        }
      })
    False -> Ok([])
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

/// Tokenizes the given cue payload and returns a Result containing the list of generated tokens or a tokenization error.
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
          case timestamp.parse(tag, ".") {
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
