import json_serialization
import nimboxcars/model
import nimboxcars/decode/[primitives, strings]

export json_serialization

createJsonFlavor RRRocketFlavor,
  mimeTypeValue = "application/json",
  automaticObjectSerialization = false,
  requireAllFields = false,
  omitOptionalFields = false,
  allowUnknownFields = false

RRRocketFlavor.useDefaultSerializationFor int8
RRRocketFlavor.useDefaultSerializationFor int16
RRRocketFlavor.useDefaultSerializationFor int32
RRRocketFlavor.useDefaultSerializationFor int64
RRRocketFlavor.useDefaultSerializationFor uint8
RRRocketFlavor.useDefaultSerializationFor uint16
RRRocketFlavor.useDefaultSerializationFor uint32
RRRocketFlavor.useDefaultSerializationFor uint64
RRRocketFlavor.useDefaultSerializationFor float32

RRRocketFlavor.useDefaultSerializationFor string
RRRocketFlavor.useDefaultSerializationFor bool
RRRocketFlavor.useDefaultSerializationFor Bool8

RRRocketFlavor.useDefaultSerializationFor Replay
RRRocketFlavor.useDefaultSerializationFor ReplayBody
RRRocketFlavor.useDefaultSerializationFor ReplayHeader

proc writeValue*(w: var JsonWriter[RRRocketFlavor], v: FString) {.raises: [IOError].} =
  w.writeValue(v)