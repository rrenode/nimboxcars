## version-aware attribute decoding, ported from boxcars 0.10.11.
## See THIRD_PARTY_NOTICES.md for attribution.
import nimboxcars/model/network
import std/unicode
import ./[bits, netprims]

type AttributeDecoder* = object
  version*: NetworkVersion
  stringServerId*: bool
  colorId*, paintedId*, specialEditionId*, teamEditionId*, titleId*: int32

proc initAttributeDecoder*(version: NetworkVersion, objects: openArray[string],
                           stringServerId = false): AttributeDecoder =
  result = AttributeDecoder(version: version, stringServerId: stringServerId,
    colorId: -1, paintedId: -1, specialEditionId: -1, teamEditionId: -1, titleId: -1)
  for i, name in objects:
    case name
    of "TAGame.ProductAttribute_UserColor_TA":
      if result.colorId < 0: result.colorId = int32(i)
    of "TAGame.ProductAttribute_Painted_TA":
      if result.paintedId < 0: result.paintedId = int32(i)
    of "TAGame.ProductAttribute_SpecialEdition_TA":
      if result.specialEditionId < 0: result.specialEditionId = int32(i)
    of "TAGame.ProductAttribute_TeamEdition_TA":
      if result.teamEditionId < 0: result.teamEditionId = int32(i)
    of "TAGame.ProductAttribute_TitleID_TA":
      if result.titleId < 0: result.titleId = int32(i)
    else: discard

proc boxed[T](value: T): ref T =
  new(result)
  result[] = value

proc readActiveActor(b: var BitReader): ActiveActor =
  result.active = b.readBool()
  result.actor = ActorId(b.readI32())

proc readExplosion(b: var BitReader, net: int): Explosion =
  result.flag = b.readBool()
  result.actor = ActorId(b.readI32())
  result.location = b.readVector3f(net)

proc readLoadout(b: var BitReader): Loadout =
  result.version = b.readU8()
  result.body = b.readU32()
  result.decal = b.readU32()
  result.wheels = b.readU32()
  result.rocketTrail = b.readU32()
  result.antenna = b.readU32()
  result.topper = b.readU32()
  result.unknown1 = b.readU32()
  if result.version > 10: result.unknown2 = some(b.readU32())
  if result.version >= 16:
    result.engineAudio = some(b.readU32())
    result.trail = some(b.readU32())
    result.goalExplosion = some(b.readU32())
  if result.version >= 17: result.banner = some(b.readU32())
  if result.version >= 19: result.productId = some(b.readU32())
  if result.version >= 22:
    for i in 0..2: discard b.readU32()

proc readUniqueId(b: var BitReader, net: int, system: uint8): UniqueId =
  result.systemId = system
  case system
  of 0: result.remoteId = RemoteId(kind: RemoteIdKind.SplitScreen, splitScreenValue: uint32(b.readBits(24)))
  of 1: result.remoteId = RemoteId(kind: RemoteIdKind.Steam, steamValue: b.readU64())
  of 2:
    let nameBytes = b.readBytes(16)
    var n = 0
    while n < nameBytes.len and nameBytes[n] != 0: inc n
    var ps4 = Ps4Id(name: decode1252(nameBytes.toOpenArray(0, n-1)))
    ps4.unknown1 = b.readBytes(if net >= 1: 16 else: 8)
    ps4.onlineId = b.readU64()
    result.remoteId = RemoteId(kind: RemoteIdKind.PlayStation, playStationValue: ps4)
  of 4: result.remoteId = RemoteId(kind: RemoteIdKind.Xbox, xboxValue: b.readU64())
  of 5: result.remoteId = RemoteId(kind: RemoteIdKind.QQ, qQValue: b.readU64())
  of 6:
    var id = SwitchId(onlineId: b.readU64())
    id.unknown1 = b.readBytes(24)
    result.remoteId = RemoteId(kind: RemoteIdKind.Switch, switchValue: id)
  of 7:
    var id = PsyNetId(onlineId: b.readU64())
    if net < 10: id.unknown1 = b.readBytes(24)
    result.remoteId = RemoteId(kind: RemoteIdKind.PsyNet, psyNetValue: id)
  of 11: result.remoteId = RemoteId(kind: RemoteIdKind.Epic, epicValue: b.readText())
  else: b.fail("Unrecognized remote ID system " & $system)
  result.localId = b.readU8()

proc readUniqueId(b: var BitReader, net: int): UniqueId =
  let system = b.readU8()
  b.readUniqueId(net, system)

proc readProduct(d: AttributeDecoder, b: var BitReader): Product =
  result.unknown = b.readBool()
  let id = b.readI32()
  if id < 0: b.fail("Negative product object ID")
  result.objectInd = ObjectId(id)
  if id == d.colorId:
    if d.version >= (868, 23, 8):
      result.value = ProductValue(kind: ProductValueKind.NewColor, newColorValue: b.readU32())
    elif b.readBool():
      result.value = ProductValue(kind: ProductValueKind.OldColor, oldColorValue: uint32(b.readBits(31)))
    else: result.value = ProductValue(kind: ProductValueKind.NoColor)
  elif id == d.paintedId:
    if d.version >= (868, 18, 0):
      result.value = ProductValue(kind: ProductValueKind.NewPaint, newPaintValue: uint32(b.readBits(31)))
    else: result.value = ProductValue(kind: ProductValueKind.OldPaint, oldPaintValue: b.readBounded(14))
  elif id == d.titleId:
    result.value = ProductValue(kind: ProductValueKind.Title, titleValue: b.readText())
  elif id == d.specialEditionId:
    result.value = ProductValue(kind: ProductValueKind.SpecialEdition, specialEditionValue: uint32(b.readBits(31)))
  elif id == d.teamEditionId:
    if d.version >= (868, 18, 0):
      result.value = ProductValue(kind: ProductValueKind.NewTeamEdition, newTeamEditionValue: uint32(b.readBits(31)))
    else: result.value = ProductValue(kind: ProductValueKind.OldTeamEdition, oldTeamEditionValue: b.readBounded(14))
  else: result.value = ProductValue(kind: ProductValueKind.Absent)

proc readOnlineLoadout(d: AttributeDecoder, b: var BitReader): seq[seq[Product]] =
  let count = int(b.readU8())
  for i in 0..<count:
    let size = int(b.readU8())
    var products: seq[Product]
    for j in 0..<size: products.add d.readProduct(b)
    result.add products

proc decodeAttribute*(d: AttributeDecoder, tag: AttributeTag, b: var BitReader): Attribute =
  let net = d.version.net
  case tag
  of AttributeTag.Boolean: result = Attribute(kind: AttributeKind.Boolean, booleanValue: b.readBool())
  of AttributeTag.Byte: result = Attribute(kind: AttributeKind.Byte, byteValue: b.readU8())
  of AttributeTag.Float: result = Attribute(kind: AttributeKind.Float, floatValue: b.readF32())
  of AttributeTag.Int: result = Attribute(kind: AttributeKind.Int, intValue: b.readI32())
  of AttributeTag.Int64: result = Attribute(kind: AttributeKind.Int64, int64Value: b.readI64())
  of AttributeTag.Enum: result = Attribute(kind: AttributeKind.Enum, enumValue: uint16(b.readBits(11)))
  of AttributeTag.PlayerHistoryKey:
    result = Attribute(kind: AttributeKind.PlayerHistoryKey, playerHistoryKeyValue: uint16(b.readBits(14)))
  of AttributeTag.FlaggedByte:
    let flag = b.readBool()
    result = Attribute(kind: AttributeKind.FlaggedByte, flaggedByteValue: (flag, b.readU8()))
  of AttributeTag.GameMode:
    let width = if d.version < (868, 12, 0): 2 else: 8
    result = Attribute(kind: AttributeKind.GameMode, gameModeValue: (uint8(width), uint8(b.readBits(width))))
  of AttributeTag.QWordString:
    if d.stringServerId: result = Attribute(kind: AttributeKind.String, stringValue: b.readText())
    else: result = Attribute(kind: AttributeKind.QWord, qWordValue: b.readU64())
  of AttributeTag.String: result = Attribute(kind: AttributeKind.String, stringValue: b.readText())
  of AttributeTag.ActiveActor: result = Attribute(kind: AttributeKind.ActiveActor, activeActorValue: b.readActiveActor())
  of AttributeTag.Location: result = Attribute(kind: AttributeKind.Location, locationValue: b.readVector3f(net))
  of AttributeTag.RotationTag: result = Attribute(kind: AttributeKind.Rotation, rotationValue: b.readRotation())
  of AttributeTag.RigidBody:
    var body = RigidBody(sleeping: b.readBool())
    body.location = b.readVector3f(net)
    body.rotation = b.readQuaternion(net)
    if not body.sleeping:
      body.linearVelocity = some(b.readVector3f(net))
      body.angularVelocity = some(b.readVector3f(net))
    result = Attribute(kind: AttributeKind.RigidBody, rigidBodyValue: body)
  of AttributeTag.CamSettings:
    if d.version >= (868, 34, 12): b.fail("Camera settings newer than the supported boxcars 0.10.11 model")
    var c = CamSettings()
    c.fov = b.readF32()
    c.height = b.readF32()
    c.angle = b.readF32()
    c.distance = b.readF32()
    c.stiffness = b.readF32()
    c.swivel = b.readF32()
    if d.version >= (868, 20, 0): c.transition = some(b.readF32())
    result = Attribute(kind: AttributeKind.CamSettings, camSettingsValue: boxed(c))
  of AttributeTag.ClubColors:
    var c = ClubColors()
    c.blueFlag = b.readBool()
    c.blueColor = b.readU8()
    c.orangeFlag = b.readBool()
    c.orangeColor = b.readU8()
    result = Attribute(kind: AttributeKind.ClubColors, clubColorsValue: c)
  of AttributeTag.AppliedDamage:
    var a = AppliedDamage(id: b.readU8())
    a.position = b.readVector3f(net)
    a.damageIndex = b.readI32()
    a.totalDamage = b.readI32()
    result = Attribute(kind: AttributeKind.AppliedDamage, appliedDamageValue: a)
  of AttributeTag.DamageState:
    var s = DamageState(tileState: b.readU8())
    s.damaged = b.readBool()
    s.offender = ActorId(b.readI32())
    s.ballPosition = b.readVector3f(net)
    s.directHit = b.readBool()
    s.unknown1 = b.readBool()
    result = Attribute(kind: AttributeKind.DamageState, damageStateValue: s)
  of AttributeTag.Demolish:
    var v = Demolish(attackerFlag: b.readBool())
    v.attacker = ActorId(b.readI32())
    v.victimFlag = b.readBool()
    v.victim = ActorId(b.readI32())
    v.attackVelocity = b.readVector3f(net)
    v.victimVelocity = b.readVector3f(net)
    result = Attribute(kind: AttributeKind.Demolish, demolishValue: boxed(v))
  of AttributeTag.DemolishFx:
    var v = DemolishFx(customDemoFlag: b.readBool())
    v.customDemoId = b.readI32()
    v.attackerFlag = b.readBool()
    v.attacker = ActorId(b.readI32())
    v.victimFlag = b.readBool()
    v.victim = ActorId(b.readI32())
    v.attackVelocity = b.readVector3f(net)
    v.victimVelocity = b.readVector3f(net)
    result = Attribute(kind: AttributeKind.DemolishFx, demolishFxValue: boxed(v))
  of AttributeTag.DemolishExtended:
    var v = DemolishExtended(attackerPri: b.readActiveActor())
    v.selfDemo = b.readActiveActor()
    v.selfDemolish = b.readBool()
    v.goalExplosionOwner = b.readActiveActor()
    v.attacker = b.readActiveActor()
    v.victim = b.readActiveActor()
    v.attackerVelocity = b.readVector3f(net)
    v.victimVelocity = b.readVector3f(net)
    result = Attribute(kind: AttributeKind.DemolishExtended, demolishExtendedValue: boxed(v))
  of AttributeTag.Explosion: result = Attribute(kind: AttributeKind.Explosion, explosionValue: b.readExplosion(net))
  of AttributeTag.ExtendedExplosion:
    var v = ExtendedExplosion(explosion: b.readExplosion(net))
    v.unknown1 = b.readBool()
    v.secondaryActor = ActorId(b.readI32())
    result = Attribute(kind: AttributeKind.ExtendedExplosion, extendedExplosionValue: v)
  of AttributeTag.Loadout: result = Attribute(kind: AttributeKind.Loadout, loadoutValue: boxed(b.readLoadout()))
  of AttributeTag.TeamLoadout:
    var v = TeamLoadout(blue: b.readLoadout())
    v.orange = b.readLoadout()
    result = Attribute(kind: AttributeKind.TeamLoadout, teamLoadoutValue: boxed(v))
  of AttributeTag.MusicStinger:
    var v = MusicStinger(flag: b.readBool())
    v.cue = b.readU32()
    v.trigger = b.readU8()
    result = Attribute(kind: AttributeKind.MusicStinger, musicStingerValue: v)
  of AttributeTag.Pickup, AttributeTag.PickupNew:
    var instigator: Option[ActorId]
    if b.readBool(): instigator = some(ActorId(b.readI32()))
    if tag == AttributeTag.Pickup:
      result = Attribute(kind: AttributeKind.Pickup, pickupValue: Pickup(instigator: instigator, pickedUp: b.readBool()))
    else:
      result = Attribute(kind: AttributeKind.PickupNew, pickupNewValue: PickupNew(instigator: instigator, pickedUp: b.readU8()))
  of AttributeTag.Welded:
    var v = Welded(active: b.readBool())
    v.actor = ActorId(b.readI32())
    v.offset = b.readVector3f(net)
    v.mass = b.readF32()
    v.rotation = b.readRotation()
    result = Attribute(kind: AttributeKind.Welded, weldedValue: v)
  of AttributeTag.Title:
    let a = b.readBool()
    let c = b.readBool()
    let d = b.readU32()
    let e = b.readU32()
    let f = b.readU32()
    let g = b.readU32()
    let h = b.readU32()
    let i = b.readBool()
    result = Attribute(kind: AttributeKind.Title, titleValue: (a, c, d, e, f, g, h, i))
  of AttributeTag.TeamPaint:
    var v = TeamPaint(team: b.readU8())
    v.primaryColor = b.readU8()
    v.accentColor = b.readU8()
    v.primaryFinish = b.readU32()
    v.accentFinish = b.readU32()
    result = Attribute(kind: AttributeKind.TeamPaint, teamPaintValue: v)
  of AttributeTag.UniqueId: result = Attribute(kind: AttributeKind.UniqueId, uniqueIdValue: boxed(b.readUniqueId(net)))
  of AttributeTag.PartyLeader:
    let system = b.readU8()
    var id: Option[ref UniqueId]
    if system != 0: id = some(boxed(b.readUniqueId(net, system)))
    result = Attribute(kind: AttributeKind.PartyLeader, partyLeaderValue: id)
  of AttributeTag.Reservation:
    var v = Reservation(number: uint32(b.readBits(3)))
    v.uniqueId = b.readUniqueId(net)
    if v.uniqueId.systemId != 0: v.name = some(b.readText())
    elif v.uniqueId.remoteId.splitScreenValue != 0:
      var name = ""
      while name.len < 255:
        let c = b.readU8()
        if c == 0: break
        name.add Rune(c).toUTF8
      v.name = some(name)
    v.unknown1 = b.readBool()
    v.unknown2 = b.readBool()
    if d.version >= (868, 12, 0): v.unknown3 = some(uint8(b.readBits(6)))
    result = Attribute(kind: AttributeKind.Reservation, reservationValue: boxed(v))
  of AttributeTag.PrivateMatchSettings:
    var v = PrivateMatchSettings(mutators: b.readText())
    v.joinableBy = b.readU32()
    v.maxPlayers = b.readU32()
    v.gameName = b.readText()
    v.password = b.readText()
    v.flag = b.readBool()
    result = Attribute(kind: AttributeKind.PrivateMatch, privateMatchValue: boxed(v))
  of AttributeTag.LoadoutOnline:
    result = Attribute(kind: AttributeKind.LoadoutOnline, loadoutOnlineValue: d.readOnlineLoadout(b))
  of AttributeTag.LoadoutsOnline:
    var v = LoadoutsOnline(blue: d.readOnlineLoadout(b))
    v.orange = d.readOnlineLoadout(b)
    v.unknown1 = b.readBool()
    v.unknown2 = b.readBool()
    result = Attribute(kind: AttributeKind.LoadoutsOnline, loadoutsOnlineValue: v)
  of AttributeTag.StatEvent:
    var v = StatEvent(unknown1: b.readBool())
    v.objectId = b.readI32()
    result = Attribute(kind: AttributeKind.StatEvent, statEventValue: v)
  of AttributeTag.RepStatTitle:
    var v = RepStatTitle(unknown: b.readBool())
    v.name = b.readText()
    v.unknown2 = b.readBool()
    v.index = b.readU32()
    v.value = b.readU32()
    result = Attribute(kind: AttributeKind.RepStatTitle, repStatTitleValue: v)
  of AttributeTag.PickupInfo:
    var v = PickupInfo()
    for i in 0..2: v.availablePickups[i] = b.readActiveActor()
    v.itemsArePreview = b.readBool()
    result = Attribute(kind: AttributeKind.PickupInfo, pickupInfoValue: v)
  of AttributeTag.Impulse:
    var v = Impulse(compressedRotation: b.readI32())
    v.speed = b.readF32()
    result = Attribute(kind: AttributeKind.Impulse, impulseValue: v)
  of AttributeTag.ReplicatedBoost:
    var v = ReplicatedBoost(grantCount: b.readU8())
    v.boostAmount = b.readU8()
    v.unused1 = b.readU8()
    v.unused2 = b.readU8()
    result = Attribute(kind: AttributeKind.ReplicatedBoost, replicatedBoostValue: v)
  of AttributeTag.LogoData:
    var v = LogoData(logoId: b.readU32())
    v.swapColors = b.readBool()
    result = Attribute(kind: AttributeKind.LogoData, logoDataValue: v)
  of AttributeTag.NotImplemented: b.fail("Unsupported network attribute")
