_G.ApplyLighting = function()
    local Lighting = game:GetService("Lighting")
    
    -- Убираем всё лишнее (небо, атмосферу, постобработку)
    for _, v in pairs(Lighting:GetChildren()) do
        if v:IsA("Sky") or v:IsA("Atmosphere") or v:IsA("Clouds") or v:IsA("PostEffect") then
            v:Destroy()
        end
    end

    -- ФОРСИРУЕМ САМУЮ СЛАБУЮ ГРАФИКУ (Voxel / Compatibility)
    pcall(function()
        Lighting.Technology = Enum.Technology.Compatibility 
    end)

    -- Отключаем тяжелые тени и настраиваем плоский свет
    Lighting.GlobalShadows = false
    Lighting.Brightness = 2
    Lighting.ClockTime = 12
    Lighting.ExposureCompensation = 0
    Lighting.EnvironmentDiffuseScale = 0
    Lighting.EnvironmentSpecularScale = 0
    Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)
    Lighting.Ambient = Color3.fromRGB(100, 100, 100)

    -- Наш "фейковый" облегченный свет (чтобы не было темно)
    local cc = Instance.new("ColorCorrectionEffect")
    cc.Brightness = 0.1
    cc.Contrast = 0.1
    cc.Saturation = 0.1
    cc.Parent = Lighting
end 
