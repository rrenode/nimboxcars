type
  Properties* = object
    teamSize*: int
    unfairTeamSize*: int

  Header* = object
    headerLength*: int32
    headerCrc*: int32
    version*: string
    properties*: Properties
    content_size*: int32
    contentCrc*: int32


proc parseHeader*(data: openArray[byte]): void =
  var i = 0
  for b in data:
    let byteVal = ord(b)
    echo byteVal
    i += 1
    if i > 5:
      return