type
  Vector3f* = object
    x*: float32
    y*: float32
    z*: float32
  
  Vector3i* = object
    x*: int32
    y*: int32
    z*: int32

  Quaternion* = object
    x*: float32
    y*: float32
    z*: float32
    w*: float32
  
  Rotation* = object
    yaw*: int8
    pitch*: int8
    roll*: int8

  ActorId* = int32
  StreamId* = int32
  ObjectId* = int32
  