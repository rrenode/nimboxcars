## RL Replay Parser - Robert J Renode IV (Feb. 2026)
## 
## Instrumental in writing this was tanrbobanr's documentation of the RL replay binary structure.
##  https://github.com/tanrbobanr/rocket-league-replay-format/blob/main/rpdoc_generated.md
## Additionally, boxcars (a rust RL replay lib) served to help me avoid reverse-engineering more modern RL replay formats.
## Fun fact: Modern replay formats have StructProperty! <-- boy was that headache I missed for too long!
import std/[streams]
import nimboxcars/[decode, model, crc]
import nimboxcars/decode/network/netparse

export model
export netparse.decodeNetwork, netparse.NetworkDecodeError

type
  NetworkDataParseMode* = enum
    skipDeserial, skipParsing, getAll

proc validateCrc(data: openArray[byte], expected: uint32): bool =
  result = calcCrc(data) == expected

proc crcSection(s: Stream, size: int, expected: uint32, section: string) =
  let sectionStart = s.getPosition()
  var sectionBytes = newSeq[byte](size)
  discard s.readData(addr sectionBytes[0], size)
  if not validateCrc(sectionBytes, expected):
    raise newException(IOError, "Possible corrupt replay: " & section & "CRC mismatch")
  s.setPosition(sectionStart)

proc parseHeader*(s: Stream, checkCrc: bool = false): ReplayHeader =
  ## Parse replay file stream into ReplayHeader.
  result.hSize = int32.take(s, "header.hSize")
  result.headerCrc = uint32.take(s, "header.crc")

  if checkCrc:
    crcSection(s, result.hSize, result.headerCrc, "Header")

  result.majorVersion = uint32.take(s, "header.majorVersion")
  result.minorVersion = uint32.take(s, "header.minorVersion")

  if (result.majorVersion, result.minorVersion) >= (868'u32, 18'u32):
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

proc parseBody*(s: Stream, netDataMode: NetworkDataParseMode = NetworkDataParseMode.skipParsing,
                checkCrc: bool = false, header: Option[ReplayHeader] = none(ReplayHeader)): ReplayBody =
  ## Parse continued replay file stream into ReplayBody
  if netDataMode == NetworkDataParseMode.getAll and header.isNone:
    raise newException(ValueError, "parseBody(getAll) requires header = some(parsedHeader)")
  result.contentSize = int32.take(s, "body.contentSize")
  result.contentCrc = uint32.take(s, "body.crc")

  if checkCrc:
    crcSection(s, result.contentSize, result.contentCrc, "body")

  result.levels = FString.takeListOf(s, "body.levels")
  result.keyFrames = KeyFrame.takeListOf(s, "body.keyframes")
  result.networkSize = int32.take(s, "body.netdataSize")
  if result.networkSize < 0: raise newException(IOError, "Negative network data size")

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
    # Tables following the payload are required before decoding its bits.
    result.networkData = takeBytes(s, result.networkSize)

  result.debugInfo = DebugInfo.takeListOf(s, "body.debugInfo")
  result.tickMarks = TickMark.takeListOf(s, "body.tickMarks")
  result.packages = FString.takeListOf(s, "body.packages")
  result.objects = FString.takeListOf(s, "body.objects")
  result.names = FString.takeListOf(s, "body.names")
  result.classIndices = ClassIndex.takeListOf(s, "body.classIndices")
  result.netCache = NetCache.takeListof(s, "body.netCache")
  if netDataMode == NetworkDataParseMode.getAll:
    result.networkFrames = some(decodeNetwork(header.get, result))

proc parseReplay*(replayPath: string; netDataMode: NetworkDataParseMode = NetworkDataParseMode.skipParsing, checkCrc: bool = false): Replay =
  ## Opens a replay file and parses it into a Replay.
  var fs: FileStream = newFileStream(replayPath, fmRead)
  if fs.isNil:
    raise newException(IOError, "Cannot open file: " & replayPath)
  defer: fs.close()

  result.header = parseHeader(fs, checkCrc)
  result.body = parseBody(fs, netDataMode, checkCrc, some(result.header))
