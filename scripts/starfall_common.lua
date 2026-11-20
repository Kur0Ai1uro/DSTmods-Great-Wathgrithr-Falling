local SpDamageUtil = require("components/spdamageutil")

local Common = {}

local LINES = {
    no_spear = "我需要奔雷矛！",
    no_hunger = "腹中空空！",
    cooldown = "还不能再次降下！",
    bad_land = "那里无法降落！",
    busy = "此刻无法飞升！",
    success = "星陨！",
}

local AREA_CANT = { "INLIMBO", "playerghost", "wall", "companion", "FX", "NOCLICK" }

function Common.Tuning()
    return _G.STARFALL_TUNING
end

function Common.Say(inst, reason)
    local line = LINES[reason]
    if line == nil or inst.components.talker == nil then
        return
    end
    inst.components.talker:Say(line, reason == "success" and 1.6 or 2.4)
end

local function RestoreCollision(inst)
    inst.Physics:SetCollisionMask(
        COLLISION.WORLD,
        COLLISION.OBSTACLES,
        COLLISION.SMALLOBSTACLES,
        COLLISION.CHARACTERS,
        COLLISION.GIANTS
    )
end

function Common.HideWeapon(inst)
    inst.AnimState:Hide("swap_object")
    local cast = inst._starfall
    local weapon = cast ~= nil and cast.weapon or nil
    if weapon ~= nil and weapon:IsValid() and weapon.fx ~= nil then
        weapon.fx:Hide()
    end
end

local function ShowWeapon(inst, cast)
    inst.AnimState:Show("swap_object")
    local weapon = cast ~= nil and cast.weapon or nil
    if weapon ~= nil and weapon:IsValid() and weapon.fx ~= nil then
        weapon.fx:Show()
    end
end

function Common.StartFlight(inst)
    if inst._starfall_flying then
        return
    end
    inst._starfall_flying = true
    if inst.components.health ~= nil then
        inst._starfall_was_invincible = inst.components.health.invincible == true
        inst.components.health:SetInvincible(true)
    end
    inst:AddTag("notarget")
    if inst.DynamicShadow ~= nil then
        inst.DynamicShadow:Enable(false)
    end
    -- 地面碰撞会把角色高度按回 0，飞行期间清掉全部碰撞，落地再按 SGwilson 的掩码恢复。
    inst.Physics:ClearCollisionMask()
    inst.Physics:Stop()
    inst.Physics:SetMotorVel(0, 0, 0)
    if inst.components.locomotor ~= nil then
        inst.components.locomotor:Stop()
    end
    inst:ClearBufferedAction()
end

function Common.EndFlight(inst)
    if not inst._starfall_flying and inst._starfall == nil then
        return
    end
    local cast = inst._starfall
    inst._starfall_flying = nil
    inst._starfall = nil

    if inst.Physics ~= nil then
        RestoreCollision(inst)
        inst.Physics:Stop()
        inst.Physics:SetMotorVel(0, 0, 0)
        local x, _, z = inst.Transform:GetWorldPosition()
        if x ~= nil then
            inst.Physics:Teleport(x, 0, z)
        end
    end
    if inst.components.health ~= nil then
        inst.components.health:SetInvincible(inst._starfall_was_invincible == true)
    end
    inst._starfall_was_invincible = nil
    inst:RemoveTag("notarget")
    if inst.DynamicShadow ~= nil then
        inst.DynamicShadow:Enable(true)
    end
    if inst.AnimState ~= nil then
        ShowWeapon(inst, cast)
    end
    if cast ~= nil and cast.spear ~= nil and cast.spear:IsValid() then
        cast.spear:Remove()
    end
    if cast ~= nil and cast.zones ~= nil then
        for i = 1, #cast.zones do
            local zone = cast.zones[i]
            if zone ~= nil and zone:IsValid() then
                zone:Remove()
            end
        end
    end
    if cast ~= nil and cast.warning ~= nil and cast.warning:IsValid() then
        cast.warning:Remove()
    end
end

function Common.HoldHeight(inst, x, z, y)
    if inst.components.locomotor ~= nil then
        inst.components.locomotor:Stop()
    end
    inst.Physics:Stop()
    inst.Physics:Teleport(x, y, z)
    inst.Physics:SetMotorVel(0, 0, 0)
end

function Common.CanLandAt(x, z)
    local map = TheWorld.Map
    if map:IsPointNearHole(Vector3(x, 0, z)) then
        return false
    end
    if not map:IsPassableAtPoint(x, 0, z) then
        return false
    end
    local walls = TheSim:FindEntities(x, 0, z, 1.5, { "wall" }, { "INLIMBO" })
    for i = 1, #walls do
        local wall = walls[i]
        local radius = wall:GetPhysicsRadius(0) + 0.25
        if wall:GetDistanceSqToPoint(x, 0, z) <= radius * radius then
            return false
        end
    end
    return true
end

function Common.ResolveDestination(inst, x, z)
    local tuning = Common.Tuning()
    local px, _, pz = inst.Transform:GetWorldPosition()
    local dx = x - px
    local dz = z - pz
    local dist = math.sqrt(dx * dx + dz * dz)
    if dist < 0.2 then
        local theta = inst.Transform:GetRotation() * DEGREES
        dx = math.cos(theta)
        dz = -math.sin(theta)
        dist = 1
    end
    local clamped = dist
    local max_range = Common.ScopeLayout().aim
    if clamped < tuning.min_range then
        clamped = tuning.min_range
    elseif clamped > max_range then
        clamped = max_range
    end
    local tx = px + dx / dist * clamped
    local tz = pz + dz / dist * clamped
    if not Common.CanLandAt(tx, tz) then
        return nil, nil, "bad_land"
    end
    return tx, tz
end

local function GetLightningSpear(inst)
    local inventory = inst.components.inventory
    if inventory == nil then
        return nil
    end
    local item = inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    if item ~= nil and (item.prefab == "spear_wathgrithr_lightning" or item.prefab == "spear_wathgrithr_lightning_charged") then
        return item
    end
    return nil
end

local function IsBusy(inst)
    if inst:HasTag("playerghost") then
        return true
    end
    if inst.components.health ~= nil and inst.components.health:IsDead() then
        return true
    end
    if inst.components.rider ~= nil and inst.components.rider:IsRiding() then
        return true
    end
    local sg = inst.sg
    if sg == nil then
        return true
    end
    if sg:HasStateTag("starfall") or sg:HasStateTag("dead") or sg:HasStateTag("sleeping")
        or sg:HasStateTag("knockout") or sg:HasStateTag("channeling") or sg:HasStateTag("flight")
        or sg:HasStateTag("transform") then
        return true
    end
    if sg:HasStateTag("busy") and not sg:HasStateTag("attack") then
        return true
    end
    return false
end

local function ShouldElectric(cast, weapon, target)
    if IsEntityElectricImmune(target) then
        return false
    end
    if weapon ~= nil and weapon:IsValid() and weapon.CanElectrocuteTarget ~= nil then
        return weapon:CanElectrocuteTarget(target)
    end
    return target.GetWetMultiplier ~= nil and target:GetWetMultiplier() > 0
end

local function IsValidTarget(inst, ent)
    if ent == inst or not ent:IsValid() then
        return false
    end
    if ent.components.health == nil or ent.components.health:IsDead() then
        return false
    end
    if ent.components.combat == nil then
        return false
    end
    if ent:HasTag("structure") and not ent:HasTag("equipmentmodel") then
        return false
    end
    if ent:HasTag("player") and not TheNet:GetPVPEnabled() then
        return false
    end
    local combat = inst.components.combat
    if not ent:HasTag("player") and combat ~= nil and combat.IsAlly ~= nil and combat:IsAlly(ent) then
        return false
    end
    if ent.components.combat.CanBeAttacked ~= nil and not ent.components.combat:CanBeAttacked(inst) then
        return false
    end
    return true
end

local function SpawnImpact(inst, x, z, phase)
    local dust = SpawnPrefab("groundpound_fx")
    if dust ~= nil then
        dust.Transform:SetPosition(x, 0, z)
    end
    if inst.SoundEmitter == nil then
        return
    end
    if phase == "spear" or phase == "stick" then
        inst.SoundEmitter:PlaySound("dontstarve/impacts/impact_clay_wall_sharp")
        inst.SoundEmitter:PlaySound("meta3/wigfrid/spear_lighting_lunge_thunder")
    else
        local ring = SpawnPrefab("groundpoundring_fx")
        if ring ~= nil then
            ring.Transform:SetPosition(x, 0, z)
        end
        inst.SoundEmitter:PlaySound("dontstarve/movement/bodyfall_dirt")
        inst.SoundEmitter:PlaySound("dontstarve/common/meteor_impact")
        local boom = SpawnPrefab("explode_small")
        if boom ~= nil then
            boom.Transform:SetPosition(x, 0, z)
            boom.Transform:SetScale(1.4, 1.4, 1.4)
        end
        local chunks = SpawnPrefab("ground_chunks_breaking")
        if chunks ~= nil then
            chunks.Transform:SetPosition(x, 0, z)
        end
        local scorch = SpawnPrefab("burntground")
        if scorch ~= nil then
            scorch.Transform:SetPosition(x, 0, z)
            scorch.Transform:SetScale(1.5, 1.5, 1.5)
            scorch:DoTaskInTime(8, scorch.Remove)
        end
    end
end

function Common.SpawnFireWave(inst)
    local x, _, z = inst.Transform:GetWorldPosition()
    local prev = inst._starfall_firepos
    if prev == nil then
        inst._starfall_firepos = { x = x, z = z }
        prev = inst._starfall_firepos
    end
    local dx, dz = x - prev.x, z - prev.z
    local dist = math.sqrt(dx * dx + dz * dz)
    if dist < 0.28 then
        return
    end

    local theta = inst.Transform:GetRotation() * DEGREES
    local rx = math.sin(theta)
    local rz = math.cos(theta)
    local rotation = inst.Transform:GetRotation()
    local cast = inst._starfall
    local scope = cast ~= nil and cast.scope or Common.ScopeLayout()
    local half = scope.world_h * 0.42
    local steps = math.min(4, math.max(1, math.ceil(dist / 0.42)))
    for s = 1, steps do
        local t = s / steps
        local px = prev.x + dx * t
        local pz = prev.z + dz * t
        for i = -2, 2 do
            local flame = SpawnPrefab("warg_mutated_breath_fx")
            if flame ~= nil then
                local side = (i / 2) * half
                flame.Transform:SetPosition(px + rx * side, 0, pz + rz * side)
                flame.Transform:SetRotation(rotation)
                if flame.RestartFX ~= nil then
                    flame:RestartFX(0.78, "latefade")
                end
            end
        end
    end
    inst._starfall_firepos = { x = x, z = z }
end

local function HitTarget(inst, ent, cast, weapon, mult)
    if mult <= 0 or not IsValidTarget(inst, ent) then
        return
    end
    local stimuli = nil
    local electric_mult = 1
    if ShouldElectric(cast, weapon, ent) then
        stimuli = "electric"
        local wet = ent.GetWetMultiplier ~= nil and ent:GetWetMultiplier() or 0
        electric_mult = (cast.electric_damage_mult or 1) + (cast.electric_wet_damage_mult or 0) * wet
        SpawnElectricHitSparks(inst, ent, true)
    end

    local dmg, spdmg
    if weapon ~= nil then
        dmg, spdmg = inst.components.combat:CalcDamage(ent, weapon, electric_mult)
    else
        local ext = inst.components.combat.externaldamagemultipliers
        dmg = (cast.base_damage or 0)
            * (inst.components.combat.damagemultiplier or 1)
            * (ext ~= nil and ext:Get() or 1)
            * electric_mult
            + (inst.components.combat.damagebonus or 0)
        if (cast.planar or 0) > 0 then
            spdmg = { planar = cast.planar }
        end
    end
    dmg = (dmg or 0) * mult
    if spdmg ~= nil then
        spdmg = SpDamageUtil.ApplyMult(spdmg, mult)
    end
    ent.components.combat:GetAttacked(inst, dmg, weapon, stimuli, spdmg)
end

local function PathFalloff(px, pz, ox, oz, dx, dz, length, half_width)
    local vx = dx - ox
    local vz = dz - oz
    local t = 0
    if length > 0.001 then
        t = ((px - ox) * vx + (pz - oz) * vz) / (length * length)
    end
    if t < 0 or t > 1 then
        return nil
    end
    local lx = ox + vx * t
    local lz = oz + vz * t
    local lateral = math.sqrt((px - lx) * (px - lx) + (pz - lz) * (pz - lz))
    if lateral > half_width then
        return nil
    end
    return 1 - 0.5 * (lateral / half_width)
end

local SCOPE_W = 918
local SCOPE_H = 432
local SCOPE_CIRCLE_X = 710
-- 贴图按原比例，宽 16。最远落点比最高镜头正前方再远一截，方便点到画面两侧。
local SCOPE_WORLD_W = 16

function Common.ScopeLayout()
    local dist = 50
    local pitch_deg = 60
    local fov = 35
    local cam = TheCamera
    if cam ~= nil then
        dist = cam.maxdist or dist
        pitch_deg = cam.maxdistpitch or pitch_deg
        fov = cam.fov or fov
    end
    local pitch = pitch_deg * DEGREES
    local height = dist * math.sin(pitch)
    local center = height / math.max(0.2, math.tan(pitch))
    local far_ang = math.max(0.2, pitch - fov * 0.5 * DEGREES)
    local far = height / math.max(0.2, math.tan(far_ang))
    local world_w = SCOPE_WORLD_W
    local world_h = world_w * (SCOPE_H / SCOPE_W)
    local center_u = SCOPE_CIRCLE_X / SCOPE_W
    return {
        world_w = world_w,
        world_h = world_h,
        center_u = center_u,
        back = center_u * world_w,
        aim = math.max(18, (far - center) * 1.4),
    }
end

function Common.SlideStart(cast, slide_length)
    local origin = cast.origin or cast.dest
    local dx = cast.dest.x - origin.x
    local dz = cast.dest.z - origin.z
    local dist = math.sqrt(dx * dx + dz * dz)
    local dirx, dirz = 1, 0
    if dist > 0.001 then
        dirx = dx / dist
        dirz = dz / dist
    end
    local back = cast.scope ~= nil and cast.scope.back or slide_length
    local slide = math.min(back, math.max(dist, 0.5))
    return cast.dest.x - dirx * slide, cast.dest.z - dirz * slide
end

function Common.DoDiveDamage(inst)
    local cast = inst._starfall
    local tuning = Common.Tuning()
    if cast == nil or tuning == nil or inst.components.combat == nil or cast.dest == nil then
        return
    end

    local scope = cast.scope or Common.ScopeLayout()
    local origin = cast.origin or cast.dest
    local dx, dz = cast.dest.x, cast.dest.z
    local vx, vz = dx - origin.x, dz - origin.z
    local dist = math.sqrt(vx * vx + vz * vz)
    local fx, fz = 1, 0
    if dist > 0.001 then
        fx, fz = vx / dist, vz / dist
    end
    local rx, rz = fz, -fx
    local shift = (scope.center_u - 0.5) * scope.world_w
    local cx = dx - fx * shift
    local cz = dz - fz * shift
    local half_l = scope.world_w * 0.5
    local half_w = scope.world_h * 0.5
    local land_radius = tuning.land_radius
    local weapon = cast.weapon
    if weapon ~= nil and not weapon:IsValid() then
        weapon = nil
    end

    SpawnImpact(inst, dx, dz, "slam")

    local reach = math.sqrt(half_l * half_l + half_w * half_w) + land_radius
    local ents = TheSim:FindEntities(cx, 0, cz, math.max(reach, 1), { "_combat" }, AREA_CANT)
    local land_sq = land_radius * land_radius
    for i = 1, #ents do
        local ent = ents[i]
        local ex, _, ez = ent.Transform:GetWorldPosition()
        local along = (ex - cx) * fx + (ez - cz) * fz
        local lat = (ex - cx) * rx + (ez - cz) * rz
        if math.abs(along) <= half_l and math.abs(lat) <= half_w then
            local falloff = 1 - 0.5 * (math.abs(lat) / math.max(0.001, half_w))
            local mult = falloff * tuning.path_mult
            local land_dx = ex - dx
            local land_dz = ez - dz
            if land_dx * land_dx + land_dz * land_dz <= land_sq then
                mult = mult + tuning.land_mult
            end
            HitTarget(inst, ent, cast, weapon, mult)
        end
    end
end

function Common.OnSpearLand(proj, attacker)
    if proj == nil or not proj:IsValid() then
        return
    end
    local x, _, z = proj.Transform:GetWorldPosition()
    local owner = attacker
    if (owner == nil or not owner:IsValid()) and proj._arc ~= nil then
        owner = proj._arc.attacker
    end
    if proj._impacted then
        return
    end
    proj._impacted = true

    if owner ~= nil and owner:IsValid() and owner._starfall ~= nil then
        if owner._starfall.spear == proj then
            owner._starfall.spear = nil
        end
        if not owner._starfall.phase1 then
            owner._starfall.phase1 = true
            owner._starfall.dest = Vector3(x, 0, z)
            SpawnImpact(owner, x, z, "stick")
            owner:PushEvent("starfall_spearhit")
        end
    end
    if proj:IsValid() and proj.StickInGround ~= nil then
        proj:StickInGround(x, z)
    elseif proj:IsValid() then
        proj:Remove()
    end
end

function Common.LaunchSpear(inst)
    local cast = inst._starfall
    local tuning = Common.Tuning()
    if cast == nil or tuning == nil then
        return 0.2
    end

    Common.HideWeapon(inst)

    local x, y, z = inst.Transform:GetWorldPosition()
    local dest = cast.dest
    local dx = dest.x - x
    local dz = dest.z - z
    local dist = math.sqrt(dx * dx + dz * dz)
    local duration = math.max(0.28, dist / tuning.spear_speed)
    cast.spear_timeout = duration + tuning.spear_pad

    local spear = SpawnPrefab("wathgrithr_starfall_spear")
    if spear == nil or spear.BeginArc == nil then
        cast.phase1 = true
        cast.spear_timeout = 0.05
        return cast.spear_timeout
    end

    cast.spear = spear
    if spear.SetupAppearance ~= nil then
        spear:SetupAppearance(cast.charged)
    end
    spear:BeginArc(x, math.max(y, tuning.peak * 0.85), z, dest.x, dest.z, duration, inst)
    return cast.spear_timeout
end

function Common.SpawnZones(inst)
    local cast = inst._starfall
    local tuning = Common.Tuning()
    if cast == nil or cast.zones ~= nil or cast.dest == nil or cast.origin == nil or tuning == nil then
        return
    end
    cast.zones = {}
    local dx, dz = cast.dest.x, cast.dest.z
    local ox, oz = cast.origin.x, cast.origin.z
    local rotation = math.atan2(-(dz - oz), dx - ox) / DEGREES

    local mark = SpawnPrefab("wathgrithr_starfall_zone")
    if mark ~= nil then
        mark.Transform:SetPosition(dx, 0, dz)
        mark.Transform:SetRotation(rotation)
        cast.zones[#cast.zones + 1] = mark
    end
    local warning = SpawnPrefab("meteorwarning")
    if warning ~= nil then
        warning.Transform:SetPosition(dx, 0, dz)
        warning.Transform:SetScale(2.2, 2.2, 2.2)
        cast.warning = warning
    end
    if inst.SoundEmitter ~= nil then
        inst.SoundEmitter:PlaySound("dontstarve/common/staff_blink")
    end
end

function Common.EnsurePhase1(inst)
    local cast = inst._starfall
    if cast == nil or cast.phase1 then
        return
    end
    cast.phase1 = true
end

function Common.TryStarfall(inst, x, z)
    if inst == nil or not inst:IsValid() or not TheWorld.ismastersim then
        return
    end
    if inst.prefab ~= "wathgrithr" then
        return
    end
    if inst.sg ~= nil and inst.sg:HasStateTag("starfall") then
        return
    end

    local tuning = Common.Tuning()
    if tuning == nil then
        return
    end
    if IsBusy(inst) then
        Common.Say(inst, "busy")
        return
    end

    local weapon = GetLightningSpear(inst)
    if weapon == nil then
        Common.Say(inst, "no_spear")
        return
    end

    if inst.components.starfallcaster == nil then
        inst:AddComponent("starfallcaster")
    end
    if not inst.components.starfallcaster:IsReady() then
        Common.Say(inst, "cooldown")
        return
    end

    local hunger = inst.components.hunger
    if hunger == nil or hunger.current < tuning.hunger then
        Common.Say(inst, "no_hunger")
        return
    end

    local tx, tz, reason = Common.ResolveDestination(inst, x, z)
    if tx == nil then
        Common.Say(inst, reason or "bad_land")
        return
    end

    local weapon_cmp = weapon.components.weapon
    local px, _, pz = inst.Transform:GetWorldPosition()
    inst._starfall = {
        origin = Vector3(px, 0, pz),
        dest = Vector3(tx, 0, tz),
        weapon = weapon,
        charged = weapon.prefab == "spear_wathgrithr_lightning_charged",
        base_damage = FunctionOrValue(weapon_cmp.damage, weapon, inst, nil),
        planar = weapon.components.planardamage ~= nil and weapon.components.planardamage:GetDamage() or 0,
        electric_damage_mult = weapon_cmp.electric_damage_mult or 1,
        electric_wet_damage_mult = weapon_cmp.electric_wet_damage_mult or 0,
        phase1 = false,
        spear = nil,
        scope = Common.ScopeLayout(),
    }

    inst.components.starfallcaster:SetCooldown(tuning.cooldown)
    hunger:DoDelta(-tuning.hunger)
    if weapon.components.finiteuses ~= nil then
        weapon.components.finiteuses:Use(tuning.uses)
    end
    if not weapon:IsValid() then
        inst._starfall.weapon = nil
    end

    inst:ForceFacePoint(tx, 0, tz)
    inst.sg:GoToState("starfall_rise")
end

local function ScopeMark()
    if ThePlayer == nil or ThePlayer.Transform == nil then
        return nil
    end
    local x, _, z = ThePlayer.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, 0, z, 80, { "starfall_scope" })
    local mark = ents[1]
    if mark ~= nil and mark:IsValid() then
        return mark
    end
    return nil
end

local function UpdateScope(img)
    if img == nil or img.inst == nil or not img.inst:IsValid() or ThePlayer == nil then
        return
    end
    local mark = ScopeMark()
    if mark == nil then
        img:Hide()
        return
    end
    local scope = Common.ScopeLayout()
    local mx, _, mz = mark.Transform:GetWorldPosition()
    local cam = TheCamera
    local heading = cam ~= nil and cam.heading or 0
    local right = (heading + 90) * DEGREES
    local sx, sy = TheSim:GetScreenPos(mx, 0, mz)
    local sx2, sy2 = TheSim:GetScreenPos(mx + math.cos(right), 0, mz + math.sin(right))
    if sx == nil or sy == nil or sx2 == nil or sy2 == nil then
        img:Hide()
        return
    end
    local ppu = math.sqrt((sx2 - sx) * (sx2 - sx) + (sy2 - sy) * (sy2 - sy))
    if ppu ~= ppu or ppu < 0.01 then
        img:Hide()
        return
    end
    local pix_w = ppu * scope.world_w
    local pix_h = ppu * scope.world_h
    img:SetScale(1, 1)
    img:SetSize(pix_w, pix_h)

    local px, _, pz = ThePlayer.Transform:GetWorldPosition()
    local psx, psy = TheSim:GetScreenPos(px, 0, pz)
    local rot = mark.Transform:GetRotation() * DEGREES
    local fx, fy = TheSim:GetScreenPos(mx + math.cos(rot), 0, mz - math.sin(rot))
    local aim_x = (fx or sx) - sx
    local aim_y = (fy or sy) - sy
    if psx ~= nil and psy ~= nil then
        local dx = sx - psx
        local dy = sy - psy
        if dx * dx + dy * dy > 16 then
            aim_x, aim_y = dx, dy
        end
    end
    local len = math.sqrt(aim_x * aim_x + aim_y * aim_y)
    local ux, uy = 1, 0
    if len > 0.001 then
        ux, uy = aim_x / len, aim_y / len
    end
    local ox = (SCOPE_CIRCLE_X / SCOPE_W - 0.5) * pix_w
    img:SetRotation(math.deg(math.atan2(-uy, ux)))
    img:SetPosition(sx - ox * ux, sy - ox * uy)
    img:Show()
end

function Common.HideScope(inst)
    if inst ~= nil and inst ~= ThePlayer then
        return
    end
    local hud = ThePlayer ~= nil and ThePlayer.HUD or nil
    if hud == nil or hud._starfall_scope == nil then
        return
    end
    hud._starfall_scope:Kill()
    hud._starfall_scope = nil
end

function Common.ShowScope(inst)
    if inst == nil or inst ~= ThePlayer or ThePlayer.HUD == nil then
        return
    end
    local hud = ThePlayer.HUD
    if hud._starfall_scope ~= nil then
        return
    end
    local root = hud.under_root or hud.popupstats_root or hud
    local Image = require("widgets/image")
    local img = root:AddChild(Image("images/scope.xml", "scope.tex"))
    img:Hide()
    img:SetClickable(false)
    img:SetTint(1, 1, 1, 0.45)
    img:SetHRegPoint(ANCHOR_MIDDLE)
    img:SetVRegPoint(ANCHOR_MIDDLE)
    img.OnUpdate = UpdateScope
    img:StartUpdating()
    hud._starfall_scope = img
    UpdateScope(img)
end

_G.STARFALL = Common

return Common
