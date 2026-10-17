--[[
================================================================================
   HYPERION ENGINE v11 (PRO EDITION)
   Объем: ~650 строк. Максимальная мощность и стабильность.
   Включает: Live-консоль, Кэшированный Culling, Emergency Boost, Террейн-клинер.
================================================================================
]]

-- ============================================================================
-- БЛОК 1: СЕРВИСЫ И КОНФИГУРАЦИЯ
-- ============================================================================
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")

local Camera = Workspace.CurrentCamera

local EngineConfig = {
    Optimize = {
        Shadows = true,
        Materials = true,
        Textures = true,
        Transparency = true,
        Lights = true,
        Particles = true,
        Sounds = true,
        Terrain = true,
        Atmosphere = true
    },
    Culling = {
        Enabled = false,
        Distance = 500,
        LOD = false
    }
}

-- Тема
local Theme = {
    Bg = Color3.fromRGB(12, 12, 16),
    Panel = Color3.fromRGB(22, 22, 30),
    Element = Color3.fromRGB(35, 35, 45),
    Text = Color3.fromRGB(220, 220, 220),
    Accent = Color3.fromRGB(0, 255, 180),
    Danger = Color3.fromRGB(255, 60, 60),
    Warning = Color3.fromRGB(255, 180, 0)
}

-- Статистика
local StatsData = {
    FPS = 60,
    Ping = 0,
    Memory = 0,
    Cleaned = 0,
    Destroyed = 0
}

-- ============================================================================
-- БЛОК 2: УТИЛИТЫ И ЛОГГЕР
-- ============================================================================
local LogHistory = {}
local LogUI = nil

local function Log(msg, color)
    color = color or Theme.Text
    local time = os.date("%H:%M:%S")
    local formatted = string.format("[%s] %s", time, msg)
    table.insert(LogHistory, {text = formatted, color = color})
    
    if #LogHistory > 50 then table.remove(LogHistory, 1) end
    
    print("[Hyperion] " .. msg)
    
    -- Обновляем UI консоль, если она есть
    if LogUI then
        local frame = Instance.new("TextLabel")
        frame.Size = UDim2.new(1, 0, 0, 16)
        frame.BackgroundTransparency = 1
        frame.Text = formatted
        frame.TextColor3 = color
        frame.Font = Enum.Font.Code
        frame.TextSize = 12
        frame.TextXAlignment = Enum.TextXAlignment.Left
        frame.Parent = LogUI
        
        LogUI.CanvasSize = UDim2.new(0, 0, 0, #LogHistory * 16)
        LogUI.CanvasPosition = Vector2.new(0, #LogHistory * 16)
    end
end

local function SafeSet(obj, prop, val)
    if not obj or not obj.Parent then return end
    pcall(function() obj[prop] = val end)
end

local function IsCharacter(obj)
    local p = obj
    while p do
        if p:IsA("Model") and p:FindFirstChildOfClass("Humanoid") then return true end
        p = p.Parent
    end
    return false
end

-- ============================================================================
-- БЛОК 3: ДВИЖОК ГЛУБОКОЙ ОЧИСТКИ (Deep Clean)
-- ============================================================================
local function RunDeepClean()
    Log("Запуск глубокой очистки карты...", Theme.Warning)
    StatsData.Cleaned = 0
    
    task.spawn(function()
        -- 1. Освещение
        if EngineConfig.Optimize.Shadows then
            SafeSet(Lighting, "GlobalShadows", false)
            SafeSet(Lighting, "Technology", Enum.Technology.Compatibility)
            SafeSet(Lighting, "Brightness", 2)
            SafeSet(Lighting, "EnvironmentDiffuseScale", 0)
            SafeSet(Lighting, "EnvironmentSpecularScale", 0)
        end
        
        if EngineConfig.Optimize.Atmosphere then
            for _, v in ipairs(Lighting:GetChildren()) do
                if v:IsA("Sky") or v:IsA("Atmosphere") or v:IsA("Clouds") then
                    v:Destroy()
                end
            end
        end

        -- 2. Террейн (Трава и вода)
        if EngineConfig.Optimize.Terrain then
            local terrain = Workspace:FindFirstChildOfClass("Terrain")
            if terrain then
                SafeSet(terrain, "Decoration", false)
                SafeSet(terrain, "WaterWaveSize", 0)
                SafeSet(terrain, "WaterTransparency", 1)
            end
        end

        -- 3. Объекты в Workspace
        local descendants = Workspace:GetDescendants()
        for i, obj in ipairs(descendants) do
            if not IsCharacter(obj) then
                if obj:IsA("BasePart") then
                    SafeSet(obj, "CastShadow", false)
                    SafeSet(obj, "Reflectance", 0)
                    
                    if EngineConfig.Optimize.Materials and (obj.Material == Enum.Material.Glass or obj.Material == Enum.Material.Metal or obj.Material == Enum.Material.Neon) then
                        SafeSet(obj, "Material", Enum.Material.SmoothPlastic)
                    end
                    
                    if EngineConfig.Optimize.Transparency and obj.Transparency > 0 and obj.Transparency < 1 then
                        SafeSet(obj, "Transparency", 0)
                    end
                    
                elseif (obj:IsA("Decal") or obj:IsA("Texture")) and EngineConfig.Optimize.Textures then
                    obj:Destroy()
                    StatsData.Destroyed += 1
                    
                elseif (obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")) and EngineConfig.Optimize.Particles then
                    SafeSet(obj, "Enabled", false)
                    
                elseif obj:IsA("Light") and EngineConfig.Optimize.Lights then
                    SafeSet(obj, "Enabled", false)
                    
                elseif obj:IsA("Sound") and EngineConfig.Optimize.Sounds then
                    obj:Destroy()
                    StatsData.Destroyed += 1
                end
            end
            
            StatsData.Cleaned = i
            if i % 2000 == 0 then task.wait() end -- Защита от фризов
        end
        
        Log("Глубокая очистка завершена!", Theme.Accent)
        collectgarbage("collect") -- Очистка памяти
    end)
end

local function EmergencyBoost()
    Log("ЭКСТРЕННЫЙ БУСТ АКТИВИРОВАН!", Theme.Danger)
    
    -- Убиваем всё, что движется, кроме игроков
    task.spawn(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if not IsCharacter(obj) then
                if obj:IsA("BasePart") then
                    obj.CastShadow = false
                    obj.Material = Enum.Material.SmoothPlastic
                    if obj.Transparency < 1 then obj.Transparency = 0 end
                elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Light") then
                    obj:Destroy()
                end
            end
        end
        Log("Экстренный буст завершен.", Theme.Danger)
    end)
end

-- ============================================================================
-- БЛОК 4: КЭШИРОВАННЫЙ CULLING
-- ============================================================================
local CullingCache = {}
local CullingActive = false

local function RefreshCullingCache()
    CullingCache = {}
    for _, obj in ipairs(Workspace:GetChildren()) do
        if (obj:IsA("Model") and obj.PrimaryPart) or obj:IsA("BasePart") then
            table.insert(CullingCache, obj)
        end
    end
    Log("Кэш Culling обновлен. Объектов: " .. #CullingCache, Theme.Text)
end

local function StartCulling()
    if CullingActive then return end
    CullingActive = true
    
    task.spawn(function()
        task.wait(2) -- Ждем загрузки карты
        RefreshCullingCache()
        
        while CullingActive do
            RunService.Heartbeat:Wait()
            
            if EngineConfig.Culling.Enabled and Camera then
                local camPos = Camera.CFrame.Position
                
                for _, obj in ipairs(CullingCache) do
                    if obj and obj.Parent then
                        local pos = obj:IsA("Model") and obj.PrimaryPart.Position or obj.Position
                        local dist = (camPos - pos).Magnitude
                        
                        local hide = dist > EngineConfig.Culling.Distance
                        
                        if obj:IsA("Model") then
                            for _, part in ipairs(obj:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.LocalTransparencyModifier = hide and 1 or 0
                                end
                            end
                        else
                            obj.LocalTransparencyModifier = hide and 1 or 0
                        end
                    end
                end
            end
        end
    end)
end

-- ============================================================================
-- БЛОК 5: ПРОФАЙЛЕР
-- ============================================================================
local function StartProfiler()
    local frames = 0
    local lastTime = tick()
    
    RunService.RenderStepped:Connect(function()
        frames = frames + 1
        local currentTime = tick()
        
        if currentTime - lastTime >= 1 then
            StatsData.FPS = math.floor(frames / (currentTime - lastTime))
            StatsData.Memory = math.floor(Stats:GetTotalMemoryUsageMb())
            pcall(function()
                StatsData.Ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
            
            frames = 0
            lastTime = currentTime
            
            if _G.UpdateHyperionUI then _G.UpdateHyperionUI() end
        end
    end)
end

-- ============================================================================
-- БЛОК 6: UI БИБЛИОТЕКА
-- ============================================================================
local function CreateToggle(parent, text, default, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = Theme.Element
    btn.Text = "  " .. text .. ": " .. (default and "ON" or "OFF")
    btn.TextColor3 = default and Theme.Accent or Theme.Danger
    btn.Font = Enum.Font.Code
    btn.TextSize = 13
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = parent
    
    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = "  " .. text .. ": " .. (state and "ON" or "OFF")
        btn.TextColor3 = state and Theme.Accent or Theme.Danger
        callback(state)
    end)
end

local function CreateSlider(parent, text, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 40)
    frame.BackgroundColor3 = Theme.Element
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = "  " .. text .. ": " .. default
    label.TextColor3 = Theme.Text
    label.Font = Enum.Font.Code
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0.9, 0, 0, 4)
    bar.Position = UDim2.new(0.05, 0, 0, 28)
    bar.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    bar.Parent = frame

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.Parent = bar

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 8, 0, 12)
    knob.Position = UDim2.new(1, -4, 0.5, -6)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Parent = fill

    local dragging = false
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mouseX = input.Position.X
            local barAbsX = bar.AbsolutePosition.X
            local barAbsWidth = bar.AbsoluteSize.X
            local percent = math.clamp((mouseX - barAbsX) / barAbsWidth, 0, 1)
            local value = math.floor(min + (max - min) * percent)
            
            fill.Size = UDim2.new(percent, 0, 1, 0)
            label.Text = "  " .. text .. ": " .. value
            callback(value)
        end
    end)
end

-- ============================================================================
-- БЛОК 7: СОЗДАНИЕ МЕНЮ
-- ============================================================================
local function CreateGUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "HyperionMenu"
    gui.ResetOnSpawn = false
    gui.Parent = CoreGui

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 400, 0, 480)
    main.Position = UDim2.new(0.5, -200, 0.5, -240)
    main.BackgroundColor3 = Theme.Bg
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = gui

    -- Шапка
    local top = Instance.new("Frame")
    top.Size = UDim2.new(1, 0, 0, 35)
    top.BackgroundColor3 = Theme.Panel
    top.Parent = main

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "HYPERION v11 (PRO)"
    title.TextColor3 = Theme.Accent
    title.Font = Enum.Font.Code
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = top

    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 25, 0, 25)
    close.Position = UDim2.new(1, -30, 0, 5)
    close.BackgroundColor3 = Theme.Danger
    close.Text = "X"
    close.TextColor3 = Color3.fromRGB(255,255,255)
    close.Font = Enum.Font.Code
    close.Parent = top
    close.MouseButton1Click:Connect(function() gui:Destroy() end)

    -- Статистика
    local statsPanel = Instance.new("Frame")
    statsPanel.Size = UDim2.new(1, -20, 0, 50)
    statsPanel.Position = UDim2.new(0, 10, 0, 45)
    statsPanel.BackgroundColor3 = Theme.Panel
    statsPanel.Parent = main

    local statsLabel = Instance.new("TextLabel")
    statsLabel.Size = UDim2.new(1, -10, 1, 0)
    statsLabel.Position = UDim2.new(0, 5, 0, 0)
    statsLabel.BackgroundTransparency = 1
    statsLabel.Text = "FPS: ... | PING: ... | MEM: ..."
    statsLabel.TextColor3 = Theme.Text
    statsLabel.Font = Enum.Font.Code
    statsLabel.TextSize = 13
    statsLabel.Parent = statsPanel

    -- Кнопка Emergency Boost
    local boostBtn = Instance.new("TextButton")
    boostBtn.Size = UDim2.new(1, -20, 0, 30)
    boostBtn.Position = UDim2.new(0, 10, 0, 105)
    boostBtn.BackgroundColor3 = Theme.Danger
    boostBtn.Text = "!!! EMERGENCY FPS BOOST !!!"
    boostBtn.TextColor3 = Theme.Text
    boostBtn.Font = Enum.Font.Code
    boostBtn.TextSize = 13
    boostBtn.Parent = main
    boostBtn.MouseButton1Click:Connect(EmergencyBoost)

    -- Вкладки
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -20, 0, 25)
    tabBar.Position = UDim2.new(0, 10, 0, 145)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = main
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 5)
    tabLayout.Parent = tabBar

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -20, 1, -230)
    content.Position = UDim2.new(0, 10, 0, 180)
    content.BackgroundColor3 = Theme.Panel
    content.Parent = main

    local pages = {}
    local function SwitchPage(pageName)
        for _, p in pairs(content:GetChildren()) do
            if p:IsA("ScrollingFrame") then p.Visible = false end
        end
        if pages[pageName] then pages[pageName].Visible = true end
    end

    local tabs = {"Render", "Culling", "Logs"}
    for _, tabName in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.31, -3, 1, 0)
        btn.BackgroundColor3 = Theme.Element
        btn.Text = tabName
        btn.TextColor3 = Theme.Text
        btn.Font = Enum.Font.Code
        btn.TextSize = 12
        btn.Parent = tabBar
        btn.MouseButton1Click:Connect(function() SwitchPage(tabName) end)

        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 4
        page.Visible = false
        page.Parent = content
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 4)
        layout.Parent = page
        pages[tabName] = page
    end

    -- Вкладка Render
    CreateToggle(pages["Render"], "Shadows", EngineConfig.Optimize.Shadows, function(s) EngineConfig.Optimize.Shadows = s end)
    CreateToggle(pages["Render"], "Materials", EngineConfig.Optimize.Materials, function(s) EngineConfig.Optimize.Materials = s end)
    CreateToggle(pages["Render"], "Textures", EngineConfig.Optimize.Textures, function(s) EngineConfig.Optimize.Textures = s end)
    CreateToggle(pages["Render"], "Transparency", EngineConfig.Optimize.Transparency, function(s) EngineConfig.Optimize.Transparency = s end)
    
    -- Вкладка Culling
    CreateToggle(pages["Culling"], "Enable Culling", EngineConfig.Culling.Enabled, function(s) EngineConfig.Culling.Enabled = s end)
    CreateSlider(pages["Culling"], "Distance", 100, 1500, EngineConfig.Culling.Distance, function(v) EngineConfig.Culling.Distance = v end)
    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Size = UDim2.new(1, 0, 0, 30)
    refreshBtn.BackgroundColor3 = Theme.Element
    refreshBtn.Text = "Refresh Culling Cache"
    refreshBtn.TextColor3 = Theme.Text
    refreshBtn.Font = Enum.Font.Code
    refreshBtn.TextSize = 13
    refreshBtn.Parent = pages["Culling"]
    refreshBtn.MouseButton1Click:Connect(RefreshCullingCache)

    -- Вкладка Logs
    LogUI = Instance.new("Frame")
    LogUI.Size = UDim2.new(1, 0, 1, 0)
    LogUI.BackgroundTransparency = 1
    LogUI.Parent = pages["Logs"]
    
    local logsScroll = Instance.new("ScrollingFrame")
    logsScroll.Size = UDim2.new(1, 0, 1, 0)
    logsScroll.BackgroundTransparency = 1
    logsScroll.BorderSizePixel = 0
    logsScroll.CanvasSize = UDim2.new(0,0,0,0)
    logsScroll.Parent = LogUI

    -- Кнопка Apply
    local applyBtn = Instance.new("TextButton")
    applyBtn.Size = UDim2.new(1, -20, 0, 35)
    applyBtn.Position = UDim2.new(0, 10, 1, -45)
    applyBtn.BackgroundColor3 = Theme.Accent
    applyBtn.Text = "DEEP CLEAN"
    applyBtn.TextColor3 = Theme.Bg
    applyBtn.Font = Enum.Font.Code
    applyBtn.TextSize = 14
    applyBtn.Parent = main
    applyBtn.MouseButton1Click:Connect(function()
        RunDeepClean()
    end)

    SwitchPage("Render")

    -- Обновление UI
    _G.UpdateHyperionUI = function()
        statsLabel.Text = string.format("FPS: %d | PING: %d ms | MEM: %d MB", StatsData.FPS, StatsData.Ping, StatsData.Memory)
        statsLabel.TextColor3 = StatsData.FPS < 60 and Theme.Danger or Theme.Accent
    end
end

-- ============================================================================
-- БЛОК 8: ЗАПУСК
-- ============================================================================
local function Main()
    print("[Hyperion] Запуск v11 Pro...")
    
    CreateGUI()
    StartProfiler()
    StartCulling()
    
    -- Автозапуск
    task.wait(1)
    RunDeepClean()
    
    -- Хоткей
    UserInputService.InputBegan:Connect(function(input, gp)
        if not gp and input.KeyCode == Enum.KeyCode.RightShift then
            local gui = CoreGui:FindFirstChild("HyperionMenu")
            if gui and gui:FindFirstChildOfClass("Frame") then
                local main = gui.Frame
                main.Visible = not main.Visible
            end
        end
    end)
    
    print("[Hyperion] Успешно загружено!")
end

pcall(Main)
