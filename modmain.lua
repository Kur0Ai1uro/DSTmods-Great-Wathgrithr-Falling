local tonumber = GLOBAL.tonumber

local function Num(name, fallback)
    local value = tonumber(GetModConfigData(name))
    if value == nil then
        return fallback
    end
    return value
end

GLOBAL.STARFALL_TUNING = {
    cooldown = Num("COOLDOWN", 30),
    hunger = Num("HUNGER", 30),
    min_range = Num("MIN_RANGE", 3),
    max_range = Num("MAX_RANGE", 18),
    path_half_width = 4,
    slide_length = 12,
    path_mult = 3.3,
    land_radius = 2,
    land_mult = 2.0,
    uses = Num("USES", 4),
    channel_time = 1.8,
    rise_time = 0.4,
    dive_time = 0.45,
    slide_time = 0.4,
    travel_speed = 22,
    recover_time = 0.3,
    peak = 5.5,
    spear_speed = 36,
    spear_pad = 0.15,
}

local Common = require("starfall_common")

PrefabFiles = {
    "wathgrithr_starfall_spear",
    "wathgrithr_starfall_zone",
}

-- 状态注册放在 mod 环境里。位移只在 wilson，wilson_client 只播同名动画。
modimport("scripts/states_starfall.lua")

AddPlayerPostInit(function(inst)
    if inst.prefab ~= "wathgrithr" then
        return
    end
    local world = GLOBAL.TheWorld
    if world ~= nil and world.ismastersim then
        inst:AddComponent("starfallcaster")
    end
end)

-- 主机和加入的客户端都只把落点发给服务器。伤害、饥饿和位移只在服务器上结算。
AddModRPCHandler("wathgrithr_starfall", "cast", function(player, x, z)
    if player == nil or not player:IsValid() or not player:HasTag("player") then
        return
    end
    x = tonumber(x)
    z = tonumber(z)
    if x == nil or z == nil or x ~= x or z ~= z then
        return
    end
    Common.TryStarfall(player, x, z)
end)

local function RequestStarfall(x, z)
    GLOBAL.SendModRPCToServer(GLOBAL.MOD_RPC["wathgrithr_starfall"]["cast"], x, z)
end

local function OnCastKey()
    local player = GLOBAL.ThePlayer
    if player == nil or not player:IsValid() or player.prefab ~= "wathgrithr" then
        return
    end
    if player.HUD ~= nil and player.HUD:HasInputFocus() then
        return
    end
    local front_end = GLOBAL.TheFrontEnd
    if front_end ~= nil then
        local screen = front_end:GetActiveScreen()
        if screen ~= nil and screen ~= player.HUD then
            return
        end
    end
    local pos = GLOBAL.TheInput:GetWorldPosition()
    if pos == nil then
        return
    end
    RequestStarfall(pos.x, pos.z)
end

if not GLOBAL.TheNet:IsDedicated() then
    local keyname = GetModConfigData("CAST_KEY", true) or "KEY_R"
    local key = GLOBAL[keyname]
    local input = GLOBAL.TheInput
    if key ~= nil and input ~= nil then
        input:AddKeyDownHandler(key, OnCastKey)
    end
end
