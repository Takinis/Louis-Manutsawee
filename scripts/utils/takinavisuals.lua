local TakinaVisuals = {}
TakinaVisuals.SCALE = 1

local BASE_BANK = hash("wilson")
local TAKINA_BANK = hash("takina_player")

function TakinaVisuals.Apply(anim_state, build)
    local bank = anim_state:GetBankHash()
    if build == "takina" then
        -- Leave temporary chair, mounted, and ghost banks to their stategraphs.
        if bank == BASE_BANK then
            anim_state:SetBank("takina_player")
        end
    elseif bank == TAKINA_BANK then
        anim_state:SetBank("wilson")
    end
end

function TakinaVisuals.Refresh(inst, build)
    if inst:HasTag("playerghost") then
        build = nil
    end
    TakinaVisuals.Apply(inst.AnimState, build)
    if inst.ApplyAnimScale ~= nil then
        inst:ApplyAnimScale("takina_visuals", build == "takina" and TakinaVisuals.SCALE or 1)
    end
end

function TakinaVisuals.ApplyPreview(anim_state, build)
    -- UIAnim owns preview scaling; AnimState:SetScale hides reused UI puppets.
    TakinaVisuals.Apply(anim_state, build)
end

local function Update(inst)
    local anim_state = inst.AnimState
    local build = anim_state:GetSkinBuild()
    if build == nil or build == "" then
        build = anim_state:GetBuild()
    end
    TakinaVisuals.Refresh(inst, build)
end

function TakinaVisuals.Attach(inst)
    if inst._takina_visual_task == nil then
        -- Some native state exits restore wilson without reapplying the skin.
        inst._takina_visual_task = inst:DoPeriodicTask(0, Update)
    end
    Update(inst)
end

return TakinaVisuals
