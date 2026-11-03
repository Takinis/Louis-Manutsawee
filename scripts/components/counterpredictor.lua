local SCAN_PERIOD = 3 * FRAMES
local SCAN_RADIUS = 18
local PROJECTILE_LEAD_TIME = 5 * FRAMES
local PROJECTILE_HIT_GRACE = 2 * FRAMES
local SCAN_CANT_TAGS = {"INLIMBO", "DECOR", "playerghost"}
local SCAN_ONE_OF_TAGS = {"_combat", "projectile"}

local function IsAlive(inst)
    return inst ~= nil
        and inst:IsValid()
        and not inst:IsInLimbo()
        and (inst.components.health == nil or not inst.components.health:IsDead())
end

local function GetAttackTarget(attacker)
    local mem = attacker.sg.statemem
    local target = mem.target or mem.original_target
    return target ~= nil and target.Transform ~= nil and target or attacker.components.combat.target
end

local function IsRangedWeapon(weapon)
    return weapon ~= nil
        and (weapon.components.projectile ~= nil
            or weapon.components.complexprojectile ~= nil
            or weapon:HasTag("rangedweapon")
            or (weapon.components.weapon ~= nil and weapon.components.weapon.projectile ~= nil))
end

local function GetProjectileAttacker(projectile)
    local owner = projectile.owner
    if owner ~= nil and owner.components.combat == nil and owner.components.inventoryitem ~= nil then
        return owner.components.inventoryitem.owner
    end
    return owner
end

local function OnHostileProjectile(inst)
    local predictor = inst.components.counterpredictor
    if predictor.enabled then
        predictor:Scan()
        predictor:OnUpdate(0)
    end
end

local CounterPredictor = Class(function(self, inst)
    self.inst = inst
    self.enabled = false
    self.sleeping = false
    self.attackers = {}
    self.projectiles = {}
    self.scan_remaining = 0

    inst:ListenForEvent("hostileprojectile", OnHostileProjectile)
end)

function CounterPredictor:SetEnabled(enabled)
    if self.enabled == enabled then
        return
    end
    self.enabled = enabled
    self.attackers = {}
    self.projectiles = {}
    self.scan_remaining = 0
    if enabled and not self.sleeping then
        self.inst:StartUpdatingComponent(self)
        self:OnUpdate(0)
    else
        self.inst:StopUpdatingComponent(self)
    end
end

function CounterPredictor:WatchAttacker(attacker)
    if self.enabled and attacker ~= self.inst and IsAlive(attacker)
        and attacker.components.combat ~= nil and attacker.sg ~= nil then
        self.attackers[attacker] = self.attackers[attacker] or {}
    end
end

function CounterPredictor:Scan()
    local x, y, z = self.inst.Transform:GetWorldPosition()
    for _, entity in ipairs(TheSim:FindEntities(x, y, z, SCAN_RADIUS, nil, SCAN_CANT_TAGS, SCAN_ONE_OF_TAGS)) do
        local projectile = entity.components.projectile
        if projectile ~= nil and projectile.target == self.inst then
            self.projectiles[entity] = self.projectiles[entity] or {}
        elseif entity.sg ~= nil and entity.sg:HasStateTag("attack") then
            self:WatchAttacker(entity)
        end
    end
    self.scan_remaining = SCAN_PERIOD
end

function CounterPredictor:IsMeleeThreat(attacker)
    if not IsAlive(attacker) or attacker.sg == nil or attacker.components.combat == nil
        or not attacker.sg:HasStateTag("attack")
        or attacker.sg:HasStateTag("counterattack")
        or GetAttackTarget(attacker) ~= self.inst then
        return false
    end
    local combat = attacker.components.combat
    local weapon = combat:GetWeapon()
    return not IsRangedWeapon(weapon) and combat:CanHitTarget(self.inst, weapon)
end

function CounterPredictor:GetProjectileImpactTime(entity)
    local projectile = entity.components.projectile
    local attacker = projectile ~= nil and GetProjectileAttacker(projectile) or nil
    if projectile == nil or projectile.target ~= self.inst or attacker == nil
        or not attacker:IsValid() or attacker:IsInLimbo()
        or projectile.speed == nil or projectile.speed <= 0 then
        return
    end

    local x, y, z = entity.Transform:GetWorldPosition()
    local tx, ty, tz = self.inst.Transform:GetWorldPosition()
    local dx, dz = tx - x, tz - z
    local radius = self.inst:GetPhysicsRadius(0) + projectile.hitdist
    local distance = math.sqrt(dx * dx + dz * dz)
    if distance <= radius then
        return
    end

    if not projectile.homing then
        local rotation = entity.Transform:GetRotation() * DEGREES
        local vx, vz = math.cos(rotation), -math.sin(rotation)
        local forward = dx * vx + dz * vz
        local lateral_sq = dx * dx + dz * dz - forward * forward
        if forward <= 0 or lateral_sq > radius * radius then
            return
        end
        distance = forward - math.sqrt(math.max(0, radius * radius - lateral_sq))
    else
        distance = distance - radius
    end
    return distance / projectile.speed
end

function CounterPredictor:UpdateMeleeThreats()
    for attacker, record in pairs(self.attackers) do
        if not IsAlive(attacker) or attacker.sg == nil or attacker.components.combat == nil
            or not attacker.sg:HasStateTag("attack") then
            self.attackers[attacker] = nil
        else
            local sg = attacker.sg
            if record.state ~= sg.statemem then
                record.state = sg.statemem
                record.guarded = false
                record.countered = false
            end
            local last_attack = attacker.components.combat.lastdoattacktime
            -- Do not predict a strike that has already been delivered.
            if not record.guarded
                and (last_attack == nil or last_attack < sg.statestarttime)
                and self:IsMeleeThreat(attacker) then
                record.guarded = true
            end
        end
    end
end

function CounterPredictor:UpdateProjectileThreats()
    local now = GetTime()
    for entity, record in pairs(self.projectiles) do
        local projectile = entity:IsValid() and entity.components.projectile or nil
        if projectile == nil or entity:IsInLimbo() or projectile.target ~= self.inst then
            self.projectiles[entity] = nil
        else
            if record.owner ~= projectile.owner or record.start ~= projectile.start then
                record = {owner = projectile.owner, start = projectile.start}
                self.projectiles[entity] = record
            end
            local impact = self:GetProjectileImpactTime(entity)
            if impact ~= nil and impact <= PROJECTILE_LEAD_TIME then
                record.attacker = GetProjectileAttacker(projectile)
                record.weapon = projectile.owner
                record.guarded = true
                record.deadline = now + impact + PROJECTILE_HIT_GRACE
            elseif impact ~= nil then
                record.guarded = false
            elseif not record.guarded or record.deadline < now
                or self.inst:GetDistanceSqToInst(entity)
                    > (self.inst:GetPhysicsRadius(0) + projectile.hitdist) ^ 2 then
                record.guarded = false
            end
        end
    end
end

function CounterPredictor:ExecuteCounterAttack()
    local sg = self.inst.sg
    if sg:HasStateTag("counterattack") and not sg.statemem.counter_committed then
        return
    end

    local target, pending
    local distance_sq = math.huge
    local deadline = math.huge
    for entity, record in pairs(self.projectiles) do
        if record.guarded and not record.countered and not record.consumed
            and IsAlive(record.attacker) and record.deadline < deadline then
            target, pending, deadline = record.attacker, record, record.deadline
        end
    end
    if pending == nil then
        for attacker, record in pairs(self.attackers) do
            if record.guarded and not record.countered and self:IsMeleeThreat(attacker) then
                local dsq = self.inst:GetDistanceSqToInst(attacker)
                if dsq < distance_sq then
                    target, pending, distance_sq = attacker, record, dsq
                end
            end
        end
    end
    if pending ~= nil and IsAlive(target) then
        pending.countered = true
        self.inst.components.playerskillcontroller:ClearActiveSkill()
        sg:GoToState("counter_attack", target)
    end
end

function CounterPredictor:ShouldBlockAttack(attacker, weapon)
    local controller = self.inst.components.playerskillcontroller
    if not self.enabled or controller == nil or not controller:CanAutoCounterAttack() then
        return false
    end

    for entity, record in pairs(self.projectiles) do
        local projectile = entity:IsValid() and entity.components.projectile or nil
        if projectile ~= nil and record.guarded and not record.consumed and record.attacker == attacker
            and (projectile.target == nil or projectile.target == self.inst)
            and (projectile.owner == nil or projectile.owner == record.owner)
            and projectile.start == record.start
            and (weapon == entity or weapon == record.weapon)
            and record.deadline >= GetTime() then
            record.consumed = true
            return true
        end
    end

    local record = self.attackers[attacker]
    return record ~= nil and record.guarded and IsAlive(attacker) and attacker.sg ~= nil
        and record.state == attacker.sg.statemem
        and not IsRangedWeapon(weapon) and self:IsMeleeThreat(attacker)
end

function CounterPredictor:OnUpdate(dt)
    if not self.enabled or self.sleeping then
        return
    end
    local controller = self.inst.components.playerskillcontroller
    if controller == nil or not controller:CanAutoCounterAttack() then
        return
    end
    self.scan_remaining = self.scan_remaining - dt
    if self.scan_remaining <= 0 then
        self:Scan()
    end
    self:UpdateMeleeThreats()
    self:UpdateProjectileThreats()
    self:ExecuteCounterAttack()
end

function CounterPredictor:OnEntitySleep()
    self.sleeping = true
    self.attackers = {}
    self.projectiles = {}
    self.inst:StopUpdatingComponent(self)
end

function CounterPredictor:OnEntityWake()
    self.sleeping = false
    self.scan_remaining = 0
    if self.enabled then
        self.inst:StartUpdatingComponent(self)
    end
end

function CounterPredictor:OnRemoveFromEntity()
    self:SetEnabled(false)
    self.inst:RemoveEventCallback("hostileprojectile", OnHostileProjectile)
end

CounterPredictor.OnRemoveEntity = CounterPredictor.OnRemoveFromEntity

function CounterPredictor:GetDebugString()
    local attackers, projectiles = 0, 0
    for _ in pairs(self.attackers) do attackers = attackers + 1 end
    for _ in pairs(self.projectiles) do projectiles = projectiles + 1 end
    return string.format("enabled=%s attackers=%d projectiles=%d", tostring(self.enabled), attackers, projectiles)
end

return CounterPredictor
