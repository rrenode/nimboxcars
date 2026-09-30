## The most boring thing I've ever had to do for a personal project.

import nimboxcars/model/network/netprims

type
  AttributeTag* {.pure.} = enum
    atBoolean,
    atByte,
    atAppliedDamage,
    atDamageState,
    atCamSettings,
    atClubColors,
    atDemolish,
    atDemolishFx,
    atDemolishExtended,
    atEnum,
    atExplosion,
    atExtendedExplosion,
    atFlaggedByte,
    atActiveActor,
    atFloat,
    atGameMode,
    atInt,
    atInt64,
    atLoadout,
    atTeamLoadout,
    atLocation,
    atMusicStinger,
    atPickup,
    atPickupNew,
    atPlayerHistoryKey,
    atQWord,
    atWelded,
    atRigidBody,
    atTitle,
    atTeamPaint,
    atNotImplemented,
    atstring,
    atUniqueId,
    atReservation,
    atPartyLeader,
    atPrivateMatchSettings,
    atLoadoutOnline,
    atLoadoutsOnline,
    atStatEvent,
    atRotation,
    atRepStatTitle,
    atPickupInfo,
    atImpulse,
    atReplicatedBoost,
    atLogoData

  Attribute* = object
    case kind*: AttributeTag
    of atBoolean:
      boolean*: bool
    of atByte:
      byteVal*: uint8
    of atAppliedDamage:
      appliedDamage*: AppliedDamage
    of atDamageState:
      damageState*: DamageState
    of atCamSettings:
      camSettings*: ref CamSettings
    of atClubColors:
      clubColors*: ClubColors
    of atDemolish:
      demolish*: ref Demolish
    of atDemolishExtended:
      demolishExtended*: ref DemolishExtended
    of atDemolishFx:
      demolishFx*: ref DemolishFx
    of atEnum:
      enumVal*: uint16
    of atExplosion:
      explosion*: Explosion
    of atExtendedExplosion:
      extendedExplosion*: ExtendedExplosion
    of atFlaggedByte:
      flagged*: bool
      flaggedByte*: uint8
    of atActiveActor:
      activeActor*: ActiveActor
    of atFloat:
      floatVal*: float32
    of atGameMode:
      gameModeA*: uint8
      gameModeB*: uint8
    of atInt:
      intVal*: int32
    of atInt64:
      int64Val*: int64
    of atLoadout:
      loadout*: ref Loadout
    of atTeamLoadout:
      teamLoadout*: ref TeamLoadout
    of atLocation:
      location*: Vector3f
    of atMusicStinger:
      musicStinger*: MusicStinger
    of atPlayerHistoryKey:
      playerHistoryKey*: uint16
    of atPickup:
      pickup*: Pickup
    of atPickupNew:
      pickupNew*: PickupNew
    of atQWord:
      qword*: uint64
    of atWelded:
      welded*: Welded
    of atTitle:
      titleA*: bool
      titleB*: bool
      titleC*: uint32
      titleD*: uint32
      titleE*: uint32
      titleF*: uint32
      titleG*: uint32
      titleH*: bool
    of atTeamPaint:
      teamPaint*: TeamPaint
    of atRigidBody:
      rigidBody*: RigidBody
    of atstring:
      stringVal*: string
    of atUniqueId:
      uniqueId*: ref UniqueId
    of atReservation:
      reservation*: ref Reservation
    of atPartyLeader:
      partyLeader*: ref UniqueId
    of atPrivateMatchSettings:
      privateMatch*: ref PrivateMatchSettings
    of atLoadoutOnline:
      loadoutOnline*: seq[seq[Product]]
    of atLoadoutsOnline:
      loadoutsOnline*: LoadoutsOnline
    of atStatEvent:
      statEvent*: StatEvent
    of atRotation:
      rotation*: Rotation
    of atRepStatTitle:
      repStatTitle*: RepStatTitle
    of atPickupInfo:
      pickupInfo*: PickupInfo
    of atImpulse:
      impulse*: Impulse
    of atReplicatedBoost:
      replicatedBoost*: ReplicatedBoost
    of atLogoData:
      logoData*: LogoData
    of atNotImplemented:
      discard

  RemoteIdKind* {.pure.} = enum
    ridPlayStation,
    ridPsyNet,
    ridSplitScreen,
    ridSteam,
    ridSwitch,
    ridXbox,
    ridQQ,
    ridEpic

  RemoteId* = object
    case kind*: RemoteIdKind
    of ridPlayStation:
      playStation*: Ps4Id
    of ridPsyNet:
      psyNet*: PsyNetId
    of ridSplitScreen:
      splitScreen*: uint32
    of ridSteam:
      steam*: uint64
    of ridSwitch:
      switch*: SwitchId
    of ridXbox:
      xbox*: uint64
    of ridQQ:
      qq*: uint64
    of ridEpic:
      epic*: string

  ActiveActor* = object
    active*: bool
    actor*: ActorId

  CamSettings* = object
    fov*: float32
    height*: float32
    angle*: float32
    distance*: float32
    stiffness*: float32
    swivel*: float32
    transition*: float32

  ClubColors* = object
    blueFlag*: bool
    blueColor*: uint8
    orangeFlag*: bool
    orangeColor*: uint8

  AppliedDamage* = object
    id*: uint8
    position*: Vector3f
    damageIndex*: int32
    totalDamage*: int32

  DamageState* = object
    tileState*: uint8
    damaged*: bool
    offender*: ActorId
    ballPosition*: Vector3f
    directHit*: bool
    unknown1*: bool

  Demolish* = object
    attackerFlag*: bool
    attacker*: ActorId
    victimFlag*: bool
    victim*: ActorId
    attackVelocity*: Vector3f
    victimVelocity*: Vector3f

  DemolishExtended* = object
    attackerPri*: ActiveActor
    selfDemo*: ActiveActor
    selfDemolish*: bool
    goalExplosionOwner*: ActiveActor
    attacker*: ActiveActor
    victim*: ActiveActor
    attackerVelocity*: Vector3f
    victimVelocity*: Vector3f

  DemolishFx* = object
    customDemoFlag*: bool
    customDemoId*: int32
    attackerFlag*: bool
    attacker*: ActorId
    victimFlag*: bool
    victim*: ActorId
    attackVelocity*: Vector3f
    victimVelocity*: Vector3f

  Explosion* = object
    flag*: bool
    actor*: ActorId
    location*: Vector3f

  ExtendedExplosion* = object
    explosion*: Explosion
    unknown1*: bool
    secondaryActor*: ActorId

  Loadout* = object
    version*: uint8
    body*: uint32
    decal*: uint32
    wheels*: uint32
    rocketTrail*: uint32
    antenna*: uint32
    topper*: uint32
    unknown1*: uint32
    unknown2*: uint32
    engineAudio*: uint32
    trail*: uint32
    goalExplosion*: uint32
    banner*: uint32
    productId*: uint32

  TeamLoadout* = object
    blue*: Loadout
    orange*: Loadout

  StatEvent* = object
    unknown1*: bool
    objectId*: int32

  MusicStinger* = object
    flag*: bool
    cue*: uint32
    trigger*: uint8

  Pickup* = object
    instigator*: ActorId
    pickedUp*: bool

  PickupNew* = object
    instigator*: ActorId
    pickedUp*: uint8

  Welded* = object
    active*: bool
    actor*: ActorId
    offset*: Vector3f
    mass*: float32
    rotation*: Rotation

  TeamPaint* = object
    team*: uint8
    primaryColor*: uint8
    accentColor*: uint8
    primaryFinish*: uint32
    accentFinish*: uint32

  RigidBody* = object
    sleeping*: bool
    location*: Vector3f
    rotation*: Quaternion
    linearVelocity*: Vector3f
    angularVelocity*: Vector3f

  UniqueId* = object
    systemId*: uint8
    remoteId*: RemoteId
    localId*: uint8

  PsyNetId* = object
    onlineId*: uint64
    unknown1*: seq[uint8]

  SwitchId* = object
    onlineId*: uint64
    unknown1*: seq[uint8]

  Ps4Id* = object
    onlineId*: uint64
    name*: string
    unknown1*: seq[uint8]

  Reservation* = object
    number*: uint32
    uniqueId*: UniqueId
    name*: string
    unknown1*: bool
    unknown2*: bool
    unknown3*: uint8

  PrivateMatchSettings* = object
    mutators*: string
    joinableBy*: uint32
    maxPlayers*: uint32
    gameName*: string
    password*: string
    flag*: bool

  Product* = object
    unknown*: bool
    objectInd*: ObjectId
    value*: ProductValue

  LoadoutsOnline* = object
    blue*: seq[seq[Product]]
    orange*: seq[seq[Product]]
    unknown1*: bool
    unknown2*: bool

  RepStatTitle* = object
    unknown*: bool
    name*: string
    unknown2*: bool
    index*: uint32
    value*: uint32

  PickupInfo* = object
    availablePickups*: array[3, ActiveActor]
    itemsArePreview*: bool

  Impulse* = object
    compressedRotation*: int32
    speed*: float32

  ReplicatedBoost* = object
    grantCount*: uint8
    boostAmount*: uint8
    unused1*: uint8
    unused2*: uint8

  LogoData* = object
    logoId*: uint32
    swapColors*: bool

  ProductValueKind* {.pure.} = enum
    pvNoColor,
    pvAbsent,
    pvOldColor,
    pvNewColor,
    pvOldPaint,
    pvNewPaint,
    pvTitle,
    pvSpecialEdition,
    pvOldTeamEdition,
    pvNewTeamEdition

  ProductValue* = object
    case kind*: ProductValueKind
    of pvNoColor, pvAbsent:
      discard
    of pvOldColor:
      oldColor*: uint32
    of pvNewColor:
      newColor*: uint32
    of pvOldPaint:
      oldPaint*: uint32
    of pvNewPaint:
      newPaint*: uint32
    of pvTitle:
      title*: string
    of pvSpecialEdition:
      specialEdition*: uint32
    of pvOldTeamEdition:
      oldTeamEdition*: uint32
    of pvNewTeamEdition:
      newTeamEdition*: uint32