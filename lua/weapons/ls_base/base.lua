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
-- once that animation finishes.
SWEP.WalkAnim = nil
SWEP.SprintAnim = nil

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


function SWEP:Deploy()
	local ply = self:GetOwner()

	if ply:IsNPC() then
		return self:Remove() -- NPC support has not been added, this avoids possible errors
	end
	if self.CustomMaterial then
		if CLIENT then
			self.Owner:GetViewModel():SetMaterial(self.CustomMaterial)
			self.CustomMatSetup = true
		end
	end

	local vm = ply:GetViewModel()

	if self.CustomSubMats then
		for id, mat in pairs(self.CustomSubMats) do
			vm:SetSubMaterial(id, mat)
		end
	else
		for id, mat in pairs(vm:GetMaterials()) do
			vm:SetSubMaterial(id, "")
		end
	end

	if self.ExtraDeploy then
		self:ExtraDeploy()
	end

	self:EmitWeaponSound(self:GetDeploySound())

	if not self.NoDrawAnim then
		-- PlayAnim returns nil for a viewmodel that lacks the draw sequence (e.g. the first aid kit has no ACT_VM_DRAW), so fall back to 0 to avoid arithmetic on nil.
		local dur = self:PlayAnim(self.DrawAnim or ACT_VM_DRAW) or 0

		self:SetNextPrimaryFire(CurTime() + dur)
		self:QueueIdle()
	end

	if self.PlayerSpeedMultiplier then
		local ply = self:GetOwner()
		local oldSpeed = ply:GetWalkSpeed()
		ply.lsOldWalkSpeed = oldSpeed
		ply:SetWalkSpeed(oldSpeed * self.PlayerSpeedMultiplier)
	end

	self:SetLowered(false)
	self:SetHoldType(self.HoldType)

	return true
end

function SWEP:Holster(w)
	local vm = self:GetOwner():GetViewModel()

	self:ResetValues()

	if CLIENT then
		self.ViewModelPos = Vector( 0, 0, 0 )
		self.ViewModelAng = Angle( 0, 0, 0 )
		self.FOV = nil
	end

	if self.CustomMaterial then
		if CLIENT then
			if self.Owner == LocalPlayer() then
				self.Owner:GetViewModel():SetMaterial("")
			end
		end
	end

	if self.CustomSubMats then
		for id, mat in pairs(self.CustomSubMats) do
			vm:SetSubMaterial(id, "")
		end
	end

	if self.PlayerSpeedMultiplier then
		local oldSpeed = self:GetOwner().lsOldWalkSpeed
		if oldSpeed != self:GetOwner():GetWalkSpeed() then
			self:GetOwner():SetWalkSpeed(oldSpeed)
		end
	end

	if self.ExtraHolster then
		self:ExtraHolster()
	end
	
	return true
end

print("[longsword] Longsword weapon base loaded. Version " .. longsword.version .. ". Copyright 2019 vin")
