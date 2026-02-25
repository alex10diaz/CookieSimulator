local UserInputService = game:GetService("UserInputService")

local gui = script.Parent

local SkillCheck = gui.SkillCheck

local TouchFrame = SkillCheck:WaitForChild("TouchFrame")
local TouchBar = SkillCheck:WaitForChild("TouchBar")

local function checkPosition(frame, mid)
	local touchBarPos = frame.AbsolutePosition.X
	local touchBarFrame = mid.AbsolutePosition.X

	local a = touchBarPos + frame.AbsoluteSize.X
	local b = touchBarFrame + mid.AbsoluteSize.X

	if (touchBarFrame <= touchBarPos and touchBarPos <= b) or (a <= touchBarFrame and a <= b) then
		print ("Not Overlapping")
	else
		print("Overlapping")
	end
end

local function randomizeTouchFrame()
	local minX = 100
	local maxX = 500

	local randomX = math.random(minX, maxX)

	TouchFrame.Position = UDim2.new(0, randomX, 0, 0)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.E then
		checkPosition(TouchFrame, TouchBar)
		randomizeTouchFrame()
	end
end)

while task.wait() do
	-- To do: Add any repeating logic here if needed
end
