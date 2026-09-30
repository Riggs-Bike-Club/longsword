function SWEP:ShootBullet(damage, num_bullets, aimcone)
	local bullet = {}

	bullet.Num 	= num_bullets
	bullet.Src 	= self:GetOwner():GetShootPos() -- Source
	bullet.Dir 	= self:GetOwner():GetAimVector() -- Dir of bullet
	bullet.Spread 	= Vector(aimcone, aimcone, 0)	-- Aim Cone
    if ( self.Spread.Radial ) then
        local seed = self:EntIndex() + engine.TickCount() + 1
        local rotation = util.SharedRandom("longsword.spread", 0, 360, seed)
        local angle = Angle(math.sin(rotation), math.cos(rotation), 0)
        angle:Mul(aimcone * util.SharedRandom("longsword.spread.radius", 0, 45, seed) * math.sqrt(2))
        angle:Add(bullet.Dir:Angle())
        bullet.Dir = angle:Forward()
        bullet.Spread = Vector()
    end

	if self.Primary.Tracer then
		bullet.TracerName = self.Primary.Tracer
	end

	if self.Primary.Range then
		bullet.Distance = self.Primary.Range
	end

	bullet.Tracer	= 1 -- Show a tracer on every x bullets
	bullet.Force	= self.Primary.Force or 1 -- Amount of force to give to phys objects
	bullet.Damage	= damage
	bullet.AmmoType = ""

	if CLIENT then
		bullet.Callback = function(attacker, tr)
			debugoverlay.Cross(tr.HitPos, 2, 3, Color(255, 0, 0), true)
		end
	end

    if ( self.Primary.DamageType or self.Primary.DamageMin or self.Primary.ImpactEffect ) then
        bullet.Callback = function(attacker, trace, damageInfo)
            if ( self.Primary.DamageType ) then
                damageInfo:SetDamageType(self.Primary.DamageType)
            end
            if ( self.Primary.DamageMin ) then
                damageInfo:SetDamage(self:GetDamageAtRange(trace.StartPos:Distance(trace.HitPos)))
            end
            if ( self.Primary.ImpactEffect ) then
                local effect = EffectData()
                effect:SetOrigin(trace.HitPos)
                effect:SetNormal(trace.HitNormal)
                util.Effect(self.Primary.ImpactEffect, effect, true)
            end
        end
    end

	self:GetOwner():FireBullets(bullet)

	self:ShootEffects()
end

function SWEP:AddRecoil()
	self:SetRecoil( math.Clamp( self:GetRecoil() + self.Primary.Recoil * 0.4, 0, self.Primary.MaxRecoil or 1 ) )
end

function SWEP:CalculateSpread()
    if ( self.Spread.Multiplicative ) then
        local spread = self.Primary.Cone
        local owner = self:GetOwner()
        if ( !self:GetIronsights() ) then
            spread = (spread + (self.Spread.HipFireAdd or 0)) * (self.Spread.HipFireMod or 1)
        end
        if ( self.Overheat ) then
            spread = spread + (self.Spread.HeatAdd or 0) * self:GetCurrentHeat() / math.max(self.HeatCapacity or 75, 1)
        end
        local moving = math.Clamp(owner:GetVelocity():Length2D() / math.max(owner:GetWalkSpeed(), 1), 0, 1)
        spread = (spread + (self.Spread.MoveAdd or 0) * moving) * Lerp(moving, 1, self.Spread.MoveMod or 1)
        return spread
    end
	local spread = self.Primary.Cone
	local maxSpeed = self.LoweredPos and self:GetOwner():GetWalkSpeed() or self:GetOwner():GetRunSpeed()

	spread = spread + self.Primary.Cone * math.Clamp( self:GetOwner():GetVelocity():Length2D() / maxSpeed, 0, self.Spread.VelocityMod )
	spread = spread + self:GetRecoil() * self.Spread.RecoilMod

	if not self:GetOwner():IsOnGround() then
		spread = spread * self.Spread.AirMod
	end

	if self:GetOwner():IsOnGround() and self:GetOwner():Crouching() then
		spread = spread * self.Spread.CrouchMod
	end

	if self:GetIronsights() then
		spread = spread * (self.Spread.IronsightsMod or 1)
	end

	spread = math.Clamp( spread, self.Spread.Min, self.Spread.Max )

	if CLIENT then
		self.LastSpread = spread
	end

	return spread
end

--- Returns linear damage falloff between the configured distances in Source units.
---@param distance number
---@return number damage
function SWEP:GetDamageAtRange(distance)
    local near = self.Primary.RangeMin or 0
    local far = math.max(self.Primary.RangeMax or near, near + 1)
    local fraction = math.Clamp((distance - near) / (far - near), 0, 1)
    return Lerp(fraction, self.Primary.Damage, self.Primary.DamageMin or self.Primary.Damage)
end

function SWEP:PrimaryAttack()
	if self:UsesProjectileAttack() then
		return self:PrimaryProjectileAttack()
	end

	if self:UsesMeleeAttack() then
		return self:PrimaryMeleeAttack()
	end

	if not self:CanShoot() then return end
    if ( self.Bash and self:GetOwner():KeyDown(IN_USE) and !self:GetIronsights() ) then
        return self:BashAttack()
    end

    local clip = self:GetAvailablePrimaryAmmo()
    if ( clip > 0 and !self:PrepareTriggerDelay() ) then return end

	if self.Primary.Burst and clip >= 3 then
		self:SetBursting(true)
		self.Burst = 3

		local delay = CurTime() + ((self.Primary.Delay * 3) + (self.Primary.BurstEndDelay or 0.3))
		self:SetNextPrimaryFire(delay)
		self:SetReloadTime(delay)
	elseif clip >= 1 then
		self:Shoot()
		self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	else
        if ( self.BottomlessClip ) then
            self:ResetTriggerDelay()
            self:EmitWeaponSound(self.EmptySound)
        end
        if ( !self.NoDryFireAnim and self:GetDryFireAnim() != nil ) then
			if self.HammerDown == true then return end
			self:PlayAnim(self:GetDryFireAnim())
			self:QueueIdle()

			if self.EmptySound then
				self:EmitWeaponSound(self.EmptySound)
			end

			self.HammerDown = true
		end

		self:SetNextPrimaryFire(CurTime() + 1)
	end
end

function SWEP:Shoot()
    if ( self.BottomlessClip and self:Ammo1() > 0 ) then
        self:GetOwner():RemoveAmmo(1, self:GetPrimaryAmmoType())
    else
        self:TakePrimaryAmmo(1)
    end
    if ( self.TriggerDelay ) then
        self:SetTriggerFired(true)
    end

	self:ShootBullet(self.Primary.Damage, self.Primary.NumShots, self:CalculateSpread())

	self:AddRecoil()
	self:ViewPunch()
	
	self:SetReloadTime(CurTime() + self.Primary.Delay)
    self:AddShotHeat()
end

function SWEP:SecondaryAttack() 
    if ( self.Bash and self.BashSecondary and self:CanShoot() ) then
        self:BashAttack()
    end
end
