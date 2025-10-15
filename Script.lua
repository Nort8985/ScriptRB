-- MOBILE-OPTIMIZED ANTICHEAT TESTER v4.3 ULTIMATE TELEPORT REACH
-- ============================ CHANGELOG v4.3 TELEPORT REACH ============================
-- 1. НОВОЕ: Временная телепортация к объекту для обхода серверных проверок
-- 2. НОВОЕ: Мгновенный возврат на место после активации
-- 3. ИСПРАВЛЕНО: Работает с любыми Remote Functions с проверкой расстояния
-- 4. ОПТИМИЗИРОВАНО: Увеличена задержка для надежной активации (0.5 сек)
-- 5. НОВОЕ: Работает через стены - NoClip во время телепортации
-- =======================================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Добавляем флаг мобильной платформы (Android / touch)
local IS_MOBILE = UserInputService.TouchEnabled

-- ==================== GLOBALS & SETUP ====================
_G.SavedCheckpoints = _G.SavedCheckpoints or {}
local cheats = {
    platformWalk = false, antiTrigger = false, invisible = false, spider = false,
    noclip = false, speed = false, infiniteJump = false, esp = false,
    fly = false, teleport = false, rewind = false, infiniteReach = false,
    itemDuplication = false
}
local connections = {}
local teleportMarker = nil

-- ==================== KEYBIND SYSTEM ====================
local keybinds = {} -- Таблица для хранения биндов: {keyCode = functionName}
local keybindConnections = {} -- Для хранения соединений биндов
local isBindingMode = false -- Флаг режима назначения биндов
local currentBindingButton = nil -- Текущая кнопка для назначения бинда

-- Конфигурация для invisibility
local INVISIBILITY_CONFIG = {
    INVISIBILITY_POSITION = Vector3.new(-25.95, 84, 3537.55),
    SOUND_ID = "rbxassetid://942127495",
    SPEED_MULTIPLIER = 2
}

-- Конфигурация для Infinite Reach
local REACH_CONFIG = {
    MAX_DISTANCE = 9999,
    HIGHLIGHT_COLOR = Color3.fromRGB(0, 255, 255),
    ORIGINAL_DISTANCES = {},
    TELEPORT_OFFSET = Vector3.new(0, 3, 0), -- Отступ при телепортации
    ACTIVATION_DELAY = 0.5, -- Увеличенная задержка для активации
    RETURN_DELAY = 0.2 -- Задержка перед возвратом
}

-- Сохраняем оригинальную скорость
local originalWalkSpeed = 16
local invisibilityPreviousStates = {
    noclip = false,
    speed = false,
    originalSpeed = 16
}

-- ==================== HELPER FUNCTIONS ====================
local function findRemoteHandler()
    local remote = workspace:FindFirstChild("Remote")
    if remote then
        local itemHandler = remote:FindFirstChild("ItemHandler")
        if itemHandler and itemHandler:IsA("RemoteFunction") then
            return itemHandler
        end
    end
    
    local repStorage = game:GetService("ReplicatedStorage")
    for _, child in pairs(repStorage:GetDescendants()) do
        if child:IsA("RemoteFunction") and child.Name:find("Item") then
            return child
        end
    end
    
    return nil
end

local function getObjectPosition(obj)
    if obj:IsA("Model") then
        return obj:GetPivot().Position
    elseif obj:IsA("BasePart") then
        return obj.Position
    elseif obj.Parent and obj.Parent:IsA("Model") then
        return obj.Parent:GetPivot().Position
    elseif obj.Parent and obj.Parent:IsA("BasePart") then
        return obj.Parent.Position
    end
    return nil
end

local function findInteractableObject(part)
    if not part then return nil, nil, nil end
    
    -- ITEMPICKUP (оружие, предметы)
    local itemPickup = part:FindFirstChild("ITEMPICKUP") or 
                      (part.Parent and part.Parent:FindFirstChild("ITEMPICKUP"))
    
    if itemPickup then
        local pos = getObjectPosition(itemPickup)
        return itemPickup, "ITEM", pos
    end
    
    -- Кнопки
    if part.Name:find("Spawner") or part.Name:find("Button") or 
       (part.Parent and part.Parent.Name:find("button")) then
        local pos = getObjectPosition(part)
        return part, "BUTTON", pos
    end
    
    -- ClickDetector или ProximityPrompt
    local clickDetector = part:FindFirstChildOfClass("ClickDetector", true)
    local proximityPrompt = part:FindFirstChildOfClass("ProximityPrompt", true)
    
    if clickDetector or proximityPrompt then
        local pos = getObjectPosition(part)
        return part, "DETECTOR", pos
    end
    
    return nil, nil, nil
end

-- Функция временного включения NoClip
local function enableTemporaryNoclip(duration)
    local char = player.Character
    if not char then return end
    
    -- Сохраняем текущее состояние NoClip
    local wasNoclipEnabled = cheats.noclip
    
    -- Включаем NoClip для прохода через стены
    local noclipConnection
    noclipConnection = RunService.Stepped:Connect(function()
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
    
    -- Отключаем NoClip через заданное время
    task.delay(duration, function()
        if noclipConnection then
            noclipConnection:Disconnect()
        end
        
        -- Восстанавливаем состояние NoClip если он не был включен
        if not wasNoclipEnabled and char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end)
    
    return noclipConnection
end

-- ==================== KEYBIND FUNCTIONS ====================
local function saveKeybindsToFile()
    if writefile then
        pcall(function()
            writefile("keybinds_" .. game.PlaceId .. ".json", HttpService:JSONEncode(keybinds))
        end)
    end
end

local function loadKeybindsFromFile()
    if readfile and isfile then
        local filename = "keybinds_" .. game.PlaceId .. ".json"
        pcall(function()
            if isfile(filename) then
                local decoded = HttpService:JSONDecode(readfile(filename))
                for keyCode, funcName in pairs(decoded) do
                    keybinds[tonumber(keyCode)] = funcName
                end
            end
        end)
    end
end

local function getFunctionByName(funcName)
    local functions = {
        toggleInfiniteReach = toggleInfiniteReach,
        togglePlatformWalk = togglePlatformWalk,
        toggleAntiTrigger = toggleAntiTrigger,
        toggleSpider = toggleSpider,
        toggleNoclip = toggleNoclip,
        toggleSpeed = toggleSpeed,
        toggleInfiniteJump = toggleInfiniteJump,
        toggleESP = toggleESP,
        toggleFly = toggleFly,
        toggleRewind = toggleRewind,
        setupTeleport = setupTeleport,
        toggleItemDuplication = toggleItemDuplication,
        toggleInvisibility = toggleInvisibility,
        openCheckpointManager = openCheckpointManager
    }
    return functions[funcName]
end

local function executeKeybind(keyCode)
    local funcName = keybinds[keyCode]
    if funcName then
        local func = getFunctionByName(funcName)
        if func then
            local success, result = pcall(func)
            if success then
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = "⌨️ Keybind",
                    Text = funcName .. " активировано!",
                    Duration = 1
                })
            end
        end
    end
end

local function setKeybind(keyCode, funcName)
    -- Удаляем старый бинд для этой клавиши
    for k, v in pairs(keybinds) do
        if v == funcName then
            keybinds[k] = nil
            break
        end
    end

    -- Устанавливаем новый бинд
    keybinds[keyCode] = funcName
    saveKeybindsToFile()
end

local function removeKeybind(keyCode)
    keybinds[keyCode] = nil
    saveKeybindsToFile()
end

local function getKeyName(keyCode)
    local keyNames = {
        [Enum.KeyCode.A] = "A", [Enum.KeyCode.B] = "B", [Enum.KeyCode.C] = "C",
        [Enum.KeyCode.D] = "D", [Enum.KeyCode.E] = "E", [Enum.KeyCode.F] = "F",
        [Enum.KeyCode.G] = "G", [Enum.KeyCode.H] = "H", [Enum.KeyCode.I] = "I",
        [Enum.KeyCode.J] = "J", [Enum.KeyCode.K] = "K", [Enum.KeyCode.L] = "L",
        [Enum.KeyCode.M] = "M", [Enum.KeyCode.N] = "N", [Enum.KeyCode.O] = "O",
        [Enum.KeyCode.P] = "P", [Enum.KeyCode.Q] = "Q", [Enum.KeyCode.R] = "R",
        [Enum.KeyCode.S] = "S", [Enum.KeyCode.T] = "T", [Enum.KeyCode.U] = "U",
        [Enum.KeyCode.V] = "V", [Enum.KeyCode.W] = "W", [Enum.KeyCode.X] = "X",
        [Enum.KeyCode.Y] = "Y", [Enum.KeyCode.Z] = "Z",
        [Enum.KeyCode.One] = "1", [Enum.KeyCode.Two] = "2", [Enum.KeyCode.Three] = "3",
        [Enum.KeyCode.Four] = "4", [Enum.KeyCode.Five] = "5", [Enum.KeyCode.Six] = "6",
        [Enum.KeyCode.Seven] = "7", [Enum.KeyCode.Eight] = "8", [Enum.KeyCode.Nine] = "9",
        [Enum.KeyCode.Zero] = "0", [Enum.KeyCode.Space] = "Пробел",
        [Enum.KeyCode.LeftShift] = "LShift", [Enum.KeyCode.RightShift] = "RShift",
        [Enum.KeyCode.LeftControl] = "LCtrl", [Enum.KeyCode.RightControl] = "RCtrl",
        [Enum.KeyCode.LeftAlt] = "LAlt", [Enum.KeyCode.RightAlt] = "RAlt",
        [Enum.KeyCode.Tab] = "Tab", [Enum.KeyCode.Escape] = "Esc",
        [Enum.KeyCode.Insert] = "Ins", [Enum.KeyCode.Delete] = "Del",
        [Enum.KeyCode.Home] = "Home", [Enum.KeyCode.End] = "End",
        [Enum.KeyCode.PageUp] = "PgUp", [Enum.KeyCode.PageDown] = "PgDn",
        [Enum.KeyCode.F1] = "F1", [Enum.KeyCode.F2] = "F2", [Enum.KeyCode.F3] = "F3",
        [Enum.KeyCode.F4] = "F4", [Enum.KeyCode.F5] = "F5", [Enum.KeyCode.F6] = "F6",
        [Enum.KeyCode.F7] = "F7", [Enum.KeyCode.F8] = "F8", [Enum.KeyCode.F9] = "F9",
        [Enum.KeyCode.F10] = "F10", [Enum.KeyCode.F11] = "F11", [Enum.KeyCode.F12] = "F12"
    }
    return keyNames[keyCode] or tostring(keyCode)
end

-- Функция телепортации к объекту и обратно С NOCLIP
local function teleportAndActivate(targetObject, targetPosition)
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local rootPart = char.HumanoidRootPart
    local originalPosition = rootPart.CFrame
    
    -- Включаем временный NoClip для прохода через стены
    local totalDuration = REACH_CONFIG.ACTIVATION_DELAY + REACH_CONFIG.RETURN_DELAY + 0.3
    enableTemporaryNoclip(totalDuration)
    
    -- Телепортируемся к объекту
    rootPart.CFrame = CFrame.new(targetPosition + REACH_CONFIG.TELEPORT_OFFSET)
    
    -- Увеличенная задержка для синхронизации с сервером
    task.wait(REACH_CONFIG.ACTIVATION_DELAY)
    
    -- Активируем объект
    local success = false
    local remoteHandler = findRemoteHandler()
    
    if remoteHandler then
        success = pcall(function()
            local args = {targetObject}
            remoteHandler:InvokeServer(unpack(args))
        end)
    end
    
    -- Дополнительная попытка активации
    if not success then
        task.wait(0.1)
        success = pcall(function()
            local args = {targetObject}
            workspace.Remote.ItemHandler:InvokeServer(unpack(args))
        end)
    end
    
    -- Задержка перед возвратом
    task.wait(REACH_CONFIG.RETURN_DELAY)
    
    -- Возвращаемся обратно
    rootPart.CFrame = originalPosition
    
    return success
end

-- ==================== REWIND SYSTEM ====================
local rewindHistory = {}
local maxRewindTime = 5
local rewindInterval = 0.1
local isRewinding = false

local function recordPosition()
    if isRewinding then return end
    
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local rootPart = char.HumanoidRootPart
        local record = {
            position = rootPart.Position,
            cframe = rootPart.CFrame,
            timestamp = tick()
        }
        
        table.insert(rewindHistory, record)
        
        while #rewindHistory > 0 and rewindHistory[1].timestamp < tick() - maxRewindTime do
            table.remove(rewindHistory, 1)
        end
    end
end

connections.rewindRecorder = RunService.Heartbeat:Connect(function()
    recordPosition()
end)

local function activateRewind()
    if isRewinding or #rewindHistory < 2 then 
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "⏪ Rewind",
            Text = "Недостаточно данных для возврата",
            Duration = 2
        })
        return false
    end
    
    isRewinding = true
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        isRewinding = false
        return false
    end
    
    local rootPart = char.HumanoidRootPart
    local wasFlying = cheats.fly
    
    if wasFlying then
        toggleFly()
    end
    
    local targetTime = tick() - maxRewindTime
    local targetRecord = rewindHistory[1]
    
    for i, record in ipairs(rewindHistory) do
        if record.timestamp >= targetTime then
            targetRecord = record
            break
        end
    end
    
    if targetRecord then
        local rewindEffect = Instance.new("Part")
        rewindEffect.Name = "RewindEffect"
        rewindEffect.Size = Vector3.new(8, 8, 8)
        rewindEffect.Position = rootPart.Position
        rewindEffect.Anchored = true
        rewindEffect.CanCollide = false
        rewindEffect.Material = Enum.Material.Neon
        rewindEffect.BrickColor = BrickColor.new("Bright violet")
        rewindEffect.Transparency = 0.7
        rewindEffect.Shape = Enum.PartType.Ball
        rewindEffect.Parent = workspace
        
        local tween = TweenService:Create(rewindEffect, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(0.1, 0.1, 0.1),
            Transparency = 1
        })
        tween:Play()
        Debris:AddItem(rewindEffect, 0.5)
        
        local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = TweenService:Create(rootPart, tweenInfo, {
            CFrame = targetRecord.cframe
        })
        tween:Play()
        
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "⏪ Rewind Activated",
            Text = "Возврат на 5 секунд назад",
            Duration = 3
        })
        
        tween.Completed:Wait()
        rewindHistory = {}
    end
    
    if wasFlying then
        toggleFly()
    end
    
    isRewinding = false
    return true
end

local function toggleRewind()
    local success = activateRewind()
    return false
end

-- ==================== SAVING & LOADING ====================
local function saveCheckpointsToFile()
    if writefile then
        pcall(function() 
            writefile("cp_" .. game.PlaceId .. ".json", HttpService:JSONEncode(_G.SavedCheckpoints)) 
        end)
    end
end

local function loadCheckpointsFromFile()
    if readfile and isfile then
        local filename = "cp_" .. game.PlaceId .. ".json"
        pcall(function()
            if isfile(filename) then
                local decoded = HttpService:JSONDecode(readfile(filename))
                for name, cp in pairs(decoded) do
                    if cp.Position then
                        _G.SavedCheckpoints[name] = {
                            CFrame = CFrame.new(cp.Position.X, cp.Position.Y, cp.Position.Z),
                            Position = {X = cp.Position.X, Y = cp.Position.Y, Z = cp.Position.Z},
                            Time = cp.Time
                        }
                    end
                end
            end
        end)
    end
end
loadCheckpointsFromFile()
loadKeybindsFromFile()

-- ==================== KEYBIND HANDLER ====================
connections.keybindHandler = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    -- Не обрабатываем бинды в режиме назначения клавиш
    if isBindingMode then return end

    -- Обрабатываем только клавиши клавиатуры
    if input.UserInputType == Enum.UserInputType.Keyboard then
        executeKeybind(input.KeyCode)
    end
end)

-- ==================== GUI UTILITIES ====================
local function createCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = parent
    return corner
end

local function makeDraggable(frame, handle)
    local dragging, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, frame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- ==================== GUI CREATION ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MobileCheatTester"
screenGui.ResetOnSpawn = false
if player:FindFirstChild("PlayerGui") then
    screenGui.Parent = player.PlayerGui
else
    player:WaitForChild("PlayerGui")
    screenGui.Parent = player.PlayerGui
end

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 60, 0, 60)
toggleButton.Position = UDim2.new(0, 10, 0.3, 0)
toggleButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
toggleButton.Text = "☰"
toggleButton.TextScaled = true
toggleButton.TextColor3 = Color3.new(1, 1, 1)
-- Делать кнопку видимой сразу на мобильных
toggleButton.Visible = IS_MOBILE
toggleButton.Parent = screenGui
createCorner(toggleButton, 15)

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 250, 0.6, 0)
mainFrame.Position = UDim2.new(0, 10, 0.5, -0.3)
mainFrame.AnchorPoint = Vector2.new(0, 0.5)
mainFrame.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
createCorner(mainFrame, 12)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 35)
titleBar.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
titleBar.Parent = mainFrame
createCorner(titleBar, 12)

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -70, 1, 0)
titleText.Text = "AC Tester v4.3"
titleText.TextColor3 = Color3.new(1, 0.3, 0.3)
titleText.TextScaled = true
titleText.BackgroundTransparency = 1
titleText.Font = Enum.Font.GothamBold
titleText.Parent = titleBar

local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, 30, 0, 30)
minimizeButton.Position = UDim2.new(1, -65, 0, 2.5)
minimizeButton.Text = "_"
minimizeButton.TextScaled = true
minimizeButton.TextColor3 = Color3.new(1, 1, 1)
minimizeButton.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.Parent = titleBar
createCorner(minimizeButton, 6)

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -32, 0, 2.5)
closeButton.Text = "X"
closeButton.TextScaled = true
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.BackgroundColor3 = Color3.new(0.8, 0.2, 0.2)
closeButton.Font = Enum.Font.GothamBold
closeButton.Parent = titleBar
createCorner(closeButton, 6)

local functionsFrame = Instance.new("ScrollingFrame")
functionsFrame.Size = UDim2.new(1, -10, 1, -40)
functionsFrame.Position = UDim2.new(0, 5, 0, 37)
functionsFrame.BackgroundTransparency = 1
functionsFrame.ScrollBarThickness = 6
functionsFrame.BorderSizePixel = 0
functionsFrame.Parent = mainFrame

makeDraggable(mainFrame, titleBar)

-- ==================== ОТДЕЛЬНАЯ КНОПКА INVISIBILITY ====================
local invisibilityButton = Instance.new("TextButton")
invisibilityButton.Size = UDim2.new(0, 60, 0, 60)
invisibilityButton.Position = UDim2.new(1, -70, 0.3, 0)
invisibilityButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
invisibilityButton.Text = "👻"
invisibilityButton.TextScaled = true
invisibilityButton.TextColor3 = Color3.new(1, 1, 1)
invisibilityButton.Font = Enum.Font.GothamBold
invisibilityButton.Parent = screenGui
createCorner(invisibilityButton, 15)

makeDraggable(invisibilityButton, invisibilityButton)

local invisSound = Instance.new("Sound")
invisSound.Name = "InvisibilitySound"
invisSound.SoundId = INVISIBILITY_CONFIG.SOUND_ID
invisSound.Volume = 0.5
invisSound.Parent = screenGui

-- ==================== UNIVERSAL BUTTON CREATOR ====================
local buttonCount = 0
local buttonsDict = {}
local function createButton(name, callback, color, isToggle)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -10, 0, 45)
    button.Position = UDim2.new(0, 5, 0, buttonCount * 50)
    button.Text = isToggle and (name .. ": OFF") or name
    button.TextScaled = true
    button.TextColor3 = Color3.new(1, 1, 1)
    button.BackgroundColor3 = color or Color3.new(0.3, 0.3, 0.3)
    button.Font = Enum.Font.Gotham
    button.Parent = functionsFrame
    createCorner(button, 8)
    
    button.MouseButton1Click:Connect(function()
        if isToggle then
            local state = callback()
            button.Text = name .. ": " .. (state and "ON" or "OFF")
            button.BackgroundColor3 = state and Color3.new(0.3, 0.8, 0.3) or (color or Color3.new(0.3, 0.3, 0.3))
        else
            callback()
            TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = Color3.new(1, 1, 1)}):Play()
            wait(0.1)
            TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = color or Color3.new(0.7, 0.3, 0.3)}):Play()
        end
    end)
    
    buttonCount = buttonCount + 1
    functionsFrame.CanvasSize = UDim2.new(0, 0, 0, buttonCount * 50)
    
    buttonsDict[name] = button
    
    return button
end

-- ==================== CORE FUNCTIONS ====================

local function setCharacterTransparency(character, transparency)
    for _, descendant in character:GetDescendants() do
        if descendant:IsA("BasePart") or descendant:IsA("Decal") then
            descendant.Transparency = transparency
        end
    end
end

local function playInvisSound()
    if invisSound then
        invisSound:Play()
    end
end

local toggleNoclip, toggleSpeed

-- ==================== INFINITE REACH WITH TELEPORT BYPASS ====================
local function toggleInfiniteReach()
    cheats.infiniteReach = not cheats.infiniteReach
    
    if cheats.infiniteReach then
        -- Расширение ProximityPrompts
        local function extendProximityPrompt(prompt)
            if prompt:IsA("ProximityPrompt") then
                if not REACH_CONFIG.ORIGINAL_DISTANCES[prompt] then
                    REACH_CONFIG.ORIGINAL_DISTANCES[prompt] = {
                        MaxActivationDistance = prompt.MaxActivationDistance,
                        HoldDuration = prompt.HoldDuration
                    }
                end
                prompt.MaxActivationDistance = REACH_CONFIG.MAX_DISTANCE
                prompt.HoldDuration = 0
                
                local parent = prompt.Parent
                if parent and (parent:IsA("BasePart") or parent:IsA("Model")) then
                    if not parent:FindFirstChild("ReachHighlight") then
                        local highlight = Instance.new("Highlight")
                        highlight.Name = "ReachHighlight"
                        highlight.FillColor = REACH_CONFIG.HIGHLIGHT_COLOR
                        highlight.FillTransparency = 0.5
                        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                        highlight.OutlineTransparency = 0.3
                        highlight.Parent = parent
                    end
                end
            end
        end
        
        -- Расширение ClickDetectors
        local function extendClickDetector(detector)
            if detector:IsA("ClickDetector") then
                if not REACH_CONFIG.ORIGINAL_DISTANCES[detector] then
                    REACH_CONFIG.ORIGINAL_DISTANCES[detector] = {
                        MaxActivationDistance = detector.MaxActivationDistance
                    }
                end
                detector.MaxActivationDistance = REACH_CONFIG.MAX_DISTANCE
            end
        end
        
        -- Применяем ко всем существующим объектам
        for _, obj in pairs(workspace:GetDescendants()) do
            extendProximityPrompt(obj)
            extendClickDetector(obj)
        end
        
        -- Слушаем новые объекты
        connections.reachPrompts = workspace.DescendantAdded:Connect(function(obj)
            if cheats.infiniteReach then
                extendProximityPrompt(obj)
                extendClickDetector(obj)
            end
        end)
        
        -- Подсветка инструментов и интерактивных объектов
        connections.reachTools = RunService.Heartbeat:Connect(function()
            if not cheats.infiniteReach then return end
            
            local char = player.Character
            if not char then return end
            
            local rootPart = char:FindFirstChild("HumanoidRootPart")
            if not rootPart then return end
            
            -- Подсветка инструментов
            for _, obj in pairs(workspace:GetChildren()) do
                if obj:IsA("Tool") and obj:FindFirstChild("Handle") then
                    if not obj:FindFirstChild("ReachHighlight") then
                        local highlight = Instance.new("Highlight")
                        highlight.Name = "ReachHighlight"
                        highlight.FillColor = Color3.fromRGB(255, 255, 0)
                        highlight.FillTransparency = 0.5
                        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                        highlight.Parent = obj
                    end
                end
            end
            
            -- Подсветка Prison_ITEMS
            if workspace:FindFirstChild("Prison_ITEMS") then
                for _, item in pairs(workspace.Prison_ITEMS:GetDescendants()) do
                    if item.Name == "ITEMPICKUP" or item.Name:find("Spawner") or item.Name:find("Button") then
                        local parent = item.Parent
                        if parent and not parent:FindFirstChild("ReachHighlight") then
                            local highlight = Instance.new("Highlight")
                            highlight.Name = "ReachHighlight"
                            highlight.FillColor = Color3.fromRGB(0, 255, 0)
                            highlight.FillTransparency = 0.6
                            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                            highlight.Parent = parent
                        end
                    end
                end
            end
        end)
        
        -- ГЛАВНАЯ ФУНКЦИЯ: Клик с телепортацией
        connections.reachActivate = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if not cheats.infiniteReach then return end
            
            if input.UserInputType == Enum.UserInputType.MouseButton1 or 
               input.UserInputType == Enum.UserInputType.Touch then
                
                task.wait(0.05)
                if gameProcessed then return end
                
                local target = mouse.Target
                if target then
                    local activated = false
                    
                    -- Находим интерактивный объект
                    local interactObj, interactType, targetPos = findInteractableObject(target)
                    
                    if interactObj and targetPos then
                        -- ТЕЛЕПОРТИРУЕМСЯ И АКТИВИРУЕМ (ЧЕРЕЗ СТЕНЫ)
                        local success = teleportAndActivate(interactObj, targetPos)
                        
                        if success then
                            activated = true
                            game:GetService("StarterGui"):SetCore("SendNotification", {
                                Title = "🎯 Teleport Reach",
                                Text = "Активировано: " .. interactObj.Name,
                                Duration = 2
                            })
                        end
                    end
                    
                    -- Стандартные ProximityPrompt
                    if not activated then
                        local prompt = target:FindFirstChildOfClass("ProximityPrompt", true)
                        if not prompt and target.Parent then
                            prompt = target.Parent:FindFirstChildOfClass("ProximityPrompt", true)
                        end
                        
                        if prompt then
                            pcall(function()
                                fireproximityprompt(prompt)
                            end)
                            activated = true
                            game:GetService("StarterGui"):SetCore("SendNotification", {
                                Title = "🎯 Infinite Reach",
                                Text = "ProximityPrompt активирован!",
                                Duration = 2
                            })
                        end
                    end
                    
                    -- ClickDetector
                    if not activated then
                        local detector = target:FindFirstChildOfClass("ClickDetector", true)
                        if not detector and target.Parent then
                            detector = target.Parent:FindFirstChildOfClass("ClickDetector", true)
                        end
                        
                        if detector then
                            pcall(function()
                                fireclickdetector(detector)
                            end)
                            activated = true
                            game:GetService("StarterGui"):SetCore("SendNotification", {
                                Title = "🎯 Infinite Reach",
                                Text = "ClickDetector активирован!",
                                Duration = 2
                            })
                        end
                    end
                    
                    -- Подбор инструмента
                    if not activated then
                        local tool = target:FindFirstAncestorOfClass("Tool")
                        if tool and tool.Parent == workspace then
                            if player.Character then
                                tool.Parent = player.Character
                                activated = true
                                game:GetService("StarterGui"):SetCore("SendNotification", {
                                    Title = "🎯 Infinite Reach",
                                    Text = "Инструмент поднят: " .. tool.Name,
                                    Duration = 2
                                })
                            end
                        end
                    end
                    
                    -- Визуальный эффект
                    if activated then
                        local effect = Instance.new("Part")
                        effect.Name = "ActivationEffect"
                        effect.Size = Vector3.new(2, 2, 2)
                        effect.Position = target.Position
                        effect.Anchored = true
                        effect.CanCollide = false
                        effect.Material = Enum.Material.Neon
                        effect.BrickColor = BrickColor.new("Bright green")
                        effect.Transparency = 0.3
                        effect.Shape = Enum.PartType.Ball
                        effect.Parent = workspace
                        
                        local tween = TweenService:Create(effect, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                            Size = Vector3.new(0.1, 0.1, 0.1),
                            Transparency = 1
                        })
                        tween:Play()
                        Debris:AddItem(effect, 0.5)
                    end
                end
            end
        end)
        
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "🎯 Teleport Reach ON",
            Text = "Кликай - работает через стены!",
            Duration = 4
        })
    else
        -- Восстанавливаем оригинальные значения
        for obj, original in pairs(REACH_CONFIG.ORIGINAL_DISTANCES) do
            if obj and obj.Parent then
                pcall(function()
                    if obj:IsA("ProximityPrompt") then
                        obj.MaxActivationDistance = original.MaxActivationDistance
                        obj.HoldDuration = original.HoldDuration
                    elseif obj:IsA("ClickDetector") then
                        obj.MaxActivationDistance = original.MaxActivationDistance
                    end
                end)
            end
        end
        REACH_CONFIG.ORIGINAL_DISTANCES = {}
        
        -- Удаляем все подсветки
        for _, obj in pairs(workspace:GetDescendants()) do
            local highlight = obj:FindFirstChild("ReachHighlight")
            if highlight then
                highlight:Destroy()
            end
        end
        
        -- Отключаем connections
        if connections.reachPrompts then connections.reachPrompts:Disconnect() end
        if connections.reachTools then connections.reachTools:Disconnect() end
        if connections.reachActivate then connections.reachActivate:Disconnect() end
        
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "🎯 Teleport Reach OFF",
            Text = "Дальность взаимодействия восстановлена",
            Duration = 3
        })
    end
    
    return cheats.infiniteReach
end

-- ==================== ОСТАЛЬНЫЕ ФУНКЦИИ (INVISIBILITY, PLATFORM, ETC) ====================
local function toggleInvisibility()
    if not player.Character then
        warn("Character not found")
        return cheats.invisible
    end

    cheats.invisible = not cheats.invisible
    playInvisSound()

    if cheats.invisible then
        local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
        local humanoid = player.Character:FindFirstChild("Humanoid")
        
        if not humanoidRootPart or not humanoid then
            warn("HumanoidRootPart or Humanoid not found")
            cheats.invisible = false
            return cheats.invisible
        end

        invisibilityPreviousStates.noclip = cheats.noclip
        invisibilityPreviousStates.speed = cheats.speed
        invisibilityPreviousStates.originalSpeed = humanoid.WalkSpeed

        local savedPosition = humanoidRootPart.CFrame

        player.Character:MoveTo(INVISIBILITY_CONFIG.INVISIBILITY_POSITION)
        task.wait(0.15)

        local seat = Instance.new("Seat")
        seat.Name = "invischair"
        seat.Anchored = false
        seat.CanCollide = false
        seat.Transparency = 1
        seat.Position = INVISIBILITY_CONFIG.INVISIBILITY_POSITION
        seat.Parent = workspace

        local weld = Instance.new("Weld")
        weld.Part0 = seat
        weld.Part1 = player.Character:FindFirstChild("Torso") or player.Character:FindFirstChild("UpperTorso")
        weld.Parent = seat

        task.wait()
        seat.CFrame = savedPosition

        setCharacterTransparency(player.Character, 0.5)

        if not cheats.noclip then
            toggleNoclip()
            if buttonsDict["👻 NoClip"] then
                buttonsDict["👻 NoClip"].Text = "👻 NoClip: ON"
                buttonsDict["👻 NoClip"].BackgroundColor3 = Color3.new(0.3, 0.8, 0.3)
            end
        end

        humanoid.WalkSpeed = invisibilityPreviousStates.originalSpeed * INVISIBILITY_CONFIG.SPEED_MULTIPLIER

        invisibilityButton.BackgroundColor3 = Color3.new(0.3, 0.8, 0.3)
        invisibilityButton.Text = "✨"

        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "👻 Invisibility ON",
            Text = "NoClip активирован, скорость x2",
            Duration = 3
        })
    else
        local invisChair = workspace:FindFirstChild("invischair")
        if invisChair then
            invisChair:Destroy()
        end

        if player.Character then
            setCharacterTransparency(player.Character, 0)
            
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = invisibilityPreviousStates.originalSpeed
            end
        end

        if not invisibilityPreviousStates.noclip and cheats.noclip then
            toggleNoclip()
            if buttonsDict["👻 NoClip"] then
                buttonsDict["👻 NoClip"].Text = "👻 NoClip: OFF"
                buttonsDict["👻 NoClip"].BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
            end
        end

        invisibilityButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
        invisibilityButton.Text = "👻"

        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "👻 Invisibility OFF",
            Text = "Вы теперь видимы",
            Duration = 3
        })
    end
    
    return cheats.invisible
end

local function togglePlatformWalk()
    cheats.platformWalk = not cheats.platformWalk
    if cheats.platformWalk then
        connections.platformWalk = RunService.Heartbeat:Connect(function()
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
                local root, hum = char.HumanoidRootPart, char.Humanoid
                if hum.MoveDirection.Magnitude > 0 or hum:GetState() == Enum.HumanoidStateType.Freefall then
                    local platform = Instance.new("Part")
                    platform.Name = "AirPlatform"
                    platform.Size = Vector3.new(8, 0.5, 8)
                    platform.Position = root.Position - Vector3.new(0, 3.5, 0)
                    platform.Anchored = true
                    platform.CanCollide = true
                    platform.Transparency = 0.3
                    platform.Material = Enum.Material.Neon
                    platform.BrickColor = BrickColor.new("Cyan")
                    platform.Parent = workspace
                    Debris:AddItem(platform, 0.6)
                end
            end
        end)
    else
        if connections.platformWalk then connections.platformWalk:Disconnect() end
        for _, platform in pairs(workspace:GetChildren()) do
            if platform.Name == "AirPlatform" then platform:Destroy() end
        end
    end
    return cheats.platformWalk
end

local function toggleAntiTrigger()
    cheats.antiTrigger = not cheats.antiTrigger
    if cheats.antiTrigger then
        connections.antiTrigger = RunService.Heartbeat:Connect(function()
            local char = player.Character
            if char and char:FindFirstChild("Humanoid") then
                local humanoid = char.Humanoid
                if humanoid.Health < humanoid.MaxHealth then
                    humanoid.Health = humanoid.MaxHealth
                end
            end
        end)
    else
        if connections.antiTrigger then connections.antiTrigger:Disconnect() end
    end
    return cheats.antiTrigger
end

local function toggleSpider()
    cheats.spider = not cheats.spider
    if cheats.spider then
        connections.spider = RunService.Heartbeat:Connect(function()
            local char = player.Character
            if not char then return end
            local root, hum = char:FindFirstChild("HumanoidRootPart"), char:FindFirstChild("Humanoid")
            if not root or not hum then return end
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = {char}
            for _, dir in pairs({root.CFrame.LookVector, -root.CFrame.LookVector, root.CFrame.RightVector, -root.CFrame.RightVector}) do
                local ray = workspace:Raycast(root.Position, dir * 4, params)
                if ray and ray.Instance and (hum:GetState() == Enum.HumanoidStateType.Jumping or hum:GetState() == Enum.HumanoidStateType.Freefall) then
                    root.Velocity = Vector3.new(root.Velocity.X * 0.8, 40, root.Velocity.Z * 0.8)
                end
            end
        end)
    else
        if connections.spider then connections.spider:Disconnect() end
    end
    return cheats.spider
end

toggleNoclip = function()
    cheats.noclip = not cheats.noclip
    if cheats.noclip then
        connections.noclip = RunService.Stepped:Connect(function()
            local char = player.Character
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if connections.noclip then connections.noclip:Disconnect() end
        local char = player.Character
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
    return cheats.noclip
end

toggleSpeed = function()
    cheats.speed = not cheats.speed
    local char = player.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            if cheats.invisible then
                hum.WalkSpeed = cheats.speed and 200 or (originalWalkSpeed * INVISIBILITY_CONFIG.SPEED_MULTIPLIER)
            else
                hum.WalkSpeed = cheats.speed and 100 or originalWalkSpeed
            end
        end
    end
    return cheats.speed
end

local function toggleInfiniteJump()
    cheats.infiniteJump = not cheats.infiniteJump
    if cheats.infiniteJump then
        connections.jump = UserInputService.JumpRequest:Connect(function()
            local char = player.Character
            if char then
                local hum = char:FindFirstChild("Humanoid")
                if hum then
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end)
    else
        if connections.jump then connections.jump:Disconnect() end
    end
    return cheats.infiniteJump
end

local function toggleESP()
    cheats.esp = not cheats.esp

    local function createHighlightForCharacter(char)
        if not char then return end
        if char:FindFirstChild("ESPHighlight") then return end
        local h = Instance.new("Highlight")
        h.Name = "ESPHighlight"
        h.FillColor = Color3.new(1, 0, 0)
        h.OutlineColor = Color3.new(1, 1, 1)
        h.FillTransparency = 0.5
        h.Parent = char
    end

    if cheats.esp then
        -- Для уже присутствующих игроков
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player then
                if p.Character then
                    createHighlightForCharacter(p.Character)
                end
                -- Подключаемся к событию CharacterAdded для постоянного восстановления
                connections["espChar_" .. p.UserId] = p.CharacterAdded:Connect(function(char)
                    task.wait(0.4)
                    if cheats.esp then createHighlightForCharacter(char) end
                end)
            end
        end

        -- Когда новые игроки заходят
        connections.espPlayerAdded = Players.PlayerAdded:Connect(function(p)
            if p ~= player then
                connections["espChar_" .. p.UserId] = p.CharacterAdded:Connect(function(char)
                    task.wait(0.4)
                    if cheats.esp then createHighlightForCharacter(char) end
                end)
                if p.Character then
                    task.wait(0.4)
                    createHighlightForCharacter(p.Character)
                end
            end
        end)

        -- Удаляем соединения по выходу игрока
        connections.espPlayerRemoving = Players.PlayerRemoving:Connect(function(p)
            local key = "espChar_" .. p.UserId
            if connections[key] then
                connections[key]:Disconnect()
                connections[key] = nil
            end
        end)

        -- Периодическое восстановление подсветок (нечасто, чтобы не нагружать)
        local accumulator = 0
        connections.espUpdater = RunService.Heartbeat:Connect(function(dt)
            accumulator = accumulator + dt
            if accumulator < 0.6 then return end
            accumulator = 0
            if not cheats.esp then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= player and p.Character then
                    createHighlightForCharacter(p.Character)
                end
            end
        end)
    else
        -- Отключаем все esp-соединения
        if connections.espUpdater then connections.espUpdater:Disconnect(); connections.espUpdater = nil end
        if connections.espPlayerAdded then connections.espPlayerAdded:Disconnect(); connections.espPlayerAdded = nil end
        if connections.espPlayerRemoving then connections.espPlayerRemoving:Disconnect(); connections.espPlayerRemoving = nil end

        -- Отключаем CharacterAdded-соединения созданные для ESP
        for k, conn in pairs(connections) do
            if type(k) == "string" and k:match("^espChar_") then
                if conn then conn:Disconnect() end
                connections[k] = nil
            end
        end

        -- Удаляем подсветки у всех игроков
        for _, p in pairs(Players:GetPlayers()) do
            if p.Character then
                local h = p.Character:FindFirstChild("ESPHighlight")
                if h then h:Destroy() end
            end
        end
    end

    return cheats.esp
end

local function toggleFly()
    cheats.fly = not cheats.fly
    local char = player.Character
    if not char then return cheats.fly end
    local root = char:FindFirstChild("HumanoidRootPart")
    if cheats.fly and root then
        local bv = Instance.new("BodyVelocity", root)
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Name = "FlyV"
        local bg = Instance.new("BodyGyro", root)
        bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bg.P = 5000
        bg.Name = "FlyG"
        connections.fly = RunService.Heartbeat:Connect(function()
            if root and bv and bv.Parent then
                local cam = workspace.CurrentCamera
                bg.CFrame = cam.CFrame
                bv.Velocity = char.Humanoid.MoveDirection.Magnitude > 0 and cam.CFrame.LookVector * 50 or Vector3.new(0, 0, 0)
            end
        end)
    else
        if root then
            local fv, fg = root:FindFirstChild("FlyV"), root:FindFirstChild("FlyG")
            if fv then fv:Destroy() end
            if fg then fg:Destroy() end
        end
        if connections.fly then connections.fly:Disconnect() end
    end
    return cheats.fly
end

local function toggleItemDuplication()
    cheats.itemDuplication = not cheats.itemDuplication

    if cheats.itemDuplication then
        local char = player.Character
        if not char then
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "📦 Дублирование предметов",
                Text = "Персонаж не найден",
                Duration = 3
            })
            cheats.itemDuplication = false
            return cheats.itemDuplication
        end

        local humanoid = char:FindFirstChild("Humanoid")
        if not humanoid then
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "📦 Дублирование предметов",
                Text = "Humanoid не найден",
                Duration = 3
            })
            cheats.itemDuplication = false
            return cheats.itemDuplication
        end

        -- Ищем активный инструмент в character игрока
        local activeTool = nil
        for _, child in pairs(char:GetChildren()) do
            if child:IsA("Tool") then
                activeTool = child
                break
            end
        end

        if not activeTool then
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "📦 Дублирование предметов",
                Text = "Активный инструмент не найден",
                Duration = 3
            })
            cheats.itemDuplication = false
            return cheats.itemDuplication
        end

        -- Создаем клон инструмента
        local success, duplicatedTool = pcall(function()
            return activeTool:Clone()
        end)

        if not success or not duplicatedTool then
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "📦 Дублирование предметов",
                Text = "Ошибка при создании копии инструмента",
                Duration = 3
            })
            cheats.itemDuplication = false
            return cheats.itemDuplication
        end

        -- Размещаем копию рядом с игроком
        local rootPart = char:FindFirstChild("HumanoidRootPart")
        if rootPart then
            local offset = Vector3.new(3, 0, 0) -- Размещаем справа от игрока
            duplicatedTool.Parent = workspace
            duplicatedTool.Handle.CFrame = rootPart.CFrame * CFrame.new(offset)

            -- Создаем визуальный эффект дублирования
            local effect = Instance.new("Part")
            effect.Name = "DuplicationEffect"
            effect.Size = Vector3.new(2, 2, 2)
            effect.Position = duplicatedTool.Handle.Position
            effect.Anchored = true
            effect.CanCollide = false
            effect.Material = Enum.Material.Neon
            effect.BrickColor = BrickColor.new("Bright yellow")
            effect.Transparency = 0.3
            effect.Shape = Enum.PartType.Ball
            effect.Parent = workspace

            local tween = TweenService:Create(effect, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = Vector3.new(0.1, 0.1, 0.1),
                Transparency = 1
            })
            tween:Play()
            Debris:AddItem(effect, 0.5)

            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "📦 Дублирование предметов",
                Text = "Инструмент '" .. activeTool.Name .. "' успешно дублирован!",
                Duration = 3
            })
        else
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "📦 Дублирование предметов",
                Text = "HumanoidRootPart не найден",
                Duration = 3
            })
            duplicatedTool:Destroy()
            cheats.itemDuplication = false
            return cheats.itemDuplication
        end
    else
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "📦 Дублирование предметов",
            Text = "Режим дублирования отключен",
            Duration = 2
        })
    end

    return cheats.itemDuplication
end

-- ==================== TELEPORT SYSTEM ====================
local function setupTeleport()
    cheats.teleport = not cheats.teleport
    if cheats.teleport then
        local teleportSelectButton = Instance.new("TextButton")
        teleportSelectButton.Name = "TeleportSelectButton"
        teleportSelectButton.Size = UDim2.new(0, 120, 0, 50)
        teleportSelectButton.Position = UDim2.new(0.5, -60, 0.8, 0)
        teleportSelectButton.BackgroundColor3 = Color3.new(0.2, 0.6, 1)
        teleportSelectButton.Text = "🎯 Выбрать точку"
        teleportSelectButton.TextScaled = true
        teleportSelectButton.TextColor3 = Color3.new(1, 1, 1)
        teleportSelectButton.Visible = true
        teleportSelectButton.Parent = screenGui
        createCorner(teleportSelectButton, 10)
        
        local isSelectingPoint = false
        local selectionCircle = nil
        
        teleportSelectButton.MouseButton1Click:Connect(function()
            isSelectingPoint = not isSelectingPoint
            
            if isSelectingPoint then
                teleportSelectButton.Text = "✅ Выбирается..."
                teleportSelectButton.BackgroundColor3 = Color3.new(0.2, 0.8, 0.2)
                
                if selectionCircle then selectionCircle:Destroy() end
                selectionCircle = Instance.new("Part")
                selectionCircle.Name = "SelectionCircle"
                selectionCircle.Size = Vector3.new(6, 0.2, 6)
                selectionCircle.Anchored = true
                selectionCircle.CanCollide = false
                selectionCircle.Material = Enum.Material.Neon
                selectionCircle.BrickColor = BrickColor.new("Bright yellow")
                selectionCircle.Transparency = 0.3
                selectionCircle.Parent = workspace
                
                local highlight = Instance.new("Highlight")
                highlight.FillColor = Color3.new(1, 1, 0)
                highlight.FillTransparency = 0.7
                highlight.OutlineColor = Color3.new(1, 1, 0)
                highlight.Parent = selectionCircle
                
                connections.teleportTracker = RunService.Heartbeat:Connect(function()
                    local hit = mouse.Hit
                    if hit then
                        selectionCircle.Position = hit.Position + Vector3.new(0, 0.1, 0)
                    end
                end)
                
                connections.teleportClick = UserInputService.InputBegan:Connect(function(input, gp)
                    if gp or not isSelectingPoint then return end
                    
                    if input.UserInputType == Enum.UserInputType.Touch or 
                       input.UserInputType == Enum.UserInputType.MouseButton1 then
                        
                        local hit = mouse.Hit
                        if hit then
                            if teleportMarker then teleportMarker:Destroy() end
                            teleportMarker = Instance.new("Part")
                            teleportMarker.Name = "TeleportMarker"
                            teleportMarker.Size = Vector3.new(4, 0.2, 4)
                            teleportMarker.Position = hit.Position
                            teleportMarker.Anchored = true
                            teleportMarker.CanCollide = false
                            teleportMarker.Transparency = 0.5
                            teleportMarker.Material = Enum.Material.Neon
                            teleportMarker.BrickColor = BrickColor.new("Bright green")
                            teleportMarker.Parent = workspace
                            
                            local teleportGoButton = Instance.new("TextButton")
                            teleportGoButton.Name = "TeleportGoButton"
                            teleportGoButton.Size = UDim2.new(0, 120, 0, 50)
                            teleportGoButton.Position = UDim2.new(0.5, -60, 0.7, 0)
                            teleportGoButton.BackgroundColor3 = Color3.new(0.2, 0.8, 0.2)
                            teleportGoButton.Text = "🚀 Телепорт!"
                            teleportGoButton.TextScaled = true
                            teleportGoButton.TextColor3 = Color3.new(1, 1, 1)
                            teleportGoButton.Visible = true
                            teleportGoButton.Parent = screenGui
                            createCorner(teleportGoButton, 10)
                            
                            teleportGoButton.MouseButton1Click:Connect(function()
                                if player.Character and player.Character.HumanoidRootPart then
                                    local effect = Instance.new("Part")
                                    effect.Size = Vector3.new(3, 3, 3)
                                    effect.Position = player.Character.HumanoidRootPart.Position
                                    effect.Anchored = true
                                    effect.CanCollide = false
                                    effect.Material = Enum.Material.Neon
                                    effect.BrickColor = BrickColor.new("Bright blue")
                                    effect.Shape = Enum.PartType.Ball
                                    effect.Parent = workspace
                                    
                                    local tween = TweenService:Create(effect, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                        Size = Vector3.new(0.1, 0.1, 0.1),
                                        Transparency = 1
                                    })
                                    tween:Play()
                                    Debris:AddItem(effect, 0.5)
                                    
                                    player.Character.HumanoidRootPart.CFrame = CFrame.new(hit.Position + Vector3.new(0, 5, 0))
                                    
                                    local afterEffect = Instance.new("Part")
                                    afterEffect.Size = Vector3.new(0.1, 0.1, 0.1)
                                    afterEffect.Position = hit.Position + Vector3.new(0, 2.5, 0)
                                    afterEffect.Anchored = true
                                    afterEffect.CanCollide = false
                                    afterEffect.Material = Enum.Material.Neon
                                    afterEffect.BrickColor = BrickColor.new("Bright blue")
                                    afterEffect.Shape = Enum.PartType.Ball
                                    afterEffect.Parent = workspace
                                    
                                    local tween2 = TweenService:Create(afterEffect, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                        Size = Vector3.new(3, 3, 3),
                                        Transparency = 1
                                    })
                                    tween2:Play()
                                    Debris:AddItem(afterEffect, 0.5)
                                    
                                    teleportGoButton:Destroy()
                                end
                            end)
                            
                            isSelectingPoint = false
                            teleportSelectButton.Text = "🎯 Выбрать точку"
                            teleportSelectButton.BackgroundColor3 = Color3.new(0.2, 0.6, 1)
                            
                            if selectionCircle then 
                                selectionCircle:Destroy()
                                selectionCircle = nil
                            end
                            
                            if connections.teleportTracker then
                                connections.teleportTracker:Disconnect()
                            end
                        end
                    end
                end)
            else
                teleportSelectButton.Text = "🎯 Выбрать точку"
                teleportSelectButton.BackgroundColor3 = Color3.new(0.2, 0.6, 1)
                
                if selectionCircle then 
                    selectionCircle:Destroy()
                    selectionCircle = nil
                end
                
                if connections.teleportTracker then
                    connections.teleportTracker:Disconnect()
                end
            end
        end)
        
        connections.teleportSelectButton = teleportSelectButton
    else
        if connections.teleportSelectButton then
            connections.teleportSelectButton:Destroy()
        end
        if connections.teleportTracker then
            connections.teleportTracker:Disconnect()
        end
        if connections.teleportClick then
            connections.teleportClick:Disconnect()
        end
        if teleportMarker then
            teleportMarker:Destroy()
        end
        
        local teleportGoButton = screenGui:FindFirstChild("TeleportGoButton")
        if teleportGoButton then
            teleportGoButton:Destroy()
        end
    end
    return cheats.teleport
end

local checkpointMenu = nil
local function openCheckpointManager()
    if checkpointMenu and checkpointMenu.Parent then
        checkpointMenu.Visible = not checkpointMenu.Visible
        return
    end
    
    checkpointMenu = Instance.new("Frame")
    checkpointMenu.Name = "CheckpointMenu"
    checkpointMenu.Size = UDim2.new(0, 320, 0.6, 0)
    checkpointMenu.Position = UDim2.new(0.5, -160, 0.5, 0)
    checkpointMenu.AnchorPoint = Vector2.new(0.5, 0.5)
    checkpointMenu.BackgroundColor3 = Color3.new(0.12, 0.12, 0.12)
    checkpointMenu.BorderSizePixel = 0
    checkpointMenu.Parent = screenGui
    createCorner(checkpointMenu, 12)
    
    local cpTitleBar = Instance.new("Frame")
    cpTitleBar.Size = UDim2.new(1, 0, 0, 35)
    cpTitleBar.BackgroundColor3 = Color3.new(0.08, 0.08, 0.08)
    cpTitleBar.Parent = checkpointMenu
    createCorner(cpTitleBar, 12)
    
    local cpCount = 0; for _ in pairs(_G.SavedCheckpoints) do cpCount = cpCount + 1 end
    
    local cpTitle = Instance.new("TextLabel")
    cpTitle.Size = UDim2.new(1, -70, 1, 0)
    cpTitle.Text = "📍 CP (" .. cpCount .. ")"
    cpTitle.TextScaled = true
    cpTitle.TextColor3 = Color3.new(0.4, 0.8, 1)
    cpTitle.BackgroundTransparency = 1
    cpTitle.Font = Enum.Font.GothamBold
    cpTitle.Parent = cpTitleBar
    
    local cpMinBtn = Instance.new("TextButton")
    cpMinBtn.Size = UDim2.new(0, 30, 0, 30); cpMinBtn.Position = UDim2.new(1, -65, 0, 2.5); cpMinBtn.Text = "_"; cpMinBtn.TextScaled = true; cpMinBtn.TextColor3 = Color3.new(1,1,1); cpMinBtn.BackgroundColor3 = Color3.new(0.3,0.3,0.3); cpMinBtn.Parent = cpTitleBar; createCorner(cpMinBtn, 6)
    cpMinBtn.MouseButton1Click:Connect(function() checkpointMenu.Visible = false end)
    
    local cpCloseBtn = Instance.new("TextButton")
    cpCloseBtn.Size = UDim2.new(0, 30, 0, 30); cpCloseBtn.Position = UDim2.new(1, -32, 0, 2.5); cpCloseBtn.Text = "X"; cpCloseBtn.TextScaled = true; cpCloseBtn.TextColor3 = Color3.new(1,1,1); cpCloseBtn.BackgroundColor3 = Color3.new(0.8,0.2,0.2); cpCloseBtn.Parent = cpTitleBar; createCorner(cpCloseBtn, 6)
    cpCloseBtn.MouseButton1Click:Connect(function() checkpointMenu:Destroy(); checkpointMenu = nil end)
    
    makeDraggable(checkpointMenu, cpTitleBar)
    
    local inputBox = Instance.new("TextBox")
    inputBox.Size = UDim2.new(0.58, 0, 0, 30); inputBox.Position = UDim2.new(0.02, 0, 0, 40); inputBox.PlaceholderText = "Name..."; inputBox.TextScaled = true; inputBox.BackgroundColor3 = Color3.new(0.2,0.2,0.2); inputBox.Parent = checkpointMenu; createCorner(inputBox, 8)
    
    local saveBtn = Instance.new("TextButton")
    saveBtn.Size = UDim2.new(0.38, 0, 0, 30); saveBtn.Position = UDim2.new(0.61, 0, 0, 40); saveBtn.Text = "💾"; saveBtn.TextScaled = true; saveBtn.BackgroundColor3 = Color3.new(0.2,0.8,0.2); saveBtn.Parent = checkpointMenu; createCorner(saveBtn, 8)
    
    local listFrame = Instance.new("ScrollingFrame")
    listFrame.Size = UDim2.new(0.96, 0, 1, -155); listFrame.Position = UDim2.new(0.02, 0, 0, 75); listFrame.BackgroundColor3 = Color3.new(0.08,0.08,0.08); listFrame.ScrollBarThickness = 4; listFrame.Parent = checkpointMenu; createCorner(listFrame, 8)
    
    local listLayout = Instance.new("UIListLayout"); listLayout.Padding = UDim.new(0, 3); listLayout.Parent = listFrame
    
    local function updateList()
        for _, child in pairs(listFrame:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
        cpCount = 0
        for name, data in pairs(_G.SavedCheckpoints) do
            cpCount = cpCount + 1
            local item = Instance.new("Frame"); item.Size = UDim2.new(1, -8, 0, 42); item.BackgroundColor3 = Color3.new(0.16,0.16,0.16); item.Parent = listFrame; createCorner(item, 6)
            local nameLabel = Instance.new("TextLabel", item); nameLabel.Size = UDim2.new(0.55, 0, 1, 0); nameLabel.Position = UDim2.new(0, 3, 0, 0); nameLabel.Text = "📍 " .. name; nameLabel.TextScaled = true; nameLabel.TextXAlignment = Enum.TextXAlignment.Left; nameLabel.BackgroundTransparency = 1
            local tpBtn = Instance.new("TextButton", item); tpBtn.Size = UDim2.new(0.18, 0, 0.75, 0); tpBtn.Position = UDim2.new(0.57, 0, 0.125, 0); tpBtn.Text = "TP"; tpBtn.TextScaled = true; tpBtn.BackgroundColor3 = Color3.new(0.3,0.6,0.9); createCorner(tpBtn, 4)
            tpBtn.MouseButton1Click:Connect(function() if player.Character and player.Character.HumanoidRootPart then player.Character.HumanoidRootPart.CFrame = data.CFrame end end)
            local delBtn = Instance.new("TextButton", item); delBtn.Size = UDim2.new(0.2, 0, 0.75, 0); delBtn.Position = UDim2.new(0.77, 0, 0.125, 0); delBtn.Text = "🗑️"; delBtn.TextScaled = true; delBtn.BackgroundColor3 = Color3.new(0.8,0.2,0.2); createCorner(delBtn, 4)
            delBtn.MouseButton1Click:Connect(function() _G.SavedCheckpoints[name] = nil; saveCheckpointsToFile(); updateList() end)
        end
        cpTitle.Text = "📍 CP (" .. cpCount .. ")"; listFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
    end
    
    saveBtn.MouseButton1Click:Connect(function() if player.Character and player.Character.HumanoidRootPart then local cpName = inputBox.Text ~= "" and inputBox.Text or "CP"..(cpCount+1); _G.SavedCheckpoints[cpName] = {CFrame = player.Character.HumanoidRootPart.CFrame, Position = {X=player.Character.HumanoidRootPart.Position.X,Y=player.Character.HumanoidRootPart.Position.Y,Z=player.Character.HumanoidRootPart.Position.Z}}; saveCheckpointsToFile(); inputBox.Text = ""; updateList() end end)
    
    local quickFrame = Instance.new("Frame"); quickFrame.Size = UDim2.new(0.96, 0, 0, 70); quickFrame.Position = UDim2.new(0.02, 0, 1, -75); quickFrame.BackgroundTransparency = 1; quickFrame.Parent = checkpointMenu
    local quickButtons = {{name="Start",c=Color3.new(0.3,0.8,0.3)},{name="Mid",c=Color3.new(0.9,0.7,0.2)},{name="End",c=Color3.new(0.8,0.3,0.3)},{name="Secret",c=Color3.new(0.6,0.3,0.8)}}
    for i, btn in ipairs(quickButtons) do
        local qb = Instance.new("TextButton", quickFrame); qb.Size=UDim2.new(0.23,0,0,32); qb.Position=UDim2.new((i-1)*0.25+0.01,0,0,0); qb.Text=btn.name; qb.TextScaled=true; qb.BackgroundColor3=btn.c; createCorner(qb,6)
        qb.MouseButton1Click:Connect(function() if player.Character and player.Character.HumanoidRootPart then _G.SavedCheckpoints[btn.name] = {CFrame=player.Character.HumanoidRootPart.CFrame,Position={X=player.Character.HumanoidRootPart.Position.X,Y=player.Character.HumanoidRootPart.Position.Y,Z=player.Character.HumanoidRootPart.Position.Z}}; saveCheckpointsToFile(); updateList() end end)
    end
    local clearBtn = Instance.new("TextButton",quickFrame); clearBtn.Size=UDim2.new(1,0,0,32); clearBtn.Position=UDim2.new(0,0,0,37); clearBtn.Text="🗑️ Clear All"; clearBtn.TextScaled=true; clearBtn.BackgroundColor3=Color3.new(0.6,0.1,0.1); createCorner(clearBtn,6)
    clearBtn.MouseButton1Click:Connect(function() _G.SavedCheckpoints={}; saveCheckpointsToFile(); updateList() end)
    
    updateList()
end

-- ==================== KEYBIND MANAGER ====================
local keybindMenu = nil
local function openKeybindManager()
    if keybindMenu and keybindMenu.Parent then
        keybindMenu.Visible = not keybindMenu.Visible
        return
    end

    keybindMenu = Instance.new("Frame")
    keybindMenu.Name = "KeybindMenu"
    keybindMenu.Size = UDim2.new(0, 400, 0.7, 0)
    keybindMenu.Position = UDim2.new(0.5, -200, 0.5, 0)
    keybindMenu.AnchorPoint = Vector2.new(0.5, 0.5)
    keybindMenu.BackgroundColor3 = Color3.new(0.12, 0.12, 0.12)
    keybindMenu.BorderSizePixel = 0
    keybindMenu.Parent = screenGui
    createCorner(keybindMenu, 12)

    local kbTitleBar = Instance.new("Frame")
    kbTitleBar.Size = UDim2.new(1, 0, 0, 35)
    kbTitleBar.BackgroundColor3 = Color3.new(0.08, 0.08, 0.08)
    kbTitleBar.Parent = keybindMenu
    createCorner(kbTitleBar, 12)

    local kbTitle = Instance.new("TextLabel")
    kbTitle.Size = UDim2.new(1, -70, 1, 0)
    kbTitle.Text = "⌨️ Keybinds"
    kbTitle.TextScaled = true
    kbTitle.TextColor3 = Color3.new(0.8, 0.4, 1)
    kbTitle.BackgroundTransparency = 1
    kbTitle.Font = Enum.Font.GothamBold
    kbTitle.Parent = kbTitleBar

    local kbMinBtn = Instance.new("TextButton")
    kbMinBtn.Size = UDim2.new(0, 30, 0, 30)
    kbMinBtn.Position = UDim2.new(1, -65, 0, 2.5)
    kbMinBtn.Text = "_"
    kbMinBtn.TextScaled = true
    kbMinBtn.TextColor3 = Color3.new(1,1,1)
    kbMinBtn.BackgroundColor3 = Color3.new(0.3,0.3,0.3)
    kbMinBtn.Parent = kbTitleBar
    createCorner(kbMinBtn, 6)
    kbMinBtn.MouseButton1Click:Connect(function() keybindMenu.Visible = false end)

    local kbCloseBtn = Instance.new("TextButton")
    kbCloseBtn.Size = UDim2.new(0, 30, 0, 30)
    kbCloseBtn.Position = UDim2.new(1, -32, 0, 2.5)
    kbCloseBtn.Text = "X"
    kbCloseBtn.TextScaled = true
    kbCloseBtn.TextColor3 = Color3.new(1,1,1)
    kbCloseBtn.BackgroundColor3 = Color3.new(0.8,0.2,0.2)
    kbCloseBtn.Parent = kbTitleBar
    createCorner(kbCloseBtn, 6)
    kbCloseBtn.MouseButton1Click:Connect(function() keybindMenu:Destroy(); keybindMenu = nil end)

    makeDraggable(keybindMenu, kbTitleBar)

    local listFrame = Instance.new("ScrollingFrame")
    listFrame.Size = UDim2.new(0.96, 0, 1, -40)
    listFrame.Position = UDim2.new(0.02, 0, 0, 40)
    listFrame.BackgroundColor3 = Color3.new(0.08,0.08,0.08)
    listFrame.ScrollBarThickness = 4
    listFrame.Parent = keybindMenu
    createCorner(listFrame, 8)

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 3)
    listLayout.Parent = listFrame

    local function updateKeybindList()
        for _, child in pairs(listFrame:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end

        -- Список доступных функций для биндов
        local availableFunctions = {
            {name = "🎯 Teleport Reach", func = "toggleInfiniteReach"},
            {name = "🟩 Platform Walk", func = "togglePlatformWalk"},
            {name = "💀 Anti-Trigger", func = "toggleAntiTrigger"},
            {name = "🕷️ Spider Climb", func = "toggleSpider"},
            {name = "👻 NoClip", func = "toggleNoclip"},
            {name = "⚡ Speed Hack", func = "toggleSpeed"},
            {name = "🦘 Infinite Jump", func = "toggleInfiniteJump"},
            {name = "👁️ ESP Players", func = "toggleESP"},
            {name = "✈️ Fly Mode", func = "toggleFly"},
            {name = "⏪ Rewind 5s", func = "toggleRewind"},
            {name = "🖲️ Teleport (Click)", func = "setupTeleport"},
            {name = "📦 Дублировать предмет", func = "toggleItemDuplication"},
            {name = "👻 Invisibility", func = "toggleInvisibility"},
            {name = "📍 Checkpoints", func = "openCheckpointManager"}
        }

        for _, funcInfo in ipairs(availableFunctions) do
            local item = Instance.new("Frame")
            item.Size = UDim2.new(1, -8, 0, 50)
            item.BackgroundColor3 = Color3.new(0.16,0.16,0.16)
            item.Parent = listFrame
            createCorner(item, 6)

            local nameLabel = Instance.new("TextLabel", item)
            nameLabel.Size = UDim2.new(0.4, 0, 1, 0)
            nameLabel.Position = UDim2.new(0.02, 0, 0, 0)
            nameLabel.Text = funcInfo.name
            nameLabel.TextScaled = true
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.BackgroundTransparency = 1
            nameLabel.TextColor3 = Color3.new(1, 1, 1)

            local keybindLabel = Instance.new("TextLabel", item)
            keybindLabel.Size = UDim2.new(0.25, 0, 1, 0)
            keybindLabel.Position = UDim2.new(0.45, 0, 0, 0)
            keybindLabel.Text = "Без бинда"
            keybindLabel.TextScaled = true
            keybindLabel.TextXAlignment = Enum.TextXAlignment.Center
            keybindLabel.BackgroundTransparency = 1
            keybindLabel.TextColor3 = Color3.new(0.7, 0.7, 0.7)

            -- Находим текущий бинд для этой функции
            local currentKeyCode = nil
            for keyCode, funcName in pairs(keybinds) do
                if funcName == funcInfo.func then
                    currentKeyCode = keyCode
                    keybindLabel.Text = getKeyName(keyCode)
                    keybindLabel.TextColor3 = Color3.new(0.4, 0.8, 1)
                    break
                end
            end

            local setBindBtn = Instance.new("TextButton", item)
            setBindBtn.Size = UDim2.new(0.15, 0, 0.7, 0)
            setBindBtn.Position = UDim2.new(0.73, 0, 0.15, 0)
            setBindBtn.Text = "Установить"
            setBindBtn.TextScaled = true
            setBindBtn.BackgroundColor3 = Color3.new(0.2, 0.6, 0.2)
            setBindBtn.TextColor3 = Color3.new(1, 1, 1)
            createCorner(setBindBtn, 4)

            local removeBindBtn = Instance.new("TextButton", item)
            removeBindBtn.Size = UDim2.new(0.15, 0, 0.7, 0)
            removeBindBtn.Position = UDim2.new(0.9, 0, 0.15, 0)
            removeBindBtn.Text = "Удалить"
            removeBindBtn.TextScaled = true
            removeBindBtn.BackgroundColor3 = Color3.new(0.8, 0.2, 0.2)
            removeBindBtn.TextColor3 = Color3.new(1, 1, 1)
            createCorner(removeBindBtn, 4)

            setBindBtn.MouseButton1Click:Connect(function()
                if isBindingMode then return end

                isBindingMode = true
                currentBindingButton = setBindBtn
                setBindBtn.Text = "Нажмите клавишу..."
                setBindBtn.BackgroundColor3 = Color3.new(0.8, 0.6, 0.2)

                -- Обработчик для захвата клавиши
                local keyCaptureConnection
                keyCaptureConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                    if gameProcessed then return end

                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        -- Удаляем старый бинд для этой функции
                        for k, v in pairs(keybinds) do
                            if v == funcInfo.func then
                                keybinds[k] = nil
                                break
                            end
                        end

                        -- Устанавливаем новый бинд
                        keybinds[input.KeyCode] = funcInfo.func
                        saveKeybindsToFile()

                        -- Обновляем интерфейс
                        updateKeybindList()

                        -- Восстанавливаем состояние кнопки
                        isBindingMode = false
                        setBindBtn.Text = "Установить"
                        setBindBtn.BackgroundColor3 = Color3.new(0.2, 0.6, 0.2)

                        -- Отключаем обработчик
                        if keyCaptureConnection then
                            keyCaptureConnection:Disconnect()
                        end

                        game:GetService("StarterGui"):SetCore("SendNotification", {
                            Title = "⌨️ Keybind",
                            Text = funcInfo.name .. " привязан к " .. getKeyName(input.KeyCode),
                            Duration = 2
                        })
                    end
                end)
            end)

            removeBindBtn.MouseButton1Click:Connect(function()
                if currentKeyCode then
                    keybinds[currentKeyCode] = nil
                    saveKeybindsToFile()
                    updateKeybindList()

                    game:GetService("StarterGui"):SetCore("SendNotification", {
                        Title = "⌨️ Keybind",
                        Text = "Бинд для " .. funcInfo.name .. " удален",
                        Duration = 2
                    })
                end
            end)
        end

        listFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
    end

    updateKeybindList()
end

-- ==================== BUTTON DEFINITIONS ====================
createButton("🎯 Teleport Reach", toggleInfiniteReach, Color3.fromRGB(0, 191, 255), true)
createButton("🟩 Platform Walk", togglePlatformWalk, Color3.new(0.3, 0.9, 0.6), true)
createButton("💀 Anti-Trigger", toggleAntiTrigger, Color3.new(0.8, 0.3, 0.8), true)
createButton("🕷️ Spider Climb", toggleSpider, Color3.new(0.8, 0.3, 0.5), true)
createButton("👻 NoClip", toggleNoclip, nil, true)
createButton("⚡ Speed Hack", toggleSpeed, nil, true)
createButton("🦘 Infinite Jump", toggleInfiniteJump, nil, true)
createButton("👁️ ESP Players", toggleESP, nil, true)
createButton("✈️ Fly Mode", toggleFly, nil, true)
createButton("⏪ Rewind 5s", toggleRewind, Color3.new(0.7, 0.3, 0.9), false)
createButton("🖲️ Teleport (Click)", setupTeleport, Color3.new(0.5, 0.3, 0.7), true)

buttonCount = buttonCount + 0.2
createButton("🔀 TP Random", function()
    local otherPlayers = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character then table.insert(otherPlayers, p) end
    end
    if #otherPlayers > 0 then
        local randomPlayer = otherPlayers[math.random(1, #otherPlayers)]
        if randomPlayer.Character and randomPlayer.Character.HumanoidRootPart and player.Character and player.Character.HumanoidRootPart then
            player.Character.HumanoidRootPart.CFrame = randomPlayer.Character.HumanoidRootPart.CFrame + Vector3.new(5, 0, 0)
        end
    end
end, Color3.new(0.9, 0.6, 0.2), false)

createButton("📍 Checkpoints", openCheckpointManager, Color3.new(0.3, 0.7, 0.9), false)
createButton("📦 Дублировать предмет", toggleItemDuplication, Color3.new(0.9, 0.7, 0.3), true)
createButton("⌨️ Keybinds", openKeybindManager, Color3.new(0.8, 0.4, 1), false)

-- ==================== EVENT HANDLERS ====================
minimizeButton.MouseButton1Click:Connect(function() mainFrame.Visible, toggleButton.Visible = false, true end)
toggleButton.MouseButton1Click:Connect(function() mainFrame.Visible, toggleButton.Visible = true, false end)

invisibilityButton.MouseButton1Click:Connect(function()
    toggleInvisibility()
end)

player.CharacterAdded:Connect(function(character)
    cheats.invisible = false
    invisibilityButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
    invisibilityButton.Text = "👻"
    
    local invisChair = workspace:FindFirstChild("invischair")
    if invisChair then
        invisChair:Destroy()
    end
    
    local humanoid = character:WaitForChild("Humanoid")
    if humanoid then
        originalWalkSpeed = humanoid.WalkSpeed
        invisibilityPreviousStates.originalSpeed = originalWalkSpeed
    end
end)

if player.Character and player.Character:FindFirstChild("Humanoid") then
    originalWalkSpeed = player.Character.Humanoid.WalkSpeed
    invisibilityPreviousStates.originalSpeed = originalWalkSpeed
end

closeButton.MouseButton1Click:Connect(function()
    saveCheckpointsToFile()
    
    if cheats.invisible then
        toggleInvisibility()
    end
    
    if cheats.infiniteReach then
        toggleInfiniteReach()
    end
    
    for cheat, state in pairs(cheats) do
        if state and cheat ~= "invisible" and cheat ~= "infiniteReach" then
            local funcName = "toggle" .. cheat:sub(1,1):upper() .. cheat:sub(2)
            if _G[funcName] then pcall(_G[funcName]) end
        end
    end

    -- Отключаем обработчик биндов
    if connections.keybindHandler then
        connections.keybindHandler:Disconnect()
    end

    screenGui:Destroy()
end)


-- ==================== FINAL NOTIFICATION ====================
local cpCount = 0; for _ in pairs(_G.SavedCheckpoints) do cpCount = cpCount + 1 end
local kbCount = 0; for _ in pairs(keybinds) do kbCount = kbCount + 1 end
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "🚀 AC Tester v4.3 + Keybinds",
    Text = "Работает через стены! Биндов: " .. kbCount,
    Duration = 4
})
print("AC TESTER v4.3 TELEPORT REACH ENHANCED + SPIDER-MAN + KEYBINDS: Loaded successfully!")
