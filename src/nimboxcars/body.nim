import std/[streams, options, strformat]
import primitives

type
  KeyFrame* = object
    time*: float32
    frame*: int32
    position*: int32
  
  DebugInfo* = object
    frame*: int32
    user*: String16
    text*: String16

  TickMark* = object
    description*: String16
    frame*: int32

  ClassIndex* = object
    class*: String16
    index*: int32

  NetCacheProperty* = object
    objectIndex*: int32
    streamId*: int32

  NetCache* = object
    objectIndex*: int32
    parentId*: int32
    cacheId*: int32
    properties*: seq[NetCacheProperty]

proc read*(t: typedesc[KeyFrame]; s: Stream; what = "keyFrame"): KeyFrame =
  ##
  result.time = readFloat32Ctx(s, &"{what}.keyFrame.time")
  result.frame = int32.take(s, &"{what}.keyFrame.frame")
  result.position = int32.take(s, &"{what}.keyFrame.position")

proc read*(t: typedesc[DebugInfo]; s: Stream; what = "debugInfo"): DebugInfo =
  ##
  result.frame = int32.take(s, &"{what}.debugInfo.frame")
  result.user = readString16Ctx(s, &"{what}.debugInfo.user")
  result.text = readString16Ctx(s, &"{what}.debugInfo.text")

proc read*(t: typedesc[TickMark]; s: Stream; what = "tickMark"): TickMark =
  ##
  result.description = readString16Ctx(s, &"{what}.tickMark.description")
  result.frame = int32.take(s, &"{what}.tickMark.frame")

proc read*(t: typedesc[ClassIndex]; s: Stream; what = "classIndex"): ClassIndex =
  ##
  result.class = readString16Ctx(s, &"{what}.classIndex.class")
  result.index = int32.take(s, &"{what}.classIndex.index")

proc read*(t: typedesc[NetCacheProperty]; s: Stream; what = "netCacheProp"): NetCacheProperty =
  ##
  result.objectIndex = int32.take(s, &"{what}.netCacheProp.objectIndex")
  result.streamId = int32.take(s, &"{what}.netCacheProp.streamId")

proc read*(t: typedesc[NetCache]; s: Stream; what = "netCache"): NetCache =
  ##
  result.objectIndex = int32.take(s, &"{what}.netCache.objectIndex")
  result.parentId = int32.take(s, &"{what}.netCache.parentId")
  result.cacheId = int32.take(s, &"{what}.netCache.cacheId")
  result.properties = NetCacheProperty.readListOf(s, &"{what}.netCache.props")