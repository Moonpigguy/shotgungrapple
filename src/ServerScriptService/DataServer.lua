local Players = game.Players
local DatastoreService = game:GetService("DataStoreService"):GetDataStore("Kills")

local function onPlayerAdded(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local killsValue = Instance.new("IntValue")
	killsValue.Name = "Kills"
	killsValue.Parent = leaderstats

	local key = "Kills_" .. player.UserId

	local success, value = pcall(function()
		return DatastoreService:GetAsync(key)
	end)

	if success then
		killsValue.Value = value
	else
		warn("Error getting kills for player " .. player.Name .. ": " .. value)
	end

	killsValue.Changed:Connect(function(newValue)
		local success, value = pcall(function()
			return DatastoreService:SetAsync(key, newValue)
		end)

		if not success then
			warn("Error saving kills for player " .. player.Name .. ": " .. value)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)

local function onPlayerRemoving(player)
	local leaderstats = player:WaitForChild("leaderstats")
	local killsValue = leaderstats:WaitForChild("Kills")

	local key = "Kills_" .. player.UserId

	local success, value = pcall(function()
		return DatastoreService:SetAsync(key, killsValue.Value)
	end)

	if not success then
		warn("Error saving kills for player " .. player.Name .. ": " .. value)
	end
end

Players.PlayerRemoving:Connect(onPlayerRemoving)
