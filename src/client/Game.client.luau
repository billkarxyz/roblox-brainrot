-- Game.client.luau: the Brainrot Bazaar HUD.
-- A ScreenGui over the 3D world: a top bar with cash, income per second and
-- multiplier (centered, clear of the top-left corner where Roblox's own menu
-- buttons sit), Lock Base and Rebirth buttons, a storm banner, a toast line,
-- and a Brainrotpedia panel listing the whole cast. The client only displays
-- what the server sends and asks for actions; it never decides money.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotDefs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotDefs"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local statsEvent = remotes:WaitForChild("StatsUpdate")
local notifyEvent = remotes:WaitForChild("Notify")
local warningEvent = remotes:WaitForChild("EventWarning")
local startEvent = remotes:WaitForChild("EventStart")
local endEvent = remotes:WaitForChild("EventEnd")
local lockEvent = remotes:WaitForChild("LockBase")
local rebirthEvent = remotes:WaitForChild("RebirthRequest")

local gui = Instance.new("ScreenGui")
gui.Name = "BazaarHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function makeLabel(parent, name, size, position, text, textColor, font)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Font = font or Enum.Font.GothamBold
	label.Parent = parent
	return label
end

local function makeButton(parent, name, size, position, text, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextStrokeTransparency = 0.3
	button.TextScaled = true
	button.Font = Enum.Font.FredokaOne
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	return button
end

-- Top bar: centered, away from the top-left Roblox menu buttons.
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.AnchorPoint = Vector2.new(0.5, 0)
topBar.Size = UDim2.new(0, 480, 0, 56)
topBar.Position = UDim2.new(0.5, 0, 0, 12)
topBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
topBar.BackgroundTransparency = 0.15
topBar.BorderSizePixel = 0
topBar.Parent = gui
local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 12)
topCorner.Parent = topBar

local cashLabel = makeLabel(topBar, "CashLabel", UDim2.new(0.34, 0, 1, 0), UDim2.new(0.02, 0, 0, 0), "Cash: $100", Color3.fromRGB(255, 230, 120), Enum.Font.FredokaOne)
local incomeLabel = makeLabel(topBar, "IncomeLabel", UDim2.new(0.32, 0, 1, 0), UDim2.new(0.34, 0, 0, 0), "$0/s", Color3.fromRGB(140, 255, 140))
local multiplierLabel = makeLabel(topBar, "MultiplierLabel", UDim2.new(0.3, 0, 1, 0), UDim2.new(0.68, 0, 0, 0), "x1", Color3.fromRGB(255, 170, 220))

-- Storm banner under the top bar, hidden until an event fires.
local banner = Instance.new("Frame")
banner.Name = "EventBanner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Size = UDim2.new(0, 480, 0, 44)
banner.Position = UDim2.new(0.5, 0, 0, 76)
banner.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
banner.BackgroundTransparency = 0.1
banner.BorderSizePixel = 0
banner.Visible = false
banner.Parent = gui
local bannerCorner = Instance.new("UICorner")
bannerCorner.CornerRadius = UDim.new(0, 10)
bannerCorner.Parent = banner
local bannerLabel = makeLabel(banner, "BannerLabel", UDim2.new(0.96, 0, 1, 0), UDim2.new(0.02, 0, 0, 0), "", Color3.fromRGB(255, 255, 255), Enum.Font.FredokaOne)

-- Action buttons along the bottom.
local lockButton = makeButton(gui, "LockButton", UDim2.new(0, 160, 0, 48), UDim2.new(0, 16, 1, -64), "LOCK BASE", Color3.fromRGB(60, 120, 220))
local rebirthButton = makeButton(gui, "RebirthButton", UDim2.new(0, 200, 0, 48), UDim2.new(0, 188, 1, -64), "REBIRTH ($10,000)", Color3.fromRGB(170, 60, 200))
local pediaButton = makeButton(gui, "PediaButton", UDim2.new(0, 170, 0, 44), UDim2.new(1, -186, 0, 12), "BRAINROTPEDIA", Color3.fromRGB(40, 160, 90))

-- Toast line above the bottom buttons.
local toast = makeLabel(gui, "ToastLabel", UDim2.new(0, 520, 0, 32), UDim2.new(0.5, -260, 1, -116), "", Color3.fromRGB(255, 255, 255))
toast.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
toast.BackgroundTransparency = 0.25
toast.Visible = false

-- Brainrotpedia: a scrolling list of the whole cast, toggled by its button.
local pediaPanel = Instance.new("Frame")
pediaPanel.Name = "PediaPanel"
pediaPanel.Size = UDim2.new(0, 320, 0, 420)
pediaPanel.Position = UDim2.new(1, -336, 0, 66)
pediaPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
pediaPanel.BackgroundTransparency = 0.1
pediaPanel.BorderSizePixel = 0
pediaPanel.Visible = false
pediaPanel.Parent = gui
local pediaCorner = Instance.new("UICorner")
pediaCorner.CornerRadius = UDim.new(0, 12)
pediaCorner.Parent = pediaPanel

makeLabel(pediaPanel, "PediaTitle", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0, 6), "BRAINROTPEDIA", Color3.fromRGB(255, 230, 120), Enum.Font.FredokaOne)

local pediaList = Instance.new("ScrollingFrame")
pediaList.Name = "PediaList"
pediaList.Size = UDim2.new(1, -16, 1, -52)
pediaList.Position = UDim2.new(0, 8, 0, 46)
pediaList.BackgroundTransparency = 1
pediaList.BorderSizePixel = 0
pediaList.ScrollBarThickness = 6
pediaList.CanvasSize = UDim2.new(0, 0, 0, 0)
pediaList.Parent = pediaPanel

local pediaLayout = Instance.new("UIListLayout")
pediaLayout.Padding = UDim.new(0, 6)
pediaLayout.Parent = pediaList

local characters = BrainrotDefs.getAllCharacters()
for _, def in ipairs(characters) do
	local row = Instance.new("Frame")
	row.Name = def.id
	row.Size = UDim2.new(1, 0, 0, 52)
	row.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	row.BorderSizePixel = 0
	row.Parent = pediaList
	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 8)
	rowCorner.Parent = row

	makeLabel(row, "EntryName", UDim2.new(0.6, 0, 0.55, 0), UDim2.new(0.03, 0, 0, 2), def.name, Color3.fromRGB(255, 255, 255))
	makeLabel(row, "EntryRarity", UDim2.new(0.34, 0, 0.55, 0), UDim2.new(0.64, 0, 0, 2), def.rarity, BrainrotDefs.getRarityColor(def.rarity))
	makeLabel(row, "EntryStats", UDim2.new(0.94, 0, 0.45, 0), UDim2.new(0.03, 0, 0.55, 0), "Cost $" .. def.cost .. "  |  $" .. def.incomePerSec .. "/s", Color3.fromRGB(255, 230, 120))
end
pediaList.CanvasSize = UDim2.new(0, 0, 0, #characters * 58)

local toastToken = 0
local function showToast(message)
	toastToken += 1
	local token = toastToken
	toast.Text = message
	toast.Visible = true
	task.delay(4, function()
		if token == toastToken then
			toast.Visible = false
		end
	end)
end

local bannerToken = 0
local function showBanner(message, seconds)
	bannerToken += 1
	local token = bannerToken
	bannerLabel.Text = message
	banner.Visible = true
	if seconds and seconds > 0 then
		task.delay(seconds, function()
			if token == bannerToken then
				banner.Visible = false
			end
		end)
	end
end

statsEvent.OnClientEvent:Connect(function(cash, incomePerSec, multiplier, rebirthCost)
	cashLabel.Text = "Cash: $" .. cash
	incomeLabel.Text = "$" .. incomePerSec .. "/s"
	multiplierLabel.Text = "x" .. multiplier
	rebirthButton.Text = "REBIRTH ($" .. rebirthCost .. ")"
end)

notifyEvent.OnClientEvent:Connect(function(message)
	showToast(message)
end)

warningEvent.OnClientEvent:Connect(function(message)
	showBanner(message, 10)
end)

startEvent.OnClientEvent:Connect(function(message)
	showBanner(message, 20)
end)

endEvent.OnClientEvent:Connect(function(message)
	showBanner(message, 5)
end)

lockButton.MouseButton1Click:Connect(function()
	lockEvent:FireServer()
end)

rebirthButton.MouseButton1Click:Connect(function()
	rebirthEvent:FireServer()
end)

pediaButton.MouseButton1Click:Connect(function()
	pediaPanel.Visible = not pediaPanel.Visible
end)

showToast("Welcome to Brainrot Bazaar! Click a brainrot on the conveyor to buy it.")
