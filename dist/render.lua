_G.ApplyLighting = function()
    local Lighting = game:GetService("Lighting")
    
    -- Убираем старое небо
    for _, v in pairs(Lighting:GetChildren()) do
        if v:IsA("Sky") or v:IsA("Atmosphere") or v:IsA("Clouds") or v:IsA("PostEffect") then
            v:Destroy()
        end
    end

    -- Отключаем тяжелые тени
    Lighting.GlobalShadows = false
    Lighting.Brightness = 2
    Lighting.ClockTime = 12
    Lighting.ExposureCompensation = 0
    Lighting.EnvironmentDiffuseScale = 0.5
    Lighting.EnvironmentSpecularScale = 0.2
    Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)
    Lighting.Ambient = Color3.fromRGB(100, 100, 100)

    -- Наш "фейковый" облегченный свет
    local cc = Instance.new("ColorCorrectionEffect")
    cc.Brightness = 0.1
    cc.Contrast = 0.2
    cc.Saturation = 0.3
    cc.TintColor = Color3.fromRGB(255, 245, 230)
    cc.Parent = Lighting

    local atm = Instance.new("Atmosphere")
    atm.Density = 0.1
    atm.Haze = 0.5
    atm.Color = Color3.fromRGB(200, 200, 200)
    atm.Decay = Color3.fromRGB(150, 150, 150)
    atm.Parent = Lighting
end 

_G.ApplyMaterials = function()
    local Workspace = game:GetService("Workspace")
    
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.CastShadow = false
            obj.Reflectance = 0
            
            -- Убиваем стекло и металл
            if obj.Material == Enum.Material.Glass or obj.Material == Enum.Material.Metal or obj.Material == Enum.Material.Neon then
                obj.Material = Enum.Material.SmoothPlastic
            end
            
            -- УБИРАЕМ ПРОЗРАЧНОСТЬ (Overdraw Killer)
            if not obj.Parent:FindFirstChild("Humanoid") then
                if obj.Transparency > 0 and obj.Transparency < 1 then
                    obj.Transparency = 0 -- Делаем сплошным
                end
            end
        end
    end
end 

_G.StartOptimizer = function()
    local Workspace = game:GetService("Workspace")
    
    -- 1. Отключаем лампочки, частицы и звуки
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Light") then
            obj.Enabled = false
        end
        if (obj:IsA("ParticleEmitter") or obj:IsA("Trail")) and not obj.Parent:FindFirstChild("Humanoid") then
            if obj:IsA("ParticleEmitter") then obj.Enabled = false end
            if obj:IsA("Trail") then obj.Enabled = false end
        end
        if obj:IsA("Sound") then
            obj:Destroy()
        end
    end

    -- 2. Следим за новыми объектами (если карта подгружается)
    Workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("Light") then
            obj.Enabled = false
        elseif obj:IsA("BasePart") then
            obj.CastShadow = false
            -- Если появилось новое прозрачное стекло
            if obj.Transparency > 0 and obj.Transparency < 1 and not obj.Parent:FindFirstChild("Humanoid") then
                obj.Transparency = 0
            end
        elseif obj:IsA("Sound") then
            obj:Destroy()
        end
    end)
end 

-- Инициализация
print("[Render] Инициализация тяжелой очистки...")

if _G.ApplyLighting then _G.ApplyLighting() end
if _G.ApplyMaterials then _G.ApplyMaterials() end
if _G.StartOptimizer then _G.StartOptimizer() end

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Smart Render",
    Text = "Тени, стекла и звуки отключены.",
    Duration = 5
})

print("[Render] Готово.")
