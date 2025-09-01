local TICRATE = TICRATE
local FRACUNIT = FRACUNIT
local ANGLE_22h = ANGLE_22h
local FRACBITS = FRACBITS
local starttime = 6 * TICRATE + (3 * TICRATE / 4)

if not unpack then
    unpack = table.unpack or function(t, i, j)
        i = i or 1
        j = j or #t
        if i <= j then
            return t[i], unpack(t, i + 1, j)
        end
    end
end

-- ================================
-- CONFIGURATION TURBO (single source of truth)
-- ================================
local TurboConfig = {
    -- Jauge
    maxGauge = 2500,
    consumptionRate = 20,
    displayDuration = 3 * TICRATE,

    -- Rewards (remplissage de jauge)
    rewards = {
        ["driftlv1"]       = {3,   "Drift Level 1"},
        ["driftlv2"]       = {2,   "Drift Level 2"},
        ["driftlv3"]       = {1,   "Drift Level 3"},
        ["driftboostlv1"]  = {150, "Drift Boost Level 1"},
        ["driftboostlv2"]  = {250, "Drift Boost Level 2"},
        ["driftboostlv3"]  = {350, "Drift Boost Level 3"},
        ["keepup"]         = {150, "Keep it up !!"},
        ["cool"]           = {250, "Cool"},
        ["dontgiveup"]    = {450, "Dont give up !!"},
        ["perfectstart"]   = {500, "Perfect Start Boost !!!"},
        ["normalstart"]    = {250, "Normal Start Boost !!!"},
        ["ded"]            = {-1000,"DED"},
        ["oof"]            = {-200,"OOF"},
        ["missedtrick"]    = {-50, "Missed Trick"},
        ["oktrick"]        = {100, "Ok - ish Trick"},
        ["nicetrick"]      = {125, "Nice Trick"},
        ["radicaltrick"]   = {150, "Radical Trick"},
        ["wildtrick"]      = {200, "WILD Trick"},
        ["perfecttrick"]   = {300, "Perfect Trick"},
        ["maxtrick"]       = {450, "Maximum Trick"},
        ["wskip"]          = {10,  "Water skip"},
    },

    -- Stages (paliers)
    stages = {
        { threshold = FRACUNIT      , boost = 200, color = SKINCOLOR_SUPER, colorized = true , instashield = true , sound = sfx_s3k35 },
        { threshold = FRACUNIT * 3/4, boost = 175, color = SKINCOLOR_SUPER, colorized = true , instashield = true , sound = sfx_s3k35 },
        { threshold = FRACUNIT / 2  , boost = 150, color = SKINCOLOR_SUPER, colorized = true , instashield = false, sound = sfx_s3k1e },
        { threshold = FRACUNIT / 4  , boost = 125, color = nil           , colorized = false, instashield = false, sound = sfx_s3k1b },
        { threshold = 0             , boost = 100, color = nil           , colorized = false, instashield = false, sound = sfx_s3k0e },
    },

    minSneakerTimer = 2,
    instaThrust = 100,
    minSpeedScale = 12,
    boostFlashTime = TICRATE/3,
    shakeTime = TICRATE/6,
    smokeCount = 5,
    smokeOffset = 20*FRACUNIT,
    smokeZ = 5*FRACUNIT,
    smokeScale = FRACUNIT/2,
    smokeTics = 10
}

-- ensure init uses the single config
local function initTurbo(p)
    p.turboDisplayTimer = TurboConfig.displayDuration
    p.turboGauge = 0
    p.turbogain = 0
    p.turbopercent = 0
    p.turboaction = ""
    p.lastlap = p.laps
    p.healthtemp = p.health
    p.turbo_button = BT_CUSTOM1
    p.guard_button = BT_CUSTOM2
    p.waterskip = p.kartstuff and p.kartstuff[k_waterskip] or 0

    p.turboMax = TurboConfig.maxGauge
    p.turboConsumptionRate = TurboConfig.consumptionRate
    p.displayDuration = TurboConfig.displayDuration
	
	if acrobasics then print("Accrobasics Activated")end
	if acrobatics then print("Accrobatics Activated")end
end

local function Notify(p, log, temp) 
	p.turboDisplayTimer = p.displayDuration
	if log ~= p.turboaction then 
		p.turbogain = p.turboGauge - temp 
	else 
		p.turbogain = p.turbogain + p.turboGauge - temp 
	end
	p.turboaction = log
end

-- Fonction pour remplir la jauge Turbo 
local function updateTurbo(p, gain) 
	local prevGauge = p.turboGauge -- Met à jour la jauge 
	p.turboGauge = $ + gain[1] 
	p.turboGauge = max(0, min(p.turboGauge, p.turboMax)) -- Clamp entre 0 et max 
	p.turbopercent = (p.turboMax > 0) and ((p.turboGauge * 100) / p.turboMax) or 0 
	p.turboDisplayTimer = p.displayDuration -- Mise à jour du log et du gain 
	if gain[2] ~= p.turboaction then 
		p.turboaction = gain[2] 
		p.turbogain = p.turboGauge - prevGauge 
	else 
		p.turbogain = $ + (p.turboGauge - prevGauge) 
	end 
	
	p.turbopercentgain = (p.turbogain * 100) / p.turboMax 
end 

-- safer ratio + no bitshift
local function useTurbo(p)
    if not (p and p.mo and p.mo.valid) then return end
    if p.spectator then return end
    if not P_IsObjectOnGround(p.mo) then return end
    if not p.turboMax or p.turboMax == 0 then return end
    if p.turboGauge < p.turboConsumptionRate then return end

    -- consume first
    p.turboGauge = max(0, p.turboGauge - p.turboConsumptionRate)
    K_PlayBoostTaunt(p.mo)

    -- turbo ratio in fixed
    local turboRatio = FixedDiv(p.turboGauge * FRACUNIT, p.turboMax)
    local stageData = TurboConfig.stages[#TurboConfig.stages]
    for _, s in ipairs(TurboConfig.stages) do
        if turboRatio >= s.threshold then stageData = s; break end
    end

    if stageData.color then
        p.mo.color = stageData.color
        p.mo.colorized = stageData.colorized or false
    end
    if stageData.instashield then K_DoInstashield(p) end
    if stageData.sound then S_StartSound(p.mo, stageData.sound) end

    p.kartstuff[k_sneakertimer] = max(TurboConfig.minSneakerTimer, p.kartstuff[k_sneakertimer] or 0)
    P_InstaThrust(p.mo, p.mo.angle, TurboConfig.instaThrust * p.mo.scale)
    if p.speed < p.mo.scale * TurboConfig.minSpeedScale then
        p.speed = p.mo.scale * TurboConfig.minSpeedScale
    end

    p.boostFlash = TurboConfig.boostFlashTime
    p.shakeTimer = TurboConfig.shakeTime

    for i = 0, TurboConfig.smokeCount-1 do
        local angle = p.mo.angle + ANGLE_45 * (i - (TurboConfig.smokeCount-1)/2)
        local x = p.mo.x + FixedMul(cos(angle), TurboConfig.smokeOffset)
        local y = p.mo.y + FixedMul(sin(angle), TurboConfig.smokeOffset)
        local z = p.mo.z + TurboConfig.smokeZ
        local smoke = P_SpawnMobj(x, y, z, MT_THOK)
        smoke.state = S_ROCKETSMOKE
        smoke.scale = TurboConfig.smokeScale
        smoke.tics = TurboConfig.smokeTics
    end
end

-- fix: always use TurboConfig.rewards
local function processTrick(p)
    if P_IsObjectOnGround(p.mo) then
        local trickpoints = {
            [-1] = "missedtrick",
            [0] = "missedtrick",
            [1] = "oktrick",
            [2] = "nicetrick",
            [3] = "radicaltrick",
            [4] = "wildtrick",
            [5] = "perfecttrick",
            [6] = "maxtrick"
        }
		
        local grade = p.trickgrade or -1
		print("Trick grade :" .. grade)
        local key = trickpoints[grade] or "missedtrick"
        updateTurbo(p, TurboConfig.rewards[key])
    end
end

-- Table pour déterminer le niveau de drift 
local DriftLevels = { 
	{min = 0, factor = 1, key = "driftlv1"}, 
	{min = 2, factor = 2, key = "driftlv2"}, 
	{min = 4, factor = 4, key = "driftlv3"} } 

-- Table pour les boosts de drift finaux 
local DriftBoostLevels = { 
	{min = 0, factor = 1, key = "driftboostlv1"}, 
	{min = 2, factor = 2, key = "driftboostlv2"}, 
	{min = 4, factor = 4, key = "driftboostlv3"} } 
	
-- Mapping des positions (lap hand) 
local LapHandMap = { 
		[1] = "keepup", 
		[2] = "cool", 
		[3] = "dontgiveup" 
} 

-- Mapping des start boosts 
local StartBoostMap = { 
	normal = "normalstart", 
	perfect = "perfectstart" 
} 

local function getDriftKey(p, spark, levels) 
	for i = #levels, 1, -1 do 
		if p.kartstuff[k_driftcharge] >= spark * levels[i].factor then 
			return levels[i].key 
		end 
	end
	return levels[1].key 
end

-- handle buttons robustly
local function handlePlayerActions(p)
    if not (p and p.mo and p.mo.valid) or p.spectator then return end

    -- Turbo on button
    if (p.cmd.buttons & BT_CUSTOM1) ~= 0 and p.turboGauge > 0 then
        useTurbo(p)
        return
    end

    local spark = K_GetKartDriftSparkValue(p) or 0

    -- Drift ongoing
    if p.kartstuff[k_drift] ~= 0 and p.kartstuff[k_driftcharge] > spark then
        local lvdrift = getDriftKey(p, spark, DriftLevels)
        updateTurbo(p, TurboConfig.rewards[lvdrift])
    end

    -- Drift end
    if p.kartstuff[k_driftend] ~= 0 and p.kartstuff[k_driftcharge] > spark then
        local driftboost = getDriftKey(p, spark, DriftBoostLevels)
        updateTurbo(p,TurboConfig.rewards[driftboost])
    end

    -- Laps
    if p.lastlap ~= p.laps then
        local pos = LapHandMap[p.kartstuff[k_laphand]] or "dontgiveup"
        updateTurbo(p, TurboConfig.rewards[pos])
        p.lastlap = p.laps
    end

    -- Start boost window
    if leveltime == starttime and p.kartstuff[k_boostcharge] >= 35 and p.kartstuff[k_boostcharge] <= 50 then
        local startboost = (p.kartstuff[k_boostcharge] <= 36) and "perfectstart" or "normalstart"
        updateTurbo(p, TurboConfig.rewards[startboost])
    end

    -- Death
    if p.healthtemp ~= p.health then
        if p.health <= 0 then updateTurbo(p, TurboConfig.rewards["ded"]) end
        p.healthtemp = p.health
    end

    -- Spinout
    if p.kartstuff[k_spinouttimer] > 0 then
        updateTurbo(p, TurboConfig.rewards["oof"])
    end

    -- Water skip
    if p.waterskip ~= p.kartstuff[k_waterskip] then
        updateTurbo(p, TurboConfig.rewards["wskip"])
        p.waterskip = p.kartstuff[k_waterskip]
    end

    -- Tricks
	if acrobasics then
		if p.trickboostburst then print("Boost Burst :" .. p.trickboostburst)end
		if p.hastricked or (p.trickactive and p.trickboostburst > 0) then
			processTrick(p)
		end
	end
	
	if acrobatics then
		if p.trickboostburst then print("Boost Burst :" .. p.trickboostburst)end
		if p.hastricked or (p.trickactive and p.trickboostburst > 0) then
			processTrick(p)
		end
	end
end

-- per-frame percent once
addHook("ThinkFrame", function()
    if G_BattleGametype() then return end
    for p in players.iterate() do
        if leveltime == 0 then initTurbo(p) end

        if p.turboDisplayTimer > 0 then
            p.turboDisplayTimer = $ - 1
        else
            p.turbogain = 0
        end

        p.turbopercent = (p.turboMax and p.turboMax > 0) and ((p.turboGauge * 100) / p.turboMax) or 0
        handlePlayerActions(p)
    end
end)

-- HUD: fix 'then' and splitscreen logic
hud.add(function(v, p, c)
    if p.exiting then return end
    local ss = splitscreen or 0
    if ss == 0 then
        v.drawString(12,65, "Turbo gauge :" .. p.turbopercent .. "%", V_SNAPTOLEFT,"left")
        if p.turboDisplayTimer > 0 then
            v.drawString(150,35, p.turboaction, V_SNAPTOLEFT,"center")
            v.drawString(150,45, p.turbogain, V_SNAPTOLEFT,"center")
        end
        v.drawString(12,85, "Speed :" .. p.kartstuff[k_speedboost], V_SNAPTOLEFT,"left")
        v.drawString(12,95, "Acceleration :" .. p.kartstuff[k_accelboost], V_SNAPTOLEFT,"left")
		return
    end

    -- splitscreen >= 1
    local ssindex
    for i = 0, ss do
        if p == displayplayers[i] then ssindex = i; break end
    end
    if ssindex == nil then return end

    local sox, soy = 0, 0
    if ss == 1 then -- 2 players
        if ssindex == 1 then
            soy = 100
        else
            soy = 0
        end
    else -- 3/4 players
        if (ssindex % 2) == 1 then sox = 160 end
        if ssindex > 1 then soy = 100 end
    end

    v.drawString(50 + sox, soy, p.turbopercent .. "%", V_SNAPTOLEFT, "center")
    if p.turboDisplayTimer > 0 then
        v.drawString(50 + sox, soy + 10, p.turboaction, V_SNAPTOLEFT, "center")
        v.drawString(50 + sox, soy + 20, p.turbogain, V_SNAPTOLEFT, "center")
    end
end)
