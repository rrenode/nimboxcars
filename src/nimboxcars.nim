## nimboxcars CLI - A Rocket League replay parser written in Nim
## Copyright (c) 2026 by Robert J. Renode IV

import std/[parseopt, options]
import nimboxcars/parser
import nimboxcars/jsonmodel/[flavors, rrrocket_flavor]

export parseReplay, model

from std/os import paramCount

const helpText = """
nimboxcars — A Rocket League replay parser and lib written in Nim

USAGE
  nimboxcars [OPTIONS] REPLAY_PATH

DESCRIPTION
  Reads a Rocket League replay and prints its contents in various formats.
  By default, the replay is decoded and echoed as a structured replay object.
  No loggin; when something echoes to stdout, the program quits.

ARGUMENTS
  REPLAY_PATH
      Path to the replay file to read.

OPTIONS
  -j, --json
      Output the replay as JSON.

  --flavor <NAME>
      Select the JSON flavor used for serialization (auto enables json output).

      Available values:
        rrrocket    Default JSON schema.

  --netdata <MODE>
      Controls how network data is handled during parsing.

      Modes:
        skip    Skip network data entirely. (default)
        parse   Parse network data but do not deserialize it.
                The raw payload is returned as a byte sequence.
        all     Fully parse and deserialize network data.

  --crc
      Enforces CRC validation; error if validation fails.

  -h, --help
      Show this help message and exit.
"""

when isMainModule:
  var replayFilePath: Option[string] = none(string)
  var jsonOutput: bool = false
  var dataFlavor: JsonFlavors = JsonFlavors.rrrocket
  var netDataMode: NetworkDataParseMode = NetworkDataParseMode.skipParsing
  var checkCrc: bool = false

  if paramCount() == 0:
    echo helpText
    quit()

  for kind, key, val in getopt():
    case kind:
    of cmdArgument:
      replayFilePath = some(key)
    of cmdLongOption, cmdShortOption:
      case key:
      of "-h", "--help":
        echo helpText
        quit()
      of "j", "--json":
        if val != "":
          echo "The `-j` option is a flag! Attached value found: " & val
          quit()
        jsonOutput = true
        continue
      of "--flavor":
        case val:
        of "rrrocket":
          dataFlavor = JsonFlavors.rrrocket
        else:
          echo "Selected output flavor does not exist: " & val
          echo "Options are: `rrrocket`"
          quit()
      of "--netdata":
        case val:
        of "skip":
          netDataMode = NetworkDataParseMode.skipParsing
        of "parse":
          netDataMode = NetworkDataParseMode.skipDeserial
        of "all":
          netDataMode = NetworkDataParseMode.getAll
        else:
          echo "Selected netdata mode does not exist: " & val
          echo "Options are: `skip`, `parse`, or `all`"
          quit()
      of "crc":
        checkCrc = true
      else:
        echo "Unknown command option of `", key, "`"
        quit()
    of cmdEnd:
      discard
  
  if replayFilePath.isNone():
    echo "Replay file path not provided!"
    quit()

  let replay = parseReplay(replayFilePath.get(), netDataMode, checkCrc)

  if jsonOutput:
    case dataFlavor:
    of JsonFlavors.rrrocket:
      let json = RRRocketFlavor.encode(replay)
      echo json
  else:
    echo replay