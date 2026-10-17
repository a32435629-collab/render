_G.StartOptimizer = function()
    local Workspace = game:GetService("Workspace")
    
    -- 1. Отключаем лампочки, частицы и звуки
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Light") then
            obj.Enabled = false
        end
        if (obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam")) and not obj.Parent:FindFirstChild("Humanoid") then
            obj.Enabled = false
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
        elseif obj:IsA("Sound") then
            obj:Destroy()
        elseif obj:IsA("Texture") or obj:IsA("Decal") then
            obj:Destroy()
        end
    end)
end 
