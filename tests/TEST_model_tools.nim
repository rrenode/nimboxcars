import std/[json, os, osproc, strutils, tempfiles, unittest]
import ../tools/[rustupdoc, updoc2]

proc primitive(name: string): JsonNode = %*{"primitive": name}

proc pathType(id: int, name: string, args: varargs[JsonNode]): JsonNode =
  var arguments = newJArray()
  for arg in args: arguments.add %*{"type": arg}
  %*{"resolved_path": {"id": id, "path": name,
      "args": {"angle_bracketed": {"args": arguments, "constraints": []}}}}

proc fixture(): JsonNode =
  ## A small rustdoc-shaped crate covering the model shapes used by boxcars.
  result = %*{"root": 0, "format_version": 57, "index": {}, "paths": {}}
  let doc = result
  proc add(id: int, name: string, inner: JsonNode, visibility = "public") =
    doc["index"][$id] = %*{"id": id, "crate_id": 0, "name": name,
        "visibility": visibility, "inner": inner}
    doc["paths"][$id] = %*{"path": ["boxcars", "network", name]}
  proc field(id: int, name: string, typ: JsonNode) =
    add(id, name, %*{"struct_field": typ})
  proc structure(id: int, name: string, kind: JsonNode) =
    add(id, name, %*{"struct": {"kind": kind,
        "generics": {"params": [], "where_predicates": []}}})
  proc enumeration(id: int, name: string, variants: seq[int], visibility = "public") =
    add(id, name, %*{"enum": {"variants": variants, "has_stripped_variants": false,
        "generics": {"params": [], "where_predicates": []}}}, visibility)
  proc variant(id: int, name: string, kind: JsonNode) =
    add(id, name, %*{"variant": {"kind": kind, "discriminant": nil}})

  add(0, "boxcars", %*{"module": {"items": []}})
  for entry in [(900, "core::option::Option"), (901, "alloc::vec::Vec"),
                (902, "alloc::boxed::Box"), (903, "alloc::string::String")]:
    doc["paths"][$entry[0]] = %*{"path": entry[1].split("::")}
  field(11, "0", primitive("i32"))
  structure(10, "ActorId", %*{"tuple": [11]})
  field(21, "transition", pathType(900, "Option", primitive("f32")))
  field(22, "available_pickups", %*{"array": {"len": "3", "type": pathType(10, "ActorId")}})
  field(23, "products", pathType(901, "Vec", pathType(901, "Vec", primitive("u32"))))
  field(24, "type", pathType(903, "String"))
  field(25, "managed_products", pathType(901, "Vec", pathType(901, "Vec", pathType(80, "Product"))))
  structure(20, "Settings", %*{"plain": {"fields": [21, 22, 23, 24, 25], "has_stripped_fields": false}})
  variant(31, "None", %"plain")
  field(35, "0", primitive("bool"))
  field(36, "1", primitive("u8"))
  variant(32, "FlaggedByte", %*{"tuple": [35, 36]})
  field(37, "0", pathType(900, "Option", pathType(902, "Box", pathType(20, "Settings"))))
  variant(33, "Leader", %*{"tuple": [37]})
  field(38, "object_id", pathType(10, "ActorId"))
  variant(34, "Named", %*{"struct": {"fields": [38], "has_stripped_fields": false}})
  enumeration(30, "Attribute", @[31, 32, 33, 34])
  variant(41, "Boolean", %"plain")
  variant(42, "Int", %"plain")
  enumeration(40, "AttributeTag", @[41, 42], "crate")
  structure(50, "Empty", %"unit")
  field(61, "0", primitive("u8"))
  field(62, "1", %*{"tuple": [primitive("bool"), primitive("i16")]})
  structure(60, "Pair", %*{"tuple": [61, 62]})
  structure(70, "PrivateDecoder", %"unit")
  doc["index"]["70"]["visibility"] = %"crate"
  field(81, "value", pathType(90, "ProductValue"))
  structure(80, "Product", %*{"plain": {"fields": [81], "has_stripped_fields": false}})
  variant(91, "Absent", %"plain")
  field(93, "0", pathType(903, "String"))
  variant(92, "Title", %*{"tuple": [93]})
  enumeration(90, "ProductValue", @[91, 92])

proc checkProgram(models, program: string) =
  let directory = createTempDir("nimboxcars-models-", "")
  defer: removeDir(directory)
  writeFile(directory / "generated_models.nim", models)
  writeFile(directory / "exercise.nim", "import generated_models\n" & program)
  let command = quoteShell(findExe("nim")) & " c -r --hints:off --mm:orc --nimcache:" &
      quoteShell(directory / "cache") & " --out:" & quoteShell(directory / "exercise.exe") &
      " " & quoteShell(directory / "exercise.nim")
  let execution = execCmdEx(command)
  checkpoint execution.output
  check execution.exitCode == 0

suite "rustdoc model conversion":
  test "generated models compile and preserve usable payloads and presence":
    let forms = formalize(fixture())
    check forms["types"].len == 8
    checkProgram(generateNim(forms), """
var settings = Settings(transition: some(0'f32), `type`: "test")
doAssert settings.transition.isSome
settings.transition = none(float32)
doAssert settings.transition.isNone
settings.availablePickups[0] = ActorId(7)
doAssert int32(settings.availablePickups[0]) == 7
settings.products = @[@[1'u32, 2'u32]]
doAssert settings.products[0][1] == 2
let a = Attribute(kind: AttributeKind.FlaggedByte, flaggedByteValue: (true, 4'u8))
doAssert a.flaggedByteValue.field0
doAssert a.flaggedByteValue.field1 == 4
var boxed: ref Settings
new(boxed)
boxed[] = settings
let b = Attribute(kind: AttributeKind.Leader, leaderValue: some(boxed))
doAssert b.leaderValue.get.`type` == "test"
let c = Attribute(kind: AttributeKind.Named, namedValue: (objectId: ActorId(9)))
doAssert int32(c.namedValue.objectId) == 9
let empty = Attribute(kind: AttributeKind.None)
doAssert empty.kind == AttributeKind.None
let pair = Pair(field0: 3, field1: (true, -2'i16))
doAssert pair.field1.field1 == -2
discard Empty()
discard AttributeTag.Boolean
proc checkCopies() =
  var original = @[Product(value: ProductValue(kind: ProductValueKind.Title,
    titleValue: newString(128)))]
  original[0].value.titleValue[0] = 'A'
  var copied = original
  copied[0].value.titleValue[0] = 'B'
  doAssert copied[0].value.titleValue[0] == 'B'
  doAssert original[0].value.titleValue[0] == 'A'
for i in 0 .. 100: checkCopies()
""")

  test "index order does not affect output":
    let doc = fixture()
    var ids: seq[string]
    for id in doc["index"].keys: ids.add id
    var reordered = newJObject()
    for i in countdown(ids.high, 0): reordered[ids[i]] = doc["index"][ids[i]]
    let expected = formalize(doc)
    doc["index"] = reordered
    check formalize(doc) == expected

  test "string IDs and integer IDs resolve equivalently":
    let doc = fixture()
    doc["root"] = %"0"
    doc["index"]["10"]["inner"]["struct"]["kind"]["tuple"].elems[0] = %"11"
    doc["index"]["30"]["inner"]["enum"]["variants"].elems[0] = %"31"
    doc["index"]["38"]["inner"]["struct_field"]["resolved_path"]["id"] = %"10"
    check formalize(doc) == formalize(fixture())

  test "unknown types and missing fields fail instead of silently dropping data":
    let doc = fixture()
    doc["index"]["21"]["inner"]["struct_field"] = %*{"borrowed_ref": {"type": primitive("u8")}}
    expect ValueError: discard formalize(doc)
    let missing = fixture()
    missing["index"].delete("21")
    expect ValueError: discard formalize(missing)
    let stripped = fixture()
    stripped["index"]["20"]["inner"]["struct"]["kind"]["plain"]["has_stripped_fields"] = %true
    expect ValueError: discard formalize(stripped)

  test "unresolved external types and name collisions fail":
    let doc = fixture()
    doc["paths"]["903"]["path"] = %*["vendor", "String"]
    expect ValueError: discard generateNim(formalize(doc))
    let collision = fixture()
    collision["index"]["24"]["name"] = %"availablePickups"
    expect ValueError: discard generateNim(formalize(collision))
    expect ValueError: discard generateNim(%*{"schemaVersion": 99, "types": []})
    expect ValueError: discard formalize(fixture(), "missing::module")

const boxcarsRustdoc {.strdefine.} = ""
when boxcarsRustdoc.len > 0:
  suite "local boxcars snapshot integration":
    test "all selected network declarations and enum payloads survive generation":
      let doc = parseFile(boxcarsRustdoc)
      let forms = formalize(doc)
      var expected = 0
      for id, item in doc["index"]:
        if not (item["inner"].hasKey("struct") or item["inner"].hasKey("enum")): continue
        if item["visibility"].getStr != "public" and item["name"].getStr != "AttributeTag": continue
        if not doc["paths"].hasKey(id): continue
        let path = doc["paths"][id]["path"]
        if path.len >= 3 and path[0].getStr == "boxcars" and path[1].getStr == "network": inc expected
      check forms["types"].len == expected
      for d in forms["types"]:
        if d["kind"].getStr == "enum":
          check d["variants"].len == doc["index"][d["id"].getStr]["inner"]["enum"]["variants"].len
      checkProgram(generateNim(forms), """
let body = RigidBody(linearVelocity: none(Vector3f), angularVelocity: some(Vector3f()))
doAssert body.linearVelocity.isNone
doAssert body.angularVelocity.isSome
let camera = CamSettings(transition: some(0'f32))
doAssert camera.transition.isSome
let a = Attribute(kind: AttributeKind.PartyLeader, partyLeaderValue: none(ref UniqueId))
doAssert a.partyLeaderValue.isNone
let products = Attribute(kind: AttributeKind.LoadoutOnline, loadoutOnlineValue: @[@[Product()]])
doAssert products.loadoutOnlineValue[0].len == 1
doAssert int32(ActorId(4)) == 4
doAssert NewActor().nameId.isNone
doAssert Rotation().yaw.isNone
doAssert Trajectory().location.isNone
""")
