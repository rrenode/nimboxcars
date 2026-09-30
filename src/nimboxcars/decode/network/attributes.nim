import std/[streams, strformat]
import nimboxcars/model/network/[attributes]
import nimboxcars/decode/[generics_utils, strings]
import nimboxcars/decode/network[netprims]

proc take*(t: typedesc[UpdatedAttribute]; s: Stream; what="Attribute"): Attribute =
  result.actorId = ActorId.take(s, &"{what}.updatedAttribute.actorId")
  result.streamId = StreamId.take(s, &"{what}.updatedAttribute.streamId")
  result.objectId = ObjectId.take(s, &"{what}.updatedAttribute.objectId")
  result.attribute = Attribute.take(s, &"{what}.updatedAttribute.attribute")