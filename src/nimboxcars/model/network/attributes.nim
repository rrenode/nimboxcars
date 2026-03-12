type
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
    blue_flag*: bool
    blue_color*: uint8
    orange_flag*: bool
    orange_color*: uint8

  AppliedDamage* = object
    id*: uint8
    position*: Vector3f
    damage_index*: int32
    total_damage*: int32

  DamageState* = object
    tile_state*: uint8
    damaged*: bool
    offender*: ActorId
    ball_position*: Vector3f
    direct_hit*: bool
    unknown1*: bool

  Demolish* = object
    attacker_flag*: bool
    attacker*: ActorId
    victim_flag*: bool
    victim*: ActorId
    attack_velocity*: Vector3f
    victim_velocity*: Vector3f

  DemolishExtended* = object
    attacker_pri*: ActiveActor
    self_demo*: ActiveActor
    self_demolish*: bool
    goal_explosion_owner*: ActiveActor
    attacker*: ActiveActor
    victim*: ActiveActor
    attacker_velocity*: Vector3f
    victim_velocity*: Vector3f

  DemolishFx* = object
    custom_demo_flag*: bool
    custom_demo_id*: int32
    attacker_flag*: bool
    attacker*: ActorId
    victim_flag*: bool
    victim*: ActorId
    attack_velocity*: Vector3f
    victim_velocity*: Vector3f

  Explosion* = object
    flag*: bool
    actor*: ActorId
    location*: Vector3f

  ExtendedExplosion* = object
    explosion*: Explosion
    unknown1*: bool
    secondary_actor*: ActorId

  Loadout* = object
    version*: uint8
    body*: uint32
    decal*: uint32
    wheels*: uint32
    rocket_trail*: uint32
    antenna*: uint32
    topper*: uint32
    unknown1*: uint32
    unknown2*: uint32
    engine_audio*: uint32
    trail*: uint32
    goal_explosion*: uint32
    banner*: uint32
    product_id*: uint32

  TeamLoadout* = object
    blue*: Loadout
    orange*: Loadout

  StatEvent* = object
    unknown1*: bool
    object_id*: int32

  MusicStinger* = object
    flag*: bool
    cue*: uint32
    trigger*: uint8

  Pickup* = object
    instigator*: ActorId
    picked_up*: bool

  PickupNew* = object
    instigator*: ActorId
    picked_up*: uint8

  Welded* = object
    active*: bool
    actor*: ActorId
    offset*: Vector3f
    mass*: float32
    rotation*: Rotation

  TeamPaint* = object
    team*: uint8
    primary_color*: uint8
    accent_color*: uint8
    primary_finish*: uint32
    accent_finish*: uint32

  RigidBody* = object
    sleeping*: bool
    location*: Vector3f
    rotation*: Quaternion
    linear_velocity*: Vector3f
    angular_velocity*: Vector3f

  UniqueId* = object
    system_id*: uint8
    remote_id*: RemoteId
    local_id*: uint8

  PsyNetId* = object
    online_id*: uint64
    unknown1*: seq[uint8]

  SwitchId* = object
    online_id*: uint64
    unknown1*: seq[uint8]

  Ps4Id* = object
    online_id*: uint64
    name*: String
    unknown1*: seq[uint8]

  pub enum RemoteId
    PlayStation(Ps4Id)
    PsyNet(PsyNetId)
    SplitScreen(uint32)

    Steam(uint64)
    Switch(SwitchId)

    Xbox(uint64)

    QQ(uint64)
    Epic(String)


  Reservation* = object
    number*: uint32
    unique_id*: UniqueId
    name*: String
    unknown1*: bool
    unknown2*: bool
    unknown3*: uint8


  PrivateMatchSettings* = object
    mutators*: String
    joinable_by*: uint32
    max_players*: uint32
    game_name*: String
    password*: String
    flag*: bool


  Product* = object
    unknown*: bool
    object_ind*: ObjectId
    value*: ProductValue

  AttributeKind* = enum
    akBoolean, akByte, akAppliedDamage, akDamageState, akCamSettings,
    akClubColors, akDemolish, akDemolishExtended, akDemolishFx,
    akEnum, akExplosion, akExtendedExplosion, akFlaggedByte,
    akActiveActor, akFloat, akGameMode, akInt, akInt64,
    akLoadout, akTeamLoadout, akLocation, akMusicStinger,
    akPlayerHistoryKey, akPickup, akPickupNew, akQWord,
    akWelded, akTitle, akTeamPaint, akRigidBody, akString,
    akUniqueId, akReservation, akPartyLeader, akPrivateMatch,
    akLoadoutOnline, akLoadoutsOnline, akStatEvent, akRotation,
    akRepStatTitle, akPickupInfo, akImpulse, akReplicatedBoost,
    akLogoData

  AttributeValue* = object
    case kind*: AttributeKind
    of akBoolean: boolean*: bool
    of akByte: byteVal*: uint8
    of akFloat: floatVal*: float32
    of akInt: intVal*: int32
    of akInt64: int64Val*: int64
    of akQWord: qwordVal*: uint64
    of akString: stringVal*: string
    of akAppliedDamage: appliedDamageVal*: AppliedDamage
    of akDamageState: damageStateVal*: DamageState
    of akCamSettings: camSettingsVal*: CamSettings
    of akClubColors: clubColorsVal*: ClubColors
    else:
      discard