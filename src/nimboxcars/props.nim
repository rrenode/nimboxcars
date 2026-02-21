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

proc readPropertiesUntilNone*(s: Stream; what: string = "header"): Properties
proc readPropertyName*(s: Stream; what: string = "propName"): Option[string]
proc readArrayOfProperties*(s: Stream; what: string = "arrayProp"): seq[Properties]

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

proc readByteProperty*(s: Stream; what = "byteProp"): ByteValue =
  let kind = readString8Ctx(s, what)
  if kind == "None":
    discard readUint8(s)
    return ByteValue(kind: kind, value: none(string))
  else:
    return ByteValue(kind: kind, value: some(readString8Ctx(s, what)))

proc readPropertyName*(s: Stream; what = "propName"): Option[string] = 
  let n = readString8Ctx(s, what)
  if n == "None" or n == "\0\0\0None":
    return none(string)
  return some(n)

proc readArrayOfProperties*(s: Stream; what: string = "arrayProp"): seq[Properties] =
  let count = int(readInt32Ctx(s, what))
  if count < 0:
    raise newException(ValueError, &"Negative ArrayProperty size: {count} at {s.getPosition()}")

  result = newSeq[Properties](count)
  for i in 0..<count:
    result[i] = readPropertiesUntilNone(s, what)

proc readPropertiesUntilNone*(s: Stream; what: string = "header"): Properties =
  result = @[]
  while true:
    let nameOpt = readPropertyName(s, what)
    if nameOpt.isNone:
      break
    let propType = readString8Ctx(s, &"{what}.{nameOpt}.propType")

    discard readUint32Ctx(s) # Boxcars says not to rely on this!
    discard readUint32Ctx(s) # Unknown Prop Attribute
    
    var propVal: PropertyValue
    case propType:
      of "IntProperty":
        propVal = PropertyValue(kind: pkInt, i: readInt32Ctx(s, &"{what}.{nameOpt}"))
      of "StrProperty":
        propVal = PropertyValue(kind: pkStr, s: readString16Ctx(s, &"{what}.{nameOpt}"))
      of "NameProperty":
        propVal = PropertyValue(kind: pkName, s: readString16Ctx(s, &"{what}.{nameOpt}"))
      of "FloatProperty":
        propVal = PropertyValue(kind: pkFloat, f: readFloat32Ctx(s, &"{what}.{nameOpt}"))
      of "ArrayProperty":
        propVal = PropertyValue(kind: pkArray, props: readArrayOfProperties(s, &"{what}.{nameOpt}"))
      of "ByteProperty":
        propVal = PropertyValue(kind: pkBytes, bytes: readByteProperty(s, &"{what}.{nameOpt}"))
      of "QWordProperty":
        propVal = PropertyValue(kind: pkQWord, q: readUint64Ctx(s, &"{what}.{nameOpt}"))
      of "BoolProperty":
        propVal = PropertyValue(kind: pkBool, b: readBool8Ctx(s, &"{what}.{nameOpt}"))
      of "StructProperty":
        let structName = readString8Ctx(s, &"{what}.{nameOpt}")
        let fields = readPropertiesUntilNone(s, &"{what}.{nameOpt}.{structName}")
        propVal = PropertyValue(kind: pkStruct, st: StructValue(name: structName, fields: fields))
    result.add(Property(name:nameOpt.get(), kind:propType, value:propVal))