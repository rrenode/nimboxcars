<p align="center">
  <a href="https://nim-lang.org/">
    <img alt="Nim" src="https://img.shields.io/badge/Nim-FFE953?style=for-the-badge&logo=nim&logoColor=black" />
  </a>
</p>

# NimBoxCars
NimBoxCars is a [Rocket League](http://www.rocketleaguegame.com/) replay parser library and tool written in Nim.

## ToDos
- [ ] C bindings
- [ ] Online Docs
- [ ] Convenience Tool for quick visualization of info (such as players, team names, etc.)
- [ ] Get this jawn listed on Nimble

## Tool Usage

Download the binary from the releases page. Rocket League replays are typically
stored in `%USERPROFILE%\Documents\My Games\TAGame\Demos` on Windows.

Open PowerShell in the folder containing `nimboxcars.exe`, then run it with the
path to your replay. Keep the path in quotes if it contains spaces:

```powershell
.\nimboxcars.exe "C:\path\to\match.replay"
```

To include decoded network frames and output JSON:

```powershell
.\nimboxcars.exe --netdata:all --json "C:\path\to\match.replay"
```

## Goals
A lib written in Nim that parses entire replay files into Nim objects.
Preserve unknown data in a structured form.
Expose a raw/debug view without forcing raw everywhere.

## Why do this and not just use x?

This project started out of a necessity to support another project; but quickly turned into a "I can't believe this is what's going on between the clients and server"; which eventually became a "why in the world is it designed like this"; then "who in their right mind"; and finally to "it's done and I still don't like their design choices". Psst... it's a 10+ year-old game that I absolutely love, no hate on the devs at Psyonix.

"Okay, yeah. Great story," you exclaim sarcastically quickly following up with asking, "But why not one of the many other greats libs for this purpose like like [rattletrap](https://github.com/tfausak/rattletrap), [CPPRP](https://github.com/Bakkes/CPPRP), [RocketLeague Replay Parser](https://github.com/jjbott/RocketLeagueReplayParser), [RocketRP](https://github.com/Drogebot/RocketRP), or [boxcars](https://crates.io/crates/boxcars)?"

Good question. And it basically boils down to requirements I made for the project that inspired nimboxcar and my own preferences. The inspiration project is written in Nim and I wanted to, as best as possible without spreading myself too thin, write the entire project in Nim as a way to familiarize with this, thus far, wonderful language I began learning and using since mid 2025. I could utilize Rust's and Nim's FFI to get interoptability with our favorite middleman language; C. But alas, this seemed more fun while opening me up to more opportunity for my goal of learning Nim.

With that, if one of the others listed above fit your needs better, then by all means they're all pretty great! Actually I have more about [RL replay parsers on my public journal]().


## About NimBoxCar's Current State
NimBoxCars is currently an infant. As such it lacks quite a bit of functionality that may be expected. Regardless, a solid foundation for a future, mature project has been laid. 

As a **lib**, NimBoxCars provides object types (most notably the Replay object). It also provides binary step-reading procs for replay files' data types. There's far too much in the lib to go over here in the readme so please see TODO:LibDocs.

In terms of **parsing**, the header, body, and network frames are decoded into Nim objects. Network decoding follows the local boxcars 0.10.11 snapshot, including actor creation, updates, deletion, and version-dependent attribute layouts. Newer wire formats may require updated models and decoders.

To decode network frames from the library:

```nim
import nimboxcars/parser

let replay = parseReplay("match.replay", getAll, checkCrc = true)
let frames = replay.body.networkFrames.get.frames
```

`skipParsing` skips network bytes; `skipDeserial` retains raw network bytes;
`getAll` also decodes frames. To decode a previously loaded raw replay, call
`decodeNetwork(replay.header, replay.body)`. Invalid or unsupported network data
raises `NetworkDecodeError` with decoding context.

The CLI supports `--netdata:all --json match.replay` for JSON with decoded
`network_frames`. Without decoding, that JSON field is null. Network JSON uses
boxcars's tagged variants, snake_case fields, and strings for 64-bit integers.

Run the decoder regression tests with:

```powershell
nim c -r --path:src tests/TEST_network.nim
```

With rrrocket 0.10.11 installed, compare every network field in the replay fixtures:

```powershell
nim c -d:release --path:src --out:bin/debug/nimboxcars-network.exe src/nimboxcars.nim
python tests/compare_network.py --nim bin/debug/nimboxcars-network.exe
```

The comparison permits small floating-point rounding differences (2e-6 relative
or absolute tolerance); other values must match exactly.


# A HUGE THANK YOU TO
## GitHub User: tanrbobanr
He has graciously made a repository that documents Rocket League's replay format. [Check it out!](https://github.com/tanrbobanr/rocket-league-replay-format)

## GitHub User: jjbott
For being responsible for inital reverse engineering efforts of Rocket League's replay file and contacting with me about the project on occasion. [The original thread on Psyonix Fourms](https://web.archive.org/web/20190501232510/https://psyonix.com/forum/viewtopic.php?f=33&t=13656)

## and nameless others...
All who put in much work into reverse engineering replay files. Opening up to modern day RL tools; analysis; ballchasing; Boxcars; etc. From their hard work of the past I get to focus on design of this project. 

___
### FOOTNOTES:
n/a
