# Package

version       = "0.2.3"
author        = "rrenode"
description   = "An RL Replay parsing lib written in Nim."
license       = "MIT"
srcDir        = "src"
bin = @["nimboxcars"]


# Dependencies

requires "nim >= 2.2.6"

requires "json_serialization >= 0.4.4"

task build, "Builds debug version of nimboxcars":
    echo "Build debug..."
    exec "nim c --out:bin/debug/nimboxcars.exe src/nimboxcars.nim"