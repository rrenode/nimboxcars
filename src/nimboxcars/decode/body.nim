import std/[streams, strformat]
import nimboxcars/decode/[generics_utils, strings]
import nimboxcars/model/[body, strings]

proc take*(t: typedesc[KeyFrame]; s: Stream; what = "keyFrame"): KeyFrame =
  ## TODO: Write KeyFrame's `take` generic's desc
  result.time = float32.take(s, &"{what}.keyFrame.time")
  result.frame = int32.take(s, &"{what}.keyFrame.frame")
  result.position = int32.take(s, &"{what}.keyFrame.position")

proc take*(t: typedesc[DebugInfo]; s: Stream; what = "debugInfo"): DebugInfo =
  ## TODO: Write DebugInfo's `take` generic's desc
  result.frame = int32.take(s, &"{what}.debugInfo.frame")
  result.user = FString.take(s, &"{what}.debugInfo.user")
  result.text = FString.take(s, &"{what}.debugInfo.text")

proc take*(t: typedesc[TickMark]; s: Stream; what = "tickMark"): TickMark =
  ## TODO: Write TickMark's `take` generic's desc
  result.description = FString.take(s, &"{what}.tickMark.description")
  result.frame = int32.take(s, &"{what}.tickMark.frame")

proc take*(t: typedesc[ClassIndex]; s: Stream; what = "classIndex"): ClassIndex =
  ## TODO: Write ClassIndex's `take` generic's desc
  result.class = FString.take(s, &"{what}.classIndex.class")
  result.index = int32.take(s, &"{what}.classIndex.index")

proc take*(t: typedesc[NetCacheProperty]; s: Stream; what = "netCacheProp"): NetCacheProperty =
  ## TODO: Write NetCacheProperty's `take` generic's desc
  result.objectIndex = int32.take(s, &"{what}.netCacheProp.objectIndex")
  result.streamId = int32.take(s, &"{what}.netCacheProp.streamId")

proc take*(t: typedesc[NetCache]; s: Stream; what = "netCache"): NetCache =
  ## TODO: Write NetCache's `take` generic's desc
  result.objectIndex = int32.take(s, &"{what}.netCache.objectIndex")
  result.parentId = int32.take(s, &"{what}.netCache.parentId")
  result.cacheId = int32.take(s, &"{what}.netCache.cacheId")
  result.properties = NetCacheProperty.takeListOf(s, &"{what}.netCache.props")