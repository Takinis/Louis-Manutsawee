local MUST_TAGS = { "_combat" }
local CANT_TAGS = { "INLIMBO", "notarget", "noattack", "invisible", "player", "playerghost" }
local RANK = { low = 1, normal = 2, high = 3, keep = 4 }

local function Scan(inst)
    inst.components.enemytracker:Scan()
end

local EnemyTracker = Class(function(self, inst)
    self.inst = inst
    self.marks = {}
    self.situation = { count = 0, large_count = 0, priority = "low", danger = "low" }
    self.threat = 0
    self.task = inst:DoPeriodicTask(TUNING.MOMENTUM.SCAN_PERIOD, Scan, 0)
    inst:ListenForEvent("changearea", Scan)
    inst:ListenForEvent("death", Scan)
    inst:ListenForEvent("ms_becameghost", Scan)
    inst:ListenForEvent("ms_respawnedfromghost", Scan)
end)

function EnemyTracker:GetPriority(target)
    local priority = TUNING.MOMENTUM.ENEMY_PREFABS[target.prefab] or "low"
    for tag, value in pairs(TUNING.MOMENTUM.ENEMY_TAGS) do
        if target:HasTag(tag) and RANK[value] > RANK[priority] then
            priority = value
        end
    end
    return priority
end

function EnemyTracker:IsEnemy(target)
    if target == self.inst or not target:IsValid() or not target.entity:IsVisible()
        or target.components.combat == nil then
        return false
    end
    for _, tag in ipairs(CANT_TAGS) do
        if target:HasTag(tag) then
            return false
        end
    end
    local health = target.components.health
    if health ~= nil and health:IsDead() then
        return false
    end
    local follower = target.components.follower
    if follower ~= nil and follower.leader ~= nil and follower.leader:HasTag("player") then
        return false
    end
    local combat = target.components.combat
    return combat.target == self.inst
        or self.inst.components.combat.target == target
        or self:GetPriority(target) ~= "low"
end

function EnemyTracker:GetDangerousArea()
    local areaaware = self.inst.components.areaaware
    local area = areaaware ~= nil and areaaware:GetCurrentArea() or nil
    if area ~= nil then
        for _, tag in ipairs(area.tags or {}) do
            if TUNING.MOMENTUM.AREA_TAGS[tag] then
                return tag
            end
        end
        for _, id in ipairs(TUNING.MOMENTUM.AREA_IDS) do
            if area.id ~= nil and string.find(area.id, id, 1, true) ~= nil then
                return id
            end
        end
    end
end

function EnemyTracker:UpdateMark(target)
    local mark = self.marks[target]
    if mark == nil then
        mark = {}
        self.marks[target] = mark
        mark.onchanged = function()
            if self:IsEnemy(target)
                and self.inst:GetDistanceSqToInst(target) <= TUNING.MOMENTUM.SCAN_RADIUS ^ 2 then
                self:UpdateMark(target)
            else
                self:Unmark(target)
            end
            self:UpdateSituation(true)
        end
        mark.onremoved = function()
            self:Unmark(target)
            self:UpdateSituation(true)
        end
        self.inst:ListenForEvent("healthdelta", mark.onchanged, target)
        self.inst:ListenForEvent("death", mark.onremoved, target)
        self.inst:ListenForEvent("onremove", mark.onremoved, target)
    end
    local health = target.components.health
    local combat = target.components.combat
    local priority = self:GetPriority(target)
    local current_health = health ~= nil and health.currenthealth or 0
    local max_health = health ~= nil and health:GetMaxWithPenalty() or 0
    -- Base attack estimate, before weapon, special-attack and defender modifiers.
    local attack_damage = (combat.defaultdamage or 0) * (combat.damagemultiplier or 1)
        * (combat.playerdamagepercent or 1) * combat.externaldamagemultipliers:Get()
        + (combat.damagebonus or 0)
    local changed = mark.priority ~= priority or mark.health ~= current_health
        or mark.max_health ~= max_health or mark.attack_damage ~= attack_damage
    mark.priority = priority
    mark.danger = priority
    mark.large = target:HasTag("epic") or target:HasTag("boss") or RANK[priority] >= RANK.high
    mark.health = current_health
    mark.max_health = max_health
    mark.attack_damage = attack_damage
    mark.distance = math.sqrt(self.inst:GetDistanceSqToInst(target))
    return changed
end

function EnemyTracker:Unmark(target)
    local mark = self.marks[target]
    if mark ~= nil then
        self.inst:RemoveEventCallback("healthdelta", mark.onchanged, target)
        self.inst:RemoveEventCallback("death", mark.onremoved, target)
        self.inst:RemoveEventCallback("onremove", mark.onremoved, target)
        self.marks[target] = nil
    end
end

function EnemyTracker:UpdateSituation(marks_changed)
    local situation = {
        count = 0, large_count = 0, health = 0, max_health = 0,
        attack_damage = 0, priority = "low", danger = "low",
        area = self:GetDangerousArea(),
    }
    local threat = 0
    for _, mark in pairs(self.marks) do
        -- Nearby enemies weigh up to twice as much as ones at the edge of the scan radius.
        local falloff = 1 - 0.5 * math.min(1, (mark.distance or 0) / TUNING.MOMENTUM.SCAN_RADIUS)
        threat = threat + TUNING.MOMENTUM.THREAT_WEIGHTS[mark.priority] * falloff
        situation.count = situation.count + 1
        situation.large_count = situation.large_count + (mark.large and 1 or 0)
        situation.health = situation.health + mark.health
        situation.max_health = situation.max_health + mark.max_health
        situation.attack_damage = math.max(situation.attack_damage, mark.attack_damage)
        if RANK[mark.priority] > RANK[situation.priority] then
            situation.priority = mark.priority
        end
    end
    if situation.area ~= nil then
        threat = math.max(threat, TUNING.MOMENTUM.AREA_THREAT)
        situation.priority = "keep"
    elseif situation.count >= TUNING.MOMENTUM.GROUP_COUNT
        and RANK[situation.priority] < RANK.high then
        situation.priority = "high"
    elseif situation.count > 0 and situation.priority == "low" then
        situation.priority = "normal"
    end
    situation.danger = situation.priority
    situation.large_danger = situation.large_count > 0
    situation.multiple_dangers = situation.count >= TUNING.MOMENTUM.GROUP_COUNT
    local changed = marks_changed
    for key, value in pairs(situation) do
        changed = changed or self.situation[key] ~= value
    end
    changed = changed or self.situation.area ~= situation.area
    self.situation = situation
    -- Threat drifts with distance, so it is polled by consumers instead of pushing events.
    self.threat = threat
    if changed then
        self.inst:PushEvent("kiritzuka_dangerchanged", situation)
    end
end

function EnemyTracker:Scan()
    local seen = {}
    local changed = false
    if not self.inst.components.health:IsDead() and not self.inst:HasTag("playerghost") then
        local x, y, z = self.inst.Transform:GetWorldPosition()
        for _, target in ipairs(TheSim:FindEntities(x, y, z,
            TUNING.MOMENTUM.SCAN_RADIUS, MUST_TAGS, CANT_TAGS)) do
            if self:IsEnemy(target) then
                seen[target] = true
                changed = self:UpdateMark(target) or changed
            end
        end
    end
    local removed = {}
    for target in pairs(self.marks) do
        if not seen[target] then
            removed[#removed + 1] = target
        end
    end
    for _, target in ipairs(removed) do
        self:Unmark(target)
        changed = true
    end
    self:UpdateSituation(changed)
end

function EnemyTracker:GetMarks()
    return self.marks
end

function EnemyTracker:GetSituation()
    return self.situation
end

function EnemyTracker:GetThreat()
    return self.threat
end

function EnemyTracker:OnRemoveFromEntity()
    if self.task ~= nil then
        self.task:Cancel()
        self.task = nil
    end
    self.inst:RemoveEventCallback("changearea", Scan)
    self.inst:RemoveEventCallback("death", Scan)
    self.inst:RemoveEventCallback("ms_becameghost", Scan)
    self.inst:RemoveEventCallback("ms_respawnedfromghost", Scan)
    while next(self.marks) ~= nil do
        self:Unmark(next(self.marks))
    end
end

EnemyTracker.OnRemoveEntity = EnemyTracker.OnRemoveFromEntity

function EnemyTracker:GetDebugString()
    return string.format("enemies=%d large=%d priority=%s area=%s threat=%.2f",
        self.situation.count, self.situation.large_count, self.situation.priority, tostring(self.situation.area), self.threat)
end

return EnemyTracker
