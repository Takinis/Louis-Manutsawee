local msurfboardassets = {
    Asset("ANIM", "anim/raft_mbasic.zip"),
    Asset("ANIM", "anim/raft_msurfboard_build.zip"),
    Asset("ANIM", "anim/raft_midles.zip"),
    Asset("ANIM", "anim/raft_mpaddle.zip"),
    Asset("ANIM", "anim/raft_mtrawl.zip"),

    Asset("ANIM", "anim/boat_hud_raft.zip"),
    Asset("ANIM", "anim/boat_inspect_raft.zip"),
    Asset("ANIM", "anim/flotsam_surfboard_build.zip"),

    Asset("ANIM", "anim/msurfboard.zip"),
}

local prefabs = {
    "flotsam_surfboard",
    "rowboat_wake",
    "boat_hit_fx",
}

local function Sink(inst)
    local sailor = inst.components.sailable:GetSailor()
    if sailor then
        sailor.components.sailor:Disembark(nil, nil, true)

        -- sailor:PushEvent("onsink", {ia_boat = inst})

        sailor.SoundEmitter:PlaySound(inst.sinksound)
    end
    if inst.components.container then
        inst.components.container:DropEverything()
    end

    inst:Remove()
end

local function OnHit(inst)
    inst.components.lootdropper:DropLoot()
    if inst.components.container then
        inst.components.container:DropEverything()
    end
    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    inst.SoundEmitter:PlaySound("dontstarve/common/destroy_wood")
    inst:Remove()
end

local function OnRepaired(inst, doer, repair_item)
    inst.SoundEmitter:PlaySound("ia/common/boatrepairkit")
end

local function OnDisEmbarked(inst)
    inst.components.workable:SetWorkable(false)
end

local function OnEmbarked(inst)
    inst.components.workable:SetWorkable(true)
end

local function OnOpen(inst)
    if inst.components.sailable.sailor == nil then
        inst.SoundEmitter:PlaySound("dontstarve_DLC002/common/boat/inventory_open")
    end
end

local function OnClose(inst)
    if inst.components.sailable.sailor == nil then
        inst.SoundEmitter:PlaySound("dontstarve_DLC002/common/boat/inventory_close")
    end
end

local function OnWorked(inst)
    inst.AnimState:PlayAnimation("hit")
    inst.AnimState:PushAnimation("run_loop", true)
end



local function surfboard_pickupfn(inst, guy)
    local item = SpawnPrefab(inst.boat_item)
    if item then
        local value = inst.boatname:value()
        local name = value and value ~= "" and value or ""
        item.components.writeable:SetText(name)
        item.boatname:set(name)

        guy.components.inventory:GiveItem(item)
        item.components.pocket:GiveItem(inst.prefab, inst)
    end

    return true
end

local function onworked(inst, worker)
    inst.components.lootdropper:DropLoot()
    if inst.components.container ~= nil then
        inst.components.container:DropEverything()
    end
    SpawnAt("collapse_small", inst)
    inst.SoundEmitter:PlaySound("dontstarve/common/destroy_wood")
    inst:Remove()
end

local function common()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    inst.entity:AddPhysics()
    inst.entity:AddMiniMapEntity()

    inst:AddTag("boat")
    inst:AddTag("sailable")

    inst.Transform:SetFourFaced()
    inst.MiniMapEntity:SetPriority(5)

    inst.AnimState:SetFinalOffset(FINALOFFSET_MIN) --has some visual glitches but looks much better than the boat being infront of the player on a disembark

    inst.Physics:SetCylinder(0.25,2)

    inst:AddTag("surfboard")

    inst.boat_item = "msurfboard_item"

    inst.AnimState:SetBank("mraft")
    inst.AnimState:SetBuild("raft_msurfboard_build")
    inst.AnimState:PlayAnimation("run_loop", true)

    inst.MiniMapEntity:SetIcon("boat_msurfboard.tex")

    inst.no_wet_prefix = true

    inst.sailmusic = "sailing"

    inst.boatvisuals = {}

    inst.boatname = net_string(inst.GUID, "boatname")

    inst.displaynamefn = function(_inst)
        local name = _inst.boatname:value()
        return name ~= "" and name or STRINGS.NAMES[string.upper(_inst.prefab)]
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        function inst.OnEntityReplicated(_inst)
            _inst.replica.sailable.creaksound = "ia/common/boat/creaks/creaks"
            _inst.replica.sailable.sailsound = "ia/common/sail_LP/surfboard"
            _inst.replica.sailable.sailloopanim = "surf_loop"
            _inst.replica.sailable.sailstartanim = "surf_pre"
            _inst.replica.sailable.sailstopanim = "surf_pst"
            _inst.replica.sailable.alwayssail = true
        end
        return inst
    end

    inst:AddComponent("inspectable")

    inst:AddComponent("hauntable")
    inst.components.hauntable:SetHauntValue(TUNING.HAUNT_TINY)

    inst:AddComponent("writeable")
    inst:RemoveEventCallback("onbuilt", inst.event_listening.onbuilt[inst][1])
    inst.components.writeable:SetDefaultWriteable(false)
    inst.components.writeable:SetAutomaticDescriptionEnabled(false)

    local _Write = inst.components.writeable.Write
    inst.components.writeable.Write = function(self, doer, text, ...)
        if not text then
            text = self.text
            if doer.tool_prefab then
                doer.components.inventory:GiveItem(SpawnPrefab(doer.tool_prefab), nil, inst:GetPosition())
            end
        else
            inst.SoundEmitter:PlaySound("dontstarve/common/together/draw")
        end

        inst.boatname:set(text and text ~= "" and text or "")
        _Write(self, doer, text, ...)
    end

    local _OnLoad = inst.components.writeable.OnLoad
    inst.components.writeable.OnLoad = function(self, ...)
        _OnLoad(self, ...)
        local text = self.text
        inst.boatname:set(text and text ~= "" and text or "")
    end

    inst:AddComponent("sailable")
    inst.components.sailable.sanitydrain = TUNING.RAFT_SANITY_DRAIN
    inst.components.sailable.movementbonus = TUNING.RAFT_SPEED + 5
    inst.components.sailable.maprevealbonus = TUNING.MAPREVEAL_RAFT_BONUS
    inst.components.sailable.hitmoisturerate = TUNING.SURFBOARD_HITMOISTURERATE
    inst.components.sailable.flotsambuild = "flotsam_surfboard_build"

    inst.landsound = "ia/common/boatjump_land_bamboo"
    inst.sinksound = "ia/common/boat/sinking/bamboo"

    inst.waveboost = TUNING.WAVEBOOST

    inst:AddComponent("rowboatwakespawner")

    inst:AddComponent("boathealth")
    inst.components.boathealth:SetDepletedFn(sink)
    inst.components.boathealth:SetHealth(TUNING.RAFT_HEALTH, TUNING.RAFT_PERISHTIME)
    inst.components.boathealth.leakinghealth = TUNING.RAFT_LEAKING_HEALTH
    inst.components.boathealth.damagesound = "ia/common/boat/damage/bamboo"
    inst.components.boathealth.hitfx = "boat_hit_fx_raft_bamboo"

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnFinishCallback(onworked)
    inst.components.workable:SetOnWorkCallback(onhit)

    inst:AddComponent("lootdropper")

    inst:AddComponent("repairable")
    inst.components.repairable.repairmaterial = "boat"
    inst.components.repairable.onrepaired = onrepaired

    inst:ListenForEvent("embarked", OnEmbarked)
    inst:ListenForEvent("disembarked", OnDisEmbarked)

    inst.onworked = onworked

    inst:AddComponent("flotsamspawner")

    inst.components.flotsamspawner.flotsamprefab = "flotsam_bamboo"

    inst:AddSpoofedComponent("boatcontainer", "container")

    inst.components.container.onopenfn = onopen
    inst.components.container.onclosefn = onclose

    inst:AddComponent("boatvisualmanager")


    inst.board = nil

    inst.components.container:WidgetSetup("boat_msurfboard")

    inst.waveboost = TUNING.SURFBOARD_WAVEBOOST
    inst.wavesanityboost = TUNING.SURFBOARD_WAVESANITYBOOST



    inst.perishtime = TUNING.SURFBOARD_PERISHTIME
    inst.components.boathealth.maxhealth = TUNING.MSURFBOARD_HEALTH
    inst.components.boathealth:SetHealth(TUNING.MSURFBOARD_HEALTH, inst.perishtime)

    inst.components.boathealth.damagesound = "ia/common/boat/damage/surfboard"

    inst.components.flotsamspawner.flotsamprefab = "flotsam_surfboard"

    inst.components.boathealth.hitfx = nil

    inst.sinksound = "ia/common/boat/sinking/log_cargo"
    inst.replica.sailable.sailsound = "ia/common/sail_LP/surfboard"
    inst.replica.sailable.sailloopanim = "surf_loop"
    inst.replica.sailable.sailstartanim = "surf_pre"
    inst.replica.sailable.sailstopanim = "surf_pst"
    inst.components.sailable.alwayssail = true
    inst.sailmusic = "surfing"

    inst:AddComponent("pickupable")
    inst.components.pickupable:SetOnPickupFn(surfboard_pickupfn)
    inst:SetInherentSceneAltAction(ACTIONS.RETRIEVE)

    inst:ListenForEvent("embarked", function(_inst)
        _inst.components.pickupable.canbepickedup = false
        _inst:SetInherentSceneAltAction(nil)
    end)

    inst:ListenForEvent("disembarked", function(_inst)
        _inst.components.pickupable.canbepickedup = true
        _inst:SetInherentSceneAltAction(ACTIONS.RETRIEVE)
    end)

    return inst
end


local function item_ondropped(inst)
    --If this is a valid place to be deployed, auto deploy yourself.
    local x, y, z = inst.Transform:GetWorldPosition()
    local pt = Vector3(x, 0, z)
    if inst.components.deployable and inst._custom_candeploy_fn and inst:_custom_candeploy_fn(pt) then
        inst.components.deployable.forcedeploy = true
        inst.components.deployable:Deploy(pt, inst)
        inst.components.deployable.forcedeploy = false
    end
end

local function item_ondeploy(inst, pt, deployer)
    local boat = inst.components.pocket:RemoveItem(inst.boat) or SpawnPrefab(inst.boat)
    if boat then
        local value = inst.boatname:value()
        local name = value and value ~= "" and value or ""
        boat.components.writeable:SetText(name)
        boat.boatname:set(name)

        local x, y, z = pt:Get()
        boat.components.flotsamspawner.inpocket = false
        boat.Physics:SetCollides(false)
        boat.Physics:Teleport(x, y, z)
        boat.Physics:SetCollides(true)
        inst:Remove()
    end
end

local function surfboarditemfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()

    inst.MiniMapEntity:SetIcon("boat_msurfboard.tex")
    inst.MiniMapEntity:SetPriority(5)

    MakeInventoryPhysics(inst)
    MakeInventoryFloatable(inst)

    inst.AnimState:SetBank("msurfboard")
    inst.AnimState:SetBuild("msurfboard")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("boat")

    inst.boatname = net_string(inst.GUID, "boatname")

    inst.displaynamefn = function(_inst)
        local name = _inst.boatname:value()
        return name ~= "" and name or STRINGS.NAMES[string.upper(_inst.prefab)]
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.boat = "boat_msurfboard"

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:SetOnDroppedFn(item_ondropped)

    inst:AddComponent("pocket")

    inst:AddComponent("deployable")
    inst.components.deployable:SetDeployMode(DEPLOYMODE.CUSTOM)
    inst._custom_candeploy_fn = function(_inst, pt)
        local tile = TheWorld.Map:GetTileAtPoint(pt:Get())
        local IsWaterMode = IA_CONFIG.aquaticplacedstwater and IsWaterAny or IsWater
        return IsWaterMode(tile)
    end
    inst.components.deployable.ondeploy = item_ondeploy
    inst.components.deployable.candeployonland = false
    inst.components.deployable.candeployonbuildableocean = true
    inst.components.deployable.candeployonunbuildableocean = true
    inst.components.deployable.deploydistance = 3

    inst:AddComponent("writeable")
    inst.components.writeable:SetDefaultWriteable(false)
    inst.components.writeable:SetAutomaticDescriptionEnabled(false)
    local _Write = inst.components.writeable.Write
    inst.components.writeable.Write = function(self, doer, text, ...)
        if not text then
            text = self.text
            if doer and doer.tool_prefab then
                doer.components.inventory:GiveItem(SpawnPrefab(doer.tool_prefab), nil, inst:GetPosition())
            end
        else
            inst.SoundEmitter:PlaySound("dontstarve/common/together/draw")
        end

        inst.boatname:set(text and text ~= "" and text or "")
        _Write(self, doer, text, ...)
    end

    local _OnLoad = inst.components.writeable.OnLoad
    inst.components.writeable.OnLoad = function(self, ...)
        _OnLoad(self, ...)
        local text = self.text
        inst.boatname:set(text and text ~= "" and text or "")
    end

    return inst
end

return Prefab("boat_msurfboard", common, msurfboardassets, prefabs),
        Prefab("msurfboard_item", surfboarditemfn, msurfboardassets, prefabs),
        MakePlacer("msurfboard_item_placer", "mraft", "raft_msurfboard_build", "run_loop", nil, nil, nil, nil, nil, nil, nil, 2)
