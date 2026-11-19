-- EventSystem: the Durian Storm, Brainrot Bazaar's roaming hazard.
-- Every few minutes a 10-second warning banner goes out, then spiky durians
-- rain on the central bazaar for about 20 seconds. A durian that touches a
-- player knocks them back without killing them, so a thief mid-steal has to
-- dodge or drop the run. The storm is harmless to brainrots and bases.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local EventSystem = {}

local STORM_INTERVAL_SECONDS = 180
local WARNING_SECONDS = 10
local STORM_DURATION_SECONDS = 20
local DURIAN_FALL_HEIGHT = 60
local DURIAN_SPAWN_GAP_SECONDS = 0.7
local KNOCKBACK_SPEED = 45
local KNOCKBACK_UP = 25

local rng = Random.new()
local stormRunning = false
local eventLoopRunning = false

local function getRemotes()
	return ReplicatedStorage:WaitForChild("BrainrotRemotes")
end

local function broadcast(eventName, message)
	local event = getRemotes():FindFirstChild(eventName)
	if event then
		event:FireAllClients(message)
	end
end

local function dropDurian()
	local durian = Instance.new("Part")
	durian.Name = "FallingDurian"
	durian.Shape = Enum.PartType.Ball
	durian.Size = Vector3.new(2.5, 2.5, 2.5)
	durian.Position = Vector3.new(rng:NextNumber(-55, 55), DURIAN_FALL_HEIGHT, rng:NextNumber(-55, 55))
	durian.Anchored = false
	durian.CanCollide = true
	durian.BrickColor = BrickColor.new("Bright yellowish green")
	durian.Material = Enum.Material.Grass
	durian.TopSurface = Enum.SurfaceType.Smooth
	durian.Parent = workspace

	local touched = false
	durian.Touched:Connect(function(hit)
		if touched then
			return
		end
		local character = hit.Parent
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then
			touched = true
			local away = (root.Position - durian.Position)
			away = Vector3.new(away.X, 0, away.Z)
			if away.Magnitude < 0.5 then
				away = Vector3.new(0, 0, 1)
			end
			root.AssemblyLinearVelocity = away.Unit * KNOCKBACK_SPEED + Vector3.new(0, KNOCKBACK_UP, 0)
			local player = Players:GetPlayerFromCharacter(character)
			if player then
				local notifyEvent = getRemotes():FindFirstChild("Notify")
				if notifyEvent then
					notifyEvent:FireClient(player, "Bonk! A durian knocked you flying!")
				end
			end
		end
	end)

	task.delay(6, function()
		if durian.Parent then
			durian:Destroy()
		end
	end)
end

--- Run one Durian Storm now: warning banner, then falling durians. The
--- optional argument is ignored; it exists so TOUR.json can call this
--- function with the one argument a tour call carries.
function EventSystem.triggerDurianStorm(_arg)
	if stormRunning then
		return
	end
	stormRunning = true
	task.spawn(function()
		broadcast("EventWarning", "DURIAN STORM INCOMING! Take cover in 10 seconds!")
		task.wait(WARNING_SECONDS)
		broadcast("EventStart", "DURIAN STORM! Dodge the falling durians!")
		local startedAt = os.clock()
		while os.clock() - startedAt < STORM_DURATION_SECONDS do
			dropDurian()
			task.wait(DURIAN_SPAWN_GAP_SECONDS)
		end
		broadcast("EventEnd", "The storm has passed. The bazaar is safe again.")
		stormRunning = false
	end)
end

--- Start the recurring storm loop. Safe to call once; extra calls are ignored.
function EventSystem.startEventLoop()
	if eventLoopRunning then
		return
	end
	eventLoopRunning = true
	task.spawn(function()
		while true do
			task.wait(STORM_INTERVAL_SECONDS)
			local ok, err = pcall(EventSystem.triggerDurianStorm)
			if not ok then
				warn("Durian Storm failed: " .. tostring(err))
				stormRunning = false
			end
		end
	end)
end

return EventSystem
