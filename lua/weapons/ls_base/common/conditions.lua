--- Requires sprint input as well as movement so releasing sprint immediately frees weapon actions.
---@return boolean bSprinting
function SWEP:IsSprinting()
    local owner = self:GetOwner()
    if ( !IsValid( owner ) ) then return false end
    if ( !owner:KeyDown( IN_SPEED ) or owner:KeyDown( IN_WALK ) or owner:Crouching() ) then return false end

    return owner:GetVelocity():Length2D() > owner:GetRunSpeed() - 50
        and owner:IsOnGround()
end

function SWEP:CanShoot()
    if ( self.SprintToFireTime and self:GetSprintReadyTime() > CurTime() ) then return false end
    if ( self.HolsterAnimEnd or (self.Overheat and self:IsHeatBlocked()) ) then return false end
	if self.ExtraCanShoot and not self:ExtraCanShoot() then return false end

	return not self:GetBursting() and not (self.LoweredPos and self:IsSprinting()) and self:GetReloadTime() < CurTime() and not self:GetLowered()
end

function SWEP:CanIronsight()
    if ( self.Bash and self.BashSecondary ) then return false end
    if ( self.Overheat and self:IsHeatBlocked() ) then return false end
	if self.NoIronsights then
		return false
	end

if self:UsesMeleeAttack() then
return false
end

	return not self:IsSprinting() and not self:GetReloading() and self:GetOwner():IsOnGround() and not self:GetLowered()
end

function SWEP:CanReload()
    if ( self.BottomlessClip or (self.Overheat and self:IsHeatBlocked()) ) then return false end
    local clipSize = self.Primary.ClipSize

    if self:UsesShotgunReload() and self.CanChamberShotgun then
        clipSize = clipSize + 1
    end

    return self:Ammo1() > 0 and self:Clip1() < clipSize
        and !self:GetReloading() and self:GetNextPrimaryFire() < CurTime() and ( self.NextFMToggle or 0 ) < CurTime()
end
