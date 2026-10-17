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