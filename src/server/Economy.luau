-- Economy: the server-authoritative money of Brainrot Bazaar.
-- Cash lives in leaderstats (an IntValue the client can only read), income is
-- summed on the server from the brainrots a player actually owns, and every
-- spend goes through trySpend, which never lets cash go below zero. The
-- client is never trusted for money: it only asks, the server decides.
-- A 1-second tick pays each player their income and pushes fresh stats.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotDefs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotDefs"))

local Economy = {}

local START_CASH = 100
local TICK_SECONDS = 1

local playerData = {}
local remotes = nil
local tickRunning = false

local function getRemotes()
	if not remotes then
		remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
	end
	return remotes
end

local function getData(player)
	return playerData[player.UserId]
end

--- Income multiplier from rebirths: each rebirth doubles all earnings.
function Economy.getMultiplier(player)
	local data = getData(player)
	if not data then
		return 1
	end
	return 2 ^ data.rebirths
end

--- Cash a player needs for their next rebirth.
function Economy.getRebirthCost(player)
	local data = getData(player)
	local rebirths = 0
	if data then
		rebirths = data.rebirths
	end
	return 10000 * (5 ^ rebirths)
end

--- Total income per second of everything a player owns, before multiplier.
function Economy.getBaseIncome(player)
	local data = getData(player)
	if not data then
		return 0
	end
	local total = 0
	for _, entry in ipairs(data.owned) do
		local def = BrainrotDefs.getCharacter(entry.characterId)
		if def then
			total += def.incomePerSec
		end
	end
	return total
end

--- Total income per second after the rebirth multiplier.
function Economy.getIncomePerSecond(player)
	return Economy.getBaseIncome(player) * Economy.getMultiplier(player)
end

--- How many brainrots a player owns.
function Economy.getOwnedCount(player)
	local data = getData(player)
	if not data then
		return 0
	end
	return #data.owned
end

--- Push fresh stats to one player's HUD.
function Economy.pushStats(player)
	local data = getData(player)
	if not data then
		return
	end
	local statsEvent = getRemotes():FindFirstChild("StatsUpdate")
	if statsEvent then
		statsEvent:FireClient(
			player,
			data.cash.Value,
			Economy.getIncomePerSecond(player),
			Economy.getMultiplier(player),
			Economy.getRebirthCost(player)
		)
	end
end

--- Send a short toast message to one player's HUD.
function Economy.notify(player, message)
	local notifyEvent = getRemotes():FindFirstChild("Notify")
	if notifyEvent then
		notifyEvent:FireClient(player, message)
	end
end

--- Set up leaderstats and an empty wallet for a joining player.
function Economy.setupPlayer(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = START_CASH
	cash.Parent = leaderstats

	playerData[player.UserId] = {
		cash = cash,
		rebirths = 0,
		owned = {},
	}
	Economy.pushStats(player)
end

--- Clean up when a player leaves: their brainrots are destroyed and their
--- plot slots are freed by the caller (WorldBuilder.releasePlot).
function Economy.removePlayer(player)
	local data = getData(player)
	if data then
		for _, entry in ipairs(data.owned) do
			if entry.model and entry.model.Parent then
				entry.model:Destroy()
			end
		end
		playerData[player.UserId] = nil
	end
end

--- Spend cash when the player can afford it; returns true on success.
function Economy.trySpend(player, amount)
	local data = getData(player)
	if not data or data.cash.Value < amount then
		return false
	end
	data.cash.Value -= amount
	Economy.pushStats(player)
	return true
end

--- Add cash (income tick, never called from the client).
function Economy.addCash(player, amount)
	local data = getData(player)
	if data then
		data.cash.Value += amount
	end
end

--- Register a brainrot model as owned by a player.
function Economy.registerBrainrot(player, model, characterId)
	local data = getData(player)
	if data then
		table.insert(data.owned, { model = model, characterId = characterId })
	end
	Economy.pushStats(player)
end

--- Remove a brainrot model from a player's owned list (sold, stolen away,
--- or destroyed). Returns the entry removed, or nil.
function Economy.unregisterBrainrot(player, model)
	local data = getData(player)
	if not data then
		return nil
	end
	for i, entry in ipairs(data.owned) do
		if entry.model == model then
			table.remove(data.owned, i)
			Economy.pushStats(player)
			return entry
		end
	end
	return nil
end

--- Destroy every brainrot a player owns and empty their list (rebirth).
function Economy.clearOwnedBrainrots(player)
	local data = getData(player)
	if not data then
		return
	end
	for _, entry in ipairs(data.owned) do
		if entry.model and entry.model.Parent then
			entry.model:Destroy()
		end
	end
	data.owned = {}
end

--- Reset a player's cash to the starting amount (rebirth).
function Economy.resetCash(player)
	local data = getData(player)
	if data then
		data.cash.Value = START_CASH
	end
end

--- Grant one rebirth level to a player.
function Economy.addRebirth(player)
	local data = getData(player)
	if data then
		data.rebirths += 1
	end
end

--- Start the 1-second income tick. Safe to call once; extra calls are ignored.
function Economy.startIncomeTick()
	if tickRunning then
		return
	end
	tickRunning = true
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			for _, player in ipairs(Players:GetPlayers()) do
				local ok, err = pcall(function()
					local income = Economy.getIncomePerSecond(player)
					if income > 0 then
						Economy.addCash(player, income)
					end
					Economy.pushStats(player)
				end)
				if not ok then
					warn("Income tick failed for " .. player.Name .. ": " .. tostring(err))
				end
			end
		end
	end)
end

return Economy
