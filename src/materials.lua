_G.ApplyMaterials = function()
    local Workspace = game:GetService("Workspace")
    
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.CastShadow = false
            obj.Reflectance = 0
            if obj.Material == Enum.Material.Glass or obj.Material == Enum.Material.Metal or obj.Material == Enum.Material.Neon then
                obj.Material = Enum.Material.SmoothPlastic
            end
        end
    end
end