_G.StartOptimizer = function()
    local Workspace = game:GetService("Workspace")
    
    -- 1. Отключаем лампочки и тени
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Light") then
            obj.Enabled = false
        end
        -- Выключаем частицы, если это не эффект игрока
        if (obj:IsA("ParticleEmitter") or obj:IsA("Trail")) and not obj.Parent:FindFirstChild("Humanoid") then
            if obj:IsA("ParticleEmitter") then obj.Enabled = false end
            if obj:IsA("Trail") then obj.Enabled = false end
        end
        -- Уничтожаем звуки (чтобы не грузили память)
        if obj:IsA("Sound") then
            obj:Destroy()
        end
    end

    -- 2. Следим за новыми объектами
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
