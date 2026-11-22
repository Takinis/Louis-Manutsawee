-- Run from the mod directory: lua tests/porkland_undertile.lua
GLOBAL = _G

local enabled = false
KnownModIndex = {
    IsModEnabledAny = function(_, name)
        return enabled and name == "workshop-3322803908"
    end,
}

local hooks = {}
AddComponentPostInit = function(name, fn)
    hooks[name] = fn
end

local sent = {}
ZipAndEncodeString = function(data) return data end
GetClientModRPC = function(namespace, name)
    assert(namespace == "Porkland" and name == "update_undertile")
    return name
end
SendModRPCToClient = function(rpc, userid, data)
    assert(rpc == "update_undertile")
    sent[#sent + 1] = { userid = userid, payload = data }
end

dofile("postinit/components/porkland_undertile.lua")
assert(next(hooks) == nil)
enabled = true
dofile("postinit/components/porkland_undertile.lua")

local world = { HasTag = function(_, tag) return tag == "porkland" end }
local forest = { HasTag = function() return false end }
local function OriginalNotify() error("Unexpected original RPC sender") end
local sender = { NotifyUnderTileChanged = OriginalNotify }
hooks.undertile(sender, forest)
assert(sender.NotifyUnderTileChanged == OriginalNotify)
hooks.undertile(sender, world)

local receiver = { grid = {} }
function receiver:OnUnderTilesChange(payload)
    for index, tile in pairs(payload.data) do
        self.grid[index] = payload.action == "update" and tile or nil
    end
end
hooks.clientundertile(receiver, world)
receiver:OnUnderTilesChange(nil)
receiver:OnUnderTilesChange({})

local snapshot = { [0] = 1 }
for i = 1, 24000 do
    snapshot[i * 19] = i % 256
end
sender:NotifyUnderTileChanged(snapshot, "joining-user")
assert(#sent > 1)
for _, rpc in ipairs(sent) do
    assert(rpc.userid == "joining-user" and rpc.payload.action == "update")
    local count = 0
    for _ in pairs(rpc.payload.data) do count = count + 1 end
    assert(count > 0 and count <= 512)
    receiver:OnUnderTilesChange(rpc.payload)
end
for index, tile in pairs(snapshot) do
    assert(receiver.grid[index] == tile)
end

sent = {}
sender:NotifyUnderTileChanged({ action = "update", data = { [0] = 5 } })
sender:NotifyUnderTileChanged({ action = "remove", data = { [19] = true } })
sender:NotifyUnderTileChanged({})
assert(#sent == 2 and sent[1].userid == nil and sent[2].userid == nil)
receiver:OnUnderTilesChange(sent[1].payload)
receiver:OnUnderTilesChange(sent[2].payload)
assert(receiver.grid[0] == 5 and receiver.grid[19] == nil)

print("porkland_undertile: ok")
