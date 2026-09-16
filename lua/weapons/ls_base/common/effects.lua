function SWEP:ViewPunch()
	if SERVER or (not game.SinglePlayer() and not IsFirstTimePredicted()) then return end
	local punch = Angle()
	local i = 3 * self.Primary.Recoil

	local offset = Angle(math.random(0, -i * 0.9), math.random(-i * 0.25, i * 0.25))
	hook.Run("LongswordRecoil", self, offset)

	self:GetOwner():ViewPunch(offset)
	if IsFirstTimePredicted() and ( CLIENT or game.SinglePlayer() ) then
		self:GetOwner():SetEyeAngles( self:GetOwner():EyeAngles() + offset * 0.2)
	end
end

function SWEP:ShouldResetCustomRecoil()
	if self.UseIronsightsRecoil == false then
		return false
	end

	if self.Recoil then
		if (self.Recoil.IronsightsOnly == true or self.Recoil.IronsightsOnly == nil) and not self:GetIronsights() then
			return false
		end

		if self.Recoil.Enabled == false then
			return false
		end
	elseif not self.Recoil and not self:GetIronsights() then
		return false
	end

	return true
end

function SWEP:ResetCustomRecoil()
	self.RecoilTarget = 1
	self.RecoilSpeed = 64
	self.RecoilRollRandom = math.Rand(-1, 1)
end

function SWEP:ShouldAnimateFire()
	if self.Recoil then
		if self.Recoil.DoFireAnim then
			return true
		end
	end

	if self.UseIronsightsRecoil then
		return false
	end

	return true
end

-- Returns a random entry from a list, the single-sequence field, or the fallback -- in that order. Lets every fire slot accept either a list (picked at random) or one sequence without each caller repeating the check.
function SWEP:PickFireAnim(list, single, fallback)
	if list and #list > 0 then
		return list[math.random(#list)]
	end

	return single or fallback
end

function SWEP:GetFireAnimation()
	local bEmpty = self.DoLastFireAnim and self:IsClipEmpty()

	if self:GetIronsights() then
		-- The shot that empties the clip has its own aimed sequence too, so it is preferred before the normal aimed fire.
		if bEmpty and (self.IronsightsLastFireAnims or self.IronsightsLastFireAnim) then
			return self:PickFireAnim(self.IronsightsLastFireAnims, self.IronsightsLastFireAnim)
		end

		local iron = self.IronsightsAnimation
		if istable(iron) then
			return self:PickFireAnim(iron, nil, ACT_VM_PRIMARYATTACK_1)
		end

		return iron or ACT_VM_PRIMARYATTACK_1
	end

	-- The shot that empties the clip: viewmodels that lock the slide back animate it as a separate sequence (one per fire variant, hence the list) rather than as part of the normal fire animation.
	if bEmpty then
		return self:PickFireAnim(self.LastFireAnims, self.LastFireAnim, ACT_VM_PRIMARYATTACK_EMPTY)
	end

	return self:PickFireAnim(self.FireAnims, self.FireAnim, ACT_VM_PRIMARYATTACK)
end

local smoke = Material("sprites/smoke")
local trail
function SWEP:ShootEffects()
	local ply = self:GetOwner()
	local vm = ply:GetViewModel()
	local fireDuration = 0
	if not self:GetIronsights() or self:ShouldAnimateFire() then
		local anim = self:GetFireAnimation()
		fireDuration = self:PlayAnim(anim) or 0
		self:QueueIdle()
	end

	self:PlayFireSound()
	local muz = vm:LookupAttachment(self.MuzzleAttachment or "muzzle")

    if self.MuzzleEffect and IsFirstTimePredicted() then
        local effect = EffectData()
        effect:SetEntity(self)
        effect:SetOrigin(ply:GetShootPos())
        effect:SetNormal(ply:GetAimVector())
        effect:SetAttachment(muz)
        util.Effect(self.MuzzleEffect, effect, true, false)
    end

	if CLIENT then
		self.BlurFraction = 1
		if self:ShouldResetCustomRecoil() and (game.SinglePlayer() or IsFirstTimePredicted()) then
			self:ResetCustomRecoil()
		end

		self.RecoilCameraRoll = 1
		self.RecoilCameraFreq = math.random(15, 23)
		self.RecoilCameraLastShoot = CurTime()

		local isThirdperson = ply:ShouldDrawLocalPlayer()

		if not isThirdperson and not self.MuzzleEffect then
			local posang = vm:GetAttachment(muz)

			if posang then
				local ef = EffectData()
				ef:SetOrigin(self:GetOwner():GetShootPos())
				ef:SetStart(self:GetOwner():GetShootPos())
				ef:SetNormal(self:GetOwner():EyeAngles():Forward())
				ef:SetEntity(vm)
				ef:SetAttachment(muz)
				ef:SetScale(self.IronsightsMuzzleFlashScale or 1)

				util.Effect(self.IronsightsMuzzleFlash or "ls_muzzleflash", ef)
			end
		end

		if (self.Primary.BulletModel or self.Primary.BulletEffect) and self.Primary.EjectAttachment then
			if self.Primary.BulletEjectDelay then
				timer.Simple(self.Primary.BulletEjectDelay, function()
					if not IsValid(self) then return end
					self:DoBulletEjection()
				end)
			else
				self:DoBulletEjection()
			end
		end
	end

    if not self.MuzzleEffect then
        self:GetOwner():MuzzleFlash()
    end
	self:PlayAnimWorld(ACT_VM_PRIMARYATTACK)
	self:GetOwner():SetAnimation(PLAYER_ATTACK1)

	-- The fire animation queues its own idle above. Queueing a second one here measured whatever the viewmodel happened to be playing, so a shot that plays no fire animation at all (ironsighted, with UseIronsightsRecoil driving the recoil procedurally) queued an idle the full length of the idle loop it was already in -- several seconds during which the weapon counted as mid-animation and refused to swap loops, so the slide stayed forward after the last round.
	if self.CustomShootEffects then
		self:CustomShootEffects()
	end

	if self:ShouldPullback() then
		-- Wait for the fire animation to finish, then the configured delay on top.
		timer.Simple(fireDuration + self:GetPullbackDelay(), function()
			if not IsValid(self) then return end

			self:DoPullback()
		end)
	end
end

-- Pullback (pump) animations -------------------------------------------------
-- Driven by the SWEP.Pullback property list (see ls_base/base.lua). Plays a
-- short viewmodel animation once the fire animation finishes, plus the
-- configured delay on top, used by pump shotguns and other manually-cycled
-- weapons. The legacy PumpDelay / PumpAnimation / GetPumpAnimation properties
-- are still honoured as a fallback.

function SWEP:ShouldPullback()
	-- The shot that empties the clip plays a dedicated last-fire sequence that already cocks the action (or locks the bolt open), so a normal pump on top of it would double the motion.
	if self.DoLastFireAnim and self:IsClipEmpty() then
		return false
	end

	if self.Pullback and self.Pullback.Enabled then
		return true
	end

	return self.PumpDelay != nil
end

function SWEP:GetPullbackDelay()
	if self.Pullback and self.Pullback.Delay then
		return self.Pullback.Delay
	end

	return self.PumpDelay or 0
end

function SWEP:GetPullbackAnimation()
	local pullback = self.Pullback

	if pullback then
		if pullback.Anims and #pullback.Anims > 0 then
			return pullback.Anims[math.random(#pullback.Anims)]
		end

		if pullback.Anim then
			return pullback.Anim
		end
	end

	if self.GetPumpAnimation then
		return self:GetPumpAnimation()
	end

	return self.PumpAnimation or ACT_VM_PULLBACK
end

function SWEP:DoPullback()
	self:PlayAnim(self:GetPullbackAnimation())
	self:QueueIdle()

	local pullback = self.Pullback
	if pullback and pullback.Sound then
		self:EmitSound(pullback.Sound)
	end
end

function SWEP:DoBulletEjection()
	if (self.NextBulletEject or 0) > CurTime() then return end
	self.NextBulletEject = CurTime() + (self.Primary.Delay or 0)

	-- Ejection is deferred by Primary.BulletEjectDelay, so the shot that fired it can easily outlive the owner.
	local vm = self:GetOwnerViewModel()
	if not vm then return end

	local att = self.Primary.EjectAttachment
	local attID = vm:LookupAttachment(att)
	local data = vm:GetAttachment(attID)
	if not data then 
		return longsword.debugPrint(self:GetClass() .. ".Primary.EjectAttachment is invalid!")
	end

	if self.Primary.BulletModel then
		local cs = ClientsideModel(self.Primary.BulletModel)
		cs:SetPos(data.Pos)
		cs:SetAngles(data.Ang)
		cs:Spawn()

		local phy = cs:GetPhysicsObject()
		if IsValid(phy) then
			local dir = self.Primary.BulletDirection or "right"
			local vel
			if dir == "right" then
				vel = vm:GetRight()
			elseif dir == "left" then
				vel = -vm:GetRight()
			elseif dir == "up" then
				vel = vm:GetUp()
			elseif dir == "down" then -- what kind of fucking gun
				vel = -vm:GetUp()
			else
				longsword.debugPrint(self:GetClass() .. ".Primary.BulletDirection is invalid! Defaulting to \"right\".")
				vel = vm:GetRight()
			end

			vel = vel * (self.Primary.BulletEjectForce or 10)
	
			phy:SetVelocity(vel)
		end

		timer.Simple(3, function()
			if not IsValid(cs) then return end

			cs:Remove()
		end)
	elseif self.Primary.BulletEffect then
		local ef = EffectData()
		ef:SetEntity(vm)
		ef:SetAttachment(attID)
		ef:SetOrigin(data.Pos)
		ef:SetAngles(data.Ang)
		ef:SetScale(self.Primary.BulletScale or 1)
		util.Effect(self.Primary.BulletEffect, ef)
	else
		return longsword.debugPrint("DoBulletEjection called on weapon with no bullet properties!")
	end
end
