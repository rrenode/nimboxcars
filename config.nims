# begin Nimble config (version 2)
--noNimblePath
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"

task docs, "builds local project docs":
  exec "nim doc --project --index:on bin/docs/nimboxcars.nim"
# end Nimble config