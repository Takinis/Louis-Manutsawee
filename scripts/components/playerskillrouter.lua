local INPUT_COOLDOWN_TIME = 1

local PlayerSkillRouter = Class(function(self, inst)
    self.inst = inst
    self.input_routes = {}
    self.sequence_routes = {}
    self.hold_routes = {}
    self.input_cooldowns = {
        [SKILL_INPUT.ICHIMONJI] = INPUT_COOLDOWN.ICHIMONJI,
        [SKILL_INPUT.FLIP] = INPUT_COOLDOWN.FLIP,
        [SKILL_INPUT.THRUST] = INPUT_COOLDOWN.THRUST,
        [SKILL_INPUT.IMMORTALSLASH] = INPUT_COOLDOWN.IMMORTALSLASH,
        cancel = "skill_cancel_cd",
    }
    self.input_levels = {}
    self.input_base_mindpower = {}
    self.last_input_name = nil
    self.last_input_time = 0
end)

function PlayerSkillRouter:AddInputRoute(input_name, data)
    if input_name == nil or data == nil then
        return
    end

    if self.input_routes[input_name] == nil then
        self.input_routes[input_name] = {}
    end

    table.insert(self.input_routes[input_name], data)

    if data.sequence_from ~= nil then
        if self.sequence_routes[input_name] == nil then
            self.sequence_routes[input_name] = {}
        end
        table.insert(self.sequence_routes[input_name], data)
    end

    if data.hold_from ~= nil then
        if self.hold_routes[input_name] == nil then
            self.hold_routes[input_name] = {}
        end
        table.insert(self.hold_routes[input_name], data)
    end

    self.input_cooldowns[input_name] = data.key_cooldown or self.input_cooldowns[input_name] or string.lower(input_name) .. "_key_cd"
    self.input_levels[input_name] = data.input_level or data.level or self.input_levels[input_name] or 0
    self.input_base_mindpower[input_name] = data.base_mindpower or self.input_base_mindpower[input_name]
end

function PlayerSkillRouter:GetInputLevel(input_name)
    return self.input_levels[input_name] or 0
end

function PlayerSkillRouter:GetInputBaseMindpower(input_name)
    return self.input_base_mindpower[input_name]
end

function PlayerSkillRouter:IsInputCoolingDown(input_name)
    local timer = self.inst.components.timer
    local cooldown = self.input_cooldowns[input_name]
    return timer ~= nil and cooldown ~= nil and timer:TimerExists(cooldown)
end

function PlayerSkillRouter:StartInputCooldown(input_name, time)
    local timer = self.inst.components.timer
    local cooldown = self.input_cooldowns[input_name]
    if timer ~= nil and cooldown ~= nil and not timer:TimerExists(cooldown) then
        timer:StartTimer(cooldown, time or INPUT_COOLDOWN_TIME)
    end
end

function PlayerSkillRouter:ClearInputChain()
    self.last_input_name = nil
    self.last_input_time = 0
end

function PlayerSkillRouter:IsSkillActive(tag)
    return tag ~= nil and self.inst:HasTag(tag)
end

function PlayerSkillRouter:WeaponHasTags(tags)
    if tags == nil then
        return true
    end

    local inventory = self.inst.components.inventory
    local weapon = inventory ~= nil and inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
    if weapon == nil then
        return false
    end

    for _, tag in ipairs(tags) do
        if not weapon:HasTag(tag) then
            return false
        end
    end

    return true
end

function PlayerSkillRouter:GetCurrentActiveSkill()
    local controller = self.inst.components.playerskillcontroller
    return controller ~= nil and controller:GetCurrentActiveSkill() or nil
end

function PlayerSkillRouter:BuildRouteContext()
    return {
        active_skill = self:GetCurrentActiveSkill(),
        control_mode = M_CONFIG.SkillControlMode,
    }
end

function PlayerSkillRouter:RouteHasBlockedActiveSkill(route)
    if route.blocked_tags ~= nil then
        for _, tag in ipairs(route.blocked_tags) do
            if tag ~= route.sequence_from and tag ~= route.hold_from and self:IsSkillActive(tag) then
                return true
            end
        end
    end
    return false
end

function PlayerSkillRouter:RouteMatches(route, context)
    if route.sequence_from ~= nil or route.hold_from ~= nil then
        return false
    end

    if route.control ~= nil and route.control ~= context.control_mode then
        return false
    end

    if route.requires_tags ~= nil then
        for _, tag in ipairs(route.requires_tags) do
            if not self:IsSkillActive(tag) then
                return false
            end
        end
    end

    return self:WeaponHasTags(route.weapon_tags)
end

function PlayerSkillRouter:RouteMatchesActiveSkill(route, context)
    return context.active_skill ~= nil
        and (route.sequence_from == context.active_skill or route.hold_from == context.active_skill)
        and self:WeaponHasTags(route.weapon_tags)
end

function PlayerSkillRouter:ResolveBaseRoute(input_name)
    local context = self:BuildRouteContext()
    local routes = self.input_routes[input_name]
    if routes ~= nil then
        for _, route in ipairs(routes) do
            if self:RouteHasBlockedActiveSkill(route) then
                return nil, "blocked"
            end

            if self:RouteMatches(route, context) then
                return route
            end
        end
    end
end

function PlayerSkillRouter:ResolveSequentialRoute(input_name)
    local context = self:BuildRouteContext()
    local current_time = GetTime()
    local timeout = M_CONFIG.SkillInputTimeout
    local routes = self.sequence_routes[input_name]

    if routes ~= nil and self.last_input_name == input_name and current_time - self.last_input_time <= timeout then
        for _, route in ipairs(routes) do
            if self:RouteHasBlockedActiveSkill(route) then
                return nil, "blocked"
            end

            if self:RouteMatchesActiveSkill(route, context) then
                self.last_input_name = input_name
                self.last_input_time = current_time
                return route
            end
        end
    end
end

function PlayerSkillRouter:ResolveHoldRoute(input_name)
    local context = self:BuildRouteContext()
    local routes = self.hold_routes[input_name]
    if routes ~= nil then
        for _, route in ipairs(routes) do
            if self:RouteHasBlockedActiveSkill(route) then
                return nil, "blocked"
            end

            if self:RouteMatchesActiveSkill(route, context) then
                return route
            end
        end
    end
end

function PlayerSkillRouter:ResolveBaseInput(input_name, ignore_cooldown)
    if not ignore_cooldown and self:IsInputCoolingDown(input_name) then
        return {
            reason = "cooldown",
            input_name = input_name,
        }
    end

    local route, reason = self:ResolveBaseRoute(input_name)
    local context = self:BuildRouteContext()
    return {
        route = route,
        reason = reason,
        input_name = input_name,
        input_level = self:GetInputLevel(input_name),
        base_mindpower = self:GetInputBaseMindpower(input_name),
        start_cooldown = route == nil or route.start_cooldown ~= false,
        keep_input_chain = true,
        mark_last_input = context.control_mode == SKILL_CONTROL_MODE.SEQUENCE,
    }
end

function PlayerSkillRouter:ResolveSequenceInput(input_name)
    local route, reason = self:ResolveSequentialRoute(input_name)
    if route ~= nil or reason ~= nil then
        return {
            route = route,
            reason = reason,
            input_name = input_name,
            start_cooldown = route ~= nil,
            keep_input_chain = true,
        }
    end

    if self:IsInputCoolingDown(input_name) then
        return {
            reason = "cooldown",
            input_name = input_name,
        }
    end

    local result = self:ResolveBaseInput(input_name, true)
    result.mark_last_input = true
    return result
end

function PlayerSkillRouter:ResolveHoldInput(input_name)
    local route, reason = self:ResolveHoldRoute(input_name)
    return {
        route = route,
        reason = reason,
        input_name = input_name,
        start_cooldown = route ~= nil,
    }
end

function PlayerSkillRouter:ProcessSkillInput(input_name, input_phase)
    input_phase = input_phase or "pressed"

    if input_phase == "released" then
        return {
            reason = "released",
            input_name = input_name,
        }
    end

    if input_phase == "hold" then
        return self:ResolveHoldInput(input_name)
    elseif input_phase == "sequence" then
        return self:ResolveSequenceInput(input_name)
    end

    return self:ResolveBaseInput(input_name)
end

function PlayerSkillRouter:SetLastInput(input_name)
    self.last_input_name = input_name
    self.last_input_time = GetTime()
end

function PlayerSkillRouter:OnRemoveEntity()
    self:ClearInputChain()
end

PlayerSkillRouter.OnRemoveFromEntity = PlayerSkillRouter.OnRemoveEntity

return PlayerSkillRouter
