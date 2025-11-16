return Class(function(self, inst)

    self.inst = inst

    local idle_anims = {}
    local funny_idle_anims = {}
    local idle_anim_mode = M_CONFIG.IdleAnimationMode

    local function CustomIdleAnimFn(inst)
        if idle_anim_mode == "Random" then
            return idle_anims ~= nil and GetRandomItem(idle_anims)
        elseif idle_anim_mode == "Default" then
            local build = inst.AnimState:GetBuild()
            local idle_anim = idle_anims ~= nil and idle_anims[build] ~= nil and idle_anims[build] or nil
            return idle_anim ~= nil and idle_anim or nil
        end
    end

    local function CustomIdleStateFn(inst)
        if idle_anim_mode == "Random" then
            return funny_idle_anims ~= nil and GetRandomItem(funny_idle_anims)
        elseif idle_anim_mode == "Default" then
            local build = inst.AnimState:GetBuild()
            local funny_idle_anim = funny_idle_anims ~= nil and funny_idle_anims[build]
            return funny_idle_anim ~= nil and funny_idle_anim or nil
        end
    end

    function self:SetIdleAnim(idle_anim, funny_idle_anim)
        if idle_anim ~= nil and type(idle_anim) == "table" then
            idle_anims = idle_anim
        end
        if funny_idle_anim ~= nil and type(funny_idle_anim) == "table" then
            funny_idle_anims = funny_idle_anim
        end
    end

    inst.AnimState:AddOverrideBuild("player_idles_wes")
    inst.AnimState:AddOverrideBuild("player_idles_wendy")
    inst.AnimState:AddOverrideBuild("player_idles_wanda")

    inst.customidleanim = CustomIdleAnimFn
    inst.customidlestate = CustomIdleStateFn
end)
