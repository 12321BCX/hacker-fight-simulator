--[[
Hacker Fight Simulator - One-Time Installer
Paste this into Roblox Studio Command Bar and run it once.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local function EnsureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function EnsureRemote(parent, name)
	local remote = parent:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = parent
	end
	return remote
end

local function EnsureModule(parent, name, source)
	local module = parent:FindFirstChild(name)
	if not module then
		module = Instance.new("ModuleScript")
		module.Name = name
		module.Source = source
		module.Parent = parent
	end
	return module
end

local function EnsureScript(parent, name, source)
	local script = parent:FindFirstChild(name)
	if not script then
		script = Instance.new("Script")
		script.Name = name
		script.Source = source
		script.Parent = parent
	end
	return script
end

local function EnsureLocalScript(parent, name, source)
	local script = parent:FindFirstChild(name)
	if not script then
		script = Instance.new("LocalScript")
		script.Name = name
		script.Source = source
		script.Parent = parent
	end
	return script
end

local hackerRoot = EnsureFolder(ReplicatedStorage, "HackerFight")
local modulesFolder = EnsureFolder(hackerRoot, "Modules")
local remotesFolder = EnsureFolder(hackerRoot, "Remotes")

for _, name in ipairs({
	"RequestAction",
	"CombatRequest",
	"TeleportRequest",
	"SettingsRequest",
	"Notify",
	"StateSync"
}) do
	EnsureRemote(remotesFolder, name)
end

local configSource = [[
local Config = {}

Config.MaxReach = 18
Config.MaxDamage = 40
Config.GodModeDuration = 6
Config.TeleportCooldown = 2.5
Config.DashCooldown = 1.4
Config.ShieldDuration = 6
Config.HealCooldown = 10
Config.InvisibilityDuration = 6
Config.DefaultSpeed = 16
Config.DefaultJump = 50
Config.DefaultFlySpeed = 30

return Config
]]

EnsureModule(modulesFolder, "Config", configSource)

local serverSource = [[
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

local function doTeleport(player, destination)
	local root = getRootPart(player)
	if not root then
		return false
	end
	root.CFrame = CFrame.new(destination)
	return true
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
			local target = root.Position + (dir.Unit * 18)
			doTeleport(player, target)
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
]]

EnsureScript(ServerScriptService, "HackerFightServer", serverSource)

local clientSource = [[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local rootFolder = ReplicatedStorage:WaitForChild("HackerFight")
local remotes = rootFolder:WaitForChild("Remotes")

local request = remotes:WaitForChild("RequestAction")
local notify = remotes:WaitForChild("Notify")
local stateSync = remotes:WaitForChild("StateSync")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HackerFightGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 760, 0, 510)
main.Position = UDim2.new(0.5, -380, 0.5, -255)
main.BackgroundColor3 = Color3.fromRGB(18, 21, 25)
main.BorderSizePixel = 0
main.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = main

local uiStroke = Instance.new("UIStroke")
uiStroke.Color = Color3.fromRGB(0, 255, 160)
uiStroke.Transparency = 0.35
uiStroke.Thickness = 1
uiStroke.Parent = main

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = Color3.fromRGB(24, 28, 32)
header.BorderSizePixel = 0
header.Parent = main

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0, 260, 1, 0)
title.Position = UDim2.new(0, 14, 0, 0)
title.Text = "Hacker Fight Simulator"
title.TextColor3 = Color3.fromRGB(0, 255, 140)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 28, 0, 28)
closeButton.Position = UDim2.new(1, -36, 0.5, -14)
closeButton.Text = "X"
closeButton.BackgroundColor3 = Color3.fromRGB(42, 48, 54)
closeButton.TextColor3 = Color3.fromRGB(255,255,255)
closeButton.Parent = header
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton
closeButton.MouseButton1Click:Connect(function()
	main.Visible = false
end)

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 170, 1, -44)
sidebar.Position = UDim2.new(0, 0, 0, 44)
sidebar.BackgroundColor3 = Color3.fromRGB(20, 24, 28)
sidebar.BorderSizePixel = 0
sidebar.Parent = main

local tabs = {}
local sectionFrames = {}

local tabOrder = {"Player", "Combat", "Movement", "Teleport", "Visuals", "Settings", "Misc"}

local function createTabButton(name)
	local button = Instance.new("TextButton")
	button.Text = name
	button.Size = UDim2.new(1, -20, 0, 30)
	button.Position = UDim2.new(0, 10, 0, (#tabs * 36) + 12)
	button.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
	button TextColor3 = Color3.fromRGB(255,255,255)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.BorderSizePixel = 0
	button.Parent = sidebar
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(40, 48, 54)}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(30, 35, 40)}):Play()
	end)
	button.MouseButton1Click:Connect(function()
		for _, btn in ipairs(tabs) do
			btn.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
		end
		button.BackgroundColor3 = Color3.fromRGB(42, 52, 60)
		for secName, sec in pairs(sectionFrames) do
			sec.Visible = (secName == name)
		end
	end)
	table.insert(tabs, button)
	return button
end

local function createSection(name)
	local frame = Instance.new("ScrollingFrame")
	frame.Name = name
	frame.Size = UDim2.new(1, -170, 1, -44)
	frame.Position = UDim2.new(0, 170, 0, 44)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 6
	frame.Visible = (name == "Movement")
	frame.Parent = main
	frame.CanvasSize = UDim2.new(0, 0, 0, 900)
	sectionFrames[name] = frame
	return frame
end

for _, tabName in ipairs(tabOrder) do
	createTabButton(tabName)
	createSection(tabName)
end

local function addToggle(section, labelText, y, callback)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 230, 0, 30)
	button.Position = UDim2.new(0, 18, 0, y)
	button.Text = labelText .. "  OFF"
	button.BackgroundColor3 = Color3.fromRGB(32, 38, 42)
	button.TextColor3 = Color3.fromRGB(230, 230, 230)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.BorderSizePixel = 0
	button.Parent = section
	button.MouseButton1Click:Connect(function()
		if callback then
			callback()
		end
	end)
	return button
end

local function addActionButton(section, labelText, y, callback)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 200, 0, 30)
	button.Position = UDim2.new(0, 18, 0, y)
	button.Text = labelText
	button.TextColor3 = Color3.fromRGB(255,255,255)
	button.BackgroundColor3 = Color3.fromRGB(28, 35, 40)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.BorderSizePixel = 0
	button.Parent = section
	button.MouseButton1Click:Connect(function()
		if callback then
			callback()
		end
	end)
	return button
end

local function addSlider(section, labelText, y, key, startValue)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 130, 0, 20)
	label.Position = UDim2.new(0, 18, 0, y)
	label.Text = labelText
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(220,220,220)
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = 12
	label.Parent = section

	local valueButton = Instance.new("TextButton")
	valueButton.Size = UDim2.new(0, 110, 0, 22)
	valueButton.Position = UDim2.new(0, 160, 0, y)
	valueButton.Text = tostring(startValue)
	valueButton.BackgroundColor3 = Color3.fromRGB(38, 45, 49)
	valueButton.TextColor3 = Color3.fromRGB(255,255,255)
	valueButton.Font = Enum.Font.GothamBold
	valueButton.TextSize = 12
	valueButton.BorderSizePixel = 0
	valueButton.Parent = section
	valueButton.MouseButton1Click:Connect(function()
		request:FireServer("setValue", { key = key, value = (tonumber(valueButton.Text) or startValue) + 1 })
		valueButton.Text = tostring((tonumber(valueButton.Text) or startValue) + 1)
	end)
	return label, valueButton
end

local movementSection = sectionFrames["Movement"]
local combatSection = sectionFrames["Combat"]
local teleportSection = sectionFrames["Teleport"]
local visualsSection = sectionFrames["Visuals"]
local settingsSection = sectionFrames["Settings"]
local miscSection = sectionFrames["Misc"]
local playerSection = sectionFrames["Player"]

local y = 20
addToggle(movementSection, "Fly", y, function() request:FireServer("toggle", { name = "Fly" }) end)
y += 40
addToggle(movementSection, "TP Walk", y, function() request:FireServer("toggle", { name = "TPWalk" }) end)
y += 40
addToggle(movementSection, "Noclip", y, function() request:FireServer("toggle", { name = "Noclip" }) end)
y += 40
addToggle(movementSection, "Dash", y, function() request:FireServer("dash") end)
y += 40
addToggle(movementSection, "Speed Hack", y, function() request:FireServer("toggle", { name = "SpeedHack" }) end)
y += 40
addToggle(movementSection, "Infinite Jump", y, function() request:FireServer("toggle", { name = "InfiniteJump" }) end)
y += 40
addSlider(movementSection, "Speed", y, "SpeedHack", 16)
y += 40
addSlider(movementSection, "Jump", y, "JumpPower", 50)
y += 40
addSlider(movementSection, "Fly Speed", y, "FlySpeed", 30)

y = 20
addToggle(combatSection, "Kill Aura", y, function() request:FireServer("toggle", { name = "KillAura" }) end)
y += 40
addToggle(combatSection, "Combat Toggle", y, function() request:FireServer("toggle", { name = "CombatToggle" }) end)
y += 40
addToggle(combatSection, "Auto Attack", y, function() request:FireServer("toggle", { name = "AutoAttack" }) end)
y += 40
addActionButton(combatSection, "Attack Nearby Target", y, function()
	local target = Players:GetPlayers()[1]
	if target then
		request:FireServer("toggle", { name = "KillAura" })
		local targetName = target.Name
		local dmg = 1
		remotes:WaitForChild("CombatRequest"):FireServer(targetName, dmg)
	end
end)
y += 40
addSlider(combatSection, "Reach", y, "Reach", 18)
y += 40
addSlider(combatSection, "Damage Multiplier", y, "DamageMultiplier", 1)

y = 20
addActionButton(teleportSection, "Teleport to Spawn", y, function()
	remotes:WaitForChild("TeleportRequest"):FireServer("ToSpawn")
end)
y += 40
addActionButton(teleportSection, "Teleport to Random Player", y, function()
	local players = Players:GetPlayers()
	local target = players[2] or players[1]
	if target then
		remotes:WaitForChild("TeleportRequest"):FireServer("ToPlayer", target.Name)
	end
end)
y += 40
addToggle(teleportSection, "Safe Teleport", y, function() request:FireServer("toggle", { name = "SafeTeleport" }) end)
y += 40
addActionButton(teleportSection, "Save Waypoint", y, function() request:FireServer("toggle", { name = "SaveWaypoint" }) end)

y = 20
addToggle(visualsSection, "Player ESP", y, function() request:FireServer("toggle", { name = "ESP" }) end)
y += 40
addToggle(visualsSection, "Name ESP", y, function() request:FireServer("toggle", { name = "NameESP" }) end)
y += 40
addToggle(visualsSection, "Distance ESP", y, function() request:FireServer("toggle", { name = "DistanceESP" }) end)
y += 40
addToggle(visualsSection, "Health ESP", y, function() request:FireServer("toggle", { name = "HealthESP" }) end)

y = 20
addActionButton(settingsSection, "Save Settings", y, function() remotes:WaitForChild("SettingsRequest"):FireServer("save") end)
y += 40
addActionButton(settingsSection, "Reset Settings", y, function() remotes:WaitForChild("SettingsRequest"):FireServer("reset") end)
y += 40
addSlider(settingsSection, "UI Scale", y, "UIScale", 1)

y = 20
addToggle(miscSection, "Kill Feed", y, function() request:FireServer("toggle", { name = "KillFeed" }) end)
y += 40
addToggle(miscSection, "Crosshair", y, function() request:FireServer("toggle", { name = "Crosshair" }) end)
y += 40
addToggle(miscSection, "Performance Mode", y, function() request:FireServer("toggle", { name = "PerformanceMode" }) end)

y = 20
addActionButton(playerSection, "Toggle UI", y, function()
	main.Visible = not main.Visible
end)
y += 40
addActionButton(playerSection, "Refresh Player List", y, function()
	print("Player list refreshed")
end)

stateSync.OnClientEvent:Connect(function(key, value)
	if key == "FlyEnabled" and value == false then
		-- client side acknowledgement
	end
end)

notify.OnClientEvent:Connect(function(message)
	local popup = Instance.new("TextLabel")
	popup.Size = UDim2.new(0, 220, 0, 30)
	popup.Position = UDim2.new(0.5, -110, 0, 12)
	popup.Text = tostring(message)
	popup.BackgroundColor3 = Color3.fromRGB(12, 16, 20)
	popup.TextColor3 = Color3.fromRGB(0, 255, 140)
	popup.BorderSizePixel = 0
	popup.Font = Enum.Font.GothamBold
	popup.TextSize = 12
	popup.Parent = screenGui
	local popupCorner = Instance.new("UICorner")
popupCorner.CornerRadius = UDim.new(0, 8)
popupCorner.Parent = popup
	local popupStroke = Instance.new("UIStroke")
popupStroke.Color = Color3.fromRGB(0, 255, 140)
popupStroke.Transparency = 0.3
	popupStroke.Parent = popup
	task.delay(1.8, function()
		if popup and popup.Parent then
			popup:Destroy()
		end
	end)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		main.Visible = not main.Visible
	end
end)

print("Hacker Fight Simulator client started.")
]]

EnsureLocalScript(StarterPlayer:WaitForChild("StarterPlayerScripts"), "HackerFightClient", clientSource)

print("Installer complete. Roblox project structure was generated.")
