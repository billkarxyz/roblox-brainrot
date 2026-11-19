-- WorldBuilder: builds the whole 3D world of Brainrot Bazaar at server start.
-- There is no Studio on the build machine, so every part of the map is made
-- here from Parts: the green baseplate, the spawn pad, the central conveyor
-- belt, eight fenced player base plots with eight slots each, and decorations
-- (trees, lamps, market stalls). It also owns plot assignment and slot use.

local WorldBuilder = {}

local PLOT_CENTERS = {
	Vector3.new(-70, 0, -70),
	Vector3.new(70, 0, -70),
	Vector3.new(-70, 0, 70),
	Vector3.new(70, 0, 70),
	Vector3.new(-78, 0, -35),
	Vector3.new(78, 0, -35),
	Vector3.new(-78, 0, 35),
	Vector3.new(78, 0, 35),
}

local PLOT_FLOOR_COLORS = {
	"Bright blue",
	"Bright red",
	"Bright yellow",
	"Bright violet",
	"Bright bluish green",
	"Bright orange",
	"Hot pink",
	"Lime green",
}

local CONVEYOR_START = Vector3.new(-78, 0, 0)
local CONVEYOR_END = Vector3.new(78, 0, 0)

local worldFolder = nil
local plots = {}
local playerPlots = {}

local function newPart(name, size, position, colorName, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.CanCollide = true
	part.BrickColor = BrickColor.new(colorName)
	part.Material = material or Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function buildBaseplate()
	local plate = newPart("Baseplate", Vector3.new(200, 2, 200), Vector3.new(0, -1, 0), "Bright green", Enum.Material.Grass)
	plate.Parent = worldFolder

	-- Low stone border so players can see the edge of the bazaar.
	local borderColor = "Medium stone grey"
	local walls = {
		{ Vector3.new(200, 3, 2), Vector3.new(0, 1.5, -100) },
		{ Vector3.new(200, 3, 2), Vector3.new(0, 1.5, 100) },
		{ Vector3.new(2, 3, 200), Vector3.new(-100, 1.5, 0) },
		{ Vector3.new(2, 3, 200), Vector3.new(100, 1.5, 0) },
	}
	for i, wall in ipairs(walls) do
		local part = newPart("BorderWall" .. i, wall[1], wall[2], borderColor, Enum.Material.Concrete)
		part.Parent = worldFolder
	end
end

local function buildSpawnPad()
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnPad"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.5, 45)
	spawn.Anchored = true
	spawn.BrickColor = BrickColor.new("Bright blue")
	spawn.Material = Enum.Material.Neon
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = worldFolder

	-- The welcome sign stands between the spawn pad and the bazaar, its
	-- Front face turned toward arriving players.
	local sign = newPart("SpawnSign", Vector3.new(8, 3, 0.5), Vector3.new(0, 6, 39), "Institutional white")
	sign.CFrame = CFrame.lookAt(Vector3.new(0, 6, 39), Vector3.new(0, 6, 45))
	sign.Parent = worldFolder
	local post = newPart("SpawnSignPost", Vector3.new(0.6, 4, 0.6), Vector3.new(0, 2.5, 39), "Brown")
	post.Parent = worldFolder

	local label = Instance.new("SurfaceGui")
	label.Name = "WelcomeLabel"
	label.Face = Enum.NormalId.Front
	label.Parent = sign
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Text = "BRAINROT BAZAAR"
	text.TextColor3 = Color3.fromRGB(30, 30, 30)
	text.TextScaled = true
	text.Font = Enum.Font.FredokaOne
	text.Parent = label
end

local function buildConveyor()
	local belt = newPart("ConveyorBelt", Vector3.new(164, 1, 8), Vector3.new(0, 0.5, 0), "Dark stone grey", Enum.Material.Concrete)
	belt.Parent = worldFolder

	-- Yellow chevron stripes along the belt so its direction reads at a glance.
	for x = -76, 76, 8 do
		local stripe = newPart("BeltStripe", Vector3.new(2, 0.15, 6), Vector3.new(x, 1.05, 0), "Bright yellow", Enum.Material.Neon)
		stripe.CanCollide = false
		stripe.Parent = worldFolder
	end

	local startPad = newPart("ConveyorStart", Vector3.new(6, 1.2, 10), Vector3.new(-82, 0.6, 0), "Bright green", Enum.Material.Neon)
	startPad.Parent = worldFolder
	local endPad = newPart("ConveyorEnd", Vector3.new(6, 1.2, 10), Vector3.new(82, 0.6, 0), "Bright red", Enum.Material.Neon)
	endPad.Parent = worldFolder
end

local function buildPlot(index, center)
	local plot = {
		index = index,
		center = center,
		owner = nil,
		slots = {},
		signLabel = nil,
	}

	local floorColor = PLOT_FLOOR_COLORS[index]
	local floor = newPart("PlotFloor" .. index, Vector3.new(20, 1, 20), center + Vector3.new(0, 0.5, 0), floorColor, Enum.Material.Concrete)
	floor.Parent = worldFolder

	-- Low fence on three sides; the side facing the middle stays open.
	local fenceColor = "Institutional white"
	local fences = {
		{ Vector3.new(20, 2, 0.6), center + Vector3.new(0, 2, -10) },
		{ Vector3.new(20, 2, 0.6), center + Vector3.new(0, 2, 10) },
		{ Vector3.new(0.6, 2, 20), center + Vector3.new(-10 * math.sign(center.X), 2, 0) },
	}
	for i, fence in ipairs(fences) do
		local part = newPart("PlotFence" .. index .. "_" .. i, fence[1], fence[2], fenceColor)
		part.Parent = worldFolder
	end

	-- Eight slots in two rows of four where owned brainrots stand.
	for row = 0, 1 do
		for col = 0, 3 do
			local slotPos = center + Vector3.new(-6 + col * 4, 1, -3 + row * 6)
			local pad = newPart("SlotPad" .. index .. "_" .. (row * 4 + col + 1), Vector3.new(3, 0.2, 3), slotPos, "Light stone grey", Enum.Material.Neon)
			pad.CanCollide = false
			pad.Parent = worldFolder
			table.insert(plot.slots, { position = slotPos + Vector3.new(0, 0.2, 0), model = nil })
		end
	end

	-- Owner sign on a post at the plot's inner corner.
	local signPos = center + Vector3.new(-8 * math.sign(center.X), 0, -8 * math.sign(center.Z))
	local post = newPart("PlotSignPost" .. index, Vector3.new(0.6, 5, 0.6), signPos + Vector3.new(0, 2.5, 0), "Brown")
	post.Parent = worldFolder
	local board = newPart("PlotSign" .. index, Vector3.new(6, 2.5, 0.5), signPos + Vector3.new(0, 6, 0), "Institutional white")
	-- Turn the sign's Front face toward the middle of the bazaar so every
	-- player walking past can read whose base this is.
	board.CFrame = CFrame.lookAt(signPos + Vector3.new(0, 6, 0), Vector3.new(0, 6, 0))
	board.Parent = worldFolder

	local gui = Instance.new("SurfaceGui")
	gui.Name = "OwnerLabel"
	gui.Face = Enum.NormalId.Front
	gui.Parent = board
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Text = "EMPTY PLOT"
	text.TextColor3 = Color3.fromRGB(40, 40, 40)
	text.TextScaled = true
	text.Font = Enum.Font.FredokaOne
	text.Parent = gui
	plot.signLabel = text

	return plot
end

local function buildTree(position, leafColor)
	local trunk = newPart("TreeTrunk", Vector3.new(1.5, 6, 1.5), position + Vector3.new(0, 3, 0), "Brown", Enum.Material.Wood)
	trunk.Parent = worldFolder
	local leaves = Instance.new("Part")
	leaves.Name = "TreeLeaves"
	leaves.Shape = Enum.PartType.Ball
	leaves.Size = Vector3.new(7, 7, 7)
	leaves.Position = position + Vector3.new(0, 8, 0)
	leaves.Anchored = true
	leaves.BrickColor = BrickColor.new(leafColor)
	leaves.Material = Enum.Material.Grass
	leaves.TopSurface = Enum.SurfaceType.Smooth
	leaves.Parent = worldFolder
end

local function buildLamp(position)
	local pole = newPart("LampPole", Vector3.new(0.6, 7, 0.6), position + Vector3.new(0, 3.5, 0), "Dark stone grey", Enum.Material.Metal)
	pole.Parent = worldFolder
	local head = newPart("LampHead", Vector3.new(2, 1, 2), position + Vector3.new(0, 7.5, 0), "Bright yellow", Enum.Material.Neon)
	head.Parent = worldFolder
end

local function buildStall(position, roofColor)
	local counter = newPart("StallCounter", Vector3.new(6, 2.5, 3), position + Vector3.new(0, 1.25, 0), "Reddish brown", Enum.Material.Wood)
	counter.Parent = worldFolder
	for _, dx in ipairs({ -2.6, 2.6 }) do
		local post = newPart("StallPost", Vector3.new(0.5, 4, 0.5), position + Vector3.new(dx, 4, 0), "Brown", Enum.Material.Wood)
		post.Parent = worldFolder
	end
	local roof = newPart("StallRoof", Vector3.new(7, 0.4, 4.5), position + Vector3.new(0, 6.2, 0), roofColor)
	roof.Parent = worldFolder
end

local function buildDecorations()
	local treeSpots = {
		{ Vector3.new(-45, 0, -45), "Bright green" },
		{ Vector3.new(45, 0, -45), "Bright green" },
		{ Vector3.new(-45, 0, 45), "Bright green" },
		{ Vector3.new(45, 0, 45), "Dark green" },
		{ Vector3.new(-20, 0, -60), "Dark green" },
		{ Vector3.new(20, 0, -60), "Bright green" },
		{ Vector3.new(-20, 0, 60), "Bright green" },
		{ Vector3.new(20, 0, 60), "Dark green" },
		{ Vector3.new(-90, 0, 0), "Bright green" },
		{ Vector3.new(90, 0, 0), "Dark green" },
		{ Vector3.new(0, 0, -85), "Bright green" },
		{ Vector3.new(0, 0, 85), "Dark green" },
	}
	for _, spot in ipairs(treeSpots) do
		buildTree(spot[1], spot[2])
	end

	local lampSpots = {
		Vector3.new(-30, 0, -8),
		Vector3.new(30, 0, -8),
		Vector3.new(-30, 0, 8),
		Vector3.new(30, 0, 8),
		Vector3.new(-8, 0, 38),
		Vector3.new(8, 0, 38),
	}
	for _, spot in ipairs(lampSpots) do
		buildLamp(spot)
	end

	buildStall(Vector3.new(-25, 0, -25), "Bright red")
	buildStall(Vector3.new(25, 0, -25), "Bright blue")
	buildStall(Vector3.new(0, 0, -55), "Bright yellow")
end

--- Build the whole world once at server start. Safe to call a single time.
function WorldBuilder.buildWorld()
	if worldFolder then
		return plots
	end
	worldFolder = Instance.new("Folder")
	worldFolder.Name = "World"
	worldFolder.Parent = workspace

	buildBaseplate()
	buildSpawnPad()
	buildConveyor()
	for index, center in ipairs(PLOT_CENTERS) do
		plots[index] = buildPlot(index, center)
	end
	buildDecorations()

	return plots
end

--- The conveyor path a fresh brainrot walks, start to end.
function WorldBuilder.getConveyorWaypoints()
	return { CONVEYOR_START, Vector3.new(0, 0, 0), CONVEYOR_END }
end

--- Give a joining player the first free plot, or nil when all are taken.
function WorldBuilder.assignPlot(player)
	for _, plot in ipairs(plots) do
		if plot.owner == nil then
			plot.owner = player
			playerPlots[player.UserId] = plot
			plot.signLabel.Text = player.DisplayName .. "'s BASE"
			return plot
		end
	end
	return nil
end

--- The plot a player owns, or nil.
function WorldBuilder.getPlotForPlayer(player)
	return playerPlots[player.UserId]
end

--- Free a player's plot when they leave; their brainrots are cleared by Economy.
function WorldBuilder.releasePlot(player)
	local plot = playerPlots[player.UserId]
	if plot then
		plot.owner = nil
		plot.signLabel.Text = "EMPTY PLOT"
		for _, slot in ipairs(plot.slots) do
			slot.model = nil
		end
		playerPlots[player.UserId] = nil
	end
end

--- Claim the first free slot of a plot for a brainrot model, returning its
--- stand position, or nil when the plot is full.
function WorldBuilder.claimSlot(plot, model)
	for _, slot in ipairs(plot.slots) do
		if slot.model == nil then
			slot.model = model
			return slot.position
		end
	end
	return nil
end

--- Free the slot a brainrot model occupies, if any.
function WorldBuilder.freeSlot(plot, model)
	for _, slot in ipairs(plot.slots) do
		if slot.model == model then
			slot.model = nil
			return
		end
	end
end

--- Is a world position inside a plot's floor (used to finish a steal)?
function WorldBuilder.isInsidePlot(plot, position)
	local half = 10
	return math.abs(position.X - plot.center.X) <= half and math.abs(position.Z - plot.center.Z) <= half
end

return WorldBuilder
