local assets = {
    Asset("ANIM", "anim/reticuleaoe.zip"),
    Asset("ANIM", "anim/gridplacer.zip"),
    Asset("ATLAS", "images/scope.xml"),
    Asset("IMAGE", "images/scope.tex"),
}

-- 原版 reticuleaoe 的 idle 在 AnimState 缩放 1.5 时大约覆盖半径 4。
local SCALE_AT_RADIUS_4 = 1.5
-- gridplacer 的一格大约是 4。
local TILE = 4

local function ApplyLand(inst)
    inst.AnimState:SetBank("reticuleaoe")
    inst.AnimState:SetBuild("reticuleaoe")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGroundFixed)
    local radius = inst._length:value()
    if radius <= 0 then
        return
    end
    local scale = SCALE_AT_RADIUS_4 * (radius / 4)
    inst.AnimState:SetScale(scale, scale)
    inst.AnimState:SetMultColour(1, 0.45, 0.12, 0.95)
    inst.AnimState:SetAddColour(0.35, 0.12, 0, 0)
end

local function ApplyBox(inst)
    local length = inst._length:value()
    local width = inst._width:value()
    local rotation = inst._rot:value()
    if length <= 0 or width <= 0 then
        return
    end
    inst.AnimState:SetBank("gridplacer")
    inst.AnimState:SetBuild("gridplacer")
    inst.AnimState:PlayAnimation("anim", true)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetScale(math.max(length, 0.5) / TILE, width / TILE)
    inst.AnimState:SetMultColour(1, 0.45, 0.12, 0.4)
    inst.AnimState:SetAddColour(0.2, 0.05, 0, 0)
    inst.Transform:SetRotation(rotation)
end

local function Apply(inst)
    local kind = inst._kind:value()
    if kind == 1 then
        ApplyLand(inst)
    elseif kind == 2 then
        ApplyBox(inst)
    end
end

local function SetKind(inst, kind, radius)
    if kind == "land" then
        inst._length:set(radius or 0)
        inst._kind:set(1)
    else
        inst._kind:set(0)
    end
    Apply(inst)
end

local function SetBox(inst, length, width, rotation)
    inst._length:set(length)
    inst._width:set(width)
    inst._rot:set(rotation)
    inst._kind:set(2)
    Apply(inst)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("reticuleaoe")
    inst.AnimState:SetBuild("reticuleaoe")
    inst.AnimState:PlayAnimation("idle")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGroundFixed)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
    inst.AnimState:SetMultColour(1, 1, 1, 0)
    inst.AnimState:SetScale(0, 0)

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst:AddTag("starfall_scope")

    inst._kind = net_tinybyte(inst.GUID, "starfallzone.kind", "starfallzone.dirty")
    inst._length = net_float(inst.GUID, "starfallzone.length", "starfallzone.dirty")
    inst._width = net_float(inst.GUID, "starfallzone.width", "starfallzone.dirty")
    inst._rot = net_float(inst.GUID, "starfallzone.rot", "starfallzone.dirty")
    inst:ListenForEvent("starfallzone.dirty", Apply)

    inst.entity:SetCanSleep(false)
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false
    inst.SetKind = SetKind
    inst.SetBox = SetBox

    return inst
end

return Prefab("wathgrithr_starfall_zone", fn, assets)
