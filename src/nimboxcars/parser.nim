## RL Replay Parser - Robert J Renode IV (Feb. 2026)
## 
## Instrumental in writing this was tanrbobanr's documentation of the RL replay binary structure.
##  https://github.com/tanrbobanr/rocket-league-replay-format/blob/main/rpdoc_generated.md
## Additionally, boxcars (a rust RL replay lib) served to help me avoid reverse-engineering more modern RL replay formats.
## Fun fact: Modern replay formats have StructProperty!
import std/[streams, options]
import primitives, body, props 

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
    levels*: seq[String16]
    keyFrames*: seq[KeyFrame]
    networkSize*: int32
    networkData*: seq[byte]
    debugInfo*: seq[DebugInfo]
    tickMarks*: seq[TickMark]
    packages*: seq[String16]
    objects*: seq[String16]
    names*: seq[String16]
    classIndices*: seq[ClassIndex]
    netCache*: seq[NetCache]
  
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

proc parseBody*(s: Stream, netData: NetworkDataParse = NetworkDataParse.skipParsing): ReplayBody =
  ## Parse replay file stream into ReplayBody.
  ## DOES NOT ACCOUNT FOR HEADER
  result.contentSize = readInt32Ctx(s, "body.contentSize")
  result.contentCrc = readUint32Ctx(s, "body.contentCrc")
  result.levels = String16.readListOf(s, "body.levels")
  result.keyFrames = KeyFrame.readListOf(s, "body.keyframes")
  result.networkSize = readInt32Ctx(s, "body.networkSize")
  case netData:
  of NetworkDataParse.skipDeserial:
    var networkData = newSeq[byte](result.networkSize)
    discard s.readData(addr networkData[0], result.networkSize)
    result.networkData = networkData
  of NetworkDataParse.skipParsing:
    s.setPosition(s.getPosition() + int(result.networkSize))
  of NetworkDataParse.getAll:
    echo "Network parsing is not yet completed. Skipping!"
    s.setPosition(s.getPosition() + int(result.networkSize))
  result.debugInfo = DebugInfo.readListOf(s, "body.debugInfo")
  result.tickMarks = TickMark.readListOf(s, "body.tickMarks")
  result.packages = String16.readListOf(s, "body.packages")
  result.objects = String16.readListOf(s, "body.objects")
  result.names = String16.readListof(s, "body.names")
  result.classIndices = ClassIndex.readListof(s, "body.classIndices")
  result.netCache = NetCache.readListOf(s, "body.netCache")

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
  result.body = parseBody(fs)