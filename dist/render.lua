--[[
================================================================================
   HYPERION RENDER ENGINE v9.1 (ENTERPRISE FIXED)
   Исправлен баг с инициализацией Config и добавлен вывод ошибок в консоль.
================================================================================
]]
print("[Hyperion] Загрузка скрипта...")

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local DefaultConfig = {
    System = {
        Version = "9.1.0",
        AutoLoadConfig = true,
        ShowNotifications = true,
        DebugMode = true,
        Theme = "Dark",
        ToggleKey = Enum.KeyCode.RightShift,
        GUIVisible = true,
        MaxLogHistory = 150
    },
    Render = {
        Enabled = true, DisableShadows = true, ForceVoxel = true,
        DisablePostFX = true, DisableAtmosphere = true, FlattenAmbient = true,
        AmbientColor = {150, 150, 150}
    },
    Materials = {
        Enabled = true, RemoveTextures = true, FlattenMaterials = true,
        RemoveTransparency = true, RemoveReflectance = true
    },
    Effects = {
        Enabled = true, DisableParticles = true, DisableTrails = true,
        DisableLights = true, DisableSounds = true
    },
    Physics = {
        Enabled = true, DisableDebrisCollisions = true
    },
    Culling = {
        Enabled = false, RenderDistance = 500, LODEnabled = false,
        LODDistance = 300, ChunkSize = 100, CheckInterval = 0.2
    },
    Memory = {
        AutoGarbageCollect = true, GCInterval = 30
    }
}

-- ИСПРАВЛЕНИЕ: Инициализируем Config сразу, чтобы не было nil
local Config = DefaultConfig 
local ActiveTheme

local Themes = {
    Dark = { Background = Color3.fromRGB(15, 15, 20), TitleBar = Color3.fromRGB(25, 25, 35), Panel = Color3.fromRGB(20, 20, 25), Element = Color3.fromRGB(30, 30, 40), Text = Color3.fromRGB(200, 200, 200), SubText = Color3.fromRGB(150, 150, 150), Accent = Color3.fromRGB(0, 255, 200), Danger = Color3.fromRGB(255, 60, 60) },
    Light = { Background = Color3.fromRGB(240, 240, 245), TitleBar = Color3.fromRGB(220, 220, 230), Panel = Color3.fromRGB(250, 250, 255), Element = Color3.fromRGB(200, 200, 210), Text = Color3.fromRGB(30, 30, 30), SubText = Color3.fromRGB(80, 80, 80), Accent = Color3.fromRGB(0, 150, 200), Danger = Color3.fromRGB(200, 50, 50) },
    Cyberpunk = { Background = Color3.fromRGB(10, 5, 15), TitleBar = Color3.fromRGB(20, 10, 30), Panel = Color3.fromRGB(15, 10, 20), Element = Color3.fromRGB(40, 20, 50), Text = Color3.fromRGB(255, 200, 100), SubText = Color3.fromRGB(200, 150, 80), Accent = Color3.fromRGB(255, 0, 150), Danger = Color3.fromRGB(255, 255, 0) }
}
ActiveTheme = Themes[Config.System.Theme] or Themes.Dark

local Logger = { History = {}, LogFile = "HyperionEngine_v9.txt" }
function Logger.Write(level, message)
    local timestamp = os.date("%H:%M:%S")
    local formatted = string.format("[%s] [%s] %s", timestamp, level, message)
    table.insert(Logger.History, formatted)
    if #Logger.History > Config.System.MaxLogHistory then table.remove(Logger.History, 1) end
    if Config.System.DebugMode then
        if level == "ERROR" then warn(formatted) else print(formatted) end
    end
    task.spawn(function()
        pcall(function()
            local currentLog = ""
            if isfile(Logger.LogFile) then currentLog = readfile(Logger.LogFile) end
            if #currentLog < 50000 then writefile(Logger.LogFile, currentLog .. formatted .. "\n") end
        end)
    end)
end
function Logger.Info(msg) Logger.Write("INFO", msg) end
function Logger.Success(msg) Logger.Write("SUCCESS", msg) end
function Logger.Error(msg) Logger.Write("ERROR", msg) end

local EventManager = { Connections = {} }
function EventManager.Connect(event, callback)
    local connection = event:Connect(callback)
    table.insert(EventManager.Connections, connection)
    return connection
end

local Utils = {}
function Utils.IsPlayerPart(obj)
    local current = obj
    while current do
        if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then return true end
        current = current.Parent
    end
    return false
end
function Utils.SafeSet(obj, property, value)
    if not obj or not obj.Parent then return end
    pcall(function() obj[property] = value end)
end
function Utils.SafeDestroy(obj)
    if not obj or not obj.Parent then return end
    pcall(function() obj:Destroy() end)
end
function Utils.ValidateConfig(newData)
    local validated = {}
    for category, settings in pairs(DefaultConfig) do
        validated[category] = {}
        for key, defaultVal in pairs(settings) do
            if newData[category] and newData[category][key] ~= nil then
                validated[category][key] = newData[category][key]
            else
                validated[category][key] = defaultVal
            end
        end
    end
    return validated
end

local SettingsManager = {}
function SettingsManager.Load()
    pcall(function()
        if isfile("HyperionConfig_v9.json") then
            local json = readfile("HyperionConfig_v9.json")
            local decoded = HttpService:JSONDecode(json)
            Config = Utils.ValidateConfig(decoded)
            ActiveTheme = Themes[Config.System.Theme] or Themes.Dark
            Logger.Success("Конфигурация загружена с диска.")
        end
    end)
end
function SettingsManager.Save()
    pcall(function()
        local json = HttpService:JSONEncode(Config)
        writefile("HyperionConfig_v9.json", json)
        Logger.Success("Конфигурация сохранена на диск.")
    end)
end

local TaskPool = { Queue = {}, Processing = false }
function TaskPool.Enqueue(func, ...)
    local args = {...}
    table.insert(TaskPool.Queue, function() func(unpack(args)) end)
    if not TaskPool.Processing then TaskPool.Start() end
end
function TaskPool.Start()
    if TaskPool.Processing then return end
    TaskPool.Processing = true
    task.spawn(function()
        while #TaskPool.Queue > 0 do
            local task = table.remove(TaskPool.Queue, 1)
            pcall(task)
            if #TaskPool.Queue % 20 == 0 then RunService.Heartbeat:Wait() end
        end
        TaskPool.Processing = false
    end)
end

local Notifications = {}
function Notifications.Init()
    local ToastGui = Instance.new("ScreenGui")
    ToastGui.Name = "HyperionToasts"
    ToastGui.ResetOnSpawn = false
    ToastGui.Parent = CoreGui
    local ToastFrame = Instance.new("Frame")
    ToastFrame.Size = UDim2.new(0, 250, 1, -40)
    ToastFrame.Position = UDim2.new(1, -270, 0, 20)
    ToastFrame.BackgroundTransparency = 1
    ToastFrame.Parent = ToastGui
    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 10)
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    Layout.Parent = ToastFrame
    
    _G.HyperionNotify = function(title, text, duration)
        duration = duration or 5
        local Frame = Instance.new("Frame")
        Frame.Size = UDim2.new(1, 0, 0, 60)
        Frame.BackgroundColor3 = ActiveTheme.Panel
        Frame.BorderSizePixel = 0
        Frame.Position = UDim2.new(1, 300, 0, 0)
        Frame.Parent = ToastFrame
        local Accent = Instance.new("Frame")
        Accent.Size = UDim2.new(0, 4, 1, 0)
        Accent.BackgroundColor3 = ActiveTheme.Accent
        Accent.BorderSizePixel = 0
        Accent.Parent = Frame
        local Title = Instance.new("TextLabel")
        Title.Size = UDim2.new(1, -20, 0, 25)
        Title.Position = UDim2.new(0, 15, 0, 5)
        Title.BackgroundTransparency = 1
        Title.Text = title
        Title.TextColor3 = ActiveTheme.Text
        Title.Font = Enum.Font.Code
        Title.TextSize = 16
        Title.TextXAlignment = Enum.TextXAlignment.Left
        Title.Parent = Frame
        local Text = Instance.new("TextLabel")
        Text.Size = UDim2.new(1, -20, 0, 25)
        Text.Position = UDim2.new(0, 15, 0, 30)
        Text.BackgroundTransparency = 1
        Text.Text = text
        Text.TextColor3 = ActiveTheme.SubText
        Text.Font = Enum.Font.Code
        Text.TextSize = 12
        Text.TextXAlignment = Enum.TextXAlignment.Left
        Text.Parent = Frame
        TweenService:Create(Frame, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.new(0, 0, 0, 0) }):Play()
        task.delay(duration, function()
            local Tween = TweenService:Create(Frame, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Position = UDim2.new(1, 300, 0, 0), BackgroundTransparency = 1 })
            Tween:Play()
            Tween.Completed:Connect(function() Frame:Destroy() end)
        end)
    end
end

local RenderEngine = {}
function RenderEngine.ApplyLighting()
    if not Config.Render.Enabled then return end
    TaskPool.Enqueue(function()
        if Config.Render.DisablePostFX then
            for _, v in pairs(Lighting:GetChildren()) do
                if v:IsA("PostEffect") then Utils.SafeDestroy(v) end
            end
        end
        if Config.Render.DisableAtmosphere then
            for _, v in pairs(Lighting:GetChildren()) do
                if v:IsA("Atmosphere") or v:IsA("Clouds") then Utils.SafeDestroy(v) end
            end
        end
        if Config.Render.ForceVoxel then Utils.SafeSet(Lighting, "Technology", Enum.Technology.Compatibility) end
        if Config.Render.DisableShadows then Utils.SafeSet(Lighting, "GlobalShadows", false) end
        if Config.Render.FlattenAmbient then
            Utils.SafeSet(Lighting, "Brightness", 2)
            Utils.SafeSet(Lighting, "ClockTime", 12)
            Utils.SafeSet(Lighting, "EnvironmentDiffuseScale", 0)
            Utils.SafeSet(Lighting, "EnvironmentSpecularScale", 0)
            local c = Config.Render.AmbientColor
            Utils.SafeSet(Lighting, "Ambient", Color3.fromRGB(c[1], c[2], c[3]))
            Utils.SafeSet(Lighting, "OutdoorAmbient", Color3.fromRGB(c[1], c[2], c[3]))
        end
    end)
end
function RenderEngine.ApplyTerrain()
    TaskPool.Enqueue(function()
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            Utils.SafeSet(terrain, "Decoration", false)
            Utils.SafeSet(terrain, "WaterWaveSize", 0)
            Utils.SafeSet(terrain, "WaterWaveSpeed", 0)
            Utils.SafeSet(terrain, "WaterTransparency", 1)
        end
    end)
end
function RenderEngine.ProcessObject(obj)
    TaskPool.Enqueue(function()
        if Utils.IsPlayerPart(obj) then return end
        if obj:IsA("BasePart") then
            Utils.SafeSet(obj, "CastShadow", false)
            Utils.SafeSet(obj, "Reflectance", 0)
            if Config.Materials.FlattenMaterials and (obj.Material == Enum.Material.Glass or obj.Material == Enum.Material.Metal or obj.Material == Enum.Material.Neon) then
                Utils.SafeSet(obj, "Material", Enum.Material.SmoothPlastic)
            end
            if Config.Materials.RemoveTransparency and obj.Transparency > 0 and obj.Transparency < 1 then
                Utils.SafeSet(obj, "Transparency", 0)
            end
            if Config.Physics.DisableDebrisCollisions and obj.Size.Magnitude < 5 then
                Utils.SafeSet(obj, "CanCollide", false)
                Utils.SafeSet(obj, "CanTouch", false)
                Utils.SafeSet(obj, "CanQuery", false)
            end
        elseif obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("SurfaceAppearance") then
            if Config.Materials.RemoveTextures then Utils.SafeDestroy(obj) end
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") then
            if Config.Effects.DisableParticles then Utils.SafeSet(obj, "Enabled", false) end
        elseif obj:IsA("Light") then
            if Config.Effects.DisableLights then Utils.SafeSet(obj, "Enabled", false) end
        elseif obj:IsA("Sound") then
            if Config.Effects.DisableSounds then Utils.SafeDestroy(obj) end
        end
    end)
end
function RenderEngine.ScanAll()
    Logger.Info("Начало глубокого сканирования карты...")
    local descendants = Workspace:GetDescendants()
    for _, obj in ipairs(descendants) do RenderEngine.ProcessObject(obj) end
    Logger.Success("Добавлено в очередь: " .. #descendants .. " объектов.")
end

local CullingEngine = { Active = false }
function CullingEngine.Start()
    if CullingEngine.Active then return end
    CullingEngine.Active = true
    EventManager.Connect(RunService.Heartbeat, function()
        if not Config.Culling.Enabled or not Camera then return end
        local camPos = Camera.CFrame.Position
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Model") and obj.PrimaryPart then
                local dist = (camPos - obj.PrimaryPart.Position).Magnitude
                local hide = dist > Config.Culling.RenderDistance or not (function(pos) 
                    local dir = (pos - camPos).Unit
                    return dir:Dot(Camera.CFrame.LookVector) > 0 
                end)(obj.PrimaryPart.Position)
                for _, part in ipairs(obj:GetDescendants()) do
                    if part:IsA("BasePart") then part.LocalTransparencyModifier = hide and 1 or 0 end
                end
            end
        end
    end)
end

local Profiler = { FPS = 0, Memory = 0, Ping = 0, Entities = 0, History = {} }
function Profiler.Start()
    local frames, lastTime = 0, tick()
    EventManager.Connect(RunService.RenderStepped, function()
        frames = frames + 1
        local currentTime = tick()
        if currentTime - lastTime >= 1 then
            Profiler.FPS = math.floor(frames / (currentTime - lastTime))
            Profiler.Memory = math.floor(Stats:GetTotalMemoryUsageMb())
            Profiler.Entities = #Workspace:GetDescendants()
            pcall(function() Profiler.Ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
            table.insert(Profiler.History, Profiler.FPS)
            if #Profiler.History > 50 then table.remove(Profiler.History, 1) end
            frames, lastTime = 0, currentTime
            if _G.HyperionGUI_v9 and _G.HyperionGUI_v9.UpdateStats then _G.HyperionGUI_v9.UpdateStats(Profiler) end
        end
    end)
end

-- Исправленный поток сборки мусора
task.spawn(function()
    while true do
        local waitTime = Config.Memory and Config.Memory.GCInterval or 30
        task.wait(waitTime)
        if Config.Memory and Config.Memory.AutoGarbageCollect then
            collectgarbage("collect")
            Logger.Info("Автоматическая сборка мусора (GC) выполнена.")
        end
    end
end)

local UI = {}
function UI.CreateToggle(parent, text, defaultState, callback)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 30)
    Btn.BackgroundColor3 = ActiveTheme.Element
    Btn.Text = "  " .. text .. ": " .. (defaultState and "ON" or "OFF")
    Btn.TextColor3 = defaultState and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 100, 100)
    Btn.Font = Enum.Font.Code
    Btn.TextSize = 14
    Btn.TextXAlignment = Enum.TextXAlignment.Left
    Btn.Parent = parent
    local state = defaultState
    Btn.MouseButton1Click:Connect(function()
        state = not state
        Btn.Text = "  " .. text .. ": " .. (state and "ON" or "OFF")
        Btn.TextColor3 = state and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 100, 100)
        callback(state)
    end)
end
function UI.CreateSlider(parent, text, min, max, default, callback)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 40)
    Frame.BackgroundColor3 = ActiveTheme.Element
    Frame.Parent = parent
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 0, 20)
    Label.BackgroundTransparency = 1
    Label.Text = "  " .. text .. ": " .. default
    Label.TextColor3 = ActiveTheme.Text
    Label.Font = Enum.Font.Code
    Label.TextSize = 14
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame
    local SliderBg = Instance.new("Frame")
    SliderBg.Size = UDim2.new(0.9, 0, 0, 5)
    SliderBg.Position = UDim2.new(0.05, 0, 0, 30)
    SliderBg.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    SliderBg.Parent = Frame
    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    Fill.BackgroundColor3 = ActiveTheme.Accent
    Fill.Parent = SliderBg
    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 10, 0, 15)
    Knob.Position = UDim2.new(1, -5, 0.5, -7.5)
    Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Knob.Parent = Fill
    local Dragging = false
    Knob.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then Dragging = true end end)
    UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then Dragging = false end end)
    UserInputService.InputChanged:Connect(function(input)
        if Dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mouseX = input.Position.X
            local sliderAbsX = SliderBg.AbsolutePosition.X
            local sliderAbsWidth = SliderBg.AbsoluteSize.X
            local percent = math.clamp((mouseX - sliderAbsX) / sliderAbsWidth, 0, 1)
            local value = math.floor(min + (max - min) * percent)
            Fill.Size = UDim2.new(percent, 0, 1, 0)
            Label.Text = "  " .. text .. ": " .. value
            callback(value)
        end
    end)
end

local GUI = {}
function GUI.Build()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "HyperionGUI_v9"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = CoreGui
    ScreenGui.Enabled = Config.System.GUIVisible
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 420, 0, 600)
    MainFrame.Position = UDim2.new(0.5, -210, 0.5, -300)
    MainFrame.BackgroundColor3 = ActiveTheme.Background
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui
    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 40)
    TitleBar.BackgroundColor3 = ActiveTheme.TitleBar
    TitleBar.Parent = MainFrame
    local TitleText = Instance.new("TextLabel")
    TitleText.Size = UDim2.new(1, -80, 1, 0)
    TitleText.Position = UDim2.new(0, 15, 0, 0)
    TitleText.BackgroundTransparency = 1
    TitleText.Text = "HYPERION ENGINE v9.1"
    TitleText.TextColor3 = ActiveTheme.Accent
    TitleText.Font = Enum.Font.Code
    TitleText.TextSize = 18
    TitleText.TextXAlignment = Enum.TextXAlignment.Left
    TitleText.Parent = TitleBar
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseBtn.Position = UDim2.new(1, -35, 0, 5)
    CloseBtn.BackgroundColor3 = ActiveTheme.Danger
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.Font = Enum.Font.Code
    CloseBtn.Parent = TitleBar
    CloseBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false; Config.System.GUIVisible = false end)
    local StatsFrame = Instance.new("Frame")
    StatsFrame.Size = UDim2.new(1, -20, 0, 80)
    StatsFrame.Position = UDim2.new(0, 10, 0, 50)
    StatsFrame.BackgroundColor3 = ActiveTheme.Panel
    StatsFrame.Parent = MainFrame
    local StatsLabel = Instance.new("TextLabel")
    StatsLabel.Size = UDim2.new(1, 0, 0, 20)
    StatsLabel.BackgroundTransparency = 1
    StatsLabel.Text = "FPS: -- | MEM: -- | PING: -- | ENT: --"
    StatsLabel.TextColor3 = ActiveTheme.Text
    StatsLabel.Font = Enum.Font.Code
    StatsLabel.TextSize = 14
    StatsLabel.Parent = StatsFrame
    local GraphFrame = Instance.new("Frame")
    GraphFrame.Size = UDim2.new(1, -10, 0, 40)
    GraphFrame.Position = UDim2.new(0, 5, 0, 25)
    GraphFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    GraphFrame.BorderSizePixel = 0
    GraphFrame.Parent = StatsFrame
    local bars = {}
    for i = 1, 50 do
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0.02, -1, 0, 0)
        bar.Position = UDim2.new(i * 0.02, 0, 1, 0)
        bar.BackgroundColor3 = ActiveTheme.Accent
        bar.AnchorPoint = Vector2.new(0, 1)
        bar.Parent = GraphFrame
        table.insert(bars, bar)
    end
    local TabBar = Instance.new("Frame")
    TabBar.Size = UDim2.new(1, -20, 0, 30)
    TabBar.Position = UDim2.new(0, 10, 0, 140)
    TabBar.BackgroundColor3 = ActiveTheme.Panel
    TabBar.Parent = MainFrame
    local TabList = Instance.new("UIListLayout")
    TabList.FillDirection = Enum.FillDirection.Horizontal
    TabList.Padding = UDim.new(0, 5)
    TabList.Parent = TabBar
    local ContentFrame = Instance.new("Frame")
    ContentFrame.Size = UDim2.new(1, -20, 1, -260)
    ContentFrame.Position = UDim2.new(0, 10, 0, 180)
    ContentFrame.BackgroundColor3 = ActiveTheme.Panel
    ContentFrame.Parent = MainFrame
    local ContentList = Instance.new("UIListLayout")
    ContentList.Padding = UDim.new(0, 5)
    ContentList.Parent = ContentFrame
    local tabs = {}
    local currentTab = nil
    local function SwitchTab(tabName)
        for _, frame in pairs(ContentFrame:GetChildren()) do
            if frame:IsA("Frame") or frame:IsA("ScrollingFrame") then frame.Visible = false end
        end
        if tabs[tabName] then tabs[tabName].Visible = true; currentTab = tabName end
    end
    local tabNames = {"Render", "Effects", "Culling", "Config"}
    for _, name in ipairs(tabNames) do
        local TabBtn = Instance.new("TextButton")
        TabBtn.Size = UDim2.new(0.23, 0, 1, 0)
        TabBtn.BackgroundColor3 = ActiveTheme.Element
        TabBtn.Text = name
        TabBtn.TextColor3 = ActiveTheme.Text
        TabBtn.Font = Enum.Font.Code
        TabBtn.TextSize = 12
        TabBtn.Parent = TabBar
        TabBtn.MouseButton1Click:Connect(function() SwitchTab(name) end)
        local TabContent = Instance.new("ScrollingFrame")
        TabContent.Size = UDim2.new(1, 0, 1, 0)
        TabContent.BackgroundTransparency = 1
        TabContent.BorderSizePixel = 0
        TabContent.ScrollBarThickness = 4
        TabContent.Visible = false
        TabContent.Parent = ContentFrame
        local Layout = Instance.new("UIListLayout")
        Layout.Padding = UDim.new(0, 5)
        Layout.Parent = TabContent
        tabs[name] = TabContent
    end
    UI.CreateToggle(tabs["Render"], "Disable Shadows", Config.Render.DisableShadows, function(s) Config.Render.DisableShadows = s end)
    UI.CreateToggle(tabs["Render"], "Flatten Materials", Config.Materials.FlattenMaterials, function(s) Config.Materials.FlattenMaterials = s end)
    UI.CreateToggle(tabs["Render"], "Remove Textures", Config.Materials.RemoveTextures, function(s) Config.Materials.RemoveTextures = s end)
    UI.CreateToggle(tabs["Render"], "Kill Transparency", Config.Materials.RemoveTransparency, function(s) Config.Materials.RemoveTransparency = s end)
    UI.CreateToggle(tabs["Effects"], "Disable Particles", Config.Effects.DisableParticles, function(s) Config.Effects.DisableParticles = s end)
    UI.CreateToggle(tabs["Effects"], "Disable Sounds", Config.Effects.DisableSounds, function(s) Config.Effects.DisableSounds = s end)
    UI.CreateToggle(tabs["Effects"], "Disable Lights", Config.Effects.DisableLights, function(s) Config.Effects.DisableLights = s end)
    UI.CreateToggle(tabs["Culling"], "Enable Culling", Config.Culling.Enabled, function(s) Config.Culling.Enabled = s end)
    UI.CreateSlider(tabs["Culling"], "Distance", 100, 2000, Config.Culling.RenderDistance, function(v) Config.Culling.RenderDistance = v end)
    UI.CreateSlider(tabs["Culling"], "Chunk Size", 50, 500, Config.Culling.ChunkSize, function(v) Config.Culling.ChunkSize = v end)
    local SaveBtn = Instance.new("TextButton")
    SaveBtn.Size = UDim2.new(1, 0, 0, 40)
    SaveBtn.BackgroundColor3 = Color3.fromRGB(40, 150, 40)
    SaveBtn.Text = "SAVE SETTINGS"
    SaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    SaveBtn.Font = Enum.Font.Code
    SaveBtn.Parent = tabs["Config"]
    SaveBtn.MouseButton1Click:Connect(function() SettingsManager.Save() end)
    local LoadBtn = Instance.new("TextButton")
    LoadBtn.Size = UDim2.new(1, 0, 0, 40)
    LoadBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 150)
    LoadBtn.Text = "LOAD SETTINGS"
    LoadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    LoadBtn.Font = Enum.Font.Code
    LoadBtn.Parent = tabs["Config"]
    LoadBtn.MouseButton1Click:Connect(function() SettingsManager.Load() end)
    local CleanBtn = Instance.new("TextButton")
    CleanBtn.Size = UDim2.new(1, -20, 0, 40)
    CleanBtn.Position = UDim2.new(0, 10, 1, -60)
    CleanBtn.BackgroundColor3 = ActiveTheme.Danger
    CleanBtn.Text = "APPLY OPTIMIZATION NOW"
    CleanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CleanBtn.Font = Enum.Font.Code
    CleanBtn.TextSize = 14
    CleanBtn.Parent = MainFrame
    CleanBtn.MouseButton1Click:Connect(function()
        RenderEngine.ApplyLighting()
        RenderEngine.ApplyTerrain()
        RenderEngine.ScanAll()
        collectgarbage("collect")
        _G.HyperionNotify("System", "Оптимизация применена!", 2)
    end)
    SwitchTab("Render")
    _G.HyperionGUI_v9 = {
        UpdateStats = function(data)
            StatsLabel.Text = string.format("FPS: %d | MEM: %d MB | PING: %d ms | ENT: %d", data.FPS, data.Memory, data.Ping, data.Entities)
            StatsLabel.TextColor3 = data.FPS < 60 and ActiveTheme.Danger or ActiveTheme.Accent
            for i, fps in ipairs(data.History) do
                local bar = bars[i]
                if bar then
                    local height = math.clamp(fps / 240, 0, 1)
                    bar.Size = UDim2.new(0.02, -1, height, 0)
                    bar.BackgroundColor3 = fps < 30 and ActiveTheme.Danger or (fps < 60 and Color3.fromRGB(255, 200, 0) or ActiveTheme.Accent)
                end
            end
        end,
        Toggle = function() MainFrame.Visible = not MainFrame.Visible; Config.System.GUIVisible = MainFrame.Visible end
    }
    Logger.Success("GUI успешно создано.")
end

local function Main()
    local startTime = tick()
    Logger.Info("========================================")
    Logger.Info("ЗАПУСК HYPERION ENGINE v" .. Config.System.Version)
    Logger.Info("========================================")
    if Config.System.AutoLoadConfig then SettingsManager.Load() end
    ActiveTheme = Themes[Config.System.Theme] or Themes.Dark
    Notifications.Init()
    RenderEngine.ApplyLighting()
    RenderEngine.ApplyTerrain()
    RenderEngine.ScanAll()
    CullingEngine.Start()
    Profiler.Start()
    GUI.Build()
    EventManager.Connect(UserInputService.InputBegan, function(input, gp)
        if gp then return end
        if input.KeyCode == Config.System.ToggleKey then
            if _G.HyperionGUI_v9 and _G.HyperionGUI_v9.Toggle then _G.HyperionGUI_v9.Toggle() end
        end
    end)
    Logger.Success(string.format("Движок запущен за %.2f секунд!", tick() - startTime))
    task.delay(1, function() _G.HyperionNotify("Hyperion v9.1", "Успешно загружено! Нажми RightShift.", 5) end)
end

-- ИСПРАВЛЕНИЕ: Теперь ошибка не скроется, а вылезет в консоль F9
local success, err = pcall(Main)
if not success then
    warn("[Hyperion] КРИТИЧЕСКАЯ ОШИБКА ПРИ ЗАПУСКЕ: " .. tostring(err))
end
