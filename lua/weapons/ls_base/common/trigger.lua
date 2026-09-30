--- Returns usable ammunition, including reserve ammunition for bottomless weapons.
---@return number amount
function SWEP:GetAvailablePrimaryAmmo()
    if ( self.BottomlessClip ) then
        return self:Ammo1() + math.max(self:Clip1(), 0)
    end
    return self:Clip1()
end

--- Resets a charged trigger without changing heat or interrupting a replacement animation.
function SWEP:ResetTriggerDelay()
    if ( !self.TriggerDelay ) then return end

    self:SetTriggerReadyTime(0)
    self:SetTriggerFired(false)
end

--- Starts wind-up once per trigger hold and permits firing only after its deadline.
---@return boolean bReady
function SWEP:PrepareTriggerDelay()
    if ( !self.TriggerDelay ) then return true end
    if ( self:GetTriggerFired() and (!self.Primary.Automatic or self:GetSemiAutomatic()) ) then return false end

    if ( self:GetTriggerReadyTime() == 0 ) then
        self:SetTriggerReadyTime(CurTime() + (self.TriggerDelayTime or 0.2))
        self:PlayAnimation("trigger")
        self:SetNextIdle(self:GetTriggerReadyTime())
        return false
    end

    return CurTime() >= self:GetTriggerReadyTime()
end

--- Cancels wind-up on release or interrupted actions and completes delayed semi-automatic shots while held.
function SWEP:TriggerThink()
    if ( self.SprintToFireTime and self:IsSprinting() ) then
        self:SetSprintReadyTime(CurTime() + self.SprintToFireTime)
    end
    if ( !self.TriggerDelay or self:GetTriggerReadyTime() == 0 ) then return end

    local owner = self:GetOwner()
    if ( !IsValid(owner) or !owner:Alive() or owner:GetActiveWeapon() != self ) then
        self:ResetTriggerDelay()
        return
    end

    if ( self.HolsterAnimEnd or self:GetReloading() or self:GetLowered() or self:IsSprinting() or self:IsHeatBlocked() ) then
        self:ResetTriggerDelay()
        if ( !self.HolsterAnimEnd and !self:IsHeatBlocked() and !self:GetReloading() ) then
            self:PlayAnimation("untrigger")
            self:QueueIdle()
        end
        return
    end

    if ( !owner:KeyDown(IN_ATTACK) or self:GetAvailablePrimaryAmmo() <= 0 ) then
        local bFired = self:GetTriggerFired()
        self:ResetTriggerDelay()
        if ( !bFired or self.TriggerReleaseAnimation ) then
            self:PlayAnimation("untrigger")
            self:QueueIdle()
        end
        return
    end

    if ( !self:GetTriggerFired() and CurTime() >= self:GetTriggerReadyTime() and CurTime() >= self:GetNextPrimaryFire() ) then
        self:PrimaryAttack()
    end
end
