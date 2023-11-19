# glubs - Subtitle parser

[![Package Version](https://img.shields.io/hexpm/v/glubs)](https://hex.pm/packages/glubs)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/glubs/)

glubs is a WebVTT and SRT parser and serializer written in Gleam.
It also has a tokenizer for formatted WebVTT payloads.

## Installation

If available on Hex this package can be added to your Gleam project:

```sh
gleam add glubs
```

and its documentation can be found at <https://hexdocs.pm/glubs>.

## Features

* [x] Parses WebVTT files into a structured format
* [x] Handles both comments and cues with start and end times
* [x] Tokenizes WebVTT cue payload into individual tokens
* [x] Converts a WebVTT type back to a string
* [x] Parse SRT
* [x] Convert SRT to string
* [x] Support WebVTT STYLE-Tags (https://developer.mozilla.org/en-US/docs/Web/API/WebVTT_API#styling_webvtt_cues)
* [x] Support WebVTT cue settings (https://developer.mozilla.org/en-US/docs/Web/API/WebVTT_API#cue_settings)
* [ ] Support WebVTT header metadata

## Example

```gleam
import glubs/webvtt.{Cue, EndTag, Note, StartTag, Text, WebVTT}
import gleam/option.{None, Some}
import simplifile

pub fn main() {
  // WebVTT parser
  let assert Ok(content) = simplifile.read("test/fixtures/comments.vtt")
  let assert Ok(result) = webvtt.parse(content)

  let assert WebVTT(
    comment: Some("- Translation of that film I like"),
    items: [
      Note(
        "This translation was done by Kyle so that\nsome friends can watch it with their parents.",
      ),
      Cue(
        id: Some("1"),
        start_time: 135_000,
        end_time: 140_000,
        payload: "- Ta en kopp varmt te.\n- Det är inte varmt.",
      ),
      Cue(
        id: Some("2"),
        start_time: 140_000,
        end_time: 145_000,
        payload: "- Har en kopp te.\n- Det smakar som te.",
      ),
      Note("This last line may not translate well."),
      Cue(
        id: Some("3"),
        start_time: 145_000,
        end_time: 150_000,
        payload: "- Ta en kopp",
      ),
    ],
  ) = result

  // Cue payload tokenizer
  let assert Ok(tokens) =
    "<v Phil>Hi!\n<v.loud.shout Rob>Hello <i>mate!</i></v>"
    |> webvtt.tokenize()

  let assert [
    StartTag("v", classes: [], annotation: Some("Phil")),
    Text("Hi!\n"),
    StartTag("v", classes: ["loud", "shout"], annotation: Some("Rob")),
    Text("Hello "),
    StartTag("i", classes: [], annotation: None),
    Text("mate!"),
    EndTag("i"),
    EndTag("v"),
  ] = tokens
}
```
