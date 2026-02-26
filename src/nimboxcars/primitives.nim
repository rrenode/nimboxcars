## Binary decoding from stream for fixed-width types as wrappers of Nim std/streams built-ins.
import std/[streams, encodings, strformat]

type
  # Meta Type first
  RlNode* = object
    startPos*: int
    endPos*: int

  # Wrapper types
  Bool8* = bool

proc takeWithPos*[T](t: typedesc[T], s: Stream, what: string): tuple[val:T, node:RlNode] =
  let startPos: int = s.getPosition()
  let value = t.take(s, what)
  let endPos: int = s.getPosition()
  result = (val: value, node: RlNode(startPos: startPos, endPos: endPos))

proc take*[T](t: typedesc[T], s: Stream; what: string): T {.inline.} =
  {.error: "No read(typedesc[" & $T & "], Stream, string) defined".}

proc take*(t: typedesc[int8], s: Stream, what = "int8"): int8 =
  ## Takes the file stream and reads `int8`.
  ## Raises `IOError` is error occurred.
  ## Uses `what` for error message.
  var pos: int = s.getPosition()
  try:
    var x = readInt8(s)
    when cpuEndian == bigEndian:
      x = swapEndian8(x)
    result = x
  except IOError as e:
    raise newException(IOError,  &"EOF while reading {what} at offset {pos}: {e.msg}")

proc take*(t: typedesc[int32], s: Stream, what = "int32"): int32 =
  ## Takes the file stream and reads `int8`.
  ## Raises `IOError` is error occurred.
  ## Uses `what` for error message.
  var pos: int = s.getPosition()
  try:
    var x = readInt32(s)
    when cpuEndian == bigEndian:
      x = swapEndian32(x)
    result = x
  except IOError as e:
    raise newException(IOError,  &"EOF while reading {what} at offset {pos}: {e.msg}")

proc take*(t: typedesc[int64], s: Stream, what = "int64"): int64 =
  ## Takes the file stream and reads `int64`.
  ## Raises `IOError` is error occurred.
  ## Uses `what` for error message.
  var pos: int = s.getPosition()
  try:
    var x = readInt64(s)
    when cpuEndian == bigEndian:
      x = swapEndian64(x)
    result = x
  except IOError as e:
    raise newException(IOError, &"EOF while reading {what} at offset {pos}: {e.msg}")

proc take*(t: typedesc[uint8], s: Stream, what = "uint8"): uint8 =
  ## Takes the file stream and reads `uint8`.
  ## Raises `IOError` is error occurred.
  ## Uses `what` for error message.
  var pos: int = s.getPosition()
  try:
    var x = readUint8(s)
    when cpuEndian == bigEndian:
      x = swapEndian8(x)
    result = x
  except IOError as e:
    raise newException(IOError,  &"EOF while reading {what} at offset {pos}: {e.msg}")

proc take*(t: typedesc[uint32], s: Stream, what = "uint32"): uint32 =
  ## Takes the file stream and reads `uint32`.
  ## Raises `IOError` is error occurred.
  ## Uses `what` for error message.
  var pos: int = s.getPosition()
  try:
    var x = readUint32(s)
    when cpuEndian == bigEndian:
      x = swapEndian32(x)
    result = x
  except IOError as e:
    raise newException(IOError,  &"EOF while reading {what} at offset {pos}: {e.msg}")

proc take*(t: typedesc[uint64], s: Stream, what = "uint64"): uint64 =
  ## Takes the file stream and reads `int64`.
  ## Raises `IOError` is error occurred.
  ## Uses `what` for error message.
  var pos: int = s.getPosition()
  try:
    var x: uint64 = readUint64(s)
    when cpuEndian == bigEndian:
      x = swapEndian64(x)
    result = x
  except IOError as e:
    raise newException(IOError, &"EOF while reading {what} at offset {pos}: {e.msg}")

proc take*(t: typedesc[Bool8], s: Stream, what = "bool8"): Bool8 =
  let b = uint8.take(s, what)
  b != 0'u8

proc take*(t: typedesc[float32], s: Stream, what = "float32"): float32 = 
  ## Takes the file stream and reads `float32`.
  ## Raises `IOError` is error occurred.
  ## Uses `what` for error message.
  var pos: int = s.getPosition()
  try:
    var x: float = readFloat32(s)
    when cpuEndian == bigEndian:
      x = swapEndian64(x)
    result = x
  except IOError as e:
    raise newException(IOError, &"EOF while reading {what} at offset {pos}: {e.msg}")