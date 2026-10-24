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
	button.TextColor3 = Color3.fromRGB(255,255,255)
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
		local nextVal = (tonumber(valueButton.Text) or startValue) + 1
		valueButton.Text = tostring(nextVal)
		request:FireServer("setValue", { key = key, value = nextVal })
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
		remotes:WaitForChild("CombatRequest"):FireServer(target.Name, 1)
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
		-- acknowledgment
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
