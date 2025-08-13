local STEAL_RANGE = 2.0
local PROGRESS_MS = 3000
local SEARCH_ANIM_DICT = 'amb@medic@standing@kneel@idle_a'
local SEARCH_ANIM_NAME = 'idle_a'

local DEBUG = false

local function notify(optsOrType, description)
	if type(optsOrType) == 'table' then
		if lib and lib.notify then
			if not optsOrType.position then optsOrType.position = 'top-right' end
			lib.notify(optsOrType)
		else
			BeginTextCommandThefeedPost("STRING")
			AddTextComponentSubstringPlayerName(optsOrType.description or '')
			EndTextCommandThefeedPostTicker(false, false)
		end
		return
	end

	local notificationType = optsOrType or 'inform'
	local message = description or ''
	if lib and lib.notify then
		lib.notify({ title = 'toxo_rob', description = message, type = notificationType, position = 'top-right' })
	else
		BeginTextCommandThefeedPost("STRING")
		AddTextComponentSubstringPlayerName(message)
		EndTextCommandThefeedPostTicker(false, false)
	end
end

local function getClosestPlayer(maxDistance)
	local playerPed = PlayerPedId()
	local myCoords = GetEntityCoords(playerPed)
	local closestPlayer, closestDist

	for _, ply in ipairs(GetActivePlayers()) do
		if ply ~= PlayerId() then
			local ped = GetPlayerPed(ply)
			if DoesEntityExist(ped) then
				local dist = #(GetEntityCoords(ped) - myCoords)
				if not closestDist or dist < closestDist then
					closestPlayer = ply
					closestDist = dist
				end
			end
		end
	end

	if closestPlayer and closestDist and closestDist <= (maxDistance or STEAL_RANGE) then
		return closestPlayer, closestDist
	end

	return nil, nil
end

local function loadAnimDict(dict)
	if not HasAnimDictLoaded(dict) then
		RequestAnimDict(dict)
		local timeout = GetGameTimer() + 5000
		while not HasAnimDictLoaded(dict) do
			Wait(10)
			if GetGameTimer() > timeout then break end
		end
	end
end

local function playSearchAnim(ped)
	SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)

	if not IsPedInAnyVehicle(ped, false) then
		TaskStartScenarioInPlace(ped, 'CODE_HUMAN_MEDIC_TEND_TO_DEAD', 0, true)
		Wait(200)
		if IsPedActiveInScenario and IsPedActiveInScenario(ped) then
			if DEBUG then print('[toxo_rob] Using scenario: CODE_HUMAN_MEDIC_TEND_TO_DEAD') end
			return
		end
	end

	loadAnimDict(SEARCH_ANIM_DICT)
	TaskPlayAnim(ped, SEARCH_ANIM_DICT, SEARCH_ANIM_NAME, 8.0, -8.0, -1, 49, 0.0, false, false, false)
	Wait(120)
	if IsEntityPlayingAnim(ped, SEARCH_ANIM_DICT, SEARCH_ANIM_NAME, 3) then
		if DEBUG then print('[toxo_rob] Using anim:', SEARCH_ANIM_DICT, SEARCH_ANIM_NAME) end
		return
	end

	loadAnimDict('mini@repair')
	TaskPlayAnim(ped, 'mini@repair', 'fixing_a_ped', 8.0, -8.0, -1, 49, 0.0, false, false, false)
	if DEBUG then print('[toxo_rob] Using fallback anim: mini@repair fixing_a_ped') end
end

local function stopSearchAnim(ped)
    ClearPedTasks(ped)
end

local function isHandsUp(ped)
	return IsEntityPlayingAnim(ped, 'missminuteman_1ig_2', 'handsup_base', 3)
		or IsEntityPlayingAnim(ped, 'random@mugging3', 'handsup_standing_base', 3)
end

local function isDowned(ped)
	return IsPedFatallyInjured(ped) or IsPedDeadOrDying(ped, true)
end

local function isCuffed(ped)
	return IsPedCuffed(ped) or IsEntityPlayingAnim(ped, 'mp_arresting', 'idle', 3)
end

local function isTargetRobbableByAnim(targetPed)
    return isDowned(targetPed) or isHandsUp(targetPed) or isCuffed(targetPed)
end

local function isTargetRobbableByState(targetPlayerIndex)
    local state = Player(targetPlayerIndex) and Player(targetPlayerIndex).state
    if not state then return false end

    -- Downed variants used by ox/qbx ecosystems
    local isDown = state.isDead == true or state.dead == true or state.laststand == true or state.isIncapacitated == true

    -- Cuffed/restrained variants used by ox_police/qbx_police
    local isRestrained = state.isCuffed == true or state.handcuffed == true or state.restrained == true or state.isRestrained == true

    return isDown or isRestrained
end

local function runProgress(duration, label)
    local ped = PlayerPedId()

    if GetResourceState and GetResourceState('ox_lib') == 'started' and lib and lib.progressCircle then
        local ok = lib.progressCircle({
            duration = duration or PROGRESS_MS,
            label = label or 'Robbing...',
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 },
            disable = {
                move = true,
                car = true,
                mouse = false,
                combat = true,
            },
        })
        return ok == true
    end

    playSearchAnim(ped)
    Wait(duration or PROGRESS_MS)
    stopSearchAnim(ped)
    return true
end

RegisterCommand('rob', function()
	local ply, dist = getClosestPlayer(STEAL_RANGE)
	if not ply then
		notify('inform', 'No player nearby')
		return
	end

    local targetPed = GetPlayerPed(ply)
    if not (isTargetRobbableByAnim(targetPed) or isTargetRobbableByState(ply)) then
		notify('error', 'Target must be downed, hands up, or cuffed')
		return
	end

	if not runProgress(PROGRESS_MS, 'Robbing...') then
		return
	end

	local targetServerId = tonumber(GetPlayerServerId(ply))
	if targetServerId then
		TriggerServerEvent('ox_rob:openTargetInventory', targetServerId)
	else
		notify('error', 'Failed to resolve target server id')
	end
end)

RegisterKeyMapping('rob', 'Rob/Search Player', 'keyboard', 'G')


AddEventHandler('onClientResourceStart', function(res)
	if res == GetCurrentResourceName() then
		TriggerEvent('chat:addSuggestion', '/rob', 'Rob/Search Player')
	end
end)

AddEventHandler('onClientResourceStop', function(res)
	if res == GetCurrentResourceName() then
		TriggerEvent('chat:removeSuggestion', '/rob')
	end
end)

