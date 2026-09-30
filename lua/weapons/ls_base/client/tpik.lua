--- Longsword adaptation of ARC9's animated-model hand targets and two-bone arm IK approach.
local enabled = CreateClientConVar("longsword_tpik", "1", true, false, "Enable TPIK on supported Longsword weapons.", 0, 1)
local others = CreateClientConVar("longsword_tpik_others", "1", true, false, "Enable Longsword TPIK on other players.", 0, 1)
local distance = CreateClientConVar("longsword_tpik_distance", "1500", true, false, "Maximum Longsword TPIK rendering distance.", 100, 5000)
longsword.tpikModels = longsword.tpikModels or {}
local models = longsword.tpikModels

--- Resolves a bone matrix without indexing a missing bone.
local function GetBone(entity, name)
    local index = entity:LookupBone(name)
    return index, index and entity:GetBoneMatrix(index)
end

--- Solves a two-segment limb with a bend hint and clamps unreachable targets.
function SWEP:SolveTPIKArm(shoulder, target, hint, upperLength, lowerLength)
    local delta = target - shoulder
    local length = delta:Length()
    if ( length < 0.001 or upperLength < 0.001 or lowerLength < 0.001 ) then return end

    local direction = delta / length
    length = math.Clamp(length, math.abs(upperLength - lowerLength) + 0.001, upperLength + lowerLength - 0.001)
    local along = (length * length + upperLength * upperLength - lowerLength * lowerLength) / (2 * length)
    local height = math.sqrt(math.max(upperLength * upperLength - along * along, 0))
    local bend = hint - shoulder
    bend = bend - direction * bend:Dot(direction)
    if ( bend:LengthSqr() < 0.001 ) then
        bend = direction:Cross(vector_up)
        if ( bend:LengthSqr() < 0.001 ) then bend = direction:Cross(Vector(0, 1, 0)) end
    end
    bend:Normalize()
    return shoulder + direction * along + bend * height, shoulder + direction * length
end

--- Moves a bone subtree while preserving helper-bone offsets and stopping at the next driven joint.
local function MoveBone(owner, index, matrix, stop)
    local original = owner:GetBoneMatrix(index)
    if ( !original ) then return end
    local inverse = original:GetInverse()
    if ( !inverse ) then return end
    local delta = matrix * inverse
    local pending = {index}
    while ( #pending > 0 ) do
        local bone = table.remove(pending)
        local current = owner:GetBoneMatrix(bone)
        if ( current ) then owner:SetBoneMatrix(bone, delta * current) end
        for _, child in ipairs(owner:GetChildBones(bone) or {}) do
            if ( child != stop ) then pending[#pending + 1] = child end
        end
    end
end

--- Applies an animated hand target and solves the player's own arm lengths around it.
function SWEP:ApplyTPIKArm(owner, model, side)
    local prefix = "ValveBiped.Bip01_" .. side
    local upper, upperMatrix = GetBone(owner, prefix .. "_UpperArm")
    local lower, lowerMatrix = GetBone(owner, prefix .. "_Forearm")
    local hand, handMatrix = GetBone(owner, prefix .. "_Hand")
    local _, target = GetBone(model, prefix .. "_Hand")
    if ( !upperMatrix or !lowerMatrix or !handMatrix or !target ) then return false end

    local shoulder = upperMatrix:GetTranslation()
    local originalElbow = lowerMatrix:GetTranslation()
    local originalHand = handMatrix:GetTranslation()
    local elbow, wrist = self:SolveTPIKArm(shoulder, target:GetTranslation(), originalElbow,
        shoulder:Distance(originalElbow), originalElbow:Distance(originalHand))
    if ( !elbow ) then return false end

    local upperPose = Matrix(upperMatrix)
    local lowerPose = Matrix(lowerMatrix)
    upperPose:SetAngles((elbow - shoulder):AngleEx(upperMatrix:GetAngles():Up()))
    lowerPose:SetTranslation(elbow)
    lowerPose:SetAngles((wrist - elbow):AngleEx(lowerMatrix:GetAngles():Up()))
    MoveBone(owner, upper, upperPose, lower)
    MoveBone(owner, lower, lowerPose, hand)
    local handPose = Matrix(target)
    handPose:SetTranslation(wrist)
    MoveBone(owner, hand, handPose)

    local correction = wrist - target:GetTranslation()
    for finger = 0, 4 do
        for _, suffix in ipairs({"", "1", "2"}) do
            local name = prefix .. "_Finger" .. finger .. suffix
            local index = owner:LookupBone(name)
            local _, pose = GetBone(model, name)
            if ( index and pose ) then
                pose = Matrix(pose)
                pose:SetTranslation(pose:GetTranslation() + correction)
                MoveBone(owner, index, pose)
            end
        end
    end
    return true
end

--- Reports whether this weapon can currently supply a third-person arm pose.
function SWEP:ShouldTPIK()
    if ( !self.TPIK or !enabled:GetBool() ) then return false end
    local owner = self:GetOwner()
    if ( !IsValid(owner) or !owner:IsPlayer() or !owner:Alive() or owner:GetActiveWeapon() != self ) then return false end
    if ( owner:IsPlayingTaunt() or (owner:InVehicle() and !owner:GetAllowWeaponsInVehicle()) ) then return false end
    if ( owner != LocalPlayer() and !others:GetBool() ) then return false end
    if ( EyePos():DistToSqr(owner:GetPos()) > distance:GetFloat() ^ 2 ) then return false end
    return true
end

--- Removes the transient animated model without modifying persistent player bone manipulations.
function SWEP:RemoveTPIKModel()
    local owner = self:GetOwner()
    if ( IsValid(owner) ) then owner:InvalidateBoneCache() end
    if ( IsValid(self.tpikModel) ) then self.tpikModel:Remove() end
    self.tpikModel = nil
    self.tpikFrame = nil
    self.tpikLoweredAmount = nil
    self.tpikOffsetFrame = nil
    self.tpikOffsetTime = nil
    models[self] = nil
end

--- Creates the animation source model on demand and replaces it if its configured model changes.
function SWEP:GetTPIKModel()
    local path = self.TPIKModel or self.ViewModel
    if ( IsValid(self.tpikModel) and self.tpikModel:GetModel() != path ) then self:RemoveTPIKModel() end
    if ( !IsValid(self.tpikModel) ) then
        self.tpikModel = ClientsideModel(path, RENDERGROUP_OPAQUE)
        if ( !IsValid(self.tpikModel) ) then return end
        self.tpikModel:SetNoDraw(true)
        self.tpikModel:SetPlaybackRate(0)
        models[self] = self.tpikModel
    end
    return self.tpikModel
end

--- Uses the framework's replicated raise state when available, otherwise Longsword's standalone lowering state.
function SWEP:IsTPIKLowered()
    local owner = self:GetOwner()
    if ( IsValid(owner) and isfunction(owner.IsWeaponRaised) ) then
        return !owner:IsWeaponRaised()
    end
    return self:GetLowered()
end

--- Resolves raised and lowered offsets with legacy per-field fallbacks and one transition update per frame.
function SWEP:GetTPIKOffset()
    local fallback = self.TPIKOffset or {}
    local states = self.TPIKOffsets or {}
    local raised = states.raised or fallback
    local lowered = states.lowered or raised
    local target = self:IsTPIKLowered() and 1 or 0
    local now = RealTime()
    if ( self.tpikOffsetFrame != FrameNumber() ) then
        local duration = self.TPIKTransitionTime or 0.2
        if ( self.tpikLoweredAmount == nil or duration <= 0 ) then
            self.tpikLoweredAmount = target
        else
            self.tpikLoweredAmount = math.Approach(self.tpikLoweredAmount, target, math.max(now - (self.tpikOffsetTime or now), 0) / duration)
        end
        self.tpikOffsetTime = now
        self.tpikOffsetFrame = FrameNumber()
    end

    local amount = self.tpikLoweredAmount
    local position = raised.Pos or fallback.Pos or vector_origin
    local angle = raised.Ang or fallback.Ang or angle_zero
    local scale = raised.Scale or fallback.Scale or 1
    return LerpVector(amount, position, lowered.Pos or position),
        LerpAngle(amount, angle, lowered.Ang or angle),
        Lerp(amount, scale, lowered.Scale or scale)
end

--- Positions the animated model using ARC9's right-hand offset axes and rotation order.
function SWEP:PositionTPIKModel(model, anchor)
    local position, rotation, scale = self:GetTPIKOffset()
    local angle = anchor:GetAngles()
    local forward, right, up = angle:Forward(), angle:Right(), angle:Up()
    local origin = anchor:GetTranslation() + forward * position.x + right * position.y + up * position.z
    angle:RotateAroundAxis(forward, rotation.r)
    angle:RotateAroundAxis(right, rotation.p)
    angle:RotateAroundAxis(up, rotation.y)
    model:SetPos(origin)
    model:SetAngles(angle)
    model:SetModelScale(scale, 0)
end

--- Evaluates replicated animation timing and poses hands before the player is drawn.
function SWEP:DoTPIK()
    self.tpikFrame = nil
    if ( !self:ShouldTPIK() ) then return end
    local owner = self:GetOwner()
    owner:InvalidateBoneCache()
    owner:SetupBones()
    owner.longswordHeadAimApplied = self:ApplyHeadAim(true) or nil
    local _, anchor = GetBone(owner, self.TPIKAnchor or "ValveBiped.Bip01_R_Hand")
    if ( !anchor ) then return end
    local model = self:GetTPIKModel()
    if ( !IsValid(model) ) then return end

    local name = self.GetTPIKSequenceName and self:GetTPIKSequenceName() or ""
    local start = self.GetTPIKSequenceStart and self:GetTPIKSequenceStart() or CurTime()
    if ( name == "" ) then name = self.TPIKIdleSequence or "idle" end
    local sequence = model:LookupSequence(name)
    if ( sequence < 0 ) then return end
    local duration = model:SequenceDuration(sequence)
    local cycle = duration > 0 and math.max(CurTime() - start, 0) / duration or 0
    local info = model:GetSequenceInfo(sequence)
    cycle = info and bit.band(info.flags, 1) != 0 and cycle % 1 or math.min(cycle, 1)
    model:SetSequence(sequence)
    model:SetCycle(cycle)
    model:SetSkin(self:GetSkin())
    for _, bodygroup in ipairs(model:GetBodyGroups()) do
        model:SetBodygroup(bodygroup.id, self:GetBodygroup(bodygroup.id))
    end
    self:PositionTPIKModel(model, anchor)
    model:InvalidateBoneCache()
    model:SetupBones()
    if ( !self:ApplyTPIKArm(owner, model, "R") ) then return end
    if ( !self.TPIKNoLeftHand and !owner:IsTyping() ) then self:ApplyTPIKArm(owner, model, "L") end
    self.tpikFrame = FrameNumber()
end

--- Draws the posed model only when its owner's current render pass has a valid TPIK solution.
function SWEP:DrawTPIKWorldModel()
    if ( !self:ShouldTPIK() or self.tpikFrame != FrameNumber() or !IsValid(self.tpikModel) ) then return false end
    self.tpikModel:DrawModel()
    self:DrawWorldModelElements(self.tpikModel:GetPos(), self.tpikModel:GetAngles())
    return true
end

--- Aligns a configured weapon owner's eyes with their aim while preserving the model's head-bone axes.
function SWEP:ApplyHeadAim(bBonesReady)
    local owner = self:GetOwner()
    if ( !self.HeadTracksAim or !IsValid(owner) or !owner:Alive() or owner:GetActiveWeapon() != self ) then return false end
    if ( owner:IsPlayingTaunt() or (owner.ResolveForcedSequence and owner:ResolveForcedSequence()) ) then return false end
    if ( EyePos():DistToSqr(owner:GetPos()) > distance:GetFloat() ^ 2 ) then return false end
    if ( !bBonesReady ) then
        owner:InvalidateBoneCache()
        owner:SetupBones()
    end
    local head, matrix = GetBone(owner, "ValveBiped.Bip01_Head1")
    if ( !matrix ) then return false end
    if ( self.headAimModel != owner:GetModel() or !self.headAimRelative ) then
        local attachment = owner:LookupAttachment("eyes")
        local eyes = attachment > 0 and owner:GetAttachment(attachment)
        if ( !eyes ) then return false end
        local _, relative = WorldToLocal(vector_origin, matrix:GetAngles(), vector_origin, eyes.Ang)
        self.headAimRelative = relative
        self.headAimModel = owner:GetModel()
    end

    local aim = owner:EyeAngles()
    local body = owner:GetRenderAngles()
    local yawLimit = self.HeadAimYawLimit or 85
    local pitchLimit = self.HeadAimPitchLimit or 60
    local target = Angle(math.Clamp(math.NormalizeAngle(aim.p), -pitchLimit, pitchLimit),
        body.y + math.Clamp(math.AngleDifference(aim.y, body.y), -yawLimit, yawLimit), 0)
    local _, rotation = LocalToWorld(vector_origin, self.headAimRelative, vector_origin, target)
    local pose = Matrix(matrix)
    pose:SetAngles(rotation)
    MoveBone(owner, head, pose)
    return true
end

--- Updates supported active weapons before their owners render, including mirror and depth passes.
local function PrePlayerDraw(owner)
    local weapon = owner:GetActiveWeapon()
    if ( owner.longswordHeadAimApplied and (!IsValid(weapon) or !weapon.HeadTracksAim) ) then
        owner:InvalidateBoneCache()
    end
    owner.longswordHeadAimApplied = nil
    if ( IsValid(weapon) and weapon.IsLongsword and weapon.DoTPIK ) then
        weapon:DoTPIK()
        if ( !owner.longswordHeadAimApplied and weapon.tpikFrame != FrameNumber() ) then
            owner.longswordHeadAimApplied = weapon:ApplyHeadAim() or nil
        end
    end
end

--- Reclaims models after holstering, removal, disabling TPIK or leaving its rendering range.
local function CleanupModels()
    for weapon, model in pairs(models) do
        if ( !IsValid(weapon) ) then
            if ( IsValid(model) ) then model:Remove() end
            models[weapon] = nil
        elseif ( !weapon:ShouldTPIK() or weapon:IsDormant() ) then
            weapon:RemoveTPIKModel()
        end
    end
end

hook.Add("PrePlayerDraw", "longsword.TPIK", PrePlayerDraw)
hook.Add("Think", "longsword.TPIKCleanup", CleanupModels)
