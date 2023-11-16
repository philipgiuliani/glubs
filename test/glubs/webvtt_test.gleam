import gleeunit/should
import gleam/option.{None, Some}
import glubs/webvtt.{EndTag, StartTag, Text, Timestamp}

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
