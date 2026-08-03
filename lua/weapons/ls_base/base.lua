-- The main file, containing the base data for longsword. 
-- Created by vin and modified by bingu.

SWEP.IsLongsword = true
SWEP.PrintName = "Longsword"
SWEP.Category = "LS"
SWEP.DrawWeaponInfoBox = false

SWEP.Spawnable = false
SWEP.AdminOnly = false

SWEP.ViewModelFOV = 55
SWEP.UseHands = true

SWEP.Slot = 1
SWEP.SlotPos = 1

SWEP.CSMuzzleFlashes = true

SWEP.Primary.Sound = Sound("Weapon_Pistol.Single")
SWEP.Primary.Recoil = 0.8
SWEP.Primary.Damage = 5
SWEP.Primary.NumShots = 1
SWEP.Primary.Cone = 0.03
SWEP.Primary.Delay = 0.13

SWEP.Primary.Ammo = "pistol"
SWEP.Primary.Automatic = false
SWEP.Primary.ClipSize = 12
SWEP.Primary.DefaultClip = 12

SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Automatic = false
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1

SWEP.EmptySound = Sound("Weapon_Pistol.Empty")

SWEP.Spread = {}
SWEP.Spread.Min = 0
SWEP.Spread.Max = 0.5
SWEP.Spread.IronsightsMod = 0.1
SWEP.Spread.CrouchMod = 0.6
SWEP.Spread.AirMod = 1.2
SWEP.Spread.RecoilMod = 0.025
SWEP.Spread.VelocityMod = 0.5

SWEP.IronsightsPos = Vector( -5.9613, -3.3101, 2.706 )
SWEP.IronsightsAng = Angle( 0, 0, 0 )
SWEP.IronsightsFOV = 0.8
SWEP.IronsightsSensitivity = 0.8
SWEP.IronsightsCrosshair = false
SWEP.scopedIn = SWEP.scopedIn or false

-- Idle animations played while iron-sighted. When set, they replace the normal
-- idle for as long as the weapon is aimed down sights, and are played the moment
-- the player enters or leaves ironsights (so the swap is instant rather than
-- waiting for the next idle cycle). Both accept an activity (ACT_VM_*) or a raw
-- sequence name string; leave nil to keep using the standard idle.
-- EmptyIronsightsIdleAnim takes priority while the clip is empty, falling back to
-- IronsightsIdleAnim when it is not set.
SWEP.IronsightsIdleAnim = nil
SWEP.EmptyIronsightsIdleAnim = nil

-- Looping viewmodel animations played while the owner is on the move. WalkAnim
-- covers normal ground movement and SprintAnim covers sprinting; each swaps in
-- the instant the movement state changes and falls back to the standard idle
-- when nil. Both accept an activity (ACT_VM_*) or a raw sequence name string.
-- They never interrupt a draw, fire or reload -- the matching loop is picked up
-- once that animation finishes. Aiming down sights suspends them: the weapon
-- drops to IronsightsIdleAnim, or to the standard idle when it has none, so the
-- hands never keep walking or sprinting while the player stands still aimed.
SWEP.WalkAnim = nil
SWEP.SprintAnim = nil

-- The standing idle. IdleAnim is the loop the weapon settles into whenever it is
-- neither moving nor aimed, defaulting to ACT_VM_IDLE.
SWEP.IdleAnim = nil

-- Empty-clip counterparts to the loops above, for viewmodels that animate the
-- slide or bolt locked back (idle_empty, walk_empty, sprint_empty). Each is used
-- in place of its loaded variant for as long as the clip reads 0 and falls back
-- to that variant when nil, so a weapon only has to declare the empty sequences
-- its model actually ships. The swap follows the clip rather than the animation
-- that changed it: firing the last round, finishing a reload or having ammo
-- handed over all re-pick the loop on the spot.
SWEP.EmptyIdleAnim = nil
SWEP.EmptyWalkAnim = nil
SWEP.EmptySprintAnim = nil

-- Draw animations. DrawAnim is played on deploy (default ACT_VM_DRAW) and
-- EmptyDrawAnim replaces it while the clip is empty. NoDrawAnim skips both.
SWEP.DrawAnim = nil
SWEP.EmptyDrawAnim = nil

-- Holster animations, off by default. Playing one means holding the weapon
-- switch back until the animation finishes, so weapons opt in with DoHolsterAnim
-- and the switch goes through the moment it ends. HolsterAnim picks the sequence
-- and EmptyHolsterAnim replaces it while the clip is empty; with neither set the
-- switch stays instant. Death, dropping the weapon and switching with nothing to
-- switch to all bypass the delay.
SWEP.DoHolsterAnim = false
SWEP.HolsterAnim = nil
SWEP.EmptyHolsterAnim = nil

-- Reload animations. ReloadAnimation is the normal one (default ACT_VM_RELOAD);
-- with DoEmptyReloadAnim set, a reload started on an empty clip plays
-- EmptyReloadAnimation (default ACT_VM_RELOAD_EMPTY) instead, which is the one
-- that drops the slide or charges the bolt at the end.
SWEP.DoEmptyReloadAnim = false
SWEP.ReloadAnimation = nil
SWEP.EmptyReloadAnimation = nil

-- The shot that empties the clip. With DoLastFireAnim set it plays a dedicated
-- animation instead of the normal fire one -- LastFireAnims picks at random from
-- a list (one per fire variant, matching FireAnims), LastFireAnim is the
-- single-sequence form, and ACT_VM_PRIMARYATTACK_EMPTY is the fallback. The
-- Ironsights* forms below are the aimed counterparts, used only when the shot is
-- animated down the sights (Recoil.DoFireAnim); with none set the aimed
-- last-shot falls back to the normal aimed fire.
SWEP.DoLastFireAnim = false
SWEP.LastFireAnim = nil
SWEP.LastFireAnims = nil
SWEP.IronsightsLastFireAnim = nil
SWEP.IronsightsLastFireAnims = nil

-- Animation played when the trigger is pulled on an empty chamber, defaulting to
-- ACT_VM_DRYFIRE. IronsightsDryFireAnim replaces it while aimed when set.
-- NoDryFireAnim suppresses it entirely.
SWEP.DryFireAnim = nil
SWEP.IronsightsDryFireAnim = nil

-- Shell-by-shell (shotgun) reload sequences, used when SWEP.Shotgun is set. The
-- reload runs an opening rack, one insert per shell and a closing rack; each
-- stage takes a named-sequence or activity override, and the *Empty forms are
-- swapped in when the tube started empty (bolt locked open). Left nil, the stages
-- keep the activities the reload used before (ACT_SHOTGUN_RELOAD_START /
-- ACT_VM_RELOAD / ACT_SHOTGUN_RELOAD_FINISH), so a shotgun with a single reload
-- set is unaffected.
SWEP.ShotgunReloadStartAnim = nil
SWEP.ShotgunReloadStartEmptyAnim = nil
SWEP.ShotgunReloadInsertAnim = nil
SWEP.ShotgunReloadEndAnim = nil
SWEP.ShotgunReloadEndEmptyAnim = nil

-- When the empty-start reload animation loads a round directly into the chamber, set this so that shell is credited as the rack plays -- unlike CanChamberShotgun it does not raise the clip size, for tubes (like the M590) whose ClipSize already counts the chambered round.
SWEP.ShotgunEmptyChambers = false

-- Seconds a new movement state must hold before the loop actually swaps. Stops
-- velocity hovering near the walk/sprint thresholds from rapidly flipping the
-- viewmodel and stuttering between frames.
SWEP.MoveAnimDebounce = 0.1

-- How much of the procedural camera bob/roll to keep when the weapon has its own
-- walk/sprint animation. The animation already supplies the locomotion motion, so
-- this defaults to 0 -- the procedural bob is disabled and the animation drives
-- everything, which stops the two stacking and fighting (the muddled motion seen
-- only on animated weapons). Raise toward 1 to layer some procedural bob back on
-- top. No effect on weapons without WalkAnim/SprintAnim.
SWEP.MoveAnimBobScale = 0

-- Inspect animations. InspectAnimations is a list (one is chosen at random) and
-- InspectAnimation is a single-sequence fallback; both accept an activity
-- (ACT_VM_*) or a raw sequence name string. They drive the manual inspect (press
-- reload on a full clip) and, when AutoInspect is enabled, the random idle
-- inspect below.
SWEP.InspectAnimation = nil
SWEP.InspectAnimations = nil

-- Extra cooldown (seconds) after a manual inspect (reload on a full clip) before
-- another may play, on top of the animation's own length. Holding reload only
-- triggers a single inspect regardless of this; the cooldown rate-limits rapid
-- re-pressing. 0 means you can inspect again as soon as the animation finishes.
SWEP.InspectCooldown = 0

-- Random idle inspects. When AutoInspect is enabled the weapon occasionally
-- plays one of its inspect animations after sitting idle for a random number of
-- seconds (between InspectMinDelay and InspectMaxDelay), and cancels it the
-- instant the owner shoots, aims down sights or starts moving. Off by default so
-- weapons that only want the manual inspect are unaffected.
SWEP.AutoInspect = false
SWEP.InspectMinDelay = 14
SWEP.InspectMaxDelay = 35
SWEP.InspectSound = nil


SWEP.BobScale = 0
SWEP.SwayScale = 0

-- Pullback (pump) animations.
-- A short viewmodel animation played a moment after each shot, used by pump
-- shotguns, lever-/bolt-action rifles and other manually-cycled weapons.
-- Override the WHOLE table in your weapon (like SWEP.Spread) rather than a
-- single field, so you don't mutate the shared base default.
SWEP.Pullback = {}
SWEP.Pullback.Enabled = false             -- play a pullback animation after firing
SWEP.Pullback.Delay = 0.5                 -- extra seconds added on top of the fire animation's duration
SWEP.Pullback.Anims = { ACT_VM_PULLBACK } -- one is chosen at random each shot; accepts activities or raw sequence ids
SWEP.Pullback.Sound = nil                 -- optional sound emitted with the animation
-- For per-shot custom logic (e.g. different anims while ironsighted) override
-- SWEP:GetPullbackAnimation() instead.

function SWEP:SetupDataTables()
	self:NetworkVar("Bool", 0, "Ironsights")
	self:NetworkVar("Bool", 1, "Reloading")
	self:NetworkVar("Bool", 2, "Bursting")
	self:NetworkVar("Bool", 3, "Lowered")

	self:NetworkVar("String", 0, "CurAttachment")

	self:NetworkVar("Float", 1, "IronsightsRecoil")
	self:NetworkVar("Float", 2, "Recoil")
	self:NetworkVar("Float", 3, "ReloadTime")
	self:NetworkVar("Float", 4, "NextIdle")

	if self.ExtraDataTables then -- change these when adding network vars
		self:ExtraDataTables({
			["Bool"] = 3,
			["String"] = 1,
			["Float"] = 4
		})
	end
end

function SWEP:ResetValues()
	self:SetIronsights(false)

	self:SetReloading(false)
	self:SetLowered( false )

	self:SetReloadTime(0)

	self:SetRecoil(0)
	self:SetNextIdle(0)

	self.LastMoveState = nil
	self.PendingMoveState = nil
	self.LastEmptyState = nil
	self.HolsterAnimEnd = nil
	self.ReloadStartedEmpty = nil

	self.Charging = false
	self.ChargeIdlePlayed = false
	self.SecondaryDown = false

	self.Inspecting = false
	self.NextInspect = nil

	self.InspectArmed = true
	self.NextInspectAllowed = 0

	self.OriginalVMFov = self.ViewModelFOV
end

function SWEP:Initialize()
	self:ResetValues()

	self:SetHoldType(self.HoldType)

	if SERVER and self.CustomMaterial then
		self.Weapon:SetMaterial(self.CustomMaterial)
	end

	if self.CustomInit then
		self:CustomInit()
	end
end

function SWEP:OnReloaded()
	if self.OnCodeReload then
		self:OnCodeReload()
	end

	self:ResetValues()

	self:SetLowered(false)
	self:SetHoldType(self.HoldType)

	if self.VMElements then
		for _, element in pairs(self.VMElements) do
			if IsValid(element._CSModel) then
				element._CSModel:Remove()
			end
		end
	end

	if self.WMElements then
		for _, element in pairs(self.WMElements) do
			if IsValid(element._WMModel) then
				element._WMModel:Remove()
			end
		end
	end

	if IsValid(self.WMElementRoot) then
		self.WMElementRoot:Remove()
	end

	for attID, on in pairs(self.EquippedAttachments or {}) do
		if not on then continue end

		self:ProcessModifiersOn(attID)
	end
end

function SWEP:EmitWeaponSound(snd, lvl, pitch, vol)
	self:EmitSound(snd, lvl or 60, pitch or 100, vol or 1, CHAN_AUTO)
end

function SWEP:DrawWeaponSelection()
end

function SWEP:GetPassiveHoldType()
	if self.HoldType == "revolver" or self.HoldType == "pistol" then
		return "normal"
	end

	return "passive"
end

function SWEP:SetHTPassive()
	self:SetHoldType(self:GetPassiveHoldType())
end

function SWEP:GetDeploySound()
	local isPistol = self.HoldType == "revolver" or self.HoldType == "pistol"

	return "LS_Generic.Draw" .. (isPistol and "Pistol" or "")
end

function SWEP:GetHolsterSound()
	local isPistol = self.HoldType == "revolver" or self.HoldType == "pistol"

	return "LS_Generic.Holster" .. (isPistol and "Pistol" or "")
end


-- Resolves the owner's viewmodel, returning nothing whenever the weapon has no player behind it. The engine keeps calling the render, think and lifecycle entry points on a weapon whose owner has gone -- a death, a strip, the tail of a weapon switch -- and every path that reaches straight through GetOwner() for the viewmodel errors on those frames.
function SWEP:GetOwnerViewModel()
	local owner = self:GetOwner()
	if not IsValid(owner) or not owner:IsPlayer() then return end

	local vm = owner:GetViewModel()
	if not IsValid(vm) then return end

	return vm
end

function SWEP:Deploy()
	local ply = self:GetOwner()

	if IsValid(ply) and ply:IsNPC() then
		return self:Remove() -- NPC support has not been added, this avoids possible errors
	end

	local vm = self:GetOwnerViewModel()

	if CLIENT and self.CustomMaterial and vm then
		vm:SetMaterial(self.CustomMaterial)
		self.CustomMatSetup = true
	end

	if vm then
		if self.CustomSubMats then
			for id, mat in pairs(self.CustomSubMats) do
				vm:SetSubMaterial(id, mat)
			end
		else
			for id, mat in pairs(vm:GetMaterials()) do
				vm:SetSubMaterial(id, "")
			end
		end
	end

	if self.ExtraDeploy then
		self:ExtraDeploy()
	end

	self:EmitWeaponSound(self:GetDeploySound())

	-- A holster animation cut short by a fresh deploy (dying mid-switch, an admin forcing the weapon back out) would otherwise leave the marker behind and block the next holster for its duration.
	self.HolsterAnimEnd = nil

	if not self.NoDrawAnim then
		-- PlayAnim returns nil for a viewmodel that lacks the draw sequence (e.g. the first aid kit has no ACT_VM_DRAW), so fall back to 0 to avoid arithmetic on nil.
		local dur = self:PlayAnim(self:GetDrawAnim()) or 0

		self:SetNextPrimaryFire(CurTime() + dur)
		self:QueueIdle()
	end

	if self.PlayerSpeedMultiplier and IsValid(ply) then
		local oldSpeed = ply:GetWalkSpeed()
		ply.lsOldWalkSpeed = oldSpeed
		ply:SetWalkSpeed(oldSpeed * self.PlayerSpeedMultiplier)
	end

	self:SetLowered(false)
	self:SetHoldType(self.HoldType)

	return true
end

-- Plays the holster animation and defers the weapon switch until it has finished, returning true once the switch may go ahead. The engine tears the viewmodel down the moment Holster() succeeds, so the animation is only ever seen if the switch is cancelled and re-issued afterwards -- which is what the timer below does. Anything the player cannot be left stuck in the middle of (no animation, no weapon to switch to, dead, dropped) passes straight through.
function SWEP:HandleHolsterAnim(wep)
	if not self.DoHolsterAnim then return true end

	local anim = self:GetHolsterAnim()
	if not anim then return true end

	local owner = self:GetOwner()
	if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return true end
	if not IsValid(wep) or wep == self then return true end

	-- Second pass: the deferred switch came back around, so drop the marker and let it through. The slack covers the timer landing on the tick just short of the animation's exact end, which would otherwise cancel the switch it was fired to make.
	if self.HolsterAnimEnd then
		if CurTime() < self.HolsterAnimEnd - 0.05 then return false end

		self.HolsterAnimEnd = nil

		return true
	end

	local dur = self:PlayAnim(anim) or 0
	if dur <= 0 then return true end

	self.HolsterAnimEnd = CurTime() + dur

	self:SetNextIdle(0)
	self:SetNextPrimaryFire(CurTime() + dur)

	-- The client follows the switch through the networked active weapon, so only the server re-issues it.
	if SERVER then
		local class = wep:GetClass()

		timer.Simple(dur, function()
			if not IsValid(self) or not IsValid(owner) then return end
			if owner:GetActiveWeapon() != self then return end

			owner:SelectWeapon(class)
		end)
	end

	return false
end

function SWEP:Holster(w)
	if not self:HandleHolsterAnim(w) then return false end

	-- Holster runs on the way out of a weapon the owner may already have lost (death, a strip), so everything below has to survive a NULL owner and a torn-down viewmodel.
	local owner = self:GetOwner()
	local vm = self:GetOwnerViewModel()

	self:ResetValues()

	if CLIENT then
		self.ViewModelPos = Vector( 0, 0, 0 )
		self.ViewModelAng = Angle( 0, 0, 0 )
		self.FOV = nil
	end

	if CLIENT and vm and self.CustomMaterial and owner == LocalPlayer() then
		vm:SetMaterial("")
		self.CustomMatSetup = nil
	end

	if vm and self.CustomSubMats then
		for id, mat in pairs(self.CustomSubMats) do
			vm:SetSubMaterial(id, "")
		end
	end

	if self.PlayerSpeedMultiplier and IsValid(owner) then
		local oldSpeed = owner.lsOldWalkSpeed
		if oldSpeed and oldSpeed != owner:GetWalkSpeed() then
			owner:SetWalkSpeed(oldSpeed)
		end
	end

	if self.ExtraHolster then
		self:ExtraHolster()
	end
	
	return true
end

print("[longsword] Longsword weapon base loaded. Version " .. longsword.version .. ". Copyright 2019 vin")
