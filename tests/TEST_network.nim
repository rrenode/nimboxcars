import std/[unittest, os, streams, json]
import nimboxcars/parser
import nimboxcars/decode/network/[bits, netprims, attributes, netparse]
import nimboxcars/jsonmodel/network

type Writer = object
  data: seq[byte]
  position: int

proc put(w: var Writer, value: uint64, count: int) =
  for i in 0..<count:
    if w.position div 8 == w.data.len: w.data.add 0
    if (value and (1'u64 shl i)) != 0:
      w.data[w.position div 8] = w.data[w.position div 8] or byte(1 shl (w.position mod 8))
    inc w.position

proc bounded(w: var Writer, value, maximum: uint32) =
  var accumulated = 0'u32
  var mask = 1'u32
  while accumulated + mask < maximum:
    let bit = value and mask
    w.put(uint64(ord(bit != 0)), 1)
    accumulated = accumulated or bit
    mask = mask shl 1

proc f32(w: var Writer, value: float32) = w.put(cast[uint32](value), 32)
proc text(w: var Writer, value: string) =
  w.put(uint64(value.len + 1), 32)
  for c in value: w.put(uint64(ord(c)), 8)
  w.put(0, 8)

proc decoder(version: NetworkVersion = (868, 32, 10), stringId = true): AttributeDecoder =
  initAttributeDecoder(version, @[], stringId)

proc parse(tag: AttributeTag, w: Writer, d = decoder()): Attribute =
  var b = initBitReader(w.data)
  result = d.decodeAttribute(tag, b)
  doAssert b.position == w.position, "Decoder consumed a different number of bits"

suite "network bitstream":
  test "unaligned 64-bit values, bounds, and no partial read on EOF":
    var w: Writer
    w.put(5, 3)
    w.put(high(uint64), 64)
    w.put(0x81, 8)
    var b = initBitReader(w.data)
    check b.readBits(3) == 5
    check b.readU64() == high(uint64)
    check b.readI8() == -127
    let position = b.position
    expect NetworkDecodeError: discard b.readU32()
    check b.position == position

  test "SerializeInt at power-of-two and conditional-bit boundaries":
    for maximum in 1'u32..65'u32:
      for value in 0'u32..<maximum:
        var w: Writer
        w.bounded(value, maximum)
        w.put(0xAC, 8)
        var b = initBitReader(w.data)
        check b.readBounded(maximum) == value
        check b.readU8() == 0xAC
        check b.position == w.position

  test "published boxcars vector and rotation examples":
    var b = initBitReader(@[6'u8, 8, 216, 13])
    check b.readVector3i(5) == Vector3i(x: 0, y: 0, z: 93)
    b = initBitReader(@[5'u8, 0])
    let rot = b.readRotation()
    check rot.yaw.get == 2
    check rot.pitch.isNone and rot.roll.isNone

  test "legacy and smallest-three quaternion encodings":
    var w: Writer
    for i in 0..2: w.put(32768, 16)
    var b = initBitReader(w.data)
    check b.readQuaternion(6) == Quaternion()
    for largest in 0..3:
      w = Writer()
      w.put(uint64(largest), 2)
      for i in 0..2: w.put(131071, 18)
      b = initBitReader(w.data)
      let q = b.readQuaternion(7)
      check abs([q.x, q.y, q.z, q.w][largest] - 1) < 0.00001
      check b.position == 56

  test "Windows-1252, zero-length, UTF-16 surrogate pairs and invalid lengths":
    var w: Writer
    w.text("\x80\xE9")
    var b = initBitReader(w.data)
    check b.readText() == "€é"
    w = Writer()
    w.put(cast[uint32](-3'i32), 32)
    w.put(0xD83D, 16)
    w.put(0xDE80, 16)
    w.put(0, 16)
    b = initBitReader(w.data)
    check b.readText() == "🚀"
    b = initBitReader(@[0'u8, 0, 0, 0])
    check b.readText() == ""
    b = initBitReader(@[1'u8, 0, 0, 0, 0])
    check b.readText() == ""
    b = initBitReader(@[0'u8, 0, 0, 128])
    expect NetworkDecodeError: discard b.readText()
    w = Writer()
    w.put(cast[uint32](-2'i32), 32)
    w.put(0xD800, 16)
    w.put(0, 16)
    b = initBitReader(w.data)
    expect NetworkDecodeError: discard b.readText()

suite "network attributes":
  test "split-screen reservation names preserve byte-to-character encoding":
    var w: Writer
    w.put(0, 3)
    w.put(0, 8) # split-screen system
    w.put(1, 24)
    w.put(0, 8) # local ID
    w.put(0x80, 8)
    w.put(0, 8)
    w.put(0, 8) # two flags and six unknown bits
    check parse(AttributeTag.Reservation, w).reservationValue.name.get == "\u0080"

  test "every supported tag consumes its complete zero-value wire layout":
    # Independently counted wire widths at (868,32,10). Zero vectors occupy
    # 5 size bits plus three 2-bit coordinates; modern quaternions occupy 56.
    const widths: array[AttributeTag, int] = [
      1, 8, 83, 54, 224, 18, 88, 121, 188, 11, 44, 77, 9, 33, 32,
      8, 32, 64, 232, 464, 11, 41, 2, 9, 14, 32, 79, 90, 163, 88,
      0, 32, 40, 51, 8, 161, 8, 18, 33, 3, 98, 100, 64, 32, 33]
    for tag in AttributeTag:
      if tag == AttributeTag.NotImplemented: continue
      checkpoint $tag
      var b = initBitReader(newSeq[byte](1024))
      discard decoder().decodeAttribute(tag, b)
      check b.position == widths[tag]
      b = initBitReader(newSeq[byte]((widths[tag] - 1) div 8))
      expect NetworkDecodeError: discard decoder().decodeAttribute(tag, b)
    var b = initBitReader(@[])
    expect NetworkDecodeError: discard decoder().decodeAttribute(AttributeTag.NotImplemented, b)

  test "camera transition and game mode version boundaries":
    for version in [(868, 19, 0), (868, 20, 0)]:
      var w: Writer
      for i in 1..6: w.f32(float32(i))
      if version >= (868, 20, 0): w.f32(0)
      let a = parse(AttributeTag.CamSettings, w, decoder(version))
      check a.camSettingsValue.transition.isSome == (version >= (868, 20, 0))
    for version in [(868, 11, 0), (868, 12, 0)]:
      let width = if version < (868, 12, 0): 2 else: 8
      var w: Writer
      w.put(3, width)
      check parse(AttributeTag.GameMode, w, decoder(version)).gameModeValue == (uint8(width), 3'u8)

  test "loadout version gates and discarded trailing words stay aligned":
    for version in [10, 11, 16, 17, 19, 22]:
      var w: Writer
      w.put(uint64(version), 8)
      for i in 1..7: w.put(uint64(i), 32)
      if version > 10: w.put(8, 32)
      if version >= 16:
        for i in 9..11: w.put(uint64(i), 32)
      if version >= 17: w.put(12, 32)
      if version >= 19: w.put(13, 32)
      if version >= 22:
        for i in 14..16: w.put(uint64(i), 32)
      let v = parse(AttributeTag.Loadout, w).loadoutValue
      check v.body == 1 and v.unknown1 == 7
      check v.unknown2.isSome == (version > 10)
      check v.engineAudio.isSome == (version >= 16)
      check v.banner.isSome == (version >= 17)
      check v.productId.isSome == (version >= 19)

  test "absent versus zero actor IDs, party leader and sleeping velocities":
    var w: Writer
    w.put(0, 1)
    w.put(1, 1)
    check parse(AttributeTag.Pickup, w).pickupValue.instigator.isNone
    w = Writer()
    w.put(1, 1)
    w.put(0, 32)
    w.put(9, 8)
    let p = parse(AttributeTag.PickupNew, w).pickupNewValue
    check p.instigator.isSome and int32(p.instigator.get) == 0
    check p.pickedUp == 9
    w = Writer()
    w.put(0, 8)
    check parse(AttributeTag.PartyLeader, w).partyLeaderValue.isNone
    var b = initBitReader(@[1'u8] & newSeq[byte](8))
    let rb = decoder().decodeAttribute(AttributeTag.RigidBody, b).rigidBodyValue
    check rb.sleeping
    check rb.linearVelocity.isNone and rb.angularVelocity.isNone
    check b.position == 68

  test "all platform IDs and PsyNet/PS4 version-dependent tails":
    for net in [0, 1, 9, 10]:
      for system in [0, 1, 2, 4, 5, 6, 7, 11]:
        var w: Writer
        w.put(uint64(system), 8)
        case system
        of 0: w.put(42, 24)
        of 1, 4, 5: w.put(high(uint64), 64)
        of 2:
          for i in 0..<16: w.put(if i == 0: 65'u64 else: 0'u64, 8)
          for i in 0..<(if net >= 1: 16 else: 8): w.put(0xAC, 8)
          w.put(123, 64)
        of 6, 7:
          w.put(123, 64)
          if system == 6 or net < 10:
            for i in 0..<24: w.put(0xAC, 8)
        of 11: w.text("epic-id")
        else: discard
        w.put(3, 8)
        let id = parse(AttributeTag.UniqueId, w, decoder((868, 32, net))).uniqueIdValue
        check int(id.systemId) == system and id.localId == 3
        if system == 2: check id.remoteId.playStationValue.name == "A"
        if system == 7: check id.remoteId.psyNetValue.unknown1.len == (if net < 10: 24 else: 0)
    var b = initBitReader(@[3'u8])
    expect NetworkDecodeError: discard decoder().decodeAttribute(AttributeTag.UniqueId, b)

  test "server ID selects integer or string representation":
    var w: Writer
    w.put(high(uint64), 64)
    check parse(AttributeTag.QWordString, w, decoder(stringId = false)).qWordValue == high(uint64)
    w = Writer()
    w.text("server-123")
    check parse(AttributeTag.QWordString, w).stringValue == "server-123"

  test "product value version gates and nested loadouts":
    let objects = @["TAGame.ProductAttribute_UserColor_TA", "TAGame.ProductAttribute_Painted_TA",
      "TAGame.ProductAttribute_SpecialEdition_TA", "TAGame.ProductAttribute_TeamEdition_TA",
      "TAGame.ProductAttribute_TitleID_TA", "other"]
    for version in [(868, 17, 0), (868, 18, 0), (868, 23, 8)]:
      var w: Writer
      w.put(1, 8) # one slot
      w.put(6, 8) # six product attributes
      for id in 0..5:
        w.put(1, 1)
        w.put(uint64(id), 32)
        case id
        of 0:
          if version < (868, 23, 8): w.put(1, 1)
          w.put(123, if version < (868, 23, 8): 31 else: 32)
        of 1, 3:
          if version < (868, 18, 0): w.bounded(13, 14)
          else: w.put(13, 31)
        of 2: w.put(7, 31)
        of 4: w.text("title")
        else: discard
      let products = parse(AttributeTag.LoadoutOnline, w, initAttributeDecoder(version, objects)).loadoutOnlineValue[0]
      check products.len == 6
      check products[0].value.kind == (if version < (868, 23, 8): ProductValueKind.OldColor else: ProductValueKind.NewColor)
      check products[1].value.kind == (if version < (868, 18, 0): ProductValueKind.OldPaint else: ProductValueKind.NewPaint)
      check products[3].value.kind == (if version < (868, 18, 0): ProductValueKind.OldTeamEdition else: ProductValueKind.NewTeamEdition)
      check products[4].value.titleValue == "title"
      check products[5].value.kind == ProductValueKind.Absent

proc frameHeader(w: var Writer, time: float32) =
  w.f32(time)
  w.f32(0.03)

proc channel(w: var Writer, alive, fresh: bool) =
  w.put(1, 1)
  w.bounded(5, 1023)
  w.put(uint64(ord(alive)), 1)
  if alive: w.put(uint64(ord(fresh)), 1)

proc syntheticHeader(count: int32): ReplayHeader =
  ReplayHeader(majorVersion: 868, minorVersion: 32, netVersion: 10,
    props: @[Property(name: "NumFrames", value: PropertyValue(kind: pkInt, i: count))])

suite "network frames and replay integration":
  test "spawn, inherited property update, deletion and channel reuse":
    var w: Writer
    w.frameHeader(1)
    w.channel(true, true)
    w.put(7, 32) # name
    w.put(0, 1)
    w.put(0, 32) # ZoneInfo has no trajectory
    w.channel(true, false)
    w.put(1, 1) # property present, bounded stream 0/max 1 takes zero bits
    w.put(1, 1) # bHidden
    w.put(0, 1) # no more properties
    w.put(0, 1) # no more actors
    w.frameHeader(2)
    w.channel(false, false)
    w.put(0, 1)
    w.frameHeader(3)
    w.channel(true, true)
    w.put(8, 32)
    w.put(0, 1)
    w.put(0, 32)
    w.put(0, 1)
    let body = ReplayBody(networkData: w.data,
      objects: @[FString("Engine.ZoneInfo"), FString("Engine.Actor"), FString("Engine.Actor:bHidden")],
      netCache: @[NetCache(objectIndex: 1, properties: @[NetCacheProperty(objectIndex: 2, streamId: 0)])])
    let f = decodeNetwork(syntheticHeader(3), body).frames
    check f.len == 3
    check f[0].newActors[0].initialTrajectory.location.isNone
    check f[0].updatedActors[0].attribute.booleanValue
    check int32(f[1].deletedActors[0]) == 5
    check f[2].newActors[0].nameId.get == 8

  test "truncated frames, unknown actors and invalid cache indices report errors":
    var w: Writer
    w.frameHeader(1)
    w.channel(true, false)
    expect NetworkDecodeError:
      discard decodeNetwork(syntheticHeader(1), ReplayBody(networkData: w.data))
    expect NetworkDecodeError:
      discard decodeNetwork(syntheticHeader(1), ReplayBody(networkData: @[1'u8]))
    expect NetworkDecodeError:
      discard decodeNetwork(syntheticHeader(1), ReplayBody(networkData: w.data, netCache: @[NetCache(objectIndex: -1)]))
    expect ValueError:
      discard parseBody(newStringStream(""), getAll)

  test "map instance normalization":
    check normalizeObject("stadium_foggy_p.TheWorld:PersistentLevel.VehiclePickup_Boost_TA_30") ==
      "TheWorld:PersistentLevel.VehiclePickup_Boost_TA"
    check normalizeObject("TAGame.Car_TA") == "TAGame.Car_TA"

  test "both replay fixtures decode expected frame and actor counts":
    for fixture in [("SIMPLE", 336, 36, 137, 0), ("C83035FA11F10787A86F62987AC938C8", 10462, 5360, 198204, 566)]:
      let path = currentSourcePath().parentDir / "replays" / (fixture[0] & ".replay")
      let replay = parseReplay(path, getAll, checkCrc = true)
      check replay.body.networkFrames.isSome
      let frames = replay.body.networkFrames.get.frames
      check frames.len == fixture[1]
      var created, updated, deleted: int
      for f in frames:
        created += f.newActors.len
        updated += f.updatedActors.len
        deleted += f.deletedActors.len
      check (created, updated, deleted) == (fixture[2], fixture[3], fixture[4])

  test "skip, raw and decoded states are distinct":
    let path = currentSourcePath().parentDir / "replays" / "SIMPLE.replay"
    let skipped = parseReplay(path, skipParsing)
    let raw = parseReplay(path, skipDeserial)
    check skipped.body.networkData.len == 0 and skipped.body.networkFrames.isNone
    check raw.body.networkData.len == int(raw.body.networkSize) and raw.body.networkFrames.isNone
    check decodeNetwork(raw.header, raw.body).frames.len == 336

  test "JSON matches Rust variant shape and preserves 64-bit IDs":
    check networkJson(Attribute(kind: AttributeKind.QWord, qWordValue: high(uint64))) ==
      %*{"QWord": "18446744073709551615"}
    check networkJson(Attribute(kind: AttributeKind.PartyLeader, partyLeaderValue: none(ref UniqueId))) ==
      %*{"PartyLeader": nil}
    check networkJson(ProductValue(kind: ProductValueKind.Absent)) == %"Absent"
    check networkJson(Attribute(kind: AttributeKind.FlaggedByte, flaggedByteValue: (true, 5'u8))) ==
      %*{"FlaggedByte": [true, 5]}
