import std/[streams]

#writeFile("network_frames.bin", result.networkData)

proc writeNetframesFile(filePath: string, netData: seq[byte]) =
  ## TODO: