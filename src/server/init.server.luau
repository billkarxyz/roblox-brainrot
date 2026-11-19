-- init.server.luau: bootstrap for Brainrot Bazaar.
-- Creates the RemoteEvents the client talks on, builds the world, wires the
-- game systems together, and routes every brainrot click: a conveyor
-- brainrot is a buy, another player's brainrot is a steal attempt. Every
-- risky step runs inside pcall so one error never kills the server loop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- RemoteEvents live in one folder so client and server agree on the names.
local remotes = Instance.new("Folder")
remotes.Name = "BrainrotRemotes"
remotes.Parent = ReplicatedStorage

local REMOTE_NAMES = {
	"StatsUpdate", -- server -> client: cash, income/s, multiplier, rebirth cost
	"Notify", -- server -> client: toast message
	"EventWarning", -- server -> client: storm warning banner
	"EventStart", -- server -> client: storm active banner
	"EventEnd", -- server -> client: storm over banner
	"LockBase", -- client -> server: lock my base
	"RebirthRequest", -- client -> server: rebirth me
}
for _, name in ipairs(REMOTE_NAMES) do
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes
end

-- Require the systems in dependency order. A failed require is fatal to the
-- game, so it is loud: the error is warned and the script stops.
local WorldBuilder = require(script.WorldBuilder)
local BrainrotFactory = require(script.BrainrotFactory)
local Economy = require(script.Economy)
local BrainrotSpawner = require(script.BrainrotSpawner)
local StealSystem = require(script.StealSystem)
local RebirthSystem = require(script.RebirthSystem)
local EventSystem = require(script.EventSystem)

local worldOk, worldErr = pcall(WorldBuilder.buildWorld)
if not worldOk then
	warn("WorldBuilder failed: " .. tostring(worldErr))
end

--- One router for every brainrot click in the game. The brainrot's State
--- attribute decides what the click means; the server validates the rest.
local function handleBrainrotClick(player, model)
	local state = model:GetAttribute("State")
	if state == "conveyor" then
		local ok, message = BrainrotSpawner.tryBuyBrainrot(player, model)
		if not ok then
			Economy.notify(player, message)
		end
	elseif state == "owned" then
		local ownerUserId = model:GetAttribute("OwnerUserId")
		if ownerUserId == player.UserId then
			Economy.notify(player, model.Name .. " is earning for you. Nice!")
		else
			local ok, message = StealSystem.tryStealBrainrot(player, model)
			if not ok then
				Economy.notify(player, message)
			end
		end
	elseif state == "stolen" then
		Economy.notify(player, "That brainrot is mid-steal already!")
	end
end
BrainrotFactory.setClickHandler(handleBrainrotClick)

local function onPlayerAdded(player)
	local ok, err = pcall(function()
		Economy.setupPlayer(player)
		local plot = WorldBuilder.assignPlot(player)
		if plot then
			Economy.notify(player, "Welcome to Brainrot Bazaar! Your base is plot #" .. plot.index .. ".")
		else
			Economy.notify(player, "Welcome! All bases are taken right now — try again soon.")
		end
	end)
	if not ok then
		warn("Player setup failed for " .. player.Name .. ": " .. tostring(err))
	end
end

local function onPlayerRemoving(player)
	local ok, err = pcall(function()
		StealSystem.cancelStealsForPlayer(player)
		Economy.removePlayer(player)
		WorldBuilder.releasePlot(player)
	end)
	if not ok then
		warn("Player cleanup failed for " .. player.Name .. ": " .. tostring(err))
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
-- Players who joined before this script ran (Studio play solo).
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

remotes.LockBase.OnServerEvent:Connect(function(player)
	local ok, message = StealSystem.tryLockBase(player)
	if not ok then
		Economy.notify(player, message)
	end
end)

remotes.RebirthRequest.OnServerEvent:Connect(function(player)
	local ok, message = RebirthSystem.tryRebirth(player)
	if not ok then
		Economy.notify(player, message)
	end
end)

Economy.startIncomeTick()
BrainrotSpawner.startSpawner()
EventSystem.startEventLoop()

print("Brainrot Bazaar is open for business!")
