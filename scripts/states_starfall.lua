local Common = require("starfall_common")
local State = GLOBAL.State
local EventHandler = GLOBAL.EventHandler

local STARFALL_STATE = {
    starfall_rise = true,
    starfall_hang = true,
    starfall_dive = true,
    starfall_land = true,
}

local TAGS = { "busy", "nopredict", "pausepredict", "nomorph", "nointerrupt", "notalking", "starfall" }

local function AbortToIdle(inst)
    if inst.sg.statemem.aborting then
        return
    end
    inst.sg.statemem.aborting = true
    inst.sg:GoToState("idle")
end

local function StopMoving(inst)
    if inst.components.locomotor ~= nil then
        inst.components.locomotor:Stop()
    end
end

local function IsLocalPlayer(inst)
    return inst == GLOBAL.ThePlayer
end

local function CameraPull(inst)
    if not IsLocalPlayer(inst) then
        return
    end
    local cam = GLOBAL.TheCamera
    if cam == nil or inst._starfall_cam ~= nil then
        return
    end
    inst._starfall_cam = {
        distance = cam:GetDistance(),
        controllable = cam:IsControllable(),
    }
    cam:SetControllable(false)
    if cam.maxdist ~= nil then
        cam:SetDistance(cam.maxdist)
    end
end

local function CameraRestore(inst)
    if not IsLocalPlayer(inst) then
        return
    end
    local saved = inst._starfall_cam
    inst._starfall_cam = nil
    local cam = GLOBAL.TheCamera
    if cam == nil or saved == nil then
        return
    end
    cam:SetDistance(saved.distance)
    cam:SetControllable(saved.controllable ~= false)
end

local function CameraShake(inst)
    if not IsLocalPlayer(inst) then
        return
    end
    local now = GLOBAL.GetTime()
    if inst._starfall_shaken ~= nil and now ~= nil and (now - inst._starfall_shaken) < 0.2 then
        return
    end
    inst._starfall_shaken = now
    local cam = GLOBAL.TheCamera
    local shake = GLOBAL.CAMERASHAKE
    if cam ~= nil and shake ~= nil then
        cam:Shake(shake.FULL, 0.4, 0.02, 0.25)
    end
end

local function OnExit(inst, nextstate)
    if STARFALL_STATE[nextstate] then
        return
    end
    Common.EndFlight(inst)
    CameraRestore(inst)
    Common.HideScope(inst)
end

AddStategraphState("wilson", State({
    name = "starfall_rise",
    tags = TAGS,

    onenter = function(inst)
        local cast = inst._starfall
        if cast == nil then
            AbortToIdle(inst)
            return
        end
        StopMoving(inst)
        Common.StartFlight(inst)
        Common.SpawnZones(inst)
        Common.Say(inst, "success")
        CameraPull(inst)
        Common.ShowScope(inst)
        if inst.SoundEmitter ~= nil then
            inst.SoundEmitter:PlaySound("meta3/wigfrid/spear_lighting_lunge")
            inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_whoosh")
        end
        inst.AnimState:PlayAnimation("throw_pre")
        inst.AnimState:PushAnimation("throw", false)
        inst:ForceFacePoint(cast.dest:Get())
        local x, _, z = inst.Transform:GetWorldPosition()
        inst.sg.statemem.x = x
        inst.sg.statemem.z = z
        inst.sg.statemem.t = 0
    end,

    onupdate = function(inst, dt)
        local cast = inst._starfall
        if cast == nil then
            AbortToIdle(inst)
            return
        end
        local tuning = Common.Tuning()
        inst.sg.statemem.t = inst.sg.statemem.t + dt
        local k = math.min(1, inst.sg.statemem.t / tuning.rise_time)
        local ease = k * k * (3 - 2 * k)
        Common.HoldHeight(inst, inst.sg.statemem.x, inst.sg.statemem.z, tuning.peak * ease)
        inst:ForceFacePoint(cast.dest:Get())
        if k >= 1 then
            inst.sg:GoToState("starfall_hang")
        end
    end,

    onexit = OnExit,
}))

AddStategraphState("wilson", State({
    name = "starfall_hang",
    tags = TAGS,

    onenter = function(inst)
        local cast = inst._starfall
        if cast == nil then
            AbortToIdle(inst)
            return
        end
        StopMoving(inst)
        inst.AnimState:PlayAnimation("idle_loop", true)
        local x, _, z = inst.Transform:GetWorldPosition()
        inst.sg.statemem.x = x
        inst.sg.statemem.z = z
        Common.HoldHeight(inst, x, z, Common.Tuning().peak)
        inst:ForceFacePoint(cast.dest:Get())
        inst.sg:SetTimeout(Common.LaunchSpear(inst))
    end,

    onupdate = function(inst)
        local cast = inst._starfall
        if cast == nil then
            AbortToIdle(inst)
            return
        end
        Common.HoldHeight(inst, inst.sg.statemem.x, inst.sg.statemem.z, Common.Tuning().peak)
        inst:ForceFacePoint(cast.dest:Get())
    end,

    events = {
        EventHandler("starfall_spearhit", function(inst)
            if inst.sg.statemem.dived or inst._starfall == nil then
                return
            end
            inst.sg.statemem.dived = true
            inst.sg:GoToState("starfall_dive")
        end),
    },

    ontimeout = function(inst)
        if inst.sg.statemem.dived or inst._starfall == nil then
            return
        end
        inst.sg.statemem.dived = true
        Common.EnsurePhase1(inst)
        inst.sg:GoToState("starfall_dive")
    end,

    onexit = OnExit,
}))

AddStategraphState("wilson", State({
    name = "starfall_dive",
    tags = TAGS,

    onenter = function(inst)
        local cast = inst._starfall
        if cast == nil then
            AbortToIdle(inst)
            return
        end
        StopMoving(inst)
        local tuning = Common.Tuning()
        local origin = cast.origin or cast.dest
        local lx, lz = Common.SlideStart(cast, tuning.slide_length)
        inst.sg.statemem.x = origin.x
        inst.sg.statemem.z = origin.z
        inst.sg.statemem.y = tuning.peak
        inst.sg.statemem.land_x = lx
        inst.sg.statemem.land_z = lz
        inst.sg.statemem.t = 0
        inst.sg.statemem.sliding = false
        Common.HoldHeight(inst, origin.x, origin.z, tuning.peak)
        inst:ForceFacePoint(cast.dest:Get())
        inst.AnimState:PlayAnimation("spearjab_pre")
        inst.AnimState:PushAnimation("spearjab", false)
        inst._starfall_firepos = nil
    end,

    onupdate = function(inst, dt)
        local cast = inst._starfall
        if cast == nil then
            AbortToIdle(inst)
            return
        end
        local tuning = Common.Tuning()
        local dest = cast.dest
        inst.sg.statemem.t = inst.sg.statemem.t + dt
        if not inst.sg.statemem.sliding then
            local k = math.min(1, inst.sg.statemem.t / tuning.dive_time)
            local ease = k * k
            local x = inst.sg.statemem.x + (inst.sg.statemem.land_x - inst.sg.statemem.x) * ease
            local z = inst.sg.statemem.z + (inst.sg.statemem.land_z - inst.sg.statemem.z) * ease
            local y = inst.sg.statemem.y * (1 - ease)
            Common.HoldHeight(inst, x, z, y)
            inst:ForceFacePoint(dest.x, 0, dest.z)
            if k >= 1 then
                inst.sg.statemem.sliding = true
                inst.sg.statemem.t = 0
                inst.sg.statemem.x = inst.sg.statemem.land_x
                inst.sg.statemem.z = inst.sg.statemem.land_z
                inst._starfall_firepos = nil
                Common.HoldHeight(inst, inst.sg.statemem.land_x, inst.sg.statemem.land_z, 0)
            end
            return
        end
        local slide_time = tuning.slide_time or 0.4
        local k = math.min(1, inst.sg.statemem.t / slide_time)
        local ease = k * k
        local x = inst.sg.statemem.x + (dest.x - inst.sg.statemem.x) * ease
        local z = inst.sg.statemem.z + (dest.z - inst.sg.statemem.z) * ease
        Common.HoldHeight(inst, x, z, 0)
        if (dest.x - x) * (dest.x - x) + (dest.z - z) * (dest.z - z) > 0.04 then
            inst:ForceFacePoint(dest.x, 0, dest.z)
        end
        Common.SpawnFireWave(inst)
        if k >= 1 then
            inst.sg:GoToState("starfall_land")
        end
    end,

    onexit = function(inst, nextstate)
        inst._starfall_firepos = nil
        OnExit(inst, nextstate)
    end,
}))

AddStategraphState("wilson", State({
    name = "starfall_land",
    tags = TAGS,

    onenter = function(inst)
        local cast = inst._starfall
        if cast == nil then
            AbortToIdle(inst)
            return
        end
        local dest = cast.dest
        inst.Physics:Teleport(dest.x, 0, dest.z)
        Common.DoDiveDamage(inst)
        Common.EndFlight(inst)
        CameraShake(inst)
        inst.AnimState:PlayAnimation("spearjab_pre")
        inst.AnimState:PushAnimation("spearjab", false)
        inst.sg:SetTimeout(Common.Tuning().recover_time)
    end,

    ontimeout = function(inst)
        if inst.components.health ~= nil and inst.components.health:IsDead() then
            return
        end
        inst.sg:GoToState("idle")
    end,

    onexit = OnExit,
}))

local function ClientShowSpear(inst)
    if inst.AnimState ~= nil then
        inst.AnimState:Show("swap_object")
    end
    if inst.DynamicShadow ~= nil then
        inst.DynamicShadow:Enable(true)
    end
end

local function ClientHideSpear(inst)
    if inst.AnimState ~= nil then
        inst.AnimState:Hide("swap_object")
    end
end

local function ClientShadow(inst, enabled)
    if inst.DynamicShadow ~= nil then
        inst.DynamicShadow:Enable(enabled)
    end
end

local function ClientOnExit(inst, nextstate)
    if STARFALL_STATE[nextstate] then
        return
    end
    ClientShowSpear(inst)
    CameraRestore(inst)
    Common.HideScope(inst)
end

local function AddClientState(name, onenter)
    AddStategraphState("wilson_client", State({
        name = name,
        tags = TAGS,
        onenter = onenter,
        onexit = ClientOnExit,
    }))
end

AddClientState("starfall_rise", function(inst)
    StopMoving(inst)
    ClientShadow(inst, false)
    CameraPull(inst)
    Common.ShowScope(inst)
    inst.AnimState:PlayAnimation("throw_pre")
    inst.AnimState:PushAnimation("throw", false)
end)

AddClientState("starfall_hang", function(inst)
    StopMoving(inst)
    ClientShadow(inst, false)
    ClientHideSpear(inst)
    inst.AnimState:PlayAnimation("idle_loop", true)
end)

AddClientState("starfall_dive", function(inst)
    StopMoving(inst)
    ClientShadow(inst, false)
    ClientHideSpear(inst)
    inst.AnimState:PlayAnimation("idle_loop", true)
end)

AddClientState("starfall_land", function(inst)
    StopMoving(inst)
    ClientShowSpear(inst)
    CameraShake(inst)
    inst.AnimState:PlayAnimation("spearjab_pre")
    inst.AnimState:PushAnimation("spearjab", false)
end)
