local idle_anim_mode = M_CONFIG.IdleAnimationMode

local function CustomIdleAnimFn(inst)
    local customidleanim = inst.components.customidleanim
    if idle_anim_mode == "Random" then
        return customidleanim.idle_anims ~= nil and GetRandomItem(customidleanim.idle_anims)
    elseif idle_anim_mode == "Default" then
        local build = inst.AnimState:GetBuild()
        local idle_anim = customidleanim.idle_anims ~= nil and customidleanim.idle_anims[build] ~= nil and customidleanim.idle_anims[build] or nil
        return idle_anim ~= nil and idle_anim or nil
    end
end

local function CustomIdleStateFn(inst)
    local customidleanim = inst.components.customidleanim
    if idle_anim_mode == "Random" then
        return customidleanim.funny_idle_anims ~= nil and GetRandomItem(customidleanim.funny_idle_anims)
    elseif idle_anim_mode == "Default" then
        local build = inst.AnimState:GetBuild()
        local funny_idle_anim = customidleanim.funny_idle_anims ~= nil and customidleanim.funny_idle_anims[build]
        return funny_idle_anim ~= nil and funny_idle_anim or nil
    end
end

local CustomIdleAnim = Class(function(self, inst)

    self.inst = inst

    self.inst.idle_anims = {}
    self.inst.funny_idle_anims = {}

    inst.AnimState:AddOverrideBuild("player_idles_wes")
    inst.AnimState:AddOverrideBuild("player_idles_wendy")
    inst.AnimState:AddOverrideBuild("player_idles_wanda")

    inst.customidleanim = CustomIdleAnimFn
    inst.customidlestate = CustomIdleStateFn

end)

function CustomIdleAnim:SetIdleAnim(idle_anim, funny_idle_anim)
    if idle_anim ~= nil and type(idle_anim) == "table" then
        self.inst.idle_anims = idle_anim
    end
    if funny_idle_anim ~= nil and type(funny_idle_anim) == "table" then
        self.inst.funny_idle_anims = funny_idle_anim
    end
end

return CustomIdleAnim
