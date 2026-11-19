-- RebirthSystem: the long ladder of Brainrot Bazaar.
-- At a cash threshold a player can rebirth: cash resets to the starting
-- amount and every owned brainrot is lost, but each rebirth permanently
-- doubles all future income (x2, x4, x8, ...). The cost grows fivefold per
-- rebirth, so the ladder stays a real decision, not a free reset.

local Economy = require(script.Parent:WaitForChild("Economy"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))

local RebirthSystem = {}

--- Try to rebirth a player. Validates the cash cost on the server, then
--- clears their brainrots and cash and grants one multiplier level.
function RebirthSystem.tryRebirth(player)
	local cost = Economy.getRebirthCost(player)
	local plot = WorldBuilder.getPlotForPlayer(player)

	if not Economy.trySpend(player, cost) then
		return false, "Rebirth costs $" .. cost .. ". Keep earning!"
	end

	-- Free the plot slots before the models are destroyed.
	if plot then
		for _, slot in ipairs(plot.slots) do
			slot.model = nil
		end
	end
	Economy.clearOwnedBrainrots(player)
	Economy.resetCash(player)
	Economy.addRebirth(player)
	Economy.pushStats(player)

	local multiplier = Economy.getMultiplier(player)
	Economy.notify(player, "REBIRTH! All income is now x" .. multiplier .. " forever.")
	return true, "Rebirthed to x" .. multiplier .. " income."
end

return RebirthSystem
