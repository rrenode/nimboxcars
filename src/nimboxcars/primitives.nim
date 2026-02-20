import std/[streams, encodings, strformat]

proc readBool8*(s: Stream): bool =
  let b = readUint8(s)
  b != 0'u8

proc readU64*(s: Stream): uint64 =
  ## Takes the file stream and reads the next 8 bytes as uint64
  let pos = s.getPosition()
  var b: array[8, byte]
  if s.readData(addr b[0], 8) != 8:
    raise newException(IOError, &"EOF while reading u64 at index {pos}")
  result = uint64(b[0]) or
  (uint64(b[1]) shl 8)  or 
  (uint64(b[2]) shl 16) or 
  (uint64(b[3]) shl 24) or
  (uint64(b[4]) shl 32) or
  (uint64(b[5]) shl 40) or
  (uint64(b[6]) shl 48) or
  (uint64(b[7]) shl 56)

proc readU32*(s: Stream): uint32 =
  ## Takes the file stream and reads the next 4 bytes as a uint32
  let pos = s.getPosition()
  var b: array[4, byte]
  if s.readData(addr b[0], 4) != 4:
    raise newException(IOError, &"EOF while reading u32 at index {pos}")
  result = uint32(b[0]) or (uint32(b[1]) shl 8) or (uint32(b[2]) shl 16) or (uint32(b[3]) shl 24)

proc readString16*(s: Stream): string =
  ## Takes the file stream and reads bytes as a string; encoding as either utf-16 or Windows-1252
  ## <0 => UTF-16LE, bytes = -characters * 2, includes 2-byte NUL
  ## >=0 => Windows-1252, bytes = characters, includes 1-byte NUL
  let pos = s.getPosition()
  let characters = readInt32(s)

  if characters < -10_000'i32 or characters > 10_000'i32:
    raise newException(ValueError, &"TextTooLarge({characters}) at index {pos}")
  
  if characters < 0'i32:
    let size = int(-characters) * 2
    if size == 0: return ""

    var raw = newString(size)
    if s.readData(addr raw[0], size) != size:
      raise newException(IOError, &"EOF while reading text(utf16) at index {pos}")

    # drop UTF-16 terminator if present
    if raw.len >= 2 and raw[^1] == '\0' and raw[^2] == '\0':
      raw.setLen(raw.len - 2)

    return encodings.convert(raw, "UTF-8", "UTF-16")

  else:
    let size = int(characters)
    if size == 0: return ""

    var raw = newString(size)
    if s.readData(addr raw[0], size) != size:
      raise newException(IOError, &"EOF while reading text(cp1252) at index {pos}")

    if raw.len > 0 and raw[^1] == '\0':
      raw.setLen(raw.len - 1)

    # Convert Windows-1252 bytes to UTF-8 string
    return encodings.convert(raw, "UTF-8", "CP1252")

proc readString8*(s: Stream): string =
  ## Takes the file stream and reads bytes as string utf-8
  let pos = s.getPosition()
  let n = int(readU32(s))
  if n <= 0: return ""

  var raw = newSeq[byte](n)
  if s.readData(addr raw[0], n) != n:
    raise newException(IOError, &"EOF while reading string at index {pos}")

  let m = max(0, n - 1)

  result = newString(m)
  if m > 0:
    copyMem(addr result[0], unsafeAddr raw[0], m)

  return result