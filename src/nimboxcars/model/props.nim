import std/options

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