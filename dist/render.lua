--[[
================================================================================
   HYPERION ENGINE v14 (EXTREME EDITION)
   Объем: ~538 строк.
   Включает: Frustum Culling, FPS Limiter, Freeze Physics, UI Tabs, Live Logs.
================================================================================
]]

-- ============================================================================
-- 1. СЕРВИСЫ
-- ============================================================================
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============================================================================
-- 2. КОНФИГУРАЦИЯ
-- ============================================================================
local Config = {
    Render = {
        Enabled = true,
        DisableShadows = true,
        RemoveAtmosphere = true,
        FlattenMaterials = true,
        RemoveTransparency = true,
    },
    Physics = {
        Enabled = true,
        FreezeDebris = true,
        DisableCollisions = true,
    },
    Memory = {
        Enabled = true,
        RemoveTextures = true,
        RemoveSounds = true,
        DisableParticles = true,
    },
    Culling = {
        Enabled = false,
        RenderDistance = 500,
        FrustumCheck = true,
    },
    FPS = {
        LimitEnabled = false,
        LimitValue = 60,
    }
}

-- Цветовая тема
local Theme = {
    Bg = Color3.fromRGB(15, 15, 20),
    Panel = Color3.fromRGB(22, 22, 30),
    Element = Color3.fromRGB(35, 35, 45),
    Text = Color3.fromRGB(220, 220, 220),
    Accent = Color3.fromRGB(0, 255, 180),
    Danger = Color3.fromRGB(255, 60, 60),
}

-- Статистика
local StatsData = {
    FPS = 60,
    Memory = 0,
    CleanedParts = 0,
    RemovedTextures = 0,
    FrozenParts = 0
}

-- ============================================================================
-- 3. УТИЛИТЫ И ЛОГГЕР
-- ============================================================================
local LogUI = nil
local function Log(msg, color)
    color = color or Theme.Text
    local formatted = string.format("[Hyperion] %s", msg)
    print(formatted)
    
    if LogUI then
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 16)
        label.BackgroundTransparency = 1
        label.Text = os.date("%H:%M:%S ") .. msg
        label.TextColor3 = color
        label.Font = Enum.Font.Code
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = LogUI
        LogUI.CanvasSize = UDim2.new(0, 0, 0, #LogUI:GetChildren() * 16)
        LogUI.CanvasPosition = Vector2.new(0, LogUI.CanvasSize.Y.Offset)
    end
end

local function IsPlayerPart(obj)
    local p = obj
    while p do
        if p:IsA("Model") and p:FindFirstChildOfClass("Humanoid") then return true end
        p = p.Parent
    end
    return false
end

local function SafeSet(obj, prop, val)
    if obj and obj.Parent then pcall(function() obj[prop] = val end) end
end

local function SafeDestroy(obj)
    if obj and obj.Parent then pcall(function() obj:Destroy() end) end
end

-- ============================================================================
-- 4. МОДУЛЬ РЕНДЕРА (GPU)
-- ============================================================================
local function OptimizeRender()
    if not Config.Render.Enabled then return end
    Log("Оптимизация рендера (GPU)...", Theme.Accent)
    
    if Config.Render.DisableShadows then
        SafeSet(Lighting, "GlobalShadows", false)
        SafeSet(Lighting, "Technology", Enum.Technology.Compatibility)
        SafeSet(Lighting, "Brightness", 2)
        SafeSet(Lighting, "EnvironmentDiffuseScale", 0)
        SafeSet(Lighting, "EnvironmentSpecularScale", 0)
    end
    
    if Config.Render.RemoveAtmosphere then
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("PostEffect") or v:IsA("Atmosphere") or v:IsA("Clouds") then
                SafeDestroy(v)
            end
        end
    end
end

-- ============================================================================
-- 5. МОДУЛЬ ПАМЯТИ И ФИЗИКИ (CPU/RAM)
-- ============================================================================
local function ProcessObject(obj)
    if IsPlayerPart(obj) then return end
    
    -- GPU / Рендер
    if obj:IsA("BasePart") then
        SafeSet(obj, "CastShadow", false)
        SafeSet(obj, "Reflectance", 0)
        
        if Config.Render.FlattenMaterials and (obj.Material == Enum.Material.Glass or obj.Material == Enum.Material.Metal or obj.Material == Enum.Material.Neon) then
            SafeSet(obj, "Material", Enum.Material.SmoothPlastic)
        end
        
        if Config.Render.RemoveTransparency and obj.Transparency > 0 and obj.Transparency < 1 then
            SafeSet(obj, "Transparency", 0)
        end
        
        -- Физика (CPU)
        if Config.Physics.Enabled then
            if Config.Physics.FreezeDebris and obj.Size.Magnitude < 6 and not obj.Anchored then
                SafeSet(obj, "Anchored", true)
                StatsData.FrozenParts += 1
            end
            if Config.Physics.DisableCollisions and obj.Size.Magnitude < 6 then
                SafeSet(obj, "CanCollide", false)
                SafeSet(obj, "CanTouch", false)
                SafeSet(obj, "CanQuery", false)
            end
        end
        
    -- RAM (Текстуры и Звуки)
    elseif obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("SurfaceAppearance") then
        if Config.Memory.RemoveTextures then
            SafeDestroy(obj)
            StatsData.RemovedTextures += 1
        end
    elseif obj:IsA("Sound") then
        if Config.Memory.RemoveSounds then SafeDestroy(obj) end
    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") then
        if Config.Memory.DisableParticles then SafeSet(obj, "Enabled", false) end
    elseif obj:IsA("Light") then
        SafeSet(obj, "Enabled", false)
    end
    
    StatsData.CleanedParts += 1
end

local function ScanWorld()
    Log("Запуск глубокого сканирования...", Theme.Warning)
    OptimizeRender()
    
    task.spawn(function()
        local descendants = Workspace:GetDescendants()
        for i, obj in ipairs(descendants) do
            ProcessObject(obj)
            if i % 1000 == 0 then task.wait() end -- Защита от фризов
        end
        Log("Сканирование завершено! Объектов: " .. #descendants, Theme.Accent)
        collectgarbage("collect")
    end)
end

-- ============================================================================
-- 6. СИСТЕМА CULLING (Отсечение)
-- ============================================================================
local function IsInFrustum(pos)
    if not Config.Culling.FrustumCheck then return true end
    local camPos = Camera.CFrame.Position
    local lookVec = Camera.CFrame.LookVector
    local dirToObj = (pos - camPos).Unit
    return dirToObj:Dot(lookVec) > 0 -- Проверка, находится ли объект спереди
end

task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        if Config.Culling.Enabled and Camera then
            local camPos = Camera.CFrame.Position
            for _, obj in ipairs(Workspace:GetChildren()) do
                if obj:IsA("Model") and obj.PrimaryPart then
                    local pos = obj.PrimaryPart.Position
                    local dist = (camPos - pos).Magnitude
                    
                    local hide = false
                    if dist > Config.Culling.RenderDistance then hide = true end
                    if not IsInFrustum(pos) then hide = true end
                    
                    for _, part in ipairs(obj:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.LocalTransparencyModifier = hide and 1 or 0
                        end
                    end
                end
            end
        end
    end
end)

-- ============================================================================
-- 7. ОГРАНИЧИТЕЛЬ FPS
-- ============================================================================
local fpsLimitClock = tick()
RunService.RenderStepped:Connect(function()
    if Config.FPS.LimitEnabled then
        local targetTime = 1 / Config.FPS.LimitValue
        local elapsed = tick() - fpsLimitClock
        if elapsed < targetTime then
            task.wait(targetTime - elapsed)
        end
        fpsLimitClock = tick()
    end
end)

-- ============================================================================
-- 8. ПРОФАЙЛЕР
-- ============================================================================
local function StartProfiler()
    local frames, lastTime = 0, tick()
    RunService.RenderStepped:Connect(function()
        frames += 1
        local currentTime = tick()
        if currentTime - lastTime >= 1 then
            StatsData.FPS = math.floor(frames / (currentTime - lastTime))
            StatsData.Memory = math.floor(Stats:GetTotalMemoryUsageMb())
            frames, lastTime = 0, currentTime
            if _G.UpdateHyperionUI then _G.UpdateHyperionUI() end
        end
    end)
end

-- ============================================================================
-- 9. АВТО-КЛИНЕР
-- ============================================================================
Workspace.DescendantAdded:Connect(function(obj)
    task.wait(0.1)
    ProcessObject(obj)
end)

-- ============================================================================
-- 10. UI БИБЛИОТЕКА
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
-- 11. СОЗДАНИЕ МЕНЮ
-- ============================================================================
local function CreateGUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "HyperionMenu"
    gui.ResetOnSpawn = false
    gui.Parent = CoreGui

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 420, 0, 500)
    main.Position = UDim2.new(0.5, -210, 0.5, -250)
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
    title.Text = "HYPERION v14 (EXTREME)"
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
    statsLabel.Text = "FPS: ... | MEM: ..."
    statsLabel.TextColor3 = Theme.Text
    statsLabel.Font = Enum.Font.Code
    statsLabel.TextSize = 13
    statsLabel.Parent = statsPanel

    -- Вкладки
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -20, 0, 25)
    tabBar.Position = UDim2.new(0, 10, 0, 105)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = main
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 5)
    tabLayout.Parent = tabBar

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -20, 1, -190)
    content.Position = UDim2.new(0, 10, 0, 140)
    content.BackgroundColor3 = Theme.Panel
    content.Parent = main

    local pages = {}
    local function SwitchPage(pageName)
        for _, p in pairs(content:GetChildren()) do
            if p:IsA("ScrollingFrame") then p.Visible = false end
        end
        if pages[pageName] then pages[pageName].Visible = true end
    end

    local tabs = {"Render", "Physics", "Culling", "Logs"}
    for _, tabName in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.23, -3, 1, 0)
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
    CreateToggle(pages["Render"], "Shadows", Config.Render.DisableShadows, function(s) Config.Render.DisableShadows = s ScanWorld() end)
    CreateToggle(pages["Render"], "Atmosphere", Config.Render.RemoveAtmosphere, function(s) Config.Render.RemoveAtmosphere = s ScanWorld() end)
    CreateToggle(pages["Render"], "Textures", Config.Memory.RemoveTextures, function(s) Config.Memory.RemoveTextures = s ScanWorld() end)
    CreateToggle(pages["Render"], "Transparency", Config.Render.RemoveTransparency, function(s) Config.Render.RemoveTransparency = s ScanWorld() end)

    -- Вкладка Physics
    CreateToggle(pages["Physics"], "Freeze Debris", Config.Physics.FreezeDebris, function(s) Config.Physics.FreezeDebris = s ScanWorld() end)
    CreateToggle(pages["Physics"], "Disable Collisions", Config.Physics.DisableCollisions, function(s) Config.Physics.DisableCollisions = s ScanWorld() end)
    CreateToggle(pages["Physics"], "Remove Sounds", Config.Memory.RemoveSounds, function(s) Config.Memory.RemoveSounds = s ScanWorld() end)

    -- Вкладка Culling
    CreateToggle(pages["Culling"], "Enable Culling", Config.Culling.Enabled, function(s) Config.Culling.Enabled = s end)
    CreateToggle(pages["Culling"], "Frustum Check", Config.Culling.FrustumCheck, function(s) Config.Culling.FrustumCheck = s end)
    CreateSlider(pages["Culling"], "Distance", 100, 2000, Config.Culling.RenderDistance, function(v) Config.Culling.RenderDistance = v end)
    CreateToggle(pages["Culling"], "FPS Limit", Config.FPS.LimitEnabled, function(s) Config.FPS.LimitEnabled = s end)
    CreateSlider(pages["Culling"], "FPS Target", 30, 240, Config.FPS.LimitValue, function(v) Config.FPS.LimitValue = v end)

    -- Вкладка Logs
    LogUI = Instance.new("ScrollingFrame")
    LogUI.Size = UDim2.new(1, 0, 1, 0)
    LogUI.BackgroundTransparency = 1
    LogUI.BorderSizePixel = 0
    LogUI.ScrollBarThickness = 4
    LogUI.Parent = pages["Logs"]

    -- Кнопка Apply
    local applyBtn = Instance.new("TextButton")
    applyBtn.Size = UDim2.new(1, -20, 0, 35)
    applyBtn.Position = UDim2.new(0, 10, 1, -45)
    applyBtn.BackgroundColor3 = Theme.Accent
    applyBtn.Text = "ПРИМЕНИТЬ ВСЁ"
    applyBtn.TextColor3 = Theme.Bg
    applyBtn.Font = Enum.Font.Code
    applyBtn.TextSize = 14
    applyBtn.Parent = main
    applyBtn.MouseButton1Click:Connect(function() ScanWorld() end)

    SwitchPage("Render")

    -- Обновление UI
    _G.UpdateHyperionUI = function()
        statsLabel.Text = string.format("FPS: %d | MEM: %d MB | Cleaned: %d", StatsData.FPS, StatsData.Memory, StatsData.CleanedParts)
        statsLabel.TextColor3 = StatsData.FPS < 60 and Theme.Danger or Theme.Accent
    end
end

-- ============================================================================
-- 12. СТАРТ
-- ============================================================================
local function Main()
    Log("Запуск v14 Extreme...", Theme.Accent)
    CreateGUI()
    StartProfiler()
    
    task.wait(1)
    ScanWorld()
    
    UserInputService.InputBegan:Connect(function(input, gp)
        if not gp and input.KeyCode == Enum.KeyCode.RightShift then
            local gui = CoreGui:FindFirstChild("HyperionMenu")
            if gui and gui:FindFirstChildOfClass("Frame") then
                gui.Frame.Visible = not gui.Frame.Visible
            end
        end
    end)
end

pcall(Main)
