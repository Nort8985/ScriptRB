-- Spider-Man Script для Roblox
-- Автор: Kilo Code
-- Описание: Превращает игрока в человека-паука с полетом и визуальными эффектами

local SpiderMan = {}
SpiderMan.__index = SpiderMan

-- Сервисы Roblox
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- Константы
local FLIGHT_SPEED = 50
local FLIGHT_ACCELERATION = 2
local MAX_FLIGHT_SPEED = 100
local WEB_SHOOT_COOLDOWN = 0.5
local FLIGHT_FUEL_CONSUMPTION = 1

-- Цвета для визуальных эффектов
local SPIDER_COLOR = Color3.fromRGB(255, 0, 0)
local WEB_COLOR = Color3.fromRGB(255, 255, 255)

function SpiderMan.new(player)
    local self = setmetatable({}, SpiderMan)

    -- Ссылки на игрока и персонажа
    self.Player = player
    self.Character = player.Character or player.CharacterAdded:Wait()
    self.Humanoid = self.Character:WaitForChild("Humanoid")
    self.HumanoidRootPart = self.Character:WaitForChild("HumanoidRootPart")

    -- Состояния
    self.IsSpiderMan = false
    self.IsFlying = false
    self.FlightVelocity = Vector3.new(0, 0, 0)
    self.CurrentFlightSpeed = 0
    self.LastWebShoot = 0
    self.FlightFuel = 100

    -- Визуальные элементы
    self.WebParticles = nil
    self.FlightParticles = nil
    self.SpiderEmblem = nil

    -- Звуки
    self.FlightSound = nil
    self.WebShootSound = nil

    -- Связи событий
    self.Connections = {}

    return self
end

function SpiderMan:Initialize()
    -- Ждем загрузки персонажа
    if not self.Character or not self.Character.Parent then
        self.Player.CharacterAdded:Wait()
        self.Character = self.Player.Character
        self.Humanoid = self.Character:WaitForChild("Humanoid")
        self.HumanoidRootPart = self.Character:WaitForChild("HumanoidRootPart")
    end

    -- Создаем визуальные эффекты
    self:CreateVisualEffects()

    -- Создаем звуки
    self:CreateSounds()

    -- Подключаем управление
    self:SetupControls()

    -- Запускаем цикл обновления
    self:StartUpdateLoop()

    print("Spider-Man инициализирован для игрока: " .. self.Player.Name)
end

function SpiderMan:CreateVisualEffects()
    -- Создаем паутину-пarticles
    self.WebParticles = Instance.new("ParticleEmitter")
    self.WebParticles.Name = "WebParticles"
    self.WebParticles.Texture = "rbxassetid://244028469" -- Текстура паутины
    self.WebParticles.Color = ColorSequence.new(WEB_COLOR)
    self.WebParticles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 0.1)
    })
    self.WebParticles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1)
    })
    self.WebParticles.Lifetime = NumberRange.new(0.5, 1)
    self.WebParticles.Rate = 0
    self.WebParticles.Speed = NumberRange.new(20, 30)
    self.WebParticles.Parent = self.HumanoidRootPart

    -- Создаем particles для полета
    self.FlightParticles = Instance.new("ParticleEmitter")
    self.FlightParticles.Name = "FlightParticles"
    self.FlightParticles.Texture = "rbxassetid://133619974" -- Огненная текстура
    self.FlightParticles.Color = ColorSequence.new(SPIDER_COLOR)
    self.FlightParticles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0.1)
    })
    self.FlightParticles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 1)
    })
    self.FlightParticles.Lifetime = NumberRange.new(0.3, 0.6)
    self.FlightParticles.Rate = 0
    self.FlightParticles.Speed = NumberRange.new(10, 20)
    self.FlightParticles.Parent = self.HumanoidRootPart

    -- Создаем эмблему паука
    self.SpiderEmblem = Instance.new("Decal")
    self.SpiderEmblem.Name = "SpiderEmblem"
    self.SpiderEmblem.Texture = "rbxassetid://123456789" -- ID текстуры эмблемы паука
    self.SpiderEmblem.Face = Enum.NormalId.Front

    -- Добавляем эмблему на торс персонажа
    local torso = self.Character:FindFirstChild("Torso") or self.Character:FindFirstChild("UpperTorso")
    if torso then
        local emblemClone = self.SpiderEmblem:Clone()
        emblemClone.Parent = torso
        self.SpiderEmblem = emblemClone
    end
end

function SpiderMan:CreateSounds()
    -- Создаем звук полета
    self.FlightSound = Instance.new("Sound")
    self.FlightSound.Name = "FlightSound"
    self.FlightSound.SoundId = "rbxassetid://142700651" -- Звук реактивного двигателя
    self.FlightSound.Volume = 0.5
    self.FlightSound.Looped = true
    self.FlightSound.Parent = self.HumanoidRootPart

    -- Создаем звук выстрела паутины
    self.WebShootSound = Instance.new("Sound")
    self.WebShootSound.Name = "WebShootSound"
    self.WebShootSound.SoundId = "rbxassetid://131961136" -- Звук выстрела
    self.WebShootSound.Volume = 0.3
    self.WebShootSound.Parent = self.HumanoidRootPart
end

function SpiderMan:SetupControls()
    -- Подключаем ввод для ПК
    table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end

        if input.KeyCode == Enum.KeyCode.E then
            self:StartFlight()
        elseif input.KeyCode == Enum.KeyCode.Q then
            self:ShootWeb()
        end
    end))

    table.insert(self.Connections, UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if input.KeyCode == Enum.KeyCode.E then
            self:StopFlight()
        end
    end))

    -- Подключаем касания для мобильных устройств
    table.insert(self.Connections, UserInputService.TouchStarted:Connect(function(touch, gameProcessed)
        if gameProcessed then return end
        self:StartFlight()
    end))

    table.insert(self.Connections, UserInputService.TouchEnded:Connect(function(touch, gameProcessed)
        self:StopFlight()
    end))
end

function SpiderMan:StartUpdateLoop()
    table.insert(self.Connections, RunService.Heartbeat:Connect(function(deltaTime)
        self:Update(deltaTime)
    end))
end

function SpiderMan:Update(deltaTime)
    if not self.IsFlying or not self:IsInAir() then
        self:StopFlight()
        return
    end

    -- Обновляем физику полета
    self:UpdateFlightPhysics(deltaTime)

    -- Обновляем визуальные эффекты
    self:UpdateVisualEffects()

    -- Проверяем топливо
    if self.FlightFuel <= 0 then
        self:StopFlight()
    end
end

function SpiderMan:UpdateFlightPhysics(deltaTime)
    local camera = workspace.CurrentCamera
    if not camera then return end

    -- Получаем направление взгляда камеры
    local lookVector = camera.CFrame.LookVector

    -- Увеличиваем скорость полета
    self.CurrentFlightSpeed = math.min(
        self.CurrentFlightSpeed + (FLIGHT_ACCELERATION * deltaTime),
        MAX_FLIGHT_SPEED
    )

    -- Применяем скорость к персонажу
    self.FlightVelocity = lookVector * self.CurrentFlightSpeed
    self.HumanoidRootPart.Velocity = Vector3.new(
        self.FlightVelocity.X,
        math.max(self.FlightVelocity.Y, -10), -- Не даем падать слишком быстро
        self.FlightVelocity.Z
    )

    -- Потребляем топливо
    self.FlightFuel = math.max(0, self.FlightFuel - (FLIGHT_FUEL_CONSUMPTION * deltaTime))

    -- Создаем эффект паутины для движения
    self:CreateWebTrail()
end

function SpiderMan:UpdateVisualEffects()
    if self.IsFlying then
        -- Включаем particles полета
        self.FlightParticles.Rate = 50

        -- Включаем звук полета
        if self.FlightSound and not self.FlightSound.IsPlaying then
            self.FlightSound:Play()
        end
    else
        -- Выключаем particles полета
        self.FlightParticles.Rate = 0

        -- Выключаем звук полета
        if self.FlightSound and self.FlightSound.IsPlaying then
            self.FlightSound:Stop()
        end
    end
end

function SpiderMan:StartFlight()
    if not self:IsInAir() or self.IsFlying then return end

    self.IsFlying = true
    self.CurrentFlightSpeed = FLIGHT_SPEED

    -- Включаем визуальные эффекты
    self.FlightParticles.Enabled = true

    print("Полёт начат для игрока: " .. self.Player.Name)
end

function SpiderMan:StopFlight()
    if not self.IsFlying then return end

    self.IsFlying = false
    self.CurrentFlightSpeed = 0
    self.FlightVelocity = Vector3.new(0, 0, 0)

    -- Выключаем визуальные эффекты
    self.FlightParticles.Enabled = false

    print("Полёт остановлен для игрока: " .. self.Player.Name)
end

function SpiderMan:ShootWeb()
    local currentTime = tick()
    if currentTime - self.LastWebShoot < WEB_SHOOT_COOLDOWN then return end
    self.LastWebShoot = currentTime

    -- Создаем веб-шот
    local webShot = Instance.new("Part")
    webShot.Size = Vector3.new(0.2, 0.2, 2)
    webShot.Color = WEB_COLOR
    webShot.Material = Enum.Material.Neon
    webShot.CanCollide = false
    webShot.Anchored = true

    -- Позиционируем веб-шот перед игроком
    local camera = workspace.CurrentCamera
    if camera then
        local startPos = self.HumanoidRootPart.Position + camera.CFrame.LookVector * 2
        local endPos = startPos + camera.CFrame.LookVector * 20

        webShot.CFrame = CFrame.new(startPos, endPos)
    end

    webShot.Parent = workspace

    -- Добавляем particles паутины
    local webParticles = self.WebParticles:Clone()
    webParticles.Parent = webShot
    webParticles.Rate = 100

    -- Воспроизводим звук
    if self.WebShootSound then
        self.WebShootSound:Play()
    end

    -- Удаляем через 2 секунды
    Debris:AddItem(webShot, 2)

    -- Создаем эффект прилипания
    self:CreateWebAttachEffect(webShot)
end

function SpiderMan:CreateWebTrail()
    -- Создаем след паутины во время полета
    local trail = Instance.new("Part")
    trail.Size = Vector3.new(0.1, 0.1, 0.1)
    trail.Color = WEB_COLOR
    trail.Material = Enum.Material.Neon
    trail.CanCollide = false
    trail.Anchored = true
    trail.Position = self.HumanoidRootPart.Position + Vector3.new(
        math.random(-1, 1),
        math.random(-1, 1),
        math.random(-1, 1)
    )

    trail.Parent = workspace

    -- Удаляем через короткое время
    Debris:AddItem(trail, 0.5)
end

function SpiderMan:CreateWebAttachEffect(webShot)
    -- Создаем эффект прилипания паутины
    local attachEffect = Instance.new("ParticleEmitter")
    attachEffect.Texture = "rbxassetid://244028469"
    attachEffect.Color = ColorSequence.new(WEB_COLOR)
    attachEffect.Size = NumberSequence.new(0.5)
    attachEffect.Lifetime = NumberRange.new(0.5, 1)
    attachEffect.Rate = 20
    attachEffect.Speed = NumberRange.new(5, 10)
    attachEffect.Parent = webShot

    -- Удаляем эффект через 1 секунду
    Debris:AddItem(attachEffect, 1)
end

function SpiderMan:IsInAir()
    -- Проверяем, находится ли игрок в воздухе
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {self.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

    local raycastResult = workspace:Raycast(
        self.HumanoidRootPart.Position,
        Vector3.new(0, -5, 0),
        raycastParams
    )

    return raycastResult == nil
end

function SpiderMan:TransformToSpiderMan()
    if self.IsSpiderMan then return end

    self.IsSpiderMan = true

    -- Добавляем костюм человека-паука (цвета)
    for _, part in pairs(self.Character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            if part.Name:find("Torso") or part.Name:find("Arm") or part.Name:find("Leg") then
                part.Color = Color3.fromRGB(255, 0, 0) -- Красный цвет
                part.Material = Enum.Material.SmoothPlastic
            elseif part.Name:find("Head") then
                part.Color = Color3.fromRGB(255, 255, 255) -- Белая маска
            end
        end
    end

    -- Добавляем синие элементы костюма
    local torso = self.Character:FindFirstChild("Torso") or self.Character:FindFirstChild("UpperTorso")
    if torso then
        local bluePart = Instance.new("Part")
        bluePart.Size = Vector3.new(1.8, 0.8, 0.2)
        bluePart.Color = Color3.fromRGB(0, 0, 255)
        bluePart.Material = Enum.Material.SmoothPlastic
        bluePart.CanCollide = false
        bluePart.Anchored = false

        local weld = Instance.new("Weld")
        weld.Part0 = torso
        weld.Part1 = bluePart
        weld.C0 = CFrame.new(0, 0, -0.1)
        weld.Parent = bluePart
        bluePart.Parent = torso
    end

    print("Игрок " .. self.Player.Name .. " превращён в человека-паука!")
end

function SpiderMan:Cleanup()
    -- Останавливаем полет
    self:StopFlight()

    -- Отключаем все соединения
    for _, connection in pairs(self.Connections) do
        connection:Disconnect()
    end
    self.Connections = {}

    -- Удаляем визуальные эффекты
    if self.WebParticles then
        self.WebParticles:Destroy()
    end
    if self.FlightParticles then
        self.FlightParticles:Destroy()
    end
    if self.SpiderEmblem then
        self.SpiderEmblem:Destroy()
    end

    -- Останавливаем звуки
    if self.FlightSound then
        self.FlightSound:Destroy()
    end
    if self.WebShootSound then
        self.WebShootSound:Destroy()
    end

    print("Spider-Man очищен для игрока: " .. self.Player.Name)
end

-- Глобальная функция для инициализации
function InitializeSpiderMan(player)
    local spiderMan = SpiderMan.new(player)
    spiderMan:Initialize()
    spiderMan:TransformToSpiderMan()

    -- Сохраняем экземпляр для доступа
    player.SpiderManInstance = spiderMan

    -- Подключаем очистку при выходе игрока
    player.AncestryChanged:Connect(function()
        if not player:IsDescendantOf(game.Players) then
            spiderMan:Cleanup()
        end
    end)
end

-- Подключаем к событию появления игроков
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        InitializeSpiderMan(player)
    end)

    if player.Character then
        InitializeSpiderMan(player)
    end
end)

print("Spider-Man скрипт загружен успешно!")

return SpiderMan