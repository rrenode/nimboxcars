## Binary decoding from stream for fixed-width types as wrappers of Nim std/streams built-ins.
## 
## 
## ==== WHY ====
## Nim's built-ins are not equivalent as they use the native endianness of the machine.
## And to my knowledge, all Rocket League replays should be little endian. 
## Thus, the existence of these procs and their utility over Nim's built-ins.

import std/[streams, encodings, strformat]

proc readInt8Ctx*(s: Stream, what = "int8"): int8 =
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

proc readInt32Ctx*(s: Stream, what = "int32"): int32 =
  ## Takes the file stream and reads `int32`.
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

proc readInt64Ctx*(s: Stream, what = "int64"): int64 =
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

proc readUint8Ctx*(s: Stream, what = "uint8"): uint8 =
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

proc readUint32Ctx*(s: Stream, what = "uint32"): uint32 =
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

proc readUint64Ctx*(s: Stream, what = "uint64"): uint64 =
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

proc readBool8Ctx*(s: Stream, what = "bool8"): bool =
  let b = readUint8Ctx(s, what)
  b != 0'u8

proc readFloat32Ctx*(s: Stream, what = "float32"): float32 = 
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

proc readString16Ctx*(s: Stream, what = "string16"): string =
  ## Takes the file stream and reads bytes as a string; encoding as either utf-16 or Windows-1252
  ## Raises ValueError for when text is too large.
  ## Raises IOError on other exceptions occurances.
  ## 
  ## <0 => UTF-16LE, bytes = -characters * 2, includes 2-byte NUL
  ## >=0 => Windows-1252, bytes = characters, includes 1-byte NUL
  ## 
  # I might of messed this up? But there's no error. Soemthing just feels wrong.
  let pos = s.getPosition()
  let characters = readInt32Ctx(s, what)

  if characters < -10_000'i32 or characters > 10_000'i32:
    raise newException(ValueError, &"TextTooLarge({characters}) at index {pos} while reading {what}")
  
  if characters < 0'i32:
    let size = int(-characters) * 2
    if size == 0: return ""

    var raw = newString(size)
    if s.readData(addr raw[0], size) != size:
      raise newException(IOError, &"EOF while reading text(utf16) at index {pos} while reading {what}")

    # drop UTF-16 terminator if present
    if raw.len >= 2 and raw[^1] == '\0' and raw[^2] == '\0':
      raw.setLen(raw.len - 2)

    return encodings.convert(raw, "UTF-8", "UTF-16")

  else:
    let size = int(characters)
    if size == 0: return ""

    var raw = newString(size)
    if s.readData(addr raw[0], size) != size:
      raise newException(IOError, &"EOF while reading text(cp1252) at index {pos} while reading {what}")

    if raw.len > 0 and raw[^1] == '\0':
      raw.setLen(raw.len - 1)

    # Convert Windows-1252 bytes to UTF-8 string
    return encodings.convert(raw, "UTF-8", "CP1252")

proc readString8Ctx*(s: Stream, what = "string8"): string =
  ## Readers UE3 string8 from stream.
  ## Raises `IOError` if error occurred.
  let pos = s.getPosition()
  let n = int(readUint32Ctx(s, what))

  let m = n - 1
  if n <= 0: return ""

  result = newString(m)
  if m > 0:
    if s.readData(addr result[0], m) != m:
      raise newException(IOError, &"EOF while reading string at index {pos} while reading {what}")

  var nul: byte

  if s.readData(addr nul, 1) != 1:
    raise newException(IOError, &"EOF while reading string terminator at index {pos} while reading {what}")