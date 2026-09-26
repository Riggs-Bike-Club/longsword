-- Returns a random inspect animation, preferring the InspectAnimations list and falling back to the single InspectAnimation field.
function SWEP:GetInspectAnim()
	local anims = self.InspectAnimations
	if anims and #anims > 0 then
		return anims[math.random(#anims)]
	end

	return self.InspectAnimation
end

--- Starts one interruptible inspect per reload press without locking firing for the animation duration.
function SWEP:Inspect()
    if ( !self.InspectArmed or !self:CanInspect() ) then return end
    if ( ( self.NextInspectAllowed or 0 ) > CurTime() ) then return end

    self.InspectArmed = false

    local duration = self:DoInspect() or 0
    self.NextInspectAllowed = CurTime() + duration + ( self.InspectCooldown or 0 )
end

function SWEP:Reload()
	self.HammerDown = false

	if self:UsesProjectileAttack() then return end
	if self:UsesMeleeAttack() then return end

	if self:Clip1() >= self:GetMaxClip1() then
		return self:Inspect()
	end

	if not self:CanReload() then return end

	-- self:EmitWeaponSound("LS_Generic.Reload")

    if self:UsesShotgunReload() then
        return self:ReloadShotgun()
    end

	self:GetOwner():DoReloadEvent()

	local anim = self.ReloadAnimation or ACT_VM_RELOAD
	if self.DoEmptyReloadAnim and self:IsClipEmpty() then
		anim = self.EmptyReloadAnimation or ACT_VM_RELOAD_EMPTY
	end

	self:PlayAnim(anim)
	self:QueueIdle()

	if self.ReloadSound then 
		self:EmitSound(self.ReloadSound) 
	elseif self.OnReload then
		self.OnReload(self)
	end

	self:SetReloading( true )
	self:SetReloadTime( CurTime() + self:GetOwner():GetViewModel():SequenceDuration() )

	hook.Run("LongswordWeaponReload", self:GetOwner(), self)
end

function SWEP:FinishReload()
	self:SetReloading( false )

	local amount = math.min( self:GetMaxClip1() - self:Clip1(), self:Ammo1() )

	self:SetClip1( self:Clip1() + amount )
	self:GetOwner():RemoveAmmo( amount, self:GetPrimaryAmmoType() )
end
