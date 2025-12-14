--!native
--!optimize 2
--[[
    ╔══════════════════════════════════════════════╗
    ║  ULTRA SAVE INSTANCE v2.0                   ║
    ║  Copia juegos completos listos para publicar ║
    ║  https://discord.gg/wx4ThpAsmw              ║
    ╚══════════════════════════════════════════════╝
]]

-- ============================================
-- CACHÉ DE FUNCIONES GLOBALES (Rendimiento)
-- ============================================
local game_GetService = game.GetService
local game_FindService = game.FindService
local Instance_new = Instance.new
local table_create, table_concat, table_insert, table_clear, table_move, table_sort = 
    table.create, table.concat, table.insert, table.clear, table.move, table.sort
local string_char, string_byte, string_sub, string_find, string_gsub, string_format, string_split, string_lower, string_match =
    string.char, string.byte, string.sub, string.find, string.gsub, string.format, string.split, string.lower, string.match
local math_floor, math_ceil, math_random, math_huge = math.floor, math.ceil, math.random, math.huge
local buffer_create, buffer_writef32, buffer_writeu32, buffer_writeu8, buffer_tostring, buffer_writestring =
    buffer.create, buffer.writef32, buffer.writeu32, buffer.writeu8, buffer.tostring, buffer.writestring
local pcall, typeof, type, tostring, tonumber, next, pairs, setmetatable =
    pcall, typeof, type, tostring, tonumber, next, pairs, setmetatable
local task_spawn, task_wait, os_clock = task.spawn, task.wait, os.clock

-- ============================================
-- UTILIDADES CORE
-- ============================================
local EXECUTOR_NAME = (function()
    local ok, name = pcall(identifyexecutor or getexecutorname or function() return "Unknown" end)
    return ok and name or "Unknown"
end)()

local function ArrayToDict(arr, value)
    local dict = {}
    for _, v in arr do
        dict[v] = value == nil and true or value
    end
    return dict
end

local service = setmetatable({}, {
    __index = function(t, k)
        local s = game_FindService(game, k) or game_GetService(game, k)
        t[k] = s
        return s
    end
})

-- ============================================
-- BASE64 ULTRA RÁPIDO
-- ============================================
local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+='
local function base64(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return B64:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

-- ============================================
-- HASH SHA384 (Simplificado)
-- ============================================
local function sha384_simple(data)
    local hash = 0
    for i = 1, #data do
        hash = (hash * 31 + string_byte(data, i)) % 2^32
    end
    return tostring(hash)
end

-- ============================================
-- MÉTODO FINDER SIMPLIFICADO
-- ============================================
local global_container = {}
for fname, func in {
    gethiddenproperty = gethiddenproperty,
    getscriptbytecode = getscriptbytecode or dumpstring,
    gethui = gethui,
    protectgui = protectgui,
} do
    global_container[fname] = func
end

-- ============================================
-- CONFIGURACIÓN DE API DUMP
-- ============================================
local API_CACHE = {}

local function LoadAPI()
    local ok, api = pcall(function()
        return service.HttpService:JSONDecode(
            game:HttpGet("https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Mini-API-Dump.json", true)
        ).Classes
    end)
    
    if not ok then
        warn("⚠️ No se pudo cargar API Dump, usando fallback")
        return {}
    end
    
    local classList = {}
    for _, class in api do
        local props = {}
        for _, member in class.Members or {} do
            if member.MemberType == "Property" then
                local ser = member.Serialization
                if ser.CanLoad and ser.CanSave then
                    table_insert(props, {
                        Name = member.Name,
                        Type = member.ValueType.Name,
                        Category = member.ValueType.Category,
                    })
                end
            end
        end
        classList[class.Name] = {
            Props = props,
            Super = class.Superclass,
            Tags = ArrayToDict(class.Tags or {})
        }
    end
    
    return classList
end

API_CACHE = LoadAPI()

-- ============================================
-- DESCRIPTORES XML COMPACTOS
-- ============================================
local XML = {}

XML.Escape = function(s)
    return string_gsub(s or "", '[&<>"\']', {
        ['&'] = '&amp;', ['<'] = '&lt;', ['>'] = '&gt;',
        ['"'] = '&quot;', ["'"] = '&apos;'
    })
end

XML.CDATA = function(s) return '<![CDATA[' .. s .. ']]>' end

XML.Tag = function(tag, name, value)
    return string_format('<%s name="%s">%s</%s>', tag, name, value, tag)
end

-- Descriptores por tipo
local Descriptors = {
    string = function(v) 
        return string_find(v, "[<>&]") and XML.CDATA(v) or XML.Escape(v)
    end,
    
    bool = function(v) return v and "true" or "false" end,
    
    int = function(v) return tostring(math_floor(v)) end,
    
    float = function(v) 
        if v ~= v then return "nan"
        elseif v == math_huge then return "inf"
        elseif v == -math_huge then return "-inf"
        end
        return tostring(v)
    end,
    
    Vector3 = function(v)
        return string_format("<X>%s</X><Y>%s</Y><Z>%s</Z>", v.X, v.Y, v.Z)
    end,
    
    Vector2 = function(v)
        return string_format("<X>%s</X><Y>%s</Y>", v.X, v.Y)
    end,
    
    CFrame = function(v)
        local x,y,z,r00,r01,r02,r10,r11,r12,r20,r21,r22 = v:GetComponents()
        return string_format(
            "<X>%s</X><Y>%s</Y><Z>%s</Z>" ..
            "<R00>%s</R00><R01>%s</R01><R02>%s</R02>" ..
            "<R10>%s</R10><R11>%s</R11><R12>%s</R12>" ..
            "<R20>%s</R20><R21>%s</R21><R22>%s</R22>",
            x,y,z,r00,r01,r02,r10,r11,r12,r20,r21,r22
        )
    end,
    
    Color3 = function(v)
        return string_format("<R>%s</R><G>%s</G><B>%s</B>", v.R, v.G, v.B)
    end,
    
    UDim2 = function(v)
        return string_format(
            "<XS>%s</XS><XO>%s</XO><YS>%s</YS><YO>%s</YO>",
            v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset
        )
    end,
    
    EnumItem = function(v) return tostring(v.Value) end,
    
    BrickColor = function(v) return tostring(v.Number) end,
    
    NumberRange = function(v) return v.Min .. " " .. v.Max end,
    
    BinaryString = function(v) return v == "" and "" or base64(v) end,
    
    Content = function(v)
        return v == "" and "<null></null>" or "<url>" .. XML.Escape(v) .. "</url>"
    end,
}

-- Aliases
Descriptors.double = Descriptors.float
Descriptors.Color3uint8 = function(v)
    return 0xFF000000 + math_floor(v.R*255)*0x10000 + math_floor(v.G*255)*0x100 + math_floor(v.B*255)
end
Descriptors.CoordinateFrame = function(v) return "<CFrame>" .. Descriptors.CFrame(v) .. "</CFrame>" end

-- ============================================
-- DECOMPILADOR INTELIGENTE
-- ============================================
local decompile_cache = {}

local function SmartDecompile(script)
    if not script:IsA("LuaSourceContainer") then return nil end
    
    -- Verificar caché
    local bytecode_func = global_container.getscriptbytecode
    if bytecode_func then
        local ok, bytecode = pcall(bytecode_func, script)
        if ok and bytecode then
            local hash = sha384_simple(bytecode)
            if decompile_cache[hash] then
                return decompile_cache[hash]
            end
        end
    end
    
    -- Intentar decompilación
    local source = nil
    
    -- Método 1: LinkedSource
    if script.LinkedSource ~= "" then
        local id = string_match(script.LinkedSource, "%d+")
        if id then
            pcall(function()
                source = game:HttpGet("https://assetdelivery.roproxy.com/v1/asset/?id=" .. id)
            end)
        end
    end
    
    -- Método 2: Decompilador
    if not source and decompile then
        local ok, result = pcall(function()
            local thread = coroutine.running()
            local timeout = false
            
            task.delay(10, function()
                timeout = true
                coroutine.resume(thread, nil)
            end)
            
            task_spawn(function()
                local s, r = pcall(decompile, script)
                if not timeout then
                    coroutine.resume(thread, s and r or nil)
                end
            end)
            
            return coroutine.yield()
        end)
        
        if ok and result then
            source = result
        end
    end
    
    -- Fallback
    if not source then
        local isServer = (script:IsA("Script") and script.RunContext ~= Enum.RunContext.Client)
        source = isServer 
            and "-- ⚠️ Server Script (IMPOSIBLE de copiar)" 
            or "-- ⚠️ No se pudo decompiar"
    end
    
    -- Cachear
    if bytecode_func then
        local ok, bytecode = pcall(bytecode_func, script)
        if ok and bytecode then
            decompile_cache[sha384_simple(bytecode)] = source
        end
    end
    
    return source
end

-- ============================================
-- AUTO-FIX SYSTEM (HACE QUE FUNCIONE EN STUDIO)
-- ============================================
local AutoFixes = {}

-- Fix 1: Reparar Chat
AutoFixes.FixChat = function()
    return [[
-- AUTO-FIX: Chat System
local TextChatService = game:GetService("TextChatService")
local Chat = game:GetService("Chat")

-- Limpiar servicios de chat que pueden causar conflictos
pcall(function() TextChatService:ClearAllChildren() end)
pcall(function() Chat:ClearAllChildren() end)

print("✅ Chat limpiado")
]]
end

-- Fix 2: Habilitar Spawn
AutoFixes.FixSpawn = function()
    return [[
-- AUTO-FIX: Spawn System
local Players = game:GetService("Players")
Players.CharacterAutoLoads = true

-- Asegurar que hay un SpawnLocation
task.spawn(function()
    task.wait(1)
    local spawns = {}
    for _, obj in workspace:GetDescendants() do
        if obj:IsA("SpawnLocation") then
            table.insert(spawns, obj)
        end
    end
    
    if #spawns == 0 then
        warn("⚠️ No hay SpawnLocations, creando uno...")
        local spawn = Instance.new("SpawnLocation")
        spawn.Position = Vector3.new(0, 1, 0)
        spawn.Size = Vector3.new(6, 1, 6)
        spawn.Anchored = true
        spawn.Parent = workspace
    end
    
    print("✅ Spawn configurado")
end)
]]
end

-- Fix 3: Reparar Cámara
AutoFixes.FixCamera = function()
    return [[
-- AUTO-FIX: Camera System
task.spawn(function()
    local Players = game:GetService("Players")
    
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(char)
            task.wait(0.5)
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                workspace.CurrentCamera.CameraSubject = humanoid
                workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
            end
        end)
    end)
end)
]]
end

-- Fix 4: Limpiar CoreGui referencias
AutoFixes.FixCoreGui = function()
    return [[
-- AUTO-FIX: Limpiar referencias a CoreGui
for _, obj in game:GetDescendants() do
    if obj:IsA("ScreenGui") then
        -- Mover GUIs de CoreGui a StarterGui
        if obj.Parent and obj.Parent.ClassName == "CoreGui" then
            pcall(function()
                obj.Parent = game:GetService("StarterGui")
            end)
        end
    end
end
]]
end

-- Fix 5: Reparar Colisiones
AutoFixes.FixCollisions = function()
    return [[
-- AUTO-FIX: Collision Fidelity
local fixed = 0
for _, obj in workspace:GetDescendants() do
    if obj:IsA("TriangleMeshPart") or obj:IsA("MeshPart") then
        pcall(function()
            if obj.CollisionFidelity ~= Enum.CollisionFidelity.Default then
                obj.CollisionFidelity = Enum.CollisionFidelity.Default
                fixed = fixed + 1
            end
        end)
    end
end
print("✅ Colisiones reparadas:", fixed)
]]
end

-- ============================================
-- MOTOR PRINCIPAL DE GUARDADO
-- ============================================
local function UltraSaveInstance(options)
    options = options or {}
    
    -- Configuración
    local config = {
        FilePath = options.FilePath or "UltraGame",
        Mode = options.Mode or "full",
        AutoFix = options.AutoFix ~= false, -- Por defecto habilitado
        IncludeScripts = options.IncludeScripts ~= false,
        Timeout = options.Timeout or 15,
        ShowProgress = options.ShowProgress ~= false,
        Objects = options.Objects or {},
    }
    
    print("🚀 ULTRA SAVE INSTANCE - Iniciando...")
    
    -- Sistema de progreso
    local progress = {
        current = 0,
        total = 0,
        status = "Preparando..."
    }
    
    local function UpdateProgress(status)
        progress.status = status
        if config.ShowProgress then
            print(string_format("[%d/%d] %s", progress.current, progress.total, status))
        end
    end
    
    -- Contenedor de salida
    local output = table_create(10000)
    local output_n = 0
    
    local function Write(str)
        output_n = output_n + 1
        output[output_n] = str
    end
    
    -- Referencias
    local refs = {}
    local ref_count = 0
    
    local function GetRef(inst)
        if not refs[inst] then
            refs[inst] = ref_count
            ref_count = ref_count + 1
        end
        return refs[inst]
    end
    
    -- Función para guardar instancia
    local function SaveInstance(inst, depth)
        depth = depth or 0
        
        local className = inst.ClassName
        local ref = GetRef(inst)
        
        -- Iniciar Item
        Write(string_format('%s<Item class="%s" referent="%d">\n', 
            string.rep("  ", depth), className, ref))
        Write(string.rep("  ", depth + 1) .. "<Properties>\n")
        
        -- Guardar propiedades
        local classData = API_CACHE[className]
        if classData then
            local props = classData.Props
            
            for _, prop in props do
                local propName = prop.Name
                local ok, value = pcall(function() return inst[propName] end)
                
                if ok and value ~= nil then
                    local descriptor = Descriptors[prop.Type]
                    if descriptor then
                        local xmlValue, tag = descriptor(value)
                        tag = tag or prop.Type
                        
                        -- Manejar referencias
                        if prop.Category == "Class" then
                            tag = "Ref"
                            xmlValue = value and GetRef(value) or "null"
                        elseif prop.Category == "Enum" then
                            tag = "token"
                        end
                        
                        Write(string.rep("  ", depth + 2) .. XML.Tag(tag, propName, xmlValue) .. "\n")
                    end
                end
            end
        end
        
        -- Script Source
        if config.IncludeScripts and inst:IsA("LuaSourceContainer") then
            UpdateProgress("Decompilando " .. inst.Name)
            local source = SmartDecompile(inst)
            if source then
                Write(string.rep("  ", depth + 2) .. 
                    XML.Tag("ProtectedString", "Source", XML.CDATA(source)) .. "\n")
            end
        end
        
        Write(string.rep("  ", depth + 1) .. "</Properties>\n")
        
        -- Hijos
        local children = inst:GetChildren()
        for _, child in children do
            progress.current = progress.current + 1
            SaveInstance(child, depth + 1)
        end
        
        -- Cerrar Item
        Write(string.rep("  ", depth) .. "</Item>\n")
    end
    
    -- Contar instancias totales
    local function CountInstances(inst)
        local count = 1
        for _, child in inst:GetChildren() do
            count = count + CountInstances(child)
        end
        return count
    end
    
    -- Determinar qué guardar
    local toSave = {}
    
    if #config.Objects > 0 then
        toSave = config.Objects
    elseif config.Mode == "full" then
        local services = {
            "Workspace", "Lighting", "ReplicatedStorage", "ReplicatedFirst",
            "StarterGui", "StarterPack", "StarterPlayer", "Teams",
            "SoundService", "MaterialService", "Chat", "LocalizationService"
        }
        
        for _, svc in services do
            local s = game_FindService(game, svc)
            if s then table_insert(toSave, s) end
        end
    else
        toSave = {workspace}
    end
    
    -- Contar total
    for _, obj in toSave do
        progress.total = progress.total + CountInstances(obj)
    end
    
    UpdateProgress("Iniciando guardado...")
    
    -- Escribir header
    Write('<?xml version="1.0" encoding="utf-8"?>\n')
    Write('<!-- ★ ULTRA SAVE INSTANCE v2.0 - Game Ready for Publishing -->\n')
    Write('<roblox version="4">\n')
    
    -- Guardar objetos
    for _, obj in toSave do
        SaveInstance(obj, 1)
    end
    
    -- AUTO-FIX SCRIPT
    if config.AutoFix then
        UpdateProgress("Agregando auto-fixes...")
        
        Write('  <Item class="Script" referent="' .. ref_count .. '">\n')
        Write('    <Properties>\n')
        Write('      ' .. XML.Tag("string", "Name", "★ AUTO_FIX_SYSTEM") .. '\n')
        
        local autoFixCode = [[
-- ╔══════════════════════════════════════╗
-- ║  AUTO-FIX SYSTEM                    ║
-- ║  Este script repara el juego        ║
-- ║  automáticamente al cargar          ║
-- ╚══════════════════════════════════════╝

print("🔧 Ejecutando AUTO-FIX...")

]] .. AutoFixes.FixChat() .. "\n" 
   .. AutoFixes.FixSpawn() .. "\n"
   .. AutoFixes.FixCamera() .. "\n"
   .. AutoFixes.FixCoreGui() .. "\n"
   .. AutoFixes.FixCollisions() .. [[

print("✅ Todos los auto-fixes completados")
print("🎮 Juego listo para jugar!")

-- Auto-destruir después de ejecutar
script:Destroy()
]]
        
        Write('      ' .. XML.Tag("ProtectedString", "Source", XML.CDATA(autoFixCode)) .. '\n')
        Write('    </Properties>\n')
        Write('  </Item>\n')
    end
    
    -- Cerrar documento
    Write('</roblox>\n')
    
    -- Guardar archivo
    UpdateProgress("Escribiendo archivo...")
    
    local filename = config.FilePath .. ".rbxlx"
    local content = table_concat(output)
    
    local ok, err = pcall(writefile, filename, content)
    
    if ok then
        print("✅ GUARDADO EXITOSO!")
        print("📁 Archivo:", filename)
        print("📊 Tamaño:", string_format("%.2f MB", #content / 1024 / 1024))
        print("🎮 Listo para abrir en Studio y publicar!")
        
        return true, filename
    else
        warn("❌ Error al guardar:", err)
        return false, err
    end
end

-- ============================================
-- VERSIÓN SIMPLIFICADA (1 Línea)
-- ============================================
local function QuickSave(name)
    return UltraSaveInstance({
        FilePath = name or "MyGame",
        AutoFix = true
    })
end

-- ============================================
-- INTERFAZ GRÁFICA SIMPLE
-- ============================================
local function CreateGUI()
    local ScreenGui = Instance_new("ScreenGui")
    ScreenGui.Name = "UltraSaveGUI"
    ScreenGui.ResetOnSpawn = false
    
    if global_container.gethui then
        ScreenGui.Parent = global_container.gethui()
    elseif global_container.protectgui then
        global_container.protectgui(ScreenGui)
        ScreenGui.Parent = service.CoreGui
    else
        ScreenGui.Parent = service.CoreGui
    end
    
    local Frame = Instance_new("Frame")
    Frame.Size = UDim2.new(0, 300, 0, 200)
    Frame.Position = UDim2.new(0.5, -150, 0.5, -100)
    Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    Frame.BorderSizePixel = 0
    Frame.Parent = ScreenGui
    
    -- Sombra
    local Shadow = Instance_new("ImageLabel")
    Shadow.Image = "rbxasset://textures/ui/Controls/DropShadow.png"
    Shadow.ImageColor3 = Color3.new(0, 0, 0)
    Shadow.ImageTransparency = 0.5
    Shadow.ScaleType = Enum.ScaleType.Slice
    Shadow.SliceCenter = Rect.new(12, 12, 12, 12)
    Shadow.Size = UDim2.new(1, 20, 1, 20)
    Shadow.Position = UDim2.new(0, -10, 0, -10)
    Shadow.BackgroundTransparency = 1
    Shadow.ZIndex = 0
    Shadow.Parent = Frame
    
    local Title = Instance_new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
    Title.BorderSizePixel = 0
    Title.Text = "★ ULTRA SAVE INSTANCE"
    Title.TextColor3 = Color3.new(1, 1, 1)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 16
    Title.Parent = Frame
    
    local SaveButton = Instance_new("TextButton")
    SaveButton.Size = UDim2.new(0.8, 0, 0, 40)
    SaveButton.Position = UDim2.new(0.1, 0, 0.4, 0)
    SaveButton.BackgroundColor3 = Color3.fromRGB(40, 200, 100)
    SaveButton.BorderSizePixel = 0
    SaveButton.Text = "💾 GUARDAR JUEGO COMPLETO"
    SaveButton.TextColor3 = Color3.new(1, 1, 1)
    SaveButton.Font = Enum.Font.GothamBold
    SaveButton.TextSize = 14
    SaveButton.Parent = Frame
    
    local QuickButton = Instance_new("TextButton")
    QuickButton.Size = UDim2.new(0.8, 0, 0, 40)
    QuickButton.Position = UDim2.new(0.1, 0, 0.65, 0)
    QuickButton.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
    QuickButton.BorderSizePixel = 0
    QuickButton.Text = "⚡ GUARDADO RÁPIDO"
    QuickButton.TextColor3 = Color3.new(1, 1, 1)
    QuickButton.Font = Enum.Font.GothamBold
    QuickButton.TextSize = 14
    QuickButton.Parent = Frame
    
    -- Esquinas redondeadas
    for _, obj in {Frame, SaveButton, QuickButton} do
        local Corner = Instance_new("UICorner")
        Corner.CornerRadius = UDim.new(0, 8)
        Corner.Parent = obj
    end
    
    -- Eventos
    SaveButton.MouseButton1Click:Connect(function()
        SaveButton.Text = "⏳ Guardando..."
        SaveButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        
        task_spawn(function()
            local ok = UltraSaveInstance({
                Mode = "full",
                AutoFix = true
            })
            
            if ok then
                SaveButton.Text = "✅ GUARDADO!"
                SaveButton.BackgroundColor3 = Color3.fromRGB(40, 200, 100)
                task_wait(2)
                ScreenGui:Destroy()
            else
                SaveButton.Text = "❌ ERROR"
                SaveButton.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
                task_wait(2)
                SaveButton.Text = "💾 GUARDAR JUEGO COMPLETO"
                SaveButton.BackgroundColor3 = Color3.fromRGB(40, 200, 100)
            end
        end)
    end)
    
    QuickButton.MouseButton1Click:Connect(function()
        QuickButton.Text = "⏳ Guardando..."
        QuickButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        
        task_spawn(function()
            local ok = QuickSave("QuickSave_" .. os.time())
            
            if ok then
                QuickButton.Text = "✅ GUARDADO!"
                QuickButton.BackgroundColor3 = Color3.fromRGB(40, 200, 100)
                task_wait(2)
                ScreenGui:Destroy()
            else
                QuickButton.Text = "❌ ERROR"
                QuickButton.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
            end
        end)
    end)
end

-- ============================================
-- EXPORTAR FUNCIONES
-- ============================================
getgenv().UltraSave = UltraSaveInstance
getgenv().QuickSave = QuickSave
getgenv().SaveGUI = CreateGUI

-- ============================================
-- AUTO-EJECUTAR GUI SI NO HAY PARÁMETROS
-- ============================================
print([[
╔══════════════════════════════════════════════╗
║  🚀 ULTRA SAVE INSTANCE v2.0 CARGADO        ║
╚══════════════════════════════════════════════╝

📚 COMANDOS DISPONIBLES:

  • SaveGUI()  
    Abre interfaz gráfica

  • QuickSave()  
    Guarda el juego rápidamente

  • UltraSave({options})  
    Control total con opciones

📖 EJEMPLO DE USO:
  
  UltraSave({
      FilePath = "MiJuego",
      Mode = "full",
      AutoFix = true
  })

✨ CARACTERÍSTICAS:
  ✅ Auto-repara chat, spawn, cámara
  ✅ Decompilación inteligente
  ✅ Listo para publicar en Studio
  ✅ Archivos optimizados
]])

return {
    Save = UltraSaveInstance,
    Quick = QuickSave,
    GUI = CreateGUI
}


