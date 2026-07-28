function SWEP:PlayAnim(act, bKeepCycle)
	local vmodel = self:GetOwnerViewModel()
	if not vmodel then return end

	-- Named sequences must be resolved on the viewmodel, not on self: sequence indices are per-model, SendViewModelMatchingSequence only accepts the viewmodel's own, and self:LookupSequence() reads the weapon's WORLD model, where viewmodel sequence names ("walk", "sprint", "idle01_is") do not exist. That returned -1 and aborted the call silently, so the swap never happened and whatever was already playing -- a sprint loop, say -- just kept looping.
	local seq = isstring(act) and vmodel:LookupSequence(act) or vmodel:SelectWeightedSequence(act)

	if not seq or seq == -1 then
		return longsword.debugPrint("Attempting to play invalid sequence " .. tostring(act) .. " on " .. self:GetClass() .. "!")
	end

	-- Carry the current normalised cycle across so looping locomotion anims (idle/walk/sprint) blend by phase instead of snapping back to frame 0.
	local cycle = bKeepCycle and vmodel:GetCycle() or nil

	vmodel:ResetSequenceInfo()
	vmodel:SendViewModelMatchingSequence(seq)

	if cycle then
		vmodel:SetCycle(cycle)
	end

	return vmodel:SequenceDuration(seq)
end

-- True while the weapon carries a magazine and it has run dry. Weapons without a clip (melee, projectile) report -1 and are never considered empty.
function SWEP:IsClipEmpty()
	return self:Clip1() == 0
end

-- Picks between an animation and its empty-clip counterpart. The empty variant is only used when the weapon actually defines one and the clip is dry, so weapons that only set the loaded variant behave exactly as they did before.
function SWEP:ResolveEmptyAnim(anim, emptyAnim)
	if emptyAnim and self:IsClipEmpty() then
		return emptyAnim
	end

	return anim
end

-- Returns the draw animation for the current clip state, falling back to ACT_VM_DRAW.
function SWEP:GetDrawAnim()
	return self:ResolveEmptyAnim(self.DrawAnim, self.EmptyDrawAnim) or ACT_VM_DRAW
end

-- Returns the holster animation for the current clip state, or nil when the weapon defines neither variant.
function SWEP:GetHolsterAnim()
	return self:ResolveEmptyAnim(self.HolsterAnim, self.EmptyHolsterAnim)
end

-- Returns the animation played when the trigger is pulled on an empty chamber, preferring the ironsighted variant while aimed and falling back to ACT_VM_DRYFIRE.
function SWEP:GetDryFireAnim()
	if self:GetIronsights() and self.IronsightsDryFireAnim then
		return self.IronsightsDryFireAnim
	end

	return self.DryFireAnim or ACT_VM_DRYFIRE
end

function SWEP:PlayAnimWorld(act)
	local wmodel = self
	local seq = wmodel:SelectWeightedSequence(act)

	self:ResetSequence(seq)
end

function SWEP:QueueIdle()
	local vmodel = self:GetOwnerViewModel()
	if not vmodel then return end

	self:SetNextIdle( CurTime() + vmodel:SequenceDuration() + 0.1 )
end
