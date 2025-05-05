local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local function makeBullet(player, startCF, velocity)
	local newBullet = ReplicatedStorage.bullet:Clone()
	newBullet.CFrame = startCF
	newBullet.Parent = workspace.Ignore
	local runConn
	local startTime = tick()
	runConn = RunService.Heartbeat:Connect(function(dt)
		if tick() - startTime > 3 then
			newBullet:Destroy()
			runConn:Disconnect()
			return
		end
		local ray = Ray.new(newBullet.Position, velocity * dt)
		local ignore = {workspace.Ignore}
		if player then
			table.insert(ignore, player.Character)
		end
		local hit, pos, normal = workspace:FindPartOnRayWithIgnoreList(ray, ignore)

		if hit then
			-- creates bullet hit particles
			newBullet:Destroy()
			runConn:Disconnect()
			local newParticle = ReplicatedStorage.BulletHole:Clone()
			local weldConstraint = Instance.new("WeldConstraint")
			weldConstraint.Part0 = hit
			weldConstraint.Part1 = newParticle
			weldConstraint.Parent = newParticle
			local sparkParticle = newParticle.Sparks
			newParticle.CFrame = CFrame.new(pos, pos + normal)
			newParticle.Parent = workspace.Ignore
			sparkParticle:Emit(10)
			Debris:AddItem(newParticle, 3)
			return
		end
		newBullet.CFrame = CFrame.new(newBullet.Position + velocity * dt, newBullet.Position + velocity) * CFrame.Angles(0, math.rad(90), 0)
	end)
end

ReplicatedStorage.ReplicateEffect.OnClientEvent:Connect(function(effect, player, ...)
	local args = {...}
	if effect == "Rope" then
		local startPart = args[1]
		local endPos = args[2]
		local hitPart = args[3]
		if startPart:FindFirstChild("Beam") then
			local grapple = Instance.new("Part")
			grapple.Size = Vector3.new(0.2, 0.2, 0.2)
			grapple.Anchored = false
			grapple.CanCollide = false
			grapple.Transparency = 0.5
			grapple.Position = endPos
			grapple.Name = startPart.Name
			grapple.Parent = workspace.Ignore

			local grappleWeld = Instance.new("WeldConstraint")
			grappleWeld.Part0 = grapple
			grappleWeld.Part1 = hitPart
			grappleWeld.Parent = grapple

			local newAttachment = Instance.new("Attachment")
			newAttachment.Parent = grapple
			startPart.Beam.Attachment1 = newAttachment
		end
	elseif effect == "DestroyRope" then
		local startPart = args[1]
		if workspace.Ignore:FindFirstChild(startPart.Name) then
			workspace.Ignore:FindFirstChild(startPart.Name):Destroy()
		end
	elseif effect == "Sound" then
		local sound = args[1]:Clone()
		local putPart = args[2]
		sound.Parent = putPart
		sound:Play()
		Debris:AddItem(sound, sound.TimeLength + 3)
	elseif effect == "GunArms" then
		local mousePos = args[1]
		local targetChar = player.Character
		local torso = targetChar.Torso
		
		local fakeArms = targetChar["Fake Arms"]
		local rightArm = fakeArms:WaitForChild("Right Arm")
		local leftArm = fakeArms:WaitForChild("Left Arm")
		
		local rightArmPos = (torso.CFrame * CFrame.new(1.5, 0.5, 0)).Position
		local rightArmCFrame = CFrame.new(rightArmPos, mousePos) * CFrame.new(0, 0, -1) * CFrame.Angles(math.rad(90), 0, 0)
		rightArm.ArmWeld.C1 = rightArmCFrame:inverse() * CFrame.new(0, 0, 0)
		rightArm.ArmWeld.C0 = torso.CFrame:inverse() * CFrame.new(0, 0, 0)
		
		local leftArmPos = (torso.CFrame * CFrame.new(-1.5, 0.5, 0)).Position
		local leftArmCFrame = CFrame.new(leftArmPos, mousePos) * CFrame.new(0, 0, -1) * CFrame.Angles(math.rad(90), 0, 0)
		leftArm.ArmWeld.C1 = leftArmCFrame:inverse() * CFrame.new(0, 0, 0)
		leftArm.ArmWeld.C0 = torso.CFrame:inverse() * CFrame.new(0, 0, 0)
	elseif effect == "PlaySound" then
		local sound = args[1]
		local pitch = args[2]
		sound.Pitch = pitch
		sound:Play()
	elseif effect == "RepBullet" then
		local startCF = args[1]
		local velocity = args[2]
		if typeof(velocity) == "table" then
			for _,v in pairs(velocity) do
				makeBullet(nil, v[1], v[2])
			end
		else
			makeBullet(nil, startCF, velocity)
		end
	elseif effect == "KillConfirm" then
		local text = args[1]
		local newText = ReplicatedStorage.KillsText:Clone()
		newText.Text = text
		newText.Parent = game.Players.LocalPlayer.PlayerGui:WaitForChild("KillsGui").Frame
		
		newText.Position = UDim2.new(0.5, 0, 0.5, -50)
		newText.TextTransparency = 1
		newText.Visible = true
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
		local tween = game:GetService("TweenService"):Create(newText, tweenInfo, {TextTransparency = 0})
		tween:Play()
		tween.Completed:Connect(function()
			task.wait(5)
			local tween = game:GetService("TweenService"):Create(newText, TweenInfo.new(2), {TextTransparency = 1})
			tween:Play()
			newText:Destroy() 
		end)
	end 
end)
