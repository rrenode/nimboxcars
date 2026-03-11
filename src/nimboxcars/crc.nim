## Implemented nearly one-for-one from boxcar's crc implementation
## https://github.com/nickbabcock/boxcars/blob/e28f1de88c758dc18840ef0532ea946af0fbd1ce/src/crc.rs

func swapBytes32(x: uint32): uint32 =
  ((x and 0x000000FF'u32) shl 24) or
  ((x and 0x0000FF00'u32) shl 8)  or
  ((x and 0x00FF0000'u32) shr 8)  or
  ((x and 0xFF000000'u32) shr 24)

func genCrcTable(poly: uint32): array[16, array[256, uint32]] =
  var table: array[16, array[256, uint32]]

  var i = 0
  while i < 256:
    var crc = uint32(i) shl 24
    var j = 0
    while j < 8:
      if (crc and 0x80000000'u32) != 0'u32:
        crc = (crc shl 1) xor poly
      else:
        crc = crc shl 1
      inc j
    table[0][i] = swapBytes32(crc)
    inc i

  i = 0
  while i < 256:
    var crc = swapBytes32(table[0][i])
    var j = 1
    while j < 16:
      crc = swapBytes32(table[0][int(crc shr 24)]) xor (crc shl 8)
      table[j][i] = swapBytes32(crc)
      inc j
    inc i

  table

const CRC_TABLE = genCrcTable(0x04C11DB7'u32)

proc calcCrc*(data: openArray[byte]): uint32 =
  var crc = not swapBytes32(0xEFCBF201'u32)

  var i = 0
  let fullChunks = data.len div 16

  while i < fullChunks * 16:
    let top =
      uint32(data[i + 0]) or
      (uint32(data[i + 1]) shl 8) or
      (uint32(data[i + 2]) shl 16) or
      (uint32(data[i + 3]) shl 24)

    let one = top xor crc

    crc =
      CRC_TABLE[0][int(data[i + 15])] xor
      CRC_TABLE[1][int(data[i + 14])] xor
      CRC_TABLE[2][int(data[i + 13])] xor
      CRC_TABLE[3][int(data[i + 12])] xor
      CRC_TABLE[4][int(data[i + 11])] xor
      CRC_TABLE[5][int(data[i + 10])] xor
      CRC_TABLE[6][int(data[i + 9])] xor
      CRC_TABLE[7][int(data[i + 8])] xor
      CRC_TABLE[8][int(data[i + 7])] xor
      CRC_TABLE[9][int(data[i + 6])] xor
      CRC_TABLE[10][int(data[i + 5])] xor
      CRC_TABLE[11][int(data[i + 4])] xor
      CRC_TABLE[12][int((one shr 24) and 0xFF'u32)] xor
      CRC_TABLE[13][int((one shr 16) and 0xFF'u32)] xor
      CRC_TABLE[14][int((one shr 8) and 0xFF'u32)] xor
      CRC_TABLE[15][int(one and 0xFF'u32)]

    i += 16

  while i < data.len:
    crc = (crc shr 8) xor CRC_TABLE[0][int((uint32(data[i]) xor (crc and 0xFF'u32)))]
    inc i

  result = swapBytes32(not crc)