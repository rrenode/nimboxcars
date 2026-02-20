import nimboxcars/parser
import std/[parseopt, options]

when isMainModule:

  var replayFilePath: Option[string] = none(string)

  for kind, key, val in getopt():
    case kind:
    of cmdArgument:
      replayFilePath = some(key)
    of cmdLongOption, cmdShortOption:
      case key:
      of "v", "verbose":
        #TODO: Add verbose logging
        continue
      else:
        echo "Unknown command option of `", key, "`"
    of cmdEnd:
      discard
  
  if replayFilePath.isNone():
    echo "Replay file path not provided!"
    quit()

  let replay = parseReplay(replayFilePath.get())
  echo replay