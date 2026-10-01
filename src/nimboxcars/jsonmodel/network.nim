## Rust/rrrocket-compatible JSON representation of decoded network values.
import std/[json, strutils]
import nimboxcars/model/network

proc snake(name: string): string =
  for i, c in name:
    if c in {'A'..'Z'}:
      if i > 0: result.add '_'
      result.add c.toLowerAscii
    else: result.add c

proc networkJson*[T](value: T): JsonNode =
  when T is Option:
    if value.isSome: result = networkJson(value.get)
    else: result = newJNull()
  elif T is ref:
    if value.isNil: result = newJNull()
    else: result = networkJson(value[])
  elif T is ActorId or T is ObjectId or T is StreamId:
    result = %int32(value)
  elif T is uint64 or T is int64:
    result = %($value)
  elif T is seq or T is array:
    result = newJArray()
    for v in value: result.add networkJson(v)
  elif T is tuple:
    result = newJArray()
    for field in fields(value): result.add networkJson(field)
  elif T is object:
    when T is Attribute or T is RemoteId or T is ProductValue:
      result = %($value.kind)
      for name, field in fieldPairs(value):
        when name != "kind":
          result = newJObject()
          result[$value.kind] = networkJson(field)
    else:
      result = newJObject()
      for name, field in fieldPairs(value): result[snake(name)] = networkJson(field)
  else:
    result = %value
