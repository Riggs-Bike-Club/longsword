function SWEP:Think()
	self:IronsightsThink()
	self:RecoilThink()
	self:IdleThink()
	self:MovementThink()
	self:InspectThink()
	self:LoweredThink()
	self:FiremodeThink()
	self:SoundThink()

	-- Re-arm the manual (full-clip) inspect only once the reload key is released, so holding reload plays a single inspect instead of restarting it every tick.
	if not self:GetOwner():KeyDown(IN_RELOAD) then
		self.InspectArmed = true
	end

	if self:GetBursting() then self:BurstThink() end
	if self:GetReloading() then self:ReloadThink() end

	if self.CustomThink then
		self:CustomThink()
	end

	if self.DoSprintHoldType then 
		self:SetHoldType( ( self:IsSprinting() and self:GetPassiveHoldType() ) or self.HoldType )
	end
	
	if CLIENT then
		self:SwayThink()
	end

	if not CLIENT then
		return
	end

	self.LastCurTime = CurTime()


	local attach = self:GetCurAttachment()
	self.KnownAttachment = self.KnownAttachment or ""
	
	if self.KnownAttachment != attach and attach != "" then
		self.KnownAttachment = attach
		self:SetupModifiers(attach)
	elseif self.KnownAttachment != attach then
		self:RollbackModifiers(self.KnownAttachment)
		self.KnownAttachment = attach
	end
end

-- Returns true when the weapon defines a dedicated ironsights idle to swap to.
function SWEP:HasIronsightsIdle()
	return self.IronsightsIdleAnim != nil or self.EmptyIronsightsIdleAnim != nil
end

-- Returns true when the weapon defines a dedicated walk/sprint loop to swap to.
function SWEP:HasMovementAnims()
	return self.WalkAnim != nil or self.SprintAnim != nil
end

-- Classifies the owner's current movement as "sprint", "walk" or "idle".
function SWEP:GetMoveState()
	local owner = self:GetOwner()
	if not IsValid(owner) then return "idle" end

	if self:IsSprinting() then
		return "sprint"
	end

	if owner:IsOnGround() and owner:GetVelocity():Length2D() > 16 then
		return "walk"
	end

	return "idle"
end

-- Picks the looping animation for the current state: ironsighted variants first
-- (empty taking priority over the loaded one), then sprint/walk movement loops,
-- then the standard idle/empty idle.
function SWEP:GetIdleAnim()
	if self:GetIronsights() then
		if self.EmptyIronsightsIdleAnim and self:Clip1() == 0 then
			return self.EmptyIronsightsIdleAnim
		end

		if self.IronsightsIdleAnim then
			return self.IronsightsIdleAnim
		end
	end

	local state = self:GetMoveState()
	if state == "sprint" and self.SprintAnim then
		return self.SprintAnim
	end

	if state == "walk" and self.WalkAnim then
		return self.WalkAnim
	end

	if self.EmptyIdleAnim and self:Clip1() == 0 then
		return self.EmptyIdleAnim
	end

	return self.IdleAnim or ACT_VM_IDLE
end

-- Plays whatever looping anim the current state calls for (idle/walk/sprint/ADS) and syncs the movement tracker. Deliberately does NOT queue idle: these loops play continuously, so re-queuing would replay them from frame 0 every cycle and snap.
function SWEP:ResumeIdleLoop(bKeepCycle)
	self:PlayAnim( self:GetIdleAnim(), bKeepCycle )
	self.LastMoveState = self:GetMoveState()
	self.PendingMoveState = nil
end

-- Swaps to the walk/sprint loop once the movement state has held long enough,
-- but only while settled into the idle loop -- draw/fire/reload animations leave
-- NextIdle set and pick the right loop themselves via GetIdleAnim() once done.
function SWEP:MovementThink()
	if not self:HasMovementAnims() then return end
	if self.Inspecting then return end

	local state = self:GetMoveState()

	-- Debounce: restart the timer whenever the raw state changes, so a swap only
	-- commits after the new state has stayed put for MoveAnimDebounce seconds.
	if state != self.PendingMoveState then
		self.PendingMoveState = state
		self.MoveStateChangeTime = CurTime() + (self.MoveAnimDebounce or 0.1)
	end

	if state == self.LastMoveState then return end
	if CurTime() < (self.MoveStateChangeTime or 0) then return end

	if self:GetIronsights() then return end
	if self:GetNextIdle() != 0 then return end
	if self:GetReloading() or self:GetBursting() then return end
	if self:GetNextPrimaryFire() > CurTime() then return end

	self:ResumeIdleLoop( true )
end

-- True only when the weapon is genuinely idle and free to start a random inspect.
function SWEP:CanInspect()
	local owner = self:GetOwner()
	if not IsValid(owner) then return false end

	if self:GetIronsights() then return false end
	if self:GetReloading() or self:GetBursting() then return false end
	if self:GetNextPrimaryFire() > CurTime() then return false end
	if self:GetNextIdle() != 0 then return false end
	if self:GetMoveState() != "idle" then return false end
	if owner:KeyDown(IN_ATTACK) or owner:KeyDown(IN_ATTACK2) then return false end

	return true
end

-- Arms the countdown for the next random inspect, from the configured delay range.
function SWEP:ScheduleInspect()
	self.Inspecting = false
	self.NextInspect = CurTime() + math.Rand( self.InspectMinDelay or 14, self.InspectMaxDelay or 35 )
end

-- Plays a random inspect animation and starts tracking it so it can end or cancel.
function SWEP:DoInspect()
	local anim = self:GetInspectAnim()
	if not anim then
		self:ScheduleInspect()
		return
	end

	local dur = self:PlayAnim( anim ) or 0
	if dur <= 0 then
		self:ScheduleInspect()
		return
	end

	self.Inspecting = true
	self.InspectEndTime = CurTime() + dur
	self:SetNextIdle( 0 )

	if self.InspectSound then
		self:EmitWeaponSound( self.InspectSound )
	end
end

-- Server-authoritative random idle inspects: while the weapon sits idle it occasionally plays one of its inspect animations, replicated to the client via PlayAnim, and cancelled the instant the owner shoots, aims down sights or starts moving.
function SWEP:InspectThink()
	if CLIENT then return end
	if not self.AutoInspect then return end

	if self.Inspecting then
		local owner = self:GetOwner()
		local bShooting = IsValid(owner) and owner:KeyDown(IN_ATTACK)
		local bInterrupted = self:GetIronsights() or self:GetMoveState() != "idle"

		if bShooting or bInterrupted then
			self:ScheduleInspect()

			-- Shooting plays its own fire animation; for ADS/movement we restore
			-- the correct loop ourselves so the inspect does not linger.
			if bInterrupted then
				self:ResumeIdleLoop()
			end

			return
		end

		if CurTime() >= self.InspectEndTime then
			self:ResumeIdleLoop()
			self:ScheduleInspect()
		end

		return
	end

	if not self:CanInspect() then
		self:ScheduleInspect()
		return
	end

	if not self.NextInspect then
		self:ScheduleInspect()
		return
	end

	if CurTime() < self.NextInspect then return end

	self:DoInspect()
end

function SWEP:IdleThink()
	if self:GetNextIdle() == 0 then return end

	if CurTime() > self:GetNextIdle() then
		self:SetNextIdle( 0 )
		if self.NoIdleAnim then
			return
		end

		self:ResumeIdleLoop()
	end
end

function SWEP:RecoilThink()
	self:SetRecoil( math.Clamp( self:GetRecoil() - FrameTime() * (self.Primary.RecoilRecoveryRate or 1.4), 0, self.Primary.MaxRecoil or 1 ) )

	if CLIENT then
		if (self.RecoilCameraLastShoot or 0) + 0.1 < CurTime() then
			self.RecoilCameraRoll = Lerp(RealFrameTime() * 2, self.RecoilCameraRoll or 0, 0)
		end
	end
end

function SWEP:BurstThink()
	if self.Burst and (self.nextBurst or 0) < CurTime() then
		self:Shoot()

		self.Burst = self.Burst - 1

		if self.Burst < 1 then
			self:SetBursting(false)
			self.Burst = nil
		else
			self.nextBurst = CurTime() + self.Primary.Delay
		end	
	end
end

function SWEP:OnRemove()
	if self.CustomMaterial then
		if CLIENT then
			if not self.Owner.GetViewModel then -- disconnect errors
				return
			end

			if not self.Owner == LocalPlayer() then
				return
			end

			if not IsValid(self.Owner) then
				return
			end

			if not IsValid(self.Owner:GetViewModel()) then
				return
			end

			self.Owner:GetViewModel():SetMaterial("")
		end
	end
end

function SWEP:ReloadThink()
    if self:UsesShotgunReload() then
        self:ShotgunReloadThink()
        return
    end

    if self:GetReloadTime() < CurTime() then
        self:FinishReload()
    end
end

function SWEP:IronsightsThink()
	self._CustomRecoil = self._CustomRecoil or {}


	if self.Owner:KeyDown(IN_ATTACK2) and self:CanIronsight() and not self:GetIronsights() then
		if hook.Run("LSOnIronsights", self, true) then return end
		self:SetIronsights( true )
		if self:HasIronsightsIdle() and not self:GetReloading() then
			self:PlayAnim( self:GetIdleAnim() )
			self:QueueIdle()
		end
		if CLIENT and (IsFirstTimePredicted() or game.SinglePlayer()) then
			if self.IronsightsFrac < 0.01 then
				self.IronsightsEarly = true
			else
				self.IronsightsEarly = false
			end
			self:EmitWeaponSound(longsword.ironInSound or "LS_Generic.ADSIn")
		end
	elseif (not self.Owner:KeyDown(IN_ATTACK2) or not self:CanIronsight()) and self:GetIronsights() then
		if hook.Run("LSOnIronsights", self, false) then return end
		self:SetIronsights( false )
		if self:HasIronsightsIdle() and not self:GetReloading() then
			self:PlayAnim( self:GetIdleAnim() )
			self:QueueIdle()
		end

		if CLIENT and (IsFirstTimePredicted() or game.SinglePlayer()) then
			if self.IronsightsFrac < 0.93 then
				self.IronsightsEarly = true
			else
				self.IronsightsEarly = false
			end
	
			self:EmitWeaponSound(longsword.ironOutSound or "LS_Generic.ADSOut")
		end
	end
end

function SWEP:SoundThink()
	if not self.Primary.LoopSound then return end

	local cs = self:CanShoot()
	local ply = self:GetOwner()
	local kd = ply:KeyDown(IN_ATTACK)
	if kd and cs then
		if not self.LoopSnd then
			self.LoopSnd = CreateSound(self, self.Primary.LoopSound)
		end

		if not self.LoopSnd:IsPlaying() then
			self.LoopSnd:Play()
		end
	elseif (not kd or not cs) and self.LoopSnd and self.LoopSnd:IsPlaying() then
		self.LoopSnd:Stop()
	end
end

function SWEP:LoweredThink()
	if impulse or ix or marauth then
		if self:GetLowered() then
			self:SetLowered(false)
		end

		return
	end

	self.RaiseTime = self.RaiseTime or 0
	if self.Owner:KeyDown(IN_RELOAD) then
		if self.RaiseTime != 0 and self.RaiseTime < CurTime() then
			self.RaiseTime = 0
			self:EmitWeaponSound("LS_Generic.Lower")
			self:SetLowered(not self:GetLowered())
			local lowered = self:GetLowered()
		
			if lowered then
				self:SetHTPassive()
			else
				self:SetHoldType(self.HoldType)
			end
		elseif self.RaiseTime == 0 then
			self.RaiseTime = CurTime() + (longsword.raiseTime or 1)
		end
	elseif not self.Owner:KeyDown(IN_RELOAD) and (self.RaiseTime or 0) != 0 then
		self.RaiseTime = 0
	end
end

function SWEP:FiremodeThink()
	local ply = self:GetOwner()

	if ply:KeyDown(IN_USE) and ply:KeyDown(IN_RELOAD) and self.FireModes then
		return self:ToggleFireMode()
	end
end
