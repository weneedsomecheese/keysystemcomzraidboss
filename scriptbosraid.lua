--[[
    ================================================================
    [ SCRIPT INFORMATION ]
    Project: Custom Script
    Author: OYB
    YouTube: https://www.youtube.com/channel/UCAlXXV1Hbvf7WbfXARuVtiQ
    
    [ TERMS AND CONDITIONS ]
    - You ARE allowed to use and modify this script for your own games.
    - You ARE NOT allowed to re-upload, redistribute, or claim 
      ownership of this script.
    - Removing or altering these credits is strictly prohibited.
    
    Copyright (c) 2026 OYB. All rights reserved.
    ================================================================
]]

-- ⚠️ IMPORTANT: Put this code at the VERY TOP of your Main Script (before obfuscating) ⚠️

local ProtectionConfig = {
    -- 🔴 CRITICAL: This MUST exactly match the 'Secret' value in your Key System's Config!
    -- If your Key System has: Secret = "Test"
    -- Then this must also be: SecretKey = "Test"
    SecretKey = "Ali_Hussain10",
    
    -- The name of your Hub (shown in the kick message if they try to bypass)
    HubName = "Stonk Hub"
}

-- Anti-Bypass Logic: Checks if the Key System successfully set the global variable
if not _G[ProtectionConfig.SecretKey] then
    local player = game:GetService("Players").LocalPlayer
    if player then
        player:Kick("\n🛡️ Unauthorized Execution 🛡️\n\nPlease use the official Key System to run " .. ProtectionConfig.HubName)
    end
    return -- Stops the rest of the script from loading!
end

-------------------------------------------------------------------------------
-- 👇 YOUR MAIN SCRIPT CODE STARTS HERE 👇
-------------------------------------------------------------------------------

print(ProtectionConfig.HubName .. " Loaded Successfully!")


-- Prevent multiple loads (allow re-execution after 5 seconds)
if _G._BossRaidLoadTime and (tick() - _G._BossRaidLoadTime) < 5 then return end
_G._BossRaidLoadTime = tick()

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local PartySystem = ReplicatedStorage:FindFirstChild("PartySystem")

-- ============================================================
-- SETTINGS PERSISTENCE
-- ============================================================
local SETTINGS_FILE = "BossRaidSettings.json"

local function saveSettings(cfg)
    pcall(function()
        local data = HttpService:JSONEncode({
            Boss = cfg.Boss,
            Password = cfg.Password,
            Limit = cfg.Limit,
            AutoFarm = cfg.AutoFarm,
            Flying = cfg.Flying,
            AutoShoot = cfg.AutoShoot,
            FlyHeight = cfg.FlyHeight,
            CircleRadius = cfg.CircleRadius,
            CircleSpeed = cfg.CircleSpeed,
            ShootRate = cfg.ShootRate,
            BulletsPerTick = cfg.BulletsPerTick,
        })
        writefile(SETTINGS_FILE, data)
    end)
end

local function loadSettings()
    local ok, data = pcall(function()
        if isfile(SETTINGS_FILE) then
            return HttpService:JSONDecode(readfile(SETTINGS_FILE))
        end
        return nil
    end)
    if ok and data then return data end
    return nil
end

-- Queue script to re-run after teleport (loads from GitHub, never saves raw script locally)
pcall(function()
    if queue_on_teleport then
        queue_on_teleport([[
            _G._AUTOFARM_QUEUED = true
            task.wait(3)
            pcall(function()
                _G["Ali_Hussain10"] = true
                loadstring(game:HttpGet("https://raw.githubusercontent.com/weneedsomecheese/keysystemcomzraidboss/refs/heads/main/scriptbosraid.lua"))()
            end)
        ]])
    end
end)

-- Check if we were queued from a teleport (auto-start combat)
local WAS_QUEUED = _G._AUTOFARM_QUEUED or false
_G._AUTOFARM_QUEUED = nil

local SCRIPT_START_TIME = tick()
_G._bossFoundAlive = false
_G._bossWasDead = false

-- Destroy old GUI
if LocalPlayer.PlayerGui:FindFirstChild("BossRaidAutoFarm") then
    LocalPlayer.PlayerGui.BossRaidAutoFarm:Destroy()
end
if _G._autoShootConn then
    _G._autoShootConn:Disconnect()
    _G._autoShootConn = nil
end
_G._autoShootActive = false

-- Default config
local CONFIG = {
    Boss = "Rugby",
    Password = "fet",
    Limit = 4,
    AutoFarm = false,
    StartDelay = 2,
    RejoinDelay = 5,
    Flying = false,
    AutoShoot = false,
    FlyHeight = 35,
    CircleRadius = 25,
    CircleSpeed = 1.2,
    ShootRate = 0,
    BulletsPerTick = 10,
}

-- Load saved settings over defaults
local saved = loadSettings()
if saved then
    for k, v in pairs(saved) do
        if CONFIG[k] ~= nil then
            CONFIG[k] = v
        end
    end
end

local BOSSES = {
    {display = "Chef", value = "Chef"},
    {display = "Rugby Player", value = "Rugby"},
    {display = "Wrestler", value = "Wrestler"},
    {display = "Straw Man", value = "Strawman"},
    {display = "Shark Hunter", value = "SharkHunter"},
    {display = "Road Buster", value = "RoadBuster"},
    {display = "Elite Rugby", value = "EliteRugby"},
    {display = "Blaze", value = "Blaze"},
    {display = "Dead Light", value = "DeadLight"},
    {display = "Infector", value = "Infector"},
    {display = "Atomizer", value = "Atomizer"},
    {display = "Executioner", value = "Executioner"},
}
local function getBossDisplay(val)
    for _, b in ipairs(BOSSES) do if b.value == val then return b.display end end
    return val
end
local flyBody, flyGyro, circleAngle, flyConnection = nil, nil, 0, nil

-- ============================================================
-- FIND BOSS / ZOMBIES
-- ============================================================
local function findMapFolder()
    local currentMap = workspace:FindFirstChild("CURRENT_MAP")
    if not currentMap then return nil end
    for _, v in ipairs(currentMap:GetChildren()) do
        if v:IsA("Model") or v:IsA("Folder") then
            return v
        end
    end
    return nil
end

local function findBoss()
    local mapFolder = findMapFolder()
    if not mapFolder then return nil end

    local directBoss = mapFolder:FindFirstChild("Zombie")
    if directBoss and directBoss:IsA("Model") then
        local hum = directBoss:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            return directBoss
        end
    end

    for _, v in ipairs(mapFolder:GetDescendants()) do
        if v:IsA("Model") and v:GetAttribute("IsBoss") then
            local hum = v:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                return v
            end
        end
    end

    return nil
end

if not _G._crystalZeroTimes then _G._crystalZeroTimes = {} end

local _cachedTargets = {}
local _cacheTime = 0
local CACHE_INTERVAL = 0.3

local function _refreshTargets()
    local crystals = {}
    local bList = {}
    local zombies = {}
    local seen = {}
    local mapFolder = findMapFolder()
    if not mapFolder then _cachedTargets = {} return end

    local zombieFolder = mapFolder:FindFirstChild("ZombiesSpawnedIn")

    for _, desc in ipairs(mapFolder:GetDescendants()) do
        if desc:IsA("Humanoid") then
            local model = desc.Parent
            if model and model:IsA("Model") and not seen[model] then
                local isRegularZombie = zombieFolder and model:IsDescendantOf(zombieFolder)
                local isBoss = model.Name == "Zombie" and model.Parent == mapFolder
                if isRegularZombie then
                    if desc.Health > 0 then
                        seen[model] = true
                        table.insert(zombies, model)
                    end
                elseif isBoss then
                    if desc.Health > 0 then
                        seen[model] = true
                        table.insert(bList, model)
                    end
                else
                    if desc.Health > 0 then
                        seen[model] = true
                        table.insert(crystals, model)
                        _G._crystalZeroTimes[model] = nil
                    elseif desc.Health == 0 then
                        if not _G._crystalZeroTimes[model] then
                            _G._crystalZeroTimes[model] = tick()
                        end
                        if tick() - _G._crystalZeroTimes[model] < 0.5 then
                            seen[model] = true
                            table.insert(crystals, model)
                        end
                    end
                end
            end
        end
    end

    local result = {}
    for _, c in ipairs(crystals) do table.insert(result, c) end
    for _, b in ipairs(bList) do table.insert(result, b) end
    for _, z in ipairs(zombies) do table.insert(result, z) end
    _cachedTargets = result
end

local function findAllZombies()
    local now = tick()
    if now - _cacheTime >= CACHE_INTERVAL then
        _cacheTime = now
        _refreshTargets()
    end
    return _cachedTargets
end

-- ============================================================
-- DATAPACKET ENCODER
-- ============================================================
local DataPacketEncoder
pcall(function()
    local Utilities = require(ReplicatedStorage.Modules.Utilities)
    DataPacketEncoder = unpack(Utilities.DataPacket)
end)

local function encodePacket(data)
    if DataPacketEncoder then
        local ok, result = pcall(DataPacketEncoder, data)
        if ok then return result end
    end
    local t1, t2 = {}, {}
    for k, v in pairs(data) do t1[k] = v; t2[k] = false end
    return {t1, t2}
end

-- ============================================================
-- GUI CREATION
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BossRaidAutoFarm"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 300, 0, 530)
Main.Position = UDim2.new(0.5, -150, 0.5, -265)
Main.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
local mainStroke = Instance.new("UIStroke", Main)
mainStroke.Color = Color3.fromRGB(255, 50, 50)
mainStroke.Thickness = 2

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 36)
TitleBar.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)
local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0, 12)
titleFix.Position = UDim2.new(0, 0, 1, -12)
titleFix.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
titleFix.BorderSizePixel = 0
titleFix.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -70, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Boss Farm by extracheesepls092"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 15
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local function makeTitleBtn(text, posOffset)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 28, 0, 28)
    btn.Position = UDim2.new(1, posOffset, 0, 4)
    btn.BackgroundColor3 = Color3.fromRGB(140, 25, 25)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Parent = TitleBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end
local CloseBtn = makeTitleBtn("X", -32)
local MinBtn = makeTitleBtn("-", -63)

local Content = Instance.new("ScrollingFrame")
Content.Name = "Content"
Content.Size = UDim2.new(1, -16, 1, -44)
Content.Position = UDim2.new(0, 8, 0, 40)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 4
Content.ScrollBarImageColor3 = Color3.fromRGB(255, 50, 50)
Content.CanvasSize = UDim2.new(0, 0, 0, 550)
Content.Parent = Main
local contentLayout = Instance.new("UIListLayout")
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Padding = UDim.new(0, 6)
contentLayout.Parent = Content
local contentPad = Instance.new("UIPadding")
contentPad.PaddingLeft = UDim.new(0, 4)
contentPad.PaddingRight = UDim.new(0, 4)
contentPad.Parent = Content

-- GUI Helpers
local function makeLabel(text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(255, 100, 100)
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = order
    lbl.Parent = Content
    return lbl
end

local function makeButton(text, color, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.LayoutOrder = order
    btn.Parent = Content
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    return btn
end

local function makeTextBox(placeholder, defaultText, order)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 30)
    box.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    box.Text = defaultText
    box.PlaceholderText = placeholder
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.PlaceholderColor3 = Color3.fromRGB(90, 90, 110)
    box.TextSize = 13
    box.Font = Enum.Font.Gotham
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.LayoutOrder = order
    box.Parent = Content
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
    Instance.new("UIPadding", box).PaddingLeft = UDim.new(0, 10)
    return box
end

-- ============================================================
-- BUILD GUI
-- ============================================================
makeLabel("BOSS SELECT", 1)

-- Boss dropdown selector
local BossSelectBtn = Instance.new("TextButton")
BossSelectBtn.Size = UDim2.new(1, 0, 0, 32)
BossSelectBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
BossSelectBtn.Text = getBossDisplay(CONFIG.Boss) .. "  \u{25BC}"
BossSelectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
BossSelectBtn.TextSize = 13
BossSelectBtn.Font = Enum.Font.GothamBold
BossSelectBtn.BorderSizePixel = 0
BossSelectBtn.LayoutOrder = 2
BossSelectBtn.Parent = Content
Instance.new("UICorner", BossSelectBtn).CornerRadius = UDim.new(0, 8)

-- Dropdown popup (parented to Main so it overlays Content)
local DropdownFrame = Instance.new("Frame")
DropdownFrame.Size = UDim2.new(1, -16, 0, 200)
DropdownFrame.Position = UDim2.new(0, 8, 0, 100)
DropdownFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
DropdownFrame.BorderSizePixel = 0
DropdownFrame.ZIndex = 50
DropdownFrame.Visible = false
DropdownFrame.Parent = Main
Instance.new("UICorner", DropdownFrame).CornerRadius = UDim.new(0, 8)
local ddStroke = Instance.new("UIStroke", DropdownFrame)
ddStroke.Color = Color3.fromRGB(180, 30, 30)
ddStroke.Thickness = 1

local DropdownScroll = Instance.new("ScrollingFrame")
DropdownScroll.Size = UDim2.new(1, -8, 1, -8)
DropdownScroll.Position = UDim2.new(0, 4, 0, 4)
DropdownScroll.BackgroundTransparency = 1
DropdownScroll.BorderSizePixel = 0
DropdownScroll.ScrollBarThickness = 4
DropdownScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 50, 50)
DropdownScroll.CanvasSize = UDim2.new(0, 0, 0, #BOSSES * 30)
DropdownScroll.ZIndex = 51
DropdownScroll.Parent = DropdownFrame
local ddLayout = Instance.new("UIListLayout")
ddLayout.SortOrder = Enum.SortOrder.LayoutOrder
ddLayout.Padding = UDim.new(0, 2)
ddLayout.Parent = DropdownScroll

local function updateDropdown()
    BossSelectBtn.Text = getBossDisplay(CONFIG.Boss) .. "  \u{25BC}"
    for _, child in ipairs(DropdownScroll:GetChildren()) do
        if child:IsA("TextButton") then
            if child.Name == CONFIG.Boss then
                child.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
                child.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                child.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
                child.TextColor3 = Color3.fromRGB(180, 180, 200)
            end
        end
    end
end

for i, boss in ipairs(BOSSES) do
    local opt = Instance.new("TextButton")
    opt.Name = boss.value
    opt.Size = UDim2.new(1, -4, 0, 28)
    opt.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    opt.Text = boss.display
    opt.TextColor3 = Color3.fromRGB(180, 180, 200)
    opt.TextSize = 12
    opt.Font = Enum.Font.GothamBold
    opt.BorderSizePixel = 0
    opt.LayoutOrder = i
    opt.ZIndex = 52
    opt.Parent = DropdownScroll
    Instance.new("UICorner", opt).CornerRadius = UDim.new(0, 6)
    opt.MouseButton1Click:Connect(function()
        CONFIG.Boss = boss.value
        updateDropdown()
        saveSettings(CONFIG)
        DropdownFrame.Visible = false
    end)
end
updateDropdown()

BossSelectBtn.MouseButton1Click:Connect(function()
    DropdownFrame.Visible = not DropdownFrame.Visible
end)

makeLabel("PASSWORD", 3)
local PasswordBox = makeTextBox("Enter password...", CONFIG.Password, 4)
PasswordBox.FocusLost:Connect(function() CONFIG.Password = PasswordBox.Text; saveSettings(CONFIG) end)

local CreateBtn = makeButton("Create Party", Color3.fromRGB(45, 120, 190), 5)
local StartBtn = makeButton("Start Raid", Color3.fromRGB(190, 130, 25), 6)

makeLabel("COMBAT", 10)
local FlyBtn = makeButton("Fly + Circle: OFF", Color3.fromRGB(160, 35, 35), 11)
local AutoShootBtn = makeButton("Auto Shoot: OFF", Color3.fromRGB(160, 35, 35), 12)

makeLabel("FLY SETTINGS", 20)

local function makeDescLabel(text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 13)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(130, 130, 155)
    lbl.TextSize = 10
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = order
    lbl.Parent = Content
    return lbl
end

makeDescLabel("Height above boss (studs)", 21)
local HeightBox = makeTextBox("Fly Height", tostring(CONFIG.FlyHeight), 22)
HeightBox.FocusLost:Connect(function() CONFIG.FlyHeight = tonumber(HeightBox.Text) or CONFIG.FlyHeight; saveSettings(CONFIG) end)

makeDescLabel("Circle distance from boss (studs)", 23)
local RadiusBox = makeTextBox("Circle Radius", tostring(CONFIG.CircleRadius), 24)
RadiusBox.FocusLost:Connect(function() CONFIG.CircleRadius = tonumber(RadiusBox.Text) or CONFIG.CircleRadius; saveSettings(CONFIG) end)

makeDescLabel("How fast you orbit the boss", 25)
local SpeedBox = makeTextBox("Circle Speed", tostring(CONFIG.CircleSpeed), 26)
SpeedBox.FocusLost:Connect(function() CONFIG.CircleSpeed = tonumber(SpeedBox.Text) or CONFIG.CircleSpeed; saveSettings(CONFIG) end)

makeLabel("SHOOT SETTINGS", 30)
makeDescLabel("Bullets fired per frame (higher = more DPS)", 31)
local BulletsBox = makeTextBox("Bullets Per Tick", tostring(CONFIG.BulletsPerTick), 32)
BulletsBox.FocusLost:Connect(function() CONFIG.BulletsPerTick = tonumber(BulletsBox.Text) or CONFIG.BulletsPerTick; saveSettings(CONFIG) end)

makeLabel("AUTO FARM", 40)
local AutoFarmBtn = makeButton("AutoFarm: OFF", Color3.fromRGB(160, 35, 35), 41)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 22)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: Idle"
StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
StatusLabel.TextSize = 11
StatusLabel.Font = Enum.Font.GothamMedium
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.LayoutOrder = 50
StatusLabel.Parent = Content

local BossHPLabel = Instance.new("TextLabel")
BossHPLabel.Size = UDim2.new(1, 0, 0, 18)
BossHPLabel.BackgroundTransparency = 1
BossHPLabel.Text = "Boss HP: --"
BossHPLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
BossHPLabel.TextSize = 11
BossHPLabel.Font = Enum.Font.GothamMedium
BossHPLabel.TextXAlignment = Enum.TextXAlignment.Left
BossHPLabel.LayoutOrder = 51
BossHPLabel.Parent = Content

local DiscordBtn = Instance.new("TextButton")
DiscordBtn.Size = UDim2.new(1, 0, 0, 32)
DiscordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
DiscordBtn.Text = "Discord Link"
DiscordBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
DiscordBtn.TextSize = 13
DiscordBtn.Font = Enum.Font.GothamBold
DiscordBtn.BorderSizePixel = 0
DiscordBtn.LayoutOrder = 52
DiscordBtn.Parent = Content
Instance.new("UICorner", DiscordBtn).CornerRadius = UDim.new(0, 8)
DiscordBtn.MouseButton1Click:Connect(function()
    setclipboard("https://discord.gg/s2aGHMSxq")
    DiscordBtn.Text = "Copied!"
    task.delay(2, function() DiscordBtn.Text = "Discord Link" end)
end)

contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    Content.CanvasSize = UDim2.new(0, 0, 0, contentLayout.AbsoluteContentSize.Y + 10)
end)

-- ============================================================
-- DRAGGING
-- ============================================================
local dragging, dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
    end
end)
TitleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible = not minimized
    Main.Size = minimized and UDim2.new(0, 300, 0, 36) or UDim2.new(0, 300, 0, 530)
    MinBtn.Text = minimized and "+" or "-"
end)

-- ============================================================
-- CORE FUNCTIONS
-- ============================================================
local function setStatus(text)
    if StatusLabel and StatusLabel.Parent then
        StatusLabel.Text = "Status: " .. text
    end
end

-- Click a GUI button using firesignal (works on Madium)
local function forceClickButton(btn)
    if not btn then return end
    pcall(function() firesignal(btn.MouseButton1Click) end)
    pcall(function() firesignal(btn.Activated) end)
    pcall(function()
        for _, conn in ipairs(getconnections(btn.MouseButton1Click)) do
            conn:Fire()
        end
    end)
    pcall(function() btn.MouseButton1Click:Fire() end)
    pcall(function()
        local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
        if mousemoveabs then mousemoveabs(pos.X, pos.Y) end
        if mouse1click then mouse1click() end
    end)
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
        vim:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
        vim:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
    end)
end

-- AUTO CLICK "OK" ON MISSION COMPLETE (ResultFrame)
local function clickResultClose()
    local mainMenu = LocalPlayer.PlayerGui:FindFirstChild("MainMenu")
    if not mainMenu then return false end
    local resultFrame = mainMenu:FindFirstChild("ResultFrame")
    if not resultFrame then return false end
    local closeBtn = resultFrame:FindFirstChild("CloseButton")
    if not closeBtn then return false end
    forceClickButton(closeBtn)
    return true
end

local function updateBossHP()
    local boss = findBoss()
    if boss then
        local hum = boss:FindFirstChildOfClass("Humanoid")
        if hum then
            BossHPLabel.Text = string.format("Boss HP: %s / %s", math.floor(hum.Health), math.floor(hum.MaxHealth))
            return
        end
    end
    BossHPLabel.Text = "Boss HP: --"
end

-- FLY SYSTEM
local function startFly()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if flyBody then pcall(function() flyBody:Destroy() end) end
    if flyGyro then pcall(function() flyGyro:Destroy() end) end

    flyBody = Instance.new("BodyVelocity")
    flyBody.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    flyBody.Velocity = Vector3.zero
    flyBody.Parent = hrp

    flyGyro = Instance.new("BodyGyro")
    flyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    flyGyro.D = 100
    flyGyro.P = 10000
    flyGyro.Parent = hrp

    circleAngle = 0
    if flyConnection then flyConnection:Disconnect() end

    flyConnection = RunService.Heartbeat:Connect(function(dt)
        if not CONFIG.Flying then return end
        local char2 = LocalPlayer.Character
        if not char2 then return end
        local hrp2 = char2:FindFirstChild("HumanoidRootPart")
        if not hrp2 then return end

        -- Noclip: disable collision on character parts
        for _, part in ipairs(char2:GetChildren()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end

        -- Re-create body movers if they were destroyed (teleport/respawn)
        if not flyBody or not flyBody.Parent then
            flyBody = Instance.new("BodyVelocity")
            flyBody.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            flyBody.Velocity = Vector3.zero
            flyBody.Parent = hrp2
        end
        if not flyGyro or not flyGyro.Parent then
            flyGyro = Instance.new("BodyGyro")
            flyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            flyGyro.D = 100
            flyGyro.P = 10000
            flyGyro.Parent = hrp2
        end

        local boss = findBoss()
        if boss then
            local bossHRP = boss:FindFirstChild("HumanoidRootPart") or boss:FindFirstChild("Head")
            if bossHRP then
                circleAngle = circleAngle + (CONFIG.CircleSpeed * dt)
                local bossPos = bossHRP.Position
                local targetPos = Vector3.new(
                    bossPos.X + math.cos(circleAngle) * CONFIG.CircleRadius,
                    bossPos.Y + CONFIG.FlyHeight,
                    bossPos.Z + math.sin(circleAngle) * CONFIG.CircleRadius
                )
                flyBody.Velocity = (targetPos - hrp2.Position) * 5
                flyGyro.CFrame = CFrame.lookAt(hrp2.Position, bossPos)
                return
            end
        end
        flyBody.Velocity = Vector3.new(0, (CONFIG.FlyHeight - hrp2.Position.Y) * 3, 0)
    end)
end

local function stopFly()
    if flyConnection then flyConnection:Disconnect() flyConnection = nil end
    if flyBody then pcall(function() flyBody:Destroy() end) flyBody = nil end
    if flyGyro then pcall(function() flyGyro:Destroy() end) flyGyro = nil end
end

-- Re-start fly when character respawns
LocalPlayer.CharacterAdded:Connect(function(newChar)
    if CONFIG.Flying then
        task.spawn(function()
            newChar:WaitForChild("HumanoidRootPart", 10)
            task.wait(0.5)
            if CONFIG.Flying then
                startFly()
            end
        end)
    end
end)

-- AUTO SHOOT SYSTEM - throttled to avoid server spam detection
local MAX_CALLS_PER_SEC = 200
local function startAutoShoot()
    if _G._autoShootConn then _G._autoShootConn:Disconnect() end

    local inflict = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("InflictTarget")
    if not inflict then
        setStatus("InflictTarget not found!")
        return
    end

    _G._autoShootActive = true
    local lastShot = 0
    local shootStartTime = tick()
    local isAtomizer = CONFIG.Boss == "Atomizer"

    _G._autoShootConn = RunService.Heartbeat:Connect(function()
        if not CONFIG.AutoShoot then return end
        if isAtomizer and tick() - shootStartTime < 4 then return end
        if tick() - lastShot < CONFIG.ShootRate then return end
        lastShot = tick()

        local char = LocalPlayer.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if not tool then
            local bp = LocalPlayer:FindFirstChild("Backpack")
            if bp then
                local bpTool = bp:FindFirstChildOfClass("Tool")
                if bpTool then
                    bpTool.Parent = char
                    tool = bpTool
                end
            end
            if not tool then return end
        end

        local targets = findAllZombies()
        if #targets == 0 then return end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        -- Spread shots evenly: cap per frame instead of bursting per second
        local maxPerFrame = math.max(1, math.floor(MAX_CALLS_PER_SEC / 60))
        local bulletsToFire = math.min(CONFIG.BulletsPerTick, maxPerFrame)
        if bulletsToFire <= 0 then return end

        -- Focus fire: all bullets on first alive target, then next
        local tIdx = 1
        for i = 1, bulletsToFire do
            local target = targets[tIdx]
            if not target then break end
            local hum = target:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health < 0 then
                tIdx = tIdx + 1
                target = targets[tIdx]
                if not target then break end
                hum = target:FindFirstChildOfClass("Humanoid")
                if not hum or hum.Health < 0 then break end
            end

            local head = target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
            if not head then
                for _, p in ipairs(target:GetChildren()) do
                    if p:IsA("BasePart") then head = p break end
                end
            end
            if not head then tIdx = tIdx + 1 continue end

            local dist = (hrp.Position - head.Position).Magnitude
            local packet = encodePacket({
                ChargeLevel = 0,
                ModuleName = "1",
                ClientHitSize = head.Size,
                Distance = dist,
                BulletId = "Bullet_" .. HttpService:GenerateGUID(false)
            })
            inflict:FireServer("Gun", tool, head, packet)
        end
    end)
end

local function stopAutoShoot()
    _G._autoShootActive = false
    if _G._autoShootConn then _G._autoShootConn:Disconnect() _G._autoShootConn = nil end
end

-- Re-start auto-shoot when character respawns
LocalPlayer.CharacterAdded:Connect(function(newChar)
    if CONFIG.AutoShoot then
        task.spawn(function()
            newChar:WaitForChild("HumanoidRootPart", 10)
            task.wait(0.5)
            if CONFIG.AutoShoot then
                startAutoShoot()
            end
        end)
    end
end)

-- PARTY FUNCTIONS
local function createParty()
    if not PartySystem then PartySystem = ReplicatedStorage:FindFirstChild("PartySystem") end
    if not PartySystem then setStatus("PartySystem not found!") return false end
    setStatus("Creating party...")
    PartySystem:FireServer("CREATE", {
        Limit = CONFIG.Limit,
        Boss = CONFIG.Boss,
        RoomID = 0,
        Status = true,
        Password = CONFIG.Password
    })
    task.wait(1)
    setStatus("Party created!")
    return true
end

local function startRaid()
    if not PartySystem then PartySystem = ReplicatedStorage:FindFirstChild("PartySystem") end
    if not PartySystem then setStatus("PartySystem not found!") return end
    setStatus("Starting raid...")
    PartySystem:FireServer("START")
    setStatus("Raid started!")
end

-- ============================================================
-- BUTTON CONNECTIONS
-- ============================================================
CreateBtn.MouseButton1Click:Connect(function() createParty() end)
StartBtn.MouseButton1Click:Connect(function() startRaid() end)

FlyBtn.MouseButton1Click:Connect(function()
    CONFIG.Flying = not CONFIG.Flying
    if CONFIG.Flying then
        FlyBtn.Text = "Fly + Circle: ON"
        FlyBtn.BackgroundColor3 = Color3.fromRGB(35, 160, 35)
        startFly()
        setStatus("Flying!")
    else
        FlyBtn.Text = "Fly + Circle: OFF"
        FlyBtn.BackgroundColor3 = Color3.fromRGB(160, 35, 35)
        stopFly()
        setStatus("Fly stopped")
    end
    saveSettings(CONFIG)
end)

AutoShootBtn.MouseButton1Click:Connect(function()
    CONFIG.AutoShoot = not CONFIG.AutoShoot
    if CONFIG.AutoShoot then
        AutoShootBtn.Text = "Auto Shoot: ON"
        AutoShootBtn.BackgroundColor3 = Color3.fromRGB(35, 160, 35)
        startAutoShoot()
        setStatus("Auto shooting boss!")
    else
        AutoShootBtn.Text = "Auto Shoot: OFF"
        AutoShootBtn.BackgroundColor3 = Color3.fromRGB(160, 35, 35)
        stopAutoShoot()
        setStatus("Auto shoot stopped")
    end
    saveSettings(CONFIG)
end)

AutoFarmBtn.MouseButton1Click:Connect(function()
    CONFIG.AutoFarm = not CONFIG.AutoFarm
    if CONFIG.AutoFarm then
        AutoFarmBtn.Text = "AutoFarm: ON"
        AutoFarmBtn.BackgroundColor3 = Color3.fromRGB(35, 160, 35)
        setStatus("AutoFarm started!")
        task.spawn(function()
            while CONFIG.AutoFarm and ScreenGui.Parent do
                if not PartySystem or not PartySystem.Parent then
                    PartySystem = ReplicatedStorage:FindFirstChild("PartySystem")
                end
                if PartySystem then
                    -- Reset boss tracking for new cycle
                    _G._bossFoundAlive = false
                    _G._bossWasDead = false
                    -- Step 1: Create party
                    local ok = createParty()
                    if ok then
                        task.wait(CONFIG.StartDelay)
                        if not CONFIG.AutoFarm then break end

                        -- Step 2: Start raid (teleports to boss map)
                        startRaid()
                        setStatus("Waiting for teleport...")
                        task.wait(CONFIG.RejoinDelay)
                        if not CONFIG.AutoFarm then break end

                        -- Step 3: Auto-enable fly + shoot once in raid
                        setStatus("In raid - enabling fly & shoot...")
                        if not CONFIG.Flying then
                            CONFIG.Flying = true
                            FlyBtn.Text = "Fly + Circle: ON"
                            FlyBtn.BackgroundColor3 = Color3.fromRGB(35, 160, 35)
                            startFly()
                        end
                        if not CONFIG.AutoShoot then
                            CONFIG.AutoShoot = true
                            AutoShootBtn.Text = "Auto Shoot: ON"
                            AutoShootBtn.BackgroundColor3 = Color3.fromRGB(35, 160, 35)
                            startAutoShoot()
                        end
                        setStatus("Fighting boss...")

                        -- Step 4: Wait for boss to die (or ResultFrame to appear)
                        while CONFIG.AutoFarm and ScreenGui.Parent do
                            if clickResultClose() then
                                setStatus("Mission Complete! Returning to lobby...")
                                stopFly()
                                CONFIG.Flying = false
                                FlyBtn.Text = "Fly + Circle: OFF"
                                FlyBtn.BackgroundColor3 = Color3.fromRGB(160, 35, 35)
                                stopAutoShoot()
                                CONFIG.AutoShoot = false
                                AutoShootBtn.Text = "Auto Shoot: OFF"
                                AutoShootBtn.BackgroundColor3 = Color3.fromRGB(160, 35, 35)
                                task.wait(3)
                                break
                            end
                            task.wait(1)
                        end
                    end
                else
                    setStatus("Waiting for PartySystem...")
                    task.wait(2)
                end
            end
        end)
    else
        AutoFarmBtn.Text = "AutoFarm: OFF"
        AutoFarmBtn.BackgroundColor3 = Color3.fromRGB(160, 35, 35)
        setStatus("AutoFarm stopped")
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    CONFIG.AutoFarm = false
    CONFIG.Flying = false
    CONFIG.AutoShoot = false
    _G._resultWatcherActive = false
    _G._BossRaidLoadTime = nil
    stopFly()
    stopAutoShoot()
    ScreenGui:Destroy()
end)

-- Boss HP updater (only while GUI alive)
task.spawn(function()
    while ScreenGui and ScreenGui.Parent do
        pcall(updateBossHP)
        task.wait(0.5)
    end
end)

-- Boss death / player death watcher — clicks OK on Mission Complete or Mission Failed
-- Runs in _G so it survives GUI destruction
_G._resultWatcherActive = true
_G._bossWasDead = false
_G._playerDied = false
task.spawn(function()
    while _G._resultWatcherActive do
        -- Track boss state
        local boss = findBoss()
        if boss then
            local hum = boss:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                _G._bossFoundAlive = true
            end
        end
        if _G._bossFoundAlive and not boss then
            _G._bossWasDead = true
        end
        if _G._bossFoundAlive and boss then
            local hum = boss:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then
                _G._bossWasDead = true
            end
        end

        -- Track Mission Failed: ResultFrame on-screen but boss didn't die
        local inRaid = findMapFolder() ~= nil
        if inRaid and not _G._bossWasDead then
            local mainMenu = LocalPlayer.PlayerGui:FindFirstChild("MainMenu")
            if mainMenu then
                local rf = mainMenu:FindFirstChild("ResultFrame")
                if rf and rf.Visible and rf.AbsolutePosition.Y >= 0 then
                    _G._playerDied = true
                end
            end
        end

        -- Boss died → wait 6s then click OK (Mission Complete)
        if _G._bossWasDead then
            print("[AutoFarm] Boss died! Waiting 6 seconds...")
            task.wait(6)
            for attempt = 1, 10 do
                if clickResultClose() then
                    print("[AutoFarm] Clicked Mission Complete OK!")
                    break
                end
                task.wait(1)
            end
            _G._bossWasDead = false
            _G._bossFoundAlive = false
            _G._playerDied = false
        end

        -- Player died → wait 3s then click OK (Mission Failed)
        if _G._playerDied and not _G._bossWasDead then
            print("[AutoFarm] Player died! Waiting 3 seconds...")
            task.wait(3)
            for attempt = 1, 10 do
                if clickResultClose() then
                    print("[AutoFarm] Clicked Mission Failed OK!")
                    break
                end
                task.wait(1)
            end
            _G._playerDied = false
            _G._bossFoundAlive = false
        end

        task.wait(0.5)
    end
end)

-- Mission end watcher: listen for BR RemoteEvent + LogService fallback
-- On mission end, teleport directly to lobby (bypasses button click entirely)
local LOBBY_PLACE_ID = 15899178400
local LogService = game:GetService("LogService")
local TeleportService = game:GetService("TeleportService")
if _G._rfWatcherConn then pcall(function() _G._rfWatcherConn:Disconnect() end) end
if _G._logWatcherConn then pcall(function() _G._logWatcherConn:Disconnect() end) end
if _G._brWatcherConn then pcall(function() _G._brWatcherConn:Disconnect() end) end
_G._missionEndAt = nil
_G._missionClicked = false

local function doTeleportToLobby()
    if _G._missionClicked then return end
    _G._missionClicked = true
    print("[AutoFarm] Teleporting to lobby...")
    pcall(function()
        TeleportService:Teleport(LOBBY_PLACE_ID, LocalPlayer)
    end)
    pcall(function()
        forceClickButton(LocalPlayer.PlayerGui.MainMenu.ResultFrame.CloseButton)
    end)
end

-- Primary: BR RemoteEvent fires with "SUCCESS" or "FAILED"
pcall(function()
    local matchFolder = ReplicatedStorage:FindFirstChild("MATCH FOLDER")
    if matchFolder then
        local br = matchFolder:FindFirstChild("BR")
        if br then
            _G._brWatcherConn = br.OnClientEvent:Connect(function(status)
                if status == "SUCCESS" or status == "FAILED" then
                    _G._missionEndAt = tick()
                    print("[AutoFarm] Mission " .. status .. " via BR event! Teleporting in 6s...")
                    task.delay(6, doTeleportToLobby)
                end
            end)
        end
    end
end)

-- Fallback: LogService
_G._logWatcherConn = LogService.MessageOut:Connect(function(message)
    if not _G._missionEndAt and (string.find(message, "MISSION FAILED") or string.find(message, "MISSION COMPLETE")) then
        _G._missionEndAt = tick()
        print("[AutoFarm] Mission end via log! Teleporting in 6s...")
        task.delay(6, doTeleportToLobby)
    end
end)

-- Fallback 2: boss HP watcher via Heartbeat
_G._hbBossSeenAlive = false
_G._rfWatcherConn = RunService.Heartbeat:Connect(function()
    if _G._missionEndAt then return end
    pcall(function()
        local inRaid = findMapFolder() ~= nil
        if not inRaid then return end
        local boss = findBoss()
        if boss then
            _G._hbBossSeenAlive = true
        elseif _G._hbBossSeenAlive then
            _G._hbBossSeenAlive = false
            _G._missionEndAt = tick()
            print("[AutoFarm] Boss death via HP fallback! Teleporting in 8s...")
            task.delay(8, doTeleportToLobby)
        end
    end)
end)

-- Heartbeat-based teleport timer (avoids task.delay dying on some executors)
if _G._teleportTimerConn then pcall(function() _G._teleportTimerConn:Disconnect() end) end
_G._teleportTimerConn = RunService.Heartbeat:Connect(function()
    if not _G._missionEndAt then return end
    if _G._missionClicked then return end
    local elapsed = tick() - _G._missionEndAt
    if elapsed >= 6 then
        doTeleportToLobby()
    end
end)

-- Hover effects
local allBtns = {CreateBtn, StartBtn, FlyBtn, AutoShootBtn, AutoFarmBtn, CloseBtn, MinBtn}
for _, btn in ipairs(allBtns) do
    local origColor = btn.BackgroundColor3
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), {
            BackgroundColor3 = Color3.new(
                math.min(btn.BackgroundColor3.R + 0.07, 1),
                math.min(btn.BackgroundColor3.G + 0.07, 1),
                math.min(btn.BackgroundColor3.B + 0.07, 1)
            )
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        local target = origColor
        if btn == FlyBtn then
            target = CONFIG.Flying and Color3.fromRGB(35, 160, 35) or Color3.fromRGB(160, 35, 35)
        elseif btn == AutoShootBtn then
            target = CONFIG.AutoShoot and Color3.fromRGB(35, 160, 35) or Color3.fromRGB(160, 35, 35)
        elseif btn == AutoFarmBtn then
            target = CONFIG.AutoFarm and Color3.fromRGB(35, 160, 35) or Color3.fromRGB(160, 35, 35)
        end
        TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = target}):Play()
    end)
end

ScreenGui.Parent = LocalPlayer.PlayerGui

-- Wait for character to be alive and have HRP
local function waitForCharacter()
    local char = LocalPlayer.Character
    if not char then
        char = LocalPlayer.CharacterAdded:Wait()
    end
    local hrp = char:WaitForChild("HumanoidRootPart", 10)
    local hum = char:WaitForChild("Humanoid", 10)
    if hum then
        -- Wait until alive
        local tries = 0
        while hum.Health <= 0 and tries < 50 do
            task.wait(0.2)
            tries = tries + 1
            char = LocalPlayer.Character
            if char then hum = char:FindFirstChildOfClass("Humanoid") end
            if not hum then break end
        end
    end
    return LocalPlayer.Character
end

-- Apply saved toggle states to GUI buttons
local function applyConfigToGUI()
    if CONFIG.Flying then
        FlyBtn.Text = "Fly + Circle: ON"
        FlyBtn.BackgroundColor3 = Color3.fromRGB(35, 160, 35)
        task.spawn(function()
            waitForCharacter()
            startFly()
        end)
    end
    if CONFIG.AutoShoot then
        AutoShootBtn.Text = "Auto Shoot: ON"
        AutoShootBtn.BackgroundColor3 = Color3.fromRGB(35, 160, 35)
        task.spawn(function()
            waitForCharacter()
            startAutoShoot()
        end)
    end
    if CONFIG.AutoFarm then
        AutoFarmBtn.Text = "AutoFarm: ON"
        AutoFarmBtn.BackgroundColor3 = Color3.fromRGB(35, 160, 35)
    end
end

if WAS_QUEUED then
    -- Restore saved settings (fly, shoot, etc.) from before teleport
    applyConfigToGUI()

    local inRaid = findMapFolder() ~= nil
    if inRaid then
        setStatus("Teleported! Resuming combat...")
        -- Ensure fly + shoot are on in raid
        if not CONFIG.Flying then
            CONFIG.Flying = true
            FlyBtn.Text = "Fly + Circle: ON"
            FlyBtn.BackgroundColor3 = Color3.fromRGB(35, 160, 35)
            startFly()
        end
        if not CONFIG.AutoShoot then
            CONFIG.AutoShoot = true
            AutoShootBtn.Text = "Auto Shoot: ON"
            AutoShootBtn.BackgroundColor3 = Color3.fromRGB(35, 160, 35)
            startAutoShoot()
        end
        CONFIG.AutoFarm = true
        AutoFarmBtn.Text = "AutoFarm: ON"
        AutoFarmBtn.BackgroundColor3 = Color3.fromRGB(35, 160, 35)
        saveSettings(CONFIG)

        -- Boss death watcher handles clicking OK automatically
    else
        -- We're in the lobby: auto-start the full farm loop
        setStatus("Back in lobby! Restarting farm...")
        CONFIG.AutoFarm = true
        AutoFarmBtn.Text = "AutoFarm: ON"
        AutoFarmBtn.BackgroundColor3 = Color3.fromRGB(35, 160, 35)
        saveSettings(CONFIG)
        task.spawn(function()
            task.wait(2)
            while CONFIG.AutoFarm and ScreenGui.Parent do
                if not PartySystem or not PartySystem.Parent then
                    PartySystem = ReplicatedStorage:FindFirstChild("PartySystem")
                end
                if PartySystem then
                    local ok = createParty()
                    if ok then
                        task.wait(CONFIG.StartDelay)
                        if CONFIG.AutoFarm then
                            startRaid()
                            setStatus("Starting raid...")
                            task.wait(CONFIG.RejoinDelay)
                        end
                    end
                else
                    setStatus("Waiting for PartySystem...")
                    task.wait(2)
                end
            end
        end)
    end
else
    -- First run or manual re-execute: apply saved toggle states
    applyConfigToGUI()

    -- If we're in a raid with autofarm on, resume combat watchers
    local inRaid = findMapFolder() ~= nil
    if inRaid and CONFIG.AutoFarm then
        setStatus("In raid - resuming combat...")
        if not CONFIG.Flying then
            CONFIG.Flying = true
            FlyBtn.Text = "Fly + Circle: ON"
            FlyBtn.BackgroundColor3 = Color3.fromRGB(35, 160, 35)
            task.spawn(function()
                waitForCharacter()
                startFly()
            end)
        end
        if not CONFIG.AutoShoot then
            CONFIG.AutoShoot = true
            AutoShootBtn.Text = "Auto Shoot: ON"
            AutoShootBtn.BackgroundColor3 = Color3.fromRGB(35, 160, 35)
            startAutoShoot()
        end
        saveSettings(CONFIG)
    elseif inRaid then
        setStatus("In raid")
    elseif CONFIG.AutoFarm then
        -- In lobby with AutoFarm ON — start the farm loop
        setStatus("AutoFarm resuming...")
        task.spawn(function()
            task.wait(2)
            while CONFIG.AutoFarm and ScreenGui.Parent do
                if not PartySystem or not PartySystem.Parent then
                    PartySystem = ReplicatedStorage:FindFirstChild("PartySystem")
                end
                if PartySystem then
                    _G._bossFoundAlive = false
                    _G._bossWasDead = false
                    local ok = createParty()
                    if ok then
                        task.wait(CONFIG.StartDelay)
                        if not CONFIG.AutoFarm then break end
                        startRaid()
                        setStatus("Starting raid...")
                        task.wait(CONFIG.RejoinDelay)
                    end
                else
                    setStatus("Waiting for PartySystem...")
                    task.wait(2)
                end
            end
        end)
    else
        setStatus("Ready")
    end
end
print("[BossRaidGUI] Loaded" .. (WAS_QUEUED and " (auto-resumed after teleport)" or ""))
