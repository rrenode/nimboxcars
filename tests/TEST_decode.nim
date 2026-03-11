import std/[unittest, streams]

import nimboxcars/decode/primitives

suite "binary take":
  test "uint8":
    let s = newStringStream("\x7f")
    check uint8.take(s) == 0x7Fu8

  test "bool8 false":
    let s = newStringStream("\x00")
    check Bool8.take(s) == false

  test "bool8 true":
    let s = newStringStream("\x05")
    check Bool8.take(s) == true

  test "uint32 little endian":
    let s = newStringStream("\x78\x56\x34\x12")
    check uint32.take(s) == 0x12345678'u32

  test "eof includes offset":
    let s = newStringStream("\x01\x02")
    expect IOError:
      discard uint32.take(s, "field")