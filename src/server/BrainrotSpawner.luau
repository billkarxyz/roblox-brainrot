-- BrainrotSpawner: the conveyor belt's fresh stock.
-- Every few seconds a random brainrot (rarity-weighted, see BrainrotDefs)
-- appears at the conveyor start and walks its waypoints to the far end. If
-- nobody buys it by then it despawns. Buying is server-validated here: the
-- brainrot must still be on the conveyor, the buyer must afford it and have
-- a free slot on their base.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotDefs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotDefs"))
local BrainrotFactory = require(script.Parent:WaitForChild("BrainrotFactory"))
local Economy = require(script.Parent:WaitForChild("Economy"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))

local BrainrotSpawner = {}

local SPAWN_INTERVAL_SECONDS = 8
local WALK_SPEED_STUDS_PER_SEC = 6
local WALK_STEP_SECONDS = 0.1
local MAX_ON_CONVEYOR = 10

local conveyorFolder = nil
local onConveyor = {}
local spawnerRunning = false

local function getConveyorFolder()
	if not conveyorFolder then
		conveyorFolder = Instance.new("Folder")
		conveyorFolder.Name = "ConveyorBrainrots"
		conveyorFolder.Parent = workspace
	end
	return conveyorFolder
end

local function removeFromConveyor(model)
	for i, entry in ipairs(onConveyor) do
		if entry == model then
			table.remove(onConveyor, i)
			return
		end
	end
end

--- Walk one brainrot along the conveyor waypoints until it is bought or
--- reaches the end, where it despawns. Runs in its own task per brainrot.
local function walkConveyor(model)
	local waypoints = WorldBuilder.getConveyorWaypoints()
	local height = BrainrotFactory.getModelHeight(model)
	local groundY = 1 + height / 2

	model:PivotTo(CFrame.new(Vector3.new(waypoints[1].X, groundY, waypoints[1].Z)))

	for waypointIndex = 2, #waypoints do
		local target = Vector3.new(waypoints[waypointIndex].X, groundY, waypoints[waypointIndex].Z)
		while model.Parent and model:GetAttribute("State") == "conveyor" do
			local current = model:GetPivot().Position
			local toTarget = target - current
			local distance = toTarget.Magnitude
			if distance < 0.5 then
				break
			end
			local step = math.min(WALK_SPEED_STUDS_PER_SEC * WALK_STEP_SECONDS, distance)
			local nextPos = current + toTarget.Unit * step
			-- Face the direction of travel.
			local lookAt = CFrame.lookAt(nextPos, nextPos + Vector3.new(toTarget.X, 0, toTarget.Z))
			model:PivotTo(lookAt)
			task.wait(WALK_STEP_SECONDS)
		end
		if not model.Parent or model:GetAttribute("State") ~= "conveyor" then
			return
		end
	end

	-- Reached the far end unbought: it leaves the bazaar.
	removeFromConveyor(model)
	if model.Parent then
		model:Destroy()
	end
end

local function spawnOne()
	if #onConveyor >= MAX_ON_CONVEYOR then
		return
	end
	local def = BrainrotDefs.getRandomCharacter()
	local model = BrainrotFactory.buildBrainrot(def)
	model.Parent = getConveyorFolder()
	table.insert(onConveyor, model)
	task.spawn(walkConveyor, model)
end

--- Start the spawn loop. Safe to call once; extra calls are ignored.
function BrainrotSpawner.startSpawner()
	if spawnerRunning then
		return
	end
	spawnerRunning = true
	-- A few brainrots on the belt right away so the first player sees action.
	for _ = 1, 3 do
		local ok, err = pcall(spawnOne)
		if not ok then
			warn("Initial conveyor spawn failed: " .. tostring(err))
		end
	end
	task.spawn(function()
		while true do
			task.wait(SPAWN_INTERVAL_SECONDS)
			local ok, err = pcall(spawnOne)
			if not ok then
				warn("Conveyor spawn failed: " .. tostring(err))
			end
		end
	end)
end

--- Is this model still walking the conveyor, available to buy?
function BrainrotSpawner.isOnConveyor(model)
	return model:GetAttribute("State") == "conveyor"
end

--- Try to buy a conveyor brainrot for a player. Validates everything on the
--- server: still on the conveyor, buyer has a base with a free slot, and
--- buyer can afford it. On success the brainrot moves to the buyer's base.
function BrainrotSpawner.tryBuyBrainrot(player, model)
	if not BrainrotSpawner.isOnConveyor(model) then
		return false, "That brainrot is no longer for sale."
	end

	local def = BrainrotDefs.getCharacter(model:GetAttribute("CharacterId"))
	if not def then
		return false, "Unknown brainrot."
	end

	local plot = WorldBuilder.getPlotForPlayer(player)
	if not plot then
		return false, "You have no base yet."
	end

	local slotPosition = WorldBuilder.claimSlot(plot, model)
	if not slotPosition then
		return false, "Your base is full! Rebirth or make room."
	end

	if not Economy.trySpend(player, def.cost) then
		WorldBuilder.freeSlot(plot, model)
		return false, "Not enough cash for " .. def.name .. " ($" .. def.cost .. ")."
	end

	removeFromConveyor(model)
	model:SetAttribute("State", "owned")
	model:SetAttribute("OwnerUserId", player.UserId)
	model.Parent = workspace
	local height = BrainrotFactory.getModelHeight(model)
	model:PivotTo(CFrame.new(slotPosition + Vector3.new(0, height / 2, 0)))
	Economy.registerBrainrot(player, model, def.id)
	Economy.notify(player, "Bought " .. def.name .. " for $" .. def.cost .. "! It earns $" .. def.incomePerSec .. "/s.")
	return true, "Bought " .. def.name .. "."
end

return BrainrotSpawner
