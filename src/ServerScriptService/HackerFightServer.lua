local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local root = ReplicatedStorage:WaitForChild("HackerFight")
local remotes = root:WaitForChild("Remotes")
local config = require(root:WaitForChild("Modules"):WaitForChild("Config"))

local request = remotes:WaitForChild("RequestAction")
local combat = remotes:WaitForChild("CombatRequest")
local teleport = remotes:WaitForChild("TeleportRequest")
local settings = remotes:WaitForChild("SettingsRequest")
local notify = remotes:WaitForChild("Notify")
local stateSync = remotes:WaitForChild("StateSync")

local playerState = {}
local cooldowns = {}

local function getCharacter(player)
	return player.Character
end

local function getHumanoid(player)
	local char = getCharacter(player)
	if not char then
		return nil
	end
	return char:FindFirstChildOfClass("Humanoid")
end

local function getRootPart(player)
	local char = getCharacter(player)
	if not char then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("RootPart")
end

local function getPlayerState(player)
	playerState[player] = playerState[player] or {
		FlyEnabled = false,
		KillAuraEnabled = false,
		TPWalkEnabled = false,
		NoclipEnabled = false,
		SpeedHackEnabled = false,
		GodModeEnabled = false,
		ESPEnabled = false,
		CurrentSpeed = config.DefaultSpeed,
		CurrentJump = config.DefaultJump,
		CurrentFly = config.DefaultFlySpeed,
	}
	return playerState[player]
end

local function setState(player, key, value)
	local state = getPlayerState(player)
	state[key] = value
	stateSync:FireClient(player, key, value)
end

local function checkCooldown(player, key, duration)
	cooldowns[player] = cooldowns[player] or {}
	local now = os.clock()
	local finish = cooldowns[player][key] or 0
	if now < finish then
		return false, finish - now
	end
	cooldowns[player][key] = now + duration
	return true, 0
end

local function applyHumanoidStats(player)
	local hum = getHumanoid(player)
	if not hum then
		return
	end
	local state = getPlayerState(player)
	hum.WalkSpeed = state.CurrentSpeed or config.DefaultSpeed
	hum.JumpPower = state.CurrentJump or config.DefaultJump
end

local function setFly(player, enabled)
	local root = getRootPart(player)
	if not root then
		return
	end
	local bv = root:FindFirstChild("HackerFlightVelocity")
	if enabled then
		if not bv then
			bv = Instance.new("BodyVelocity")
			bv.Name = "HackerFlightVelocity"
			bv.MaxForce = Vector3.new(40000, 40000, 40000)
			bv.Parent = root
		end
		bv.Velocity = Vector3.zero
	else
		if bv then
			bv:Destroy()
		end
	end
	setState(player, "FlyEnabled", enabled)
end

local function setNoclip(player, enabled)
	local char = getCharacter(player)
	if not char then
		return
	end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = not enabled
		end
	end
	setState(player, "NoclipEnabled", enabled)
end

local function setGodMode(player, enabled)
	local char = getCharacter(player)
	if not char then
		return
	end
	local hum = getHumanoid(player)
	if not hum then
		return
	end
	if enabled then
		char:SetAttribute("GodMode", true)
		hum.MaxHealth = math.huge
		hum.Health = hum.MaxHealth
		setState(player, "GodModeEnabled", true)
		notify:FireClient(player, "God Mode Enabled")
		task.delay(config.GodModeDuration, function()
			if player and player.Parent and char.Parent then
				char:SetAttribute("GodMode", false)
				hum.MaxHealth = 100
				hum.Health = math.clamp(hum.Health, 0, 100)
				setState(player, "GodModeEnabled", false)
			end
		end)
	else
		char:SetAttribute("GodMode", false)
		hum.MaxHealth = 100
		if hum.Health > 100 then
			hum.Health = 100
		end
		setState(player, "GodModeEnabled", false)
	end
end

local function handleAction(player, action, payload)
	if action == "toggle" then
		local state = getPlayerState(player)
		local name = payload and payload.name or ""
		if name == "Fly" then
			state.FlyEnabled = not state.FlyEnabled
			setFly(player, state.FlyEnabled)
		elseif name == "Noclip" then
			state.NoclipEnabled = not state.NoclipEnabled
			setNoclip(player, state.NoclipEnabled)
		elseif name == "GodMode" then
			setGodMode(player, not state.GodModeEnabled)
		elseif name == "KillAura" then
			state.KillAuraEnabled = not state.KillAuraEnabled
			setState(player, "KillAuraEnabled", state.KillAuraEnabled)
		elseif name == "SpeedHack" then
			state.SpeedHackEnabled = not state.SpeedHackEnabled
			state.CurrentSpeed = state.SpeedHackEnabled and 40 or config.DefaultSpeed
			applyHumanoidStats(player)
			setState(player, "SpeedHackEnabled", state.SpeedHackEnabled)
		elseif name == "TPWalk" then
			state.TPWalkEnabled = not state.TPWalkEnabled
			setState(player, "TPWalkEnabled", state.TPWalkEnabled)
		elseif name == "ESP" then
			state.ESPEnabled = not state.ESPEnabled
			setState(player, "ESPEnabled", state.ESPEnabled)
		end
	elseif action == "setValue" then
		local state = getPlayerState(player)
		local key = payload and payload.key
		local value = payload and payload.value
		if key == "SpeedHack" then
			state.CurrentSpeed = tonumber(value) or config.DefaultSpeed
			applyHumanoidStats(player)
		elseif key == "JumpPower" then
			state.CurrentJump = tonumber(value) or config.DefaultJump
			applyHumanoidStats(player)
		elseif key == "FlySpeed" then
			state.CurrentFly = tonumber(value) or config.DefaultFlySpeed
		end
		setState(player, key, value)
	elseif action == "dash" then
		local ok = checkCooldown(player, "dash", config.DashCooldown)
		if not ok then
			notify:FireClient(player, "Dash is cooling down")
			return
		end
		local root = getRootPart(player)
		local hum = getHumanoid(player)
		if root and hum then
			local dir = hum.MoveDirection
			if dir.Magnitude < 0.001 then
				dir = Vector3.new(0, 0, -1)
			end
			root.CFrame = root.CFrame + CFrame.new((dir.Unit * 18)).Position
		end
		notify:FireClient(player, "Dash used")
	elseif action == "heal" then
		local ok = checkCooldown(player, "heal", config.HealCooldown)
		if not ok then
			notify:FireClient(player, "Heal is cooling down")
			return
		end
		local hum = getHumanoid(player)
		if hum then
			hum.Health = math.min(hum.MaxHealth, hum.Health + 30)
		end
	elseif action == "shield" then
		local ok = checkCooldown(player, "shield", 8)
		if not ok then
			notify:FireClient(player, "Shield is cooling down")
			return
		end
		local char = getCharacter(player)
		if char then
			char:SetAttribute("ShieldActive", true)
			task.delay(config.ShieldDuration, function()
				if char and char.Parent then
					char:SetAttribute("ShieldActive", false)
				end
			end)
		end
	elseif action == "invisibility" then
		local ok = checkCooldown(player, "invisibility", 12)
		if not ok then
			notify:FireClient(player, "Invisibility is cooling down")
			return
		end
		local char = getCharacter(player)
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = 0.7
				end
			end
			task.delay(config.InvisibilityDuration, function()
				if char and char.Parent then
					for _, part in ipairs(char:GetDescendants()) do
						if part:IsA("BasePart") then
							part.Transparency = 0
						end
					end
				end
			end)
		end
	elseif action == "tp" then
		local ok = checkCooldown(player, "teleport", config.TeleportCooldown)
		if not ok then
			notify:FireClient(player, "Teleport is cooling down")
			return
		end
		local kind = payload and payload.kind or "Spawn"
		if kind == "Player" then
			local targetName = payload and payload.target or ""
			local target = Players:FindFirstChild(targetName)
			if target and target ~= player then
				local targetRoot = getRootPart(target)
				local meRoot = getRootPart(player)
				if targetRoot and meRoot then
					meRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 3, 0)
				end
			end
		else
			local spawn = workspace:FindFirstChild("SpawnLocation")
			if spawn then
				local root = getRootPart(player)
				if root then
					root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
				end
			end
		end
	end
end

request.OnServerEvent:Connect(function(player, action, payload)
	pcall(handleAction, player, action, payload)
end)

combat.OnServerEvent:Connect(function(player, targetName, damageMultiplier)
	local target = Players:FindFirstChild(targetName)
	if not target or target == player then
		return
	end
	local playerRoot = getRootPart(player)
	local targetRoot = getRootPart(target)
	if not playerRoot or not targetRoot then
		return
	end
	local distance = (playerRoot.Position - targetRoot.Position).Magnitude
	if distance > config.MaxReach then
		notify:FireClient(player, "Target is out of range")
		return
	end
	local ok = checkCooldown(player, "attack", 0.6)
	if not ok then
		notify:FireClient(player, "Attack cooldown active")
		return
	end
	local targetHum = getHumanoid(target)
	if targetHum and targetHum.Parent and targetHum.Parent:GetAttribute("GodMode") then
		notify:FireClient(player, "Target is protected")
		return
	end
	local dmg = config.MaxDamage * (tonumber(damageMultiplier) or 1)
	if targetHum then
		targetHum:TakeDamage(dmg)
	end
end)

teleport.OnServerEvent:Connect(function(player, kind, targetName)
	if kind == "ToPlayer" then
		local target = Players:FindFirstChild(targetName)
		if target and target ~= player then
			local targetRoot = getRootPart(target)
			local playerRoot = getRootPart(player)
			if targetRoot and playerRoot then
				playerRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 3, 0)
			end
		end
	elseif kind == "ToSpawn" then
		local spawn = workspace:FindFirstChild("SpawnLocation")
		if spawn then
			local root = getRootPart(player)
			if root then
				root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
			end
		end
	end
end)

settings.OnServerEvent:Connect(function(player, key, value)
	if key then
		local state = getPlayerState(player)
		state[key] = value
	end
end)

local function onCharacterAdded(player, character)
	local hum = character:WaitForChild("Humanoid")
	local state = getPlayerState(player)
	hum.WalkSpeed = state.CurrentSpeed or config.DefaultSpeed
	hum.JumpPower = state.CurrentJump or config.DefaultJump

	if state.FlyEnabled then
		setFly(player, true)
	end
end

Players.PlayerAdded:Connect(function(player)
	playerState[player] = {
		FlyEnabled = false,
		KillAuraEnabled = false,
		TPWalkEnabled = false,
		NoclipEnabled = false,
		SpeedHackEnabled = false,
		GodModeEnabled = false,
		ESPEnabled = false,
		CurrentSpeed = config.DefaultSpeed,
		CurrentJump = config.DefaultJump,
		CurrentFly = config.DefaultFlySpeed,
	}
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

RunService.RenderStepped:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local state = getPlayerState(player)
		local root = getRootPart(player)
		if root and state.FlyEnabled then
			local bv = root:FindFirstChild("HackerFlightVelocity")
			if bv then
				local hum = getHumanoid(player)
				if hum then
					local move = hum.MoveDirection * (state.CurrentFly or config.DefaultFlySpeed)
					bv.Velocity = Vector3.new(move.X, 0, move.Z)
				end
			end
		end
	end
end)

print("Hacker Fight Simulator server started.")
