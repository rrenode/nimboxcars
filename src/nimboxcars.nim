import std/[parseopt, options]
import nimboxcars/parser

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
      of "j":
        if val != "":
          echo "The `-j` option is a flag!"
          quit()
        #TODO: Flag to output as JSON
        continue
      else:
        echo "Unknown command option of `", key, "`"
    of cmdEnd:
      discard
  
  if replayFilePath.isNone():
    echo "Replay file path not provided!"
    quit()

  let replay = parseReplay(replayFilePath.get())
