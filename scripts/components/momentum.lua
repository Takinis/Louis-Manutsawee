local MODIFIER_KEY = "momentum"

local function OnDangerChanged(inst)
    inst.components.momentum:Wake()
end

local function OnVitalsChanged(inst)
    inst.components.momentum:Recompute()
end

local function OnAttacked(inst, data)
    inst.components.momentum:OnAttacked(data)
end

local function OnHitOther(inst, data)
    inst.components.momentum:OnHitOther(data)
end

local function OnKilled(inst, data)
    inst.components.momentum:OnKilled(data)
end

local function OnDeath(inst)
    inst.components.momentum:Reset()
end

local function OnRespawned(inst)
    inst.components.momentum:Wake()
end

local function OnTick(inst)
    inst.components.momentum:Tick()
end

local EVENTS = {
    kiritzuka_dangerchanged = OnDangerChanged,
    healthdelta = OnVitalsChanged,
    attacked = OnAttacked,
    onhitother = OnHitOther,
    killed = OnKilled,
    death = OnDeath,
    ms_becameghost = OnDeath,
    ms_respawnedfromghost = OnRespawned,
}

local Momentum = Class(function(self, inst)
    self.inst = inst
    self.value = 0
    self.stage = 1
    self.multiplier = 1
    self.last_activity = -math.huge
    self.last_tick = nil
    self.sources = {}
    self.applied = {}
    for event, callback in pairs(EVENTS) do
        inst:ListenForEvent(event, callback)
    end
end)

function Momentum:IsActive()
    return self.value > 0
end

function Momentum:GetValue()
    return self.value
end

function Momentum:GetPercent()
    return self.value / TUNING.MOMENTUM.MAX
end

function Momentum:GetStage()
    return self.stage
end

function Momentum:GetStageName()
    return TUNING.MOMENTUM.STAGES[self.stage].name
end

function Momentum:GetMultiplier()
    return self.multiplier
end

function Momentum:IsDisabled()
    return self.inst.components.health:IsDead() or self.inst:HasTag("playerghost")
end

-- Effects are multiplicative across sources, so skills and the stage can contribute independently.
function Momentum:SetSource(name, effects)
    self.sources[name] = effects
    self:Recompute()
end

function Momentum:GetEffect(name)
    local total = 1
    for _, effects in pairs(self.sources) do
        total = total * (effects[name] or 1)
    end
    local cap = name == "damage" and TUNING.MOMENTUM.DAMAGE_CAP or TUNING.MOMENTUM.EFFECT_CAPS[name]
    return cap ~= nil and math.min(total, cap) or total
end

function Momentum:GetLastStand()
    if self.value <= 0 then
        return
    end
    local tuning = TUNING.MOMENTUM
    local percent = self.inst.components.health:GetPercent()
    if percent <= tuning.CRITICAL_HEALTH then
        return tuning.CRITICAL_MULTIPLIERS[self.stage]
    end
    for _, band in ipairs(tuning.HEALTH_BANDS) do
        if percent <= band[1] then
            return band[2] + (band[3] - band[2]) * self:GetPercent()
        end
    end
end

function Momentum:UpdateStage()
    local stages = TUNING.MOMENTUM.STAGES
    local stage = self.stage
    while stage < #stages and self.value >= stages[stage + 1].enter do
        stage = stage + 1
    end
    while stage > 1 and self.value < stages[stage].exit do
        stage = stage - 1
    end
    self.stage = stage
end

function Momentum:ApplyEffect(name, value)
    if self.applied[name] == value then
        return
    end
    self.applied[name] = value
    local inst = self.inst
    if name == "damage" then
        local modifiers = inst.components.combat.externaldamagemultipliers
        if value == 1 then
            modifiers:RemoveModifier(inst, MODIFIER_KEY)
        else
            modifiers:SetModifier(inst, value, MODIFIER_KEY)
        end
    elseif name == "speed" and inst.components.locomotor ~= nil then
        if value == 1 then
            inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, MODIFIER_KEY)
        else
            inst.components.locomotor:SetExternalSpeedMultiplier(inst, MODIFIER_KEY, value)
        end
    end
end

function Momentum:Sync()
    local value, stage = self.inst.net_momentum_value, self.inst.net_momentum_stage
    if value == nil then
        return
    end
    local rounded = math.floor(self.value + 0.5)
    if rounded ~= self.synced_value or self.stage ~= self.synced_stage then
        self.synced_value, self.synced_stage = rounded, self.stage
        value:set(rounded)
        stage:set(self.stage)
        -- Netvar dirty events only fire on remote clients; a hosting player's HUD needs this one.
        self.inst:PushEvent("momentumdirty")
    end
end

function Momentum:Recompute()
    local disabled = self:IsDisabled()
    if disabled then
        self.value = 0
    end
    local old_stage = self.stage
    self:UpdateStage()
    self.sources.stage = TUNING.MOMENTUM.STAGES[self.stage].effects
    local last_stand = not disabled and self:GetLastStand() or nil
    self.sources.last_stand = last_stand ~= nil and { damage = last_stand } or nil
    -- Sources only declare effects; every applied effect is re-derived here, then diffed.
    local names = { damage = true, speed = true }
    for _, effects in pairs(self.sources) do
        for name in pairs(effects) do
            names[name] = true
        end
    end
    for name in pairs(names) do
        self:ApplyEffect(name, self:GetEffect(name))
    end
    local multiplier = self.applied.damage or 1
    self:Sync()
    if self.stage ~= old_stage or self.multiplier ~= multiplier then
        self.multiplier = multiplier
        self.inst:PushEvent("momentumchanged", {
            stage = self.stage, value = self.value, multiplier = multiplier,
        })
    end
end

function Momentum:Gain(amount)
    if amount <= 0 or self:IsDisabled() then
        return
    end
    self.last_activity = GetTime()
    self.value = math.min(TUNING.MOMENTUM.MAX, self.value + amount)
    self:Recompute()
    self:Wake()
end

-- Returns false without side effects when the gauge cannot pay.
function Momentum:Spend(amount)
    if amount <= 0 then
        return true
    end
    if self.value < amount then
        return false
    end
    self.last_activity = GetTime()
    self.value = self.value - amount
    self:Recompute()
    self.inst:PushEvent("momentumspent", { amount = amount, value = self.value })
    return true
end

function Momentum:Reset()
    self:StopTicking()
    self.value = 0
    self.stage = 1
    self.last_activity = -math.huge
    self:Recompute()
end

function Momentum:GetPriority(target)
    return self.inst.components.enemytracker:GetPriority(target)
end

function Momentum:OnAttacked(data)
    if data == nil or data.attacker == nil or data.attacker == self.inst
        or data.redirected ~= nil or (data.damageresolved or 0) <= 0 then
        return
    end
    local tuning = TUNING.MOMENTUM
    if self.value <= 0 then
        -- Include a dangerous encounter's first hit even before the next proximity scan.
        self.inst.components.enemytracker:Scan()
    end
    local fraction = data.damageresolved / math.max(1, self.inst.components.health:GetMaxWithPenalty())
    self:Gain(math.min(tuning.DAMAGED_MAX, fraction * tuning.DAMAGED_SCALE))
end

function Momentum:OnHitOther(data)
    if data == nil or data.target == nil or (data.damageresolved or 0) <= 0 then
        return
    end
    self:Gain(TUNING.MOMENTUM.HIT_GAIN[self:GetPriority(data.target)])
end

function Momentum:OnKilled(data)
    if data == nil or data.victim == nil or data.victim == self.inst then
        return
    end
    self:Gain(TUNING.MOMENTUM.KILL_GAIN[self:GetPriority(data.victim)])
end

function Momentum:GetCeiling()
    local tuning = TUNING.MOMENTUM
    local threat = self.inst.components.enemytracker:GetThreat()
    if threat <= 0 then
        return 0
    end
    return math.min(tuning.MAX, tuning.CEILING_BASE + threat * tuning.CEILING_SLOPE)
end

function Momentum:Advance(dt)
    local tuning = TUNING.MOMENTUM
    local ceiling = self:GetCeiling()
    if self.value < ceiling then
        self.value = math.min(ceiling, self.value + tuning.THREAT_GAIN * dt)
    elseif GetTime() - self.last_activity >= tuning.DECAY_DELAY then
        local rate = ceiling > 0 and tuning.SOFT_DECAY_RATE or tuning.DECAY_RATE
        self.value = math.max(ceiling, self.value - rate * dt)
    end
    return ceiling
end

function Momentum:Tick()
    local now = GetTime()
    local dt = now - (self.last_tick or now - TUNING.MOMENTUM.TICK)
    self.last_tick = now
    if self:IsDisabled() then
        self:Reset()
        return
    end
    local ceiling = self:Advance(dt)
    self:Recompute()
    if ceiling <= 0 and self.value <= 0 then
        self:StopTicking()
    end
end

-- Ticking only runs while there is a gauge to move or a threat to build it.
function Momentum:Wake()
    if self.task == nil and not self:IsDisabled()
        and (self.value > 0 or self.inst.components.enemytracker:GetThreat() > 0) then
        self.last_tick = GetTime()
        self.task = self.inst:DoPeriodicTask(TUNING.MOMENTUM.TICK, OnTick)
    end
    self:Recompute()
end

function Momentum:StopTicking()
    if self.task ~= nil then
        self.task:Cancel()
        self.task = nil
    end
    self.last_tick = nil
end

function Momentum:OnSave()
    return { value = self.value, stage = self.stage }
end

function Momentum:OnLoad(data)
    if data == nil then
        return
    end
    self.value = math.clamp(data.value or 0, 0, TUNING.MOMENTUM.MAX)
    self.stage = math.clamp(data.stage or 1, 1, #TUNING.MOMENTUM.STAGES)
    self.last_activity = GetTime()
    self:Recompute()
    -- The tracker's first scan runs after all components have loaded and wakes the ticker.
    if self.value > 0 then
        self:Wake()
    end
end

function Momentum:LongUpdate(dt)
    if self.value > 0 then
        -- Skipped time is quiet time: drain toward the current ceiling in a single step.
        self.last_activity = math.min(self.last_activity, GetTime() - TUNING.MOMENTUM.DECAY_DELAY)
        self:Advance(dt)
        self:Recompute()
    end
end

function Momentum:OnRemoveFromEntity()
    self:StopTicking()
    for event, callback in pairs(EVENTS) do
        self.inst:RemoveEventCallback(event, callback)
    end
    for name in pairs(self.applied) do
        self:ApplyEffect(name, 1)
    end
end

Momentum.OnRemoveEntity = Momentum.OnRemoveFromEntity

function Momentum:GetDebugString()
    return string.format("value=%.1f stage=%s damage=%.3f ceiling=%.1f",
        self.value, self:GetStageName(), self.multiplier, self:GetCeiling())
end

return Momentum
