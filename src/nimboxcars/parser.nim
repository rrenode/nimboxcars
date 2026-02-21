## RL Replay Parser - Robert J Renode IV (Feb. 2026)
## 
## Instrumental in writing this was tanrbobanr's documentation of the RL replay binary structure.
##  https://github.com/tanrbobanr/rocket-league-replay-format/blob/main/rpdoc_generated.md
## Additionally, boxcars (a rust RL replay lib) served to help me avoid reverse-engineering more modern RL replay formats.
## Fun fact: Modern replay formats have StructProperty!
import std/[streams]
import props, primitives

export Properties

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

proc parseHeader*(s: Stream): ReplayHeader =
  ## Parse replay file stream into ReplayHeader.
  result.hSize = readUint32Ctx(s, "header.hSize")
  result.headerCrc = readUint32Ctx(s, "header.crc")
  result.majorVersion = readUint32Ctx(s, "header.majorVersion")
  result.minorVersion = readUint32Ctx(s, "header.minorVersion")
  result.netVersion = readUint32Ctx(s, "header.netVersion")
  result.gameType = readString8Ctx(s, "header.gameType")
  result.props = readPropertiesUntilNone(s)

proc parseHeader*(replayPath: string): ReplayHeader =
  ## Opens a replay file and parses its header into a ReplayHeader.
  var fs: FileStream = newFileStream(replayPath, fmRead)
  if fs.isNil:
    raise newException(IOError, "Cannot open file: " & replayPath)
  defer: fs.close()

  result = parseHeader(fs)

proc parseReplay*(replayPath: string): Replay =
  ## Opens a replay file and parses it into a Replay.
  var fs: FileStream = newFileStream(replayPath, fmRead)
  if fs.isNil:
    raise newException(IOError, "Cannot open file: " & replayPath)
  defer: fs.close()

  result.header = parseHeader(fs)
