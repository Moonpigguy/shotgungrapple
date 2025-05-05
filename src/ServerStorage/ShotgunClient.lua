local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local torso = Character.Torso

local ShotgunLeft = Character:WaitForChild("ShotgunLeft")
local ShotgunRight = Character:WaitForChild("ShotgunRight")

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mouse = Player:GetMouse()
local replicateEffect = ReplicatedStorage:WaitForChild("ReplicateEffect")
local GunEvent = ReplicatedStorage:WaitForChild("GunEvent")
local MouseGui = Player.PlayerGui:WaitForChild("MouseGui")

-- prevent left and right arm from being animated by default roblox animations
local fakeArms = Character:WaitForChild("Fake Arms")
local rightArm = fakeArms:WaitForChild("Right Arm")
local leftArm = fakeArms:WaitForChild("Left Arm")

local spread = 1.6
local bulletsPerMag = 4
local fireCooldown = 0.1
local bulletRecoveryTime = 0.5
local shotgunForce = 1000
local velocity = 2000

local currentShotgun = ShotgunRight
local rng_v = Random.new()
local bulletsLeft = 4
local lastFire = tick()

local connection
connection = RunService.RenderStepped:Connect(function()
	-- sets the arm welds to face the mouse position
	if not torso or not torso.Parent or not fakeArms.Parent or not rightArm:FindFirstChild("ArmWeld") or not leftArm:FindFirstChild("ArmWeld") then
		connection:Disconnect()
		return
	end
	local mousePos = Mouse.Hit.Position
	local rightArmPos = (torso.CFrame * CFrame.new(1.5, 0.5, 0)).Position
	local rightArmCFrame = CFrame.new(rightArmPos, mousePos) * CFrame.new(0, 0, -1) * CFrame.Angles(math.rad(90), 0, 0)
	rightArm.ArmWeld.C1 = rightArmCFrame:inverse() * CFrame.new(0, 0, 0)
	rightArm.ArmWeld.C0 = torso.CFrame:inverse() * CFrame.new(0, 0, 0)

	local leftArmPos = (torso.CFrame * CFrame.new(-1.5, 0.5, 0)).Position
	local leftArmCFrame = CFrame.new(leftArmPos, mousePos) * CFrame.new(0, 0, -1) * CFrame.Angles(math.rad(90), 0, 0)
	leftArm.ArmWeld.C1 = leftArmCFrame:inverse() * CFrame.new(0, 0, 0)
	leftArm.ArmWeld.C0 = torso.CFrame:inverse() * CFrame.new(0, 0, 0)

	replicateEffect:FireServer("GunArms", Mouse.Hit.Position)

end)

local Debris = game:GetService("Debris")

local function handleImpact(hit, pos, normal)
	local color = hit.Color
	if hit.Parent:FindFirstChild("Humanoid") then
		local humanoid = hit.Parent:FindFirstChild("Humanoid")
		color = Color3.fromRGB(255, 0, 0)
		GunEvent:FireServer("Damage", humanoid, 20)
	end
	local newParticle = ReplicatedStorage.BulletHole:Clone()
	local weldConstraint = Instance.new("WeldConstraint")
	weldConstraint.Part0 = hit
	weldConstraint.Part1 = newParticle
	weldConstraint.Parent = newParticle
	local sparkParticle = newParticle.Sparks
	sparkParticle.Color = ColorSequence.new(color)
	newParticle.CFrame = CFrame.new(pos, pos + normal)
	newParticle.Parent = workspace.Ignore

	sparkParticle:Emit(10)
	Debris:AddItem(newParticle, 10)
end

local function createBullet(startCF, velocity)
	local newBullet = ReplicatedStorage.bullet:Clone()
	newBullet.CFrame = startCF
	local runConn
	replicateEffect:FireServer("RepBullet", startCF, velocity)
	runConn = RunService.Heartbeat:Connect(function(dt)
		local ray = Ray.new(newBullet.Position, velocity * dt)
		local hit, pos, normal = workspace:FindPartOnRayWithIgnoreList(ray, {Character, workspace.Ignore})
		if hit then
			newBullet:Destroy()
			handleImpact(hit, pos, normal)
			runConn:Disconnect()
			return
		end
		newBullet.CFrame = CFrame.new(newBullet.Position + velocity * dt, newBullet.Position + velocity) * CFrame.Angles(0, math.rad(90), 0)
	end)
	RunService.Heartbeat:Wait()
	newBullet.Parent = workspace.Ignore
end

local function RandomVectorOffset(v, maxAngle) --returns uniformly-distributed random unit vector no more than maxAngle radians away from v
	return (CFrame.new(Vector3.new(), v)*CFrame.Angles(0, 0, rng_v:NextNumber(0, 2*math.pi))*CFrame.Angles(math.acos(rng_v:NextNumber(math.cos(maxAngle), 1)), 0, 0)).LookVector
end

local function fireEffects(shotgun)
	local pitch = math.random(80, 120) / 100
	shotgun.FirePart.Fire.Pitch = pitch
	shotgun.FirePart.Fire:Play()
	replicateEffect:FireServer("PlaySound", shotgun.FirePart.Fire, pitch)
	task.spawn(function()
		shotgun.FirePart.FlashLight.Enabled = true
		task.wait(0.1)
		shotgun.FirePart.FlashLight.Enabled = false
	end)
	-- shake the screen
	workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * CFrame.Angles(math.rad(0.5), 0, 0)
end

local function fireShotgun()
	if currentShotgun == ShotgunRight then
		currentShotgun = ShotgunLeft
	else
		currentShotgun = ShotgunRight
	end
	
	bulletsLeft = bulletsLeft - 1
	lastFire = tick()
	
	local startCF = CFrame.new(currentShotgun:WaitForChild("FirePart").Position, Mouse.Hit.Position)
	
	fireEffects(currentShotgun)
	for i = 1,30 do
		task.spawn(function() createBullet(startCF, velocity * RandomVectorOffset((Mouse.Hit.p - startCF.p).Unit, math.rad(spread))) end)
	end
end
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if bulletsLeft > 0 and tick() - lastFire > fireCooldown then
			fireShotgun()
		end
	end
end)

while true do
	if bulletsLeft < bulletsPerMag and tick() - lastFire > 1 then
		bulletsLeft = bulletsLeft + 1
		task.wait(bulletRecoveryTime)
	end
	for _, bulletFrame in pairs(MouseGui.Frame.Circle.BulletFrame:GetChildren()) do
		if not tonumber(bulletFrame.Name) then continue end
		if tonumber(bulletFrame.Name) <= bulletsLeft then
			bulletFrame.Visible = true
		else
			bulletFrame.Visible = false
		end
	end
	task.wait()
end
