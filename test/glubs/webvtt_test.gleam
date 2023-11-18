import gleeunit/should
import gleam/option.{None, Some}
import glubs/webvtt.{Cue, EndTag, Note, StartTag, Text, Timestamp, WebVTT}
import simplifile

pub fn parse_invalid_header_test() {
  "INVALID"
  |> webvtt.parse()
  |> should.equal(Error("Must start with \"WEBVTT\""))
}

pub fn parse_attached_header_test() {
  "WEBVTTinvalid"
  |> webvtt.parse()
  |> should.equal(Error("Header comment must start with space or tab"))
}

pub fn parse_only_header_test() {
  "WEBVTT"
  |> webvtt.parse()
  |> should.be_ok()
}

pub fn parse_header_with_comment_test() {
  "WEBVTT This is a comment"
  |> webvtt.parse()
  |> should.equal(Ok(WebVTT(comment: Some("This is a comment"), items: [])))
}

pub fn parse_cue_test() {
  "WEBVTT\n\n1\n00:00.123 --> 00:00.456\nTest"
  |> webvtt.parse()
  |> should.equal(Ok(WebVTT(
    comment: None,
    items: [Cue(id: Some("1"), start_time: 123, end_time: 456, payload: "Test")],
  )))
}

pub fn parse_comment_test() {
  let assert Ok(content) = simplifile.read("test/fixtures/comments.vtt")

  content
  |> webvtt.parse()
  |> should.equal(Ok(WebVTT(
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
  )))
}

pub fn to_string_test() {
  let assert Ok(expected) = simplifile.read("test/fixtures/comments.vtt")

  WebVTT(
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
  )
  |> webvtt.to_string()
  |> should.equal(expected)
}

pub fn tokenize_text_test() {
  "Hello"
  |> webvtt.tokenize()
  |> should.equal(Ok([Text("Hello")]))
}

pub fn tokenize_voice_test() {
  "<v.loud.shout Rob>Hello</v>"
  |> webvtt.tokenize()
  |> should.equal(Ok([
    StartTag("v", classes: ["loud", "shout"], annotation: Some("Rob")),
    Text("Hello"),
    EndTag("v"),
  ]))
}

pub fn timestamp_tag_test() {
  "Hello <00:19.500>Phil. <01:00:00.500>How are you?"
  |> webvtt.tokenize()
  |> should.equal(Ok([
    Text("Hello "),
    Timestamp(19_500),
    Text("Phil. "),
    Timestamp(3_600_500),
    Text("How are you?"),
  ]))
}

pub fn complex_test() {
  "<v Phil>Hi!\n<v.loud.shout Rob>Hello <i>mate!</i></v>"
  |> webvtt.tokenize()
  |> should.equal(Ok([
    StartTag("v", classes: [], annotation: Some("Phil")),
    Text("Hi!\n"),
    StartTag("v", classes: ["loud", "shout"], annotation: Some("Rob")),
    Text("Hello "),
    StartTag("i", classes: [], annotation: None),
    Text("mate!"),
    EndTag("i"),
    EndTag("v"),
  ]))
}
