## RL Replay Parser - Robert J Renode IV (Feb. 2026)
## 
## Instrumental in writing this was tanrbobanr's documentation of the RL replay binary structure.
##  https://github.com/tanrbobanr/rocket-league-replay-format/blob/main/rpdoc_generated.md
## Additionally, boxcars (a rust RL replay lib) served to help me avoid reverse-engineering more modern RL replay formats.
## Fun fact: Modern replay formats have StructProperty!
import std/[streams, options]
import nimboxcars/[body, strings, primitives, props]

export Properties

type
  NetworkDataParse = enum
    skipDeserial, skipParsing, getAll

  ReplayHeader* = object
    hSize*: int32
    headerCrc*: uint32
    majorVersion*: uint32
    minorVersion*: uint32
    netVersion*: uint32
    gameType*: string
    props*: Properties
  
  ReplayBody* = object
    contentSize*: int32
    contentCrc*: uint32
    levels*: seq[FString]
    keyFrames*: seq[KeyFrame]
    networkSize*: int32
    networkData*: seq[byte]
    debugInfo*: seq[DebugInfo]
    tickMarks*: seq[TickMark]
    packages*: seq[FString]
    objects*: seq[FString]
    names*: seq[FString]
    classIndices*: seq[ClassIndex]
    netCache*: seq[NetCache]
  
  Replay* = object
    header*: ReplayHeader
    body*: ReplayBody

proc parseHeader*(s: Stream): ReplayHeader =
  ## Parse replay file stream into ReplayHeader.
  let r = int32.takeWithPos(s, "header.hSize")
  result.hSize = r.val
  result.headerCrc = uint32.take(s, "header.crc")
  result.majorVersion = uint32.take(s, "header.majorVersion")
  result.minorVersion = uint32.take(s, "header.minorVersion")
  result.netVersion = uint32.take(s, "header.netVersion")
  result.gameType = String8.take(s, "header.gameType")
  #result.props = readPropertiesUntilNone(s)

proc parseHeader*(replayPath: string): ReplayHeader =
  ## Opens a replay file and parses its header into a ReplayHeader.
  var fs: FileStream = newFileStream(replayPath, fmRead)
  if fs.isNil:
    raise newException(IOError, "Cannot open file: " & replayPath)
  defer: fs.close()

  result = parseHeader(fs)

proc parseReplay*(replayPath: string; netData: NetworkDataParse = NetworkDataParse.skipParsing): Replay =
  ## Opens a replay file and parses it into a Replay.
  var fs: FileStream = newFileStream(replayPath, fmRead)
  if fs.isNil:
    raise newException(IOError, "Cannot open file: " & replayPath)
  defer: fs.close()

  result.header = parseHeader(fs)