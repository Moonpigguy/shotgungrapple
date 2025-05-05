local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Gear = ReplicatedStorage.Gear
local Shotgun = ServerStorage.Shotgun

local MainChar = script.Parent
local teamVal = MainChar:WaitForChild("Team")

local rng_v = Random.new()
local bulletsLeft = 4

local grappleStart
local grappleEnd

local lastFire = tick()
local currentOrder = "Attack"

local damage = 1
local innacuracy = 15
local speed = 140

local function getClosestPlayer()
	local closetPlayer = nil
	local closetDistance = math.huge
	for _, Character in pairs(workspace.Live:GetChildren()) do
		if Character and Character ~= MainChar and Character:FindFirstChild("HumanoidRootPart") and not Character:FindFirstChild("Team") or Character.Team.Value ~= teamVal.Value then
			local distance = (Character.HumanoidRootPart.Position - MainChar.HumanoidRootPart.Position).magnitude
			if distance < closetDistance then
				closetPlayer = Character
				closetDistance = distance
			end
		end
	end
	return closetPlayer
end

local currentTarget = getClosestPlayer()

local range = 300
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Blacklist
overlapParams.FilterDescendantsInstances = {MainChar, workspace.Ignore}


local redPart1 = Instance.new("Part")
redPart1.Anchored = true
redPart1.Size = Vector3.new(1, 1, 1)
redPart1.Color = Color3.new(1, 0, 0)
redPart1.Transparency = 1
redPart1.Parent = workspace.Ignore
local redPart2 = redPart1:Clone()
redPart2.Parent = workspace.Ignore

local function getPartsTowards(startPos, targetPos)
	-- use a 45 degree rotated spatial query to get parts infront of the camera
	local cameraCFrame = CFrame.new(startPos, targetPos)
	local cameraLookVector = cameraCFrame.LookVector
	local cameraUpVector = cameraCFrame.UpVector
	local cameraPosition = cameraCFrame.Position

	local cameraLookVectorRotated = CFrame.fromAxisAngle(cameraUpVector, math.rad(45)) * cameraLookVector
	local newCFrame = cameraCFrame * CFrame.new(0,0,-range)
	-- CFrame.new(newCFrame.Position, newCFrame.Position + cameraLookVectorRotated)
	local parts = workspace:GetPartBoundsInBox(newCFrame, Vector3.new(range * 1.1, range * 1.1, range * 1.1), overlapParams)
	return parts
end

local function getClosestPoint(startPos, direction, part)
	local mousePosition = game:GetService("UserInputService"):GetMouseLocation()

	--// --> Convert the mouse position to a ray in world space

	--// --> Find the intersection point between the ray and the part using camera lookvector y

	local closestPoint = startPos + direction * direction:Dot(part.Position - startPos)

	-- find the closest point on the part
	local partCFrame = part.CFrame
	local partSize = part.Size
	local partPosition = partCFrame.p
	local partOrientation = partCFrame.lookVector
	local partUp = partCFrame.upVector
	local partRight = partCFrame.rightVector

	local dividedSize = 3

	local closestPoint = partPosition + partOrientation * math.clamp(partOrientation:Dot(closestPoint - partPosition), -partSize.Z/dividedSize, partSize.Z/dividedSize) + partUp * math.clamp(partUp:Dot(closestPoint - partPosition), -partSize.Y/dividedSize, partSize.Y/dividedSize) + partRight * math.clamp(partRight:Dot(closestPoint - partPosition), -partSize.X/dividedSize, partSize.X/dividedSize)


	return closestPoint

end

local grappleLeft = Instance.new("Part")
grappleLeft.Size = Vector3.new(0.2, 0.2, 0.2)
grappleLeft.Anchored = true
grappleLeft.CanCollide = false
grappleLeft.Transparency = 0.5
grappleLeft.Name = "Left"
grappleLeft.Parent = workspace.Ignore
local grappleRight = grappleLeft:Clone()
grappleRight.Name = "Right"
grappleRight.Parent = workspace.Ignore

local newAttachment = Instance.new("Attachment")
newAttachment.Parent = grappleLeft

local newAttachment2 = Instance.new("Attachment")
newAttachment2.Parent = grappleRight

local function updateRope(startPart, endPos, hitPart, grapple)
	if startPart:FindFirstChild("Beam") then
		grapple.Position = endPos


		startPart.Beam.Attachment1 = grapple.Attachment
	end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Blacklist

local function getDoublePoints(targetPos)
	rayParams.FilterDescendantsInstances = {MainChar, workspace.Ignore}
	local leftPosList = {}
	local rightPosList = {}

	for _, part in pairs(getPartsTowards(MainChar.HumanoidRootPart.Position, targetPos)) do
		if part.Size.X > 300 or part.Size.Z > 300 then continue end
		-- get the closest screen point on the right half of the screen
		-- make a ray and get the distance between the part and the ray hit
		-- if the distance is less than 0.5 then add to the list


		local closest = getClosestPoint(MainChar.HumanoidRootPart.Position, (targetPos - MainChar.HumanoidRootPart.Position), part)
		-- if on the left side of the targetPos then add to the leftPosList
		local newCF = CFrame.new(MainChar.HumanoidRootPart.Position, closest)
		local dProduct = newCF.RightVector:Dot((targetPos - MainChar.HumanoidRootPart.Position).Unit)
		if dProduct < 0 then
			table.insert(leftPosList, {closest})
		else
			table.insert(rightPosList, {closest})
		end
	end

	-- sort through each list and gets the closest position to the character
	local closestRight = Vector3.new(0,0,0)
	local closestLeft = Vector3.new(0,0,0)
	local closestMag = math.huge

    --[[for _, pos in pairs(rightPosList) do
        if (MainChar.HumanoidRootPart.Position - pos[1]).Magnitude < (MainChar.HumanoidRootPart.Position - closestRight).Magnitude then
            closestRight = pos[1]
        end
    end

    for _, pos in pairs(leftPosList) do
        if (MainChar.HumanoidRootPart.Position - pos[1]).Magnitude < (MainChar.HumanoidRootPart.Position - closestLeft).Magnitude then
            closestLeft = pos[1]
        end
    end]]
	--print(#rightPosList, #leftPosList)
	for _, pos in pairs(rightPosList) do
		for _, pos2 in pairs(leftPosList) do
			if ((pos[1] + pos2[1])/2 - targetPos).Magnitude < closestMag then
				closestRight = pos[1]
				closestLeft = pos2[1]
				closestMag = ((pos[1] + pos2[1])/2 - (closestRight + closestLeft)/2).Magnitude
			end
		end
	end
	--print(closestLeft, closestRight)
	local leftResult = workspace:Raycast(MainChar.HumanoidRootPart.Position, (closestLeft - MainChar.HumanoidRootPart.Position).Unit * range * 1.1, rayParams)
	local rightResult = workspace:Raycast(MainChar.HumanoidRootPart.Position, (closestRight - MainChar.HumanoidRootPart.Position).Unit * range * 1.1, rayParams)
	--print(leftResult.Instance, rightResult.Instance)
	if leftResult and rightResult then
		return leftResult.Position, rightResult.Position
	end
	return nil

end

local slingShotting = false
local usePartPhysics = false
local currPhys = nil

local function partPhysicsRep(char, bool, vel)
	if bool then
		usePartPhysics = true
		-- use a part to represent the physics of the character
		local part = Instance.new("Part")
		part.Name = "PartPhysics"
		part.Size = Vector3.new(1, 1, 1)
		part.Transparency = 1
		part.Velocity = vel
		part.CFrame = char.HumanoidRootPart.CFrame
		part.CollisionGroup = "PhysGroup"
		part.Parent = workspace.Ignore
		currPhys = part
		part:SetNetworkOwner(nil)

		local Heartbeat
		Heartbeat = RunService.Heartbeat:Connect(function()
			char.HumanoidRootPart.CFrame = CFrame.new(part.Position, part.Position + char.HumanoidRootPart.CFrame.LookVector)
			if not usePartPhysics then
				Heartbeat:Disconnect()
				if currPhys then
					currPhys:Destroy()
					currPhys = nil
				end
			end
		end)
		return part
	else
		usePartPhysics = false
		if currPhys then
			currPhys:Destroy()
			currPhys = nil
		end
	end
end

local unfindTime = 0
local uncollided = {}

local function toggleCharColl(bool)
	if bool then
		for _, part in pairs(MainChar:GetChildren()) do
			if part:IsA("BasePart") and part.CanCollide == true then
				part.CanCollide = false
				table.insert(uncollided, part)
			end
		end
		return 
	else
		for _, part in pairs(uncollided) do
			part.CanCollide = true
		end
		uncollided = {}
	end
end


local function updateMovement()
	local bodyVel = MainChar.HumanoidRootPart:FindFirstChild("BodyVelocity")
	local bodyGyro = MainChar.HumanoidRootPart:FindFirstChild("BodyGyro")

	-- figure out position of ropes to for sling shot
	local closest = currentTarget
	local leftPart = MainChar:FindFirstChild("Gear").Left
	local rightPart = MainChar:FindFirstChild("Gear").Right
    --[[local groundRay = workspace:Raycast(MainChar.HumanoidRootPart.Position, Vector3.new(0, -5, 0), rayParams)
    if groundRay and groundRay.Instance then
        partPhysicsRep(MainChar, false, MainChar.HumanoidRootPart.Velocity)
    end]]
	-- if the character is on the ground then jump
	if MainChar.Humanoid:GetState() == Enum.HumanoidStateType.Running or MainChar.Humanoid:GetState() == Enum.HumanoidStateType.RunningNoPhysics then
		MainChar.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
	if MainChar.HumanoidRootPart.Velocity.Magnitude < 15 then
		unfindTime = unfindTime + 1
	end
	if unfindTime > 60 then
		slingShotting = true
		toggleCharColl(false)
		bodyVel.MaxForce = Vector3.new(0, 10000, 0)
		bodyVel.Velocity = Vector3.new(0,40,0)
		local startY = MainChar.HumanoidRootPart.Position.Y
		for i = 1,50 do
			if startY - MainChar.HumanoidRootPart.Position.Y > 1 then
				break
			end
			task.wait(0.01)
		end
		toggleCharColl(true)
		unfindTime = 0
		slingShotting = false
		return
	end
	if closest and closest:FindFirstChild("HumanoidRootPart") and not slingShotting then
		local left, right = getDoublePoints(closest.HumanoidRootPart.Position + Vector3.new(0, 30, 0))
		if left == nil or right == nil then
			return
		end
		--redPart1.CFrame = CFrame.new(left)
		--redPart2.CFrame = CFrame.new(right)
		updateRope(leftPart, left, closest.HumanoidRootPart, grappleLeft)
		updateRope(rightPart, right, closest.HumanoidRootPart, grappleRight)
		local avPos = (left + right)/2
		local posDiff = (avPos - MainChar.HumanoidRootPart.Position).Unit
		local lastMag = (MainChar.HumanoidRootPart.Position - avPos).Magnitude
		local startDiff = (avPos - MainChar.HumanoidRootPart.Position).Unit
		local frameWarnings = 0
		local maxWarnings = 100
		slingShotting = true
		bodyVel.MaxForce = Vector3.new(8500, 8500, 8500)
		bodyGyro.maxTorque = Vector3.new(8000, 8000, 8000)
		grappleStart:Play()
		while posDiff:Dot(startDiff) > 0 and (MainChar.HumanoidRootPart.Position - avPos).Magnitude < 300 and (MainChar.HumanoidRootPart.Position - avPos).Magnitude < lastMag * 1.5 do
			bodyGyro.CFrame = CFrame.new(MainChar.HumanoidRootPart.Position, avPos)
			posDiff = (avPos - MainChar.HumanoidRootPart.Position).Unit
			lastMag = (MainChar.HumanoidRootPart.Position - avPos).Magnitude
			bodyVel.Velocity = (avPos - MainChar.HumanoidRootPart.Position).Unit * speed
			if MainChar.HumanoidRootPart.Velocity.Magnitude < 10 then
				frameWarnings = frameWarnings + 1
			end
			if frameWarnings > maxWarnings then
				break
			end
			task.wait() 
		end
		grappleEnd:Play()
		leftPart.Beam.Attachment1 = nil
		rightPart.Beam.Attachment1 = nil
		bodyVel.MaxForce = Vector3.new(8500, 0, 8500)
		bodyGyro.maxTorque = Vector3.new(0,0,0)
		local lastY = MainChar.HumanoidRootPart.Position.Y
		if not MainChar:FindFirstChild("HumanoidRootPart") then slingShotting = false return end
		bodyVel.Velocity = MainChar.HumanoidRootPart.Velocity
		--partPhysicsRep(MainChar, true, MainChar.HumanoidRootPart.Velocity)
        --[[while MainChar:FindFirstChild("HumanoidRootPart") and lastY > MainChar.HumanoidRootPart.Position.Y do
            lastY = MainChar.HumanoidRootPart.Position.Y
            task.wait()
        end]]
		task.wait(0.2)
		--partPhysicsRep(MainChar, false, MainChar.HumanoidRootPart.Velocity)
		slingShotting = false
	end

end

local function handleImpact(hit, pos, normal)
	if hit.Parent:FindFirstChild("Humanoid") then
		local humanoid = hit.Parent:FindFirstChild("Humanoid")

		if humanoid.Health <= 0 then return end

		humanoid:TakeDamage(damage)
		if humanoid.Health <= 0 then
			local newSound = game.ReplicatedStorage.Sounds.DeathSounds:GetChildren()[math.random(1, #game.ReplicatedStorage.Sounds.DeathSounds:GetChildren())]:Clone()
			newSound.Parent = humanoid.Parent.Head
			newSound:Play()
		end
	end
end

local function createBullet(startCF, velocity)
	local newBulletCF = startCF
	local runConn
	local startTime = tick()
	runConn = RunService.Heartbeat:Connect(function(dt)
		if tick() - startTime > 5 then
			runConn:Disconnect()
			return
		end
		local ray = Ray.new(newBulletCF.Position, velocity * dt)
		local hit, pos, normal = workspace:FindPartOnRayWithIgnoreList(ray, {MainChar, workspace.Ignore})
		if hit then
			handleImpact(hit, pos, normal)
			runConn:Disconnect()
			return
		end
		newBulletCF = CFrame.new(newBulletCF.Position + velocity * dt, newBulletCF.Position + velocity) * CFrame.Angles(0, math.rad(90), 0)
	end)
	RunService.Heartbeat:Wait()
end

local function randomVectorOffset(v, maxAngle) --returns uniformly-distributed random unit vector no more than maxAngle radians away from v
	return (CFrame.new(Vector3.new(), v)*CFrame.Angles(0, 0, rng_v:NextNumber(0, 2*math.pi))*CFrame.Angles(math.acos(rng_v:NextNumber(math.cos(maxAngle), 1)), 0, 0)).LookVector
end

local function fireEffects(shotgun)
	local pitch = math.random(80, 120) / 100
	shotgun.FirePart.Fire.Pitch = pitch
	shotgun.FirePart.Fire:Play()
	task.spawn(function()
		shotgun.FirePart.FlashLight.Enabled = true
		task.wait(0.1)
		shotgun.FirePart.FlashLight.Enabled = false
	end)
	-- shake the screen
	workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * CFrame.Angles(math.rad(0.5), 0, 0)
end

local ShotgunLeft
local ShotgunRight

local currentShotgun
local velocity = 1000
local spread = 2

local function fireShotgun()
	if currentShotgun == ShotgunRight then
		currentShotgun = ShotgunLeft
	else
		currentShotgun = ShotgunRight
	end
	local bullets = {}
	lastFire = tick()
	-- apply a force to the player based on the direction of the shot
	fireEffects(currentShotgun)
	local randomPositionOffset = Vector3.new(math.random(-innacuracy, innacuracy), math.random(-innacuracy, innacuracy), math.random(-innacuracy, innacuracy))
	local startCF = CFrame.new(currentShotgun:WaitForChild("FirePart").Position, currentTarget.HumanoidRootPart.Position + randomPositionOffset)

	for i = 1,30 do
		local angleOffset = randomVectorOffset((currentTarget.HumanoidRootPart.Position - startCF.p).Unit, math.rad(spread))
		task.spawn(function() 
			createBullet(startCF, velocity * angleOffset) 
		end)
		table.insert(bullets, {startCF, velocity * angleOffset})
	end
	game.ReplicatedStorage.ReplicateEffect:FireAllClients("RepBullet", nil, startCF, bullets)
end

local fireCooldown = math.random(50, 300) / 100

local function updateCombat()
	if currentOrder == "Attack" then
		currentTarget = getClosestPlayer()
		if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
			local humanoidResult = workspace:Raycast(MainChar.HumanoidRootPart.Position, (currentTarget.HumanoidRootPart.Position - MainChar.HumanoidRootPart.Position).Unit * 1000, rayParams)
			if tick() - lastFire > fireCooldown and humanoidResult and humanoidResult.Instance.Parent == currentTarget then
				fireShotgun()
				fireCooldown = math.random(100, 300) / 100
			end
		end
	end
end


local function updateAI()
	if not MainChar then return end
	if not MainChar:WaitForChild("HumanoidRootPart") then return end
	updateCombat()
	--updateArms()
	updateMovement()
end

task.wait(1)

MainChar.Humanoid.BreakJointsOnDeath = false
MainChar.Humanoid.RequiresNeck = false

local BodyVelocity = Instance.new("BodyVelocity")
BodyVelocity.MaxForce = Vector3.new(8500, 8500, 8500)
BodyVelocity.Velocity = Vector3.new(0, 0, 0)
BodyVelocity.Parent = MainChar.HumanoidRootPart

local bodyGyro = Instance.new("BodyGyro")
bodyGyro.CFrame = MainChar.HumanoidRootPart.CFrame 
bodyGyro.Parent = MainChar.HumanoidRootPart
bodyGyro.P = 5000
bodyGyro.maxTorque = Vector3.new(0, 0, 0)
bodyGyro.D = 500


ServerStorage.GiveGear:Fire(MainChar)

ShotgunLeft = MainChar:WaitForChild("ShotgunLeft")
ShotgunRight = MainChar:WaitForChild("ShotgunRight")

grappleStart = ReplicatedStorage.Sounds.Grapple:Clone()
grappleStart.Parent = MainChar.Gear.Middle
grappleEnd = ReplicatedStorage.Sounds.GrappleEnd:Clone()
grappleEnd.Parent = MainChar.Gear.Middle

local tweenService = game:GetService("TweenService")

currentShotgun = ShotgunLeft

local conn
conn = RunService.Heartbeat:Connect(function()
	if not MainChar or not MainChar:FindFirstChild("HumanoidRootPart") or not MainChar:FindFirstChild("Humanoid") or MainChar.Humanoid.Health <= 0 then
		conn:Disconnect()
		return
	end
	updateAI()
end)

local function handleDeath()
	for _, v: BasePart in ipairs(MainChar:GetDescendants()) do
		if v:IsA("BasePart") then
			v:SetNetworkOwner(nil)
		end
	end

	if MainChar:FindFirstChild("Fake Arms") then
		MainChar["Fake Arms"]:Destroy()
	end

	MainChar:FindFirstChild("Left Arm").Transparency = 0
	MainChar:FindFirstChild("Right Arm").Transparency = 0

	local newRagdoll = require(ReplicatedStorage.Modules.Ragdoll).new()
	newRagdoll:Ragdoll(MainChar)
	repeat task.wait() until MainChar.HumanoidRootPart.Velocity.Magnitude < 1
	local groundResult = workspace:Raycast(MainChar.HumanoidRootPart.Position, Vector3.new(0, -10, 0))
	if not groundResult then return end
	-- create pool of blood
	local bloodCyl = Instance.new("Part")
	bloodCyl.Shape = Enum.PartType.Cylinder
	bloodCyl.Size = Vector3.new(0.2, 0.2, 0.2)
	bloodCyl.Anchored = true
	bloodCyl.CanCollide = false
	bloodCyl.Transparency = 0
	bloodCyl.Material = Enum.Material.SmoothPlastic
	bloodCyl.Color = Color3.fromRGB(255, 0, 0)
	bloodCyl.Parent = MainChar
	bloodCyl.Position = groundResult.Position
	bloodCyl.CFrame = bloodCyl.CFrame * CFrame.Angles(0, 0, math.rad(90))
	local size = math.random(50, 100) / 10
	local newTween = tweenService:Create(bloodCyl, TweenInfo.new(30), {Size = Vector3.new(0.2, size, size)})
	newTween:Play()
end

MainChar.Humanoid.Died:Connect(function()
	conn:Disconnect()
	BodyVelocity:Destroy()
	bodyGyro:Destroy()
	handleDeath()
end)


ReplicatedStorage.OrderBots.OnServerEvent:Connect(function(player, order)
	if order == "Follow" then
		currentOrder = "Follow"
		currentTarget = player.Character
	elseif order == "Stop" then
		currentOrder = "Stop"
		currentTarget = nil
	end
end)
