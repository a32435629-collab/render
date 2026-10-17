_G.StartOptimizer = function()
    local Workspace = game:GetService("Workspace")
    
    -- Удаляем существующие лампочки
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Light") then
            obj.Enabled = false
        end
    end

    -- Следим за новыми объектами (если карта подгружается)
    Workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("Light") then
            obj.Enabled = false
        elseif obj:IsA("BasePart") then
            obj.CastShadow = false
        end
    end)
end