## Stage 1: rustdoc JSON -> a self-contained, versioned model schema.
import std/[algorithm, json, strutils]

proc fail(message: string) {.noreturn.} =
  raise newException(ValueError, message)

proc idKey(n: JsonNode): string =
  case n.kind
  of JString: n.getStr
  of JInt: $n.getInt
  else: fail("Expected a rustdoc item ID, got " & $n)

proc itemAt(doc: JsonNode, id: JsonNode): JsonNode =
  let key = idKey(id)
  if not doc["index"].hasKey(key): fail("Missing rustdoc item " & key)
  doc["index"][key]

proc normalizeType(t: JsonNode, doc: JsonNode): JsonNode =
  if t.kind != JObject: fail("Invalid Rust type: " & $t)
  if t.hasKey("primitive"):
    return %*{"kind": "primitive", "name": t["primitive"]}
  if t.hasKey("resolved_path"):
    let p = t["resolved_path"]
    let id = idKey(p["id"])
    var path = p{"path"}.getStr(p{"name"}.getStr)
    if doc.hasKey("paths") and doc["paths"].hasKey(id):
      var parts: seq[string]
      for part in doc["paths"][id]["path"]: parts.add part.getStr
      path = parts.join("::")
    if path.len == 0: fail("Missing path for type " & id)
    var args = newJArray()
    let rawArgs = p{"args"}
    if not rawArgs.isNil and rawArgs.kind != JNull:
      if not rawArgs.hasKey("angle_bracketed"):
        fail("Unsupported generic arguments: " & $p)
      let angle = rawArgs["angle_bracketed"]
      if angle{"constraints"}.len > 0: fail("Unsupported type constraints: " & $p)
      for arg in angle["args"]:
        if not arg.hasKey("type"): fail("Unsupported generic argument: " & $arg)
        args.add normalizeType(arg["type"], doc)
    return %*{"kind": "path", "id": id, "path": path, "args": args}
  if t.hasKey("array"):
    let a = t["array"]
    return %*{"kind": "array", "length": a["len"], "element": normalizeType(a["type"], doc)}
  if t.hasKey("tuple"):
    var elements = newJArray()
    for e in t["tuple"]: elements.add normalizeType(e, doc)
    return %*{"kind": "tuple", "elements": elements}
  fail("Unsupported Rust type (cannot convert losslessly): " & $t)

proc fields(doc: JsonNode, ids: JsonNode): JsonNode =
  result = newJArray()
  for id in ids:
    if id.kind == JNull: fail("Stripped tuple field; regenerate rustdoc with private items")
    let field = itemAt(doc, id)
    result.add %*{"name": field["name"], "type": normalizeType(field["inner"]["struct_field"], doc)}

proc shape(doc: JsonNode, k: JsonNode, plainName: string): JsonNode =
  if k.kind == JString and k.getStr in ["unit", "plain"]:
    return %*{"style": "unit", "fields": []}
  if k.kind == JObject and k.hasKey("tuple"):
    return %*{"style": "tuple", "fields": fields(doc, k["tuple"])}
  if k.kind == JObject and k.hasKey(plainName):
    let plain = k[plainName]
    if plain{"has_stripped_fields"}.getBool:
      fail("Stripped fields; regenerate rustdoc with private items")
    return %*{"style": "plain", "fields": fields(doc, plain["fields"])}
  fail("Unsupported item shape: " & $k)

proc formalize*(doc: JsonNode, modulePrefix = "boxcars::network"): JsonNode =
  if doc.kind != JObject or not doc.hasKey("index") or not doc.hasKey("paths"):
    fail("Expected rustdoc JSON with index and paths")
  let rootCrate = itemAt(doc, doc["root"])["crate_id"]
  var definitions: seq[JsonNode]
  for id, item in doc["index"]:
    if item["crate_id"] != rootCrate: continue
    let inner = item["inner"]
    if not (inner.hasKey("struct") or inner.hasKey("enum")): continue
    if not doc["paths"].hasKey(id): continue
    var parts: seq[string]
    for part in doc["paths"][id]["path"]: parts.add part.getStr
    let path = parts.join("::")
    if not path.startsWith(modulePrefix & "::"): continue
    # AttributeTag is crate-private, but belongs to the decoder's model vocabulary.
    if item["visibility"].getStr != "public" and item["name"].getStr != "AttributeTag": continue
    let kind = if inner.hasKey("struct"): "struct" else: "enum"
    let body = inner[kind]
    if body["generics"]["params"].len > 0 or body["generics"]["where_predicates"].len > 0:
      fail("Generic declarations are unsupported: " & path)
    var definition = %*{"id": id, "name": item["name"], "path": path, "kind": kind}
    if kind == "struct":
      let s = shape(doc, body["kind"], "plain")
      definition["style"] = s["style"]
      definition["fields"] = s["fields"]
    else:
      if body{"has_stripped_variants"}.getBool: fail("Stripped variants: " & path)
      var variants = newJArray()
      for variantId in body["variants"]:
        let item = itemAt(doc, variantId)
        let v = item["inner"]["variant"]
        var variant = shape(doc, v["kind"], "struct")
        variant["name"] = item["name"]
        variant["discriminant"] = v["discriminant"]
        variants.add variant
      definition["variants"] = variants
    definitions.add definition
  if definitions.len == 0: fail("No model declarations found under " & modulePrefix)
  definitions.sort(proc(a, b: JsonNode): int = cmp(a["path"].getStr, b["path"].getStr))
  result = %*{"schemaVersion": 1, "rustdocFormatVersion": doc{"format_version"},
              "module": modulePrefix, "types": definitions}

when isMainModule:
  import std/os
  if paramCount() == 1 and paramStr(1) in ["-h", "--help"]:
    echo "Usage: rustupdoc <rustdoc.json> <forms.json> [module-prefix=boxcars::network]"
    quit(0)
  if paramCount() notin 2..3:
    quit("Usage: rustupdoc <rustdoc.json> <forms.json> [module-prefix=boxcars::network]", 1)
  try:
    let prefix = if paramCount() == 3: paramStr(3) else: "boxcars::network"
    let output = formalize(parseFile(paramStr(1)), prefix)
    writeFile(paramStr(2), output.pretty & "\n")
    echo "Wrote ", output["types"].len, " types to ", paramStr(2)
  except CatchableError as e:
    quit("rustupdoc: " & e.msg, 1)
