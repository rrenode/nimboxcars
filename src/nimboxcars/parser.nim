## RL Replay Parser - Robert J Renode IV (Feb. 2026)
## 
## Instrumental in writing this was tanrbobanr's documentation of the RL replay binary structure.
##  https://github.com/tanrbobanr/rocket-league-replay-format/blob/main/rpdoc_generated.md
## Additionally, boxcars (a rust RL replay lib) served to help me avoid reverse-engineering more modern RL replay formats.
## Fun fact: Modern replay formats have StructProperty!
import std/[streams]
import body, props, primitives

export Properties

type
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
    levels*: seq[string]
    keyFrames*: seq[KeyFrame]
    networkSize*: int32
  
  Replay* = object
    header*: ReplayHeader
    body*: ReplayBody

proc parseHeader*(s: Stream): ReplayHeader =
  ## Parse replay file stream into ReplayHeader.
  result.hSize = readInt32Ctx(s, "header.hSize")
  result.headerCrc = readUint32Ctx(s, "header.crc")
  result.majorVersion = readUint32Ctx(s, "header.majorVersion")
  result.minorVersion = readUint32Ctx(s, "header.minorVersion")
  result.netVersion = readUint32Ctx(s, "header.netVersion")
  result.gameType = readString8Ctx(s, "header.gameType")
  result.props = readPropertiesUntilNone(s)

proc parseBody*(s: Stream, skip_net: bool = true): ReplayBody =
  ## Parse replay file stream into ReplayBody.
  ## DOES NOT ACCOUNT FOR HEADER
  result.contentSize = readInt32Ctx(s, "body.contentSize")
  result.contentCrc = readUint32Ctx(s, "body.contentCrc")
  result.levels = readTextList(s, "body.levels")
  result.keyFrames = readKeyFrameList(s, "body.keyFrames")
  if skip_net:
    s.setPosition(s.getPosition() + int(result.contentSize))
    echo s.getPosition()

proc parseHeader*(replayPath: string): ReplayHeader =
  ## Opens a replay file and parses its header into a ReplayHeader.
  var fs: FileStream = newFileStream(replayPath, fmRead)
  if fs.isNil:
    raise newException(IOError, "Cannot open file: " & replayPath)
  defer: fs.close()

  result = parseHeader(fs)

proc parseReplay*(replayPath: string; skip_net: bool = true): Replay =
  ## Opens a replay file and parses it into a Replay.
  var fs: FileStream = newFileStream(replayPath, fmRead)
  if fs.isNil:
    raise newException(IOError, "Cannot open file: " & replayPath)
  defer: fs.close()

  result.header = parseHeader(fs)
  result.body = parseBody(fs)