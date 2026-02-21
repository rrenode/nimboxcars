import std/[streams, options, strformat]
import primitives

type
  PropertyKind* = enum
    pkInt, pkStr, pkBool, pkName, pkArray, pkBytes, pkQWord, pkFloat, pkStruct, pkUnknown

  ByteValue* = object
    kind*: string
    value*: Option[string]

  StructValue* = object
    name*: string
    fields*: Properties

  PropertyValue* = object
    case kind*: PropertyKind
    of pkInt:     i*: int32
    of pkFloat:   f*: float32
    of pkBool:    b*: bool
    of pkQWord:   q*: uint64
    of pkStr, pkName:   s*: string
    of pkBytes:   bytes*: ByteValue
    of pkArray:   props*: seq[Properties]
    of pkStruct:  st*: StructValue
    of pkUnknown: raw*: string

  Property* = object
    name*:  string
    kind*:  string
    value*: PropertyValue
  
  Properties* = seq[Property]

proc readPropertiesUntilNone*(s: Stream): Properties
proc readPropertyName*(s: Stream): Option[string]
proc readArrayOfProperties*(s: Stream): seq[Properties]

proc kindFromTypeString*(t: string): PropertyKind =
  case t:
  of "IntProperty": pkInt
  of "StrProperty": pkStr
  of "NameProperty": pkName
  of "FloatProperty": pkFloat
  of "ByteProperty": pkBytes
  of "ArrayProperty": pkArray
  of "QWordProperty": pkQWord
  of "BoolProperty": pkBool
  of "StructProperty": pkStruct
  else:
    pkUnknown

proc readByteProperty*(s: Stream): ByteValue =
  let kind = readString8(s)
  if kind == "None":
    discard readUint8(s)
    return ByteValue(kind: kind, value: none(string))
  else:
    return ByteValue(kind: kind, value: some(readString8(s)))

proc readPropertyName*(s: Stream): Option[string] = 
  let n = readString8(s)
  if n == "None" or n == "\0\0\0None":
    return none(string)
  return some(n)

proc readArrayOfProperties*(s: Stream): seq[Properties] =
  let size = int(readInt32(s))
  if size < 0:
    raise newException(ValueError, &"Negative ArrayProperty size: {size} at {s.getPosition()}")

  result = newSeq[Properties](size)
  for i in 0..<size:
    result[i] = readPropertiesUntilNone(s)

proc readPropertiesUntilNone*(s: Stream): Properties =
  result = @[]
  while true:
    let nameOpt = readPropertyName(s)
    if nameOpt.isNone:
      break
    let propType = readString8(s)

    discard readU32(s) # Boxcars says not to rely on this!
    discard readU32(s) # Unknown Prop Attribute
    
    var propVal: PropertyValue
    case propType:
      of "IntProperty":
        propVal = PropertyValue(kind: pkInt, i: readInt32(s))
      of "StrProperty":
        propVal = PropertyValue(kind: pkStr, s: readString16(s))
      of "NameProperty":
        propVal = PropertyValue(kind: pkName, s: readString16(s))
      of "FloatProperty":
        propVal = PropertyValue(kind: pkFloat, f: readFloat32(s))
      of "ArrayProperty":
        propVal = PropertyValue(kind: pkArray, props: readArrayOfProperties(s))
      of "ByteProperty":
        propVal = PropertyValue(kind: pkBytes, bytes: readByteProperty(s))
      of "QWordProperty":
        propVal = PropertyValue(kind: pkQWord, q: readU64(s))
      of "BoolProperty":
        propVal = PropertyValue(kind: pkBool, b: readBool8(s))
      of "StructProperty":
        let structName = readString8(s)
        let fields = readPropertiesUntilNone(s)
        propVal = PropertyValue(kind: pkStruct, st: StructValue(name: structName, fields: fields))
    result.add(Property(name:nameOpt.get(), kind:propType, value:propVal))