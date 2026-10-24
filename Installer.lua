--[[
Hacker Fight Simulator
Single-file installer for Roblox Studio.
Paste this into the Command Bar and run it once.
This script creates the project automatically.
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
local remotesFolder = EnsureFolder(hackerRoot, "Remotes")

for _, name in ipairs({
	"RequestAction",
	"CombatRequest",
	"TeleportRequest",
	"SettingsRequest",
	"Notify",
	"StateSync",
}) do
	EnsureRemote(remotesFolder, name)
end

local serverSource = [[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local rootFolder = ReplicatedStorage:WaitForChild("HackerFight")
local remotes = rootFolder:WaitForChild("Remotes")

local request = remotes:WaitForChild("RequestAction")
local combatRequest = remotes:WaitForChild("CombatRequest")
local teleportRequest = remotes:WaitForChild("TeleportRequest")
local settingsRequest = remotes:WaitForChild("SettingsRequest")
local notify = remotes:WaitForChild("Notify")
local stateSync = remotes:WaitForChild("StateSync")

local config = {
	MaxReach = 18,
	MaxDamage = 40,
	TeleportCooldown = 2.5,
	DashCooldown = 1.2,
	GodModeDuration = 6,
	TeleportToPlayerNotes = "Server-authoritative teleport",
	DefaultSpeed = 16,
	DefaultJump = 50,
	DefaultFlySpeed = 30,
}

local playerState = {}
local cooldowns = {}

local function getCharacter(player)
	return player.Character
end

local function getHumanoid(player)
	local character = getCharacter(player)
	if not character then return nil end
	return character:FindFirstChildOfClass("Humanoid")
end

local function getRootPart(player)
	local character = getCharacter(player)
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("RootPart")
end

local function ensureState(player)
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
	local state = ensureState(player)
	state[key] = value
	stateSync:FireClient(player, key, value)
end

local function applyStats(player)
	local humanoid = getHumanoid(player)
	if not humanoid then return end
	local state = ensureState(player)
	humanoid.WalkSpeed = state.CurrentSpeed or config.DefaultSpeed
	humanoid.JumpPower = state.CurrentJump or config.DefaultJump
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

local function setFly(player, enabled)
	local root = getRootPart(player)
	if not root then return end
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
		if bv then bv:Destroy() end
	end
	setState(player, "FlyEnabled", enabled)
end

local function setNoclip(player, enabled)
	local character = getCharacter(player)
	if not character then return end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = not enabled
		end
	end
	setState(player, "NoclipEnabled", enabled)
end

local function setGodMode(player, enabled)
	local character = getCharacter(player)
	if not character then return end
	local humanoid = getHumanoid(player)
	if not humanoid then return end
	if enabled then
		character:SetAttribute("GodMode", true)
		humanoid.MaxHealth = math.huge
		humanoid.Health = humanoid.MaxHealth
		setState(player, "GodModeEnabled", true)
		notify:FireClient(player, "God Mode enabled")
		task.delay(config.GodModeDuration, function()
			if player and player.Parent and character.Parent then
				character:SetAttribute("GodMode", false)
				humanoid.MaxHealth = 100
				humanoid.Health = math.clamp(humanoid.Health, 0, 100)
				setState(player, "GodModeEnabled", false)
			end
		end)
	else
		character:SetAttribute("GodMode", false)
		humanoid.MaxHealth = 100
		if humanoid.Health > 100 then humanoid.Health = 100 end
		setState(player, "GodModeEnabled", false)
	end
end

local function damageTarget(target, amount)
	if not target or not target.Parent then return false end
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end
	if target:GetAttribute("GodMode") then return false end
	humanoid:TakeDamage(amount)
	return true
end

local function handleAction(player, action, payload)
	if action == "toggle" then
		local state = ensureState(player)
		local name = payload and payload.name or ""
		if name == "Fly" then
			state.FlyEnabled = not state.FlyEnabled
			setFly(player, state.FlyEnabled)
		elseif name == "Noclip" then
			state.NoclipEnabled = not state.NoclipEnabled
			setNoclip(player, state.NoclipEnabled)
		elseif name == "KillAura" then
			state.KillAuraEnabled = not state.KillAuraEnabled
			setState(player, "KillAuraEnabled", state.KillAuraEnabled)
		elseif name == "SpeedHack" then
			state.SpeedHackEnabled = not state.SpeedHackEnabled
			state.CurrentSpeed = state.SpeedHackEnabled and 40 or config.DefaultSpeed
			applyStats(player)
		elseif name == "TPWalk" then
			state.TPWalkEnabled = not state.TPWalkEnabled
			setState(player, "TPWalkEnabled", state.TPWalkEnabled)
		elseif name == "ESP" then
			state.ESPEnabled = not state.ESPEnabled
			setState(player, "ESPEnabled", state.ESPEnabled)
		elseif name == "GodMode" then
			setGodMode(player, not state.GodModeEnabled)
		end
	elseif action == "setValue" then
		local state = ensureState(player)
		local key = payload and payload.key
		local value = payload and payload.value
		if key == "SpeedHack" then
			state.CurrentSpeed = tonumber(value) or config.DefaultSpeed
		elseif key == "JumpPower" then
			state.CurrentJump = tonumber(value) or config.DefaultJump
		elseif key == "FlySpeed" then
			state.CurrentFly = tonumber(value) or config.DefaultFlySpeed
		end
		applyStats(player)
		setState(player, key, value)
	elseif action == "dash" then
		local ok = checkCooldown(player, "dash", config.DashCooldown)
		if not ok then
			notify:FireClient(player, "Dash cooling down")
			return
		end
		local root = getRootPart(player)
		local humanoid = getHumanoid(player)
		if root and humanoid then
			local direction = humanoid.MoveDirection
			if direction.Magnitude < 0.001 then direction = Vector3.new(0, 0, -1) end
			root.CFrame = root.CFrame + CFrame.new(direction.Unit * 18).Position
		end
		notify:FireClient(player, "Dash used")
	elseif action == "heal" then
		local ok = checkCooldown(player, "heal", 10)
		if not ok then
			notify:FireClient(player, "Heal cooling down")
			return
		end
		local humanoid = getHumanoid(player)
		if humanoid then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 30)
		end
	elseif action == "tp" then
		local ok = checkCooldown(player, "teleport", config.TeleportCooldown)
		if not ok then
			notify:FireClient(player, "Teleport cooling down")
			return
		end
		local kind = payload and payload.kind or "Spawn"
		if kind == "Player" then
			local targetName = payload and payload.target or ""
			local target = Players:FindFirstChild(targetName)
			if target and target ~= player then
				local playerRoot = getRootPart(player)
				local targetRoot = getRootPart(target)
				if playerRoot and targetRoot then
					playerRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 3, 0)
				end
			end
		else
			local spawn = workspace:FindFirstChild("SpawnLocation")
			if spawn then
				local root = getRootPart(player)
				if root then root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0) end
			end
		end
	end
end

request.OnServerEvent:Connect(function(player, action, payload)
	pcall(handleAction, player, action, payload)
end)

combatRequest.OnServerEvent:Connect(function(player, targetName, damageMultiplier)
	local target = Players:FindFirstChild(targetName)
	if not target or target == player then return end
	local playerRoot = getRootPart(player)
	local targetRoot = getRootPart(target)
	if not playerRoot or not targetRoot then return end
	if (playerRoot.Position - targetRoot.Position).Magnitude > config.MaxReach then
		notify:FireClient(player, "Target out of range")
		return
	end
	local ok = checkCooldown(player, "attack", 0.6)
	if not ok then
		notify:FireClient(player, "Attack cooldown active")
		return
	end
	local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
	if targetHumanoid and targetHumanoid.Parent and targetHumanoid.Parent:GetAttribute("GodMode") then
		notify:FireClient(player, "Target is protected")
		return
	end
	local damage = config.MaxDamage * (tonumber(damageMultiplier) or 1)
	if targetHumanoid then damageTarget(targetHumanoid.Parent, damage) end
end)

teleportRequest.OnServerEvent:Connect(function(player, kind, targetName)
	if kind == "ToPlayer" then
		local target = Players:FindFirstChild(targetName)
		if target and target ~= player then
			local playerRoot = getRootPart(player)
			local targetRoot = getRootPart(target)
			if playerRoot and targetRoot then
				playerRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 3, 0)
			end
		end
	elseif kind == "ToSpawn" then
		local spawn = workspace:FindFirstChild("SpawnLocation")
		if spawn then
			local root = getRootPart(player)
			if root then root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0) end
		end
	end
end)

settingsRequest.OnServerEvent:Connect(function(player, key, value)
	if key then
		local state = ensureState(player)
		state[key] = value
	end
end)

local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid")
	local state = ensureState(player)
	humanoid.WalkSpeed = state.CurrentSpeed or config.DefaultSpeed
	humanoid.JumpPower = state.CurrentJump or config.DefaultJump
	if state.FlyEnabled then setFly(player, true) end
end

Players.PlayerAdded:Connect(function(player)
	ensureState(player)
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
		local state = ensureState(player)
		local root = getRootPart(player)
		if root and state.FlyEnabled then
			local bv = root:FindFirstChild("HackerFlightVelocity")
			if bv then
				local humanoid = getHumanoid(player)
				if humanoid then
					local move = humanoid.MoveDirection * (state.CurrentFly or config.DefaultFlySpeed)
					bv.Velocity = Vector3.new(move.X, 0, move.Z)
				end
			end
		end
	end
end)

print("Hacker Fight Simulator server started.")
]]

local clientSource = [[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("HackerFight"):WaitForChild("Remotes")

local request = remotes:WaitForChild("RequestAction")
local notify = remotes:WaitForChild("Notify")
local stateSync = remotes:WaitForChild("StateSync")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HackerFightGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 760, 0, 500)
main.Position = UDim2.new(0.5, -380, 0.5, -250)
main.BackgroundColor3 = Color3.fromRGB(18, 21, 25)
main.BorderSizePixel = 0
main.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(0, 255, 160)
mainStroke.Transparency = 0.35
mainStroke.Thickness = 1
mainStroke.Parent = main

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 42)
header.BackgroundColor3 = Color3.fromRGB(24, 28, 32)
header.BorderSizePixel = 0
header.Parent = main

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0, 260, 1, 0)
title.Position = UDim2.new(0, 16, 0, 0)
title.Text = "Hacker Fight Simulator"
title.TextColor3 = Color3.fromRGB(0, 255, 140)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -38, 0.5, -15)
closeButton.Text = "X"
closeButton.BackgroundColor3 = Color3.fromRGB(45, 48, 52)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 14
closeButton.BorderSizePixel = 0
closeButton.Parent = header
closeButton.MouseButton1Click:Connect(function()
	main.Visible = false
end)

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 170, 1, -42)
sidebar.Position = UDim2.new(0, 0, 0, 42)
sidebar.BackgroundColor3 = Color3.fromRGB(20, 24, 28)
sidebar.BorderSizePixel = 0
sidebar.Parent = main

local sections = {}
local tabs = {}
local order = {"Player", "Combat", "Movement", "Teleport", "Visuals", "Settings", "Misc"}

local function createTabButton(name)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -20, 0, 30)
	button.Position = UDim2.new(0, 10, 0, (#tabs * 36) + 12)
	button.Text = name
	button.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.BorderSizePixel = 0
	button.Parent = sidebar
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1), {
			BackgroundColor3 = Color3.fromRGB(40, 48, 54),
		}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1), {
			BackgroundColor3 = Color3.fromRGB(30, 35, 40),
		}):Play()
	end)
	button.MouseButton1Click:Connect(function()
		for _, tabButton in ipairs(tabs) do
			tabButton.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
		end
		button.BackgroundColor3 = Color3.fromRGB(42, 52, 60)
		for secName, sec in pairs(sections) do
			sec.Visible = (secName == name)
		end
	end)
	table.insert(tabs, button)
	return button
end

local function createSection(name)
	local section = Instance.new("ScrollingFrame")
	section.Name = name
	section.Size = UDim2.new(1, -170, 1, -42)
	section.Position = UDim2.new(0, 170, 0, 42)
	section.Visible = (name == "Movement")
	section.BackgroundTransparency = 1
	section.BorderSizePixel = 0
	section.ScrollBarThickness = 6
	section.CanvasSize = UDim2.new(0, 0, 0, 900)
	section.Parent = main
	sections[name] = section
	return section
end

for _, tabName in ipairs(order) do
	createTabButton(tabName)
	createSection(tabName)
end

local function addToggle(section, labelText, y, callback)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 220, 0, 30)
	button.Position = UDim2.new(0, 18, 0, y)
	button.Text = labelText .. "  OFF"
	button.BackgroundColor3 = Color3.fromRGB(32, 38, 42)
	button.TextColor3 = Color3.fromRGB(220, 220, 220)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.BorderSizePixel = 0
	button.Parent = section
	button.MouseButton1Click:Connect(function()
		if callback then callback() end
	end)
	return button
end

local function addActionButton(section, labelText, y, callback)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 180, 0, 30)
	button.Position = UDim2.new(0, 18, 0, y)
	button.Text = labelText
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.BackgroundColor3 = Color3.fromRGB(28, 35, 40)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.BorderSizePixel = 0
	button.Parent = section
	button.MouseButton1Click:Connect(function()
		if callback then callback() end
	end)
	return button
end

local function addSlider(section, labelText, y, key, startValue)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 120, 0, 20)
	label.Position = UDim2.new(0, 18, 0, y)
	label.Text = labelText
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(220, 220, 220)
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = 12
	label.Parent = section

	local valueButton = Instance.new("TextButton")
	valueButton.Size = UDim2.new(0, 110, 0, 22)
	valueButton.Position = UDim2.new(0, 158, 0, y)
	valueButton.Text = tostring(startValue)
	valueButton.BackgroundColor3 = Color3.fromRGB(38, 45, 49)
	valueButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	valueButton.Font = Enum.Font.GothamBold
	valueButton.TextSize = 12
	valueButton.BorderSizePixel = 0
	valueButton.Parent = section
	valueButton.MouseButton1Click:Connect(function()
		local nextValue = (tonumber(valueButton.Text) or startValue) + 1
		valueButton.Text = tostring(nextValue)
		request:FireServer("setValue", { key = key, value = nextValue })
	end)
	return label, valueButton
end

local movementSection = sections["Movement"]
local combatSection = sections["Combat"]
local teleportSection = sections["Teleport"]
local visualsSection = sections["Visuals"]
local settingsSection = sections["Settings"]
local miscSection = sections["Misc"]
local playerSection = sections["Player"]

local y = 20
addToggle(movementSection, "Fly", y, function() request:FireServer("toggle", { name = "Fly" }) end); y += 40
addToggle(movementSection, "TP Walk", y, function() request:FireServer("toggle", { name = "TPWalk" }) end); y += 40
addToggle(movementSection, "Noclip", y, function() request:FireServer("toggle", { name = "Noclip" }) end); y += 40
addToggle(movementSection, "Dash", y, function() request:FireServer("dash") end); y += 40
addToggle(movementSection, "Speed Hack", y, function() request:FireServer("toggle", { name = "SpeedHack" }) end); y += 40
addToggle(movementSection, "Infinite Jump", y, function() request:FireServer("toggle", { name = "InfiniteJump" }) end); y += 40
addSlider(movementSection, "Speed", y, "SpeedHack", 16); y += 40
addSlider(movementSection, "Jump", y, "JumpPower", 50); y += 40
addSlider(movementSection, "Fly Speed", y, "FlySpeed", 30)

y = 20
addToggle(combatSection, "Kill Aura", y, function() request:FireServer("toggle", { name = "KillAura" }) end); y += 40
addToggle(combatSection, "Combat Toggle", y, function() request:FireServer("toggle", { name = "CombatToggle" }) end); y += 40
addToggle(combatSection, "Auto Attack", y, function() request:FireServer("toggle", { name = "AutoAttack" }) end); y += 40
addActionButton(combatSection, "Attack Nearby", y, function()
	local target = Players:GetPlayers()[2] or Players:GetPlayers()[1]
	if target then remotes:WaitForChild("CombatRequest"):FireServer(target.Name, 1) end
end); y += 40
addSlider(combatSection, "Reach", y, "Reach", 18); y += 40
addSlider(combatSection, "Damage Multiplier", y, "DamageMultiplier", 1)

y = 20
addActionButton(teleportSection, "Teleport to Spawn", y, function() remotes:WaitForChild("TeleportRequest"):FireServer("ToSpawn") end); y += 40
addActionButton(teleportSection, "Teleport to Player", y, function()
	local target = Players:GetPlayers()[2] or Players:GetPlayers()[1]
	if target then remotes:WaitForChild("TeleportRequest"):FireServer("ToPlayer", target.Name) end
end); y += 40
addToggle(teleportSection, "Safe Teleport", y, function() request:FireServer("toggle", { name = "SafeTeleport" }) end)

y = 20
addToggle(visualsSection, "Player ESP", y, function() request:FireServer("toggle", { name = "ESP" }) end); y += 40
addToggle(visualsSection, "Name ESP", y, function() request:FireServer("toggle", { name = "NameESP" }) end); y += 40
addToggle(visualsSection, "Health ESP", y, function() request:FireServer("toggle", { name = "HealthESP" }) end)

y = 20
addActionButton(settingsSection, "Save Settings", y, function() remotes:WaitForChild("SettingsRequest"):FireServer("save") end); y += 40
addActionButton(settingsSection, "Reset Settings", y, function() remotes:WaitForChild("SettingsRequest"):FireServer("reset") end); y += 40
addSlider(settingsSection, "UI Scale", y, "UIScale", 1)

y = 20
addToggle(miscSection, "Kill Feed", y, function() request:FireServer("toggle", { name = "KillFeed" }) end); y += 40
addToggle(miscSection, "Crosshair", y, function() request:FireServer("toggle", { name = "Crosshair" }) end); y += 40
addToggle(miscSection, "Performance Mode", y, function() request:FireServer("toggle", { name = "PerformanceMode" }) end)

y = 20
addActionButton(playerSection, "Toggle UI", y, function() main.Visible = not main.Visible end); y += 40
addActionButton(playerSection, "Refresh", y, function() print("Hacker list refreshed") end)

notify.OnClientEvent:Connect(function(msg)
	local popup = Instance.new("TextLabel")
	popup.Size = UDim2.new(0, 220, 0, 30)
	popup.Position = UDim2.new(0.5, -110, 0, 12)
	popup.Text = tostring(msg)
	popup.BackgroundColor3 = Color3.fromRGB(12, 16, 20)
	popup.TextColor3 = Color3.fromRGB(0, 255, 140)
	popup.BorderSizePixel = 0
	popup.Font = Enum.Font.GothamBold
	popup.TextSize = 12
	popup.Parent = screenGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = popup
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 255, 140)
	stroke.Transparency = 0.3
	stroke.Parent = popup
	task.delay(1.8, function()
		if popup and popup.Parent then popup:Destroy() end
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

EnsureScript(ServerScriptService, "HackerFightServer", serverSource)
EnsureLocalScript(StarterPlayer:WaitForChild("StarterPlayerScripts"), "HackerFightClient", clientSource)

print("Single-file installer complete. Project generated successfully.")
