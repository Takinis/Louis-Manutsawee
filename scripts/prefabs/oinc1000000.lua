--[[
{
  "style_mode": "dst_item_icon",
  "look": "Don't Starve Together item artstyle, hand-drawn ink outline, flat cel shading, muted earthy colors, thick contour lines, rough brush texture, slightly angled 2.5D perspective",
  "subject": {
    "description": "a worn and slightly crumpled million-pound banknote",
    "details": "Victorian-era design, ornate borders, subtle creases and folds",
    "material": "aged paper with yellowish tint and ink-printed markings",
    "lighting": "soft, painterly highlights and shadow under the lower edge for depth",
    "resolution": "128x128"
  },
  "aesthetic_controls": {
    "render_intent": "icon-like clarity for game inventory item, consistent with DST visual canon",
    "texture_style": [
      "visible paper fibers",
      "hand-painted ink strokes",
      "muted palette (brown, beige, olive green)",
      "slight vignette around edges"
    ]
  },
  "negative_prompt": {
    "forbidden_elements": [
      "photorealism",
      "characters",
      "backgrounds",
      "3D shading",
      "bright saturated colors",
      "modern or digital textures"
    ]
  }
}
]]
local function MakeOinc(name, build, value)
    local assets = {
        Asset("ANIM", "anim/" .. build .. ".zip"),
    }

    local function fn()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddPhysics()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)
        PorkLandMakeInventoryFloatable(inst)

        inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

        inst.AnimState:SetBank("coin")
        inst.AnimState:SetBuild(build)
        inst.AnimState:PlayAnimation("idle")

        inst:AddTag("oinc")

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("currency")
        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        inst:AddComponent("tradable")
        inst:AddComponent("bait")

        inst:AddComponent("waterproofer")
        inst.components.waterproofer.effectiveness = 0

        inst:AddComponent("edible")
        inst.components.edible.foodtype = FOODTYPE.ELEMENTAL
        inst.components.edible.hungervalue = 1

        inst.oincvalue = value

        MakeHauntableLaunch(inst)
        MakeBlowInHurricane(inst, TUNING.WINDBLOWN_SCALE_MIN.MEDIUM, TUNING.WINDBLOWN_SCALE_MAX.MEDIUM)

        return inst
    end
    return Prefab(name, fn, assets)
end

return MakeOinc("oinc1000000", "pig_coin_paper", 1000000)
