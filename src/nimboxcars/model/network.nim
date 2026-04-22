import nimboxcars/model/network/[attributes, netprims]

export attributes, netprims

type
  UpdatedAttribute* = object
    actorId*: ActorId
    streamId*: StreamId
    objectId*: ObjectId
    attribute*: Attribute

  SpawnTrajectory* = enum
    none, location, locationAndRotation
  
  Trajectory* = object
    location*: Vector3i
    rotation*: Rotation

  NewActor* = object
    actorId*: ActorId
    nameId*: int32
    objectId*: ObjectId
    initalTrajectory*: Trajectory

  Frame* = object
    time*: float32
    delta*: float32
    newActors*: seq[NewActor]
    deletedActors*: seq[ActorId]
    updateActors*: seq[UpdatedAttribute]