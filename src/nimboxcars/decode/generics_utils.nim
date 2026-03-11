import std/[streams, strformat]
import nimboxcars/decode/primitives

proc take*[T](t: typedesc[T], s: Stream; what: string): T {.inline.} =
  ## TODO: Write proc generic desc
  {.error: "No read(typedesc[" & $T & "], Stream, string) defined".}

proc takeListOf*[T](t: typedesc[T], s: Stream, what = "listOf"): seq[T] =
  ## TODO: Write proc desc
  let count = int32.take(s, what & ".count")
  result = newSeq[T](count)
  for i in 0..<count:
    result[i] = t.take(s, what & "." & $i)