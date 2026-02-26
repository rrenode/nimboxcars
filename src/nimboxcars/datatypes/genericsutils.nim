import std/[streams, strformat]
import nimboxcars/datatypes/primitives

proc take*[T](t: typedesc[T], s: Stream; what: string): T {.inline.} =
  {.error: "No read(typedesc[" & $T & "], Stream, string) defined".}

proc takeListOf*[T](t: typedesc[T], s: Stream, what = "listOf"): seq[T] =
  let count = int32.take(s, what & ".count")
  result = newSeq[T](count)
  for i in 0..<count:
    result[i] = t.take(s, what & "." & $i)