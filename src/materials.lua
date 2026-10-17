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
            -- Если это не персонаж, делаем деталь полностью непрозрачной
            if not obj.Parent:FindFirstChild("Humanoid") then
                if obj.Transparency > 0 and obj.Transparency < 1 then
                    obj.Transparency = 0 -- Делаем сплошным
                end
            end
        end
    end
end
