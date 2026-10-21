local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Config = {
    AutoFarm = false,
    AutoSkill = true,
    AutoAttack = true,
    AutoAvoid = false,
    AutoProgressStage = true,
    AutoFindChest = false,
    AutoFindEgg = false,
    SaveSettings = true,
    PerformanceMode = false,
    Debug = false,
    SafeMode = true,
    EmergencyEscape = true,

    -- UI theme accent (RGB table keeps settings JSON-safe).
    AccentColor = {92, 82, 145},

    OrbitRadius = 6,
    OrbitSpeed = 4,

    AboveHeight = 8,
    UndergroundHeight = 8,
    UndergroundMode = true,

    KillAuraRadius = 45,

    TargetRefresh = 0.20,
    PortalRefresh = 1.00,
    SkillInterval = 2.50,
    RoomClearRadius = 140,
    RoomClearDelay = 1.25,
    TargetSearchRadius = 600,
    DoorInteractDistance = 18,
    DoorOpenWait = 0.90,
    ExitSearchRadius = 600,
    ExitRetryDelay = 0.75,

    MovementInterval = 1 / 30,
    AttackInterval = 0.10,
    StatusInterval = 0.20,
    GroundSampleInterval = 0.10,
}

_G.AutoFarm = Config.AutoFarm
_G.AutoSkill = Config.AutoSkill
_G.AutoAttack = Config.AutoAttack
_G.AutoAvoid = Config.AutoAvoid
_G.AutoProgressStage = Config.AutoProgressStage
_G.OrbitRadius = Config.OrbitRadius
_G.OrbitSpeed = Config.OrbitSpeed
_G.FloatHeight = Config.AboveHeight
_G.UndergroundMode = Config.UndergroundMode
_G.KillAuraRadius = Config.KillAuraRadius

local State = {
    Character = nil,
    Humanoid = nil,
    Root = nil,

    TargetModel = nil,
    TargetRoot = nil,
    TargetHumanoid = nil,

    Portal = nil,
    PortalScore = 0,

    OrbitAngle = 0,
    TargetTimer = 0,
    PortalTimer = 0,
    CollectTimer = 0,
    CollectBusy = false,
    SkillTimer = 0,
    MovementTimer = 0,
    AttackTimer = 0,
    StatusTimer = 0,
    VerticalLockTimer = 0,
    SkillCooldowns = {
        Q = 0,
        G = 0,
        E = 0,
        R = 0,
    },

    StageBusy = false,
    StageCooldown = false,
    EmergencyBusy = false,
    CurrentAction = "Idle",
    LastDamageTime = 0,
    DamageFlash = false,
    LastTargetName = "-",
    LastTargetDistance = math.huge,
    TargetHealthPercent = 0,
    PortalName = "-",
    PortalDistance = math.huge,
    DangerDistance = math.huge,
    DangerPart = nil,
    DangerTimer = 0,
    GroundY = nil,
    GroundTimer = 0,
    UndergroundPhysics = false,
    LastPortalScan = 0,
    RoomClearTimer = 0,
    DoorBusy = false,
    DoorCooldown = false,
    StageBusyTimer = 0,
    WatchdogTimer = 0,
    FallbackTargetTimer = 0,
    Stats = {
        Heartbeats = 0,
        TargetScans = 0,
        PortalScans = 0,
        DangerScans = 0,
        LastHeartbeatMs = 0,
    },
    Dragging = false,
    DragStart = nil,
    StartPosition = nil,

    Unloaded = false,
}

local Connections = {}
local CharacterConnections = {}


local SETTINGS_FILE = "IronSoulSettings.json"

local function syncConfigGlobals()
    _G.AutoFarm = Config.AutoFarm
    _G.AutoSkill = Config.AutoSkill
    _G.AutoAttack = Config.AutoAttack
    _G.AutoAvoid = Config.AutoAvoid
    _G.AutoProgressStage = Config.AutoProgressStage
    _G.OrbitRadius = Config.OrbitRadius
    _G.OrbitSpeed = Config.OrbitSpeed
    _G.FloatHeight = Config.AboveHeight
    _G.AboveHeight = Config.AboveHeight
    _G.UnderGroundHeight = Config.UndergroundHeight
    _G.UndergroundMode = Config.UndergroundMode
    _G.KillAuraRadius = Config.KillAuraRadius
end

local function getSaveData()
    return {
        AutoFarm = Config.AutoFarm,
        AutoSkill = Config.AutoSkill,
        AutoAttack = Config.AutoAttack,
        AutoAvoid = Config.AutoAvoid,
        AutoProgressStage = Config.AutoProgressStage,
        AutoFindChest = Config.AutoFindChest,
        AutoFindEgg = Config.AutoFindEgg,
        OrbitRadius = Config.OrbitRadius,
        OrbitSpeed = Config.OrbitSpeed,
        AboveHeight = Config.AboveHeight,
        UndergroundHeight = Config.UndergroundHeight,
        UndergroundMode = Config.UndergroundMode,
        KillAuraRadius = Config.KillAuraRadius,
        PerformanceMode = Config.PerformanceMode,
        SafeMode = Config.SafeMode,
        EmergencyEscape = Config.EmergencyEscape,
        AccentColor = Config.AccentColor,
        TargetSearchRadius = Config.TargetSearchRadius,
        DoorInteractDistance = Config.DoorInteractDistance,
        DoorOpenWait = Config.DoorOpenWait,
        ExitSearchRadius = Config.ExitSearchRadius,
        ExitRetryDelay = Config.ExitRetryDelay,
        Debug = Config.Debug,
    }
end

local function saveSettings()
    if not Config.SaveSettings or type(writefile) ~= "function" then
        return
    end

    pcall(function()
        writefile(SETTINGS_FILE, HttpService:JSONEncode(getSaveData()))
    end)
end

local function loadSettings()
    if type(readfile) ~= "function" or type(isfile) ~= "function" or not isfile(SETTINGS_FILE) then
        syncConfigGlobals()
        return
    end

    pcall(function()
        local data = HttpService:JSONDecode(readfile(SETTINGS_FILE))

        if type(data) == "table" then
            for _, key in ipairs({
                "AutoFarm", "AutoSkill", "AutoAttack", "AutoAvoid", "Debug",
                "AutoProgressStage", "AutoFindChest", "AutoFindEgg", "OrbitRadius", "OrbitSpeed",
                "AboveHeight", "UndergroundHeight", "UndergroundMode",
                "KillAuraRadius", "TargetSearchRadius", "DoorInteractDistance", "DoorOpenWait", "ExitSearchRadius", "ExitRetryDelay", "PerformanceMode", "SafeMode",
                "EmergencyEscape"
            }) do
                if data[key] ~= nil then
                    Config[key] = data[key]
                end
            end

            if type(data.AccentColor) == "table" then
                local r = tonumber(data.AccentColor[1]) or tonumber(data.AccentColor.r)
                local g = tonumber(data.AccentColor[2]) or tonumber(data.AccentColor.g)
                local b = tonumber(data.AccentColor[3]) or tonumber(data.AccentColor.b)
                if r and g and b then
                    Config.AccentColor = {
                        math.clamp(r, 0, 255),
                        math.clamp(g, 0, 255),
                        math.clamp(b, 0, 255),
                    }
                end
            end
        end
    end)

    syncConfigGlobals()
end


local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(Connections, connection)
    return connection
end

local function connectCharacter(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(CharacterConnections, connection)
    return connection
end

pcall(loadSettings)

-- Always start disabled; the user must enable Auto Farm with the toggle.
Config.AutoFarm = false
_G.AutoFarm = false

local function disconnectList(list)
    for _, connection in ipairs(list) do
        if connection.Connected then
            connection:Disconnect()
        end
    end
    table.clear(list)
end

local function debugPrint(...)
    if Config.Debug then
        print("[IronSoul]", ...)
    end
end

local function refreshCharacter(character)
    disconnectList(CharacterConnections)

    State.Character = character
    State.Humanoid = character:FindFirstChildOfClass("Humanoid")
    State.Root = character:FindFirstChild("HumanoidRootPart")

    State.TargetModel = nil
    State.TargetRoot = nil
    State.TargetHumanoid = nil
    State.StageBusy = false
    State.StageCooldown = false
    State.DoorBusy = false
    State.DoorCooldown = false
    State.RoomClearTimer = 0
    State.StageBusyTimer = 0
    State.GroundY = nil
    State.GroundTimer = Config.GroundSampleInterval
    State.UndergroundPhysics = false

    if State.Humanoid then
        pcall(function()
            State.Humanoid.PlatformStand = false
            State.Humanoid.AutoRotate = true
        end)
    end

    if not State.Humanoid then
        State.Humanoid = character:WaitForChild("Humanoid", 5)
    end

    if not State.Root then
        State.Root = character:WaitForChild("HumanoidRootPart", 5)
    end

    local function configurePart(object)
        if object:IsA("BasePart") then
            object.CanCollide = false
        end
    end

    for _, object in ipairs(character:GetDescendants()) do
        configurePart(object)
    end

    connectCharacter(character.DescendantAdded, configurePart)

    debugPrint("Character refreshed")
end

connect(player.CharacterAdded, refreshCharacter)

if player.Character then
    refreshCharacter(player.Character)
else
    refreshCharacter(player.CharacterAdded:Wait())
end


local function emergencyEscape(reason)
    if not Config.EmergencyEscape
        or State.EmergencyBusy
        or not State.Root
        or not State.Humanoid then
        return
    end

    State.EmergencyBusy = true
    State.CurrentAction = reason or "Emergency Escape"

    local root = State.Root
    local humanoid = State.Humanoid

    local danger = State.DangerPart
    local direction

    if danger and danger.Parent then
        direction = root.Position - danger.Position
        direction = Vector3.new(direction.X, 0, direction.Z)
    end

    if not direction or direction.Magnitude < 0.05 then
        direction = Vector3.new(math.cos(State.OrbitAngle), 0, math.sin(State.OrbitAngle))
    else
        direction = direction.Unit
    end

    humanoid:MoveTo(root.Position + direction * 18)

    task.delay(0.45, function()
        if not State.Unloaded then
            State.EmergencyBusy = false
            State.CurrentAction = Config.AutoFarm and "Farming" or "Idle"
        end
    end)
end

local function installHealthWatcher()
    local humanoid = State.Humanoid

    if not humanoid then
        return
    end

    local previous = humanoid.Health

    connectCharacter(humanoid.HealthChanged, function(health)
        if health < previous then
            State.LastDamageTime = os.clock()

            if Config.AutoAvoid then
                State.CurrentAction = "Avoiding Attack"
            end

            if Config.EmergencyEscape then
                task.spawn(function()
                    emergencyEscape("Emergency Escape")
                end)
            end
        end

        previous = health
        State.TargetHealthPercent =
            State.TargetHumanoid
            and State.TargetHumanoid.MaxHealth > 0
            and math.clamp(State.TargetHumanoid.Health / State.TargetHumanoid.MaxHealth, 0, 1) * 100
            or 0
    end)
end

installHealthWatcher()

connect(player.CharacterAdded, function()
    task.defer(installHealthWatcher)
end)

if not _G.AntiAFK_Loaded then
    _G.AntiAFK_Loaded = true

    connect(player.Idled, function()
        if State.Unloaded then
            return
        end

        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.zero)
        end)
    end)
end

local function pressKey(keyName)
    local keyCode = Enum.KeyCode[keyName]

    if not keyCode then
        return
    end

    pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.02)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

local function activateTool()
    if not State.Character then
        return
    end

    local tool = State.Character:FindFirstChildOfClass("Tool")

    if tool then
        pcall(function()
            tool:Activate()
        end)
    end
end

local function getAliveTargetParts(model)
    if not model or model == State.Character then
        return nil, nil
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")

    if not humanoid or humanoid.Health <= 0 then
        return nil, nil
    end

    local root = model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart

    if not root or not root:IsA("BasePart") then
        return nil, nil
    end

    return humanoid, root
end

local function considerTarget(model, origin, bestDistanceSquared)
    local humanoid, root = getAliveTargetParts(model)

    if not humanoid or not root then
        return nil, bestDistanceSquared
    end

    local offset = origin - root.Position
    local distanceSquared = offset:Dot(offset)

    if distanceSquared < bestDistanceSquared then
        return root, distanceSquared, humanoid, model
    end

    return nil, bestDistanceSquared
end


local function scoreTarget(model, humanoid, root, distanceSquared)
    local score = 0
    local name = string.lower(model.Name)

    if distanceSquared < 15 * 15 then
        score += 8
    elseif distanceSquared < 35 * 35 then
        score += 5
    else
        score += 2
    end

    if name:find("boss", 1, true) then
        score += 15
    elseif name:find("elite", 1, true) then
        score += 8
    end

    if humanoid.MaxHealth > 0 then
        local hp = humanoid.Health / humanoid.MaxHealth

        if hp < 0.25 then
            score += 4
        end
    end

    if root.Position.Y < -500 then
        score -= 2
    end

    return score
end


local enemyCandidates = {}

local function looksLikeEnemyModel(model)
    if not model
        or not model:IsA("Model")
        or model == State.Character
        or Players:GetPlayerFromCharacter(model) ~= nil then
        return false
    end

    return model:FindFirstChildOfClass("Humanoid") ~= nil
        and (
            model:FindFirstChild("HumanoidRootPart") ~= nil
            or model.PrimaryPart ~= nil
        )
end

local function addEnemyCandidate(object)
    local model = object

    if not model:IsA("Model") then
        model = object:FindFirstAncestorOfClass("Model")
    end

    if model
        and model ~= State.Character
        and looksLikeEnemyModel(model) then
        enemyCandidates[model] = true
    end
end

local function removeEnemyCandidate(object)
    if object:IsA("Model") then
        enemyCandidates[object] = nil
    else
        local model = object:FindFirstAncestorOfClass("Model")
        if model then
            enemyCandidates[model] = nil
        end
    end
end

for _, object in ipairs(workspace:GetDescendants()) do
    addEnemyCandidate(object)
end

connect(workspace.DescendantAdded, addEnemyCandidate)
connect(workspace.DescendantRemoving, removeEnemyCandidate)

local fallbackOverlapParams = OverlapParams.new()
fallbackOverlapParams.FilterType = Enum.RaycastFilterType.Exclude

local function findNearestTargetFallback()
    if not State.Root or not State.Root.Parent then
        return nil, nil, nil
    end

    fallbackOverlapParams.FilterDescendantsInstances = {
        State.Character
    }

    local origin = State.Root.Position
    local radius = Config.TargetSearchRadius
    local radiusSquared = radius * radius

    local seen = {}
    local bestModel = nil
    local bestRoot = nil
    local bestHumanoid = nil
    local bestDistanceSquared = math.huge

    local ok, parts = pcall(function()
        return workspace:GetPartBoundsInRadius(
            origin,
            radius,
            fallbackOverlapParams
        )
    end)

    if not ok or not parts then
        return nil, nil, nil
    end

    for _, part in ipairs(parts) do
        local model = part:FindFirstAncestorOfClass("Model")

        if model
            and model ~= State.Character
            and not seen[model] then

            seen[model] = true

            local humanoid, targetRoot = getAliveTargetParts(model)

            if humanoid and targetRoot then
                local offset = origin - targetRoot.Position
                local distanceSquared = offset:Dot(offset)

                if distanceSquared <= radiusSquared then
                    local score = scoreTarget(
                        model,
                        humanoid,
                        targetRoot,
                        distanceSquared
                    )

                    if score > -math.huge
                        and (
                            bestModel == nil
                            or score > scoreTarget(
                                bestModel,
                                bestHumanoid,
                                bestRoot,
                                bestDistanceSquared
                            )
                        ) then
                        bestModel = model
                        bestRoot = targetRoot
                        bestHumanoid = humanoid
                        bestDistanceSquared = distanceSquared
                    end
                end
            end
        end
    end

    return bestModel, bestRoot, bestHumanoid
end

local function findNearestTarget()
    State.Stats.TargetScans += 1

    local root = State.Root

    if not root or not root.Parent then
        return nil, nil, nil
    end

    local origin = root.Position
    local searchRadius = Config.TargetSearchRadius
    local searchRadiusSquared = searchRadius * searchRadius

    local nearestRoot = nil
    local nearestHumanoid = nil
    local nearestModel = nil
    local bestScore = -math.huge

    for model in pairs(enemyCandidates) do
        if not model or not model.Parent then
            enemyCandidates[model] = nil
        else
            local humanoid, targetRoot = getAliveTargetParts(model)

            if humanoid and targetRoot then
                local offset = origin - targetRoot.Position
                local distanceSquared = offset:Dot(offset)

                if distanceSquared <= searchRadiusSquared then
                    local score = scoreTarget(
                        model,
                        humanoid,
                        targetRoot,
                        distanceSquared
                    )

                    if score > bestScore then
                        bestScore = score
                        nearestRoot = targetRoot
                        nearestHumanoid = humanoid
                        nearestModel = model
                    end
                end
            end
        end
    end

    if nearestModel then
        return nearestModel, nearestRoot, nearestHumanoid
    end

    if State.FallbackTargetTimer > 0 then
        return nil, nil, nil
    end

    State.FallbackTargetTimer = 1.0
    return findNearestTargetFallback()
end

local function targetIsValid()
    local model = State.TargetModel
    local humanoid = State.TargetHumanoid
    local root = State.TargetRoot

    return model
        and model.Parent
        and humanoid
        and humanoid.Parent
        and humanoid.Health > 0
        and root
        and root.Parent
end

local function refreshTarget()
    if not Config.AutoFarm or State.StageBusy then
        State.TargetModel = nil
        State.TargetRoot = nil
        State.TargetHumanoid = nil
        State.RoomClearTimer = 0
        return
    end

    local model, root, humanoid = findNearestTarget()

    State.TargetModel = model
    State.TargetRoot = root
    State.TargetHumanoid = humanoid
    State.LastTargetName = model and model.Name or "No target"
    State.LastTargetDistance =
        root and State.Root
        and (State.Root.Position - root.Position).Magnitude
        or math.huge

    State.TargetHealthPercent =
        humanoid and humanoid.MaxHealth > 0
        and math.clamp(
            humanoid.Health / humanoid.MaxHealth,
            0,
            1
        ) * 100
        or 0

    if model and humanoid and humanoid.Health > 0 then
        State.RoomClearTimer = 0
    end
end

local portalCandidates = {}

local function getExitType(part)
    if not part or not part:IsA("BasePart") then
        return nil
    end

    local names = {
        string.lower(part.Name),
    }

    local ancestor = part.Parent
    local depth = 0

    while ancestor and depth < 4 do
        if ancestor:IsA("Model") or ancestor:IsA("Folder") then
            table.insert(names, string.lower(ancestor.Name))
        end

        ancestor = ancestor.Parent
        depth += 1
    end

    local hasPortalName = false
    local hasDoorName = false

    for _, name in ipairs(names) do
        if name:find("portal", 1, true)
            or name:find("teleport", 1, true)
            or name:find("portalexit", 1, true)
            or name:find("warp", 1, true) then
            hasPortalName = true
        end

        if name:find("door", 1, true)
            or name:find("gate", 1, true)
            or name:find("exit", 1, true)
            or name:find("entrance", 1, true) then
            hasDoorName = true
        end

        if name:find("next", 1, true)
            or name:find("finish", 1, true) then
            hasPortalName = true
        end
    end

    if hasPortalName then
        return "portal"
    end

    if hasDoorName then
        return "door"
    end

    return nil
end

local function isPortalCandidate(part)
    return getExitType(part) ~= nil
end

local function rebuildPortalCandidates()
    State.Stats.PortalScans += 1
    table.clear(portalCandidates)

    for _, object in ipairs(workspace:GetDescendants()) do
        if isPortalCandidate(object) then
            table.insert(portalCandidates, object)
        end
    end
end

local function scorePortal(part, origin)
    if not part or not part.Parent then
        return -math.huge, nil
    end

    local exitType = getExitType(part)

    if not exitType then
        return -math.huge, nil
    end

    local name = string.lower(part.Name)
    local parentName = part.Parent
        and string.lower(part.Parent.Name)
        or ""

    local score = 0

    if exitType == "portal" then
        score += 8

        if name:find("portal", 1, true)
            or parentName:find("portal", 1, true) then
            score += 5
        end

        if name:find("teleport", 1, true)
            or parentName:find("teleport", 1, true) then
            score += 3
        end
    else
        score += 2

        if name:find("door", 1, true) then
            score += 2
        end

        if name:find("gate", 1, true) then
            score += 2
        end
    end

    if name:find("next", 1, true)
        or name:find("finish", 1, true)
        or name:find("exit", 1, true) then
        score += 2
    end

    if part:FindFirstChildOfClass("TouchTransmitter") then
        score += 3
    end

    if part:FindFirstChildOfClass("ProximityPrompt") then
        score += 4
    end

    if part.Material == Enum.Material.Neon then
        score += 3
    end

    if part.Size.Y > 5 and part.Size.X > 5 then
        score += 2
    end

    local offset = origin - part.Position
    local distanceSquared = offset:Dot(offset)

    score += math.max(0, 1 - distanceSquared / (50 * 50))

    return score, exitType
end

local function registerPortalCandidate(object)
    if isPortalCandidate(object) and not table.find(portalCandidates, object) then
        table.insert(portalCandidates, object)
    end
end

local function unregisterPortalCandidate(object)
    for index = #portalCandidates, 1, -1 do
        if portalCandidates[index] == object then
            table.remove(portalCandidates, index)
            break
        end
    end
end

connect(workspace.DescendantAdded, registerPortalCandidate)
connect(workspace.DescendantRemoving, unregisterPortalCandidate)

local function findBestExit()
    if not State.Root then
        return nil, 0, nil
    end

    local origin = State.Root.Position
    local maxDistanceSquared =
        Config.ExitSearchRadius * Config.ExitSearchRadius

    local bestPortal, bestPortalScore = nil, -math.huge
    local bestDoor, bestDoorScore = nil, -math.huge

    for index = #portalCandidates, 1, -1 do
        local part = portalCandidates[index]

        if not part or not part.Parent then
            table.remove(portalCandidates, index)
        else
            local delta = origin - part.Position
            local distanceSquared = delta:Dot(delta)

            if distanceSquared <= maxDistanceSquared then
                local score, exitType = scorePortal(part, origin)

                if exitType == "portal" and score > bestPortalScore then
                    bestPortal = part
                    bestPortalScore = score
                elseif exitType == "door" and score > bestDoorScore then
                    bestDoor = part
                    bestDoorScore = score
                end
            end
        end
    end

    if bestPortal then
        return bestPortal, bestPortalScore, "portal"
    end

    if bestDoor then
        return bestDoor, bestDoorScore, "door"
    end

    return nil, 0, nil
end


local function findProximityPrompt(rootObject)
    if not rootObject then
        return nil
    end

    if rootObject:IsA("ProximityPrompt") then
        return rootObject
    end

    return rootObject:FindFirstChildOfClass("ProximityPrompt")
        or rootObject:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function getCollectiblePart(object)
    if not object or not object.Parent then return nil end
    if object:IsA("BasePart") then return object end
    if object:IsA("Model") then
        if object.PrimaryPart then return object.PrimaryPart end
        return object:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function findNearestCollectible()
    if not State.Root or (not Config.AutoFindChest and not Config.AutoFindEgg) then
        return nil, nil, nil
    end
    local bestObject, bestPart, bestKind
    local bestDistance = Config.ExitSearchRadius * Config.ExitSearchRadius
    for _, object in ipairs(workspace:GetDescendants()) do
        if object:IsA("Model") or object:IsA("BasePart") then
            local name = string.lower(object.Name)
            local isChest = Config.AutoFindChest and name:find("chest", 1, true) ~= nil
            local isEgg = Config.AutoFindEgg and name:find("egg", 1, true) ~= nil
            if (isChest or isEgg) and not name:find("egghead", 1, true) then
                local model = object:IsA("Model") and object or object:FindFirstAncestorOfClass("Model")
                local isEnemy = model and model:FindFirstChildOfClass("Humanoid") ~= nil
                local part = getCollectiblePart(object)
                if part and not isEnemy then
                    local offset = State.Root.Position - part.Position
                    local distance = offset:Dot(offset)
                    if distance < bestDistance then
                        bestDistance = distance
                        bestObject = object
                        bestPart = part
                        bestKind = isChest and "Chest" or "Egg"
                    end
                end
            end
        end
    end
    return bestObject, bestPart, bestKind
end

local function collectNearestItem()
    if State.CollectBusy or not Config.AutoFarm or State.StageBusy
        or not State.Root or not State.Humanoid or targetIsValid() then
        return
    end
    local object, part, kind = findNearestCollectible()
    if not object or not part or not object.Parent then return end
    State.CollectBusy = true
    State.CurrentAction = "Finding " .. tostring(kind)
    pcall(function()
        local prompt = findProximityPrompt(object) or findProximityPrompt(part)
        local approach = part.Position + Vector3.new(0, math.max(2, part.Size.Y * 0.5 + 1), 0)
        travelToPosition(approach, part.Position)
        task.wait(0.25)
        if prompt and type(fireproximityprompt) == "function" then
            fireproximityprompt(prompt)
        else
            pressKey("E")
            task.wait(0.15)
            pressKey("F")
        end
        task.wait(0.65)
    end)
    State.CollectBusy = false
end

local function beginTravel()
    if not State.Humanoid then
        return
    end

    pcall(function()
        State.Humanoid.PlatformStand = false
        State.Humanoid.AutoRotate = true
        State.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end)

    State.UndergroundPhysics = false
end

local function travelToPosition(position, lookAt)
    if not State.Character or not State.Root then
        return false
    end

    beginTravel()

    local cframe

    if lookAt then
        cframe = CFrame.new(position, lookAt)
    else
        cframe = CFrame.new(position)
    end

    local ok = pcall(function()
        State.Character:PivotTo(cframe)
        State.Root.CFrame = cframe
        State.Root.AssemblyLinearVelocity = Vector3.zero
        State.Root.AssemblyAngularVelocity = Vector3.zero
    end)

    return ok
end

local function interactWithDoor(door)
    if not door
        or not door.Parent
        or State.DoorBusy
        or State.DoorCooldown
        or not State.Root
        or not State.Humanoid then
        return false
    end

    State.DoorBusy = true
    State.CurrentAction = "Opening Door"

    local succeeded = false

    pcall(function()
        local prompt = findProximityPrompt(door)

        local approachPosition =
            door.Position - door.CFrame.LookVector * Config.DoorInteractDistance

        travelToPosition(
            approachPosition,
            door.Position
        )

        task.wait(0.25)

        if prompt and type(fireproximityprompt) == "function" then
            fireproximityprompt(prompt)
            succeeded = true
        else
            pressKey("F")
            succeeded = true
        end

        task.wait(Config.DoorOpenWait)

        if door.Parent and prompt == nil then
            pressKey("F")
            task.wait(0.35)
        end
    end)

    State.DoorBusy = false
    State.DoorCooldown = true

    task.delay(1.25, function()
        if not State.Unloaded then
            State.DoorCooldown = false
        end
    end)

    return succeeded
end


local function findBestPortalOnly()
    if not State.Root then
        return nil, 0
    end

    local origin = State.Root.Position
    local maxDistanceSquared =
        Config.ExitSearchRadius * Config.ExitSearchRadius

    local bestPortal = nil
    local bestScore = -math.huge

    for index = #portalCandidates, 1, -1 do
        local part = portalCandidates[index]

        if not part or not part.Parent then
            table.remove(portalCandidates, index)
        else
            local delta = origin - part.Position
            local distanceSquared = delta:Dot(delta)

            if distanceSquared <= maxDistanceSquared then
                local score, exitType = scorePortal(part, origin)

                if exitType == "portal" and score > bestScore then
                    bestPortal = part
                    bestScore = score
                end
            end
        end
    end

    return bestPortal, bestScore
end


local function teleportNearPortal()
    if not State.Root then
        return
    end

    local portal, score = findBestPortalOnly()

    if not portal or score < 2 then
        return
    end

    State.Portal = portal
    State.PortalScore = score

    local position =
        portal.Position - portal.CFrame.LookVector * 8

    travelToPosition(position, portal.Position)
end


local function moveToNextStage()
    if not Config.AutoProgressStage
        or State.StageBusy
        or State.StageCooldown
        or State.DoorBusy
        or not State.Root
        or not State.Humanoid
        or not Config.AutoFarm then
        return
    end

    local model, root, humanoid = findNearestTarget()

    if model and root and humanoid and humanoid.Health > 0 then
        State.TargetModel = model
        State.TargetRoot = root
        State.TargetHumanoid = humanoid
        State.RoomClearTimer = 0
        State.CurrentAction = "Farming"
        return
    end

    State.TargetModel = nil
    State.TargetRoot = nil
    State.TargetHumanoid = nil

    if State.RoomClearTimer < Config.RoomClearDelay then
        State.CurrentAction = "Clearing"
        return
    end

    rebuildPortalCandidates()

    local exitObject, score, exitType = findBestExit()

    if not exitObject or not exitObject.Parent then
        State.CurrentAction = "Searching Exit"
        State.StageBusy = false
        State.StageBusyTimer = 0
        return
    end

    State.StageBusy = true
    State.StageBusyTimer = 0
    State.Portal = exitObject
    State.PortalScore = score

    local ok, err = pcall(function()
        if exitType == "door" then
            State.CurrentAction = "Moving To Door"

            local opened = interactWithDoor(exitObject)

            if opened then
                task.wait(Config.DoorOpenWait)

                rebuildPortalCandidates()

                local newPortal, newScore = findBestPortalOnly()

                if newPortal and newPortal.Parent then
                    State.Portal = newPortal
                    State.PortalScore = newScore
                    State.CurrentAction = "Moving To Portal"

                    local approach =
                        newPortal.Position
                        - newPortal.CFrame.LookVector * 6

                    travelToPosition(approach, newPortal.Position)
                    task.wait(0.15)
                    travelToPosition(
                        newPortal.Position,
                        newPortal.Position + newPortal.CFrame.LookVector
                    )
                else
                    State.CurrentAction = "Entering Door"

                    local approach =
                        exitObject.Position
                        - exitObject.CFrame.LookVector * 4

                    travelToPosition(approach, exitObject.Position)
                    task.wait(0.15)
                    travelToPosition(
                        exitObject.Position,
                        exitObject.Position + exitObject.CFrame.LookVector
                    )
                end
            end
        else
            State.CurrentAction = "Moving To Portal"

            local approach =
                exitObject.Position
                - exitObject.CFrame.LookVector * 8

            travelToPosition(approach, exitObject.Position)
            task.wait(0.15)

            State.CurrentAction = "Entering Portal"

            travelToPosition(
                exitObject.Position,
                exitObject.Position + exitObject.CFrame.LookVector
            )
        end
    end)

    if not ok and Config.Debug then
        warn("[IronSoul] exit transition error:", err)
    end

    State.StageBusy = false
    State.StageBusyTimer = 0
    State.StageCooldown = true
    State.RoomClearTimer = 0

    task.delay(Config.ExitRetryDelay, function()
        if not State.Unloaded then
            State.StageCooldown = false
        end
    end)
end


rebuildPortalCandidates()

local SkillCooldownConfig = {
    Q = 0.70,
    G = 0.70,
    E = 0.70,
    R = 1.50,
}

local function useSkills()
    if not Config.AutoFarm
        or not Config.AutoSkill
        or not targetIsValid()
        or State.StageBusy then
        return
    end

    local now = os.clock()

    for _, key in ipairs({"E", "R"}) do
        if now >= State.SkillCooldowns[key] then
            pressKey(key)
            State.SkillCooldowns[key] = now + SkillCooldownConfig[key]
            task.wait(0.15)
        end
    end
end


local orbitRayParams = RaycastParams.new()
orbitRayParams.FilterType = Enum.RaycastFilterType.Exclude

local function getGroundY(position)
    if not State.TargetModel or not State.Character then
        return nil
    end

    orbitRayParams.FilterDescendantsInstances = {
        State.TargetModel,
        State.Character,
    }

    local rayOrigin = position + Vector3.new(0, 80, 0)
    local rayDirection = Vector3.new(0, -400, 0)

    local result = workspace:Raycast(
        rayOrigin,
        rayDirection,
        orbitRayParams
    )

    if result then
        return result.Position.Y
    end

    return nil
end

local function setUndergroundPhysics(enabled)
    if not State.Humanoid or not State.Humanoid.Parent then
        return
    end

    if State.UndergroundPhysics == enabled then
        return
    end

    pcall(function()
        if enabled then
            State.Humanoid.AutoRotate = false
            State.Humanoid.PlatformStand = true
            State.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        else
            State.Humanoid.PlatformStand = false
            State.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            State.Humanoid.AutoRotate = true
        end
    end)

    State.UndergroundPhysics = enabled
end

local function getDesiredCombatCFrame()
    if not Config.AutoFarm
        or State.StageBusy
        or not State.Root
        or not State.TargetRoot
        or not State.Humanoid
        or not targetIsValid() then
        return nil
    end

    local targetPosition = State.TargetRoot.Position
    local radius = Config.OrbitRadius

    local verticalOffset = Config.UndergroundMode
        and math.max(0, tonumber(Config.UndergroundHeight) or 0)
        or math.max(0, tonumber(Config.AboveHeight) or 0)

    State.OrbitAngle += (1 / 60) * Config.OrbitSpeed

    local x = math.sin(State.OrbitAngle) * radius
    local z = math.cos(State.OrbitAngle) * radius

    local y
    local tilt

    if Config.UndergroundMode then
        setUndergroundPhysics(true)
        y = targetPosition.Y - verticalOffset
        tilt = 90
    else
        setUndergroundPhysics(false)
        y = targetPosition.Y + verticalOffset
        tilt = -90
    end

    return CFrame.new(
        targetPosition.X + x,
        y