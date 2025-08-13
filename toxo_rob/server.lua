local STEAL_RANGE = 2.5

local function isWithinDistance(sourceId, targetId, maxDistance)
	local srcPed = GetPlayerPed(sourceId)
	local tgtPed = GetPlayerPed(targetId)
	if not srcPed or not tgtPed then return false end
	local srcCoords = GetEntityCoords(srcPed)
	local tgtCoords = GetEntityCoords(tgtPed)
	return #(srcCoords - tgtCoords) <= (maxDistance or STEAL_RANGE)
end

RegisterNetEvent('ox_rob:openTargetInventory', function(targetId)
	local src = source
	if type(targetId) ~= 'number' or targetId <= 0 or src == targetId then return end

	if not isWithinDistance(src, targetId, STEAL_RANGE) then return end

	exports.ox_inventory:forceOpenInventory(src, 'player', targetId)
end)


