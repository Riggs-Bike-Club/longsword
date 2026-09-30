--- Starts a use-plus-fire gun bash with its own animation, recovery and impact delay.
function SWEP:BashAttack()
    if ( !self.Bash or self:GetNextPrimaryFire() > CurTime() ) then return end

    self:ResetTriggerDelay()
    local duration = self:PlayAnimation("bash") or 0
    local hitDelay = self.PreBashTime or 0.5
    local recovery = math.max(hitDelay + (self.PostBashTime or 0.5), duration * (self.BashMinProgress or 1))
    self:SetNextPrimaryFire(CurTime() + recovery)
    self:SetReloadTime(CurTime() + recovery)
    self:QueueIdle()
    if ( !SERVER ) then return end

    local owner = self:GetOwner()
    local serial = self.animationEventSerial
    timer.Simple(hitDelay, function()
        if ( !IsValid(self) or !IsValid(owner) or !owner:Alive() ) then return end
        if ( self:GetOwner() != owner or owner:GetActiveWeapon() != self or self.animationEventSerial != serial ) then return end

        self:ClubAttack(self.BashDamage or 50, self.BashRange or 64, self.BashHullSize or 8)
    end)
end
