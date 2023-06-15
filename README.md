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
### Mock
Mock substitutes the GlobalToMock with a function that returns the ReturnValues array
#### Arguments
| Argument Name | Description |
| --- | --- |
| GlobalToMock: string | A path to the global being mocked as a string. <br> For instance: ```"math.random"``` |
| ReturnValues: array | An array of return values to be returned by the mocked function. <br> For instance: ```{1,2,3,4,5}``` |
| Depth: number | Optional argument that specifies what layer of the function stack to apply the mocked environment to. <br> defaults to ```2``` |
#### Returns
| Return Name | Description |
| --- | --- |
| MockedEnvironment: table | The environment that Lyrebird created with the mocked functions |
### Reset
Reset undoes any mocked environments and resets it back to the default global environment
### MockService
MockService gives developers the ability to mimic existing Roblox services to allow firing events manually with customisable data
#### Arguments
| Argument Name | Description |
| --- | --- |
| ServiceName: string | The name of the service to be mocked.<br> For instance: ```"UserInputService"``` |
| Depth: number | Optional argument that specifies what layer of the function stack to apply the mocked environment to. <br> defaults to ```2``` |
#### Returns
| Return Name | Description |
| --- | --- |
| MockedService: table | A table corresponding to the service was mocked |
