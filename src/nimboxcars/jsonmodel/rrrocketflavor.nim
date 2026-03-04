## Particulars of rrrocket's json schema
## 
## Flattend Base Structure:
## 
## ReplayHeader and ReplayBody are decoding conveniences. The actual replay
##  structure is a single flat sequence of fields. 
## 
## rrrocket structures there JSON in the same way.
## 
## That is, this flavor of JSON flattens nimboxcar's "Replay" and then 
##  flattens "ReplayHeader" and "ReplayBody"
## 
## 
## Header Props Ambiguity:
## 
## primitive property  → value only
## enum property       → { kind, value }
## struct property     → { name, fields }
## 
## Basically, preserve metadata for property types that would otherwise
##  be ambiguous.

import json_serialization
import std/[enumutils]
import nimboxcars/model
import nimboxcars/decode/[primitives, strings]

export json_serialization

createJsonFlavor RRRocketFlavor,
  mimeTypeValue = "application/json",
  automaticObjectSerialization = false,
  requireAllFields = false,
  omitOptionalFields = false,
  allowUnknownFields = false

RRRocketFlavor.useDefaultSerializationFor ByteValue
RRRocketFlavor.useDefaultSerializationFor StructValue

RRRocketFlavor.useDefaultSerializationFor KeyFrame
RRRocketFlavor.useDefaultSerializationFor DebugInfo
RRRocketFlavor.useDefaultSerializationFor TickMark
RRRocketFlavor.useDefaultSerializationFor ClassIndex
RRRocketFlavor.useDefaultSerializationFor NetCacheProperty
RRRocketFlavor.useDefaultSerializationFor NetCache

proc writeValue*(w: var JsonWriter[RRRocketFlavor], v: FString) {.raises: [IOError].} = 
  w.writeValue(JsonString(toJson($v)))

proc writeValue*(w: var JsonWriter[RRRocketFlavor], v: Option[string]) {.raises: [IOError].} =
  w.writeValue(JsonString(toJson(v.get())))

proc writeValue*(w: var JsonWriter[RRRocketFlavor], v: Properties)
  {.raises: [IOError], gcsafe.} =
  ## See "Header Props Ambiguity" above
  w.beginRecord()
  for p in v:
    case p.value.kind:
    of pkInt:
      w.writeField(p.name, p.value.i)
    of pkFloat:
      w.writeField(p.name, p.value.f)
    of pkBool:
      w.writeField(p.name, p.value.b)
    of pkQWord:
      w.writeField(p.name, p.value.q)
    of pkStr, pkName:
      w.writeField(p.name, p.value.s)
    of pkBytes:
      w.writeField(p.name, p.value.bytes.value)
    of pkArray:
      w.writeField(p.name, p.value.props)
    of pkStruct:
      w.writeField(p.name, p.value.st.fields)
    of pkUnknown:
      w.writeField(p.name, p.value.raw)
  w.endRecord()

proc writeValue*(w: var JsonWriter[RRRocketFlavor], v: Replay) {.raises: [IOError].} =
  ## Flattens so that ReplayHeader's and ReplayBody's fields are in the root;
  ##  matching rrrocket.
  w.beginRecord()

  w.writeField("header_size", v.header.hSize)
  w.writeField("header_crc", v.header.headerCrc)
  w.writeField("major_version", v.header.majorVersion)
  w.writeField("minor_version", v.header.minorVersion)
  w.writeField("net_version", v.header.netVersion)
  w.writeField("game_type", v.header.gameType)
  w.writeField("properties", v.header.props)

  w.writeField("content_size", v.body.contentSize)
  w.writeField("content_crc", v.body.contentCrc)
  w.writeField("levels", v.body.levels)
  w.writeField("keyframes", v.body.keyFrames)
  w.writeField("network_size", v.body.networkSize)
  w.writeField("network_frames", v.body.networkData)
  w.writeField("debug_info", v.body.debugInfo)
  w.writeField("tick_marks", v.body.tickMarks)
  w.writeField("packages", v.body.packages)
  w.writeField("objects", v.body.objects)
  w.writeField("names", v.body.names)
  w.writeField("class_indices", v.body.classIndices)
  w.writeField("net_cache", v.body.netCache)

  w.endRecord()