local AddStategraphState = AddStategraphState
local AddStategraphPostInit = AddStategraphPostInit
GLOBAL.setfenv(1, GLOBAL)

local ATTACK_STATE = "kiritzuka_attack"
local SLAM_STATE = "kiritzuka_boss_slam"
local SPECIAL_WEAPON_TAGS = {
    "rangedweapon", "projectile", "complexprojectile", "whip", "pocketwatch",
    "book", "toolpunch", "lancejab", "chop_attack", "punch",
}
local SIGNATURE_WEAPONS = {
    baseballbat = true,
    crowbar = true,
    rebar = true,
    pickaxe = true,
    goldenpickaxe = true,
    glasscutter = true,
    nightsword = true,
}
local DEFAULT_HIT_FRAME = 8
-- Signature weapons land every swing on this frame; a lower value plays them all faster.
local SIGNATURE_HIT_FRAME = 7
-- Native impact frames, counted from the start of the pre animation.
local SIGNATURE_ATTACKS = {
    { pre = "atk_pre", loop = "atk", impact = 8 },
    { pre = "scythe_pre", loop = "scythe_loop", impact = 15, crit = true },
}
-- Faster swings can finish before the next attack starts, so the combo is tracked by time.
local SIGNATURE_COMBO_WINDOW = 1
-- The leap animation carries the vertical arc; the state only supplies the ground travel.
local LEAP_FRAMES = 12
local SLAM_IMPACT_FRAME = 9 + LEAP_FRAMES
-- Five hits at this spacing finish just before atk_leap ends on frame 43.
local SLAM_HIT_INTERVAL = 5
local SUSTAINED_PARRY_STATE = "kiritzuka_sustained_parry"
local SUSTAINED_PARRY_SPEED = 1
-- The attack refreshes the guard every tick; a short gap means it is over.
local SUSTAINED_PARRY_LINGER = 0.25
local DASH_STATE = "kiritzuka_dash"
local DASH_STAGES = 3
local DASH_SEA_STATE = "kiritzuka_dash_sea"
-- Damage stages from TUNING.KIRITZUKA_DASH.DAMAGE_MULT: the way out is a normal line, the way home the finisher.
local DASH_SEA_OUT_STAGE = 1
local DASH_SEA_BACK_STAGE = 3
-- lunge_pre runs 12 frames; doubling it lands the launch on the same frame every stage.
local DASH_LAUNCH_FRAME = 6
local DASH_TRAVEL_FRAMES = 4
local DASH_RECOVER_FRAMES = 4
-- Three lines this far apart cross at the target like an asterisk.
local DASH_LINE_TURN = math.pi / 3
local FLURRY_STATE = "kiritzuka_flurry"
local FLURRY_HITS = 10
-- Her own swing lands on its impact frame; the rest come an uneven few frames apart, so it reads as a flurry.
local FLURRY_FIRST_HIT_FRAME = 8
local FLURRY_MIN_INTERVAL = 1
local FLURRY_MAX_INTERVAL = 3

local GUARD_HIT_STATE = "kiritzuka_guard_hit"
local GUARD_HOLD_STATE = "kiritzuka_guard_hold"
local GUARD_HIT_FRAMES = 6

local GUARD_PRE_ANIM = "kiritzuka_guard_pre"
local GUARD_LOOP_ANIM = "kiritzuka_guard_loop"
local GUARD_BLOCK_ANIM = "kiritzuka_guard_block"
local GUARD_PST_ANIM = "kiritzuka_guard_pst"

local function PlayGuardPose(inst)
    inst.AnimState:PlayAnimation(GUARD_PRE_ANIM)
    inst.AnimState:PushAnimation(GUARD_LOOP_ANIM, true)
end

local function LowerGuard(inst)
    inst.AnimState:PlayAnimation(GUARD_PST_ANIM)
    inst.sg:GoToState("idle", true)
end

local function GetSignatureStep(inst)
    local mem = inst.sg.mem
    if mem.kiritzuka_attack_step == nil or GetTime() - mem.kiritzuka_attack_time > SIGNATURE_COMBO_WINDOW then
        return 1
    end
    return mem.kiritzuka_attack_step
end

-- Only a swing that reaches its impact moves the combo on, so rejected previews do not.
local function AdvanceSignatureStep(inst)
    local mem = inst.sg.mem
    mem.kiritzuka_attack_step = inst.sg.statemem.signature_step % #SIGNATURE_ATTACKS + 1
    mem.kiritzuka_attack_time = GetTime()
end

local function CommitAttack(inst, is_client)
    if is_client then
        inst:ClearBufferedAction()
    else
        local target = inst.sg.statemem.attacktarget
        if target ~= nil and target:IsValid() then
            inst.sg.statemem.recoilstate = "attack_recoil"
            inst:PerformBufferedAction()
        else
            inst:ClearBufferedAction()
        end
    end
    inst.sg:RemoveStateTag("abouttoattack")
    -- A hit blocked during the wind-up shows its guard now the swing has landed.
    local blocked = inst.sg.statemem.block_attacker
    if blocked ~= nil and blocked:IsValid() then
        inst.sg.statemem.block_attacker = nil
        inst:PlayBlockGuard(blocked)
    end
end

local function GetAttackState(weapon, rider, destination)
    if destination ~= "attack" or (rider ~= nil and rider:IsRiding())
        or weapon == nil or not weapon:HasTag("weapon") then
        return destination
    end

    for _, tag in ipairs(SPECIAL_WEAPON_TAGS) do
        if weapon:HasTag(tag) then
            return destination
        end
    end
    return ATTACK_STATE
end

local function MakeAttackState(is_client)
    return State{
        name = ATTACK_STATE,
        tags = is_client
            and { "attack", "notalking", "abouttoattack" }
            or { "attack", "notalking", "abouttoattack", "autopredict" },

        onenter = function(inst)
            local combat = is_client and inst.replica.combat or inst.components.combat
            if combat:InCooldown() then
                inst.sg:RemoveStateTag("abouttoattack")
                inst:ClearBufferedAction()
                inst.sg:GoToState("idle", true)
                return
            end

            local action = inst:GetBufferedAction()
            local target = action ~= nil and action.target or nil
            if not is_client then
                combat:SetTarget(target)
            end
            combat:StartAttack()
            inst.components.locomotor:Stop()

            local weapon = combat:GetWeapon()
            if weapon ~= nil and SIGNATURE_WEAPONS[weapon.prefab] then
                local step = GetSignatureStep(inst)
                local attack = SIGNATURE_ATTACKS[step]
                inst.sg.statemem.signature_step = step
                inst.sg.statemem.signature_crit = attack.crit
                inst.AnimState:SetDeltaTimeMultiplier(attack.impact / SIGNATURE_HIT_FRAME)
                inst.AnimState:PlayAnimation(attack.pre)
                inst.AnimState:PushAnimation(attack.loop, false)
            else
                inst.AnimState:PlayAnimation("atk_pre")
                inst.AnimState:PushAnimation("atk", false)
            end
            inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon", nil, nil, true)

            if target ~= nil and target:IsValid() then
                inst:FacePoint(target:GetPosition())
                inst.sg.statemem.attacktarget = target
                inst.sg.statemem.retarget = target
                if not is_client then
                    combat:BattleCry()
                end
            end

            local cooldown = is_client and combat:MinAttackPeriod() or combat.min_attack_period
            if not is_client or cooldown > 0 then
                inst.sg:SetTimeout(math.max(cooldown, 13 * FRAMES))
            end
            if is_client and action ~= nil then
                inst:PerformPreviewBufferedAction()
            end
        end,

        timeline = {
            TimeEvent(SIGNATURE_HIT_FRAME * FRAMES, function(inst)
                if inst.sg.statemem.signature_step ~= nil then
                    AdvanceSignatureStep(inst)
                    CommitAttack(inst, is_client)
                end
            end),
            TimeEvent(DEFAULT_HIT_FRAME * FRAMES, function(inst)
                if inst.sg.statemem.signature_step == nil then
                    CommitAttack(inst, is_client)
                end
            end),
        },

        ontimeout = function(inst)
            inst.sg:RemoveStateTag("attack")
            inst.sg:AddStateTag("idle")
        end,

        events = {
            EventHandler("equip", function(inst)
                inst.sg:GoToState("idle")
            end),
            EventHandler("unequip", function(inst)
                inst.sg:GoToState("idle")
            end),
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            local combat = is_client and inst.replica.combat or inst.components.combat
            inst.AnimState:SetDeltaTimeMultiplier(1)
            if not is_client then
                combat:SetTarget(nil)
            end
            if inst.sg:HasStateTag("abouttoattack") then
                combat:CancelAttack()
            end
        end,
    }
end

local function RestoreFlight(inst)
    local mem = inst.sg.statemem
    if mem.collision_mask ~= nil then
        inst.Physics:SetCollisionMask(mem.collision_mask)
        mem.collision_mask = nil
        inst.components.health:SetInvincible(mem.was_invincible)
    end
    inst.Physics:Stop()
    inst.Physics:SetMotorVel(0, 0, 0)
end

local WORM_LEAP_STATE = "kiritzuka_worm_leap"

-- Leaping out of the worm, the way a player hops off a boat: up, across, and down.
local worm_leap_state = State{
    name = WORM_LEAP_STATE,
    tags = { "busy", "doing", "nopredict", "nomorph", "nointerrupt", "noattack", "jumping" },

    onenter = function(inst, data)
        local mem = inst.sg.statemem
        mem.landing = data
        mem.collision_mask = inst.Physics:GetCollisionMask()
        mem.was_invincible = inst.components.health.invincible
        inst.Physics:SetCollisionMask(COLLISION.GROUND)
        inst.components.health:SetInvincible(true)
        inst:ForceFacePoint(data.x, 0, data.z)
        inst.AnimState:PlayAnimation("boat_jump_pre")
        inst.AnimState:PushAnimation("boat_jump_loop", true)
        local x, _, z = inst.Transform:GetWorldPosition()
        local dx, dz = data.x - x, data.z - z
        inst.Physics:SetMotorVel(math.sqrt(dx * dx + dz * dz) / (LEAP_FRAMES * FRAMES), 0, 0)
        inst.sg:SetTimeout(40 * FRAMES)
    end,

    timeline = {
        TimeEvent(LEAP_FRAMES * FRAMES, function(inst)
            local mem = inst.sg.statemem
            RestoreFlight(inst)
            inst.Physics:Teleport(mem.landing.x, 0, mem.landing.z)
            inst.AnimState:PlayAnimation("boat_jump_pst")
            inst.sg:RemoveStateTag("noattack")
            inst.sg:RemoveStateTag("jumping")
            inst.sg:RemoveStateTag("nointerrupt")
            mem.landed = true
        end),
    },

    events = {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() and inst.sg.statemem.landed then
                inst.sg:GoToState("idle")
            end
        end),
    },

    ontimeout = function(inst)
        inst.sg:GoToState("idle")
    end,

    onexit = function(inst)
        local mem = inst.sg.statemem
        -- Cut short in the air, she still comes down where she was headed.
        if not mem.landed then
            inst.Physics:Teleport(mem.landing.x, 0, mem.landing.z)
        end
        RestoreFlight(inst)
    end,
}

local slam_timeline = {
    TimeEvent(8 * FRAMES, function(inst)
        local mem = inst.sg.statemem
        local pos = inst:GetSlamLanding(mem.target, mem.origin)
        if pos == nil then
            inst.sg:GoToState("idle")
            return
        end
        inst:StartSlamCooldown()
        mem.collision_mask = inst.Physics:GetCollisionMask()
        mem.was_invincible = inst.components.health.invincible
        mem.airborne = true
        inst.Physics:SetCollisionMask(COLLISION.GROUND)
        inst.components.health:SetInvincible(true)
        inst.sg:AddStateTag("noattack")
        inst.sg:AddStateTag("jumping")
        inst.Transform:SetEightFaced()
        inst.AnimState:PlayAnimation("atk_leap")
        inst.SoundEmitter:PlaySound("dontstarve/common/deathpoof")
        inst:SpawnSlamCrater(mem.origin)
        mem.landing = pos
        local x, _, z = inst.Transform:GetWorldPosition()
        local dx, dz = pos.x - x, pos.z - z
        local distance = math.sqrt(dx * dx + dz * dz)
        if distance > 0 then
            inst:ForceFacePoint(pos.x, 0, pos.z)
            inst.Physics:SetMotorVel(distance / (LEAP_FRAMES * FRAMES), 0, 0)
        end
    end),
    TimeEvent((8 + LEAP_FRAMES) * FRAMES, function(inst)
        local mem = inst.sg.statemem
        -- A target lost mid-air, likely with weak mobs, still lands on the planned point.
        local pos = inst:GetSlamLanding(mem.target, mem.origin) or mem.landing
        if not inst:IsSlamPointSafe(pos) then
            inst.sg:GoToState("idle")
            return
        end
        mem.landing = pos
        inst.Physics:Stop()
        inst.Physics:SetMotorVel(0, 0, 0)
        inst.Physics:Teleport(pos.x, 0, pos.z)
        if mem.target:IsValid() then
            inst:ForceFacePoint(mem.target.Transform:GetWorldPosition())
        end
        inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")
    end),
    TimeEvent(SLAM_IMPACT_FRAME * FRAMES, function(inst)
        local mem = inst.sg.statemem
        if not inst:IsSlamPointSafe(mem.landing) then
            inst.sg:GoToState("idle")
            return
        end
        mem.impacted = true
        mem.airborne = nil
        RestoreFlight(inst)
        inst.sg:RemoveStateTag("noattack")
        inst.sg:RemoveStateTag("jumping")
        mem.impact, mem.hit_damage = inst:DoSlamImpact(mem.landing, mem.target)
    end),
}

local SLAM_HITS = TUNING.KIRITZUKA_BOSS_SLAM.HITS
for hit = 2, SLAM_HITS do
    table.insert(slam_timeline, TimeEvent((SLAM_IMPACT_FRAME + (hit - 1) * SLAM_HIT_INTERVAL) * FRAMES, function(inst)
        local mem = inst.sg.statemem
        inst:DoSlamHit(mem.impact, mem.hit_damage)
        -- The hits land as one sequence: being struck cannot cut it short.
        if hit == SLAM_HITS then
            mem.finished = true
            inst.sg:RemoveStateTag("nointerrupt")
        end
    end))
end

local slam_state = State{
    name = SLAM_STATE,
    tags = { "busy", "doing", "nopredict", "nomorph", "nointerrupt" },

    onenter = function(inst)
        local action = inst:GetBufferedAction()
        local target = action ~= nil and action.target or nil
        local origin = inst:GetPosition()
        inst:ClearBufferedAction()
        if not inst:TryReleaseSlam(target, origin) then
            inst.sg:GoToState("idle")
            return
        end
        inst.sg.statemem.target = target
        inst.sg.statemem.origin = origin
        inst.components.locomotor:Stop()
        inst.Physics:Stop()
        inst:ForceFacePoint(target.Transform:GetWorldPosition())
        inst.AnimState:PlayAnimation("atk_leap_pre")
        inst.sg:SetTimeout(54 * FRAMES)
    end,

    timeline = slam_timeline,

    events = {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() then
                if inst.sg.statemem.finished then
                    inst.sg:GoToState("idle")
                end
            end
        end),
    },

    ontimeout = function(inst)
        inst.sg:GoToState("idle")
    end,

    onexit = function(inst)
        local mem = inst.sg.statemem
        if mem.airborne then
            inst.Physics:Teleport(mem.origin.x, 0, mem.origin.z)
        end
        RestoreFlight(inst)
        inst.Transform:SetFourFaced()
    end,
}

local sustained_parry_state = State{
    name = SUSTAINED_PARRY_STATE,
    tags = { "busy", "nopredict", "nomorph", "notalking" },

    onenter = function(inst, data)
        inst.components.locomotor:Stop()
        inst:ClearBufferedAction()
        inst:ForceFacePoint(data.x, 0, data.z)
        PlayGuardPose(inst)
        inst.SoundEmitter:PlaySound("dontstarve/wilson/hit")
        inst.sg.statemem.parry_time = GetTime()
    end,

    onupdate = function(inst)
        if GetTime() - inst.sg.statemem.parry_time > SUSTAINED_PARRY_LINGER then
            LowerGuard(inst)
            return
        end
        inst.Physics:SetMotorVel(-SUSTAINED_PARRY_SPEED, 0, 0)
    end,

    events = {
        EventHandler("unequip", function(inst)
            inst.sg:GoToState("idle")
        end),
    },

    onexit = function(inst)
        inst.Physics:Stop()
    end,
}

local function EndDashFlight(inst)
    local mem = inst.sg.statemem
    if mem.collision_mask ~= nil then
        inst.Physics:SetCollisionMask(mem.collision_mask)
        mem.collision_mask = nil
        inst.components.health:SetInvincible(mem.was_invincible)
    end
    inst.Physics:Stop()
    inst.Physics:SetMotorVel(0, 0, 0)
end

local dash_state = State{
    name = DASH_STATE,
    tags = { "busy", "doing", "nopredict", "nomorph", "nointerrupt" },

    onenter = function(inst, data)
        local mem = inst.sg.statemem
        if data == nil then
            -- Routed in from the attack that released the readied dash.
            local action = inst:GetBufferedAction()
            local target = action ~= nil and action.target or nil
            inst:ClearBufferedAction()
            if not inst:TryReleaseDash(target) then
                inst.sg:GoToState("idle")
                return
            end
            if inst:IsDashAtSea(target) then
                inst.sg:GoToState(DASH_SEA_STATE, target)
                return
            end
            data = { stage = 1, target = target, angle = inst:GetDashAngle(target) }
        end
        mem.dash_stage, mem.target, mem.base_angle = data.stage, data.target, data.angle
        mem.line_angle = data.angle + (data.stage - 1) * DASH_LINE_TURN
        inst.components.locomotor:Stop()
        inst.Physics:Stop()
        inst:ClearBufferedAction()
        if data.stage > 1 then
            -- Each line needs its own side of the target, so the player vanishes round to it.
            local start = inst:GetDashPoint(mem.target, mem.line_angle)
            if start == nil then
                inst.sg:GoToState("idle")
                return
            end
            inst:SpawnDashBlink()
            inst.Physics:Teleport(start.x, 0, start.z)
            inst:SpawnDashBlink()
        end
        mem.to = inst:GetDashPoint(mem.target, mem.line_angle + math.pi)
        if mem.to == nil then
            inst.sg:GoToState("idle")
            return
        end
        inst:ForceFacePoint(mem.to.x, 0, mem.to.z)
        inst.AnimState:SetDeltaTimeMultiplier(2)
        inst.AnimState:PlayAnimation("lunge_pre")
        inst.sg:SetTimeout(45 * FRAMES)
    end,

    onupdate = function(inst)
        local mem = inst.sg.statemem
        if mem.sweep_from ~= nil then
            local pos = inst:GetPosition()
            inst:SweepDash(mem.sweep_from, pos, mem.dash_stage, mem.hit)
            mem.sweep_from = pos
        end
    end,

    timeline = {
        TimeEvent(DASH_LAUNCH_FRAME * FRAMES, function(inst)
            local mem = inst.sg.statemem
            if mem.dash_stage == 1 then
                inst:StartDashCooldown()
            end
            mem.from = inst:GetPosition()
            -- The target may have moved during the wind-up; a lost one keeps the planned end.
            if inst:CanDashHit(mem.target) then
                mem.to = inst:GetDashPoint(mem.target, mem.line_angle + math.pi) or mem.to
            end
            inst:ForceFacePoint(mem.to.x, 0, mem.to.z)
            local dx, dz = mem.to.x - mem.from.x, mem.to.z - mem.from.z
            local distance = math.sqrt(dx * dx + dz * dz)
            mem.sweep_from, mem.hit = mem.from, {}
            mem.collision_mask = inst.Physics:GetCollisionMask()
            mem.was_invincible = inst.components.health.invincible
            inst.Physics:SetCollisionMask(COLLISION.GROUND)
            inst.components.health:SetInvincible(true)
            inst.sg:AddStateTag("noattack")
            inst.sg:AddStateTag("jumping")
            inst.AnimState:SetDeltaTimeMultiplier(1)
            inst.AnimState:PlayAnimation("lunge_pst")
            inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")
            inst:StartDashFx()
            inst.Physics:SetMotorVel(distance / (DASH_TRAVEL_FRAMES * FRAMES), 0, 0)
        end),
        TimeEvent((DASH_LAUNCH_FRAME + DASH_TRAVEL_FRAMES) * FRAMES, function(inst)
            local mem = inst.sg.statemem
            EndDashFlight(inst)
            -- A boat can sail away from the planned end in flight; go back rather than land in the water.
            if not inst:IsSlamPointSafe(mem.to) then
                mem.to = mem.from
            end
            inst.Physics:Teleport(mem.to.x, 0, mem.to.z)
            inst.sg:RemoveStateTag("noattack")
            inst.sg:RemoveStateTag("jumping")
            inst:FinishDash(mem.sweep_from, mem.to, mem.dash_stage, mem.target, mem.hit)
            mem.sweep_from = nil
            mem.finished = mem.dash_stage >= DASH_STAGES or not inst:CanDashHit(mem.target)
            if mem.finished then
                inst.sg:RemoveStateTag("nointerrupt")
            end
        end),
        TimeEvent((DASH_LAUNCH_FRAME + DASH_TRAVEL_FRAMES + DASH_RECOVER_FRAMES) * FRAMES, function(inst)
            local mem = inst.sg.statemem
            if not mem.finished then
                inst.sg:GoToState(DASH_STATE, { stage = mem.dash_stage + 1, target = mem.target, angle = mem.base_angle })
            end
        end),
    },

    events = {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() and inst.AnimState:IsCurrentAnimation("lunge_pst") then
                inst.sg:GoToState("idle")
            end
        end),
    },

    ontimeout = function(inst)
        inst.sg:GoToState("idle")
    end,

    onexit = function(inst)
        EndDashFlight(inst)
        inst.AnimState:SetDeltaTimeMultiplier(1)
    end,
}

-- Moving too fast to touch, as in the dash's flight, but what she is fighting still has to want her.
-- Faded out rather than hidden: a hidden entity stops being a valid target, and everything hunting her drops it.
local function VanishForFlurry(inst)
    local mem = inst.sg.statemem
    mem.vanished = true
    mem.was_invincible = inst.components.health.invincible
    inst.components.health:SetInvincible(true)
    inst.sg:AddStateTag("noattack")
    inst.sg:AddStateTag("iframeskeepaggro")
    inst:SpawnDashBlink()
    inst.AnimState:SetMultColour(0, 0, 0, 0)
    inst.DynamicShadow:Enable(false)
end

-- A swing that never vanished just plays out; otherwise she is simply standing there when she reappears.
local function EndFlurry(inst)
    local mem = inst.sg.statemem
    if not mem.vanished then
        inst.sg:GoToState("idle", true)
        return
    end
    if mem.landing ~= nil and inst:IsSlamPointSafe(mem.landing) then
        inst.Physics:Teleport(mem.landing.x, 0, mem.landing.z)
    end
    inst:SpawnDashBlink()
    if mem.target:IsValid() then
        inst:ForceFacePoint(mem.target.Transform:GetWorldPosition())
    end
    inst.sg:GoToState("idle")
end

local function QueueFlurryHit(inst)
    inst.sg:SetTimeout(math.random(FLURRY_MIN_INTERVAL, FLURRY_MAX_INTERVAL) * FRAMES)
end

-- She lands the first hit herself and vanishes; the blur of hits comes from the images around the target.
local flurry_state = State{
    name = FLURRY_STATE,
    tags = { "busy", "doing", "nopredict", "nomorph", "nointerrupt" },

    onenter = function(inst)
        local action = inst:GetBufferedAction()
        local target = action ~= nil and action.target or nil
        inst:ClearBufferedAction()
        if not inst:TryReleaseFlurry(target) then
            inst.sg:GoToState("idle")
            return
        end
        inst.sg.statemem.target = target
        inst.components.locomotor:Stop()
        inst:ForceFacePoint(target.Transform:GetWorldPosition())
        inst.AnimState:PlayAnimation("atk_pre")
        inst.AnimState:PushAnimation("atk", false)
    end,

    timeline = {
        TimeEvent(FLURRY_FIRST_HIT_FRAME * FRAMES, function(inst)
            local mem = inst.sg.statemem
            if inst:DoFlurryHit(mem.target, 1) then
                mem.hit = 1
                VanishForFlurry(inst)
                QueueFlurryHit(inst)
            else
                EndFlurry(inst)
            end
        end),
    },

    -- One more wait follows the last hit, so she reappears on the same uneven beat.
    ontimeout = function(inst)
        local mem = inst.sg.statemem
        mem.hit = mem.hit + 1
        if mem.hit <= FLURRY_HITS and inst:DoFlurryHit(mem.target, mem.hit) then
            QueueFlurryHit(inst)
        else
            EndFlurry(inst)
        end
    end,

    onexit = function(inst)
        local mem = inst.sg.statemem
        if mem.vanished then
            inst.components.health:SetInvincible(mem.was_invincible)
            inst.AnimState:SetMultColour(1, 1, 1, 1)
            inst.DynamicShadow:Enable(true)
        end
    end,
}

local function LaunchDashLeg(inst, to)
    local mem = inst.sg.statemem
    mem.from, mem.to, mem.sweep_from, mem.hit = inst:GetPosition(), to, inst:GetPosition(), {}
    inst:ForceFacePoint(to.x, 0, to.z)
    local dx, dz = to.x - mem.from.x, to.z - mem.from.z
    inst.AnimState:SetDeltaTimeMultiplier(1)
    inst.AnimState:PlayAnimation("lunge_pst")
    inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")
    inst:StartDashFx()
    inst.Physics:SetMotorVel(math.sqrt(dx * dx + dz * dz) / (DASH_TRAVEL_FRAMES * FRAMES), 0, 0)
end

-- One unbroken flight there and back: stopping out over the water would drown the player.
local dash_sea_state = State{
    name = DASH_SEA_STATE,
    tags = { "busy", "doing", "nopredict", "nomorph", "nointerrupt" },

    onenter = function(inst, target)
        local mem = inst.sg.statemem
        mem.target = target
        mem.home = inst:GetDashHome()
        inst.components.locomotor:Stop()
        inst.Physics:Stop()
        inst:ClearBufferedAction()
        inst:ForceFacePoint(target.Transform:GetWorldPosition())
        inst.AnimState:SetDeltaTimeMultiplier(2)
        inst.AnimState:PlayAnimation("lunge_pre")
        inst.sg:SetTimeout(45 * FRAMES)
    end,

    onupdate = function(inst)
        local mem = inst.sg.statemem
        if mem.sweep_from ~= nil then
            local pos = inst:GetPosition()
            inst:SweepDash(mem.sweep_from, pos, mem.stage, mem.hit)
            mem.sweep_from = pos
        end
    end,

    timeline = {
        TimeEvent(DASH_LAUNCH_FRAME * FRAMES, function(inst)
            local mem = inst.sg.statemem
            inst:StartDashCooldown()
            mem.collision_mask = inst.Physics:GetCollisionMask()
            mem.was_invincible = inst.components.health.invincible
            mem.airborne = true
            inst.Physics:SetCollisionMask(COLLISION.GROUND)
            inst.components.health:SetInvincible(true)
            inst.sg:AddStateTag("noattack")
            inst.sg:AddStateTag("jumping")
            mem.stage = DASH_SEA_OUT_STAGE
            LaunchDashLeg(inst, inst:GetDashTurn(mem.target))
        end),
        TimeEvent((DASH_LAUNCH_FRAME + DASH_TRAVEL_FRAMES) * FRAMES, function(inst)
            local mem = inst.sg.statemem
            inst.Physics:Stop()
            inst.Physics:Teleport(mem.to.x, 0, mem.to.z)
            inst:FinishDash(mem.sweep_from, mem.to, mem.stage, mem.target, mem.hit)
            inst:SpawnDashSplash(mem.to.x, mem.to.z)
            mem.stage = DASH_SEA_BACK_STAGE
            LaunchDashLeg(inst, inst:ResolveDashHome(mem.home))
        end),
        TimeEvent((DASH_LAUNCH_FRAME + 2 * DASH_TRAVEL_FRAMES) * FRAMES, function(inst)
            local mem = inst.sg.statemem
            local home = inst:ResolveDashHome(mem.home)
            mem.airborne = nil
            EndDashFlight(inst)
            inst.Physics:Teleport(home.x, 0, home.z)
            inst:FinishDash(mem.sweep_from, home, mem.stage, mem.target, mem.hit)
            inst:SpawnDashSplash(home.x, home.z)
            mem.sweep_from = nil
            mem.landed = true
            inst.sg:RemoveStateTag("noattack")
            inst.sg:RemoveStateTag("jumping")
            inst.sg:RemoveStateTag("nointerrupt")
        end),
    },

    events = {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() and inst.sg.statemem.landed then
                inst.sg:GoToState("idle")
            end
        end),
    },

    ontimeout = function(inst)
        inst.sg:GoToState("idle")
    end,

    onexit = function(inst)
        local mem = inst.sg.statemem
        -- Cut short in flight, the player must not be left over the water.
        if mem.airborne then
            local home = inst:ResolveDashHome(mem.home)
            inst.Physics:Teleport(home.x, 0, home.z)
        end
        EndDashFlight(inst)
        inst.AnimState:SetDeltaTimeMultiplier(1)
    end,
}

local HOMERUN_STATE = "kiritzuka_homerun_charge"
local HOMERUN_SWING_STATE = "kiritzuka_homerun_swing"
local HOMERUN_HIT_FRAME = 2

-- Taking a blow on the guard. The native parry_knockback can't be used, as it plays its own pose;
-- the push is its formula: stronger up close, fading fast.
local guard_hit_state = State{
    name = GUARD_HIT_STATE,
    tags = { "busy", "nopredict", "nomorph" },

    onenter = function(inst, data)
        local mem = inst.sg.statemem
        mem.hold = data.timeleft
        inst.components.locomotor:Stop()
        inst:ClearBufferedAction()
        inst.AnimState:PlayAnimation(GUARD_BLOCK_ANIM)
        inst.AnimState:PushAnimation(GUARD_LOOP_ANIM, true)
        inst.SoundEmitter:PlaySound("dontstarve/wilson/hit")
        local knock = data.knockbackdata
        local x, y, z = knock.knocker.Transform:GetWorldPosition()
        local distsq = inst:GetDistanceSqToPoint(x, y, z)
        local rangesq = knock.radius * knock.radius
        local k = distsq < rangesq and .3 * distsq / rangesq - 1 or -.7
        inst:ForceFacePoint(x, y, z)
        mem.speed = (knock.strengthmult or 1) * 12 * k
        inst.Physics:SetMotorVel(mem.speed, 0, 0)
        inst.sg:SetTimeout(GUARD_HIT_FRAMES * FRAMES)
    end,

    onupdate = function(inst)
        local mem = inst.sg.statemem
        mem.speed = .75 * mem.speed
        inst.Physics:SetMotorVel(mem.speed, 0, 0)
    end,

    events = {
        EventHandler("unequip", function(inst)
            inst.sg.statemem.hold = nil
        end),
    },

    ontimeout = function(inst)
        local mem = inst.sg.statemem
        if mem.hold ~= nil then
            inst.sg:GoToState(GUARD_HOLD_STATE, mem.hold)
        else
            inst.sg:GoToState("idle")
        end
    end,

    onexit = function(inst)
        inst.Physics:Stop()
    end,
}

-- Keeps the guard up a moment after a blow. Idle, so walking or attacking drops it at once.
local guard_hold_state = State{
    name = GUARD_HOLD_STATE,
    tags = { "idle", "nomorph", "notalking" },

    onenter = function(inst, duration)
        -- The blow's animation is still playing, with the loop queued behind it.
        inst.components.locomotor:Stop()
        inst.sg:SetTimeout(duration)
    end,

    ontimeout = LowerGuard,

    events = {
        EventHandler("unequip", function(inst)
            inst.sg:GoToState("idle")
        end),
    },
}

-- Not busy, so moving or acting drops the charge through the native handlers, at no cost.
local homerun_state = State{
    name = HOMERUN_STATE,
    tags = { "nomorph", "notalking" },

    onenter = function(inst)
        inst.components.locomotor:Stop()
        inst:ClearBufferedAction()
        inst.AnimState:PlayAnimation("scythe_pre")
        inst.AnimState:PushAnimation("scythe_lag", true)
        inst.sg.statemem.charge_start = GetTime()
        inst.sg:SetTimeout(TUNING.KIRITZUKA_HOMERUN.MAX_HOLD)
    end,

    onupdate = function(inst)
        local mem = inst.sg.statemem
        if not mem.full and GetTime() - mem.charge_start >= TUNING.KIRITZUKA_HOMERUN.CHARGE_TIME then
            mem.full = true
            inst.components.talker:Say(STRINGS.SKILL.KIRITZUKA_HOMERUN_READY, 2, true)
        end
    end,

    ontimeout = function(inst)
        inst:ReleaseHomeRun()
    end,
}

local homerun_swing_state = State{
    name = HOMERUN_SWING_STATE,
    tags = { "busy", "nopredict", "nomorph", "nointerrupt", "attack" },

    onenter = function(inst, data)
        local mem = inst.sg.statemem
        mem.charge = data.charge
        mem.homerun = true
        -- Read by the crit roll: a full charge always crits, like the combo's scythe.
        mem.signature_crit = data.charge >= 1 or nil
        inst.components.locomotor:Stop()
        inst.AnimState:SetDeltaTimeMultiplier(1.5)
        inst.AnimState:PlayAnimation("scythe_loop")
        inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")
        inst.sg:SetTimeout(30 * FRAMES)
    end,

    timeline = {
        TimeEvent(HOMERUN_HIT_FRAME * FRAMES, function(inst)
            inst:DoHomeRunHit(inst.sg.statemem.charge)
            inst.sg:RemoveStateTag("nointerrupt")
        end),
    },

    events = {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() then
                inst.sg:GoToState("idle")
            end
        end),
    },

    ontimeout = function(inst)
        inst.sg:GoToState("idle")
    end,

    onexit = function(inst)
        inst.AnimState:SetDeltaTimeMultiplier(1)
    end,
}

local COUNTER_STATE = "kiritzuka_counter"
local COUNTER_SWING_STATE = "kiritzuka_counter_swing"
local COUNTER_HIT_FRAME = 5

-- Not busy, so moving or acting drops the stance through the native handlers.
local counter_state = State{
    name = COUNTER_STATE,
    tags = { "nomorph", "notalking" },

    onenter = function(inst)
        inst.components.locomotor:Stop()
        inst:ClearBufferedAction()
        PlayGuardPose(inst)
        inst.sg:SetTimeout(TUNING.KIRITZUKA_COUNTER.WINDOW)
    end,

    ontimeout = function(inst)
        local mem = inst.sg.statemem
        if mem.whiffed then
            inst.sg:GoToState("idle", true)
            return
        end
        -- Nothing came: the stance is left open for a moment, and that is the punishment.
        mem.whiffed = true
        inst.sg:AddStateTag("busy")
        inst:StartCounterWhiffCooldown()
        inst.AnimState:PlayAnimation(GUARD_PST_ANIM)
        inst.sg:SetTimeout(TUNING.KIRITZUKA_COUNTER.WHIFF_TIME)
    end,
}

local counter_swing_state = State{
    name = COUNTER_SWING_STATE,
    tags = { "busy", "nopredict", "nomorph", "nointerrupt", "attack" },

    onenter = function(inst, data)
        local mem = inst.sg.statemem
        mem.target, mem.blocked = data.target, data.blocked
        -- Read by the crit roll, the same way the combo's scythe guarantees its crit.
        mem.signature_crit = true
        inst.components.locomotor:Stop()
        inst:ForceFacePoint(data.target.Transform:GetWorldPosition())
        inst.AnimState:SetDeltaTimeMultiplier(8 / COUNTER_HIT_FRAME)
        inst.AnimState:PlayAnimation("atk_pre")
        inst.AnimState:PushAnimation("atk", false)
        inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")
        inst.sg:SetTimeout(30 * FRAMES)
    end,

    timeline = {
        TimeEvent(COUNTER_HIT_FRAME * FRAMES, function(inst)
            local mem = inst.sg.statemem
            inst:DoCounterHit(mem.target, mem.blocked)
            inst.sg:RemoveStateTag("nointerrupt")
        end),
    },

    events = {
        EventHandler("animqueueover", function(inst)
            if inst.AnimState:AnimDone() then
                inst.sg:GoToState("idle")
            end
        end),
    },

    ontimeout = function(inst)
        inst.sg:GoToState("idle")
    end,

    onexit = function(inst)
        inst.AnimState:SetDeltaTimeMultiplier(1)
    end,
}

local POUNCE_SWAT_STATE = "kiritzuka_pounce_swat"
local POUNCE_SWAT_SPEED = 1.6

-- The pouncer is thrown back the moment it arrives, so this starts on the strike, with no wind-up.
local pounce_swat_state = State{
    name = POUNCE_SWAT_STATE,
    tags = { "busy", "nopredict", "nomorph" },

    onenter = function(inst, pouncer)
        inst.components.locomotor:Stop()
        inst:ClearBufferedAction()
        inst:ForceFacePoint(pouncer.Transform:GetWorldPosition())
        inst.AnimState:SetDeltaTimeMultiplier(POUNCE_SWAT_SPEED)
        inst.AnimState:PlayAnimation("atk")
        inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")
    end,

    events = {
        EventHandler("animover", function(inst)
            if inst.AnimState:AnimDone() then
                inst.sg:GoToState("idle")
            end
        end),
    },

    onexit = function(inst)
        inst.AnimState:SetDeltaTimeMultiplier(1)
    end,
}

local DUMBBELL_PRE_STATE = "kiritzuka_dumbbell_pre"
local DUMBBELL_LOOP_STATE = "kiritzuka_dumbbell_loop"
local DUMBBELL_PST_STATE = "kiritzuka_dumbbell_pst"

-- The native lifting states need mightiness at every step, so these replay them purely for show.
local function ExitDumbbellEarly(inst)
    if not inst.sg.statemem.dumbbell_anim_done then
        inst.components.dumbbelllifter:StopLifting()
        inst.AnimState:ClearOverrideSymbol("swap_dumbbell")
    end
end

local dumbbell_states = {
    State{
        name = DUMBBELL_PRE_STATE,
        tags = { "doing", "nodangle", "lifting_dumbbell" },

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst:PerformBufferedAction()

            local dumbbell = inst.components.dumbbelllifter.dumbbell
            if dumbbell == nil or not dumbbell:IsValid() then
                inst.sg:GoToState("idle")
                return
            end
            inst.AnimState:OverrideSymbol("swap_dumbbell", dumbbell.swap_dumbbell, dumbbell.swap_dumbbell)
            inst.AnimState:PlayAnimation("dumbbell_normal_pre")
        end,

        events = {
            EventHandler("stopliftingdumbbell", function(inst)
                inst.sg.statemem.queue_stop = true
            end),
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg.statemem.dumbbell_anim_done = true
                    inst.sg:GoToState(inst.sg.statemem.queue_stop and DUMBBELL_PST_STATE or DUMBBELL_LOOP_STATE)
                end
            end),
        },

        onexit = ExitDumbbellEarly,
    },

    State{
        name = DUMBBELL_LOOP_STATE,
        tags = { "doing", "nodangle", "lifting_dumbbell" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("dumbbell_normal_loop")
        end,

        events = {
            EventHandler("stopliftingdumbbell", function(inst, data)
                if data ~= nil and data.instant then
                    inst.sg:GoToState("idle")
                else
                    inst.sg.statemem.queue_stop = true
                end
            end),
            EventHandler("animover", function(inst)
                inst.sg.statemem.dumbbell_anim_done = true
                if inst.sg.statemem.queue_stop or inst.components.dumbbelllifter.dumbbell == nil then
                    inst.sg:GoToState(DUMBBELL_PST_STATE)
                else
                    inst.sg:GoToState(DUMBBELL_LOOP_STATE)
                end
            end),
        },

        onexit = ExitDumbbellEarly,
    },

    State{
        name = DUMBBELL_PST_STATE,
        tags = { "doing", "nodangle", "lifting_dumbbell" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("dumbbell_normal_pst")
        end,

        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },

        onexit = function(inst)
            inst.components.dumbbelllifter:StopLifting()
            inst.AnimState:ClearOverrideSymbol("swap_dumbbell")
        end,
    },
}

local function MakeDumbbellClientState(name, server_states, animation, queued)
    return State{
        name = name,
        tags = { "doing", "lifting_dumbbell" },
        server_states = server_states,

        onenter = function(inst)
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation(animation)
            if queued ~= nil then
                inst.AnimState:PushAnimation(queued, false)
            end
            inst:PerformPreviewBufferedAction()
            inst.sg:SetTimeout(2)
        end,

        onupdate = function(inst)
            if inst.sg:ServerStateMatches() then
                if inst.entity:FlattenMovementPrediction() then
                    inst.sg:GoToState("idle", "noanim")
                end
            elseif inst.bufferedaction == nil then
                inst.sg:GoToState("idle", true)
            end
        end,

        ontimeout = function(inst)
            inst:ClearBufferedAction()
            inst.sg:GoToState("idle", true)
        end,
    }
end

AddStategraphState("wilson", MakeAttackState(false))
for _, state in ipairs(dumbbell_states) do
    AddStategraphState("wilson", state)
end
AddStategraphState("wilson_client", MakeDumbbellClientState(DUMBBELL_PRE_STATE,
    { DUMBBELL_PRE_STATE, DUMBBELL_LOOP_STATE }, "dumbbell_normal_pre", "dumbbell_normal_lag"))
AddStategraphState("wilson_client", MakeDumbbellClientState(DUMBBELL_PST_STATE,
    { DUMBBELL_PST_STATE }, "dumbbell_normal_pst"))
AddStategraphState("wilson", guard_hit_state)
AddStategraphState("wilson", guard_hold_state)
AddStategraphState("wilson", worm_leap_state)
AddStategraphState("wilson", dash_state)
AddStategraphState("wilson", dash_sea_state)
AddStategraphState("wilson", flurry_state)
AddStategraphState("wilson", homerun_state)
AddStategraphState("wilson", homerun_swing_state)
AddStategraphState("wilson", counter_state)
AddStategraphState("wilson", counter_swing_state)
AddStategraphState("wilson", pounce_swat_state)
AddStategraphState("wilson", sustained_parry_state)
AddStategraphState("wilson", slam_state)
AddStategraphState("wilson_client", MakeAttackState(true))

AddStategraphPostInit("wilson", function(sg)
    local lift_actionhandler = sg.actionhandlers[ACTIONS.LIFT_DUMBBELL].deststate
    sg.actionhandlers[ACTIONS.LIFT_DUMBBELL].deststate = function(inst, action, ...)
        if inst.prefab ~= "kiritzuka" then
            return lift_actionhandler(inst, action, ...)
        end
        return inst.components.dumbbelllifter:IsLifting(action.invobject) and DUMBBELL_PST_STATE or DUMBBELL_PRE_STATE
    end

    local knockback = sg.events.knockback
    local native_knockback = knockback.fn
    knockback.fn = function(inst, data)
        if inst.ParryKnockback ~= nil and inst:ParryKnockback(data) then
            return
        end
        return native_knockback(inst, data)
    end

    local attack_actionhandler = sg.actionhandlers[ACTIONS.ATTACK].deststate
    sg.actionhandlers[ACTIONS.ATTACK].deststate = function(inst, action, ...)
        if inst.prefab ~= "kiritzuka" then
            return attack_actionhandler(inst, action, ...)
        end
        if inst:IsSlamArmed() then
            return SLAM_STATE
        end
        if inst:IsDashArmed() then
            return DASH_STATE
        end
        if inst:IsFlurryArmed() then
            return FLURRY_STATE
        end
        local destination = attack_actionhandler(inst, action, ...)
        local weapon = inst.components.combat:GetWeapon()
        return GetAttackState(weapon, inst.components.rider, destination)
    end
end)

AddStategraphPostInit("wilson_client", function(sg)
    local lift_actionhandler = sg.actionhandlers[ACTIONS.LIFT_DUMBBELL].deststate
    sg.actionhandlers[ACTIONS.LIFT_DUMBBELL].deststate = function(inst, action, ...)
        if inst.prefab ~= "kiritzuka" then
            return lift_actionhandler(inst, action, ...)
        end
        return inst:HasTag("liftingdumbbell") and DUMBBELL_PST_STATE or DUMBBELL_PRE_STATE
    end

    local attack_actionhandler = sg.actionhandlers[ACTIONS.ATTACK].deststate
    sg.actionhandlers[ACTIONS.ATTACK].deststate = function(inst, action, ...)
        if inst.prefab ~= "kiritzuka" then
            return attack_actionhandler(inst, action, ...)
        end
        local destination = attack_actionhandler(inst, action, ...)
        local combat = inst.replica.combat
        local weapon = combat ~= nil and combat:GetWeapon() or nil
        return GetAttackState(weapon, inst.replica.rider, destination)
    end
end)
