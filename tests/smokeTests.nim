import unittest
import os
import nimboxcars

test "parse large (smoke)":
  let path = currentSourcePath().parentDir / "C83035FA11F10787A86F62987AC938C8.replay"
  let replay = parseReplay(path)

  check replay.header.hSize > 0
  check replay.header.props.len > 0
