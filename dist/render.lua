--[[
================================================================================
   HYPERION ENGINE v10.5 (BALANCED EDITION)
   Объем: ~450 строк. Идеальный баланс между функционалом и стабильностью.
   Включает: UI с вкладками, Culling, Оптимизацию и Профайлер.
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
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Настройки по умолчанию
local Config = {
    Render = {
        DisableShadows = true,
        RemoveTextures = true,
        KillTransparency = true,
        FlattenMaterials = true,
    },
    Effects = {
        DisableParticles = true,
        DisableSounds = true,
        DisableLights = true,
    },
    Culling = {
        Enabled = false,
        Distance = 400, -- Дистанция скрытия объектов
    }
}

-- Тема интерфейса
local Theme = {
    Bg = Color3.fromRGB(15, 15, 20),
    Panel = Color3.fromRGB(20, 20, 28),
    Element = Color3.fromRGB(35, 35, 45),
    Text = Color3.fromRGB(220, 220, 220),
    Accent = Color3.fromRGB(0, 255, 180),
    Danger = Color3.fromRGB(255, 60, 60)
}

-- ============================================================================
-- БЛОК 2: УТИЛИТЫ И ХЕЛПЕРЫ
-- ============================================================================
local function IsPlayerPart(obj)
    local parent = obj
    while parent do
        if parent:IsA("Model") and parent:FindFirstChildOfClass("Humanoid") then
            return true
        end
        parent = parent.Parent
    end
    return false
end

local function SafeSet(obj, prop, val)
    if not obj or not obj.Parent then return end
    pcall(function() obj[prop] = val end)
end

local function SafeDestroy(obj)
    if not obj or not obj.Parent then return end
    pcall(function() obj:Destroy() end)
end

-- ============================================================================
-- БЛОК 3: ДВИЖОК ОПТИМИЗАЦИИ
-- ============================================================================
local function OptimizeWorld()
    print("[Hyperion] Запуск оптимизации карты...")
    
    -- 1. Освещение
    if Config.Render.DisableShadows then
        SafeSet(Lighting, "GlobalShadows", false)
        SafeSet(Lighting, "Technology", Enum.Technology.Compatibility)
        SafeSet(Lighting, "Brightness", 2)
        SafeSet(Lighting, "ClockTime", 12)
    end
    
    -- Удаление постобработки
    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA("PostEffect") or v:IsA("Atmosphere") then
            SafeDestroy(v)
        end
    end

    -- 2. Террейн (Трава/Вода)
    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        SafeSet(terrain, "Decoration", false)
        SafeSet(terrain, "WaterWaveSize", 0)
        SafeSet(terrain, "WaterTransparency", 1)
    end

    -- 3. Обработка объектов (в отдельном потоке, чтобы не вешать игру)
    task.spawn(function()
        local count = 0
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if not IsPlayerPart(obj) then
                -- Детали
                if obj:IsA("BasePart") then
                    SafeSet(obj, "CastShadow", false)
                    SafeSet(obj, "Reflectance", 0)
                    
                    if Config.Render.FlattenMaterials then
                        if obj.Material == Enum.Material.Glass or obj.Material == Enum.Material.Metal or obj.Material == Enum.Material.Neon then
                            SafeSet(obj, "Material", Enum.Material.SmoothPlastic)
                        end
                    end
                    
                    if Config.Render.KillTransparency and obj.Transparency > 0 and obj.Transparency < 1 then
                        SafeSet(obj, "Transparency", 0)
                    end
                    
                -- Текстуры
                elseif obj:IsA("Decal") or obj:IsA("Texture") then
                    if Config.Render.RemoveTextures then SafeDestroy(obj) end
                    
                -- Эффекты
                elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
                    if Config.Effects.DisableParticles then SafeSet(obj, "Enabled", false) end
                    
                -- Звуки
                elseif obj:IsA("Sound") then
                    if Config.Effects.DisableSounds then SafeDestroy(obj) end
                    
                -- Свет
                elseif obj:IsA("Light") then
                    if Config.Effects.DisableLights then SafeSet(obj, "Enabled", false) end
                end
            end
            
            count = count + 1
            -- Каждые 1000 объектов даем движку продохнуть
            if count % 1000 == 0 then task.wait() end
        end
        print("[Hyperion] Оптимизировано объектов: " .. count)
    end)
end

-- ============================================================================
-- БЛОК 4: СИСТЕМА CULLING (Скрытие объектов вдали)
-- ============================================================================
local cullingActive = false

local function StartCulling()
    if cullingActive then return end
    cullingActive = true
    
    task.spawn(function()
        while cullingActive do
            RunService.Heartbeat:Wait()
            
            if Config.Culling.Enabled and Camera then
                local camPos = Camera.CFrame.Position
                
                for _, obj in ipairs(Workspace:GetChildren()) do
                    if obj:IsA("Model") and obj.PrimaryPart then
                        local dist = (camPos - obj.PrimaryPart.Position).Magnitude
                        
                        -- Проверяем дистанцию
                        if dist > Config.Culling.Distance then
                            for _, part in ipairs(obj:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.LocalTransparencyModifier = 1
                                end
                            end
                        else
                            for _, part in ipairs(obj:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.LocalTransparencyModifier = 0
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- ============================================================================
-- БЛОК 5: ПРОФАЙЛЕР (FPS и Память)
-- ============================================================================
local Profiler = {
    FPS = 60,
    Memory = 0
}

local function StartProfiler()
    local frames = 0
    local lastTime = tick()
    
    RunService.RenderStepped:Connect(function()
        frames = frames + 1
        local currentTime = tick()
        
        if currentTime - lastTime >= 1 then
            Profiler.FPS = math.floor(frames / (currentTime - lastTime))
            Profiler.Memory = math.floor(Stats:GetTotalMemoryUsageMb())
            
            frames = 0
            lastTime = currentTime
            
            -- Обновляем UI, если он существует
            if _G.HyperionUpdateStats then
                _G.HyperionUpdateStats()
            end
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
    btn.TextSize = 14
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
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0.9, 0, 0, 5)
    bar.Position = UDim2.new(0.05, 0, 0, 30)
    bar.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    bar.Parent = frame

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.Parent = bar

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 10, 0, 15)
    knob.Position = UDim2.new(1, -5, 0.5, -7.5)
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

    -- Главное окно
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 350, 0, 400)
    main.Position = UDim2.new(0.5, -175, 0.5, -200)
    main.BackgroundColor3 = Theme.Bg
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = gui

    -- Заголовок
    local title = Instance.new("Frame")
    title.Size = UDim2.new(1, 0, 0, 35)
    title.BackgroundColor3 = Theme.Panel
    title.Parent = main

    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, -40, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "HYPERION v10.5"
    titleText.TextColor3 = Theme.Accent
    titleText.Font = Enum.Font.Code
    titleText.TextSize = 16
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = title

    -- Кнопка закрытия
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -30, 0, 5)
    closeBtn.BackgroundColor3 = Theme.Danger
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
    closeBtn.Font = Enum.Font.Code
    closeBtn.Parent = title
    closeBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
    end)

    -- Панель статистики (FPS)
    local statsPanel = Instance.new("Frame")
    statsPanel.Size = UDim2.new(1, -20, 0, 40)
    statsPanel.Position = UDim2.new(0, 10, 0, 45)
    statsPanel.BackgroundColor3 = Theme.Panel
    statsPanel.Parent = main

    local statsLabel = Instance.new("TextLabel")
    statsLabel.Size = UDim2.new(1, 0, 1, 0)
    statsLabel.BackgroundTransparency = 1
    statsLabel.Text = "FPS: ... | MEM: ..."
    statsLabel.TextColor3 = Theme.Text
    statsLabel.Font = Enum.Font.Code
    statsLabel.TextSize = 14
    statsLabel.Parent = statsPanel

    -- Вкладки (кнопки)
    local tabPanel = Instance.new("Frame")
    tabPanel.Size = UDim2.new(1, -20, 0, 30)
    tabPanel.Position = UDim2.new(0, 10, 0, 95)
    tabPanel.BackgroundTransparency = 1
    tabPanel.Parent = main
    
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 5)
    tabLayout.Parent = tabPanel

    -- Контент
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -20, 1, -180)
    content.Position = UDim2.new(0, 10, 0, 135)
    content.BackgroundColor3 = Theme.Panel
    content.Parent = main

    -- Страницы
    local pages = {}
    local currentPage = nil

    local function SwitchPage(pageName)
        for _, frame in pairs(content:GetChildren()) do
            if frame:IsA("ScrollingFrame") then frame.Visible = false end
        end
        if pages[pageName] then
            pages[pageName].Visible = true
            currentPage = pageName
        end
    end

    local tabs = {"Render", "Culling", "Debug"}
    for _, tabName in ipairs(tabs) do
        local tabBtn = Instance.new("TextButton")
        tabBtn.Size = UDim2.new(0.3, -3, 1, 0)
        tabBtn.BackgroundColor3 = Theme.Element
        tabBtn.Text = tabName
        tabBtn.TextColor3 = Theme.Text
        tabBtn.Font = Enum.Font.Code
        tabBtn.TextSize = 12
        tabBtn.Parent = tabPanel
        tabBtn.MouseButton1Click:Connect(function() SwitchPage(tabName) end)

        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 4
        page.Visible = false
        page.Parent = content
        
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 5)
        layout.Parent = page
        
        pages[tabName] = page
    end

    -- Заполнение вкладок
    CreateToggle(pages["Render"], "Disable Shadows", Config.Render.DisableShadows, function(s) Config.Render.DisableShadows = s end)
    CreateToggle(pages["Render"], "Remove Textures", Config.Render.RemoveTextures, function(s) Config.Render.RemoveTextures = s end)
    CreateToggle(pages["Render"], "Kill Transparency", Config.Render.KillTransparency, function(s) Config.Render.KillTransparency = s end)
    CreateToggle(pages["Render"], "Flatten Materials", Config.Render.FlattenMaterials, function(s) Config.Render.FlattenMaterials = s end)

    CreateToggle(pages["Culling"], "Enable Culling", Config.Culling.Enabled, function(s) Config.Culling.Enabled = s end)
    CreateSlider(pages["Culling"], "Distance", 100, 1500, Config.Culling.Distance, function(v) Config.Culling.Distance = v end)

    CreateToggle(pages["Debug"], "Disable Sounds", Config.Effects.DisableSounds, function(s) Config.Effects.DisableSounds = s end)
    CreateToggle(pages["Debug"], "Disable Particles", Config.Effects.DisableParticles, function(s) Config.Effects.DisableParticles = s end)
    CreateToggle(pages["Debug"], "Disable Lights", Config.Effects.DisableLights, function(s) Config.Effects.DisableLights = s end)

    -- Кнопка применения
    local applyBtn = Instance.new("TextButton")
    applyBtn.Size = UDim2.new(1, -20, 0, 35)
    applyBtn.Position = UDim2.new(0, 10, 1, -45)
    applyBtn.BackgroundColor3 = Theme.Accent
    applyBtn.Text = "ПРИМЕНИТЬ ОПТИМИЗАЦИЮ"
    applyBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
    applyBtn.Font = Enum.Font.Code
    applyBtn.TextSize = 14
    applyBtn.Parent = main
    applyBtn.MouseButton1Click:Connect(function()
        OptimizeWorld()
        applyBtn.Text = "ПРИМЕНЕНО!"
        task.wait(2)
        applyBtn.Text = "ПРИМЕНИТЬ ОПТИМИЗАЦИЮ"
    end)

    -- Запускаем первую вкладку
    SwitchPage("Render")

    -- Обновление статистики
    _G.HyperionUpdateStats = function()
        statsLabel.Text = string.format("FPS: %d | MEM: %d MB", Profiler.FPS, Profiler.Memory)
        statsLabel.TextColor3 = Profiler.FPS < 60 and Theme.Danger or Theme.Accent
    end
end

-- ============================================================================
-- БЛОК 8: ЗАПУСК СИСТЕМ
-- ============================================================================
local function Main()
    print("[Hyperion] Загрузка v10.5...")
    
    CreateGUI()
    StartProfiler()
    StartCulling()
    
    -- Автоматическая оптимизация при старте
    OptimizeWorld()
    
    -- Хоткей для скрытия меню
    UserInputService.InputBegan:Connect(function(input, gp)
        if not gp and input.KeyCode == Enum.KeyCode.RightShift then
            local gui = CoreGui:FindFirstChild("HyperionMenu")
            if gui and gui:FindFirstChildOfClass("Frame") then
                local main = gui.Frame
                main.Visible = not main.Visible
            end
        end
    end)
    
    print("[Hyperion] Успешно запущено!")
end

pcall(Main)
