-- `GetUpvalue` and `SetUpvalue` were modified base on the upvalue tool designed by Rezecib

local function upvalue_iter(fn)
    local i = 0
    return function()
        i = i + 1
        local value_name, value = debug.getupvalue(fn, i)
        return value_name, value, i
    end
end

-- Find the upvalue by comparing the names through all upvalues,
-- returns the value and the up index
local function find_upvalue(fn, name)
    for value_name, value, index in upvalue_iter(fn) do
        if value_name == name then
            return value, index
        end
    end
end

local MAX_UPVALUE_SEARCH_DEPTH = 3

--- Returns the upvalue, the up index, and the scope function
---
--- ## Examples:
---
--- ```lua
--- local telestaff_constructor = Prefabs["telestaff"].fn
--- local teleport_start, teleport_func, i = GetUpvalue(telestaff_constructor, "teleport_func.teleport_start")
--- debug.setupvalue(teleport_func, i, function(...) print("hooked") return teleport_start(...) end)
--- ```
---@param fn function
---@param path string
---@return any, function, number
local function GetUpvalue(fn, path, depth)
    if not depth then
        depth = 1
    end

    local value, scope_fn, index = fn, nil, nil ---@type any, function | nil, number | nil

    for part in path:gmatch("[^%.]+") do
        scope_fn = value
        value, index = find_upvalue(value, part)

        if value == nil then
            -- Another mod might be hooking the function,
            -- we search all the upvalues inside this function and see if there's a match
            if depth < MAX_UPVALUE_SEARCH_DEPTH then
                for _, value in upvalue_iter(fn) do
                    if type(value) == "function" then
                        local value, scope_fn, index = GetUpvalue(value, path, depth + 1)
                        if value then
                            return value, scope_fn, index
                        end
                    end
                end
            end
            break
        end
    end

    return value, scope_fn, index
end

---@param fn function
---@param path string
---@param value any
local function SetUpvalue(fn, path, value)
    local _, scope_fn, index = GetUpvalue(fn, path)
    debug.setupvalue(scope_fn, index, value)
end

return {
    GetUpvalue = GetUpvalue,
    SetUpvalue = SetUpvalue
}
