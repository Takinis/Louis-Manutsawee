local AddStategraphState = AddStategraphState
local AddStategraphPostInit = AddStategraphPostInit
GLOBAL.setfenv(1, GLOBAL)

local REPELLED_STATE = "kiritzuka_repelled"
-- The native knockback's base speed and how fast it wears off.
local REPEL_SPEED = 10
local REPEL_DECAY = 0.075

-- The Hound Batilisk's bank has no knockback animation, which is why native refuses it one.
-- This is the same slide with a flinch standing in for the art.
AddStategraphState("bat", State{
    name = REPELLED_STATE,
    tags = { "busy", "jumping", "nosleep", "nofreeze", "noelectrocute" },

    onenter = function(inst, data)
        local mem = inst.sg.statemem
        inst.components.locomotor:StopMoving()
        inst.AnimState:PlayAnimation("hit")
        inst.AnimState:PushAnimation("fly_loop", true)
        inst:ForceFacePoint(data.knocker.Transform:GetWorldPosition())
        mem.speed, mem.dspeed = -REPEL_SPEED * data.strengthmult, 0
        inst.Physics:SetMotorVelOverride(mem.speed, 0, 0)
    end,

    onupdate = function(inst)
        local mem = inst.sg.statemem
        mem.speed = mem.speed + mem.dspeed
        if mem.speed < 0 then
            mem.dspeed = mem.dspeed + REPEL_DECAY
            inst.Physics:SetMotorVelOverride(mem.speed, 0, 0)
        else
            inst.sg:GoToState("idle")
        end
    end,

    onexit = function(inst)
        inst.Physics:ClearMotorVelOverride()
        inst.Physics:Stop()
    end,
})

-- Every attack starts unseen, so a pounce read earlier says nothing about this one.
local function ForgetReadOnEnter(state)
    local _onenter = state.onenter
    state.onenter = function(inst, ...)
        inst.sg.mem.kiritzuka_pounce_reader = nil
        return _onenter(inst, ...)
    end
end

-- The latch knocks her hat off and equips in one step with nothing to hook, so it is beaten to it each update.
local function RepelBeforeLatch(state, wait_for_attach)
    local _onupdate = state.onupdate
    state.onupdate = function(inst, dt)
        local statemem = inst.sg.statemem
        local target = statemem.target
        if dt > 0 and target ~= nil and target:IsValid() and target.RepelPounce ~= nil then
            target:ReadPounce(inst)
            if (statemem.canattach or not wait_for_attach)
                and inst:IsNear(target, TUNING.KIRITZUKA_POUNCE_REPEL.RANGE)
                and target:RepelPounce(inst) then
                return
            end
        end
        return _onupdate(inst, dt)
    end
end

AddStategraphPostInit("bat", function(sg)
    ForgetReadOnEnter(sg.states.attack)
    ForgetReadOnEnter(sg.states.chomp_attack)
    RepelBeforeLatch(sg.states.chomp_attack, true)
    RepelBeforeLatch(sg.states.chomp_fail)

    local _knockback = sg.events.knockback.fn
    sg.events.knockback.fn = function(inst, data)
        if data ~= nil and data.kiritzuka_repel then
            if not inst.components.health:IsDead() and not inst.sg:HasAnyStateTag("nointerrupt", "noknockback") then
                inst.sg:GoToState(REPELLED_STATE, data)
            end
            return
        end
        return _knockback(inst, data)
    end
end)
