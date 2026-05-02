GLOBAL.setfenv(1, GLOBAL)

function AddOtherModPrefab(prefabfiles, prefabnames, condition)
    if condition then
        if type(prefabnames) == "string" and not table.contains(prefabfiles, prefabnames) then
            table.insert(prefabfiles, prefabnames)
        elseif type(prefabnames) == "table" then
            for k, v in pairs(prefabnames) do
                table.insert(prefabfiles, v)
            end
        else
            error("prefabnames must be string or table!")
        end
    end
end

function AddOtherModAssets(assets, assetsname, condition)
    if condition and not table.contains(assets, assetsname) and type(assets) == "table" then
        if #assetsname <= 1 then
            table.insert(assets, assetsname)
        end
    else
        error("assets must be table!")
    end
end
