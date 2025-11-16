local MakeKatana = require "prefabs/katana_def"

local function TryStartFx(inst, owner)
    owner = owner
        or inst.components.equippable:IsEquipped() and inst.components.inventoryitem.owner
        or nil

    if owner == nil then
        return
    end

    if inst._vfx_fx_inst == nil then
        inst._vfx_fx_inst = SpawnPrefab("pocketwatch_weapon_fx")
        inst._vfx_fx_inst.entity:AddFollower()
        inst._vfx_fx_inst.entity:SetParent(owner.entity)
        inst._vfx_fx_inst.Follower:FollowSymbol(owner.GUID, "swap_object", 15, 0, 0)
    end
end

local function StopFx(inst)
    if inst._vfx_fx_inst ~= nil then
        inst._vfx_fx_inst:Remove()
        inst._vfx_fx_inst = nil
    end
end

local mortalblade_onattack = function(inst, owner, target)
    if inst.IsShadow(target) or inst.IsLunar(target) then
        target.components.combat:GetAttacked(owner, inst.components.weapon.damage * 10)
    end
end

local function OnRemove(inst)
    TheWorld:PushEvent("ms_forgetkatana", {name = inst.prefab})
end

local function OnSave(inst, data)
    if inst.first_time_unsheathed ~= nil then
        data.first_time_unsheathed = inst.first_time_unsheathed
    end
end

local function OnLoad(inst, data)
    if data ~= nil then
        if inst.first_time_unsheathed ~= nil then
            inst.first_time_unsheathed = data.first_time_unsheathed
        end
    end
end

local mortalblade_master_postinit = function(inst)
    inst.first_time_unsheathed = true

    inst:ListenForEvent("onremove", OnRemove)

    inst.TryStartFx = TryStartFx
    inst.StopFx = StopFx

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    inst.onequip_fn = function(inst, owner)
        inst.TryStartFx(inst, owner)
    end

    inst.onunequip_fn = function(inst, owner)
        inst.StopFx(inst)
    end
end

local tenseiga_onattack = function(inst, owner, target)
    local health = target.components.health
    if health ~= nil then
        if target:HasTag("abigail") then
            owner.components.talker:Say(STRINGS.CHARACTERS.MANUTSAWEE.DESCRIBE.ABIGAIL.PROMPT)
        elseif target:HasTag("ghost") then
            local fx = SpawnPrefab("fx_book_light_upgraded")
            fx.Transform:SetScale(.9, 2.5, 1)
            fx.entity:AddFollower()
            fx.Follower:FollowSymbol(target.GUID)
            owner.components.talker:Say(STRINGS.CHARACTERS.MANUTSAWEE.DESCRIBE.GHOST_KILL)
            target:DoTaskInTime(1, function() health:Kill() end)
        end

        if not (target:HasTag("ghost") and target:HasTag("abigail")) and inst.IsShadow(target) or inst.IsLunar(target) then
            if health:IsInvincible() then
                health:SetInvincible(false)
            end
            health:Kill()
        end
    end
end

local tenseiga_master_postinit = function(inst)
    local _onhaunt = inst.components.hauntable.onhaunt
    local function OnHaunt(inst, player)
        if player ~= nil and player:HasTag("playerghost") then
            player:PushEvent("respawnfromghost", { source = inst, user = inst })
            local fx = SpawnPrefab("fx_book_light_upgraded")
            fx.Transform:SetScale(.9, 2.5, 1)
            fx.entity:AddFollower()
            fx.Follower:FollowSymbol(inst.GUID)
        end

        return _onhaunt(inst, player)
    end

    inst.components.hauntable.onhaunt = OnHaunt

    inst:RemoveComponent("finiteuses")
end

local Spawn_Shadow_Fx = {
    wanda_attack_shadowweapon_old_fx = 1,
    wanda_attack_pocketwatch_old_fx = 1,
    shadow_merm_spawn_poof_fx = 1,
    sanity_lower = 1,
    sanity_raise = 1,
    shadowhand_fx = 1,
    statue_transition = 1,
    abigail_shadow_buff_fx = 1,
    beef_bell_shadow_cursefx = 1,
    voidcloth_boomerang_impact_fx = 1,
    cavehole_flick = 1,
    slurper_respawn = 1,
    fused_shadeling_spawn_fx = 1,
}

local function kage_master_postinit(inst)
    inst.TryStartFx = TryStartFx
    inst.StopFx = StopFx

    local _OnFinished =inst.components.finiteuses.onfinished
    local function OnFinished(inst)
        local owner = inst.components.inventoryitem:GetGrandOwner()
        local item = SpawnPrefab("katanablade")
        if owner ~= nil then
            owner.components.inventory:GiveItem(item)
        else
            local x, y, z = inst.Transform:GetWorldPosition()
            item.Transform:SetPosition(x, y, z)
        end

        if _OnFinished ~= nil then
            _OnFinished(inst)
        end
    end

    inst.components.finiteuses:SetOnFinished(OnFinished)

    inst.onequip_fn = function(inst, owner)
        inst.TryStartFx(inst, owner)
    end

    inst.onunequip_fn = function(inst, owner)
        inst.StopFx(inst)
    end

    inst.Spawn_Shadow_Fx = Spawn_Shadow_Fx
end

local kage_onattack = function(inst, owner, target)
    if inst.IsLunar(target) then
        target.components.combat:GetAttacked(owner, inst.components.weapon.damage * 10)
    end

    local hitsparks_fx_colouroverride = {1, 0, 0}
    local spark = SpawnPrefab("hitsparks_fx")
    spark:Setup(owner, target, nil, hitsparks_fx_colouroverride)
    spark.black:set(true)

    local radius = 20
    local x, y, z = owner.Transform:GetWorldPosition()
    local MUST_TAGS = {"_health"}
    local CANT_TAGS = {"CLASSIFIED", "FX", "NOCLICK", "player", "INLIMBO", "_inventoryitem", "structure", "companion", "abigial", "bird", "prey", "wall", "boat"}
    local Ents = TheSim:FindEntities(x, y, z, radius, MUST_TAGS, CANT_TAGS)
    for _, v in pairs(Ents) do
        if v ~= nil and v:IsValid() and v.components.health ~= nil and not v.components.health:IsDead() then
            local fx = v:SpawnPrefabInPos(weighted_random_choice(Spawn_Shadow_Fx))
            fx:SetScale(2)
            -- v.AnimState:SetMultColour(0, 0, 0, 1)
            if v ~= target then
                v.components.health:DoDelta(-math.random(TUNING.KATANA.DAMAGE, TUNING.KATANA.TRUE_DAMAGE))
            end
        end
    end
end

local katana_data = {
    shusui = {
        -- master_postinit = shusui_master_postinit,
        -- onattack = shusui_onattack,
        damage = TUNING.KATANA.TRUE_DAMAGE
    },
    mortalblade = {
        master_postinit = mortalblade_master_postinit,
        onattack = mortalblade_onattack,
        damage = TUNING.KATANA.TRUE_DAMAGE
    },
    tenseiga = {
        master_postinit = tenseiga_master_postinit,
        onattack = tenseiga_onattack,
        damage = 0,
    },
    kage = {
        master_postinit = kage_master_postinit,
        onattack = kage_onattack,
        damage = TUNING.KATANA.TRUE_DAMAGE,
    }
}

local ret = {}
for k, v in pairs(katana_data) do
    local data = {
        name = k,
        build = k,
        onattack = v.onattack,
        common_postinit = v.common_postinit,
        master_postinit = v.master_postinit,
        damage = v.damage
    }
    table.insert(ret, MakeKatana(data))
end

return unpack(ret)
