local function giveGear(character)
	local newGear = game:GetService("ReplicatedStorage").Gear:Clone()
	newGear.Middle.HumanoidRootPart.Part1 = character:WaitForChild("HumanoidRootPart")
	newGear.Parent = character
	local newScript = game:GetService("ServerStorage").LocalScript:Clone()
	newScript.Parent = character
	local shotgunScript = game:GetService("ServerStorage").ShotgunClient:Clone()
	shotgunScript.Parent = character
	
	local newOrders = game.ServerStorage.OrderBots:Clone()
	newOrders.Parent = character

	local shotgunLeft = game:GetService("ServerStorage").Shotgun:Clone()
	shotgunLeft.Name = "ShotgunLeft"
	local shotgunRight = game:GetService("ServerStorage").Shotgun:Clone()
	shotgunRight.Name = "ShotgunRight"

	local leftArmTrue = character:WaitForChild("Left Arm")
	local rightArmTrue = character:WaitForChild("Right Arm")
	local torsoTrue = character:WaitForChild("Torso")

	local fakeArms = Instance.new("Model")
	fakeArms.Name = "Fake Arms"
	fakeArms.Parent = character

	local fakeHumanoid = Instance.new("Humanoid")
	fakeHumanoid.Parent = fakeArms
	local Shirt = character:WaitForChild("Shirt"):Clone()

	Shirt.Parent = fakeArms

	local arms = {leftArmTrue, rightArmTrue}
	local fakearms = {}

	for n,v in ipairs(arms) do
		local P = v:Clone()
		P.Transparency = 0
		P.CanCollide = false
		P.Parent = fakeArms
		P.TopSurface, P.BottomSurface = "Smooth", "Smooth"
		local PW = Instance.new("Weld")
		PW.Name = "ArmWeld"
		PW.Parent = P
		PW.Part0, PW.Part1, PW.C0, PW.C1 = torsoTrue, P, torsoTrue.CFrame:inverse(), P.CFrame:inverse()
		v.Transparency = 1
		fakearms[n] = P
	end

	arms[1].Transparency = 1	
	arms[2].Transparency = 1
	fakearms[1].Transparency = 0 
	fakearms[2].Transparency = 0

	-- stop the fake arms from being animated by roblox animations
	for _,v in pairs(fakearms) do
		for _,v2 in pairs(v:GetChildren()) do
			if v2:IsA("Motor6D") then
				v2:Destroy()
			end
		end
	end




	-- weld shotgunleft to left arm
	shotgunLeft:SetPrimaryPartCFrame(fakearms[1].CFrame * CFrame.Angles(-math.rad(90), 0, 0) * CFrame.new(0, 0, -1))

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = shotgunLeft.Grip
	weld.Part1 = fakearms[1]
	weld.Parent = shotgunLeft.Grip

	shotgunLeft.Parent = character

	-- weld shotgunright to right arm
	shotgunRight:SetPrimaryPartCFrame(fakearms[2].CFrame * CFrame.Angles(-math.rad(90), 0, 0) * CFrame.new(0, 0, -1))

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = shotgunRight.Grip
	weld.Part1 = fakearms[2]
	weld.Parent = shotgunRight.Grip

	shotgunRight.Parent = character
end

game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		task.wait(0.1)
		character.Parent = workspace.Live
		giveGear(character)
	end)
end)

for _, player in pairs(game.Players:GetPlayers()) do
	local character = player.Character or player.CharacterAdded:Wait()
	task.wait(0.1)
	character.Parent = workspace.Live
	giveGear(character)
end

game.ServerStorage.GiveGear.Event:Connect(function(character)
	print("giving gear")
	giveGear(character)
end)
