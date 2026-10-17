-- ==========================================
-- HYPERION ENGINE v10 (LIGHTWEIGHT & STABLE)
-- ==========================================
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")

local Config = {
    DisableShadows = true,
    DisableTextures = true,
    DisableSounds = true,
    DisableLights = true,
}

-- 1. УДАЛЕНИЕ ТЕКСТУР И СВЕТА
local function OptimizeWorld()
    -- Освещение
    if Config.DisableShadows then
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.Brightness = 2
            Lighting.Technology = Enum.Technology.Compatibility
        end)
    end
    
    -- Объекты
    for _, obj in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            -- Проверка на игрока (чтобы не сломать перса)
            local isPlayer = false
            local parent = obj
            while parent do
                if parent:IsA("Model") and parent:FindFirstChildOfClass("Humanoid") then
                    isPlayer = true break
                end
                parent = parent.Parent
            end

            if not isPlayer then
                if obj:IsA("BasePart") then
                    if Config.DisableShadows then obj.CastShadow = false end
                    obj.Reflectance = 0
                    if obj.Transparency > 0 and obj.Transparency < 1 then
                        obj.Transparency = 0 -- Убираем стекла (Overdraw)
                    end
                elseif obj:IsA("Texture") or obj:IsA("Decal") then
                    if Config.DisableTextures then obj:Destroy() end
                elseif obj:IsA("Sound") then
                    if Config.DisableSounds then obj:Destroy() end
                elseif obj:IsA("Light") then
                    if Config.DisableLights then obj.Enabled = false end
                elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                    obj.Enabled = false
                end
            end
        end)
    end
    print("[Hyperion] Оптимизация завершена!")
end

-- 2. МЕНЮ
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HyperionMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 250, 0, 180)
Frame.Position = UDim2.new(0.5, -125, 0.5, -90)
Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Frame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
Title.Text = "HYPERION v10"
Title.TextColor3 = Color3.fromRGB(0, 255, 200)
Title.Font = Enum.Font.Code
Title.Parent = Frame

local FPSLabel = Instance.new("TextLabel")
FPSLabel.Size = UDim2.new(1, 0, 0, 30)
FPSLabel.Position = UDim2.new(0, 0, 0, 30)
FPSLabel.Text = "FPS: ..."
FPSLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
FPSLabel.BackgroundTransparency = 1
FPSLabel.Font = Enum.Font.Code
FPSLabel.Parent = Frame

local ApplyBtn = Instance.new("TextButton")
ApplyBtn.Size = UDim2.new(0.9, 0, 0, 40)
ApplyBtn.Position = UDim2.new(0.05, 0, 0, 70)
ApplyBtn.BackgroundColor3 = Color3.fromRGB(40, 150, 40)
ApplyBtn.Text = "ВКЛЮЧИТЬ ОПТИМИЗАЦИЮ"
ApplyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ApplyBtn.Font = Enum.Font.Code
ApplyBtn.Parent = Frame
ApplyBtn.MouseButton1Click:Connect(OptimizeWorld)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0.9, 0, 0, 30)
CloseBtn.Position = UDim2.new(0.05, 0, 0, 120)
CloseBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
CloseBtn.Text = "Закрыть"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.Code
CloseBtn.Parent = Frame
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

-- 3. FPS СЧЕТЧИК
local frames = 0
RunService.RenderStepped:Connect(function()
    frames = frames + 1
    if frames % 60 == 0 then -- Обновляем раз в секунду
        FPSLabel.Text = "FPS: " .. math.floor(1 / RunService.RenderStepped:Wait())
    end
end)

-- 4. СКРЫТИЕ МЕНЮ НА RIGHT SHIFT
UserInputService.InputBegan:Connect(function(input, gp)
    if not gp and input.KeyCode == Enum.KeyCode.RightShift then
        Frame.Visible = not Frame.Visible
    end
end)

-- 5. АВТОЗАПУСК ПРИ СТАРТЕ
OptimizeWorld()
