import std/[streams, strformat]
import nimboxcars/[strings, primitives]

type
  KeyFrame* = object
    time*: float32
    frame*: int32
    position*: int32
  
  DebugInfo* = object
    frame*: int32
    user*: FString
    text*: FString

  TickMark* = object
    description*: FString
    frame*: int32

  ClassIndex* = object
    class*: FString
    index*: int32

  NetCacheProperty* = object
    objectIndex*: int32
    streamId*: int32

  NetCache* = object
    objectIndex*: int32
    parentId*: int32
    cacheId*: int32
    properties*: seq[NetCacheProperty]

proc take*(t: typedesc[KeyFrame]; s: Stream; what = "keyFrame"): KeyFrame =
  ##
  result.time = float32.take(s, &"{what}.keyFrame.time")
  result.frame = int32.take(s, &"{what}.keyFrame.frame")
  result.position = int32.take(s, &"{what}.keyFrame.position")

proc take*(t: typedesc[DebugInfo]; s: Stream; what = "debugInfo"): DebugInfo =
  ##
  result.frame = int32.take(s, &"{what}.debugInfo.frame")
  result.user = FString.take(s, &"{what}.debugInfo.user")
  result.text = FString.take(s, &"{what}.debugInfo.text")

proc take*(t: typedesc[TickMark]; s: Stream; what = "tickMark"): TickMark =
  ##
  result.description = FString.take(s, &"{what}.tickMark.description")
  result.frame = int32.take(s, &"{what}.tickMark.frame")

proc take*(t: typedesc[ClassIndex]; s: Stream; what = "classIndex"): ClassIndex =
  ##
  result.class = FString.take(s, &"{what}.classIndex.class")
  result.index = int32.take(s, &"{what}.classIndex.index")

proc take*(t: typedesc[NetCacheProperty]; s: Stream; what = "netCacheProp"): NetCacheProperty =
  ##
  result.objectIndex = int32.take(s, &"{what}.netCacheProp.objectIndex")
  result.streamId = int32.take(s, &"{what}.netCacheProp.streamId")

proc take*(t: typedesc[NetCache]; s: Stream; what = "netCache"): NetCache =
  ##
  result.objectIndex = int32.take(s, &"{what}.netCache.objectIndex")
  result.parentId = int32.take(s, &"{what}.netCache.parentId")
  result.cacheId = int32.take(s, &"{what}.netCache.cacheId")
  result.properties = NetCacheProperty.takeListOf(s, &"{what}.netCache.props")