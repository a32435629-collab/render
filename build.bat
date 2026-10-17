@echo off
chcp 65001 > nul
echo Сборка модуля Render...

if not exist dist mkdir dist
type nul > dist\render.lua

type src\lighting.lua >> dist\render.lua
echo. >> dist\render.lua
type src\materials.lua >> dist\render.lua
echo. >> dist\render.lua
type src\optimizer.lua >> dist\render.lua
echo. >> dist\render.lua
type src\init.lua >> dist\render.lua

echo УСПЕХ! Файл dist\render.lua собран.
pause
