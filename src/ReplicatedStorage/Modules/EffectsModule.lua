-- EffectsModule — client-side particle burst effects
-- Usage: require(EffectsModule).Flour(position)
--        require(EffectsModule).Steam(position)
--        require(EffectsModule).Confetti(position)

local EffectsModule = {}

local function makePart(position, offsetY)
	local p = Instance.new("Part")
	p.Anchored    = true
	p.CanCollide  = false
	p.Transparency = 1
	p.Size        = Vector3.new(1, 1, 1)
	p.CFrame      = CFrame.new(position + Vector3.new(0, offsetY, 0))
	p.Parent      = workspace
	return p
end

local function cleanup(part, delay)
	task.delay(delay, function()
		if part and part.Parent then part:Destroy() end
	end)
end

-- Flour puff — white sparkle burst, Mix station
function EffectsModule.Flour(position)
	local part = makePart(position, 1)
	local pe   = Instance.new("ParticleEmitter", part)
	pe.Color       = ColorSequence.new(Color3.fromRGB(255, 252, 235))
	pe.LightEmission  = 0.15
	pe.LightInfluence = 0.8
	pe.Lifetime    = NumberRange.new(0.6, 1.2)
	pe.Rate        = 0
	pe.RotSpeed    = NumberRange.new(-45, 45)
	pe.Rotation    = NumberRange.new(0, 360)
	pe.Size        = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(0.6, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	pe.Speed       = NumberRange.new(8, 16)
	pe.SpreadAngle = Vector2.new(70, 70)
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe:Emit(28)
	cleanup(part, 2)
end

-- Steam — rising gray cloud, Oven station
function EffectsModule.Steam(position)
	local part = makePart(position, 2)
	local pe   = Instance.new("ParticleEmitter", part)
	pe.Color   = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   Color3.fromRGB(190, 190, 190)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 220, 220)),
		ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 255, 255)),
	})
	pe.LightEmission  = 0
	pe.LightInfluence = 0.5
	pe.Lifetime    = NumberRange.new(1.5, 2.5)
	pe.Rate        = 0
	pe.RotSpeed    = NumberRange.new(-20, 20)
	pe.Size        = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.4, 1.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	pe.Speed       = NumberRange.new(3, 7)
	pe.SpreadAngle = Vector2.new(25, 25)
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe:Emit(18)
	cleanup(part, 3.5)
end

-- Confetti — colourful burst, successful delivery
function EffectsModule.Confetti(position)
	local part = makePart(position, 2.5)
	local pe   = Instance.new("ParticleEmitter", part)
	pe.Color   = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    Color3.fromRGB(255, 210, 0)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 100, 150)),
		ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(100, 180, 255)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(160, 255, 140)),
		ColorSequenceKeypoint.new(1,    Color3.fromRGB(255, 210, 0)),
	})
	pe.LightEmission  = 0.6
	pe.LightInfluence = 0.4
	pe.Lifetime    = NumberRange.new(1.5, 2.5)
	pe.Rate        = 0
	pe.RotSpeed    = NumberRange.new(-180, 180)
	pe.Rotation    = NumberRange.new(0, 360)
	pe.Size        = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	pe.Speed       = NumberRange.new(12, 22)
	pe.SpreadAngle = Vector2.new(80, 80)
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.65, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe:Emit(50)
	cleanup(part, 3.5)
end

return EffectsModule
