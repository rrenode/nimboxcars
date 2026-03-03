import nimboxcars/model/[body, props, strings]

export body, props, strings

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