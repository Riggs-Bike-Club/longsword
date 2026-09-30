-- The main file, containing the base data for longsword. 
-- Created by vin, modified by bingu and maintained by Riggs.

SWEP.IsLongsword = true
--- Animation actions accept an activity, a sequence name, a variant list, or false to disable; omitted actions use centralized defaults.
SWEP.Animations = {}
--- Opt-in third-person arm IK; the animated model must contain matching ValveBiped hand bones.
SWEP.TPIK = false
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

-- The sprint pose. With LoweredPos set the weapon drops out of the shoulder while its owner sprints, refusing to fire and dropping its crosshair until they slow down, and its movement accuracy is measured against walk speed instead of run speed; LoweredAng is the matching rotation and falls back to a generic tilt when only the position is given. Left nil the weapon stays shouldered and fires at a dead run. A TFA port carries these as RunSightsPos / RunSightsAng.
SWEP.LoweredPos = nil
SWEP.LoweredAng = nil

--- Maximum firing delay after drawing; the cosmetic sequence may continue until another action interrupts it.
SWEP.DrawDelay = 0.25

-- When the empty-start reload animation loads a round directly into the chamber, set this so that shell is credited as the rack plays -- unlike CanChamberShotgun it does not raise the clip size, for tubes (like the M590) whose ClipSize already counts the chambered round.
SWEP.ShotgunEmptyChambers = false

--- Seconds a new movement state must hold before the loop swaps; leaving sprint skips this delay so the ready pose returns immediately.
SWEP.MoveAnimDebounce = 0.1

-- How much of the procedural camera bob/roll to keep when the weapon has its own
-- walk/sprint animation. The animation already supplies the locomotion motion, so
-- this defaults to 0 -- the procedural bob is disabled and the animation drives
-- everything, which stops the two stacking and fighting (the muddled motion seen
-- only on animated weapons). Raise toward 1 to layer some procedural bob back on
-- top. No effect on weapons without WalkAnim/SprintAnim.
SWEP.MoveAnimBobScale = 0

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

--- Mechanical cycling behavior; animation sources belong in Animations.cycle and Animations.cycleAimed.
SWEP.Pullback = {
    Enabled = false,
    Delay = 0.5,
}

--- Allocates predicted action state only for enabled features and passes the last occupied slots to derived weapons.
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

    local slots = {Bool = 3, String = 1, Float = 4}
    if ( self.TriggerDelay ) then
        self:NetworkVar("Bool", slots.Bool + 1, "TriggerFired")
        self:NetworkVar("Bool", slots.Bool + 2, "SemiAutomatic")
        self:NetworkVar("Float", slots.Float + 1, "TriggerReadyTime")
        slots.Bool = slots.Bool + 2
        slots.Float = slots.Float + 1
    end
    if ( self.Overheat ) then
        self:NetworkVar("Bool", slots.Bool + 1, "Overheated")
        self:NetworkVar("Bool", slots.Bool + 2, "HeatLocked")
        self:NetworkVar("Float", slots.Float + 1, "HeatAmount")
        self:NetworkVar("Float", slots.Float + 2, "HeatDecayTime")
        self:NetworkVar("Float", slots.Float + 3, "HeatFixTime")
        self:NetworkVar("Float", slots.Float + 4, "HeatRecoveryEnd")
        slots.Bool = slots.Bool + 2
        slots.Float = slots.Float + 4
    end
    if ( self.SprintToFireTime ) then
        self:NetworkVar("Float", slots.Float + 1, "SprintReadyTime")
        slots.Float = slots.Float + 1
    end
    if ( self.TPIK ) then
        self:NetworkVar("String", slots.String + 1, "TPIKSequenceName")
        self:NetworkVar("Float", slots.Float + 1, "TPIKSequenceStart")
        slots.String = slots.String + 1
        slots.Float = slots.Float + 1
    end
    if ( self.ExtraDataTables ) then
        self:ExtraDataTables(slots)
    end
end

function SWEP:ResetValues()
    self:ResetTriggerDelay()
    if ( self.Overheat ) then
        self:SetHeatFixTime(0)
        self:SetHeatRecoveryEnd(0)
    end
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
	if istable(snd) then
		self:EmitSound(snd[math.random(#snd)], lvl or 60, pitch or 100, vol or 1, CHAN_AUTO)
	elseif isstring(snd) then
		self:EmitSound(snd, lvl or 60, pitch or 100, vol or 1, CHAN_AUTO)
	elseif isfunction(snd) then
		snd()
	end
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

    if ( !self.NoDrawAnim and self:GetDrawAnim() != nil ) then
		-- PlayAnim returns nil for a viewmodel that lacks the draw sequence (e.g. the first aid kit has no ACT_VM_DRAW), so fall back to 0 to avoid arithmetic on nil.
		local dur = self:PlayAnim(self:GetDrawAnim()) or 0

        self:SetNextPrimaryFire( math.max( self:GetNextPrimaryFire(), CurTime() + self:GetDrawDelay( dur ) ) )
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
    if ( !self:ShouldAnimateHolster() ) then
        return true
    end

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
    self:ResetTriggerDelay()
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
