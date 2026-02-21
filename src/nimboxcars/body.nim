import std/[streams, options, strformat]
import primitives

type
  KeyFrame* = object
    time*: float32
    frame*: int32
    position*: int32

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