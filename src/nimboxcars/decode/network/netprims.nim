import std/[streams, strformat]
import nimboxcars/decode/[generics_utils, strings]
import nimboxcars/model/network/[netprims]

proc take*(t: typedesc[Vector3f]; s: Stream; what="Vector3f"): Vector3f =
  result.x = float32.take(s, &"{what}.Vector3f.x")
  result.y = float32.take(s, &"{what}.Vector3f.y")
  result.z = float32.take(s, &"{what}.Vector3f.z")

proc take*(t: typedesc[Vector3i]; s: Stream; what="Vector3i"): Vector3i =
  result.x = int32.take(s, &"{what}.Vector3i.x")
  result.y = int32.take(s, &"{what}.Vector3i.y")
  result.z = int32.take(s, &"{what}.Vector3i.z")

proc take*(t: typedesc[Quaternion]; s: Stream; what="Qaternion"): Quaternion =
  result.x = float32.take(s, &"{what}.Quaternion.x")
  result.y = float32.take(s, &"{what}.Quaternion.y")
  result.z = float32.take(s, &"{what}.Quaternion.z")
  result.w = float32.take(s, &"{what}.Quaternion.w")

proc take*(t: typedesc[Rotation]; s: Stream; what="Rotation"): Rotation =
  result.x = int8.take(s, &"{what}.Rotation.yaw")
  result.y = int8.take(s, &"{what}.Rotation.pitch")
  result.z = int8.take(s, &"{what}.Rotation.roll")

proc ActorId*(t: typedesc[ActorId]; s: Stream; what="ActorId"): ActorId =
  result = int32.take(s, &"{what}")

proc StreamId*(t: typedesc[StreamId]; s: Stream; what="StreamId"): StreamId =
  result = int32.take(s, &"{what}")

proc ObjectId*(t: typedesc[ObjectId]; s: Stream; what="ObjectId"): ObjectId =
  result = int32.take(s, &"{what}")