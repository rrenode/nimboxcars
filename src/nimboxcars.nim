#import nimboxcars/parser
import std/[streams, encodings]

proc readU64(s: Stream): uint64 =
  ## Takes the file stream and reads the next 8 bytes as uint64
  var b: array[8, byte]
  if s.readData(addr b[0], 8) != 8:
    raise newException(IOError, "EOF while reading u64")
  result = uint64(b[0]) or
  (uint32(b[1]) shl 8)  or 
  (uint32(b[2]) shl 16) or 
  (uint32(b[3]) shl 24) or
  (uint32(b[4]) shl 32) or
  (uint32(b[5]) shl 40) or
  (uint32(b[6]) shl 48) or
  (uint32(b[7]) shl 56)

proc readU32(s: Stream): uint32 =
  ## Takes the file stream and reads the next 4 bytes as a uint32
  var b: array[4, byte]
  if s.readData(addr b[0], 4) != 4:
    raise newException(IOError, "EOF while reading u32")
  result = uint32(b[0]) or (uint32(b[1]) shl 8) or (uint32(b[2]) shl 16) or (uint32(b[3]) shl 24)

proc readString16(s: Stream): string =
  ## Takes the file stream and reads bytes as string utf-16
  let n = int(readInt32(s))
  var lenBytes: int =
    if n > 0: n
    else: n * -2

  var raw = newString(lenBytes)
  if s.readData(addr raw[0], lenBytes) != lenBytes:
    raise newException(IOError, "EOF while reading string")

  if raw.len >= 2 and raw[^1] == '\0' and raw[^2] == '\0':
    raw.setLen(raw.len - 2)

  result = convert(raw, "UTF-8", "UTF-16")

proc readString8(s: Stream): string =
  ## Takes the file stream and reads bytes as string utf-8
  let n = int(readU32(s))
  if n <= 0: return ""

  var raw = newSeq[byte](n)
  if s.readData(addr raw[0], n) != n:
    raise newException(IOError, "EOF while reading string")

  var endi = n
  if endi > 0 and raw[endi-1] == 0'u8:
    dec endi

  result = cast[string](raw[0..<endi])

when isMainModule:

  let replayPath = r"C:\Users\rober\Documents\My Games\Rocket League\TAGame\Demos\A2C1C2E14020B6A1F701D8957C8C87A7.replay"
  
  block:
    # Read header size; u32 so 4 bytes
    var f = newFileStream(replayPath, fmRead)
    defer: f.close()

    let hSize = readU32(f)
    let headerCrc = readU32(f)
    let majorVersion = readU32(f)
    let minorVersion = readU32(f)
    let netVersion = readU32(f)
    let gameType = readString8(f)
    