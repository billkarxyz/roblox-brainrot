-- BrainrotDefs: the cast of Brainrot Bazaar.
-- Twelve original absurd characters themed on Indonesian street food, on a
-- ladder of five rarities. Shared between server and client: the server uses
-- it for spawning and income, the client for the Brainrotpedia panel.
-- No character here copies any real brainrot meme.

local BrainrotDefs = {}

-- Rarity ladder: spawn weight (out of 100), display color, label color.
BrainrotDefs.RARITIES = {
	Common = {
		weight = 45,
		color = Color3.fromRGB(88, 200, 88),
	},
	Rare = {
		weight = 25,
		color = Color3.fromRGB(80, 160, 255),
	},
	Epic = {
		weight = 15,
		color = Color3.fromRGB(170, 90, 240),
	},
	Legendary = {
		weight = 10,
		color = Color3.fromRGB(255, 180, 40),
	},
	Mythic = {
		weight = 5,
		color = Color3.fromRGB(255, 70, 110),
	},
}

-- shape tags drive BrainrotFactory: "round", "tall", "wide", "spiky",
-- "winged", "hat". color is a BrickColor name for the body.
BrainrotDefs.CHARACTERS = {
	{
		id = "kopi-kenyal",
		name = "Kopi Kenyal",
		rarity = "Common",
		cost = 50,
		incomePerSec = 1,
		color = "Reddish brown",
		scale = 1.0,
		shape = "round",
		blurb = "A wobbly coffee jelly that never sleeps.",
	},
	{
		id = "kerupuk-king",
		name = "Kerupuk King",
		rarity = "Common",
		cost = 100,
		incomePerSec = 2,
		color = "Bright yellow",
		scale = 1.0,
		shape = "wide",
		blurb = "Crunchy, loud, and oddly royal.",
	},
	{
		id = "sate-samurai",
		name = "Sate Samurai",
		rarity = "Rare",
		cost = 400,
		incomePerSec = 6,
		color = "Deep orange",
		scale = 1.1,
		shape = "tall",
		blurb = "Skewers first, asks questions never.",
	},
	{
		id = "cendol-centurion",
		name = "Cendol Centurion",
		rarity = "Rare",
		cost = 750,
		incomePerSec = 10,
		color = "Bright green",
		scale = 1.1,
		shape = "hat",
		blurb = "Guards the dessert stall with a ladle.",
	},
	{
		id = "nasi-goreng-ninja",
		name = "Nasi Goreng Ninja",
		rarity = "Epic",
		cost = 2000,
		incomePerSec = 25,
		color = "Bright orange",
		scale = 1.2,
		shape = "tall",
		blurb = "Stir-fried in the shadows, served at dawn.",
	},
	{
		id = "martabak-mage",
		name = "Martabak Mage",
		rarity = "Epic",
		cost = 3500,
		incomePerSec = 40,
		color = "Bright violet",
		scale = 1.2,
		shape = "hat",
		blurb = "Casts spells with condensed milk.",
	},
	{
		id = "durian-diva",
		name = "Durian Diva",
		rarity = "Legendary",
		cost = 9000,
		incomePerSec = 100,
		color = "Bright yellowish green",
		scale = 1.35,
		shape = "spiky",
		blurb = "Smells terrible, earns beautifully.",
	},
	{
		id = "rendang-ranger",
		name = "Rendang Ranger",
		rarity = "Legendary",
		cost = 15000,
		incomePerSec = 160,
		color = "Reddish brown",
		scale = 1.35,
		shape = "winged",
		blurb = "Slow-cooked for four hours, worth every second.",
	},
	{
		id = "gado-gado-guardian",
		name = "Gado-Gado Guardian",
		rarity = "Legendary",
		cost = 20000,
		incomePerSec = 220,
		color = "Lime green",
		scale = 1.4,
		shape = "wide",
		blurb = "Peanut sauce is its shield and its sword.",
	},
	{
		id = "becak-baron",
		name = "Becak Baron",
		rarity = "Mythic",
		cost = 35000,
		incomePerSec = 350,
		color = "Bright blue",
		scale = 1.5,
		shape = "winged",
		blurb = "Rides a pedicab made of pure gold.",
	},
	{
		id = "es-teh-emperor",
		name = "Es Teh Emperor",
		rarity = "Mythic",
		cost = 50000,
		incomePerSec = 500,
		color = "Bright bluish green",
		scale = 1.55,
		shape = "hat",
		blurb = "Rules the iced-tea empire with a straw scepter.",
	},
	{
		id = "bakso-behemoth",
		name = "Bakso Behemoth",
		rarity = "Mythic",
		cost = 75000,
		incomePerSec = 750,
		color = "Hot pink",
		scale = 1.7,
		shape = "round",
		blurb = "One meatball to rule the whole bazaar.",
	},
}

local byId = {}
for _, def in ipairs(BrainrotDefs.CHARACTERS) do
	byId[def.id] = def
end

local rng = Random.new()

--- Look a character definition up by its id, or nil when unknown.
function BrainrotDefs.getCharacter(id)
	return byId[id]
end

--- The display color of a rarity, defaulting to white for unknown names.
function BrainrotDefs.getRarityColor(rarity)
	local entry = BrainrotDefs.RARITIES[rarity]
	if entry then
		return entry.color
	end
	return Color3.fromRGB(255, 255, 255)
end

--- Pick a random character, weighted by rarity: Commons are frequent,
--- Mythics are rare. First rolls a rarity, then a character inside it.
function BrainrotDefs.getRandomCharacter()
	local totalWeight = 0
	for _, entry in pairs(BrainrotDefs.RARITIES) do
		totalWeight += entry.weight
	end

	local roll = rng:NextInteger(1, totalWeight)
	local pickedRarity = "Common"
	local running = 0
	local order = { "Common", "Rare", "Epic", "Legendary", "Mythic" }
	for _, rarity in ipairs(order) do
		running += BrainrotDefs.RARITIES[rarity].weight
		if roll <= running then
			pickedRarity = rarity
			break
		end
	end

	local pool = {}
	for _, def in ipairs(BrainrotDefs.CHARACTERS) do
		if def.rarity == pickedRarity then
			table.insert(pool, def)
		end
	end
	return pool[rng:NextInteger(1, #pool)]
end

--- All characters, in ladder order (cheapest first).
function BrainrotDefs.getAllCharacters()
	return BrainrotDefs.CHARACTERS
end

return BrainrotDefs
