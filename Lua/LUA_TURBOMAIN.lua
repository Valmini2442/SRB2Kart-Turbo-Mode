local TICRATE = TICRATE
local FRACUNIT = FRACUNIT
local ANGLE_22h = ANGLE_22h
local FRACBITS = FRACBITS
local starttime = 6 * TICRATE + (3 * TICRATE / 4)

-- Déclaration des variables globales
local function initTurbo(p)
	p.turboDisplayTimer = 3 * TICRATE
	p.displayDuration = 3 * TICRATE
	p.turboGauge = 0
	p.turbogain = 0
	p.turboMax = 2500
	p.turbopercent = 0
	p.turboaction = ""
	p.turboConsumptionRate = 20
	p.lastlap = p.laps
	p.healthtemp = p.health
	p.turbo_button = BT_CUSTOM1
	p.guard_button = BT_CUSTOM2
	p.waterskip = p.kartstuff[k_waterskip]
end

local rewards = {
	["driftlv1"] = {3, "Drift Level 1"},
	["driftlv2"] = {2, "Drift Level 2"},
	["driftlv3"] = {1, "Drift Level 3"},
	["driftboostlv1"] = {150, "Drift Boost Level 1"},
	["driftboostlv2"] = {250, "Drift Boost Level 2"},
	["driftboostlv3"] = {350, "Drift Boost Level 3"},
	["keepup"] = {150, "Keep it up !!"},
	["cool"] = {250, "Cool"},
	["dontgiveup"] = {450, "Dont give up !!"},
	["perfectstart"] = {500, "Perfect Start Boost !!!"},
	["normalstart"] = {250, "Normal Start Boost !!!"},
	["ded"] = {-1000, "DED"},
	["oof"] = {-200, "OOF"},
	["missedtrick"] = {-50, "Missed Trick"},
	["oktrick"] = {100, "Ok - ish Trick"},
	["nicetrick"] = {125, "Nice Trick"},
	["radicaltrick"] = {150, "Radical Trick"},
	["wildtrick"] = {200, "WILD Trick"},
	["perfecttrick"] = {300, "Perfect Trick"},
	["maxtrick"] = {450, "Maximum Trick"},
	["wskip"] = {10,"Water skip"}

}

-- Fonction pour remplir la jauge Turbo
local function updateTurbo(p, rate, log)
	local prevGauge = p.turboGauge

	-- Met à jour la jauge
	p.turboGauge = $ + rate
	p.turboGauge = max(0, min(p.turboGauge, p.turboMax)) -- Clamp entre 0 et max

	p.turbopercent = (p.turboMax > 0) and ((p.turboGauge * 100) / p.turboMax) or 0
	p.turboDisplayTimer = 0

	-- Mise à jour du log et du gain
	if log ~= p.turboaction then
		p.turboaction = log
		p.turbogain = p.turboGauge - prevGauge
	else
		p.turbogain = $ + (p.turboGauge - prevGauge)
	end

	p.turbopercentgain = (p.turbogain * 100) / p.turboMax
end

local function Notify(p, log, temp)
	p.turboDisplayTimer = 0
    if log ~= p.turboaction then
        p.turboaction = log
        p.turbogain = p.turboGauge - temp
    else 
		p.turboaction = log
        p.turbogain = p.turbogain + p.turboGauge - temp
    end
end

-- Fonction pour utiliser le Turbo
local function useTurbo(p)
	if not (p.mo and p.mo.valid) then return end
	if not P_IsObjectOnGround(p.mo) then return end
	if not p.turboMax or p.turboMax == 0 then return end
	if p.turboGauge < p.turboConsumptionRate then return end
	if p.turboGauge <= 0 then return end

	p.turbopercent = (p.turboMax > 0) and ((p.turboGauge * 100) / p.turboMax) or 0


	p.turboGauge = p.turboGauge - p.turboConsumptionRate
	K_PlayBoostTaunt(p.mo)

	local turboRatio = (p.turboGauge << FRACBITS) / p.turboMax -- turboRatio en "fixed"
	local boostAmount = 0

	if turboRatio >= (FRACUNIT * 1) then
		boostAmount = 200
		p.mo.color = SKINCOLOR_SUPER
		p.mo.colorized = true
		K_DoInstashield(p)
		S_StartSound(p.mo, sfx_s3k35) -- gros boost
	elseif turboRatio >= (FRACUNIT * 3/4) then
		boostAmount = 175
		p.mo.color = SKINCOLOR_SUPER
		p.mo.colorized = true
		K_DoInstashield(p)
		S_StartSound(p.mo, sfx_s3k35) -- gros boost
	elseif turboRatio >= (FRACUNIT / 2) then
		boostAmount = 150
		p.mo.color = SKINCOLOR_SUPER
		p.mo.colorized = true
		S_StartSound(p.mo, sfx_s3k1e)
	elseif turboRatio >= (FRACUNIT / 4) then
		boostAmount = 125
		S_StartSound(p.mo, sfx_s3k1b)
	else
		boostAmount = 100
		S_StartSound(p.mo, sfx_s3k0e) -- petit boost
	end

	p.kartstuff[k_sneakertimer] = max(2, p.kartstuff[k_sneakertimer])
	
	P_InstaThrust(player.mo, player.mo.angle, 100*player.mo.scale)
	
	-- Donner un coup de pouce direct à la vitesse si le joueur est trop lent
	if p.speed < p.mo.scale * 12 then
		p.speed = p.mo.scale * 12
	end
	
	p.boostFlash = TICRATE / 3 -- Durée du flash en ticks
p.shakeTimer = TICRATE / 6 -- Secousse caméra


	
	for i = 0, 4 do
		local angle = p.mo.angle + ANGLE_45 * (i - 2)
		local x = p.mo.x + FixedMul(cos(angle), 20*FRACUNIT)
		local y = p.mo.y + FixedMul(sin(angle), 20*FRACUNIT)
		local z = p.mo.z + (5*FRACUNIT)
		local smoke = P_SpawnMobj(x, y, z, MT_THOK)
		smoke.state = S_ROCKETSMOKE
		smoke.scale = FRACUNIT/2
		smoke.tics = 10
	end
end

local function processTrick(p)
	if (P_IsObjectOnGround(p.mo)) then
		local trickpoints = {
			[-1] = "missedtrick", -- En cas d'erreur
			[0] = "missedtrick",
			[1] = "oktrick",
			[2] = "nicetrick",
			[3] = "radicaltrick",
			[4] = "wildtrick",
			[5] = "perfecttrick",
			[6] = "maxtrick"
		}
		local grade = p.trickgrade or -1
		local trickKey = trickpoints[grade] or "missedtrick"
		local reward = rewards[trickKey]
		if reward then
			updateTurbo(p, reward[1], reward[2])
		end
	end
end

-- Fonction pour gérer les actions des joueurs qui remplissent la jauge Turbo
local function handlePlayerActions(p)
	p.turbopercent = ((p.turboGauge*100) / p.turboMax)
	if p.cmd.buttons & BT_CUSTOM1 and p.turboGauge > 0 then 
		useTurbo(p)
	else
	
		local spark = K_GetKartDriftSparkValue(p)
		if p.kartstuff[k_drift]~= 0 and p.kartstuff[k_driftcharge] > spark then
			local lvdrift = "driftlv1"
			if p.kartstuff[k_driftcharge] >= spark*2 and p.kartstuff[k_driftcharge] < spark*4 then
				lvdrift = "driftlv2"
			elseif p.kartstuff[k_driftcharge] >= spark*4 then
				lvdrift = "driftlv3"
			end
			updateTurbo(p, rewards[lvdrift][1], rewards[lvdrift][2])
		end
		
		
		if p.kartstuff[k_driftend]~= 0 and p.kartstuff[k_driftcharge] > spark then
			local driftboost = "driftboostlv1"
			if p.kartstuff[k_driftcharge] >= spark*2 and p.kartstuff[k_driftcharge] < spark*4 then
				driftboost = "driftboostlv2"
			elseif p.kartstuff[k_driftcharge] >= spark*4 then
				driftboost = "driftboostlv3"
			end
			updateTurbo(p, rewards[driftboost][1], rewards[driftboost][2])
		end
		
		if p.lastlap ~= p.laps then
			local pos = "dontgiveup"
			if p.kartstuff[k_laphand] == 1 then
				pos = "keepup"
			elseif p.kartstuff[k_laphand] == 2 then
				pos = "cool"
			elseif p.kartstuff[k_laphand] == 3 then
				pos = "dontgiveup"
			end
			updateTurbo(p,rewards[pos][1],rewards[pos][2])
			p.lastlap = p.laps
		end
		
		if leveltime == starttime and p.kartstuff[k_boostcharge] >= 35 and p.kartstuff[k_boostcharge] <= 50 then
			local startboost = "normalstart"
			if  p.kartstuff[k_boostcharge] <= 36 then
				startboost = "perfectstart"
			end
			updateTurbo(p,rewards[startboost][1],rewards[startboost][2])
		end
		
		if p.healthtemp ~= p.health  then 
			if p.health <= 0 then
				updateTurbo(p,rewards["ded"][1],rewards["ded"][2])
			end		
			p.healthtemp = p.health
		end 
		
		if p.kartstuff[k_spinouttimer] > 0 then
				updateTurbo(p,rewards["oof"][1],rewards["oof"][2])
		end
		
		if p.waterskip ~= p.kartstuff[k_waterskip] then
			updateTurbo(p,rewards["wskip"][1],rewards["wskip"][2])
			p.waterskip = p.kartstuff[k_waterskip]
		end
		
		if p.hastricked or (p.trickactive and p.trickboostburst > 0) then
			processTrick(p)
		end

		
	end
end

-- Boucle principale de mise à jour
addHook("ThinkFrame", function()
	if G_BattleGametype() then return end 
    -- Handle player actions and timer
    for p in players.iterate() do
		p.turboDisplayTimer = p.turboDisplayTimer + 1
		p.turbopercent = ((p.turboGauge * 100) / p.turboMax)
		if p.turboDisplayTimer > p.displayDuration then
			p.turbogain = 0
		end

        -- Check if the level time is zero and initialize turbo
        if leveltime == 0 then
            initTurbo(p)
        end
        
        -- Handle player actions
        handlePlayerActions(p)
    end
end)


addHook("MapLoad", do 
																			   
	for p in players.iterate() do	
		initTurbo(p)
	end
end)

hud.add(function(v, p, c) --Actual visual real HUD is in LUA_ACROHUD  - debug's here for the sake of sanity checks and not actual use lol
	

	if  p.exiting then return end --let's not get hasty here
	
	if not(splitscreen)
		v.drawString(12,65, "Turbo gauge :" .. p.turbopercent .. "%", V_SNAPTOLEFT,"left")
		
		if p.turboDisplayTimer < p.displayDuration  then
			v.drawString(150,35, p.turboaction , V_SNAPTOLEFT,"center")
			v.drawString(150,45, p.turbogain , V_SNAPTOLEFT,"center")
		end
		v.drawString(12,85, "Speed :" .. p.kartstuff[k_speedboost], V_SNAPTOLEFT,"left")
		v.drawString(12,95, "Acceleration :" .. p.kartstuff[k_accelboost], V_SNAPTOLEFT,"left")
	else
		--ss indexer by callmore
		local ssindex = nil
			for i = 0, splitscreen do
				if p == displayplayers[i] then
					ssindex = i
					break
				end
			end
		if ssindex == nil then return end --you're not visible and you need to go
		
		local sox = 0 --splitoffsetx, not clothes
		local soy = 0 --splitoffsety, not tofu
		
		if splitscreen == 1 --2p mode, big split
			if ssindex == 1 --bottom
				soy = 100 --shifts to lower scr
			else --topscreen
				soy = 0 
			end

		else --3/4p
		
			if ssindex%2 == 1
				sox = 160 --shift right!
			end
			if ssindex > 1
				soy = 100
			end
			
			v.drawString(50 + sox,soy,p.turbopercent .. "%", V_SNAPTOLEFT,"center")
			if p.turboDisplayTimer < p.displayDuration  then
				v.drawString(50 + sox,soy + 10, p.turboaction , V_SNAPTOLEFT,"center")
				v.drawString(50 + sox,20+soy, p.turbogain , V_SNAPTOLEFT,"center")
			end
		end
		

	end
			
			
		
end)