local ex_fns = require "prefabs/player_common_extensions"

--[[
    config = {
        anims,       -- only these animations leave a trail
        duration,    -- how long to keep trailing after Start
        spacing,     -- world distance between images
        lifetime,    -- how long each image takes to fade
        peak_alpha,
        colour,      -- {r, g, b}
        max_jump,    -- a longer move in one update is a teleport or lag spike, not the dash
    }
]]

local function SetAlpha(fx, a)
    -- The add colour fades with the alpha, or the silhouette would stay bright until it is hidden.
    local colour = fx.config.colour
    fx.AnimState:SetMultColour(0, 0, 0, a)
    fx.AnimState:SetAddColour(colour[1] * a, colour[2] * a, colour[3] * a, 0)
end

local function Fx_OnUpdate(fx, dt)
    fx._t = fx._t + dt
    local lifetime = fx.config.lifetime
    if fx._t < lifetime then
        local a = Remap(fx._t, 0, lifetime, 1, 0)
        SetAlpha(fx, a * a * fx.config.peak_alpha)
    elseif fx.owner:IsValid() then
        fx.components.updatelooper:RemoveOnUpdateFn(Fx_OnUpdate)
        fx:RemoveFromScene()
        fx.entity:SetParent(fx.owner.entity)
        fx.Transform:SetPosition(0, 0, 0)

        if fx.owner._afterimage_pool == nil then
            fx.owner._afterimage_pool = {fx}
        else
            table.insert(fx.owner._afterimage_pool, fx)
        end
    else
        fx:Remove()
    end
end

local function GetFx(inst, config)
    local fx
    if inst._afterimage_pool ~= nil and #inst._afterimage_pool > 0 then
        fx = table.remove(inst._afterimage_pool)
        fx.entity:SetParent(nil)
        fx:ReturnToScene()
    else
        fx = CreateEntity()

        fx:AddTag("NOCLICK")
        fx:AddTag("FX")
        fx:AddTag("nointerpolate")
        --[[Non-networked entity]]
        fx.entity:SetCanSleep(TheWorld.ismastersim)
        fx.persists = false

        fx.entity:AddTransform()
        fx.entity:AddAnimState()

        fx.Transform:SetFourFaced()

        fx.AnimState:SetBank("wilson")
        fx.AnimState:SetScale(0.88, 0.9, 1)
        ex_fns.SetupBaseSymbolVisibility(fx)

        fx:AddComponent("updatelooper")

        fx.owner = inst
    end

    fx.config = config
    fx.AnimState:SetBuild(inst.AnimState:GetBuild())
    SetAlpha(fx, config.peak_alpha)

    fx.components.updatelooper:AddOnUpdateFn(Fx_OnUpdate)
    fx._t = 0

    return fx
end

local function GetCurrentAnim(inst, config)
    for _, anim in ipairs(config.anims) do
        if inst.AnimState:IsCurrentAnimation(anim) then
            return anim
        end
    end
end

local function PostUpdate(inst)
    if GetTime() >= inst._afterimage_end_time then
        inst._afterimage_end_time = nil
        inst._afterimage_pos = nil
        inst._afterimage_config = nil
        inst.components.updatelooper:RemovePostUpdateFn(PostUpdate)
        return
    end

    local config = inst._afterimage_config
    -- The start point is kept until the animation shows up, so a client that gets it late still draws the whole line.
    local anim = GetCurrentAnim(inst, config)
    if anim == nil then
        return
    end

    local pos = inst._afterimage_pos
    local x, y, z = inst.Transform:GetWorldPosition()
    local dx, dz = x - pos.x, z - pos.z
    local distance = math.sqrt(dx * dx + dz * dz)
    local count = math.floor(distance / config.spacing)
    if count <= 0 then
        return
    elseif distance > config.max_jump then
        pos.x, pos.z = x, z
        return
    end

    -- Spaced by distance, so the trail looks the same at any speed or frame rate.
    local step = config.spacing / distance
    local rotation = inst.Transform:GetRotation()
    local frame = inst.AnimState:GetCurrentAnimationFrame()
    for i = 1, count do
        local fx = GetFx(inst, config)
        fx.Transform:SetPosition(pos.x + dx * step * i, y, pos.z + dz * step * i)
        fx.Transform:SetRotation(rotation)
        fx.AnimState:PlayAnimation(anim)
        fx.AnimState:Pause()
        fx.AnimState:SetFrame(frame)
    end
    pos.x, pos.z = pos.x + dx * step * count, pos.z + dz * step * count
end

local function Start(inst, config)
    if TheNet:IsDedicated() then
        return
    end

    if inst.components.updatelooper == nil then
        inst:AddComponent("updatelooper")
    end

    if inst._afterimage_end_time == nil then
        inst._afterimage_pos = inst:GetPosition()
        inst.components.updatelooper:AddPostUpdateFn(PostUpdate)
    end
    inst._afterimage_config = config
    inst._afterimage_end_time = GetTime() + config.duration
end

return {
    Start = Start,
}
