#import nimboxcars/parser
import std/[streams, encodings, options, strformat]

type
  Property* = object
    name*:  string
    kind*:  string
    val*:   string

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
  ## Takes the file stream and reads bytes as string utf-16
  let pos = s.getPosition()
  let n = int(readInt32(s))
  var lenBytes: int =
    if n > 0: n
    else: n * -2

  var raw = newString(lenBytes)
  if s.readData(addr raw[0], lenBytes) != lenBytes:
    raise newException(IOError, &"EOF while reading string at index {pos}")

  if raw.len >= 2 and raw[^1] == '\0' and raw[^2] == '\0':
    raw.setLen(raw.len - 2)

  result = convert(raw, "UTF-8", "UTF-16")

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

proc readPropertyName*(s: Stream): Option[string] = 
  let n = readString8(s)
  if n == "None" or n == "\0\0\0None":
    return none(string)
  some(n)

when isMainModule:

  let replayPath = r"C:\Users\rober\Documents\My Games\Rocket League\TAGame\Demos\A2C1C2E14020B6A1F701D8957C8C87A7.replay"
  #let replayPath = r"C:\Users\rober\Documents\My Games\Rocket League\TAGame\Demos\C83035FA11F10787A86F62987AC938C8.replay"
  
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
    # Start props
    echo "Starting props..."
    while true:
      let propName = readPropertyName(f)
      if propName == none(string):
        break
      
      let propType = readString8(f)

      # Unknown Prop Attribute
      discard readU64(f)
      echo propName
      echo propType

      case propType:
      of "IntProperty":
        echo readInt32(f)
      of "StrProperty":
        echo readString16(f)
      of "NameProperty":
        echo readString16(f)
      of "FloatProperty":
        echo readFloat32(f)
      of "ArrayProperty":
        echo "Array property ignored."
      of "ByteProperty":
        echo "Bytes property ignored."
      of "QWordProperty":
        echo readU64(f)
      of "BoolProperty":
        echo readBool(f)
      echo "================="