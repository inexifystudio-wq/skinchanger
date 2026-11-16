--[[
    Blade Ball - Ayri (standalone) script (v1.1.58)
    Harici UI kutuphanesi gerektirmez; hub'in kendi yerel GUI'si ile calisir.
    Combat (Auto Parry / Auto Spam / Accuracy), Curve & Detections,
    Visual (Unlock Cosmetics / Player & Ability ESP / Headless & Korblox),
    Player (Speed / Jump / Fly), Server (Rejoin / Hop) ve Ayarlar.
    GUI ac/kapat tusu: L (Ayarlar'dan degistirilebilir)
]]

local function safeService(name)
    local svc = game:GetService(name)
    if type(cloneref) == "function" then
        local ok, cloned = pcall(cloneref, svc)
        if ok and cloned then return cloned end
    end
    return svc
end

local Players = safeService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = safeService("RunService")
local UserInputService = safeService("UserInputService")
local Workspace = safeService("Workspace")
local TeleportService = safeService("TeleportService")
local HttpService = safeService("HttpService")
local ReplicatedStorage = safeService("ReplicatedStorage")
local Stats = safeService("Stats")
local TweenService = safeService("TweenService")

local runtimeEnvironment = _G
pcall(function()
    if typeof(getgenv) == "function" then runtimeEnvironment = getgenv() end
end)

local RUNTIME_KEY = "SkinChangerBETA_Standalone_bladeball"
local GUI_NAME = "SkinChanger BETA - Blade Ball"

local previousRuntime = runtimeEnvironment[RUNTIME_KEY]
if type(previousRuntime) == "table" and type(previousRuntime.stop) == "function" then
    pcall(previousRuntime.stop)
end

local runtime = { stopped = false, connections = {}, gui = nil, cleanup = nil, extraCleanups = {} }
runtimeEnvironment[RUNTIME_KEY] = runtime

local function runtimeIsActive()
    return not runtime.stopped and runtimeEnvironment[RUNTIME_KEY] == runtime
end

local function connect(signal, callback)
    local connection = signal:Connect(function(...)
        if runtimeIsActive() then callback(...) end
    end)
    table.insert(runtime.connections, connection)
    return connection
end

runtime.stop = function()
    if runtime.stopped then return end
    runtime.stopped = true
    if runtime.cleanup then pcall(runtime.cleanup) end
    for _, extraCleanup in ipairs(runtime.extraCleanups) do pcall(extraCleanup) end
    table.clear(runtime.extraCleanups)
    for _, connection in ipairs(runtime.connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(runtime.connections)
    if runtime.gui then
        pcall(function() runtime.gui:Destroy() end)
        runtime.gui = nil
    end
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local guiParent = PlayerGui
pcall(function()
    if typeof(gethui) == "function" then
        local hiddenUi = gethui()
        if hiddenUi then guiParent = hiddenUi end
    end
end)

for _, parent in ipairs({ PlayerGui, guiParent }) do
    for _, gui in ipairs(parent:GetChildren()) do
        if gui:IsA("ScreenGui") and (gui.Name == GUI_NAME or gui.Name == GUI_NAME .. " Launcher") then
            gui:Destroy()
        end
    end
end

--------------------------------------------------
-- BLADE BALL VERILERI & AYARLAR
--------------------------------------------------
local BB_Alive = Workspace:FindFirstChild("Alive")
if not BB_Alive then
    task.spawn(function()
        BB_Alive = Workspace:WaitForChild("Alive", 15)
    end)
end
local BB_Runtime = Workspace:FindFirstChild("Runtime")

local BB_Config = {
    MovementMods = false, WalkSpeed = 36, JumpPower = 50,
    Fly = false, FlySpeed = 60,
    PlayerESP = false, PlayerESPNames = true, PlayerESPDistance = true,
    PlayerESPColor = Color3.fromRGB(216, 160, 255),
    AbilityESP = false, AbilityESPColor = Color3.fromRGB(0, 255, 200),
    Headless = false, Korblox = false,
}

local BB_SwordsModule, BB_SwordApi
pcall(function()
    BB_SwordsModule = require(ReplicatedStorage.Shared.ReplicatedInstances.Swords)
    BB_SwordApi = require(ReplicatedStorage.Shared.SwordAPI)
end)

local BB_DataAbilities = ReplicatedStorage:FindFirstChild("Misc") and ReplicatedStorage.Misc:FindFirstChild("DataAbilities")
if not BB_DataAbilities then
    task.spawn(function()
        local ok, misc = pcall(function() return ReplicatedStorage:WaitForChild("Misc", 15) end)
        if ok and misc then
            local ok2, da = pcall(function() return misc:WaitForChild("DataAbilities", 15) end)
            if ok2 then BB_DataAbilities = da end
        end
    end)
end

local BB_AbilityTranslations = {
    ["Sorte"] = "Luck", ["Bola de Ouro"] = "Golden Ball", ["Mártir"] = "Martyrdom",
    ["Maldição"] = "Misfortune", ["Ceifador"] = "Reaper", ["Tato"] = "Tact",
    ["Escopofobia"] = "Scopophobia", ["Recompensa"] = "Bounty", ["Carga Qi"] = "Qi-Charge",
    ["Anjo da Guarda"] = "Guardian Angel", ["Vírus"] = "Virus", ["Salto Quádruplo"] = "Quad Jump",
    ["Deflexão Calma"] = "Calming Deflection", ["Deflexão Furiosa"] = "Raging Deflection",
    ["Arrebatamento"] = "Rapture", ["Corte Aerodinâmico"] = "Aerodynamic Slash",
    ["Campo de Força"] = "Forcefield", ["Infinito"] = "Infinity", ["Fratura"] = "Fracture",
    ["Corte da Morte"] = "Death Slash", ["Cortes da Fúria"] = "Slashes of Fury",
    ["Fantasma"] = "Phantom", ["Necromante"] = "Necromancer", ["Arena Quântica"] = "Quantum Arena",
    ["Espírito do Dragão"] = "Dragon Spirit", ["Drible"] = "Dribble", ["Combo"] = "Combo",
    ["Ganância"] = "Greed", ["Troca"] = "Swap", ["Escudo"] = "Shield",
    ["Singularidade"] = "Singularity", ["Queda"] = "Fall", ["Laser"] = "Laser",
    ["Puxão"] = "Pull", ["Empurrão"] = "Push", ["Teletransporte"] = "Teleport",
    ["Corrida Ninja"] = "Ninja Run", ["Congelar"] = "Freeze", ["Kamikaze"] = "Kamikaze",
    ["Bola de Fogo"] = "Fireball", ["Meteoro"] = "Meteor", ["Arremesso"] = "Throw",
    ["Salto"] = "Jump", ["Buraco Negro"] = "Black Hole", ["Tempestade"] = "Storm",
    ["Raio"] = "Lightning", ["Gelo"] = "Ice", ["Fogo"] = "Fire", ["Água"] = "Water",
    ["Vento"] = "Wind", ["Terra"] = "Earth", ["Luz"] = "Light", ["Trevas"] = "Darkness",
    ["Tempo"] = "Time", ["Espaço"] = "Space", ["Realidade"] = "Reality",
    ["Mente"] = "Mind", ["Alma"] = "Soul", ["Poder"] = "Power",
    ["Força"] = "Strength", ["Velocidade"] = "Speed", ["Voo"] = "Flight",
    ["Invisibilidade"] = "Invisibility", ["Cura"] = "Heal", ["Ressurreição"] = "Resurrection",
    ["Imortalidade"] = "Immortality",
}

local BB_TokenFound = false
local VirtualInputManager = nil
pcall(function() VirtualInputManager = safeService("VirtualInputManager") end)

local BB_CurveNames = { "Camera", "Random", "Accelerated", "Backwards", "Slow", "High", "Normal", "Speed", "Down", "Left", "Right" }
local BB_LegitCurveNames = { "Right", "Left", "Backwards", "Normal" }
local BB_SelectedCurve = "Camera"

local function BB_GetCurveCFrame()
    local cam = Workspace.CurrentCamera
    if not cam then return CFrame.new() end
    local char = LocalPlayer.Character
    local root = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
    local rootPos = root and root.Position or cam.CFrame.Position
    local targetPart = nil
    local bestDist = math.huge
    local mouseLoc = UserInputService:GetMouseLocation()
    if BB_Alive then
        for _, v in ipairs(BB_Alive:GetChildren()) do
            if v ~= char and v.PrimaryPart then
                local screenPos, onScreen = cam:WorldToScreenPoint(v.PrimaryPart.Position)
                if onScreen then
                    local d = (Vector2.new(screenPos.X, screenPos.Y) - mouseLoc).Magnitude
                    if d < bestDist then
                        bestDist = d
                        targetPart = v.PrimaryPart
                    end
                end
            end
        end
    end
    local targetPos = targetPart and targetPart.Position or (rootPos + cam.CFrame.LookVector * 100)
    local t = BB_SelectedCurve
    if t == "Camera" then return cam.CFrame
    elseif t == "Random" then
        local offset = Vector3.new(math.random(-120, 120), math.random(-40, 80), math.random(-120, 120))
        local lookAtPos = targetPos + offset
        if (lookAtPos - rootPos).Magnitude < 1 then lookAtPos = rootPos + cam.CFrame.LookVector * 100 end
        return CFrame.lookAt(cam.CFrame.Position, lookAtPos)
    elseif t == "Accelerated" then
        return CFrame.lookAt(cam.CFrame.Position, targetPos + Vector3.new(0, 5, 0))
    elseif t == "Backwards" then
        local diff = rootPos - targetPos
        local dir = diff.Magnitude > 0.01 and diff.Unit or -cam.CFrame.LookVector
        return CFrame.lookAt(cam.CFrame.Position, cam.CFrame.Position + dir * 150 + Vector3.new(0, 35, 0))
    elseif t == "Slow" then
        return CFrame.lookAt(cam.CFrame.Position, cam.CFrame.Position + cam.CFrame.LookVector * 100 + Vector3.new(0, -180, 0))
    elseif t == "High" then
        return CFrame.lookAt(cam.CFrame.Position, cam.CFrame.Position + cam.CFrame.LookVector * 100 + Vector3.new(0, 220, 0))
    elseif t == "Normal" then
        local lookDir = root and root.CFrame.LookVector or cam.CFrame.LookVector
        return CFrame.lookAt(cam.CFrame.Position, cam.CFrame.Position + lookDir * 100)
    elseif t == "Speed" then
        return CFrame.lookAt(cam.CFrame.Position, cam.CFrame.Position + cam.CFrame.LookVector * 100 + cam.CFrame.UpVector * 25)
    elseif t == "Down" then
        return CFrame.lookAt(cam.CFrame.Position, cam.CFrame.Position - cam.CFrame.UpVector * 150)
    elseif t == "Left" then
        return CFrame.lookAt(cam.CFrame.Position, cam.CFrame.Position - cam.CFrame.RightVector * 150)
    elseif t == "Right" then
        return CFrame.lookAt(cam.CFrame.Position, cam.CFrame.Position + cam.CFrame.RightVector * 150)
    end
    return cam.CFrame
end

local function BB_FireParryRemote(_curveCF)
    return false
end

local function BB_TriggerBlockFallback()
    local fired = false
    if VirtualInputManager then
        fired = pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
            task.delay(0.02, function()
                pcall(function() VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game) end)
            end)
        end)
    end
    if not fired and type(keypress) == "function" then
        fired = pcall(function()
            keypress(0x46)
            task.delay(0.02, function()
                if type(keyrelease) == "function" then pcall(keyrelease, 0x46) end
            end)
        end)
    end
    if not fired and type(getconnections) == "function" then
        pcall(function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            local hotbar = pg and pg:FindFirstChild("Hotbar")
            local blockButton = hotbar and hotbar:FindFirstChild("Block")
            if blockButton then
                for _, sig in ipairs({ blockButton.Activated, blockButton.MouseButton1Click, blockButton.MouseButton1Down }) do
                    for _, conn in pairs(getconnections(sig)) do
                        pcall(function() conn:Fire() end)
                    end
                end
            end
        end)
    end
end

local BB_System = {
    __properties = {
        __autoparry_enabled = true,
        __auto_spam_enabled = true,
        __play_animation = true,
        __accuracy = 50,
        __divisor_multiplier = 1.1,
        __parried = false,
        __spam_threshold = 1.5,
        __parries = 0,
        __grab_animation = nil,
        __tornado_time = tick(),
        __connections = {},
        __randomized_accuracy_enabled = false,
        __infinity_active = false,
        __deathslash_active = false,
        __timehole_active = false,
        __slashesoffury_active = false,
        __parry_mode = "Keypress",
    },
    __config = {
        __detections = { __infinity = false, __deathslash = false, __timehole = false, __slashesoffury = false },
    },
}

local function BB_UpdateDivisor()
    BB_System.__properties.__divisor_multiplier = 0.7 + (BB_System.__properties.__accuracy - 1) * (0.9 / 99)
end

local function BB_UpdateRandomizedAccuracy()
    if not BB_System.__properties.__randomized_accuracy_enabled then return end
    local ok, pingStr = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
    end)
    local ping = ok and (tonumber(string.match(pingStr, "%d+")) or 0) or 0
    local newAccuracy
    if ping >= 90 then newAccuracy = 4
    elseif ping <= 50 then newAccuracy = math.random(70, 100)
    else newAccuracy = BB_System.__properties.__accuracy end
    if newAccuracy then
        BB_System.__properties.__accuracy = newAccuracy
        BB_UpdateDivisor()
    end
end

task.spawn(function()
    while runtimeIsActive() do
        task.wait(1)
        if runtimeIsActive() and BB_System.__properties.__randomized_accuracy_enabled then
            BB_UpdateRandomizedAccuracy()
        end
    end
end)

local BB_LastPlayed = 0
local BB_SwordCP = false
local BB_AnimCache = {}

local function BB_GetParryAnimation(swordName)
    if not BB_SwordApi then return nil end
    if not swordName or swordName == "" then
        return BB_SwordApi.Collection.Default:FindFirstChild("GrabParry")
    end
    if BB_AnimCache[swordName] then return BB_AnimCache[swordName] end
    local ok, swordData = pcall(function()
        return ReplicatedStorage.Shared.ReplicatedInstances.Swords.GetSword:Invoke(swordName)
    end)
    if not ok or not swordData or type(swordData) ~= "table" or not swordData.AnimationType then
        BB_AnimCache[swordName] = BB_SwordApi.Collection.Default:FindFirstChild("GrabParry")
        return BB_AnimCache[swordName]
    end
    for _, obj in pairs(BB_SwordApi.Collection:GetChildren()) do
        if obj.Name == swordData.AnimationType then
            local anim = obj:FindFirstChild("GrabParry") or obj:FindFirstChild("Grab")
            if anim then
                BB_AnimCache[swordName] = anim
                return anim
            end
        end
    end
    BB_AnimCache[swordName] = BB_SwordApi.Collection.Default:FindFirstChild("GrabParry")
    return BB_AnimCache[swordName]
end

local function BB_PlayGrabParry()
    if not BB_System.__properties.__play_animation then return end
    if not ((os.clock() - BB_LastPlayed) >= 0.2 or BB_SwordCP) then return end
    BB_LastPlayed = os.clock()
    BB_SwordCP = false
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or not humanoid:FindFirstChild("Animator") then return end
    local currentSword = char:GetAttribute("CurrentlyEquippedSword")
    local animation = BB_GetParryAnimation(currentSword)
    if not animation then return end
    for _, track in pairs(humanoid.Animator:GetPlayingAnimationTracks()) do
        if track.Name == "GrabParry" or track.Name == "Grab" then
            track.TimePosition = 0
            pcall(function() track:Stop(0.1) end)
        elseif track.Name == "SuccessParry" or track.Name == "Success" then
            pcall(function() track:Stop(0.1) end)
        end
    end
    BB_System.__properties.__grab_animation = humanoid.Animator:LoadAnimation(animation)
    pcall(function() BB_System.__properties.__grab_animation:Play(0, 1, 1) end)
end

pcall(function()
    connect(ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent, function()
        BB_SwordCP = true
        local char = LocalPlayer.Character
        if not char then return end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        for _, track in pairs(humanoid.Animator:GetPlayingAnimationTracks()) do
            if track.Name == "GrabParry" or track.Name == "Grab" then
                pcall(function() track:Stop(0.1) end)
            end
        end
    end)
end)

local BB_Ball = {}
function BB_Ball.get()
    local balls = Workspace:FindFirstChild("Balls")
    if not balls then return nil end
    for _, ball in pairs(balls:GetChildren()) do
        if ball:GetAttribute("realBall") then
            return ball
        end
    end
    return nil
end

function BB_Ball.get_all()
    local t = {}
    local balls = Workspace:FindFirstChild("Balls")
    if not balls then return t end
    for _, ball in pairs(balls:GetChildren()) do
        if ball:GetAttribute("realBall") then
            table.insert(t, ball)
        end
    end
    return t
end

local BB_ClosestEntity = nil
local BB_LastClosestCheck = 0
local function BB_GetClosest()
    local now = tick()
    if now - BB_LastClosestCheck < 0.1 then return BB_ClosestEntity end
    BB_LastClosestCheck = now
    local maxDist = math.huge
    local closest = nil
    if not BB_Alive then return nil end
    for _, entity in pairs(BB_Alive:GetChildren()) do
        if entity ~= LocalPlayer.Character and entity.PrimaryPart then
            local d = LocalPlayer:DistanceFromCharacter(entity.PrimaryPart.Position)
            if d < maxDist then
                maxDist = d
                closest = entity
            end
        end
    end
    BB_ClosestEntity = closest
    return closest
end

local BB_Parry = {}
function BB_Parry.execute()
    if BB_System.__properties.__parries > 10000 or not LocalPlayer.Character then return end
    local ok = false
    if BB_System.__properties.__parry_mode == "Remote" then
        ok = BB_FireParryRemote(BB_GetCurveCFrame())
    end
    if not ok then
        BB_TriggerBlockFallback()
    end
    BB_System.__properties.__parries = BB_System.__properties.__parries + 1
    task.delay(0.5, function()
        if BB_System.__properties.__parries > 0 then
            BB_System.__properties.__parries = BB_System.__properties.__parries - 1
        end
    end)
end

function BB_Parry.execute_action()
    if BB_System.__properties.__parry_mode ~= "Keypress" then
        BB_PlayGrabParry()
    end
    BB_Parry.execute()
end

local function BB_LinearPredict(a, b, t) return a + (b - a) * t end

local BB_Detection = {
    __ball_properties = { __last_warping = tick(), __lerp_radians = 0, __curving = tick() },
}

function BB_Detection.is_curved()
    local props = BB_Detection.__ball_properties
    local ball = BB_Ball.get()
    if not ball then return false end
    local zoomies = ball:FindFirstChild("zoomies")
    if not zoomies then return false end
    local velocity = zoomies.VectorVelocity
    local speed = velocity.Magnitude
    if speed < 1 then return false end
    local ballDir = velocity.Unit
    local char = LocalPlayer.Character
    if not char or not char.PrimaryPart then return false end
    local pos = char.PrimaryPart.Position
    local direction = (pos - ball.Position).Unit
    local dot = direction:Dot(ballDir)
    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    local distance = (pos - ball.Position).Magnitude
    local reachTime = distance / speed - ping
    local dotThreshold = math.clamp(0.55 - (ping * 0.75), -1, 0.45)
    local speedThreshold = math.min(speed / 100, 45)
    local ballDistThreshold = 15 - math.min(distance / 1000, 15) + speedThreshold
    local clampedDot = math.clamp(dot, -1, 1)
    local radians = math.asin(clampedDot)
    props.__lerp_radians = BB_LinearPredict(props.__lerp_radians, radians, 0.85)
    if props.__lerp_radians < 0.016 then props.__last_warping = tick() end
    if distance < (ballDistThreshold * 0.85) then return false end
    if (tick() - props.__last_warping) < (reachTime / 1.4) then return true end
    if (tick() - props.__curving) < (reachTime / 1.1) then return true end
    return dot < dotThreshold
end

pcall(function()
    connect(ReplicatedStorage.Remotes.DeathBall.OnClientEvent, function(_, d)
        BB_System.__properties.__deathslash_active = d or false
    end)
    connect(ReplicatedStorage.Remotes.InfinityBall.OnClientEvent, function(_, b)
        BB_System.__properties.__infinity_active = b or false
    end)
    local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net
    connect(net["RE/TimeHoleActivate"].OnClientEvent, function(p)
        if p == LocalPlayer or p == LocalPlayer.Name or (p and p.Name == LocalPlayer.Name) then
            BB_System.__properties.__timehole_active = true
        end
    end)
    connect(net["RE/TimeHoleDeactivate"].OnClientEvent, function()
        BB_System.__properties.__timehole_active = false
    end)
    connect(net["RE/SlashesOfFuryActivate"].OnClientEvent, function(p)
        if p == LocalPlayer or p == LocalPlayer.Name or (p and p.Name == LocalPlayer.Name) then
            BB_System.__properties.__slashesoffury_active = true
        end
    end)
    connect(net["RE/SlashesOfFuryEnd"].OnClientEvent, function()
        BB_System.__properties.__slashesoffury_active = false
    end)
end)

local BB_AutoParry = {}
function BB_AutoParry.start()
    if BB_System.__properties.__connections.__autoparry then
        BB_System.__properties.__connections.__autoparry:Disconnect()
    end
    BB_System.__properties.__connections.__autoparry = connect(RunService.PreSimulation, function()
        if not BB_System.__properties.__autoparry_enabled or not LocalPlayer.Character or
           not LocalPlayer.Character.PrimaryPart then return end
        local balls = BB_Ball.get_all()
        local one_ball = BB_Ball.get()
        for _, ball in pairs(balls) do
            local zoomies = ball and ball:FindFirstChild("zoomies")
            if zoomies then
                ball:GetAttributeChangedSignal("target"):Once(function()
                    BB_System.__properties.__parried = false
                end)
                if not BB_System.__properties.__parried then
                    local ballTarget = ball:GetAttribute("target")
                    local velocity = zoomies.VectorVelocity
                    local distance = (LocalPlayer.Character.PrimaryPart.Position - ball.Position).Magnitude
                    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 10
                    local pingThreshold = math.clamp(ping / 10, 5, 17)
                    local speed = velocity.Magnitude
                    local cappedSpeedDiff = math.min(math.max(speed - 9.5, 0), 650)
                    local speedDivisor = (2.4 + cappedSpeedDiff * 0.002) * BB_System.__properties.__divisor_multiplier
                    local parryAccuracy = pingThreshold + math.max(speed / speedDivisor, 9.5)
                    local curved = BB_Detection.is_curved()
                    if ball:FindFirstChild("AeroDynamicSlashVFX") then
                        BB_System.__properties.__tornado_time = tick()
                    end
                    local skip = false
                    if BB_Runtime and BB_Runtime:FindFirstChild("Tornado") then
                        if (tick() - BB_System.__properties.__tornado_time) <
                           (BB_Runtime.Tornado:GetAttribute("TornadoTime") or 1) + 0.314159 then
                            skip = true
                        end
                    end
                    if not skip and one_ball and one_ball:GetAttribute("target") == LocalPlayer.Name and curved then skip = true end
                    if not skip and ball:FindFirstChild("ComboCounter") then skip = true end
                    if not skip and LocalPlayer.Character.PrimaryPart:FindFirstChild("SingularityCape") then skip = true end
                    if not skip and BB_System.__config.__detections.__infinity and BB_System.__properties.__infinity_active then skip = true end
                    if not skip and BB_System.__config.__detections.__deathslash and BB_System.__properties.__deathslash_active then skip = true end
                    if not skip and BB_System.__config.__detections.__timehole and BB_System.__properties.__timehole_active then skip = true end
                    if not skip and BB_System.__config.__detections.__slashesoffury and BB_System.__properties.__slashesoffury_active then skip = true end
                    if not skip and ballTarget == LocalPlayer.Name and distance <= parryAccuracy then
                        BB_Parry.execute_action()
                        BB_System.__properties.__parried = true
                    end
                end
            end
        end
    end)
end

function BB_AutoParry.stop()
    if BB_System.__properties.__connections.__autoparry then
        BB_System.__properties.__connections.__autoparry:Disconnect()
        BB_System.__properties.__connections.__autoparry = nil
    end
end

local BB_AutoSpam = {}
local function BB_GetEntityProperties()
    BB_GetClosest()
    if not BB_ClosestEntity or not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart or not BB_ClosestEntity.PrimaryPart then return false end
    return {
        Velocity = BB_ClosestEntity.PrimaryPart.AssemblyLinearVelocity,
        Direction = (LocalPlayer.Character.PrimaryPart.Position - BB_ClosestEntity.PrimaryPart.Position).Unit,
        Distance = (LocalPlayer.Character.PrimaryPart.Position - BB_ClosestEntity.PrimaryPart.Position).Magnitude,
    }
end

local function BB_GetBallProperties()
    local ball = BB_Ball.get()
    if not ball or not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return false end
    local ballVelocity = ball.AssemblyLinearVelocity
    local ballDirection = (LocalPlayer.Character.PrimaryPart.Position - ball.Position).Unit
    return {
        Velocity = ballVelocity,
        Direction = ballDirection,
        Distance = (LocalPlayer.Character.PrimaryPart.Position - ball.Position).Magnitude,
        Dot = ballVelocity.Magnitude > 0 and ballDirection:Dot(ballVelocity.Unit) or 0,
    }
end

local function BB_SpamService(self)
    local ball = BB_Ball.get()
    local entity = BB_GetClosest()
    if not ball or not entity or not entity.PrimaryPart or not LocalPlayer.Character or not LocalPlayer.Character.PrimaryPart then return 0 end
    local velocity = ball.AssemblyLinearVelocity
    local speed = velocity.Magnitude
    local direction = (LocalPlayer.Character.PrimaryPart.Position - ball.Position).Unit
    local dot = speed > 0 and direction:Dot(velocity.Unit) or 0
    local targetDistance = LocalPlayer:DistanceFromCharacter(entity.PrimaryPart.Position)
    local maximumSpamDistance = self.Ping + math.min(speed / 6, 255)
    if self.Entity_Properties.Distance > maximumSpamDistance or self.Ball_Properties.Distance > maximumSpamDistance or targetDistance > maximumSpamDistance then
        return 0
    end
    local maximumSpeed = 5 - math.min(speed / 5, 5)
    local maximumDot = math.clamp(dot, -1, 0) * maximumSpeed
    return maximumSpamDistance - maximumDot
end

function BB_AutoSpam.start()
    if BB_System.__properties.__connections.__auto_spam then
        BB_System.__properties.__connections.__auto_spam:Disconnect()
    end
    BB_System.__properties.__auto_spam_enabled = true
    BB_System.__properties.__connections.__auto_spam = connect(RunService.PreSimulation, function()
        if not BB_System.__properties.__auto_spam_enabled then return end
        local ball = BB_Ball.get()
        if not ball or BB_System.__properties.__slashesoffury_active then return end
        if not ball:FindFirstChild("zoomies") then return end
        BB_GetClosest()
        local ballProps = BB_GetBallProperties()
        local entityProps = BB_GetEntityProperties()
        if not ballProps or not entityProps or not BB_ClosestEntity or not BB_ClosestEntity.PrimaryPart then return end
        local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        local pingThreshold = math.clamp(ping / 10, 1, 16)
        local spamAccuracy = BB_SpamService({ Ball_Properties = ballProps, Entity_Properties = entityProps, Ping = pingThreshold })
        local targetDistance = LocalPlayer:DistanceFromCharacter(BB_ClosestEntity.PrimaryPart.Position)
        local distance = LocalPlayer:DistanceFromCharacter(ball.Position)
        local ballTarget = ball:GetAttribute("target")
        if not ballTarget or targetDistance > spamAccuracy or distance > spamAccuracy then return end
        if LocalPlayer.Character:GetAttribute("Pulsed") then return end
        if ballTarget == LocalPlayer.Name and targetDistance > 30 and distance > 30 then return end
        if distance <= spamAccuracy and BB_System.__properties.__parries > BB_System.__properties.__spam_threshold then
            BB_Parry.execute()
        end
    end)
end

function BB_AutoSpam.stop()
    BB_System.__properties.__auto_spam_enabled = false
    if BB_System.__properties.__connections.__auto_spam then
        BB_System.__properties.__connections.__auto_spam:Disconnect()
        BB_System.__properties.__connections.__auto_spam = nil
    end
end

--------------------------------------------------
-- COSMETICS (SWORD & EXPLOSION UNLOCK)
--------------------------------------------------
local BB_SkinsHooked = false
local BB_OriginalFindItems = nil
local BB_SwordsController = nil
local BB_EquippedSwordName = nil
local BB_LastExplosion = ""
local BB_Str10 = ""
local BB_ExplosionController = nil

local function BB_FindExplosionController()
    local controllers = ReplicatedStorage:FindFirstChild("Controllers")
    local mod = controllers and controllers:FindFirstChild("VFXController")
    if mod and not mod:IsA("ModuleScript") then
        mod = mod:FindFirstChild("VFXController")
    end
    if not mod then
        for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
            if d.Name == "VFXController" and d:IsA("ModuleScript") then
                mod = d
                break
            end
        end
    end
    if not mod then return nil end
    local ok, res = pcall(require, mod)
    if ok and type(res) == "table" and type(res.PlayExplosion) == "function" then
        return res
    end
    return nil
end

local function BB_GetSetSword()
    if BB_SwordsController then return BB_SwordsController end
    if type(getconnections) ~= "function" then return nil end
    pcall(function()
        for _, connection in pairs(getconnections(ReplicatedStorage.Remotes.ParrySuccess.OnClientEvent)) do
            local values = connection.Function and (getupvalues or debug.getupvalues)(connection.Function)
            if type(values) == "table" then
                for _, value in pairs(values) do
                    if type(value) == "table" and type(rawget(value, "SetSword")) == "function" then
                        BB_SwordsController = value
                        return
                    end
                end
            end
        end
    end)
    return BB_SwordsController
end

local function BB_SetEquippedSword(swordName)
    BB_EquippedSwordName = swordName
    pcall(function() LocalPlayer:SetAttribute("CurrentlyEquippedSword", swordName) end)
    if BB_SwordsModule then pcall(function() BB_SwordsModule:EquipSwordTo(LocalPlayer.Character, swordName) end) end
    local controller = BB_GetSetSword()
    if controller then pcall(function() controller:SetSword(swordName) end) end
end

local function BB_SetEquippedExplosion(explosionName)
    BB_LastExplosion = explosionName
    BB_Str10 = explosionName
    pcall(function() LocalPlayer:SetAttribute("CurrentlyEquippedExplosion", explosionName) end)
end

local function BB_BindCharacterCosmeticFixer(character)
    if BB_SkinsHooked and type(getconnections) == "function" then
        pcall(function()
            for _, conn in pairs(getconnections(character:GetAttributeChangedSignal("CurrentlyEquippedSword"))) do
                pcall(function() conn:Disable() end)
            end
        end)
    end
    connect(character:GetAttributeChangedSignal("CurrentlyEquippedSword"), function()
        if not BB_SkinsHooked or not BB_EquippedSwordName then return end
        local attr = character:GetAttribute("CurrentlyEquippedSword")
        if attr ~= BB_EquippedSwordName then
            pcall(function() character:SetAttribute("CurrentlyEquippedSword", BB_EquippedSwordName) end)
            if BB_SwordsModule then pcall(function() BB_SwordsModule:EquipSwordTo(character, BB_EquippedSwordName) end) end
            local controller = BB_GetSetSword()
            if controller then pcall(function() controller:SetSword(BB_EquippedSwordName) end) end
        end
    end)
    if BB_EquippedSwordName and BB_SkinsHooked then
        task.wait(0.5)
        if runtimeIsActive() then
            BB_SetEquippedSword(BB_EquippedSwordName)
        end
    end
end

connect(LocalPlayer.CharacterAdded, BB_BindCharacterCosmeticFixer)
if LocalPlayer.Character then BB_BindCharacterCosmeticFixer(LocalPlayer.Character) end

local function BB_HookBuyButton()
    local shop = LocalPlayer.PlayerGui:FindFirstChild("Shop")
    local holder = shop and shop:FindFirstChild("Holder")
    local infoBG = holder and holder:FindFirstChild("InfoBG")
    local buyButton = infoBG and infoBG:FindFirstChild("BuyButton")
    if not buyButton then return end
    if buyButton:GetAttribute("BB_Hooked") then return end
    buyButton:SetAttribute("BB_Hooked", true)
    connect(buyButton.Activated, function()
        local ok, ShopController = pcall(require, ReplicatedStorage.Controllers.UI.ShopController)
        if not ok or not ShopController or not ShopController._selectedItem then return end
        local item = ShopController._selectedItem
        if item.type == "Sword" then
            BB_SetEquippedSword(item.name)
            pcall(function() buyButton.PriceTag.TextLabel.Text = "Equipped" end)
        elseif item.type == "Explosion" then
            BB_SetEquippedExplosion(item.name)
            pcall(function() buyButton.PriceTag.TextLabel.Text = "Equipped" end)
        end
    end)
end

local function BB_UnlockAllCosmetics(on)
    if on and not BB_SkinsHooked then
        BB_SkinsHooked = true
        BB_Str10 = BB_LastExplosion
        if not BB_ExplosionController then BB_ExplosionController = BB_FindExplosionController() end
        if BB_ExplosionController and type(BB_ExplosionController.PlayExplosion) == "function" and not BB_ExplosionController.__bb_explosion_hooked then
            BB_ExplosionController.__bb_explosion_hooked = true
            local origPlay = BB_ExplosionController.PlayExplosion
            BB_ExplosionController.PlayExplosion = function(arg, arg2, arg3, arg4, arg5, arg6, arg7)
                if runtimeIsActive() and BB_Str10 ~= "" and arg7 and arg6 == LocalPlayer.Character then
                    arg2 = BB_Str10
                end
                return origPlay(arg, arg2, arg3, arg4, arg5, arg6, arg7)
            end
        end
        pcall(function()
            local Shared = require(ReplicatedStorage.Shared.Inventory.Shared)
            if type(hookfunction) == "function" and not BB_OriginalFindItems then
                BB_OriginalFindItems = hookfunction(Shared.FindItems, function(arg, arg2, arg3, arg4, arg5)
                    local ok, result = pcall(BB_OriginalFindItems, arg, arg2, arg3, arg4, arg5)
                    if string.find(tostring(arg3), "Abilit", 1, true) then
                        return ok and result or {}
                    end
                    if ok and type(result) == "table" and #result > 0 then return result end
                    if arg4 ~= nil then return { arg4 } end
                    return {}
                end)
            end
            local ok2, ShopController = pcall(require, ReplicatedStorage.Controllers.UI.ShopController)
            if ok2 and ShopController and ShopController._virtualItems then
                for _, items in pairs(ShopController._virtualItems) do
                    if type(items) == "table" then
                        for _, shopItem in pairs(items) do
                            if shopItem and shopItem.OwnsItem and (shopItem.type == "Sword" or shopItem.type == "Explosion") then
                                pcall(function()
                                    shopItem.OwnsItem:Set(true)
                                    shopItem.Section = "Owned"
                                    shopItem.ForceHide = false
                                end)
                            end
                        end
                    end
                end
            end
        end)
        BB_HookBuyButton()
    elseif not on and BB_SkinsHooked then
        BB_SkinsHooked = false
        if BB_OriginalFindItems and type(hookfunction) == "function" then
            pcall(function()
                local Shared = require(ReplicatedStorage.Shared.Inventory.Shared)
                hookfunction(Shared.FindItems, BB_OriginalFindItems)
                BB_OriginalFindItems = nil
            end)
        end
    end
end

--------------------------------------------------
-- ESP & MOVEMENT
--------------------------------------------------
local BB_CombinedBillboards = setmetatable({}, { __mode = "k" })

local function BB_GetAbilityInfo(plr, character)
    local rawName = plr:GetAttribute("EquippedAbility") or character:GetAttribute("EquippedAbility") or character:GetAttribute("CurrentlyEquippedAbility")
    if not rawName or rawName == "" then return nil, nil end
    local displayName = BB_AbilityTranslations[rawName]
    local icon = nil
    if BB_DataAbilities then
        local data = BB_DataAbilities:FindFirstChild(rawName) or (displayName and BB_DataAbilities:FindFirstChild(displayName))
        if data then
            displayName = displayName or data:GetAttribute("Name") or data.Name
            icon = data:GetAttribute("Icon") or data:GetAttribute("Image") or data:GetAttribute("IconId")
            if icon and type(icon) == "string" and string.match(icon, "^%d+$") then
                icon = "rbxassetid://" .. icon
            end
        end
    end
    return displayName or rawName, icon
end

local function BB_ClearAllESP()
    for _, bb in pairs(BB_CombinedBillboards) do
        if bb and bb.Parent then pcall(function() bb:Destroy() end) end
    end
    BB_CombinedBillboards = setmetatable({}, { __mode = "k" })
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hl = plr.Character:FindFirstChild("BB_PlayerHL")
            if hl then hl:Destroy() end
        end
    end
end

local function BB_RenderCombinedESP()
    local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
            local hl = char and char:FindFirstChild("BB_PlayerHL")
            if BB_Config.PlayerESP and char then
                if not hl then
                    hl = Instance.new("Highlight")
                    hl.Name = "BB_PlayerHL"
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.FillTransparency = 0.5
                    hl.OutlineTransparency = 0
                    hl.Parent = char
                end
                hl.OutlineColor = BB_Config.PlayerESPColor
                hl.FillColor = BB_Config.PlayerESPColor
            elseif hl then
                hl:Destroy()
            end

            local displayName, icon = nil, nil
            if BB_Config.AbilityESP and char then
                displayName, icon = BB_GetAbilityInfo(plr, char)
            end
            local abilityActive = (BB_Config.AbilityESP and displayName and displayName ~= "") and true or false
            local nameActive = (BB_Config.PlayerESP and BB_Config.PlayerESPNames) and true or false
            local distActive = (BB_Config.PlayerESP and BB_Config.PlayerESPDistance) and true or false

            if head and (abilityActive or nameActive or distActive) then
                local bb = BB_CombinedBillboards[plr]
                if not bb or not bb.Parent or bb.Adornee ~= head then
                    if bb then pcall(function() bb:Destroy() end) end
                    bb = Instance.new("BillboardGui")
                    bb.Name = "BB_CombinedBillboard"
                    bb.Size = UDim2.new(0, 200, 0, 80)
                    bb.StudsOffset = Vector3.new(0, 2.6, 0)
                    bb.AlwaysOnTop = true
                    bb.Adornee = head
                    bb.Parent = char
                    local lbl = Instance.new("TextLabel")
                    lbl.Name = "Info"
                    lbl.Size = UDim2.fromScale(1, 1)
                    lbl.BackgroundTransparency = 1
                    lbl.Font = Enum.Font.GothamBold
                    lbl.TextSize = 13
                    lbl.TextStrokeTransparency = 0
                    lbl.Parent = bb
                    BB_CombinedBillboards[plr] = bb
                end
                local lbl = bb:FindFirstChild("Info")
                if lbl then
                    local parts = {}
                    if abilityActive then table.insert(parts, "[" .. displayName .. "]") end
                    if nameActive then table.insert(parts, plr.DisplayName) end
                    if distActive then
                        local dist = localRoot and math.floor((localRoot.Position - head.Position).Magnitude) or 0
                        table.insert(parts, dist .. "m")
                    end
                    lbl.Text = table.concat(parts, "\n")
                    lbl.TextColor3 = abilityActive and BB_Config.AbilityESPColor or BB_Config.PlayerESPColor
                end
            elseif BB_CombinedBillboards[plr] then
                pcall(function() BB_CombinedBillboards[plr]:Destroy() end)
                BB_CombinedBillboards[plr] = nil
            end
        end
    end
end

local BB_DefaultWS = 36
local BB_DefaultJP = 50
local BB_FlyBV, BB_FlyBG, BB_FlyConn

local function BB_GetHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function BB_GetHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function BB_ToggleFly(on)
    BB_Config.Fly = on
    local hrp = BB_GetHRP()
    local hum = BB_GetHum()
    if BB_FlyConn then BB_FlyConn:Disconnect() BB_FlyConn = nil end
    if BB_FlyBV then pcall(function() BB_FlyBV:Destroy() end) BB_FlyBV = nil end
    if BB_FlyBG then pcall(function() BB_FlyBG:Destroy() end) BB_FlyBG = nil end
    if on then
        if not hrp or not hum then return end
        hum.PlatformStand = true
        BB_FlyBV = Instance.new("BodyVelocity")
        BB_FlyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        BB_FlyBV.Parent = hrp
        BB_FlyBG = Instance.new("BodyGyro")
        BB_FlyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        BB_FlyBG.P = 1e4
        BB_FlyBG.Parent = hrp
        BB_FlyConn = connect(RunService.Heartbeat, function()
            if not BB_Config.Fly or not BB_FlyBV or not BB_FlyBV.Parent then return end
            local move = Vector3.zero
            local cam = Workspace.CurrentCamera
            if not cam then return end
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.yAxis end
            BB_FlyBV.Velocity = move.Magnitude > 0 and move.Unit * BB_Config.FlySpeed or Vector3.zero
            BB_FlyBG.CFrame = cam.CFrame
        end)
    elseif hum then
        hum.PlatformStand = false
    end
end

local BB_LastESPUpdate = 0
local BB_LastVisualUpdate = 0
connect(RunService.Heartbeat, function()
    local hum = BB_GetHum()
    if hum and BB_Config.MovementMods then
        hum.WalkSpeed = BB_Config.WalkSpeed
        hum.JumpPower = BB_Config.JumpPower
        hum.UseJumpPower = true
    end

    local now = os.clock()
    if now - BB_LastESPUpdate >= 0.1 then
        BB_LastESPUpdate = now
        if BB_Config.PlayerESP or BB_Config.AbilityESP then
            pcall(BB_RenderCombinedESP)
        elseif next(BB_CombinedBillboards) ~= nil then
            BB_ClearAllESP()
        end
    end

    if now - BB_LastVisualUpdate >= 0.5 then
        BB_LastVisualUpdate = now
        local char = LocalPlayer.Character
        if char then
            local head = char:FindFirstChild("Head")
            if head then
                local mesh = head:FindFirstChild("BB_HeadlessMesh")
                if BB_Config.Headless then
                    head.Transparency = 1
                    local face = head:FindFirstChild("face")
                    if face then face:Destroy() end
                    if not mesh then
                        mesh = Instance.new("SpecialMesh")
                        mesh.Name = "BB_HeadlessMesh"
                        mesh.MeshType = Enum.MeshType.FileMesh
                        mesh.MeshId = "rbxassetid://1095708"
                        mesh.Scale = Vector3.new(0.001, 0.001, 0.001)
                        mesh.Parent = head
                    end
                elseif mesh then
                    head.Transparency = 0
                    mesh:Destroy()
                end
            end
            local rightLeg = char:FindFirstChild("Right Leg") or char:FindFirstChild("RightUpperLeg")
            if rightLeg then
                local mesh = rightLeg:FindFirstChild("BB_KorbloxMesh")
                if BB_Config.Korblox then
                    rightLeg.Color = Color3.fromRGB(64, 64, 64)
                    if not mesh then
                        mesh = Instance.new("SpecialMesh")
                        mesh.Name = "BB_KorbloxMesh"
                        mesh.MeshType = Enum.MeshType.FileMesh
                        mesh.MeshId = "rbxassetid://101851696"
                        mesh.Scale = Vector3.new(1.05, 1.05, 1.05)
                        mesh.Parent = rightLeg
                    end
                elseif mesh then
                    mesh:Destroy()
                end
            end
        end
    end
end)

--------------------------------------------------
-- PENCERE (GUI)
--------------------------------------------------
local theme = {
    text = Color3.fromRGB(236, 236, 240),
    muted = Color3.fromRGB(150, 150, 158),
    accent = Color3.fromRGB(104, 132, 255),
    off = Color3.fromRGB(62, 62, 62),
    card = Color3.fromRGB(32, 32, 32),
    control = Color3.fromRGB(45, 45, 45),
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 2147483647
screenGui.OnTopOfCoreBlur = true
screenGui.Enabled = true
screenGui.Parent = guiParent
runtime.gui = screenGui

local mainFrame = Instance.new("CanvasGroup")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 840, 0, 500)
mainFrame.Position = UDim2.new(0.5, -420, 0.5, -250)
mainFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
mainFrame.BackgroundTransparency = 0.45
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Visible = false
mainFrame.Parent = screenGui

mainFrame.ClipsDescendants = true
do
    local bgImage = Instance.new("ImageLabel")
    bgImage.Name = "BackgroundImage"
    bgImage.Size = UDim2.fromScale(1, 1)
    bgImage.BackgroundTransparency = 1
    bgImage.ScaleType = Enum.ScaleType.Crop
    bgImage.ImageTransparency = 0
    bgImage.ZIndex = 0
    bgImage.Parent = mainFrame
    local bgGrad = Instance.new("UIGradient")
    bgGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 235, 240)),
    })
    bgGrad.Rotation = 90
    bgGrad.Parent = bgImage
    task.spawn(function()
        if type(getcustomasset) ~= "function" then return end
        local folder = "SkinChangerBETA"
        local path = folder .. "/bg_forest_v2.jpg"
        local hasFile = type(isfile) == "function" and isfile(path)
        if not hasFile and type(writefile) == "function" then
            local ok, data = pcall(function()
                return game:HttpGet("https://raw.githubusercontent.com/inexifystudio-wq/skinchanger/main/bg_forest.jpg")
            end)
            if ok and type(data) == "string" and #data > 1000 then
                pcall(function()
                    if type(makefolder) == "function" and (type(isfolder) ~= "function" or not isfolder(folder)) then
                        makefolder(folder)
                    end
                    writefile(path, data)
                    hasFile = true
                end)
            end
        end
        if hasFile then
            local okAsset, assetId = pcall(getcustomasset, path)
            if okAsset and type(assetId) == "string" and assetId ~= "" and bgImage and bgImage.Parent then
                bgImage.Image = assetId
            end
        end
    end)
end


local mainScale = Instance.new("UIScale")
mainScale.Scale = 0.86
mainScale.Parent = mainFrame
local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(230, 230, 236)
mainStroke.Thickness = 1
mainStroke.Transparency = 0.7
mainStroke.Parent = mainFrame
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 42)
titleBar.BackgroundTransparency = 1
titleBar.ZIndex = 2
titleBar.Parent = mainFrame

local headerLabel = Instance.new("TextLabel")
headerLabel.Size = UDim2.new(1, -360, 0, 42)
headerLabel.Position = UDim2.new(0, 52, 0, 0)
headerLabel.BackgroundTransparency = 1
headerLabel.Text = "BLADE BALL"
headerLabel.TextColor3 = theme.text
headerLabel.TextSize = 14
headerLabel.Font = Enum.Font.GothamBold
headerLabel.TextXAlignment = Enum.TextXAlignment.Left
headerLabel.Parent = titleBar

do
    local iconBox = Instance.new("Frame")
    iconBox.Size = UDim2.new(0, 26, 0, 26)
    iconBox.Position = UDim2.new(0, 16, 0, 8)
    iconBox.BackgroundColor3 = theme.accent
    iconBox.BorderSizePixel = 0
    iconBox.Parent = titleBar
    Instance.new("UICorner", iconBox).CornerRadius = UDim.new(0, 7)
    local iconText = Instance.new("TextLabel")
    iconText.Size = UDim2.fromScale(1, 1)
    iconText.BackgroundTransparency = 1
    iconText.Text = "B"
    iconText.TextColor3 = Color3.new(1, 1, 1)
    iconText.TextSize = 15
    iconText.Font = Enum.Font.GothamBold
    iconText.Parent = iconBox

    local div = Instance.new("Frame")
    div.Size = UDim2.new(1, -24, 0, 1)
    div.Position = UDim2.new(0, 12, 0, 41)
    div.BackgroundColor3 = Color3.new(1, 1, 1)
    div.BackgroundTransparency = 0.92
    div.BorderSizePixel = 0
    div.Parent = titleBar
end

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 26, 0, 26)
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, -14, 0, 21)
closeButton.BackgroundColor3 = theme.control
closeButton.BorderSizePixel = 0
closeButton.Text = "X"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.TextSize = 14
closeButton.Font = Enum.Font.GothamBold
closeButton.Parent = titleBar
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 8)

do
    local dragging, dragInput, dragStart, startPos
    connect(titleBar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, mainFrame.Position
            connect(input.Changed, function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    connect(titleBar.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if input == dragInput and dragging then
            local d = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -196, 1, -64)
contentFrame.Position = UDim2.new(0, 184, 0, 52)
contentFrame.BackgroundTransparency = 0.82
contentFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
contentFrame.BorderSizePixel = 0
contentFrame.ZIndex = 2
contentFrame.Parent = mainFrame
Instance.new("UICorner", contentFrame).CornerRadius = UDim.new(0, 10)
do
    local s = Instance.new("UIStroke", contentFrame)
    s.Color = Color3.new(1, 1, 1)
    s.Transparency = 0.92
end

local MouseUnlock = Instance.new("TextButton")
MouseUnlock.BackgroundTransparency = 1
MouseUnlock.Size = UDim2.fromOffset(0, 0)
MouseUnlock.Text = ""
MouseUnlock.Modal = false
MouseUnlock.Parent = mainFrame

--------------------------------------------------
-- GUI AYARLARI + AC/KAPAT
--------------------------------------------------
local uiSettings = {
    red = 14, green = 14, blue = 14,
    transparency = 0.06,
    animationEnabled = true,
    animationDuration = 0.45,
    guiKey = "L",
    waitingKey = false,
    saveToken = 0,
    storage = { folder = "SkinChangerBETA", path = "SkinChangerBETA/gui_settings.json" },
}

pcall(function()
    if typeof(writefile) == "function" and typeof(readfile) == "function" then
        uiSettings.storage.write = writefile
        uiSettings.storage.read = readfile
        uiSettings.storage.isFile = typeof(isfile) == "function" and isfile or nil
        uiSettings.storage.makeFolder = typeof(makefolder) == "function" and makefolder or nil
        uiSettings.storage.isFolder = typeof(isfolder) == "function" and isfolder or nil
        uiSettings.storage.available = true
    end
end)

function uiSettings.applyTheme()
    mainFrame.BackgroundColor3 = Color3.fromRGB(uiSettings.red, uiSettings.green, uiSettings.blue)
    contentFrame.BackgroundColor3 = Color3.fromRGB(
        math.min(255, uiSettings.red + 10),
        math.min(255, uiSettings.green + 10),
        math.min(255, uiSettings.blue + 10)
    )
    mainFrame.GroupTransparency = uiSettings.transparency
end

function uiSettings.load()
    local st = uiSettings.storage
    if not st.available then return end
    local ok, raw = pcall(function()
        if st.isFile and not st.isFile(st.path) then return nil end
        return st.read(st.path)
    end)
    if not ok or type(raw) ~= "string" or raw == "" then return end
    local decOk, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not decOk or type(data) ~= "table" then return end
    if type(data.red) == "number" then uiSettings.red = math.clamp(math.floor(data.red), 0, 255) end
    if type(data.green) == "number" then uiSettings.green = math.clamp(math.floor(data.green), 0, 255) end
    if type(data.blue) == "number" then uiSettings.blue = math.clamp(math.floor(data.blue), 0, 255) end
    if type(data.transparency) == "number" then uiSettings.transparency = math.clamp(data.transparency, 0, 0.9) end
    if type(data.animationDuration) == "number" then uiSettings.animationDuration = math.clamp(data.animationDuration, 0.1, 1.5) end
    if type(data.animationEnabled) == "boolean" then uiSettings.animationEnabled = data.animationEnabled end
    if type(data.guiKey) == "string" and Enum.KeyCode[data.guiKey] then uiSettings.guiKey = data.guiKey end
end

function uiSettings.saveNow()
    local st = uiSettings.storage
    if not st.available then return end
    pcall(function()
        if st.makeFolder and (not st.isFolder or not st.isFolder(st.folder)) then st.makeFolder(st.folder) end
        st.write(st.path, HttpService:JSONEncode({
            red = uiSettings.red, green = uiSettings.green, blue = uiSettings.blue,
            transparency = uiSettings.transparency,
            animationDuration = uiSettings.animationDuration,
            animationEnabled = uiSettings.animationEnabled,
            guiKey = uiSettings.guiKey,
        }))
    end)
end

function uiSettings.scheduleSave()
    uiSettings.saveToken = uiSettings.saveToken + 1
    local token = uiSettings.saveToken
    task.delay(0.35, function()
        if runtimeIsActive() and token == uiSettings.saveToken then uiSettings.saveNow() end
    end)
end

uiSettings.load()
uiSettings.applyTheme()

local guiOpen = false
local guiToken = 0
local function setGuiVisible(visible)
    guiOpen = visible
    guiToken = guiToken + 1
    local myToken = guiToken
    MouseUnlock.Modal = visible
    if visible then
        mainFrame.Visible = true
        if not uiSettings.animationEnabled then
            mainScale.Scale = 1
            mainFrame.GroupTransparency = uiSettings.transparency
            return
        end
        mainScale.Scale = 0.86
        mainFrame.GroupTransparency = 1
        TweenService:Create(mainScale, TweenInfo.new(uiSettings.animationDuration, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
        TweenService:Create(mainFrame, TweenInfo.new(uiSettings.animationDuration * 0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = uiSettings.transparency }):Play()
    else
        if not uiSettings.animationEnabled or not mainFrame.Visible then
            mainFrame.Visible = false
            return
        end
        local t = uiSettings.animationDuration * 0.55
        TweenService:Create(mainFrame, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 }):Play()
        TweenService:Create(mainScale, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.92 }):Play()
        task.delay(t, function()
            if runtimeIsActive() and guiToken == myToken then mainFrame.Visible = false end
        end)
    end
end
local function toggleGui() setGuiVisible(not guiOpen) end

do
    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 26, 0, 26)
    minBtn.AnchorPoint = Vector2.new(1, 0.5)
    minBtn.Position = UDim2.new(1, -76, 0, 21)
    minBtn.BackgroundTransparency = 1
    minBtn.Text = "-"
    minBtn.TextColor3 = Color3.fromRGB(236, 236, 240)
    minBtn.TextSize = 16
    minBtn.Font = Enum.Font.GothamBold
    minBtn.ZIndex = 3
    minBtn.Parent = titleBar
    connect(minBtn.MouseButton1Click, function() setGuiVisible(false) end)

    local maxBtn = Instance.new("TextButton")
    maxBtn.Size = UDim2.new(0, 26, 0, 26)
    maxBtn.AnchorPoint = Vector2.new(1, 0.5)
    maxBtn.Position = UDim2.new(1, -44, 0, 21)
    maxBtn.BackgroundTransparency = 1
    maxBtn.Text = "[]"
    maxBtn.TextColor3 = Color3.fromRGB(236, 236, 240)
    maxBtn.TextSize = 12
    maxBtn.Font = Enum.Font.GothamBold
    maxBtn.ZIndex = 3
    maxBtn.Parent = titleBar
    local isMax = false
    connect(maxBtn.MouseButton1Click, function()
        isMax = not isMax
        if isMax then
            mainFrame.Size = UDim2.new(0, 960, 0, 560)
            mainFrame.Position = UDim2.new(0.5, -480, 0.5, -280)
        else
            mainFrame.Size = UDim2.new(0, 840, 0, 500)
            mainFrame.Position = UDim2.new(0.5, -420, 0.5, -250)
        end
    end)
end


connect(closeButton.MouseButton1Click, toggleGui)
connect(UserInputService.InputBegan, function(input, gameProcessed)
    if uiSettings.waitingKey then
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
            if input.KeyCode ~= Enum.KeyCode.Escape then
                uiSettings.guiKey = input.KeyCode.Name
                uiSettings.scheduleSave()
            end
            uiSettings.waitingKey = false
            if uiSettings.refreshKeyButton then uiSettings.refreshKeyButton() end
        end
        return
    end
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == uiSettings.guiKey then
        toggleGui()
    end
end)

do
    local launcher = Instance.new("TextButton")
    launcher.Name = "Launcher"
    launcher.Size = UDim2.fromOffset(46, 46)
    launcher.AnchorPoint = Vector2.new(0.5, 0.5)
    launcher.Position = UDim2.new(0, 42, 0.5, 0)
    launcher.BackgroundColor3 = theme.accent
    launcher.BorderSizePixel = 0
    launcher.AutoButtonColor = false
    launcher.Text = "B"
    launcher.TextColor3 = Color3.new(1, 1, 1)
    launcher.TextSize = 20
    launcher.Font = Enum.Font.GothamBold
    launcher.ZIndex = 50
    launcher.Parent = screenGui
    Instance.new("UICorner", launcher).CornerRadius = UDim.new(0, 10)
    local ls = Instance.new("UIStroke", launcher)
    ls.Color = Color3.new(1, 1, 1)
    ls.Transparency = 0.6

    local lDragging, lMoved = false, false
    local lStart, lStartPos
    connect(launcher.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            lDragging, lMoved = true, false
            lStart, lStartPos = input.Position, launcher.Position
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if lDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - lStart
            if delta.Magnitude > 4 then lMoved = true end
            if lMoved then
                launcher.Position = UDim2.new(lStartPos.X.Scale, lStartPos.X.Offset + delta.X, lStartPos.Y.Scale, lStartPos.Y.Offset + delta.Y)
            end
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if lDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            lDragging = false
            if not lMoved then toggleGui() end
        end
    end)
end

--------------------------------------------------
-- UI YARDIMCILARI
--------------------------------------------------
local function createCard(parent, title, column, y, height)
    local card = Instance.new("Frame")
    if column == 1 then
        card.Size = UDim2.new(0.5, -15, 0, height)
        card.Position = UDim2.new(0, 10, 0, y)
    elseif column == 2 then
        card.Size = UDim2.new(0.5, -15, 0, height)
        card.Position = UDim2.new(0.5, 5, 0, y)
    else
        card.Size = UDim2.new(1, -20, 0, height)
        card.Position = UDim2.new(0, 10, 0, y)
    end
    card.BackgroundColor3 = theme.card
    card.BackgroundTransparency = 0.70
    card.BorderSizePixel = 0
    card.Parent = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
    local cs = Instance.new("UIStroke", card)
    cs.Color = Color3.new(1, 1, 1)
    cs.Transparency = 0.9
    if title then
        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(1, -28, 0, 32)
        t.Position = UDim2.new(0, 14, 0, 0)
        t.BackgroundTransparency = 1
        t.Text = title
        t.TextColor3 = theme.text
        t.TextSize = 13
        t.Font = Enum.Font.GothamBold
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.Parent = card
    end
    return card
end

local function updateToggleVisuals(button, label, name, on)
    label.Text = name
    label.TextColor3 = on and theme.text or Color3.fromRGB(190, 190, 190)
    button.BackgroundColor3 = on and theme.accent or theme.off
    local knob = button:FindFirstChild("Knob")
    if knob then
        knob.Position = on and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
    end
end

local function createToggleRow(parent, name, y, initial, onToggle)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -20, 0, 42)
    row.Position = UDim2.new(0, 10, 0, y)
    row.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    row.BackgroundTransparency = 0.68
    row.BorderSizePixel = 0
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -76, 1, 0)
    label.Position = UDim2.new(0, 14, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(190, 190, 190)
    label.TextSize = 13
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 38, 0, 20)
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, -14, 0.5, 0)
    button.BackgroundColor3 = theme.off
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = ""
    button.Parent = row
    Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0, 3, 0.5, -7)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = button
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local val = initial == true
    updateToggleVisuals(button, label, name, val)
    connect(button.MouseButton1Click, function()
        val = not val
        updateToggleVisuals(button, label, name, val)
        if onToggle then onToggle(val) end
    end)
    return button, label
end

local function createActionButton(parent, text, y, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 34)
    btn.Position = UDim2.new(0, 10, 0, y)
    btn.BackgroundColor3 = theme.control
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = theme.text
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamMedium
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    if onClick then connect(btn.MouseButton1Click, onClick) end
    return btn
end

local function createSlider(parent, labelText, minV, maxV, defV, y, onChanged)
    local current = defV
    local dragging = false
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 20)
    label.Position = UDim2.new(0, 10, 0, y)
    label.BackgroundTransparency = 1
    label.Text = labelText .. ": " .. tostring(current)
    label.TextColor3 = Color3.fromRGB(200, 200, 205)
    label.TextSize = 12
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -20, 0, 6)
    bar.Position = UDim2.new(0, 10, 0, y + 26)
    bar.BackgroundColor3 = Color3.fromRGB(58, 58, 58)
    bar.BorderSizePixel = 0
    bar.Parent = parent
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local ratio = (current - minV) / (maxV - minV)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(ratio, 0, 1, 0)
    fill.BackgroundColor3 = theme.accent
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(ratio, -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = bar
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local hit = Instance.new("Frame")
    hit.Size = UDim2.new(1, 0, 0, 24)
    hit.Position = UDim2.new(0, 0, 0.5, -12)
    hit.BackgroundTransparency = 1
    hit.Parent = bar

    local function setX(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        current = math.floor(minV + (maxV - minV) * rel + 0.5)
        label.Text = labelText .. ": " .. tostring(current)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, -7, 0.5, -7)
        if onChanged then onChanged(current) end
    end

    for _, target in ipairs({ bar, hit, knob }) do
        connect(target.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; setX(input.Position.X)
            end
        end)
    end
    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setX(input.Position.X)
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

--------------------------------------------------
-- SEKMELER: Combat | Curve | Visual | Player | Ayarlar
--------------------------------------------------
local pages = {}
local tabButtons = {}

local function makePage(name)
    local p = Instance.new("ScrollingFrame")
    p.Name = name .. "Page"
    p.Size = UDim2.fromScale(1, 1)
    p.BackgroundTransparency = 1
    p.BorderSizePixel = 0
    p.ScrollBarThickness = 4
    p.AutomaticCanvasSize = Enum.AutomaticSize.Y
    p.CanvasSize = UDim2.new()
    p.Visible = false
    p.Parent = contentFrame
    pages[name] = p
    return p
end

local combatPage = makePage("Combat")
local curvePage = makePage("Curve")
local visualPage = makePage("Visual")
local playerPage = makePage("Player")
local settingsPage = makePage("Ayarlar")

do
    local tabHolder = Instance.new("Frame")
    tabHolder.Size = UDim2.new(0, 162, 1, -64)
    tabHolder.Position = UDim2.new(0, 12, 0, 52)
    tabHolder.BackgroundTransparency = 1
    tabHolder.ZIndex = 2
    tabHolder.Parent = mainFrame
    local l = Instance.new("UIListLayout", tabHolder)
    l.FillDirection = Enum.FillDirection.Vertical
    l.Padding = UDim.new(0, 6)
    l.SortOrder = Enum.SortOrder.LayoutOrder

    local function selectTab(name)
        for k, p in pairs(pages) do p.Visible = k == name end
        for k, b in pairs(tabButtons) do
            b.BackgroundColor3 = k == name and theme.accent or theme.control
        end
    end

    for idx, name in ipairs({ "Combat", "Curve", "Visual", "Player", "Ayarlar" }) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 34)
        b.TextXAlignment = Enum.TextXAlignment.Left
        local tp = Instance.new("UIPadding", b)
        tp.PaddingLeft = UDim.new(0, 14)
        b.BackgroundColor3 = theme.control
        b.BorderSizePixel = 0
        b.Text = name
        b.TextColor3 = theme.text
        b.TextSize = 12
        b.Font = Enum.Font.GothamMedium
        b.LayoutOrder = idx
        b.Parent = tabHolder
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
        tabButtons[name] = b
        connect(b.MouseButton1Click, function() selectTab(name) end)
    end
    selectTab("Combat")
end

-- 1) COMBAT SAYFASI
do
    local combatCard = createCard(combatPage, "Auto Parry & Spam", 1, 10, 316)
    local tokenLbl = Instance.new("TextLabel")
    tokenLbl.Size = UDim2.new(1, -20, 0, 22)
    tokenLbl.Position = UDim2.new(0, 10, 0, 32)
    tokenLbl.BackgroundTransparency = 1
    tokenLbl.Text = "Parry: Güvenli Keypress (Anti-Kick)"
    tokenLbl.TextColor3 = Color3.fromRGB(110, 220, 130)
    tokenLbl.TextSize = 12
    tokenLbl.Font = Enum.Font.GothamBold
    tokenLbl.TextXAlignment = Enum.TextXAlignment.Left
    tokenLbl.Parent = combatCard

    createToggleRow(combatCard, "Auto Parry", 58, true, function(on)
        BB_System.__properties.__autoparry_enabled = on
        BB_System.__properties.__play_animation = on
        if on then BB_AutoParry.start() else BB_AutoParry.stop() end
    end)

    local modeBtn = createActionButton(combatCard, "Parry Mode: Keypress (Güvenli)", 106)
    connect(modeBtn.MouseButton1Click, function()
        BB_System.__properties.__parry_mode = "Keypress"
        modeBtn.Text = "Parry Mode: Keypress (Güvenli)"
    end)

    createSlider(combatCard, "Accuracy", 1, 100, 50, 150, function(v)
        BB_System.__properties.__accuracy = v
        BB_UpdateDivisor()
    end)

    createToggleRow(combatCard, "Random Accuracy (Ping)", 202, false, function(on)
        BB_System.__properties.__randomized_accuracy_enabled = on
        if on then BB_UpdateRandomizedAccuracy() end
    end)

    createToggleRow(combatCard, "Auto Spam", 252, true, function(on)
        if on then BB_AutoSpam.start() else BB_AutoSpam.stop() end
    end)

    local detCard = createCard(combatPage, "Ability Detections", 2, 10, 236)
    createToggleRow(detCard, "Infinity Detection", 38, false, function(v) BB_System.__config.__detections.__infinity = v end)
    createToggleRow(detCard, "Death Slash Detection", 86, false, function(v) BB_System.__config.__detections.__deathslash = v end)
    createToggleRow(detCard, "Time Hole Detection", 134, false, function(v) BB_System.__config.__detections.__timehole = v end)
    createToggleRow(detCard, "Slashes Of Fury Detection", 182, false, function(v) BB_System.__config.__detections.__slashesoffury = v end)
end

-- 2) CURVE SAYFASI
do
    local curveCard = createCard(curvePage, "Parry Curve Ayarları", 1, 10, 220)
    local curveIdx = 1
    local curveBtn = createActionButton(curveCard, "Curve Type: " .. BB_SelectedCurve, 38)
    connect(curveBtn.MouseButton1Click, function()
        curveIdx = (curveIdx % #BB_CurveNames) + 1
        BB_SelectedCurve = BB_CurveNames[curveIdx]
        curveBtn.Text = "Curve Type: " .. BB_SelectedCurve
    end)

    createToggleRow(curveCard, "Random Curve", 82, false, function(v)
        if v then
            if not BB_System.__properties.__connections.__random_curve then
                BB_System.__properties.__connections.__random_curve = connect(RunService.PreSimulation, function()
                    BB_SelectedCurve = BB_CurveNames[math.random(1, #BB_CurveNames)]
                end)
            end
        elseif BB_System.__properties.__connections.__random_curve then
            BB_System.__properties.__connections.__random_curve:Disconnect()
            BB_System.__properties.__connections.__random_curve = nil
            BB_SelectedCurve = BB_CurveNames[curveIdx]
        end
    end)

    createToggleRow(curveCard, "Legit Random Curve", 132, false, function(v)
        if v then
            if not BB_System.__properties.__connections.__legit_curve then
                BB_System.__properties.__connections.__legit_curve = connect(RunService.PreSimulation, function()
                    BB_SelectedCurve = BB_LegitCurveNames[math.random(1, #BB_LegitCurveNames)]
                end)
            end
        elseif BB_System.__properties.__connections.__legit_curve then
            BB_System.__properties.__connections.__legit_curve:Disconnect()
            BB_System.__properties.__connections.__legit_curve = nil
            BB_SelectedCurve = BB_CurveNames[curveIdx]
        end
    end)
end

-- 3) VISUAL SAYFASI
do
    local espCard = createCard(visualPage, "ESP & Cosmetics", 1, 10, 286)
    createToggleRow(espCard, "Unlock All Cosmetics (Sword/Exp)", 38, false, function(v) BB_UnlockAllCosmetics(v) end)
    createToggleRow(espCard, "Player ESP", 86, false, function(v) BB_Config.PlayerESP = v end)
    createToggleRow(espCard, "Show Names", 134, true, function(v) BB_Config.PlayerESPNames = v end)
    createToggleRow(espCard, "Show Distance", 182, true, function(v) BB_Config.PlayerESPDistance = v end)
    createToggleRow(espCard, "Ability ESP", 230, false, function(v) BB_Config.AbilityESP = v end)

    local charCard = createCard(visualPage, "Karakter Görünümü", 2, 10, 140)
    createToggleRow(charCard, "Headless", 38, false, function(v) BB_Config.Headless = v end)
    createToggleRow(charCard, "Korblox", 86, false, function(v) BB_Config.Korblox = v end)
end

-- 4) PLAYER & SERVER SAYFASI
do
    local moveCard = createCard(playerPage, "Hareket (Movement)", 1, 10, 310)
    createToggleRow(moveCard, "Movement Modifiers", 38, false, function(v)
        BB_Config.MovementMods = v
        if not v then
            local hum = BB_GetHum()
            if hum then hum.WalkSpeed = BB_DefaultWS hum.JumpPower = BB_DefaultJP end
        end
    end)
    createSlider(moveCard, "Walk Speed", 16, 120, 36, 88, function(v) BB_Config.WalkSpeed = v end)
    createSlider(moveCard, "Jump Power", 50, 200, 50, 142, function(v) BB_Config.JumpPower = v end)
    createToggleRow(moveCard, "Fly", 196, false, function(v) BB_ToggleFly(v) end)
    createSlider(moveCard, "Fly Speed", 20, 300, 60, 248, function(v) BB_Config.FlySpeed = v end)

    local srvCard = createCard(playerPage, "Sunucu (Server)", 2, 10, 140)
    createActionButton(srvCard, "Rejoin Server", 38, function()
        pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
    end)
    createActionButton(srvCard, "Server Hop", 84, function()
        task.spawn(function()
            local ok, result = pcall(function()
                return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Desc&limit=100"))
            end)
            if not ok or type(result) ~= "table" or type(result.data) ~= "table" then return end
            for _, srv in ipairs(result.data) do
                if srv.playing < srv.maxPlayers and srv.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id, LocalPlayer)
                    return
                end
            end
        end)
    end)
end

-- 5) AYARLAR SAYFASI
do
    local c1 = createCard(settingsPage, "Renk ve Saydamlık", 1, 10, 260)
    createSlider(c1, "Kırmızı", 0, 255, uiSettings.red, 38, function(v)
        uiSettings.red = v; uiSettings.applyTheme(); uiSettings.scheduleSave()
    end)
    createSlider(c1, "Yeşil", 0, 255, uiSettings.green, 92, function(v)
        uiSettings.green = v; uiSettings.applyTheme(); uiSettings.scheduleSave()
    end)
    createSlider(c1, "Mavi", 0, 255, uiSettings.blue, 146, function(v)
        uiSettings.blue = v; uiSettings.applyTheme(); uiSettings.scheduleSave()
    end)
    createSlider(c1, "Saydamlık (%)", 0, 90, math.floor(uiSettings.transparency * 100 + 0.5), 200, function(v)
        uiSettings.transparency = v / 100
        mainFrame.GroupTransparency = uiSettings.transparency
        uiSettings.scheduleSave()
    end)

    local c2 = createCard(settingsPage, "Animasyon & GUI Tuşu", 2, 10, 260)
    createSlider(c2, "Animasyon Hızı", 1, 15, math.floor(uiSettings.animationDuration * 10 + 0.5), 38, function(v)
        uiSettings.animationDuration = v / 10; uiSettings.scheduleSave()
    end)
    createToggleRow(c2, "Açılış Animasyonu", 96, uiSettings.animationEnabled, function(on)
        uiSettings.animationEnabled = on; uiSettings.scheduleSave()
    end)
    local keyBtn = createActionButton(c2, "", 156, function()
        uiSettings.waitingKey = true
        if uiSettings.refreshKeyButton then uiSettings.refreshKeyButton() end
    end)
    createActionButton(c2, "Varsayılana Sıfırla (L)", 202, function()
        uiSettings.waitingKey = false
        uiSettings.guiKey = "L"
        if uiSettings.refreshKeyButton then uiSettings.refreshKeyButton() end
        uiSettings.scheduleSave()
    end)
    uiSettings.refreshKeyButton = function()
        keyBtn.Text = uiSettings.waitingKey
            and "Bir tuşa bas... (ESC: iptal)"
            or ("Tuş: " .. uiSettings.guiKey .. " (değiştirmek için tıkla)")
    end
    uiSettings.refreshKeyButton()
end

runtime.cleanup = function()
    uiSettings.saveNow()
    BB_System.__properties.__autoparry_enabled = false
    BB_System.__properties.__play_animation = false
    BB_AutoParry.stop()
    BB_AutoSpam.stop()
    BB_ToggleFly(false)
    BB_Config.MovementMods = false
    local hum = BB_GetHum()
    if hum then
        hum.WalkSpeed = BB_DefaultWS
        hum.JumpPower = BB_DefaultJP
    end
    BB_Config.PlayerESP = false
    BB_Config.AbilityESP = false
    BB_Config.Headless = false
    BB_Config.Korblox = false
    BB_ClearAllESP()
    BB_UnlockAllCosmetics(false)
end

BB_AutoParry.start()
BB_AutoSpam.start()
setGuiVisible(true)
