import gleeunit/should
import glubs/srt.{type Srt, Cue, Srt}
import simplifile

pub fn parse_example_test() {
  let assert Ok(content) = simplifile.read("test/fixtures/example.srt")

  content
  |> srt.parse()
  |> should.equal(Ok(example()))
}

pub fn to_string_example_test() {
  let assert Ok(expected) = simplifile.read("test/fixtures/example.srt")

  example()
  |> srt.to_string()
  |> should.equal(expected)
}

fn example() -> Srt {
  Srt([
    Cue(
      1,
      136_612,
      139_376,
      "Senator, we're making\nour final approach into Coruscant.",
    ),
    Cue(2, 139_482, 141_609, "Very good, Lieutenant."),
    Cue(3, 193_336, 195_167, "We made it."),
    Cue(4, 198_608, 200_371, "I guess I was wrong."),
    Cue(5, 200_476, 202_671, "There was no danger at all."),
  ])
}
