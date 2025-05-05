local function fireOtherClients(player, remote, ...)
	for i,v in pairs(game.Players:GetPlayers()) do
		if v ~= player then
			remote:FireClient(v, ...)
		end
	end
end

game.ReplicatedStorage.ReplicateEffect.OnServerEvent:Connect(function(player, effect, ...)
	fireOtherClients(player, game.ReplicatedStorage.ReplicateEffect, effect, player, ...)
end)
