local StarfallCaster = Class(function(self, inst)
    self.inst = inst
    self.cooldown_end = 0
end)

function StarfallCaster:SetCooldown(seconds)
    self.cooldown_end = GetTime() + seconds
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
        self.cooldown_end = GetTime() + data.cooldown_left
    end
end

return StarfallCaster
