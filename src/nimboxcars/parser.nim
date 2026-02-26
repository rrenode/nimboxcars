## RL Replay Parser - Robert J Renode IV (Feb. 2026)
## 
## Instrumental in writing this was tanrbobanr's documentation of the RL replay binary structure.
##  https://github.com/tanrbobanr/rocket-league-replay-format/blob/main/rpdoc_generated.md
## Additionally, boxcars (a rust RL replay lib) served to help me avoid reverse-engineering more modern RL replay formats.
## Fun fact: Modern replay formats have StructProperty!
import std/[streams]
import nimboxcars/[datatypes, body, props]

type
  NetworkDataParseMode* = enum
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
  result.hSize = int32.take(s, "header.hSize")
  result.headerCrc = uint32.take(s, "header.crc")
  result.majorVersion = uint32.take(s, "header.majorVersion")
  result.minorVersion = uint32.take(s, "header.minorVersion")

  if result.majorVersion > 865'u32 and result.minorVersion > 17'u32:
    result.netVersion = uint32.take(s, "header.netVersion")
  else:
    result.netVersion = 0'u32
  result.gameType = String8.take(s, "header.gameType")
  result.props = readPropertiesUntilNone(s)

proc parseHeader*(replayPath: string): ReplayHeader =
  ## Opens a replay file and parses only its header into a ReplayHeader.
  var fs: FileStream = newFileStream(replayPath, fmRead)
  if fs.isNil:
    raise newException(IOError, "Cannot open file: " & replayPath)
  defer: fs.close()

  result = parseHeader(fs)

proc parseBody*(s: Stream, netDataMode: NetworkDataParseMode = NetworkDataParseMode.skipParsing): ReplayBody =
  ## Parse continued replay file stream into ReplayBody
  result.contentSize = int32.take(s, "body.contentSize")
  result.contentCrc = uint32.take(s, "body.crc")
  result.levels = FString.takeListOf(s, "body.levels")
  result.keyFrames = KeyFrame.takeListOf(s, "body.keyframes")
  result.networkSize = int32.take(s, "body.netdataSize")

  proc skipNetdata(networkSize: int32) =
    ## Just for easier reading since I reuse this logic for now
    let posPastNet = s.getPosition() + int(networkSize)
    s.setPosition(posPastNet)

  case netDataMode:
  of NetworkDataParseMode.skipDeserial:
    # Reads and saves network data as bytes
    result.networkData = takeBytes(s, result.networkSize)
  of NetworkDataParseMode.skipParsing:
    # Skips network data entirely
    skipNetdata(result.networkSize)
  of NetworkDataParseMode.getAll:
    # Parses and Deserializes all of netdata
    echo "NetworkDataPaseMode `getAll` is not yet implemented... skipping network data."
    skipNetdata(result.networkSize)

  result.debugInfo = DebugInfo.takeListOf(s, "body.debugInfo")
  result.tickMarks = TickMark.takeListOf(s, "body.tickMarks")
  result.packages = FString.takeListOf(s, "body.packages")
  result.objects = FString.takeListOf(s, "body.objects")
  result.names = FString.takeListOf(s, "body.names")
  result.classIndices = ClassIndex.takeListOf(s, "body.classIndices")
  result.netCache = NetCache.takeListof(s, "body.netCache")

proc parseReplay*(replayPath: string; netDataMode: NetworkDataParseMode = NetworkDataParseMode.skipParsing): Replay =
  ## Opens a replay file and parses it into a Replay.
  var fs: FileStream = newFileStream(replayPath, fmRead)
  if fs.isNil:
    raise newException(IOError, "Cannot open file: " & replayPath)
  defer: fs.close()

  result.header = parseHeader(fs)
  result.body = parseBody(fs)