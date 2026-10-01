## Little-endian, least-significant-bit-first network reader.
## Protocol details ported from boxcars 0.10.11 (see THIRD_PARtY_NOTICES.md)
import std/[unicode]

type
  NetworkDecodeError* = object of IOError
  NetworkVersion* = tuple[major, minor, net: int]
  BitReader* = object
    data: seq[byte]
    position*: int

proc initBitReader*(data: seq[byte]): BitReader = BitReader(data: data)
proc remaining*(b: BitReader): int = b.data.len * 8 - b.position
proc fail*(b: BitReader, message: string) {.noreturn.} =
  raise newException(NetworkDecodeError, message & " at network bit " & $b.position)

proc readBits*(b: var BitReader, count: int): uint64 =
  if count < 0 or count > 64: b.fail("Invalid bit count " & $count)
  if count > b.remaining: b.fail("Truncated data: need " & $count & " bits, have " & $b.remaining)
  var shift = 0
  while shift < count:
    let offset = b.position and 7
    let take = min(8 - offset, count - shift)
    let part = (uint64(b.data[b.position shr 3]) shr offset) and ((1'u64 shl take) - 1)
    result = result or (part shl shift)
    b.position += take
    shift += take

proc readBool*(b: var BitReader): bool = b.readBits(1) != 0
proc readU8*(b: var BitReader): uint8 = uint8(b.readBits(8))
proc readI8*(b: var BitReader): int8 = cast[int8](b.readU8())
proc readU32*(b: var BitReader): uint32 = uint32(b.readBits(32))
proc readI32*(b: var BitReader): int32 = cast[int32](b.readU32())
proc readU64*(b: var BitReader): uint64 = b.readBits(64)
proc readI64*(b: var BitReader): int64 = cast[int64](b.readU64())
proc readF32*(b: var BitReader): float32 = cast[float32](b.readU32())

proc readBounded*(b: var BitReader, maximum: uint32): uint32 =
  ## Unreal SerializeInt: maximum is exclusive; the final bit is conditional.
  if maximum == 0: b.fail("Zero bounded-integer maximum")
  var width = 0
  var value = maximum
  while value > 1:
    inc width
    value = value shr 1
  result = uint32(b.readBits(width))
  let upper = uint64(result) + (1'u64 shl width)
  if upper < uint64(maximum) and b.readBool(): result = uint32(upper)

proc readBytes*(b: var BitReader, count: int): seq[byte] =
  if count < 0 or count > b.remaining div 8: b.fail("Truncated byte sequence of length " & $count)
  result = newSeq[byte](count)
  for i in 0..<count: result[i] = b.readU8()

proc decode1252*(bytes: openArray[byte]): string =
  const extended = [0x20AC, 0x81, 0x201A, 0x192, 0x201E, 0x2026, 0x2020, 0x2021,
    0x2C6, 0x2030, 0x160, 0x2039, 0x152, 0x8D, 0x17D, 0x8F,
    0x90, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
    0x2DC, 0x2122, 0x161, 0x203A, 0x153, 0x9D, 0x17E, 0x178]
  for c in bytes:
    let code = if c in 0x80'u8..0x9F'u8: extended[int(c) - 0x80] else: int(c)
    result.add Rune(code).toUTF8

proc readText*(b: var BitReader): string =
  let size = int64(b.readI32())
  if size == 0: return ""
  let bytes = if size < 0: -size * 2 else: size
  # Match the reference's bounded text buffer; validate before allocation.
  if bytes > 1024 or bytes > int64(b.remaining div 8): b.fail("Invalid network string length " & $size)
  let data = b.readBytes(int(bytes))
  if size > 0:
    return decode1252(data.toOpenArray(0, data.high - 1))
  var i = 0
  while i < data.len - 2: # FString length includes its terminator.
    let first = int(data[i]) or (int(data[i+1]) shl 8)
    i += 2
    var code = first
    if first in 0xD800..0xDBFF:
      if i >= data.len - 2: b.fail("Unpaired UTF-16 high surrogate")
      let second = int(data[i]) or (int(data[i+1]) shl 8)
      i += 2
      if second notin 0xDC00..0xDFFF: b.fail("Invalid UTF-16 surrogate pair")
      code = 0x10000 + ((first - 0xD800) shl 10) + second - 0xDC00
    elif first in 0xDC00..0xDFFF: b.fail("Unpaired UTF-16 low surrogate")
    result.add Rune(code).toUTF8
