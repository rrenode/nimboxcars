import std/[os, osproc, strutils, json, jsonutils, sequtils, tables, macros]
type
  JsonMap = Table[string, JsonNode]

  RtcVariants = enum
    rtcUnknown, rtcStruct, rtcTuple, rtcField

proc loadIndex(doc: JsonNode): JsonMap =
  result = initTable[string, JsonNode]()
  if doc.kind != JObject: return
  for k, v in doc:
    result[k] = v



proc determineFormType(formObj: JsonNode): RtcVariants =
  result = rtcUnknown
  if formObj.hasKey("style"):
    if not formObj.hasKey("fields"):
      echo "Type without fields??? " & $formObj
      return
    # either plain or tuple
    case formObj["style"].getStr
    of "plain":
      result = rtcStruct
    of "tuple":
      result = rtcTuple 
  elif formObj.hasKey("kind"):
    result = rtcField

type
  RsStructField* = object
    name*: string
    kind*: string

proc resolveFieldKind(field: JsonNode, index: JsonMap): string =
  ##
  ## Can be:
  ##  vv ARRAY vv
  ##```json
  ##  "kind": {
  ##    "array": {
  ##      "kind": {
  ##        "id": 825
  ##      },
  ##      "len": "3"
  ##    }
  ##  }
  ## ```
  ## 
  ##  vv Vector vv
  ## ```json
  ## "kind": {
  ##    "id": 32,
  ##    "path": "Vec",
  ##    "args": [
  ##      {
  ##        "id": 436
  ##      }
  ##    ]
  ##  }
  ## ```
  ## 
  ##  vv Option vv
  ## ```json
  ## "kind": {
  ##    "id": 6,
  ##    "path": "Option",
  ##    "args": [
  ##      {
  ##        "id": 422
  ##      }
  ##    ]
  ##  }
  ## ```
  ## 
  ##  vv Direct vv 
  ##```json
  ## "kind": {
  ##    "id": 214
  ##  }
  ##```
  ##
  ##  vv Primitive vv
  ## u, i, f -> 8, 16, 32, 64
  ## bool, usize
  if field.hasKey("kind"):
    case field["kind"].kind
    of JObject:
      if field["kind"].hasKey("id"):
        return index[$field["kind"]["id"].getInt]["name"].getStr
    of JArray:
      discard
    else:
      return field["kind"].getStr
  else:
    return "unknown"

proc resolveField(idx: int, index: JsonMap): RsStructField =
  let field = index[$idx]
  result.name = field["name"].getStr
  result.kind = resolveFieldKind(field, index)

proc expandFields(fields: JsonNode, index: JsonMap): seq[RsStructField] =
  for fieldIdx in fields:
    result.add(
      resolveField(parseInt(fieldIdx.getStr), index)
    )

proc processStruct(formObj: JsonNode, index: JsonMap): NimNode {.compileTime.}=
  let structName: string = formObj["name"].getStr
  let jFields: JsonNode = formObj["fields"]
  var fields: seq[RsStructField] = expandFields(jFields, index)
  echo fields
  quote do:
    type
      `structName`* = object


let docJStr = readFile(r"E:\Projects\RLAnalysis\Nimrrrocket\nimboxcars\local\forms.json")
let jdoc = docJStr.parseJson

var index = loadIndex(jdoc)

# only working with the first object ("816")

let id = "816"

var ob = index["816"]

case ob.determineFormType
of rtcStruct:
  discard
of rtcTuple:
  discard
of rtcField:
  discard
else:
  echo "Oh fuck ->" & $ob



discard processStruct(ob, index)