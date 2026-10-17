_G.ApplyMaterials = function()
    local Workspace = game:GetService("Workspace")
    local Terrain = Workspace:FindFirstChildOfClass("Terrain")
    
    -- Убиваем траву и волны на террейне (это жрет кучу ресурсов)
    if Terrain then
        pcall(function()
            Terrain.Decoration = false -- Отключает траву
            Terrain.WaterWaveSize = 0
            Terrain.WaterWaveSpeed = 0
            Terrain.WaterTransparency = 1
        end)
    end

    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.CastShadow = false
            obj.Reflectance = 0
            
            -- Убиваем стекло, металл и неон
            if obj.Material == Enum.Material.Glass or obj.Material == Enum.Material.Metal or obj.Material == Enum.Material.Neon then
                obj.Material = Enum.Material.SmoothPlastic
            end
            
            -- УБИРАЕМ ПРОЗРАЧНОСТЬ (Overdraw Killer)
            if not obj.Parent:FindFirstChild("Humanoid") then
                if obj.Transparency > 0 and obj.Transparency < 1 then
                    obj.Transparency = 0 
                end
            end
        elseif obj:IsA("Texture") or obj:IsA("Decal") or obj:IsA("SurfaceAppearance") then
            -- Удаляем все текстуры с карты (они занимают видеопамять)
            obj:Destroy()
        end
    end
end 
