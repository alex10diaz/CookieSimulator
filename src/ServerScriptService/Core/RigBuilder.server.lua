-- RigBuilder
-- Creates the NPC Rig template in ReplicatedStorage if it doesn't exist.
-- Used by NPCSpawner for customer and ambient NPCs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Skip if Rig already exists (e.g. from Studio)
if ReplicatedStorage:FindFirstChild("Rig") then
	return
end

local function createRig()
	local rig = Instance.new("Model")
	rig.Name = "Rig"

	-- HumanoidRootPart (required for movement)
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 1, 1)
	hrp.Transparency = 1
	hrp.CanCollide = true
	hrp.Anchored = false
	hrp.Parent = rig

	-- Torso (R6-style, needed for rig structure)
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 1, 1)
	torso.BrickColor = BrickColor.new("Bright blue")
	torso.TopSurface = Enum.SurfaceType.Smooth
	torso.BottomSurface = Enum.SurfaceType.Smooth
	torso.Parent = rig

	-- Head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 2, 2)
	head.Shape = Enum.PartType.Ball
	head.BrickColor = BrickColor.new("Bright yellow")
	head.TopSurface = Enum.SurfaceType.Smooth
	head.BottomSurface = Enum.SurfaceType.Smooth
	head.Parent = rig

	-- Left Arm
	local leftArm = Instance.new("Part")
	leftArm.Name = "Left Arm"
	leftArm.Size = Vector3.new(1, 2, 1)
	leftArm.BrickColor = BrickColor.new("Bright blue")
	leftArm.TopSurface = Enum.SurfaceType.Smooth
	leftArm.BottomSurface = Enum.SurfaceType.Smooth
	leftArm.Parent = rig

	-- Right Arm
	local rightArm = Instance.new("Part")
	rightArm.Name = "Right Arm"
	rightArm.Size = Vector3.new(1, 2, 1)
	rightArm.BrickColor = BrickColor.new("Bright blue")
	rightArm.TopSurface = Enum.SurfaceType.Smooth
	rightArm.BottomSurface = Enum.SurfaceType.Smooth
	rightArm.Parent = rig

	-- Left Leg
	local leftLeg = Instance.new("Part")
	leftLeg.Name = "Left Leg"
	leftLeg.Size = Vector3.new(0.9, 2, 0.9)
	leftLeg.BrickColor = BrickColor.new("Br. yellowish green")
	leftLeg.TopSurface = Enum.SurfaceType.Smooth
	leftLeg.BottomSurface = Enum.SurfaceType.Smooth
	leftLeg.Parent = rig

	-- Right Leg
	local rightLeg = Instance.new("Part")
	rightLeg.Name = "Right Leg"
	rightLeg.Size = Vector3.new(0.9, 2, 0.9)
	rightLeg.BrickColor = BrickColor.new("Br. yellowish green")
	rightLeg.TopSurface = Enum.SurfaceType.Smooth
	rightLeg.BottomSurface = Enum.SurfaceType.Smooth
	rightLeg.Parent = rig

	-- Weld parts together (R6 layout)
	local function weld(a, b, c0, c1)
		local w = Instance.new("Weld")
		w.Part0 = a
		w.Part1 = b
		w.C0 = c0 or CFrame.new()
		w.C1 = c1 or CFrame.new()
		w.Parent = a
	end

	-- Torso to HRP (same spot)
	weld(hrp, torso, CFrame.new(), CFrame.new())

	-- Head on top of torso
	weld(torso, head, CFrame.new(0, 0.5 + 1, 0), CFrame.new(0, -1, 0))

	-- Arms
	weld(torso, leftArm, CFrame.new(-1 - 0.5, 0, 0), CFrame.new(0.5, 0, 0))
	weld(torso, rightArm, CFrame.new(1 + 0.5, 0, 0), CFrame.new(-0.5, 0, 0))

	-- Legs
	weld(torso, leftLeg, CFrame.new(-0.5, -0.5 - 1, 0), CFrame.new(0, 1, 0))
	weld(torso, rightLeg, CFrame.new(0.5, -0.5 - 1, 0), CFrame.new(0, 1, 0))

	-- Humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = rig

	-- Animator (child of Humanoid)
	local animator = Instance.new("Animator")
	animator.Parent = humanoid

	rig.PrimaryPart = hrp
	rig.Parent = ReplicatedStorage

	print("[RigBuilder] Created NPC Rig in ReplicatedStorage")
end

createRig()
