import std/[streams, options, strformat]
import primitives

proc readTextList*(s: Stream; what = "textList"): seq[string] =
  let count = readInt32Ctx(s, &"{what}.textList.count")
  result = newSeq[string](count)

  for i in 0..<count:
    result[i] = readString16Ctx(s, &"{what}.textList.{i}")