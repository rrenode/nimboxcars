## Actor lifecycle and attribute streams, following boxcars 0.10.11.
## See THIRD_PARTY_NOTICES.md.
import std/[tables, sets, strutils, math]
import nimboxcars/model
import ./[bits, netprims, attributes, data]
export bits.NetworkDecodeError

type
  ObjectAttribute = object
    objectId: int32
    tag: AttributeTag
  CacheInfo = object
    known: bool
    maximum: uint32
    properties: Table[int32, ObjectAttribute]

proc intProperty(header: ReplayHeader, name: string): Option[int32] =
  for p in header.props:
    if p.name == name and p.value.kind == pkInt: return some(p.value.i)

proc stringProperty(header: ReplayHeader, name: string): string =
  for p in header.props:
    if p.name == name and p.value.kind in {pkStr, pkName}: return p.value.s

proc normalizeObject*(name: string): string =
  const prefix = "TheWorld:PersistentLevel."
  var suffix = name
  if not suffix.startsWith(prefix):
    let dot = name.find('.')
    if dot < 0: return name
    suffix = name[dot+1..^1]
  if not suffix.startsWith(prefix): return name
  let rest = suffix[prefix.len..^1]
  for cls in ["CrowdActor_TA", "CrowdManager_TA", "VehiclePickup_Boost_TA",
              "InMapScoreboard_TA", "BreakOutActor_Platform_TA", "PlayerStart_Platform_TA"]:
    if rest.startsWith(cls): return prefix & cls
  name

proc hierarchy(name: string, index: Table[string, int32]): seq[int32] =
  var current = name
  var visited = initHashSet[string]()
  while true:
    let normalized = normalizeObject(current)
    if not parentClasses.hasKey(normalized): break
    if normalized in visited:
      raise newException(NetworkDecodeError, "Cyclic object hierarchy: " & name)
    visited.incl normalized
    if index.hasKey(current): result.add index[current]
    current = parentClasses[normalized]

proc decodeNetwork*(header: ReplayHeader, body: ReplayBody): NetworkFrames =
  let version: NetworkVersion = (int(header.majorVersion), int(header.minorVersion), int(header.netVersion))
  let count = header.intProperty("NumFrames")
  if count.isNone: return
  if count.get < 0 or int(count.get) > body.networkData.len:
    raise newException(NetworkDecodeError, "Invalid NumFrames for network payload: " & $count.get)
  if count.get == 0: return
  let channels = header.intProperty("MaxChannels").get(1023)
  if channels <= 0: raise newException(NetworkDecodeError, "Invalid MaxChannels: " & $channels)
  let isLan = header.stringProperty("MatchType") == "Lan"
  let stringServerId = header.stringProperty("BuildVersion") >= "221120.42953.406184"
  var objects: seq[string]
  var index = initTable[string, int32]()
  for i, name in body.objects:
    objects.add string(name)
    if not index.hasKey(string(name)): index[string(name)] = int32(i)
  let decoder = initAttributeDecoder(version, objects, stringServerId)
  var raw = newSeq[Table[int32, ObjectAttribute]](objects.len)
  for cache in body.netCache:
    if cache.objectIndex < 0 or int(cache.objectIndex) >= objects.len:
      raise newException(NetworkDecodeError, "Net cache object index out of range: " & $cache.objectIndex)
    for prop in cache.properties:
      if prop.objectIndex < 0 or int(prop.objectIndex) >= objects.len or prop.streamId < 0:
        raise newException(NetworkDecodeError, "Invalid net cache property index")
      raw[int(cache.objectIndex)][prop.streamId] = ObjectAttribute(objectId: prop.objectIndex,
        tag: attributeTags.getOrDefault(objects[int(prop.objectIndex)], AttributeTag.NotImplemented))
  var caches = newSeq[CacheInfo](objects.len)
  var spawns = newSeq[SpawnTrajectory](objects.len)
  for i, name in objects:
    let ancestors = hierarchy(name, index)
    spawns[i] = SpawnTrajectory.None
    for ancestor in ancestors:
      let cls = objects[int(ancestor)]
      if spawnStats.hasKey(cls):
        spawns[i] = spawnStats[cls]
        break
    if ancestors.len == 0: continue
    caches[i].known = true
    for j in countdown(ancestors.high, 0):
      for stream, attr in raw[int(ancestors[j])]: caches[i].properties[stream] = attr
    var maxId = 2'i32
    if caches[i].properties.len > 0:
      maxId = 0
      for id in caches[i].properties.keys: maxId = max(maxId, id)
    caches[i].maximum = uint32(maxId) + 1

  var b = initBitReader(body.networkData)
  var actors = initTable[int32, int32]()
  while result.frames.len < int(count.get):
    try:
      var frame = Frame(time: b.readF32())
      frame.delta = b.readF32()
      for value in [frame.time, frame.delta]:
        if classify(value) in {fcNan, fcInf, fcNegInf} or value < 0 or (value > 0 and value < 1e-10):
          b.fail("Invalid frame time/delta")
      if frame.time == 0 and frame.delta == 0: break
      while b.readBool():
        let actorId = int32(b.readBounded(uint32(channels)))
        if not b.readBool():
          frame.deletedActors.add ActorId(actorId)
          # The reference retains low channel IDs after destruction. Some replays
          # contain late updates; a new spawn overwrites the retained entry.
          if actorId >= 200: actors.del(actorId)
        elif b.readBool():
          var actor = NewActor(actorId: ActorId(actorId))
          if version >= (868, 20, 0) or (version >= (868, 14, 0) and not isLan):
            actor.nameId = some(b.readI32())
          discard b.readBool()
          let objectId = b.readI32()
          if objectId < 0 or int(objectId) >= objects.len: b.fail("New actor object ID out of range: " & $objectId)
          actor.objectId = ObjectId(objectId)
          actor.initialTrajectory = b.readTrajectory(spawns[int(objectId)], version.net)
          if not caches[int(objectId)].known: b.fail("Missing class hierarchy for " & objects[int(objectId)])
          actors[actorId] = objectId
          frame.newActors.add actor
        else:
          if not actors.hasKey(actorId): b.fail("Update for unknown actor " & $actorId)
          let actorObject = int(actors[actorId])
          while b.readBool():
            let stream = int32(b.readBounded(caches[actorObject].maximum))
            if not caches[actorObject].properties.hasKey(stream):
              b.fail("Unknown stream " & $stream & " for actor " & $actorId & " (" & objects[actorObject] & ")")
            let attr = caches[actorObject].properties[stream]
            try:
              let value = decoder.decodeAttribute(attr.tag, b)
              frame.updatedActors.add UpdatedAttribute(actorId: ActorId(actorId), streamId: StreamId(stream),
                objectId: ObjectId(attr.objectId), attribute: value)
            except NetworkDecodeError as e:
              raise newException(NetworkDecodeError, "actor " & $actorId & ", stream " & $stream &
                ", property " & objects[int(attr.objectId)] & ": " & e.msg)
      result.frames.add frame
    except NetworkDecodeError as e:
      raise newException(NetworkDecodeError, "frame " & $result.frames.len & ": " & e.msg)
  # Modern replays may have a u32 trailer; the reference accepts its absence.
