local assets = {
    Asset("ANIM", "anim/spear_wathgrithr_lightning.zip"),
}

local function OnUpdate(inst)
    local arc = inst._arc
    if arc == nil or inst._resolved then
        return true
    end

    local duration = arc.dur
    if duration <= 0 then
        duration = 0.05
    end
    local k = math.min(1, (GetTime() - arc.t0) / duration)
    local x = arc.x0 + (arc.x1 - arc.x0) * k
    local z = arc.z0 + (arc.z1 - arc.z0) * k
    local y = arc.y0 * (1 - k) + math.sin(k * PI) * 1.1 * (1 - k)

    inst.Physics:Teleport(x, math.max(0, y), z)
    inst:ForceFacePoint(arc.x1, 0, arc.z1)

    if k >= 1 then
        inst._resolved = true
        inst.components.complexprojectile:Hit()
    end
    return true
end

local function OnHit(inst, attacker)
    local api = rawget(_G, "STARFALL")
    if api ~= nil and api.OnSpearLand ~= nil then
        api.OnSpearLand(inst, attacker)
    elseif inst:IsValid() then
        inst:Remove()
    end
end

local function SetupAppearance(inst, charged)
    if charged then
        inst.AnimState:PlayAnimation("idle_loop", true)
        inst.AnimState:SetSymbolBloom("bolt_b")
        inst.AnimState:SetSymbolBloom("bolt_c")
        inst.AnimState:SetSymbolBloom("bolt_f")
        inst.AnimState:SetSymbolLightOverride("bolt_b", 0.5)
        inst.AnimState:SetSymbolLightOverride("bolt_c", 0.5)
        inst.AnimState:SetSymbolLightOverride("bolt_f", 0.5)
        inst.AnimState:SetSymbolLightOverride("glow", 0.25)
        inst.AnimState:SetLightOverride(0.1)
    else
        inst.AnimState:PlayAnimation("idle")
    end
end

local STICK_TIME = 1.6

local function StickInGround(inst, x, z)
    local arc = inst._arc
    local dx = 1
    local dz = 0
    if arc ~= nil then
        dx = arc.x1 - arc.x0
        dz = arc.z1 - arc.z0
    end
    local dist = math.sqrt(dx * dx + dz * dz)
    if dist < 0.001 then
        dx, dz, dist = 1, 0, 1
    end
    dx = dx / dist
    dz = dz / dist

    local back = 0.55
    inst.Physics:Stop()
    inst.Physics:SetMotorVel(0, 0, 0)
    inst.Physics:Teleport(x - dx * back, 0.35, z - dz * back)
    inst:ForceFacePoint(x, 0, z)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetScale(1.8, 0.7)
    inst.Transform:SetScale(1.15, 1.15, 1.15)

    local started = GetTime()
    inst:DoPeriodicTask(0.1, function(spear)
        if not spear:IsValid() then
            return
        end
        local k = (GetTime() - started) / STICK_TIME
        if k > 0.65 then
            local alpha = 1 - (k - 0.65) / 0.35
            spear.AnimState:SetMultColour(1, 1, 1, math.max(0, alpha))
        end
    end)
    inst:DoTaskInTime(STICK_TIME, inst.Remove)
end

local function BeginArc(inst, x0, y0, z0, x1, z1, duration, attacker)
    inst._arc = {
        x0 = x0,
        y0 = y0,
        z0 = z0,
        x1 = x1,
        z1 = z1,
        t0 = GetTime(),
        dur = duration,
        attacker = attacker,
    }
    inst.Physics:Teleport(x0, y0, z0)
    inst:ForceFacePoint(x1, 0, z1)

    local projectile = inst.components.complexprojectile
    projectile:SetHorizontalSpeed(math.max(1, duration))
    projectile:SetGravity(-20)
    projectile:SetOnUpdate(OnUpdate)
    projectile:SetOnHit(OnHit)
    projectile:Launch(Vector3(x1, 0, z1), attacker, nil)

    inst:DoTaskInTime(duration + 0.25, function(spear)
        if spear:IsValid() and not spear._resolved then
            spear._resolved = true
            spear.components.complexprojectile:Hit()
        end
    end)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeProjectilePhysics(inst, 1, 0.2)
    inst.Physics:ClearCollisionMask()
    inst.Physics:SetDontRemoveOnSleep(true)

    inst.Transform:SetScale(1.25, 1.25, 1.25)
    inst.AnimState:SetBank("spear_wathgrithr_lightning")
    inst.AnimState:SetBuild("spear_wathgrithr_lightning")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetSortOrder(3)

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst:AddTag("projectile")

    inst.entity:SetCanSleep(false)
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false
    inst.SetupAppearance = SetupAppearance
    inst.BeginArc = BeginArc
    inst.StickInGround = StickInGround

    inst:AddComponent("complexprojectile")

    return inst
end

return Prefab("wathgrithr_starfall_spear", fn, assets)
