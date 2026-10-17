--[[
================================================================================
   ULTIMATE RENDER & PERFORMANCE ENGINE (v3.0)
   Полная переработка рендера, физики и памяти для Roblox.
   Оптимизировано для слабых ПК и встроенной графики (Intel UHD и т.д.)
================================================================================
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

-- ============================================================================
-- БЛОК 1: КОНФИГУРАЦИЯ (Меняй по своему вкусу)
-- ============================================================================
local Config = {
    -- Освещение
    DisableShadows = true,
    ForceLowestLightingTech = true, -- Переключить на Voxel/Compatibility
    DisableLocalLights = true,
    DisablePostProcessing = true,
    FlattenLighting = true,

    -- Материалы и Текстуры
    RemoveTextures = true,          -- Удалять все Decal и Texture
    FlattenMaterials = true,        -- Превращать все в гладкий пластик
    RemoveTransparency = true,      -- Убирать прозрачность (Overdraw)
    DisableNeonAndGlass = true,     -- Убирать светящиеся и стеклянные детали

    -- Террейн (Природа)
    DisableTerrainDecoration = true,-- Убирать траву
    DisableWaterWaves = true,       -- Убирать волны на воде

    -- Эффекты
    DisableParticles = true,
    DisableTrails = true,
    DisableBeams = true,

    -- Звуки (Освобождает RAM)
    DestroySounds = true,

    -- Физика (Снижает нагрузку на CPU)
    DisableUnneededCollisions = true,
    AnchorDebris = false,           -- ВНИМАНИЕ: Может сломать геймплей, если включить

    -- Оптимизация дальности
    EnableDistantCulling = false,   -- Скрывать объекты вдали (требует времени на просчет)
    CullingDistance = 500,          -- Дистанция отсечения

    -- Производительность
    ContinuousCleanup = true,       -- Следить за новыми объектами
    AggressiveMemoryClean = true    -- Форсировать сборку мусора
}

-- Внутренние переменные для статистики
local Stats = {
    PartsOptimized = 0,
    LightsDisabled = 0,
    TexturesRemoved = 0,
    SoundsDestroyed = 0,
    ParticlesDisabled = 0,
    TotalScanned = 0
}

print("[Ultimate Render] Инициализация... Пожалуйста, подождите.")

-- ============================================================================
-- БЛОК 2: ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ И ПРОВЕРКИ
-- ============================================================================

-- Проверка: является ли объект частью персонажа игрока
-- (Чтобы мы случайно не удалили звуки прыжка или текстуры лица игрока)
local function IsCharacterPart(obj)
    local parent = obj
    while parent do
        if parent:IsA("Model") and parent:FindFirstChildOfClass("Humanoid") then
            return true
        end
        parent = parent.Parent
    end
    return false
end

-- Безопасное изменение свойства (защита от read-only)
local function SafeSet(obj, prop, value)
    pcall(function()
        obj[prop] = value
    end)
end

-- ============================================================================
-- БЛОК 3: МОДУЛЬ ОСВЕЩЕНИЯ (Lighting)
-- ============================================================================
local function OptimizeLighting()
    print("[Render] Настройка освещения...")
    
    -- Удаляем небо, туман и постобработку
    if Config.DisablePostProcessing then
        for _, v in pairs(Lighting:GetChildren()) do
            if v:IsA("PostEffect") or v:IsA("Atmosphere") or v:IsA("Clouds") or v:IsA("Sky") then
                v:Destroy()
            end
        end
    end

    -- Форсируем старый метод освещения (ShadowMap -> Voxel)
    if Config.ForceLowestLightingTech then
        SafeSet(Lighting, "Technology", Enum.Technology.Compatibility)
    end

    -- Отключаем тени и выравниваем свет
    if Config.DisableShadows then
        SafeSet(Lighting, "GlobalShadows", false)
    end

    if Config.FlattenLighting then
        SafeSet(Lighting, "Brightness", 2)
        SafeSet(Lighting, "ClockTime", 12)
        SafeSet(Lighting, "ExposureCompensation", 0)
        SafeSet(Lighting, "EnvironmentDiffuseScale", 0)
        SafeSet(Lighting, "EnvironmentSpecularScale", 0)
        SafeSet(Lighting, "OutdoorAmbient", Color3.fromRGB(150, 150, 150))
        SafeSet(Lighting, "Ambient", Color3.fromRGB(100, 100, 100))
        SafeSet(Lighting, "FogEnd", 100000)
    end
end

-- ============================================================================
-- БЛОК 4: МОДУЛЬ ТЕРРЕЙНА (Трава и Вода)
-- ============================================================================
local function OptimizeTerrain()
    print("[Render] Оптимизация террейна...")
    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    
    if terrain then
        if Config.DisableTerrainDecoration then
            SafeSet(terrain, "Decoration", false) -- Убивает траву
        end
        
        if Config.DisableWaterWaves then
            SafeSet(terrain, "WaterWaveSize", 0)
            SafeSet(terrain, "WaterWaveSpeed", 0)
            SafeSet(terrain, "WaterTransparency", 1)
        end
    end
end

-- ============================================================================
-- БЛОК 5: МОДУЛЬ ОПТИМИЗАЦИИ ОБЪЕКТОВ (Part, Mesh, Light, FX)
-- ============================================================================
local function OptimizeObject(obj)
    Stats.TotalScanned = Stats.TotalScanned + 1
    local isPlayer = IsCharacterPart(obj)

    -- Оптимизация деталей (Parts)
    if obj:IsA("BasePart") and not isPlayer then
        if Config.DisableShadows then
            SafeSet(obj, "CastShadow", false)
        end
        
        if Config.FlattenMaterials then
            SafeSet(obj, "Reflectance", 0)
            if obj.Material == Enum.Material.Glass or obj.Material == Enum.Material.Metal then
                SafeSet(obj, "Material", Enum.Material.SmoothPlastic)
            end
        end
        
        if Config.DisableNeonAndGlass and obj.Material == Enum.Material.Neon then
            SafeSet(obj, "Material", Enum.Material.SmoothPlastic)
        end
        
        if Config.RemoveTransparency and obj.Transparency > 0 and obj.Transparency < 1 then
            SafeSet(obj, "Transparency", 0)
        end
        
        Stats.PartsOptimized = Stats.PartsOptimized + 1

    -- Оптимизация текстур (Decals, Textures)
    elseif (obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("SurfaceAppearance")) and not isPlayer then
        if Config.RemoveTextures then
            obj:Destroy()
            Stats.TexturesRemoved = Stats.TexturesRemoved + 1
        end

    -- Оптимизация источников света
    elseif obj:IsA("Light") and not isPlayer then
        if Config.DisableLocalLights then
            SafeSet(obj, "Enabled", false)
            Stats.LightsDisabled = Stats.LightsDisabled + 1
        end

    -- Оптимизация частиц
    elseif (obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire")) and not isPlayer then
        if Config.DisableParticles then
            SafeSet(obj, "Enabled", false)
            Stats.ParticlesDisabled = Stats.ParticlesDisabled + 1
        end

    -- Оптимизация лучей и трейлов
    elseif (obj:IsA("Trail") or obj:IsA("Beam")) and not isPlayer then
        if Config.DisableTrails then
            SafeSet(obj, "Enabled", false)
        end

    -- Уничтожение звуков
    elseif obj:IsA("Sound") and not isPlayer then
        if Config.DestroySounds then
            obj:Destroy()
            Stats.SoundsDestroyed = Stats.SoundsDestroyed + 1
        end
    end
end

-- ============================================================================
-- БЛОК 6: МОДУЛЬ ФИЗИКИ (Снижение нагрузки на CPU)
-- ============================================================================
local function OptimizePhysics()
    print("[Render] Оптимизация физики...")
    
    -- Отключаем коллизии для мелочи
    if Config.DisableUnneededCollisions then
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not IsCharacterPart(obj) then
                SafeSet(obj, "CanTouch", false)
                SafeSet(obj, "CanQuery", false)
                if obj.Size.Magnitude < 5 then
                    SafeSet(obj, "CanCollide", false)
                end
            end
        end
    end
end

-- ============================================================================
-- БЛОК 7: БЕЗОПАСНАЯ ОЧИСТКА ПАМЯТИ
-- ============================================================================
local function CleanMemory()
    if Config.AggressiveMemoryClean then
        pcall(function()
            collectgarbage("collect")
            collectgarbage("count")
        end)
    end
end

-- ============================================================================
-- БЛОК 8: ГЛАВНЫЙ ЦИКЛ СКАНИРОВАНИЯ (В отдельном потоке, чтобы не лагало)
-- ============================================================================
local function ScanWorkspace()
    local allObjects = Workspace:GetDescendants()
    
    for i, obj in ipairs(allObjects) do
        OptimizeObject(obj)
    end
end

-- ============================================================================
-- БЛОК 9: WATCHDOG (Слежка за новыми объектами)
-- ============================================================================
local function StartWatchdog()
    if not Config.ContinuousCleanup then return end
    
    Workspace.DescendantAdded:Connect(function(obj)
        -- Ждем 0.1 секунды, чтобы объект успел инициализироваться
        task.wait(0.1) 
        OptimizeObject(obj)
    end)
end

-- ============================================================================
-- БЛОК 10: ЗАПУСК
-- ============================================================================
task.spawn(function()
    local startTime = os.clock()
    
    -- 1. Освещение и Террейн
    OptimizeLighting()
    OptimizeTerrain()
    
    -- 2. Тяжелое сканирование (в фоне)
    ScanWorkspace()
    
    -- 3. Физика
    OptimizePhysics()
    
    -- 4. Включаем слежку
    StartWatchdog()
    
    -- 5. Очистка памяти
    CleanMemory()
    
    -- Итоговый отчет
    local execTime = math.floor((os.clock() - startTime) * 1000)
    
    local report = string.format(
        "[Ultimate Render] Оптимизация завершена за %d мс!\n" ..
        "----------------------------------------\n" ..
        "Всего просканировано: %d объектов\n" ..
        "Деталей оптимизировано: %d\n" ..
        "Текстур удалено: %d\n" ..
        "Лампочек выключено: %d\n" ..
        "Частиц выключено: %d\n" ..
        "Звуков уничтожено: %d\n" ..
        "----------------------------------------",
        execTime, Stats.TotalScanned, Stats.PartsOptimized, 
        Stats.TexturesRemoved, Stats.LightsDisabled, 
        Stats.ParticlesDisabled, Stats.SoundsDestroyed
    )
    
    print(report)
    
    StarterGui:SetCore("SendNotification", {
        Title = "Ultimate Render",
        Text = "Готово! Оптимизировано объектов: " .. Stats.PartsOptimized,
        Duration = 5
    })
end)
