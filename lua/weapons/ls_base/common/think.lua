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

-- Returns true when the weapon defines a dedicated walk/sprint loop to swap to, loaded or empty.
function SWEP:HasMovementAnims()
	return self.WalkAnim != nil or self.SprintAnim != nil or self.EmptyWalkAnim != nil or self.EmptySprintAnim != nil
end

-- Returns true when the weapon defines any empty-clip counterpart to one of its looping animations.
function SWEP:HasEmptyLoopAnims()
	return self.EmptyIdleAnim != nil or self.EmptyIronsightsIdleAnim != nil or self.EmptyWalkAnim != nil or self.EmptySprintAnim != nil
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

-- Picks the looping animation for the current state: ironsighted variants first,
-- then sprint/walk movement loops, then the standard idle. Every tier resolves
-- its own empty-clip counterpart, so a weapon with walk/sprint/idle_empty
-- sequences keeps the locked-back slide on screen the whole time it is dry.
function SWEP:GetIdleAnim()
	local bIronsights = self:GetIronsights()

	if bIronsights then
		local anim = self:ResolveEmptyAnim(self.IronsightsIdleAnim, self.EmptyIronsightsIdleAnim)
		if anim then
			return anim
		end
	end

	-- Movement loops are skipped entirely while aiming: a weapon without a dedicated ironsights idle must still drop to the standing idle, otherwise the walk/sprint loop that was playing when the player aimed keeps running until they lower the sights.
	if not bIronsights then
		local state = self:GetMoveState()
		if state == "sprint" then
			local anim = self:ResolveEmptyAnim(self.SprintAnim, self.EmptySprintAnim)
			if anim then
				return anim
			end
		end

		if state == "walk" then
			local anim = self:ResolveEmptyAnim(self.WalkAnim, self.EmptyWalkAnim)
			if anim then
				return anim
			end
		end
	end

	return self:ResolveEmptyAnim(self.IdleAnim, self.EmptyIdleAnim) or ACT_VM_IDLE
end

-- Plays whatever looping anim the current state calls for (idle/walk/sprint/ADS) and syncs the movement and clip trackers to the state the loop was picked for. Deliberately does NOT queue idle: these loops play continuously, so re-queuing would replay them from frame 0 every cycle and snap.
function SWEP:ResumeIdleLoop(bKeepCycle)
	self:PlayAnim( self:GetIdleAnim(), bKeepCycle )
	self.LastMoveState = self:GetMoveState()
	self.PendingMoveState = nil
	self.LastEmptyState = self:IsClipEmpty()
end

-- Re-plays the loop the new ironsights state calls for. Runs on every ADS toggle rather than only for weapons with a dedicated ironsights idle, because a walk/sprint loop entered just before aiming would otherwise keep looping until the sights come back down -- the player stands still, aimed, with the hands still sprinting.
function SWEP:RefreshIronsightsLoop()
	if self:GetReloading() then return end

	-- With a dedicated ADS idle the swap is instant and cuts whatever is playing. Without one there is nothing to swap to mid-animation, so only a settled loop is refreshed: a draw/fire/inspect already queued an idle and picks the right loop up itself once it finishes.
	if not self:HasIronsightsIdle() then
		if not self:HasMovementAnims() then return end
		if self:GetNextIdle() != 0 then return end
	end

	self:SetNextIdle( 0 )
	self:ResumeIdleLoop()
end

-- Swaps to the walk/sprint loop once the movement state has held long enough,
-- but only while settled into the idle loop -- draw/fire/reload animations leave
-- NextIdle set and pick the right loop themselves via GetIdleAnim() once done.
function SWEP:MovementThink()
	if not self:HasMovementAnims() then return end
	if self.Inspecting then return end

	local state = self:GetMoveState()

	-- Aiming owns the loop (GetIdleAnim resolves to the ironsights/standing idle),
	-- so no swap happens here -- but the tracker still follows the real movement
	-- state, otherwise it stays stuck on whatever was playing when the player
	-- aimed and blocks the swap back once the sights come down.
	if self:GetIronsights() then
		self.PendingMoveState = state
		self.LastMoveState = state
		return
	end

	-- Debounce: restart the timer whenever the raw state changes, so a swap only
	-- commits after the new state has stayed put for MoveAnimDebounce seconds.
	if state != self.PendingMoveState then
		self.PendingMoveState = state
		self.MoveStateChangeTime = CurTime() + (self.MoveAnimDebounce or 0.1)
	end

	if state == self.LastMoveState then return end
	if CurTime() < (self.MoveStateChangeTime or 0) then return end

	if self:GetNextIdle() != 0 then return end
	if self:GetReloading() or self:GetBursting() then return end
	if self:GetNextPrimaryFire() > CurTime() then return end

	self:ResumeIdleLoop( true )
end

-- Swaps the looping animation over when the clip runs dry or is refilled without the movement state changing. The loop is otherwise only re-picked when the player starts moving, aims, or an animation finishes, so a clip topped up by anything else (an admin handing out ammo, a shotgun shell chambered mid-reload) would leave the hands holding a locked-back slide over a full magazine until the next state change.
function SWEP:AmmoStateThink()
	if not self:HasEmptyLoopAnims() then return end
	if self.Inspecting then return end

	if self:IsClipEmpty() == self.LastEmptyState then return end

	-- Only a settled loop is refreshed: a draw, fire or reload animation leaves NextIdle set and resolves the right variant itself once it finishes, syncing the tracker as it does. The mismatch is left standing until then so the swap still happens if none of them ever gets around to it.
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

	if self.CustomOnRemove then
		self:CustomOnRemove()
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
