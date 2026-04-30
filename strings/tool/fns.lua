function deepcopy(object)
    local function fn(_object)
        if type(_object) ~= "table" then
            return _object
        end

        local newtable = {}
        for k, v in pairs(_object) do
            newtable[fn(k)] = fn(v)
        end

        return setmetatable(newtable, getmetatable(_object))
    end

    return fn(object)
end

function pairs_by_keys(t)
    local list = {}
    for k in pairs(t) do
        list[#list + 1] = k
    end

    table.sort(list, function(a, b)
        return string.upper(a) < string.upper(b)
    end)

    local i = 0
    return function()
        i = i + 1
        return list[i], t[list[i]]
    end
end

function is_array(t)
    if type(t) ~= "table" or not next(t) then
        return false
    end

    local n = #t
    for i, v in pairs(t) do
        if type(i) ~= "number" or i <= 0 or i > n then
            return false
        end
    end

    return true
end

function merge_table(target, add_table, override)
    target = target or {}

    for k, v in pairs(add_table) do
        if type(v) == "table" then
            if not target[k] then
                target[k] = {}
            elseif type(target[k]) ~= "table" then
                if override then
                    target[k] = {}
                else
                    error("Cannot override " .. k .. " to a table")
                end
            end

            merge_table(target[k], v, override)
        else
            if is_array(target) and not override and target[k] ~= v then
                table.insert(target, v)
            elseif not target[k] or override then
                target[k] = v
            end
        end
    end
end

function escape(str)
    return (str:gsub('\\', '\\\\')
               :gsub('"', '\\"')
               :gsub('\n', '\\n')
               :gsub('\r', '\\r'))
end

function table_to_string(t, indent)
    if not t or not next(t) then
        return "{}"
    end

    indent = indent or 1
    local dent = ""
    for i = 1, indent do
        dent = dent .. "    "
    end

    local str = ""

    if is_array(t) then
        for i = 1, #t do
            local v = t[i]
            if type(v) == "table" then
                local _str = table_to_string(v, indent + 1)
                str = str .. dent .. _str .. ",\n"
            else
                local value = ""
                if type(v) == "string" then
                    value = "\"" .. escape(v) .. "\""
                else
                    value = tostring(v)
                end
                str = str .. dent .. value .. ",\n"
            end
        end
    else
        for k, v in pairs_by_keys(t) do
            if type(v) == "table" then
                local _str = table_to_string(v, indent + 1)
                str = str .. dent .. k .. " = " .. _str .. ",\n"
            else
                local value = ""
                if type(v) == "string" then
                    value = "\"" .. escape(v) .. "\""
                else
                    value = tostring(v)
                end
                str = str .. dent .. k .. " = " .. value .. ",\n"
            end
        end
    end

    local end_dent = ""
    for i = 1, indent - 1 do
        end_dent = end_dent .. "    "
    end

    return "{\n" .. str .. end_dent .. "}"
end

-- function table_to_string(t, indent)
--     if not t or not next(t) then
--         return "{},"
--     end

--     indent = indent or 1
--     local dent = ""
--     for i = 1, indent do
--         dent = dent .. "    "
--     end

--     local str = ""
--     for k, v in pairs_by_keys(t) do
--         if type(v) == "table" then
--             local _str = table_to_string(t[k], indent + 1)
--             str = str .. dent .. k .. " = " .. _str .. "\n"
--         else
--             local value = ""
--             if type(v) == "string" then
--                 value = type(v) == "string" and ("\"" .. escape(v) .. "\"") or tostring(v)
--             end

--             if type(k) == "number" then
--                 str = str .. dent .. value .. "," .. "\n"
--             else
--                 str = str .. dent .. k .. " = " .. value .. "," .. "\n"
--             end
--         end
--     end

--     local end_dent = ""
--     for i = 1, indent - 1 do
--         end_dent = end_dent .. "    "
--     end

--     local pack = "{\n" .. str .. end_dent .. "}"
--     if indent > 1 then
--         pack = pack .. ","
--     end

--     return pack
-- end

function table_index_to_str(t, index_str)
    local package = {}
    for k, v in pairs(t) do
        local _index_str = index_str .. "."  .. k  -- don't modify orange index_str

        if type(v) == "table" then
            local _package = table_index_to_str(v, _index_str)
            merge_table(package, _package)
        else
            package["msgctxt \"" .. _index_str .. "\""] = v
        end
    end

    return package
end

function load_ds_string(path)
    local result = loadfile(path .. "common.lua")

    local data_strings = result and result() or {}

    data_strings.CHARACTERS = data_strings.CHARACTERS or {}

    for _, character in ipairs(characters) do
        local _result = loadfile(path .. character .. ".lua")
        if _result then
            data_strings.CHARACTERS[character:upper()] = _result()
        end
    end

    return data_strings
end

function create_nested_structure(keys)
    local result = {}

    for _, key in ipairs(keys) do
        local parts = {}
        for part in string.gmatch(key, "[^%.]+") do
            table.insert(parts, part)
        end

        local current = result
        for i = 1, #parts - 1 do
            local part = parts[i]
            local num_part = tonumber(part)
            if num_part then
                if not current[num_part] then
                    current[num_part] = {}
                end
                current = current[num_part]
            else
                if not current[part] then
                    current[part] = {}
                end
                current = current[part]
            end
        end

        local last_part = parts[#parts]
        local num_last = tonumber(last_part)

        if num_last then
            current[num_last] = ""
        else
            current[last_part] = ""
        end
    end

    return result
end

function write_lua_table(filepath, tbl)
    local file = io.open(filepath, "w")
    if not file then
        error("Cannot create file: " .. filepath)
    end

    file:write("return " .. table_to_string(tbl))
    file:write("\n")
    file:close()
    print("Successfully wrote to: " .. filepath)
end

function safe_load_file(filepath)
    local file = io.open(filepath, "r")
    if not file then
        print("Warning: Cannot open file " .. filepath)
        return nil
    end

    local content = file:read("*all")
    file:close()

    if not content or content == "" then
        print("Warning: File is empty " .. filepath)
        return nil
    end

    content = content:match("^%s*(.-)%s*$")

    local func, err

    func, err = loadstring(content)
    if func then
        local success, result = pcall(func)
        if success and result then
            return result
        end
    end

    func, err = loadstring("return " .. content)
    if func then
        local success, result = pcall(func)
        if success then
            return result
        end
    end

    local cleaned_content = content:gsub("^%s*return%s+", "")
    func, err = loadstring("return " .. cleaned_content)
    if func then
        local success, result = pcall(func)
        if success then
            return result
        end
    end

    print("Error loading file " .. filepath .. ": " .. (err or "unknown error"))
    print("Content preview: " .. content:sub(1, 200) .. (content:len() > 200 and "..." or ""))
    return nil
end

function extract_keys(tbl, prefix)
    local keys = {}
    prefix = prefix or ""

    if type(tbl) ~= "table" then
        return keys
    end

    if is_array(tbl) then
        local has_valid_content = false
        for i, v in ipairs(tbl) do
            if type(v) == "string" then
                if not string.find(string.lower(v), "only_used_by_") then
                    has_valid_content = true
                end
            elseif type(v) == "table" then
                local sub_keys = extract_keys(v, prefix == "" and tostring(i) or (prefix .. "." .. tostring(i)))
                if #sub_keys > 0 then
                    has_valid_content = true
                    for _, sub_key in ipairs(sub_keys) do
                        table.insert(keys, sub_key)
                    end
                end
            else
                has_valid_content = true
            end
        end

        if has_valid_content and prefix ~= "" then
            table.insert(keys, prefix)
        end
    else
        for k, v in pairs(tbl) do
            local current_key = prefix == "" and tostring(k) or (prefix .. "." .. tostring(k))

            if type(v) == "table" then
                local sub_keys = extract_keys(v, current_key)
                for _, sub_key in ipairs(sub_keys) do
                    table.insert(keys, sub_key)
                end
            else
                if type(v) == "string" and not string.find(string.lower(v), "only_used_by_") then
                    table.insert(keys, current_key)
                elseif type(v) ~= "string" then
                    table.insert(keys, current_key)
                end
            end
        end
    end

    return keys
end

function backup_file(filepath)
    local backup_path = filepath .. "_backup"
    local source = io.open(filepath, "r")
    if source then
        local content = source:read("*all")
        source:close()

        local backup = io.open(backup_path, "w")
        if backup then
            backup:write(content)
            backup:close()
            print("已备份文件: " .. backup_path)
            return true
        end
    end
    return false
end

function load_pofile(file_path, indexs)
    local file = io.open(file_path, "r")
    if not file then
        file = io.open(file_path, "w")
        file:close()
    end
    file = io.open(file_path, "r")

    local po_table = {}

    local started = false
    local workline = ""
    for line in file:lines() do
        if line:find("msgctxt") and (not indexs or indexs[line]) then
            workline = line
            started = true
        end

        if started then
            if line:find("msgstr") then
                po_table[workline] = line
                started = false
            end
        end
    end

    file:close()

    return po_table
end

function translate_table(t, translate_fn)
    t = t or {}

    for k, v in pairs(t) do
        if type(v) == "table" then
            translate_table(v, translate_fn)
        else
            t[k] = translate_fn(v)
        end
    end

    return t
end

function get_string(target, key, over_key)
    local new = {}
    over_key = over_key or key
    for k, v in pairs(target) do
        if k == key then
            new[over_key] = v
        elseif type(v) == "table" then
            local _new = get_string(target[k], key, over_key)
            if next(_new) then
                new[k] = _new
            end
        end
    end
    return new
end

function dumptable(obj, indent, recurse_levels)
    indent = indent or 1
    local i_recurse_levels = recurse_levels or 10
    if obj then
        local dent = ""
        if indent then
            for i = 1, indent do
                dent = dent .. "\t"
            end
        end

        if type(obj) == "string" then
            print(obj)
            return
        end

        for k, v in pairs(obj) do
            if type(v) == "table" and i_recurse_levels > 0 then
                print(dent.."K: ",k)
                dumptable(v, indent + 1, i_recurse_levels - 1)
            else
                print(dent .. "K: ", k, " V: ", v)
            end
        end
    end
end

function call_translator(text, target_lang, source_lang)
    source_lang = source_lang or "en"
    local max_retries = 3
    local retry_count = 0

    while retry_count < max_retries do
        -- Escape quotes for shell command
        local text_arg = string.format("%q", text)
        local target_arg = string.format("%q", target_lang)
        local source_arg = string.format("%q", source_lang)

        local command = string.format("python translator.py --text %s --target %s --source %s", text_arg, target_arg, source_arg)

        local ok, handle, err_msg = pcall(io.popen, command, "r")

        if not ok or not handle then
            retry_count = retry_count + 1
            print(string.format("Error executing translator command (attempt %d/%d): %s", retry_count, max_retries, err_msg or "unknown error"))
            if retry_count >= max_retries then
                print("Max retries reached, returning original text")
                return text -- Return original text after max retries
            end
        else
            local result = handle:read("*a")
            handle:close()

            -- Trim whitespace from the result
            if result then
                result = result:match("^%s*(.-)%s*$")
                if result == "" then
                    retry_count = retry_count + 1
                    print(string.format("Empty result from translator (attempt %d/%d), retrying...", retry_count, max_retries))
                    if retry_count >= max_retries then
                        print("Max retries reached, returning original text")
                        return text -- Return original if result is empty after max retries
                    end
                else
                    return result -- Success, return translated text
                end
            else
                retry_count = retry_count + 1
                print(string.format("Nil result from translator (attempt %d/%d), retrying...", retry_count, max_retries))
                if retry_count >= max_retries then
                    print("Max retries reached, returning original text")
                    return text -- Return original text if result is nil after max retries
                end
            end
        end
    end

    return text -- Fallback: return original text
end
