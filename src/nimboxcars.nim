import nimboxcars/parser


when isMainModule:

  let replayPath = r"C:\Users\rober\Documents\My Games\Rocket League\TAGame\Demos\A2C1C2E14020B6A1F701D8957C8C87A7.replay"
  #let replayPath = r"C:\Users\rober\Documents\My Games\Rocket League\TAGame\Demos\C83035FA11F10787A86F62987AC938C8.replay"
  
  discard parseReplay(replayPath)