## Small utility script to go through nimboxcar's rust source to get struct names
## Only made for network.
## 
import std/[os, osproc, strutils, json, sequtils, tables]

type
  JsonMap = Table[string, JsonNode]

  RustItemKinds = enum
    rsUnknown, rsStruct, rsStructField, rsEnum
  
  RustFieldKinds = enum
    rsPrimitive, rsGeneric, rsResolvedPath, rsArray

proc getObj(n: JsonNode; key: string): JsonNode =
  if n.kind == JObject and n.hasKey(key): n[key] else: newJObject()

proc getArr(n: JsonNode; key: string): JsonNode =
  if n.kind == JObject and n.hasKey(key) and n[key].kind == JArray: n[key] else: newJArray()

proc loadIndex(doc: JsonNode): JsonMap =
  result = initTable[string, JsonNode]()
  if doc.kind != JObject or not doc.hasKey("index"): return
  for k, v in doc["index"]:
    result[k] = v

proc itemKind(item: JsonNode): RustItemKinds =
  let inner = getObj(item, "inner")
  if inner.hasKey("struct"): return rsStruct
  if inner.hasKey("struct_field"): return rsStructField

var trackedFieldIds: seq[int]
var trackedStructIds: seq[int]

proc extractStruct(index: JsonMap, item: JsonNode): JsonNode =
  ## Extracts a struct while leaving its fields as ids
  let s = item["inner"]["struct"]
  let k = s["kind"]

  var fields = newJArray()
  var style = "unknown"

  if k.kind == JObject and k.hasKey("plain"):
    style = "plain"
    fields = k["plain"]["fields"]
  elif k.kind == JObject and k.hasKey("tuple"):
    style = "tuple"
    fields = k["tuple"]

  for f in fields.items:
    case f.kind
    of JInt:
      let v = f.getInt()
      trackedFieldIds.addUnique v
    else: discard

  trackedStructIds.addUnique(item["id"].getInt())
  result = %*{
    "id": item["id"],
    "name": item["name"].getStr("unknownName"),
    "style": style,
    "fields": fields
  }

## Field Stuffs
proc extractStructFieldKind(field: JsonNode): JsonNode

proc extractBorrowedRef(field: JsonNode): JsonNode =
  if field["type"].hasKey("slice"):
    result = %*{
      "borrowed_ref": {
        "type": "slice",
        "kind": extractStructFieldKind(field["type"]["slice"])
      }
    }
  else:
    result = %*{
      "borrowed_ref": {
        "kind": extractStructFieldKind(field["type"])
      }
    }

proc extractTupleField(t: JsonNode): JsonNode =
  result = newJArray()
  for e in t:
    result.add extractStructFieldKind(e)

proc extractArrayField(t: JsonNode): JsonNode =
  var kind: JsonNode = newJNull()
  if t.hasKey("type"):
    kind = extractStructFieldKind(t["type"])
  result = %*{
    "array": {
      "kind": kind,
      "len": t["len"].getStr()
    }
  }

var trackedResIds: seq[int]

proc extractResolvedPathField(rp: JsonNode): JsonNode =
  var args: JsonNode = newJArray()
  
  if rp.hasKey("args"):
    if rp["args"].kind != JNull:
      if rp["args"].hasKey("angle_bracketed"):
        if rp["args"]["angle_bracketed"].hasKey("args"):
          var innerArgs = rp["args"]["angle_bracketed"]["args"]
          for arg in innerArgs:
            if arg.hasKey("type"):
              args.add extractStructFieldKind(arg["type"])

  trackedResIds.addUnique(rp["id"].getInt())

  if args.len > 0:
    result = %*{
      "id": rp["id"],
      "args": args
    }
  else:
    result = %*{
      "id": rp["id"]
    }

proc extractStructFieldKind(field: JsonNode): JsonNode =
  result = newJNull()
  if field.hasKey("primitive"):
    result = % ("primitive." & field["primitive"].getStr())
  elif field.hasKey("generic"):
    result = % ("generic." & field["generic"].getStr())
  elif field.hasKey("tuple"):
    result = extractTupleField(field["tuple"])
  elif field.hasKey("array"):
    result = extractArrayField(field["array"])
  elif field.hasKey("resolved_path"):
    result = extractResolvedPathField(field["resolved_path"])
  elif field.hasKey("borrowed_ref"):
    result = extractBorrowedRef(field["borrowed_ref"])
    
proc extractStructField(item: JsonNode): JsonNode =
  ## Extracts the actual field objects
  let inner = getObj(item, "inner")
  let field = inner.getObj("struct_field")

  result = %*{
    "id": item["id"],
    "name": item["name"].getStr("unknownName"),
    "kind": extractStructFieldKind(field)
  }


## Process RustDocUp json into a form we care about
let doc = parseFile(r"E:\Projects\RLAnalysis\Nimrrrocket\nimboxcars\local\nimboxcarsTools\boxcars.json")
let index = loadIndex(doc)

let sout = newJArray()

for _, item in index:
  case itemKind(item)
  of rsStruct:
    sout.add extractStruct(index, item)
  else:
    discard

for idx in trackedFieldIds:
  let item = index[$idx]
  case itemKind(item)
  of rsStructField: sout.add extractStructField(item)
  of rsStruct: discard
  else: discard

for idx in trackedResIds:
  if idx notin trackedFieldIds and idx notin trackedStructIds:
    echo idx

writeFile(r"E:\Projects\RLAnalysis\Nimrrrocket\nimboxcars\local\forms.json", pretty(sout))