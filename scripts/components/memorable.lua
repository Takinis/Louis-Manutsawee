local Memorable = Class(function(self, inst)
    self.inst = inst
    self.memories = {}


end)

function Memorable:AddMemoriesType(type, data)
    self.memories[type] = data or {}
end

function Memorable:Record(name, damage, source, t)
    local rec = {
        damage = damage,
        source = source,
        type = t,
        time = GetTime(),  -- 或者你自己记录战斗内时间
    }
    table.insert(self.memories[name], rec)
end

function Memorable:Forget()
    for k, v in pairs(self.memory) do

    end
end

return Memorable
