local replicatedStorage = game:GetService("ReplicatedStorage")

replicatedStorage.GunEvent.OnServerEvent:Connect(function(player, funcType, ...)
	local args = {...}	
	if funcType == "Damage" then
		local humanoid = args[1]

		if humanoid.Health <= 0 then return end

		local damage = args[2]
		humanoid:TakeDamage(damage)
		if humanoid.Health <= 0 then
			player.leaderstats.Kills.Value = player.leaderstats.Kills.Value + 1
			replicatedStorage.ReplicateEffect:FireClient(player, "KillConfirm", player, "Killed "..humanoid.Parent.Name.. " (" .. tostring(math.floor((humanoid.Parent.Head.Position - player.Character.Head.Position).Magnitude)) .. " studs"..")")


			local newSound = game.ReplicatedStorage.Sounds.DeathSounds:GetChildren()[math.random(1, #game.ReplicatedStorage.Sounds.DeathSounds:GetChildren())]:Clone()
			newSound.Parent = humanoid.Parent.Head
			newSound:Play()

			player.Character.Humanoid.Health = player.Character.Humanoid.Health + 15
		end
	end
end)
