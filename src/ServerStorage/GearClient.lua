local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local Camera = workspace.CurrentCamera
local Character = Player.Character or Player.CharacterAdded:Wait()
local Gear = Character:WaitForChild("Gear")
local CursorUI = Player.PlayerGui:WaitForChild("MouseGui")

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Blacklist
rayParams.FilterDescendantsInstances = {Character, workspace.Ignore}

local bodyVelocity = Instance.new("BodyVelocity")
bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
bodyVelocity.Velocity = Vector3.new(0, 0, 0)
bodyVelocity.Parent = Character.HumanoidRootPart

local bodyGyro = Instance.new("BodyGyro")
bodyGyro.CFrame = Character.HumanoidRootPart.CFrame 
bodyGyro.Parent = Character.HumanoidRootPart
bodyGyro.P = 5000
bodyGyro.maxTorque = Vector3.new(0, 0, 0)
bodyGyro.D = 500

local SlipperyPhysicalProperties = PhysicalProperties.new ( 0.7, 0, 0.5, 100, 1 )
local currentPhys


local replicateEffect = ReplicatedStorage:WaitForChild("ReplicateEffect")
local Animations = ReplicatedStorage.Animations

local loadedAnims = {}

for _, anim in pairs(Animations:GetChildren()) do
	loadedAnims[anim.Name] = Character.Humanoid:LoadAnimation(anim)
end

local range = 500
local speed = 150

local holdingRight = false
local holdingLeft = false
local boosting = false

local doubleMode = false
local quadMode = false

local dead = false

local grapples = {}

for _, part in pairs(Character:GetDescendants()) do
	if part:IsA("BasePart") then
		part.CollisionGroup = "CharGroup"

	end
end

Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

local function createGrapple(pos, part)
	local grapple = Instance.new("Part")
	grapple.Size = Vector3.new(0.2, 0.2, 0.2)
	grapple.Anchored = false
	grapple.CanCollide = false
	grapple.Transparency = 0.5
	grapple.Position = pos
	grapple.Parent = workspace

	local grappleAttachment = Instance.new("Attachment")
	grappleAttachment.Parent = grapple

	local grappleWeld = Instance.new("WeldConstraint")
	grappleWeld.Part0 = grapple
	grappleWeld.Part1 = part
	grappleWeld.Parent = grapple

	return grapple
end

local function shootGrapple(originPart, pos)
	local newGrapple = Instance.new("Part")
	newGrapple.Size = Vector3.new(0.2, 0.2, 0.2)
	newGrapple.Anchored = true
	newGrapple.CanCollide = false
	newGrapple.Transparency = 1
	newGrapple.Position = originPart.Position
	newGrapple.Parent = workspace

	local grappleAttachment = Instance.new("Attachment")
	grappleAttachment.Parent = newGrapple

	originPart.Beam.Attachment1 = newGrapple.Attachment
	local tweenTime = (newGrapple.Position - pos).Magnitude / 1000
	local newTween = TweenService:Create(newGrapple, TweenInfo.new(tweenTime), {Position = pos})
	newTween:Play()

	newTween.Completed:Wait()
	newGrapple:Destroy()



end

local function lenOfDict(table)
	local count = 0
	for _, _ in pairs(table) do
		count = count + 1
	end
	return count
end

local function avPos(table)
	local total = Vector3.new(0, 0, 0)
	for _, v in pairs(table) do
		total = total + v.Position
	end
	return total / lenOfDict(table)
end

local function createAndReplicateSound(sound, part)
	local newSound = sound:Clone()
	newSound.Parent = part
	newSound:Play()
	Debris:AddItem(newSound, newSound.TimeLength + 3)
	replicateEffect:FireServer("Sound", sound, part)
end

local function grappleRightAnim()
	task.spawn(function()
		if lenOfDict(grapples) == 1 then
			if not loadedAnims["RightTurn"].IsPlaying then
				loadedAnims["RightTurn"]:Play()
				loadedAnims["RightTurn"].Stopped:Wait()
				if UserInputService:IsKeyDown(Enum.KeyCode.D) then
					loadedAnims["RightIdle"]:Play()
				end
			end
		elseif lenOfDict(grapples) > 1 then
			if not loadedAnims["DoubleIdle"].IsPlaying then
				if UserInputService:IsKeyDown(Enum.KeyCode.D) then
					loadedAnims["DoubleIdle"]:Play()
				end
			end
		end
	end)
end

local function grappleLeftAnim()
	task.spawn(function()
		if lenOfDict(grapples) == 1 then
			if not loadedAnims["LeftTurn"].IsPlaying then
				loadedAnims["LeftTurn"]:Play()
				loadedAnims["LeftTurn"].Stopped:Wait()
				if UserInputService:IsKeyDown(Enum.KeyCode.A) then
					loadedAnims["LeftIdle"]:Play()
				end
			end
		elseif lenOfDict(grapples) > 1 then
			if not loadedAnims["DoubleIdle"].IsPlaying then
				if UserInputService:IsKeyDown(Enum.KeyCode.A) then
					loadedAnims["DoubleIdle"]:Play()
				end
			end
		end
	end)
end

local function beginGrapple(result, sideID, keyEnum)
	local function update()
		local forwardVector = speed
		local directionNumber = 0
		local sideVector = 0.5
		if holdingRight then
			directionNumber = directionNumber - 1
		elseif holdingLeft then
			directionNumber = directionNumber + 1
		end
		if lenOfDict(grapples) > 1 then
			for _ = 2, lenOfDict(grapples) do
				forwardVector = forwardVector * 1.5
			end
		end
		if boosting then
			forwardVector = forwardVector * 2
		end
		if not holdingLeft then
			if holdingRight then
				sideVector = speed * 2
			end
		else
			sideVector = speed * 2
		end

		local newPos = avPos(grapples)

		local angularVelocity = (Character.HumanoidRootPart.CFrame * CFrame.Angles(0, math.rad(90) * directionNumber, 0)).LookVector * sideVector
		local newVelocity = CFrame.new(Character.HumanoidRootPart.CFrame.Position, newPos).LookVector * forwardVector * 1.1 + angularVelocity
		bodyVelocity.Velocity = newVelocity + Vector3.new(0,1,0)
		-- make the player look at the target
		local gyroCFrame = CFrame.new(Character.HumanoidRootPart.CFrame.Position, newPos)
		--print(newPos)
		bodyGyro.CFrame = gyroCFrame
		Character.Humanoid.AutoRotate = false
	end
	local gearSide = Gear:FindFirstChild(sideID)
	createAndReplicateSound(ReplicatedStorage.Sounds:WaitForChild("Grapple"), gearSide)
	shootGrapple(gearSide, result.Position)
	if loadedAnims[sideID.."Start"] then
		loadedAnims[sideID.."Start"]:Play()
	end


	if keyEnum.EnumType == Enum.KeyCode then
		if not UserInputService:IsKeyDown(keyEnum) then
			return
		end
	elseif not UserInputService:IsMouseButtonPressed(keyEnum) then
		return
	end


	bodyVelocity.MaxForce = Vector3.new(8000, 8000, 8000)
	bodyGyro.maxTorque = Vector3.new(8000, 8000, 8000)
	local grapplePart = createGrapple(result.Position, result.Instance)
	gearSide.Beam.Attachment1 = grapplePart.Attachment
	grapples[sideID] = grapplePart
	replicateEffect:FireServer("Rope", gearSide, grapplePart.Position, result.Instance)


	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		grappleLeftAnim()
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		grappleRightAnim()
	end
	if lenOfDict(grapples) > 1 then
		task.spawn(function()
			if not loadedAnims["DoubleStart"].IsPlaying then
				loadedAnims["DoubleStart"]:Play()
				loadedAnims["DoubleStart"].Stopped:Wait()
				if lenOfDict(grapples) > 1 then
					loadedAnims["DoubleTurn"]:Play()
				end
			end
		end)
	end


	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not grapples[sideID] then
			replicateEffect:FireServer("DestroyRope", gearSide)
			createAndReplicateSound(ReplicatedStorage.Sounds:WaitForChild("GrappleEnd"), gearSide)
			connection:Disconnect()

			if lenOfDict(grapples) < 1 then
				bodyVelocity.MaxForce = Vector3.new(0,0,0)
				bodyGyro.maxTorque = Vector3.new(0, 0, 0)
			end
			Character.Humanoid.AutoRotate = true
			return
		end
		update()
	end)
end

local function sendGrapple(startPart, targetPos, side, keyEnum)
	if not targetPos then
		return
	end
	local result = workspace:Raycast(startPart.Position, (targetPos - startPart.Position).Unit * range, rayParams)
	if result then
		beginGrapple(result, side, keyEnum)
	end
end

local function getClosestPoint(part)
	local mousePosition = game:GetService("UserInputService"):GetMouseLocation()

	--// --> Convert the mouse position to a ray in world space
	local ray = Camera:ViewportPointToRay(mousePosition.X, mousePosition.Y)

	--// --> Find the intersection point between the ray and the part using camera lookvector y

	local closestPoint = ray.Origin + ray.Direction * ray.Direction:Dot(part.Position - ray.Origin)

	-- find the closest point on the part
	local partCFrame = part.CFrame
	local partSize = part.Size
	local partPosition = partCFrame.p
	local partOrientation = partCFrame.lookVector
	local partUp = partCFrame.upVector
	local partRight = partCFrame.rightVector

	local dividedSize = 3


	-- closestpoint based on the part's orientation relative to the camera

	local closestPoint = partPosition + partOrientation * math.clamp(partOrientation:Dot(closestPoint - partPosition), -partSize.Z/dividedSize, partSize.Z/dividedSize) + partUp * math.clamp(partUp:Dot(closestPoint - partPosition), -partSize.Y/dividedSize, partSize.Y/dividedSize) + partRight * math.clamp(partRight:Dot(closestPoint - partPosition), -partSize.X/dividedSize, partSize.X/dividedSize)



	return closestPoint

end

local leftScreenPos = Vector3.new()
local rightScreenPos = Vector3.new()

local topLeftScreenPos = Vector3.new(0, 0, 0)
local topRightScreenPos = Vector3.new(0, 0, 0)
local bottomLeftScreenPos = Vector3.new(0, 0, 0)
local bottomRightScreenPos = Vector3.new(0, 0, 0)

local grappleRight = nil
local grappleLeft = nil
local grappleTopRight = nil
local grappleTopLeft = nil

local function getGrapplePosition()
	-- sends a ray from the camera to the mouse position and return hit position
	local mousePosition = game:GetService("UserInputService"):GetMouseLocation()
	local positions = {}
	--// --> Convert the mouse position to a ray in world space
	local originPos = Character.HumanoidRootPart.Position
	if doubleMode then
		-- returns ray between camera and rightScreenPos
		local resultRight = workspace:Raycast(originPos, (rightScreenPos - originPos).Unit * range, rayParams)
		local resultLeft = workspace:Raycast(originPos, (leftScreenPos - originPos).Unit * range, rayParams)
		if resultRight then
			table.insert(positions, resultRight.Position)
		end
		if resultLeft then
			table.insert(positions, resultLeft.Position)
		end
	else
		-- returns ray between camera and mouse position
		local result = workspace:Raycast(originPos, (Mouse.Hit.Position - originPos).Unit * range, rayParams)
		if result then
			table.insert(positions, result.Position)
		end
	end
	return positions
end

bodyVelocity.MaxForce = Vector3.new(0, 0, 0)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.E then
		local startPart = Gear:FindFirstChild("Right")
		if startPart then
			if doubleMode or quadMode then
				local targetPos = grappleRight
				sendGrapple(startPart, targetPos, "Right", input.KeyCode)
			else
				local targetPos = grappleRight
				sendGrapple(startPart, targetPos, "Right", input.KeyCode)
			end
		end
	end
	if input.KeyCode == Enum.KeyCode.Q then
		local startPart = Gear:FindFirstChild("Left")
		if startPart then
			if doubleMode or quadMode then
				local targetPos = grappleLeft
				sendGrapple(startPart, targetPos, "Left", input.KeyCode)
			else
				local targetPos = grappleRight
				sendGrapple(startPart, targetPos, "Left", input.KeyCode)
			end
		end
	end


	if input.KeyCode == Enum.KeyCode.D then
		holdingRight = true
		grappleRightAnim()
	end

	if input.KeyCode == Enum.KeyCode.A then
		holdingLeft = true
		grappleLeftAnim()
	end

	if input.KeyCode == Enum.KeyCode.Space then
		boosting = true
	end

	if input.KeyCode == Enum.KeyCode.F then
		if doubleMode then
			doubleMode = false
			--quadMode = true
        --[[elseif quadMode then
            quadMode = false]]
		else
			doubleMode = true
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.D then
		holdingRight = false
		loadedAnims["RightIdle"]:Stop()
		loadedAnims["DoubleIdle"]:Stop()
	end

	if input.KeyCode == Enum.KeyCode.A then
		holdingLeft = false
		loadedAnims["LeftIdle"]:Stop()
		loadedAnims["DoubleIdle"]:Stop()
	end

	if input.KeyCode == Enum.KeyCode.E then
		if grapples["Right"] then
			grapples["Right"]:Destroy()
			grapples["Right"] = nil

		end
	end

	if input.KeyCode == Enum.KeyCode.Q then
		if grapples["Left"] then
			grapples["Left"]:Destroy()
			grapples["Left"] = nil

		end
	end


	if input.KeyCode == Enum.KeyCode.Space then
		boosting = false
	end
end)

local function updateFOV()
	-- tween FOV based on velocity of humanoidrootpart
	local velocity = Character.HumanoidRootPart.Velocity
	local speed = velocity.Magnitude
	local fov = 70 + (speed / 100)
	Camera.FieldOfView = fov
end


local function updateCursor()
	
	if UserInputService.MouseIconEnabled then
		UserInputService.MouseIconEnabled = false
	end
	-- sets cursor UI frame position to mouse position + offset to account for topbar
	local mousePos = UserInputService:GetMouseLocation() - Vector2.new(0, 36)
	CursorUI.Frame.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
	if not doubleMode then
		--CursorUI.Frame.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
        --[[CursorUI.Frame.Left.Position = UDim2.new(0, 0, 0, 0)
        CursorUI.Frame.Right.Position = UDim2.new(0, 0, 0, 0)
        CursorUI.Frame.Middle.Position = UDim2.new(0, 0, 0, 0)
    else
        CursorUI.Frame.Position = UDim2.new(0, 0.5, 0, 0.5)
        CursorUI.Frame.Middle.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)]]
	end
end

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Blacklist
overlapParams.FilterDescendantsInstances = {Character, workspace.Ignore}

local function getPartsInfrontOfCamera()
	-- uses a 45 degree rotated spatial query to get parts infront of the camera
	local cameraCFrame = Camera.CFrame
	local cameraLookVector = cameraCFrame.LookVector
	local cameraUpVector = cameraCFrame.UpVector
	local cameraPosition = cameraCFrame.Position

	local cameraLookVectorRotated = CFrame.fromAxisAngle(cameraUpVector, math.rad(45)) * cameraLookVector
	local newCFrame = cameraCFrame * CFrame.new(0,0,-range)
	local parts = workspace:GetPartBoundsInBox(CFrame.new(newCFrame.Position, newCFrame.Position + cameraLookVectorRotated), Vector3.new(range * 1.1, range * 1.1, range * 1.1), overlapParams)
	return parts
end

local offset = Vector3.new(0,0,5)			--left/right, up/down, forward/backward
local trailAlpha = 0.05                      -- trail strengthy

local function updateCam()
	local vel = Character.HumanoidRootPart.Velocity
	local newVel = Vector3.new(vel.X, 0, vel.Z)
	local newOffset = offset * newVel.Magnitude/50
	Character.Humanoid.CameraOffset = Character.Humanoid.CameraOffset:Lerp(newOffset,trailAlpha)
end

local function getDoublePoints()
	local leftPosList = {}
	local rightPosList = {}

	for _, part in pairs(getPartsInfrontOfCamera()) do
		if part.Size.X > 300 or part.Size.Z > 300 then continue end
		-- gets the closest screen point on the right half of the screen
		local closest = getClosestPoint(part)
		local screenPos, visible = Camera:WorldToScreenPoint(closest)
		if not visible then continue end
		if screenPos.X > Camera.ViewportSize.X / 2 then
			table.insert(rightPosList, {closest, screenPos})
		elseif screenPos.X < Camera.ViewportSize.X / 2 then
			table.insert(leftPosList, {closest, screenPos})
		end
	end

	-- sorts through each list and gets the closest position to the character
	local closestRight = Vector3.new(math.huge, math.huge, math.huge)
	local closestLeft = Vector3.new(math.huge, math.huge, math.huge)
	local closestRightScreen = nil
	local closestLeftScreen = nil

	for _, pos in pairs(rightPosList) do
		if (Character.HumanoidRootPart.Position - pos[1]).Magnitude < (Character.HumanoidRootPart.Position - closestRight).Magnitude then
			closestRight = pos[1]
			closestRightScreen = pos[2]
		end
	end

	for _, pos in pairs(leftPosList) do
		if (Character.HumanoidRootPart.Position - pos[1]).Magnitude < (Character.HumanoidRootPart.Position - closestLeft).Magnitude then
			closestLeft = pos[1]
			closestLeftScreen = pos[2]
		end
	end

	return closestLeftScreen, closestLeft, closestRightScreen, closestRight

end

local function getQuadruplePoints()
	local topLeftPosList = {}
	local topRightPosList = {}
	local bottomLeftPosList = {}
	local bottomRightPosList = {}

	for _, part in pairs(getPartsInfrontOfCamera()) do
		if part.Size.X > 300 or part.Size.Z > 300 then continue end
		-- gets the closest screen point on the right half of the screen
		local closest = getClosestPoint(part)
		local screenPos, visible = Camera:WorldToScreenPoint(closest)
		if not visible then continue end
		if screenPos.X > Camera.ViewportSize.X / 2 then
			if screenPos.Y > Camera.ViewportSize.Y / 2 then
				table.insert(topRightPosList, {closest, screenPos})
			else
				table.insert(bottomRightPosList, {closest, screenPos})
			end
		elseif screenPos.X < Camera.ViewportSize.X / 2 then
			if screenPos.Y > Camera.ViewportSize.Y / 2 then
				table.insert(topLeftPosList, {closest, screenPos})
			else
				table.insert(bottomLeftPosList, {closest, screenPos})
			end
		end
	end

	-- sorts through each list and gets the closest position to the character
	local closestTopLeft = Vector3.new(math.huge, math.huge, math.huge)
	local closestTopRight = Vector3.new(math.huge, math.huge, math.huge)
	local closestBottomLeft = Vector3.new(math.huge, math.huge, math.huge)
	local closestBottomRight = Vector3.new(math.huge, math.huge, math.huge)
	local closestTopLeftScreen = nil
	local closestTopRightScreen = nil
	local closestBottomLeftScreen = nil
	local closestBottomRightScreen = nil

	for _, pos in pairs(topLeftPosList) do
		if (Character.HumanoidRootPart.Position - pos[1]).Magnitude < (Character.HumanoidRootPart.Position - closestTopLeft).Magnitude then
			closestTopLeft = pos[1]
			closestTopLeftScreen = pos[2]
		end
	end

	for _, pos in pairs(topRightPosList) do
		if (Character.HumanoidRootPart.Position - pos[1]).Magnitude < (Character.HumanoidRootPart.Position - closestTopRight).Magnitude then
			closestTopRight = pos[1]
			closestTopRightScreen = pos[2]
		end
	end

	for _, pos in pairs(bottomLeftPosList) do
		if (Character.HumanoidRootPart.Position - pos[1]).Magnitude < (Character.HumanoidRootPart.Position - closestBottomLeft).Magnitude then
			closestBottomLeft = pos[1]
			closestBottomLeftScreen = pos[2]
		end
	end

	for _, pos in pairs(bottomRightPosList) do
		if (Character.HumanoidRootPart.Position - pos[1]).Magnitude < (Character.HumanoidRootPart.Position - closestBottomRight).Magnitude then
			closestBottomRight = pos[1]
			closestBottomRightScreen = pos[2]
		end
	end

	return closestTopLeftScreen, closestTopLeft, closestTopRightScreen, closestTopRight, closestBottomLeftScreen, closestBottomLeft, closestBottomRightScreen, closestBottomRight
end

local usePartPhysics = false
local currPhys = nil

local function partPhysicsRep(bool, vel)
	if bool then
		usePartPhysics = true
		-- uses a part to represent the physics of the character
		local part = Instance.new("Part")
		part.Name = "PartPhysics"
		part.Size = Vector3.new(1, 1, 1)
		part.Transparency = 1
		part.Velocity = vel
		part.CFrame = Character.HumanoidRootPart.CFrame
		part.CollisionGroup = "PhysGroup"
		part.Parent = workspace.Ignore
		currPhys = part

		local Heartbeat
		Heartbeat = RunService.Heartbeat:Connect(function()
			Character.HumanoidRootPart.CFrame = CFrame.new(part.Position, part.Position + Character.HumanoidRootPart.CFrame.LookVector)
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

local function updateState()
	-- if player raycast towards ground is less than 10 studs, then sets state to "ground"
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = {Character, workspace.Ignore}
	raycastParams.IgnoreWater = true
	local raycastResult = workspace:Raycast(Character.HumanoidRootPart.Position, Vector3.new(0, -10, 0), raycastParams)
	if raycastResult then
		if raycastResult.Position.Y - Character.HumanoidRootPart.Position.Y < 10 then
			partPhysicsRep(false)
		end
	else
		if not currPhys then
			partPhysicsRep(true, Character.HumanoidRootPart.Velocity)
		end
	end
end

local grapplePart1 = ReplicatedStorage.GrappleTemplate:Clone()
local grapplePart2 = ReplicatedStorage.GrappleTemplate:Clone()
local grapplePart3 = ReplicatedStorage.GrappleTemplate:Clone()
local grapplePart4 = ReplicatedStorage.GrappleTemplate:Clone()
grapplePart1.Parent = workspace.Ignore
grapplePart2.Parent = workspace.Ignore
grapplePart3.Parent = workspace.Ignore
grapplePart4.Parent = workspace.Ignore

local function updatePoints()
	if dead then return end
	local positions = getGrapplePosition()
	grappleRight = positions[1] or nil
	grappleLeft = positions[2] or nil
	grappleTopRight = positions[3] or nil
	grappleTopLeft = positions[4] or nil

	if grappleRight then
		grapplePart1.CFrame = CFrame.new(grappleRight)
		grapplePart1.Parent = workspace.Ignore
	else
		grapplePart1.Parent = nil
	end

	if grappleLeft then
		grapplePart2.CFrame = CFrame.new(grappleLeft)
		grapplePart2.Parent = workspace.Ignore
	else
		grapplePart2.Parent = nil
	end

	if grappleTopRight then
		grapplePart3.CFrame = CFrame.new(grappleTopRight)
		grapplePart3.Parent = workspace.Ignore
	else
		grapplePart3.Parent = nil
	end

	if grappleTopLeft then
		grapplePart4.CFrame = CFrame.new(grappleTopLeft)
		grapplePart4.Parent = workspace.Ignore
	else
		grapplePart4.Parent = nil
	end

end

local function updateEffects(dt)
	-- creates wind lines based on velocity for the player to go past
	local vel = Character.HumanoidRootPart.Velocity
	local mag = vel.Magnitude
	local dir = vel.Unit
	if mag < 120 then return end
	local windLine = ReplicatedStorage.WindLine:Clone()
	windLine.Parent = workspace.Ignore
	local randomVector = Vector3.new(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100)).Unit
	windLine.CFrame = CFrame.new(Character.HumanoidRootPart.Position + randomVector * 20, Character.HumanoidRootPart.Position + randomVector * 20 + dir) * CFrame.new(0, 0, -mag*dt*3)
	windLine.Size = Vector3.new(0.1, 0.1, mag / 8)
	windLine.Anchored = true
	windLine.CanCollide = false
	windLine.Transparency = 0.7
	windLine.Material = Enum.Material.Neon
	windLine.Color = Color3.fromRGB(255, 255, 255)
	windLine.Name = "WindLine"
	task.wait(0.1)
	windLine:Destroy()
end


local sliding = false
local slideAnim = loadedAnims["Slide"]

local function startSliding()
	if not sliding then
		sliding = true

		-- slides the player across the ground slowly decreasing their velocity
		local steppedConn
		bodyVelocity.MaxForce = Vector3.new(20000, 0, 20000)
		Character.Humanoid.JumpHeight = 30
		bodyVelocity.Velocity = Vector3.new(Character.HumanoidRootPart.Velocity.X, 0, Character.HumanoidRootPart.Velocity.Z)
		local playerVel = Character.HumanoidRootPart.Velocity
		steppedConn = RunService.Heartbeat:Connect(function(dt)
			playerVel = Character.HumanoidRootPart.Velocity
			local playerVelMag = Vector3.new(playerVel.X, 0, playerVel.Z).Magnitude

			local groundRay = workspace:Raycast(Character.HumanoidRootPart.Position, Vector3.new(0, -5, 0), rayParams)
			local velRay = workspace:Raycast(Character.HumanoidRootPart.Position, Vector3.new(playerVel.X, 0, playerVel.Z) * dt* 3, rayParams)
			if playerVelMag > 50 and groundRay and not velRay then
				bodyVelocity.Velocity = bodyVelocity.Velocity:Lerp(Vector3.new(0, 0, 0), 0.011)
			else
				slideAnim:Stop()
				steppedConn:Disconnect()
				sliding = false
				if lenOfDict(grapples) == 0 then
					bodyVelocity.MaxForce = Vector3.new(0, 0, 0)
				end
				Character.Humanoid.JumpHeight = 7.2
			end
		end)

		if Vector3.new(playerVel.X, 0, playerVel.Z).Magnitude > 50 then
			slideAnim:Play()
		end
	end
end


RunService.RenderStepped:Connect(function(dt)
	updateFOV()
	updateCursor()
	updatePoints()
	updateEffects(dt)
	if lenOfDict(grapples) == 0 then
		updateState()
	else
		partPhysicsRep(false)
	end
	updateCam()
	if doubleMode then
		local left, leftPos, right, rightPos = getDoublePoints()

		if right and rightPos then
			rightScreenPos = rightPos
		end
		if left and leftPos then
			leftScreenPos = leftPos
		end
	end
end)

Character.Humanoid.StateChanged:Connect(function(old, new)
	if new == Enum.HumanoidStateType.Landed and lenOfDict(grapples) == 0 then
		startSliding()
	end
end)
Character.Humanoid.Died:Connect(function()
	dead = true
	if grapplePart1 then
		grapplePart1:Destroy()
	end
	if grapplePart2 then
		grapplePart2:Destroy()
	end
	if grapplePart3 then
		grapplePart3:Destroy()
	end
	if grapplePart4 then
		grapplePart4:Destroy()
	end

end)
