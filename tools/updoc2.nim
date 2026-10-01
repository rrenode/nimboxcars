## Stage 2: formal model schema -> standalone Nim type declarations.
import std/[json, sets, strutils, tables]

proc fail(message: string) {.noreturn.} =
  raise newException(ValueError, message)

proc camel(name: string): string =
  var upper = false
  for c in name:
    if c == '_': upper = true
    else:
      result.add(if upper: c.toUpperAscii else: c)
      upper = false

proc ident(name: string): string =
  if name.len == 0 or name[0] notin Letters:
    fail("Invalid Nim identifier: " & name)
  for c in name:
    if c notin Letters + Digits + {'_'}: fail("Invalid Nim identifier: " & name)
  "`" & name & "`"

proc normalized(name: string): string =
  # Conservatively reject collisions, including Nim's style-insensitive spelling.
  name.replace("_", "").toLowerAscii

proc reserve(names: var HashSet[string], name: string) =
  if normalized(name) in names: fail("Nim name collision: " & name)
  names.incl normalized(name)

proc nimType(t: JsonNode, names: Table[string, string]): string =
  case t["kind"].getStr
  of "primitive":
    case t["name"].getStr
    of "bool": "bool"
    of "u8": "uint8"
    of "u16": "uint16"
    of "u32": "uint32"
    of "u64": "uint64"
    of "usize": "uint"
    of "i8": "int8"
    of "i16": "int16"
    of "i32": "int32"
    of "i64": "int64"
    of "isize": "int"
    of "f32": "float32"
    of "f64": "float64"
    else: fail("Unsupported primitive: " & $t)
  of "path":
    let id = t["id"].getStr
    let args = t["args"]
    if names.hasKey(id):
      if args.len != 0: fail("Generic model references are unsupported: " & $t)
      return ident(names[id])
    let path = t["path"].getStr
    case path
    of "alloc::string::String", "std::string::String":
      if args.len != 0: fail("Unexpected String arguments")
      "string"
    of "alloc::vec::Vec", "std::vec::Vec", "core::option::Option", "std::option::Option",
       "alloc::boxed::Box", "std::boxed::Box":
      if args.len != 1: fail("Expected one type argument: " & $t)
      let inner = nimType(args[0], names)
      case path.split("::")[^1]
      of "Vec": "seq[" & inner & "]"
      of "Option": "Option[" & inner & "]"
      else: "ref " & inner
    else: fail("Unresolved type: " & path & " (ID " & id & ")")
  of "array":
    let length = t["length"].getStr
    try:
      if parseInt(length) < 0: fail("Negative array length")
    except ValueError:
      fail("Expected a literal array length: " & length)
    "array[" & length & ", " & nimType(t["element"], names) & "]"
  of "tuple":
    var fields: seq[string]
    for i, e in t["elements"].elems:
      fields.add "field" & $i & ": " & nimType(e, names)
    if fields.len == 0: "tuple[]" else: "tuple[" & fields.join(", ") & "]"
  else: fail("Unsupported schema type: " & $t)

proc payload(v: JsonNode, names: Table[string, string]): string =
  let fields = v["fields"]
  if v["style"].getStr == "tuple" and fields.len == 1:
    return nimType(fields[0]["type"], names)
  var parts: seq[string]
  var used = initHashSet[string]()
  for i, field in fields.elems:
    let name = if v["style"].getStr == "tuple": "field" & $i else: camel(field["name"].getStr)
    used.reserve(name)
    parts.add ident(name) & ": " & nimType(field["type"], names)
  "tuple[" & parts.join(", ") & "]"

proc hasPayload(d: JsonNode): bool =
  for v in d["variants"]:
    if v["style"].getStr != "unit": return true

proc dependencyOrder(types: JsonNode): seq[JsonNode] =
  # Declare managed payloads before their containers so Nim generates deep copies.
  var declarations = initTable[string, JsonNode]()
  for d in types: declarations[d["id"].getStr] = d
  var visited, visiting = initHashSet[string]()
  var ordered: seq[JsonNode]
  proc visit(id: string)
  proc visitType(t: JsonNode) =
    case t["kind"].getStr
    of "path":
      let id = t["id"].getStr
      if declarations.hasKey(id): visit(id)
      for arg in t["args"]: visitType(arg)
    of "array": visitType(t["element"])
    of "tuple":
      for element in t["elements"]: visitType(element)
    else: discard
  proc visit(id: string) =
    if id in visited: return
    if id in visiting: fail("Recursive model dependencies are unsupported: " & id)
    visiting.incl id
    let d = declarations[id]
    if d["kind"].getStr == "enum":
      for variant in d["variants"]:
        for field in variant["fields"]: visitType(field["type"])
    else:
      for field in d["fields"]: visitType(field["type"])
    visiting.excl id
    visited.incl id
    ordered.add d
  for d in types: visit(d["id"].getStr)
  result = ordered

proc generateNim*(schema: JsonNode): string =
  if schema{"schemaVersion"}.getInt != 1 or schema{"types"}.kind != JArray:
    fail("Expected model schema version 1; rerun rustupdoc")
  if schema["types"].len == 0: fail("Schema contains no types")
  var names = initTable[string, string]()
  var used = initHashSet[string]()
  for d in schema["types"]:
    let name = d["name"].getStr
    discard ident(name)
    used.reserve(name)
    let id = d["id"].getStr
    if names.hasKey(id): fail("Duplicate type ID: " & id)
    names[id] = name
  for d in schema["types"]:
    if d["kind"].getStr == "enum" and d.hasPayload:
      used.reserve(d["name"].getStr & "Kind")
  result = "# Generated by tools/updoc2.nim; edit the schema or generator, not this file.\n"
  result.add "import std/options\nexport options\n\ntype\n"
  for d in dependencyOrder(schema["types"]):
    let name = d["name"].getStr
    case d["kind"].getStr
    of "struct":
      let fields = d["fields"]
      let style = d["style"].getStr
      if style == "tuple" and fields.len == 1:
        result.add "  " & ident(name) & "* = distinct " & nimType(fields[0]["type"], names) & "\n\n"
        continue
      if style notin ["unit", "plain", "tuple"]: fail("Unsupported struct style: " & style)
      result.add "  " & ident(name) & "* = object\n"
      var fieldNames = initHashSet[string]()
      for i, field in fields.elems:
        let fieldName = if style == "tuple": "field" & $i else: camel(field["name"].getStr)
        fieldNames.reserve(fieldName)
        result.add "    " & ident(fieldName) & "*: " & nimType(field["type"], names) & "\n"
    of "enum":
      let variants = d["variants"]
      if variants.len == 0: fail("Empty Rust enums are unsupported: " & name)
      let tagged = d.hasPayload
      let tagName = if tagged: name & "Kind" else: name
      result.add "  " & ident(tagName) & "* {.pure.} = enum\n"
      var variantNames = initHashSet[string]()
      for v in variants:
        let vn = v["name"].getStr
        variantNames.reserve(vn)
        result.add "    " & ident(vn)
        let disc = v{"discriminant"}
        if not disc.isNil and disc.kind != JNull:
          if tagged: fail("Explicit discriminants on payload enums are unsupported: " & name)
          let value = disc["value"].getStr
          discard parseBiggestInt(value)
          result.add " = " & value
        result.add "\n"
      if tagged:
        result.add "\n  " & ident(name) & "* = object\n    case kind*: " & ident(tagName) & "\n"
        var fieldNames = initHashSet[string]()
        fieldNames.reserve("kind")
        for v in variants:
          let vn = v["name"].getStr
          result.add "    of " & ident(tagName) & "." & ident(vn) & ":\n"
          if v["style"].getStr == "unit": result.add "      discard\n"
          else:
            let fieldName = vn[0].toLowerAscii & vn[1..^1] & "Value"
            fieldNames.reserve(fieldName)
            result.add "      " & ident(fieldName) & "*: " & payload(v, names) & "\n"
    else: fail("Unsupported declaration: " & $d)
    result.add "\n"

when isMainModule:
  import std/os
  if paramCount() == 1 and paramStr(1) in ["-h", "--help"]:
    echo "Usage: updoc2 <forms.json> <models.nim>"
    quit(0)
  if paramCount() != 2: quit("Usage: updoc2 <forms.json> <models.nim>", 1)
  try:
    let output = generateNim(parseFile(paramStr(1)))
    writeFile(paramStr(2), output)
    echo "Wrote ", paramStr(2)
  except CatchableError as e:
    quit("updoc2: " & e.msg, 1)
