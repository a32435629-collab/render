print("[Render] Инициализация ядерной очистки...")

if _G.ApplyLighting then _G.ApplyLighting() end
if _G.ApplyMaterials then _G.ApplyMaterials() end
if _G.StartOptimizer then _G.StartOptimizer() end

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Smart Render",
    Text = "Ядерная оптимизация включена. FPS должен взлететь!",
    Duration = 5
})

print("[Render] Готово.")
