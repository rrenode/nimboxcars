## Compressed network primitives; these are not the byte-aligned replay readers.
import std/math
import nimboxcars/model/network
import ./bits

proc readVector3i*(b: var BitReader, netVersion: int): Vector3i =
  let size = int(b.readBounded(if netVersion >= 7: 22'u32 else: 20'u32))
  let bias = 1'i32 shl (size + 1)
  result.x = int32(b.readBits(size + 2)) - bias
  result.y = int32(b.readBits(size + 2)) - bias
  result.z = int32(b.readBits(size + 2)) - bias

proc readVector3f*(b: var BitReader, netVersion: int): Vector3f =
  let v = b.readVector3i(netVersion)
  Vector3f(x: float32(v.x) / 100, y: float32(v.y) / 100, z: float32(v.z) / 100)

proc readRotation*(b: var BitReader): Rotation =
  if b.readBool(): result.yaw = some(b.readI8())
  if b.readBool(): result.pitch = some(b.readI8())
  if b.readBool(): result.roll = some(b.readI8())

proc readQuaternion*(b: var BitReader, netVersion: int): Quaternion =
  if netVersion < 7:
    result.x = float32(int32(b.readBits(16)) - 32768) * (1'f32 / 32767'f32)
    result.y = float32(int32(b.readBits(16)) - 32768) * (1'f32 / 32767'f32)
    result.z = float32(int32(b.readBits(16)) - 32768) * (1'f32 / 32767'f32)
    return
  let largest = int(b.readBits(2))
  var components: array[4, float32]
  var sum = 0'f32
  for i in 0..3:
    if i != largest:
      let v = ((float32(b.readBits(18)) / 262143'f32 - 0.5'f32) * 2'f32) * 0.7071067811865476'f32
      components[i] = v
      sum += v * v
  components[largest] = sqrt(max(0'f32, 1'f32 - sum))
  Quaternion(x: components[0], y: components[1], z: components[2], w: components[3])

proc readTrajectory*(b: var BitReader, spawn: SpawnTrajectory, netVersion: int): Trajectory =
  if spawn != SpawnTrajectory.None: result.location = some(b.readVector3i(netVersion))
  if spawn == SpawnTrajectory.LocationAndRotation: result.rotation = some(b.readRotation())
