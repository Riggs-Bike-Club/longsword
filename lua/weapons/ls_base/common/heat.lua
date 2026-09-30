--- Returns the current heat after elapsed cooling, including time spent holstered.
---@return number heat
function SWEP:GetCurrentHeat()
    if ( !self.Overheat ) then return 0 end

    local elapsed = math.max(CurTime() - self:GetHeatDecayTime(), 0)
    return math.max(self:GetHeatAmount() - elapsed * (self.HeatDissipation or 25), 0)
end

--- Adds one shot's heat and marks the weapon for recovery when it reaches capacity.
function SWEP:AddShotHeat()
    if ( !self.Overheat ) then return end

    local capacity = math.max(self.HeatCapacity or 75, 1)
    local heat = math.min(self:GetCurrentHeat() + (self.HeatPerShot or 1), capacity)
    self:SetHeatAmount(heat)
    self:SetHeatDecayTime(CurTime() + self.Primary.Delay + (self.HeatDelayTime or 0.25))
    if ( heat >= capacity ) then
        self:SetOverheated(self:HasAnimation("fix"))
        self:SetHeatLocked(self.HeatLockout == true)
        self:ResetTriggerDelay()
    end
end

--- Reports whether overheating or its recovery animation currently blocks actions.
---@return boolean bBlocked
function SWEP:IsHeatBlocked()
    return self.Overheat and (self:GetOverheated() or self:GetHeatLocked() or self:GetHeatRecoveryEnd() > CurTime()) or false
end

--- Starts the authored heat recovery and clears heat at the configured progress point.
function SWEP:HeatThink()
    if ( !self.Overheat ) then return end

    local now = CurTime()
    if ( self:GetHeatLocked() and self:GetCurrentHeat() <= 0 ) then
        self:SetHeatLocked(false)
    end

    if ( self:GetHeatFixTime() > 0 and now >= self:GetHeatFixTime() ) then
        self:SetHeatFixTime(0)
        self:SetOverheated(false)
        if ( self.HeatFix ) then
            self:SetHeatAmount(0)
            self:SetHeatLocked(false)
        end
    end

    if ( !self:GetOverheated() or self:GetHeatFixTime() > 0 ) then return end
    if ( now < self:GetHeatDecayTime() or self.HolsterAnimEnd ) then return end

    local duration = self:PlayAnimation("fix") or 0
    local endTime = now + duration
    self:SetIronsights(false)
    self:SetHeatRecoveryEnd(endTime)
    self:SetHeatFixTime(now + duration * (self.HeatFixProgress or 0.8))
    self:SetNextPrimaryFire(endTime)
    self:SetReloadTime(endTime)
    self:SetNextIdle(endTime)
end
