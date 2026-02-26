import nimboxcars/model/[strings]

type
  KeyFrame* = object
    time*: float32
    frame*: int32
    position*: int32
  
  DebugInfo* = object
    frame*: int32
    user*: FString
    text*: FString

  TickMark* = object
    description*: FString
    frame*: int32

  ClassIndex* = object
    class*: FString
    index*: int32

  NetCacheProperty* = object
    objectIndex*: int32
    streamId*: int32

  NetCache* = object
    objectIndex*: int32
    parentId*: int32
    cacheId*: int32
    properties*: seq[NetCacheProperty]

