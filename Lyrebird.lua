local m = {}
--Lyrebird v1.0
--This module is designed to facilitate testing by allowing fine control over mocking various events to emulate live gameplay
--Dependencies
local RS = game:GetService("RunService")
--Type declarations
export type MockedService = {PatchEvent:(MockedService,string)->nil, PatchFunction:(MockedService,string)->nil, [string]:BindableEvent}
--Config vars 

--Global vars
local GlobalEnv = getfenv(0) --Stores the fenv before we call any mock methods so we can reset it if needed
--This module is only meant to be run from studio
if not RS:IsStudio() then error("This module can only be run from studio!") return {} end
--Internal functions
function CreateFenv(functionToPatch:string, returnValues:{any})
	--Parse the functionToPatch, separating by "."
	local path = string.split(functionToPatch, ".")
	--Prepare the global fenv table
	local fenv = {_Mock = true}
	--Declare the pointers to the tree we're duplicating
	local CurrentNode = fenv --This is pointing to the node we're creating
	local CurrentEnv = getfenv(0) --This is pointing to the node we're looking at
	--Loop through path, setting up a metatable for each item in that array
	for i = 1, #path do
		local BreakLoop = false 
		local CurrentKey = path[i]
		local MetatableToAdd = {}
		--Check if the CurrentKey is in CurrentEnv
		if CurrentEnv[CurrentKey] ~= nil then
			--print(CurrentEnv, CurrentKey, CurrentEnv[CurrentKey], typeof(CurrentEnv[CurrentKey]))
			if type(CurrentEnv[CurrentKey]) == "table" or type(CurrentEnv[CurrentKey]) == "userdata" then
				if i ~= #path then
					--If the CurrentEnv[CurrentKey] is a table then we create a new table with a metatable in CurrentNode with CurrentKey
					CurrentNode[CurrentKey] = setmetatable({},{__index = function(self,key)
						return CurrentEnv[key]
					end,})
					--Set the metatable's index to CurrentEnv[CurrentKey]
					MetatableToAdd.__index = CurrentEnv--function(self, key) print(key) return CurrentEnv[key] end
				else --if this is the last path element then we treat it like a constant
					local CurrentReturnValue = 0
					rawset(CurrentEnv, CurrentKey, function(...)
						if CurrentReturnValue < #returnValues then
							CurrentReturnValue += 1
						end
						--If our CurrentReturnValue is callable, call it when returning
						local CallReturnValue = false
						--Check if the CurrentReturnValue is a table
						if type(returnValues[CurrentReturnValue]) == "table" then
							--Then check if it has a metatable attached to it
							local mt = getmetatable(returnValues[CurrentReturnValue])
							if mt ~= nil and mt.__call ~= nil then
								CallReturnValue = true
							end
						elseif type(returnValues[CurrentReturnValue]) == "function" then
							CallReturnValue = true
						end
						--If the current return value is a function call it instead of returning it wholesale
						if CallReturnValue then
							return CurrentReturnValue[CurrentReturnValue](...)
						else
							return returnValues[CurrentReturnValue]
						end
					end)
					
				end
			elseif type(CurrentEnv[CurrentKey]) == "function" then
				--If the CurrentEnv[CurrentKey] is a function then we replace it with our returnFunction
				local CurrentReturnIndex = 0
				local UseMetatable = false
				--If the returnValues has only 1 element, returnValue[1] is a table, has a metatable, has the __call metamethod defined then we just slot in the given metatable to CurrentNode[CurrentKey]
				---ie UseMetatable is toggled to true
				if #returnValues == 1 and type(returnValues[1]) == "table" then
					local tableMetatable = getmetatable(returnValues[1])
					if tableMetatable ~= nil and tableMetatable.__call ~= nil then UseMetatable = true end
				end
				if UseMetatable then
					CurrentNode[CurrentKey] = returnValues[1]
				else --If not we just use a function styled like an iterator that traverses returnValue
					CurrentNode[CurrentKey] = function(...)
						if CurrentReturnIndex < #returnValues then
							CurrentReturnIndex += 1
						end
						--If our return value is a function or a table that has a __call metamethod, return what the function returns
						local CallReturn = false
						if type(returnValues[CurrentReturnIndex]) == "table" then
							local mt = getmetatable(returnValues[CurrentReturnIndex])
							if mt ~= nil and mt.__call ~= nil then CallReturn = true end
						elseif type(returnValues[CurrentReturnIndex]) == "function" then CallReturn = true end
						if CallReturn then
							return returnValues[CurrentReturnIndex](...)
						else
							return returnValues[CurrentReturnIndex]
						end
					end
				end
				--Set the metatable's index to CurrentEnv[CurrentKey]
				MetatableToAdd.__index = function(self, key) return CurrentEnv[key] end
				--Break the loop
				BreakLoop = true
			else
				--If its a constant then um hm
				---Set the __index of MetatableToAdd to use a modified version of the returnFunction
				local CurrentReturnIndex = 0
				MetatableToAdd.__index = function(self, key)
					if key == CurrentKey then
						if CurrentReturnIndex < #returnValues then
							CurrentReturnIndex += 1
						end
						return returnValues[CurrentReturnIndex]
					end
					--Otherwise just return the key in CurrentEnv
					return CurrentEnv[key]
				end
				--Break the loop
				BreakLoop = true
			end
		else
			--If the key doesn't exist um.. I guess raise an error?
			error(`Unable to find {CurrentKey} in the environment`)
		end
		--Attach the metatable to currentNode
		CurrentNode = setmetatable(CurrentNode, MetatableToAdd)
		if BreakLoop then break end
		--Then set CurrentNode and CurrentEnv to CurrentNode[CurrentKey] and CurrentEnv[CurrentKey] respectively
		CurrentNode = CurrentNode[CurrentKey]
		CurrentEnv = CurrentEnv[CurrentKey]
	end
	--Return the new environment to set to fenv or manipulate
	return fenv
end

function AddToFenv(functionToPatch:string, returnValues:{any}, depth:number|nil)
	--Decode the functionToPatch
	local path = string.split(functionToPatch, ".")
	--Fetch the current environment
	local CurrentEnv = getfenv(depth or 2)
	local GlobalEnv = GlobalEnv
	--Declare the function that returns our values
	local CurrentReturnValue = 0
	local returnFunction = function(...)
		if CurrentReturnValue < #returnValues then
			CurrentReturnValue += 1
		end
		--If our CurrentReturnValue is callable, call it when returning
		local CallReturnValue = false
		--Check if the CurrentReturnValue is a table
		if type(returnValues[CurrentReturnValue]) == "table" then
			--Then check if it has a metatable attached to it
			local mt = getmetatable(returnValues[CurrentReturnValue])
			if mt ~= nil and mt.__call ~= nil then
				CallReturnValue = true
			end
		elseif type(returnValues[CurrentReturnValue]) == "function" then
			CallReturnValue = true
		end
		--If the current return value is a function call it instead of returning it wholesale
		if CallReturnValue then
			return CurrentReturnValue[CurrentReturnValue](...)
		else
			return returnValues[CurrentReturnValue]
		end
	end
	--Loop through path and check if path[i] exists in CurrentEnv, if not add it and if so continue
	---Really its roughly the same as CreateFenv
	for i = 1, #path do
		local CurrentPath = path[i]
		local PathAtCurrentEnv =  rawget(CurrentEnv, CurrentPath)
		--print(CurrentEnv, CurrentPath)
		if PathAtCurrentEnv~= nil then 
			CurrentEnv = CurrentEnv[CurrentPath] 
			--Since if the key exists in CurrentEnv its mocking something in GlobalEnv so we can implicitly set it
			GlobalEnv = GlobalEnv[CurrentPath]
			continue end
		--If the CurrentPath doesn't exist in CurrentEnv then we check what the type of it is
		--print(GlobalEnv, CurrentEnv)
		if typeof(GlobalEnv[CurrentPath]) == "table" or type(GlobalEnv[CurrentPath]) == "userdata" then
			--print("t")
			if i ~= #path then
				--Create a table to mock the environment we're replicating
				---Essentially just copying the code we wrote for CreateFenv
				local PatchMetatable = {__index = function(self, key) if rawget(self, key) == nil then return GlobalEnv[key] else return self[key] end end}
				rawset(CurrentEnv, CurrentPath, setmetatable({},PatchMetatable))
				--And then continue traversing the tree
				GlobalEnv = GlobalEnv[CurrentPath]
				CurrentEnv = rawget(CurrentEnv, CurrentPath)
			else	--If we're at the last item in the path then we treat the item like a constant
				--If we have multiple items in returnValues then we use the returnFunction, otherwise we just patch in the singular item
				if #returnValues > 1 then
					rawset(CurrentEnv, CurrentPath, returnFunction)
				elseif #returnValues == 1 then
					rawset(CurrentEnv, CurrentPath, returnValues[1])
				end
			end
		elseif typeof(GlobalEnv[CurrentPath]) == "function" then
			--print("f")
			rawset(CurrentEnv, CurrentPath, returnFunction)
		else
			--print("c")
			--Uhh I guess it's a constant?
			if #returnValues == 1 then
				--If there's only one item in returnValues we can simply just set the CurrentPath to the returnValue
				rawset(CurrentEnv, CurrentPath, returnValues[1])
			else
				warn("Trying to patch a constant with multiple return values isn't supported yet")
				--print(CurrentEnv, getmetatable(CurrentEnv))
				---If it's a constant we setup a metatable to invoke the returnFunction
				----Which is easier said than done considering I wrote my __index to be a function so um hmm
			end
		end
	end
end
--Instance methods
function m.Mock(functionToPatch:string, returnValues:{any}, depth:nil|number)
	if type(functionToPatch)  ~= "string" then error("Must provide the path as a strting") return end
	depth = depth or 2
	--If a patch is already active, just add the new function we want to patch over
	if getfenv(depth)._Mock ~= nil then
		AddToFenv(functionToPatch, returnValues, depth+1)
	else
		--Otherwise create a new fenv and set it
		local fenv = CreateFenv(functionToPatch, returnValues)
		setfenv(depth, fenv)
		return fenv
	end
end

function m.Reset(depth:nil|number) --Resets the environment back to the global environment (or whatever the environment was when this module was first initialised)
	setfenv(depth or 2, GlobalEnv)
end

local MockServiceMethods = {}
MockServiceMethods.PatchEvent = function(self, EventName)
	if typeof(self[EventName]) ~= "RBXScriptSignal" then error(`{EventName} is not an event`) return end
	self[EventName] = true
	print(`Patched {EventName}`)
end
MockServiceMethods.PatchFunction = function(self, NameOfFunction,Func)
	if self[NameOfFunction] == nil then error(`{NameOfFunction} is not a function that can be patched`) return end
	if type(Func) ~= "function" then error(`Must provide a function to patch {NameOfFunction}`) return end
	self[NameOfFunction] = Func
	print(`Patched {NameOfFunction}`)
end

function m.MockService(ServiceName:string, depth:number|nil):MockedService --This function mocks a service by mockking GetService to return a custom table if it matches ServiceName
	depth = depth or 2
	---We need to grab the original method too
	local UnpatchedGetService = GlobalEnv.game.GetService
	--And grab the service we're patching
	local UnpatchedService = UnpatchedGetService(GlobalEnv.game, ServiceName)
	local PatchedService = {}
	--This is what's returned so as to give an interface to modify values
	local PatchInterface = setmetatable({},{
		__index = function(self,key)
			--If we try to index an event we declared here then return that
			if rawget(PatchedService, `_{key}_`) ~= nil then return rawget(PatchedService,`_{key}_`) end
			--Or if we try to invoke a method in MockServiceMethods
			if rawget(MockServiceMethods, key) ~= nil then return rawget(MockServiceMethods,key) end
			--Otherwise just return whats in PatchedService
			return PatchedService[key]
		end,
		__newindex = function(self, key, value)
			if not pcall(function()
					--Check the type of what we're trying to patch over
					if typeof(UnpatchedService[key]) == "RBXScriptSignal" then
						if typeof(value) == "Instance" then print(value) value:Destroy() value = nil end
						rawset(PatchedService,`_{key}_`, Instance.new("BindableEvent"))
						PatchedService[`_{key}_`].Name = key
					--If we're trying to patch over a function we have to feed it a function instead of any value
					elseif typeof(UnpatchedService[key] == "function") then
						if typeof(value) ~= "function" then error(`{tostring(value)} must be a function`) return end
						rawset(PatchedService, key, value)
					--Otherwise if its a constant then we just patch it over with anything without too much issue	
					else
						rawset(PatchedService, key, value)
				end
			end) then error(`{key} is not a valid member of service {ServiceName}`) return end
		end,
	})
	local PatchedServiceMetatable = {
		__index = function(self, key) if rawget(self,`_{key}_`) ~= nil then return rawget(self,`_{key}_`).Event else return UnpatchedService[key] end end
	}
	if getfenv(depth or 2)._Mock == nil then
		--Start by mocking GetService with a custom accessor
		local MockedService =  setmetatable(PatchedService,PatchedServiceMetatable)
		local GetServiceMock = setmetatable({
			--Then insert the metatable into GetService
			[ServiceName] = MockedService,
		},
		{__call = function(self, ...)
			local args = {...}
			if rawget(self,args[2]) ~= nil then
				--print(`Mocking {args[2]}`)
				return rawget(self,args[2])
			else
				--print("Fetching original")
				return UnpatchedGetService(GlobalEnv.game, args[2])
			end
		end,})

		m.Mock("game.GetService", {GetServiceMock}, depth::number + 1) --Since we're going one more level down in the stack we add 1 to our current depth
		--Then also add it to game directly since we can also do stuff like game.Players
		m.Mock("game."..ServiceName, {MockedService}, depth::number + 1)
	else
		--If the fenv(2) is already patched we just add another service to it
		local CurrentEnv = getfenv(depth::number)
		--If somehow these are nil then uhhhhhhhhh
		if CurrentEnv.game == nil or CurrentEnv.game.GetService == nil then return PatchInterface end
		--Check if the service is already patched
		if rawget(CurrentEnv.game.GetService, ServiceName) ~= nil then error(`{ServiceName} has already been patched!`) return PatchInterface end
		--Insert the PatchedService 
		local MockedService = setmetatable(PatchedService, PatchedServiceMetatable)
		rawset(CurrentEnv.game.GetService, ServiceName,MockedService)
		--Then also add it to game directly since we can also do stuff like game.Players
		m.Mock("game."..ServiceName, {MockedService}, depth::number + 1)
	end
	--Return an interface we can use to populate PatchedService
	return PatchInterface
end

return m
