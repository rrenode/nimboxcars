import unittest
import os
import nimboxcars

test "parse large (smoke)":
  let path = currentSourcePath().parentDir / "C83035FA11F10787A86F62987AC938C8.replay"
  let replay = parseReplay(path)

  check replay.header.hSize == 12610
  check replay.header.headerCRC == 632651673
  check replay.header.gameType == "TAGame.Replay_Soccar_TA"
  check len(replay.header.props) == 27
  check len(replay.body.keyFrames) == 52
  check len(replay.body.tickMarks) == 13
  check len(replay.body.objects) == 437
  check len(replay.body.names) == 456

  
