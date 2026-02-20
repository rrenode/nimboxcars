## RL Replay Parser - Robert J Renode IV (Feb. 2026)
## 
## Instrumental in writing this was tanrbobanr's documentation of the RL replay binary structure.
##  https://github.com/tanrbobanr/rocket-league-replay-format/blob/main/rpdoc_generated.md
## Additionally, boxcars (a rust RL replay lib) served to help me avoid reverse-engineering more modern RL replay formats.
## Fun fact: Modern replay formats have StructProperty!
import std/[streams]
import props, primitives

type
  ReplayHeader* = object
    hSize*: uint32
    headerCrc*: uint32
    majorVersion*: uint32
    minorVersion*: uint32
    netVersion*: uint32
    gameType*: string
    props*: Properties

  Replay* = object
    header*: ReplayHeader

proc parseReplay*(replayPath: string): Replay =
  var f: FileStream = newFileStream(replayPath, fmRead)
  if f.isNil:
    raise newException(IOError, "Cannot open file: " & replayPath)
  defer: f.close()

  result.header.hSize = readU32(f)
  result.header.headerCrc = readU32(f)
  result.header.majorVersion = readU32(f)
  result.header.minorVersion = readU32(f)
  result.header.netVersion = readU32(f)
  result.header.gameType = readString8(f)
  result.header.props = readPropertiesUntilNone(f)