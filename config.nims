# begin Nimble config (version 2)
--noNimblePath
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"

task docs, "builds project docs":
  exec "nim doc --project --index:on src/nimboxcars.nim"
# end Nimble config