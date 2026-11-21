local function AnnounceReady(inst)
    if not inst:IsValid() or inst:HasTag("playerghost") then
        return
    end
    if inst.components.health ~= nil and inst.components.health:IsDead() then
        return
    end
    local api = rawget(_G, "STARFALL")
    if api ~= nil and api.Say ~= nil then
        api.Say(inst, "ready")
    end
end

local StarfallCaster = Class(function(self, inst)
    self.inst = inst
    self.cooldown_end = 0
    inst:ListenForEvent("onremove", function()
        if self._ready_task ~= nil then
            self._ready_task:Cancel()
            self._ready_task = nil
        end
    end)
end)

function StarfallCaster:SetCooldown(seconds)
    self.cooldown_end = GetTime() + seconds
    if self._ready_task ~= nil then
        self._ready_task:Cancel()
        self._ready_task = nil
    end
    if seconds ~= nil and seconds > 0 then
        self._ready_task = self.inst:DoTaskInTime(seconds, function()
            self._ready_task = nil
            AnnounceReady(self.inst)
        end)
    end
end

function StarfallCaster:GetTimeLeft()
    return math.max(0, self.cooldown_end - GetTime())
end

function StarfallCaster:IsReady()
    return self:GetTimeLeft() <= 0
end

function StarfallCaster:OnSave()
    local left = self:GetTimeLeft()
    if left > 0 then
        return { cooldown_left = left }
    end
end

function StarfallCaster:OnLoad(data)
    if data ~= nil and data.cooldown_left ~= nil and data.cooldown_left > 0 then
        self:SetCooldown(data.cooldown_left)
    end
end

return StarfallCaster
