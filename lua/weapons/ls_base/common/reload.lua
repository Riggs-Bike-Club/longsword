-- Returns a random inspect animation, preferring the InspectAnimations list and falling back to the single InspectAnimation field.
function SWEP:GetInspectAnim()
	local anims = self.InspectAnimations
	if anims and #anims > 0 then
		return anims[math.random(#anims)]
	end

	return self.InspectAnimation
end

function SWEP:Inspect()
	-- Reload() is called every tick while the key is held, so gate on InspectArmed (re-armed in Think only once reload is released) to keep holding from re-triggering, plus a cooldown so rapid re-pressing can't restart it mid-animation.
	if not self.InspectArmed then return end
	if (self.NextInspectAllowed or 0) > CurTime() then return end

	local anim = self:GetInspectAnim()
	if not anim then return end

	self.InspectArmed = false

	local dur = self:PlayAnim(anim) or 0
	if dur > 0 then
		self:SetNextPrimaryFire(CurTime() + dur)
		self.NextInspectAllowed = CurTime() + dur + (self.InspectCooldown or 0)
	end

	self:QueueIdle()
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

	if not self.DoEmptyReloadAnim or self:Clip1() != 0 then
		self:PlayAnim(self.ReloadAnimation or ACT_VM_RELOAD)
	else
		self:PlayAnim(ACT_VM_RELOAD_EMPTY)
	end
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
