-- StealSystem: the tension of Brainrot Bazaar.
-- Clicking another player's brainrot starts a steal: the brainrot floats
-- above the thief and follows them home. Reaching their own base completes
-- the theft; dying, leaving, or the victim's lock stops it. Each brainrot
-- can only be stolen once every 15 seconds, and a base lock (30 seconds,
-- 60-second cooldown) blocks all steals from that base.

local Players = game:GetService("Players")

local Economy = require(script.Parent:WaitForChild("Economy"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local BrainrotFactory = require(script.Parent:WaitForChild("BrainrotFactory"))

local StealSystem = {}

local STEAL_COOLDOWN_SECONDS = 15
local LOCK_DURATION_SECONDS = 30
local LOCK_COOLDOWN_SECONDS = 60
local FOLLOW_STEP_SECONDS = 0.1
local CARRY_HEIGHT = 4

local activeSteals = {}
local lastStealAt = {}
local lockUntil = {}
local lockCooldownUntil = {}

local function getRootPart(player)
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(player)
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

--- Is a player's base currently locked against steals?
function StealSystem.isBaseLocked(player)
	local untilTime = lockUntil[player.UserId]
	return untilTime ~= nil and os.clock() < untilTime
end

--- Lock the caller's base for 30 seconds. Fails while the 60-second
--- cooldown (counted from the lock's end) is still running.
function StealSystem.tryLockBase(player)
	local now = os.clock()
	local cooldownEnds = lockCooldownUntil[player.UserId] or 0
	if now < cooldownEnds then
		local remaining = math.ceil(cooldownEnds - now)
		return false, "Base lock on cooldown: " .. remaining .. "s left."
	end
	if StealSystem.isBaseLocked(player) then
		return false, "Your base is already locked."
	end
	lockUntil[player.UserId] = now + LOCK_DURATION_SECONDS
	lockCooldownUntil[player.UserId] = now + LOCK_DURATION_SECONDS + LOCK_COOLDOWN_SECONDS
	Economy.notify(player, "Base locked for " .. LOCK_DURATION_SECONDS .. "s! No one can steal from you.")
	return true, "Base locked."
end

local function returnToOwnerPlot(steal)
	local model = steal.model
	local plot = steal.fromPlot
	if model.Parent and plot then
		local slotPosition = WorldBuilder.claimSlot(plot, model)
		if slotPosition then
			local height = BrainrotFactory.getModelHeight(model)
			model:PivotTo(CFrame.new(slotPosition + Vector3.new(0, height / 2, 0)))
		end
	end
	model:SetAttribute("State", "owned")
end

local function finishSteal(steal, completed)
	activeSteals[steal.model] = nil
	if completed then
		local thief = steal.thief
		local model = steal.model
		local thiefPlot = WorldBuilder.getPlotForPlayer(thief)
		if thiefPlot then
			local slotPosition = WorldBuilder.claimSlot(thiefPlot, model)
			if slotPosition then
				local height = BrainrotFactory.getModelHeight(model)
				model:PivotTo(CFrame.new(slotPosition + Vector3.new(0, height / 2, 0)))
				model:SetAttribute("State", "owned")
				model:SetAttribute("OwnerUserId", thief.UserId)
				Economy.registerBrainrot(thief, model, steal.characterId)
				Economy.notify(thief, "Steal complete! " .. model.Name .. " is yours now.")
				local victim = Players:GetPlayerByUserId(steal.ownerUserId)
				if victim then
					Economy.notify(victim, thief.DisplayName .. " stole your " .. model.Name .. "!")
				end
				return
			end
		end
		-- No room at the thief's base: the brainrot goes home.
		returnToOwnerPlot(steal)
		Economy.notify(thief, "Your base is full — the brainrot ran home!")
	else
		returnToOwnerPlot(steal)
	end
end

--- Follow loop: the stolen brainrot floats above the thief until they reach
--- their own base, die, or leave. Runs in its own task per steal.
local function followThief(steal)
	local thief = steal.thief
	local model = steal.model
	local thiefPlot = WorldBuilder.getPlotForPlayer(thief)

	while model.Parent and activeSteals[model] == steal do
		local root = getRootPart(thief)
		local humanoid = getHumanoid(thief)
		if not root or not humanoid or humanoid.Health <= 0 then
			finishSteal(steal, false)
			return
		end
		model:PivotTo(root.CFrame * CFrame.new(0, CARRY_HEIGHT, 0))
		if thiefPlot and WorldBuilder.isInsidePlot(thiefPlot, root.Position) then
			finishSteal(steal, true)
			return
		end
		task.wait(FOLLOW_STEP_SECONDS)
	end
end

--- Try to start stealing a brainrot a player clicked. The brainrot must be
--- owned by someone else, off cooldown, and its owner's base unlocked.
function StealSystem.tryStealBrainrot(thief, model)
	if model:GetAttribute("State") ~= "owned" then
		return false, "That brainrot cannot be stolen right now."
	end
	local ownerUserId = model:GetAttribute("OwnerUserId")
	if ownerUserId == thief.UserId then
		return false, "That brainrot is already yours."
	end
	if activeSteals[model] then
		return false, "Someone is already stealing that brainrot!"
	end

	local now = os.clock()
	local lastSteal = lastStealAt[model] or 0
	if now - lastSteal < STEAL_COOLDOWN_SECONDS then
		local remaining = math.ceil(STEAL_COOLDOWN_SECONDS - (now - lastSteal))
		return false, "That brainrot was just stolen. Try again in " .. remaining .. "s."
	end

	local victim = Players:GetPlayerByUserId(ownerUserId)
	if victim and StealSystem.isBaseLocked(victim) then
		return false, victim.DisplayName .. "'s base is locked!"
	end

	local victimPlot = nil
	if victim then
		victimPlot = WorldBuilder.getPlotForPlayer(victim)
	end
	if victimPlot then
		WorldBuilder.freeSlot(victimPlot, model)
	end
	if victim then
		Economy.unregisterBrainrot(victim, model)
	end

	lastStealAt[model] = now
	model:SetAttribute("State", "stolen")
	local steal = {
		model = model,
		thief = thief,
		ownerUserId = ownerUserId,
		fromPlot = victimPlot,
		characterId = model:GetAttribute("CharacterId"),
	}
	activeSteals[model] = steal
	Economy.notify(thief, "You grabbed " .. model.Name .. "! Run back to your base!")
	if victim then
		Economy.notify(victim, thief.DisplayName .. " is stealing your " .. model.Name .. "! Chase them!")
	end
	task.spawn(followThief, steal)
	return true, "Stealing " .. model.Name .. "!"
end

--- Cancel every steal a leaving player is part of, as thief or victim.
function StealSystem.cancelStealsForPlayer(player)
	for model, steal in pairs(activeSteals) do
		if steal.thief == player or steal.ownerUserId == player.UserId then
			activeSteals[model] = nil
			returnToOwnerPlot(steal)
		end
	end
	lockUntil[player.UserId] = nil
	lockCooldownUntil[player.UserId] = nil
end

return StealSystem
