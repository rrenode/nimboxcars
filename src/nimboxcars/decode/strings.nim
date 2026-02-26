import std/[streams, encodings, strformat]
import nimboxcars/model/strings
import nimboxcars/decode/[primitives, genericsutils]
export primitives, genericsutils

proc take*(t: typedesc[String8], s: Stream, what = "String8"): String8 =
  ## Readers UE3 string8 from stream.
  ## Raises `IOError` if error occurred.
  let pos = s.getPosition()
  let n = int(int32.take(s, what))

  let m = n - 1
  if n <= 0: return ""

  result = newString(m)
  if m > 0:
    if s.readData(addr result[0], m) != m:
      raise newException(IOError, &"EOF while reading string at index {pos} while reading {what}")

  var nul: byte

  if s.readData(addr nul, 1) != 1:
    raise newException(IOError, &"EOF while reading string terminator at index {pos} while reading {what}")

proc take*(t: typedesc[FString], s: Stream, what = "FString"): FString =
  ## Takes the file stream and reads bytes as a string; encoding as either utf-16 or Windows-1252
  ## Raises ValueError for when text is too large.
  ## Raises IOError on other exceptions occurances.
  ## 
  ## <0 => UTF-16LE, bytes = -characters * 2, includes 2-byte NUL
  ## >=0 => Windows-1252, bytes = characters, includes 1-byte NUL
  ## 
  # I might of messed this up? But there's no error. Soemthing just feels wrong.
  let pos = s.getPosition()
  let characters = int32.take(s, what=what)

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