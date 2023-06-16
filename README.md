# Lyrebird
A small module to help Roblox developers test their code
## What does it do?
<p>Lyrebird is heavily based off of Python's unittest.mock functionality to allow developers to test their code in a easier manner. It achieves this by giving developers the option to overwrite global functions to return specific values to allow for testing code in a variety of circumstances</p>

## How do I use it?
Lyrebird has 3 main methods:
```lua
Lyrebird.Mock(GlobalToMock:string, ReturnValues:{any}, depth:number) : {}
Lyrebird.Reset() : nil
Lyrebird.MockService(ServiceName:string, depth:number) : {}
```

To mock a function just call the method, providing the path to the function as a string.<br>Any subsequent calls to the function being mocked will instead be made to the mock
```lua
local lyrebird = require(game.ReplicatedStorage.Lyrebird)
lyrebird.Mock("math.random", {1,2,3,4,5})
for i = 1,5 do
  print(math.random(10))
end
```

## Why the name?
Lyrebirds are a group of birds with notable abilities to mimic surrounding sounds. I thought it was fitting to name a module designed to mimic environments after them
