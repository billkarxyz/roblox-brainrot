-- BrainrotFactory: builds a brainrot character as a 3D Model made of Parts.
-- Each character def carries a shape tag ("round", "tall", "wide", "spiky",
-- "winged", "hat") that picks its silhouette, and every model gets a
-- BillboardGui label (name, rarity in its color, income per second) and a
-- ClickDetector the server's click router answers. Clicks are routed through
-- a handler the bootstrap sets, so the factory never decides game rules.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotDefs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotDefs"))

local BrainrotFactory = {}

local clickHandler = nil

--- The bootstrap registers one function(player, model) that answers clicks.
function BrainrotFactory.setClickHandler(handler)
	clickHandler = handler
end

local function addPart(model, name, size, offset, colorName, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(offset)
	part.Anchored = true
	part.CanCollide = true
	part.BrickColor = BrickColor.new(colorName)
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	part.Parent = model
	return part
end

local function addEyes(model, headCenter, headWidth, scale)
	for _, side in ipairs({ -1, 1 }) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.35 * scale, 0.35 * scale, 0.35 * scale)
		eye.CFrame = CFrame.new(headCenter + Vector3.new(side * headWidth * 0.22, 0.15 * scale, headWidth * 0.55))
		eye.Anchored = true
		eye.CanCollide = false
		eye.BrickColor = BrickColor.new("Really black")
		eye.Material = Enum.Material.SmoothPlastic
		eye.Parent = model
	end
end

local function addShapeExtras(model, def, scale)
	local shape = def.shape
	local bodyTop = 1.1 * scale
	if shape == "spiky" then
		-- Durian-style spikes: small wedges fanning off the body.
		for i = 1, 6 do
			local angle = (i - 1) * (math.pi / 3)
			local spike = Instance.new("WedgePart")
			spike.Name = "Spike" .. i
			spike.Size = Vector3.new(0.7 * scale, 0.7 * scale, 0.7 * scale)
			spike.CFrame = CFrame.new(Vector3.new(math.cos(angle) * 1.1 * scale, bodyTop + 0.4 * scale, math.sin(angle) * 1.1 * scale))
				* CFrame.Angles(0, -angle, math.rad(45))
			spike.Anchored = true
			spike.BrickColor = BrickColor.new("Bright yellowish green")
			spike.Material = Enum.Material.SmoothPlastic
			spike.Parent = model
		end
	elseif shape == "winged" then
		for _, side in ipairs({ -1, 1 }) do
			local wing = addPart(model, "Wing", Vector3.new(1.6 * scale, 0.2 * scale, 1.2 * scale), Vector3.new(side * 1.7 * scale, bodyTop, 0), "Institutional white")
			wing.CFrame = CFrame.new(Vector3.new(side * 1.7 * scale, bodyTop, 0)) * CFrame.Angles(0, 0, math.rad(side * -25))
		end
	elseif shape == "hat" then
		local brim = addPart(model, "HatBrim", Vector3.new(2.6 * scale, 0.25 * scale, 2.6 * scale), Vector3.new(0, bodyTop + 1.1 * scale, 0), "Really black", Enum.PartType.Cylinder)
		brim.CFrame = CFrame.new(Vector3.new(0, bodyTop + 1.1 * scale, 0)) * CFrame.Angles(0, 0, math.rad(90))
		addPart(model, "HatTop", Vector3.new(1.5 * scale, 1.1 * scale, 1.5 * scale), Vector3.new(0, bodyTop + 1.7 * scale, 0), "Really black")
	end
end

local function addLabel(model, def, anchorPart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "BrainrotLabel"
	gui.Adornee = anchorPart
	gui.Size = UDim2.new(0, 140, 0, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = model

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.45, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = def.name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.Parent = gui

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "RarityLabel"
	rarityLabel.Size = UDim2.new(1, 0, 0.3, 0)
	rarityLabel.Position = UDim2.new(0, 0, 0.45, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = def.rarity
	rarityLabel.TextColor3 = BrainrotDefs.getRarityColor(def.rarity)
	rarityLabel.TextStrokeTransparency = 0.2
	rarityLabel.TextScaled = true
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.Parent = gui

	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "IncomeLabel"
	incomeLabel.Size = UDim2.new(1, 0, 0.25, 0)
	incomeLabel.Position = UDim2.new(0, 0, 0.75, 0)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Text = "$" .. def.incomePerSec .. "/s  |  Cost $" .. def.cost
	incomeLabel.TextColor3 = Color3.fromRGB(255, 230, 120)
	incomeLabel.TextStrokeTransparency = 0.2
	incomeLabel.TextScaled = true
	incomeLabel.Font = Enum.Font.GothamBold
	incomeLabel.Parent = gui
end

--- Build a brainrot Model from its def. The model is anchored in place at
--- the origin; the caller moves it with PivotTo. State is kept in
--- attributes the server reads: CharacterId and State ("conveyor", "owned",
--- "stolen"); OwnerUserId is set once it is bought.
function BrainrotFactory.buildBrainrot(def)
	local model = Instance.new("Model")
	model.Name = def.name

	local scale = def.scale
	local bodySize
	if def.shape == "round" then
		bodySize = Vector3.new(2.2 * scale, 2.2 * scale, 2.2 * scale)
	elseif def.shape == "tall" then
		bodySize = Vector3.new(1.6 * scale, 2.8 * scale, 1.6 * scale)
	elseif def.shape == "wide" then
		bodySize = Vector3.new(3.0 * scale, 1.6 * scale, 2.2 * scale)
	else
		bodySize = Vector3.new(2.0 * scale, 2.2 * scale, 2.0 * scale)
	end

	local bodyShape = Enum.PartType.Block
	if def.shape == "round" then
		bodyShape = Enum.PartType.Ball
	end
	local body = addPart(model, "Body", bodySize, Vector3.new(0, bodySize.Y / 2, 0), def.color, bodyShape)
	model.PrimaryPart = body

	-- A little head on top with two eyes so every brainrot has a face.
	local headSize = 1.3 * scale
	local head = addPart(model, "Head", Vector3.new(headSize, headSize, headSize), Vector3.new(0, bodySize.Y + headSize / 2, 0), def.color, Enum.PartType.Ball)
	addEyes(model, Vector3.new(0, bodySize.Y + headSize / 2, 0), headSize, scale)

	-- Stubby feet so the character reads as standing, not floating.
	for _, side in ipairs({ -1, 1 }) do
		addPart(model, "Foot", Vector3.new(0.7 * scale, 0.4 * scale, 1.0 * scale), Vector3.new(side * 0.6 * scale, 0.2 * scale, 0.2 * scale), "Really black")
	end

	addShapeExtras(model, def, scale)
	addLabel(model, def, head)

	local click = Instance.new("ClickDetector")
	click.Name = "BrainrotClick"
	click.MaxActivationDistance = 32
	click.Parent = body
	click.MouseClick:Connect(function(player)
		if clickHandler then
			local ok, err = pcall(clickHandler, player, model)
			if not ok then
				warn("Brainrot click handler failed: " .. tostring(err))
			end
		end
	end)

	model:SetAttribute("CharacterId", def.id)
	model:SetAttribute("State", "conveyor")
	model:SetAttribute("OwnerUserId", 0)

	return model
end

--- The standing height of a built model, for placing it on the ground.
function BrainrotFactory.getModelHeight(model)
	local _, size = model:GetBoundingBox()
	return size.Y
end

return BrainrotFactory
