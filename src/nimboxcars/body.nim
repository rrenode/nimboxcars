import std/[streams, options, strformat]
import primitives

type
  KeyFrame* = object
    time*: float32
    frame*: int32
    position*: int32
  
  DebugInfo* = object
    frame*: int32
    user*: string
    text*: string

proc readTextList*(s: Stream; what = "textList"): seq[string] =
  ##
  let count = readInt32Ctx(s, &"{what}.textList.count")
  result = newSeq[string](count)

  for i in 0..<count:
    result[i] = readString16Ctx(s, &"{what}.textList.{i}")

proc readKeyFrame*(s: Stream; what = "keyFrame"): KeyFrame =
  ##
  result.time = readFloat32Ctx(s, &"{what}.keyFrame.time")
  result.frame = readInt32Ctx(s, &"{what}.keyFrame.frame")
  result.position = readInt32Ctx(s, &"{what}.keyFrame.position")

proc readKeyFrameList*(s: Stream; what = "keyFrameList"): seq[KeyFrame] =
  let count = readInt32Ctx(s, &"{what}.keyFrameList.count")
  result = newSeq[KeyFrame](count)

  for i in 0..<count:
    result[i] = readKeyFrame(s, &"{what}.keyFrameList.{i}")

proc readDebugInfo*(s: Stream; what = "debugInfo"): DebugInfo =
  ##
  result.frame = readInt32Ctx(s, &"{what}.debugInfo.frame")
  result.user = readString16Ctx(s, &"{what}.debugInfo.user")
  result.text = readString16Ctx(s, &"{what}.debugInfo.text")

proc readDebugInfoList*(s: Stream; what = "debugInfoList"): seq[DebugInfo] =
  ##
  let count = readInt32Ctx(s, &"{what}.debugInfoList.count")
  result = newSeq[DebugInfo](count)

  for i in 0..<count:
    result[i] = readDebugInfo(s, &"{what}.debugInfoList.{i}")