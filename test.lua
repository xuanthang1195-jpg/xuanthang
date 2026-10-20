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
    SkillTimer = 0,
    MovementTimer = 0,
    AttackTimer = 0,
    StatusTimer = 0,
    VerticalLockTimer = 0,
    SkillCooldowns = {
        Q = 0,
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
                "AutoProgressStage", "OrbitRadius", "OrbitSpeed",
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

    -- Cache miss: use the spatial fallback, but throttle it so an empty
    -- room does not cause repeated 600-stud spatial scans.
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

    -- A portal is preferred if both the part and one of its containers have
    -- exit-like names.
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
        -- Doors/gates are valid exits, but should only be used when no
        -- active portal is already available.
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

        -- Some doors need another F after their opening animation.
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

    -- First priority is always an alive enemy. Only when the search returns
    -- nothing do we begin the room-clear timer.
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

    -- No enemy: immediately refresh the exit list and go to the closest
    -- valid portal/door. This is the old behavior the user wants restored.
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

                -- The portal inside the door may not exist until the door has
                -- opened, so rebuild after the interaction.
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
                    -- If the door itself is the transition, enter the door.
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

            -- Direct portal travel. No arbitrary 220-stud limit and no score
            -- cutoff here; findBestExit already selected the best candidate
            -- inside ExitSearchRadius.
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

    for _, key in ipairs({"E", "Q", "R"}) do
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

    -- Do not force the Humanoid into Physics every heartbeat. Repeated
    -- ChangeState/PlatformStand calls can fight Roblox's character solver and
    -- are one of the reasons the vertical offset can appear to snap back.
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

    -- Read the live Config value on every combat-position update. The height
    -- boxes therefore affect the next lock immediately instead of waiting for
    -- settings reloads or another scan.
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
        y,
        targetPosition.Z + z
    ) * CFrame.Angles(math.rad(tilt), 0, 0)
end

local function lockCombatPosition()
    local desiredCFrame = getDesiredCombatCFrame()

    if not desiredCFrame or not State.Character or not State.Root then
        return
    end

    -- Keep the character assembly exactly at the desired position.
    pcall(function()
        State.Character:PivotTo(desiredCFrame)
    end)

    pcall(function()
        State.Root.CFrame = desiredCFrame
        State.Root.AssemblyLinearVelocity = Vector3.zero
        State.Root.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function updateOrbit(dt)
    if not Config.AutoFarm
        or State.StageBusy
        or not State.Root
        or not State.TargetRoot
        or not targetIsValid() then
        return
    end

    lockCombatPosition()
end

local function updateKillAura()
    if not Config.AutoFarm
        or not Config.AutoAttack
        or State.StageBusy
        or not State.Root
        or not targetIsValid() then
        return
    end

    local offset = State.Root.Position - State.TargetRoot.Position
    local radius = Config.KillAuraRadius

    if offset:Dot(offset) <= radius * radius then
        -- Activate the equipped weapon and send the primary click. Keeping
        -- both paths makes this work with tools that listen to either input.
        activateTool()

        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.zero)
        end)
    end
end

local function isRedAttackObject(object)
    if not object:IsA("BasePart") then
        return false
    end

    local color = object.Color
    local hue, saturation, value = Color3.toHSV(color)

    local redHue = hue < 0.055 or hue > 0.945
    return redHue and saturation > 0.55 and value > 0.35 and color.R > color.G * 1.35 and color.R > color.B * 1.35
end

local dangerOverlapParams = OverlapParams.new()
dangerOverlapParams.FilterType = Enum.RaycastFilterType.Exclude

local function findNearbyRedAttack()
    State.Stats.DangerScans += 1

    if not Config.AutoAvoid or not State.Root then
        return nil
    end

    dangerOverlapParams.FilterDescendantsInstances = {
        State.Character
    }

    local origin = State.Root.Position
    local dangerRadius = 35
    local nearest
    local nearestDistanceSquared = dangerRadius * dangerRadius

    local ok, parts = pcall(function()
        return workspace:GetPartBoundsInRadius(origin, dangerRadius, dangerOverlapParams)
    end)

    if not ok or not parts then
        return nil
    end

    for _, object in ipairs(parts) do
        if isRedAttackObject(object) then
            local offset = origin - object.Position
            local distanceSquared = offset:Dot(offset)

            if distanceSquared < nearestDistanceSquared then
                nearestDistanceSquared = distanceSquared
                nearest = object
            end
        end
    end

    return nearest
end

local function updateAutoAvoid(dt)
    if not Config.AutoAvoid
        or State.StageBusy
        or State.EmergencyBusy
        or not State.Root
        or not State.Humanoid then
        State.DangerPart = nil
        State.DangerDistance = math.huge
        return
    end

    State.DangerTimer += dt

    local scanInterval = Config.PerformanceMode and 0.30 or 0.12

    if State.DangerTimer >= scanInterval then
        State.DangerTimer = 0
        State.DangerPart = findNearbyRedAttack()
    end

    local danger = State.DangerPart

    if not danger or not danger.Parent then
        State.DangerPart = nil
        State.DangerDistance = math.huge

        if Config.AutoFarm then
            State.CurrentAction = "Farming"
        end

        return
    end

    local toDanger = danger.Position - State.Root.Position
    local horizontal = Vector3.new(toDanger.X, 0, toDanger.Z)
    State.DangerDistance = horizontal.Magnitude

    local predicted = danger.Position + danger.AssemblyLinearVelocity * 0.20
    local away = State.Root.Position - predicted
    away = Vector3.new(away.X, 0, away.Z)

    if away.Magnitude < 0.05 then
        away = Vector3.new(1, 0, 0)
    else
        away = away.Unit
    end

    local safeDistance = Config.SafeMode and 16 or 12
    State.CurrentAction = "Avoiding Attack"

    State.Humanoid:MoveTo(State.Root.Position + away * safeDistance)

    if Config.EmergencyEscape and State.DangerDistance < 6 then
        emergencyEscape("Emergency Escape")
    end
end

local function getAccentColor()
    local c = Config.AccentColor or {92, 82, 145}
    return Color3.fromRGB(
        math.clamp(tonumber(c[1]) or 92, 0, 255),
        math.clamp(tonumber(c[2]) or 82, 0, 255),
        math.clamp(tonumber(c[3]) or 145, 0, 255)
    )
end

local function getAccentSoft()
    local c = getAccentColor()
    return c:Lerp(Color3.fromRGB(34, 34, 42), 0.48)
end

local function setAccentColor(color)
    Config.AccentColor = {
        math.floor(color.R * 255 + 0.5),
        math.floor(color.G * 255 + 0.5),
        math.floor(color.B * 255 + 0.5),
    }
    saveSettings()
end


local oldGui = playerGui:FindFirstChild("morgue")

if oldGui then
    oldGui:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "morgue"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 100
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = playerGui

-- ================================================================
-- PREMIUM UI ONLY
-- The farming / combat / portal mechanics above are intentionally untouched.
-- ================================================================
local WINDOW_WIDTH = 340
local WINDOW_HEIGHT = 650
local BORDER = 3

local outline = Instance.new("Frame")
outline.Name = "OutlineFrame"
outline.Size = UDim2.fromOffset(WINDOW_WIDTH + BORDER * 2, WINDOW_HEIGHT + BORDER * 2)
outline.BackgroundColor3 = getAccentColor():Lerp(Color3.fromRGB(10, 10, 14), 0.42)
outline.BorderSizePixel = 0
outline.Parent = ScreenGui

local function positionWindowLeftOfCenter()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
    local fullWidth = WINDOW_WIDTH + BORDER * 2
    local fullHeight = WINDOW_HEIGHT + BORDER * 2
    local desiredX = viewport.X * 0.5 - fullWidth - 26
    local desiredY = viewport.Y * 0.5 - fullHeight * 0.5
    outline.Position = UDim2.fromOffset(
        math.clamp(desiredX, 8, math.max(8, viewport.X - fullWidth - 8)),
        math.clamp(desiredY, 8, math.max(8, viewport.Y - fullHeight - 8))
    )
end

positionWindowLeftOfCenter()

local outlineCorner = Instance.new("UICorner")
outlineCorner.CornerRadius = UDim.new(0, 11)
outlineCorner.Parent = outline

local outlineStroke = Instance.new("UIStroke")
outlineStroke.Color = getAccentColor()
outlineStroke.Transparency = 0.30
outlineStroke.Thickness = 1
outlineStroke.Parent = outline

local main = Instance.new("Frame")
main.Size = UDim2.new(1, -BORDER * 2, 1, -BORDER * 2)
main.Position = UDim2.fromOffset(BORDER, BORDER)
main.BackgroundColor3 = Color3.fromRGB(12, 12, 17)
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = outline

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = main

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 58)
header.BackgroundColor3 = Color3.fromRGB(15, 15, 21)
header.BorderSizePixel = 0
header.Parent = main

local headerGradient = Instance.new("UIGradient")
headerGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(27, 23, 35)),
    ColorSequenceKeypoint.new(0.55, Color3.fromRGB(16, 16, 22)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(11, 12, 16)),
})
headerGradient.Rotation = 90
headerGradient.Parent = header

local headerAccent = Instance.new("Frame")
headerAccent.Size = UDim2.new(1, 0, 0, 2)
headerAccent.Position = UDim2.fromOffset(0, 56)
headerAccent.BackgroundColor3 = getAccentColor()
headerAccent.BorderSizePixel = 0
headerAccent.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -135, 0, 24)
title.Position = UDim2.fromOffset(14, 7)
title.BackgroundTransparency = 1
title.Text = "Iron forge"
title.TextColor3 = Color3.fromRGB(248, 248, 252)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -135, 0, 17)
subtitle.Position = UDim2.fromOffset(14, 30)
subtitle.BackgroundTransparency = 1
subtitle.Text = "AUTO-FARM  •  CONTROL PANEL"
subtitle.TextColor3 = Color3.fromRGB(130, 130, 146)
subtitle.Font = Enum.Font.GothamMedium
subtitle.TextSize = 8
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = header

local headerState = Instance.new("TextLabel")
headerState.Size = UDim2.fromOffset(64, 20)
headerState.Position = UDim2.new(1, -160, 0, 8)
headerState.BackgroundColor3 = Color3.fromRGB(27, 27, 35)
headerState.BorderSizePixel = 0
headerState.Text = "IDLE"
headerState.TextColor3 = Color3.fromRGB(155, 155, 168)
headerState.Font = Enum.Font.GothamBold
headerState.TextSize = 8
headerState.TextXAlignment = Enum.TextXAlignment.Center
headerState.Parent = header

local headerStateCorner = Instance.new("UICorner")
headerStateCorner.CornerRadius = UDim.new(1, 0)
headerStateCorner.Parent = headerState

-- Small palette control instead of the previous large APPEAR button.
local themeButton = Instance.new("TextButton")
themeButton.Name = "AppearanceButton"
themeButton.Size = UDim2.fromOffset(26, 26)
themeButton.Position = UDim2.new(1, -91, 0, 6)
themeButton.BackgroundColor3 = Color3.fromRGB(27, 27, 35)
themeButton.BorderSizePixel = 0
themeButton.Text = "◆"
themeButton.TextColor3 = getAccentColor()
themeButton.Font = Enum.Font.GothamBold
themeButton.TextSize = 11
themeButton.AutoButtonColor = false
themeButton.Parent = header

local themeCorner = Instance.new("UICorner")
themeCorner.CornerRadius = UDim.new(1, 0)
themeCorner.Parent = themeButton

local themeStroke = Instance.new("UIStroke")
themeStroke.Color = getAccentColor()
themeStroke.Transparency = 0.20
themeStroke.Thickness = 1
themeStroke.Parent = themeButton

local minimize = Instance.new("TextButton")
minimize.Size = UDim2.fromOffset(26, 26)
minimize.Position = UDim2.new(1, -61, 0, 6)
minimize.BackgroundColor3 = Color3.fromRGB(31, 31, 40)
minimize.BorderSizePixel = 0
minimize.Text = "−"
minimize.TextColor3 = Color3.fromRGB(224, 224, 232)
minimize.Font = Enum.Font.GothamBold
minimize.TextSize = 16
minimize.AutoButtonColor = false
minimize.Parent = header

local minimizeCorner = Instance.new("UICorner")
minimizeCorner.CornerRadius = UDim.new(0, 7)
minimizeCorner.Parent = minimize

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(26, 26)
closeButton.Position = UDim2.new(1, -31, 0, 6)
closeButton.BackgroundColor3 = Color3.fromRGB(50, 30, 37)
closeButton.BorderSizePixel = 0
closeButton.Text = "×"
closeButton.TextColor3 = Color3.fromRGB(255, 190, 198)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 17
closeButton.AutoButtonColor = false
closeButton.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 7)
closeCorner.Parent = closeButton

local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, 0, 0, 1)
divider.Position = UDim2.fromOffset(0, 58)
divider.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
divider.BorderSizePixel = 0
divider.Parent = main

local content = Instance.new("ScrollingFrame")
content.Name = "ContentFrame"
content.Size = UDim2.new(1, 0, 1, -59)
content.Position = UDim2.fromOffset(0, 59)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ClipsDescendants = true
content.ScrollBarThickness = 3
content.ScrollBarImageColor3 = getAccentColor()
content.ScrollBarImageTransparency = 0.15
content.ScrollingDirection = Enum.ScrollingDirection.Y
content.CanvasSize = UDim2.fromOffset(0, 820)
content.Active = true
content.ZIndex = 5
content.Parent = main

local function createSection(y, labelText, hintText)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -28, 0, 18)
    label.Position = UDim2.fromOffset(14, y)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = getAccentColor()
    label.Font = Enum.Font.GothamBold
    label.TextSize = 9
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = content

    if hintText then
        local hint = Instance.new("TextLabel")
        hint.Size = UDim2.new(1, -115, 0, 18)
        hint.Position = UDim2.new(0, 112, 0, y)
        hint.BackgroundTransparency = 1
        hint.Text = hintText
        hint.TextColor3 = Color3.fromRGB(90, 90, 105)
        hint.Font = Enum.Font.Gotham
        hint.TextSize = 8
        hint.TextXAlignment = Enum.TextXAlignment.Right
        hint.Parent = content
    end
end

local function createButton(text, y, height)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -28, 0, height or 38)
    button.Position = UDim2.fromOffset(14, y)
    button.BackgroundColor3 = Color3.fromRGB(25, 25, 33)
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.fromRGB(226, 226, 235)
    button.Font = Enum.Font.GothamMedium
    button.TextSize = 11
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.AutoButtonColor = false
    button.Parent = content

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 14)
    pad.PaddingRight = UDim.new(0, 14)
    pad.Parent = button

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(43, 43, 54)
    stroke.Transparency = 0.25
    stroke.Thickness = 1
    stroke.Parent = button

    local scale = Instance.new("UIScale")
    scale.Scale = 1
    scale.Parent = button

    connect(button.MouseEnter, function()
        if State.Unloaded then return end
        TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1.018}):Play()
        TweenService:Create(button, TweenInfo.new(0.12), {BackgroundColor3 = getAccentSoft()}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.12), {Color = getAccentColor(), Transparency = 0.05}):Play()
    end)

    connect(button.MouseLeave, function()
        if State.Unloaded then return end
        TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
        local active = button:GetAttribute("Active") == true
        TweenService:Create(button, TweenInfo.new(0.14), {BackgroundColor3 = active and getAccentColor() or Color3.fromRGB(25, 25, 33)}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.14), {Color = active and getAccentColor() or Color3.fromRGB(43, 43, 54), Transparency = active and 0.02 or 0.25}):Play()
    end)

    connect(button.MouseButton1Down, function()
        TweenService:Create(scale, TweenInfo.new(0.06), {Scale = 0.97}):Play()
    end)

    connect(button.MouseButton1Up, function()
        TweenService:Create(scale, TweenInfo.new(0.10), {Scale = 1.018}):Play()
    end)

    button:SetAttribute("BaseColor", true)
    return button, stroke
end

local function createInput(labelText, placeholder, y)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -28, 0, 14)
    label.Position = UDim2.fromOffset(14, y)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(135, 135, 151)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 9
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = content

    local input = Instance.new("TextBox")
    input.Size = UDim2.new(1, -28, 0, 31)
    input.Position = UDim2.fromOffset(14, y + 17)
    input.BackgroundColor3 = Color3.fromRGB(18, 18, 23)
    input.BorderSizePixel = 0
    input.PlaceholderText = placeholder
    input.PlaceholderColor3 = Color3.fromRGB(75, 75, 90)
    input.TextColor3 = Color3.fromRGB(245, 245, 250)
    input.Font = Enum.Font.GothamMedium
    input.TextSize = 12
    input.TextXAlignment = Enum.TextXAlignment.Center
    input.ClearTextOnFocus = false
    input.Parent = content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = input

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(43, 43, 54)
    stroke.Transparency = 0.20
    stroke.Thickness = 1
    stroke.Parent = input

    connect(input.Focused, function()
        TweenService:Create(stroke, TweenInfo.new(0.16), {Color = getAccentColor(), Transparency = 0}):Play()
        TweenService:Create(input, TweenInfo.new(0.16), {BackgroundColor3 = getAccentSoft()}):Play()
    end)

    connect(input.FocusLost, function()
        TweenService:Create(stroke, TweenInfo.new(0.16), {Color = Color3.fromRGB(43, 43, 54), Transparency = 0.20}):Play()
        TweenService:Create(input, TweenInfo.new(0.16), {BackgroundColor3 = Color3.fromRGB(18, 18, 23)}):Play()
    end)

    return input
end

createSection(8, "FARMING", "CORE")
local toggleButton = createButton("AUTO FARM                         OFF", 30, 40)
local modeButton = createButton("POSITION                         UNDER", 76, 40)

createSection(126, "COMBAT", "TARGETING")
local autoAttackButton = createButton("AUTO ATTACK                    ON", 148, 40)
local autoAvoidButton = createButton("AUTO AVOID                     OFF", 194, 40)
local emergencyButton = createButton("EMERGENCY ESCAPE          ON", 240, 40)

createSection(290, "TRAVEL", "STAGE")
local teleportPortalButton = createButton("NEAREST EXIT                  READY", 312, 40)

createSection(368, "PERFORMANCE & SAFETY", "SYSTEM")
local performanceButton = createButton("PERFORMANCE                   OFF", 390, 40)
local safeModeButton = createButton("SAFE MODE                       ON", 436, 40)

createSection(486, "VERTICAL CONTROL", "HEIGHT")
local aboveInput = createInput("UPPER HEIGHT", "default: 8", 508)
aboveInput.Text = tostring(Config.AboveHeight)
local undergroundInput = createInput("UNDER HEIGHT", "default: 8", 560)
undergroundInput.Text = tostring(Config.UndergroundHeight)

createSection(612, "DEBUG", "DIAGNOSTICS")
local debugButton = createButton("DEBUG MONITOR                OFF", 634, 40)

local statusPanel = Instance.new("Frame")
statusPanel.Size = UDim2.new(1, -28, 0, 120)
statusPanel.Position = UDim2.fromOffset(14, 686)
statusPanel.BackgroundColor3 = Color3.fromRGB(17, 17, 23)
statusPanel.BorderSizePixel = 0
statusPanel.Parent = content

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 9)
statusCorner.Parent = statusPanel

local statusStroke = Instance.new("UIStroke")
statusStroke.Color = getAccentColor()
statusStroke.Transparency = 0.65
statusStroke.Thickness = 1
statusStroke.Parent = statusPanel

local statusTitle = Instance.new("TextLabel")
statusTitle.Size = UDim2.new(1, -20, 0, 20)
statusTitle.Position = UDim2.fromOffset(10, 8)
statusTitle.BackgroundTransparency = 1
statusTitle.Text = "LIVE STATUS"
statusTitle.TextColor3 = getAccentColor()
statusTitle.Font = Enum.Font.GothamBold
statusTitle.TextSize = 9
statusTitle.TextXAlignment = Enum.TextXAlignment.Left
statusTitle.Parent = statusPanel

local statusText = Instance.new("TextLabel")
statusText.Size = UDim2.new(1, -20, 1, -34)
statusText.Position = UDim2.fromOffset(10, 29)
statusText.BackgroundTransparency = 1
statusText.Text = "State    Idle\nTarget   -\nDistance -\nHP       -\nDanger   -"
statusText.TextColor3 = Color3.fromRGB(203, 203, 214)
statusText.Font = Enum.Font.Code
statusText.TextSize = 9
statusText.TextXAlignment = Enum.TextXAlignment.Left
statusText.TextYAlignment = Enum.TextYAlignment.Top
statusText.Parent = statusPanel

local debugPanel = Instance.new("Frame")
debugPanel.Size = UDim2.new(1, -28, 0, 82)
debugPanel.Position = UDim2.fromOffset(14, 816)
debugPanel.BackgroundColor3 = Color3.fromRGB(14, 14, 19)
debugPanel.BorderSizePixel = 0
debugPanel.Parent = content

local debugCorner = Instance.new("UICorner")
debugCorner.CornerRadius = UDim.new(0, 9)
debugCorner.Parent = debugPanel

local debugStroke = Instance.new("UIStroke")
debugStroke.Color = Color3.fromRGB(50, 50, 62)
debugStroke.Transparency = 0.25
debugStroke.Thickness = 1
debugStroke.Parent = debugPanel

local debugTitle = Instance.new("TextLabel")
debugTitle.Size = UDim2.new(1, -20, 0, 18)
debugTitle.Position = UDim2.fromOffset(10, 7)
debugTitle.BackgroundTransparency = 1
debugTitle.Text = "DEBUG CONSOLE"
debugTitle.TextColor3 = Color3.fromRGB(155, 155, 170)
debugTitle.Font = Enum.Font.GothamBold
debugTitle.TextSize = 8
debugTitle.TextXAlignment = Enum.TextXAlignment.Left
debugTitle.Parent = debugPanel

local debugPanelText = Instance.new("TextLabel")
debugPanelText.Size = UDim2.new(1, -20, 1, -28)
debugPanelText.Position = UDim2.fromOffset(10, 25)
debugPanelText.BackgroundTransparency = 1
debugPanelText.Text = "Debug is disabled."
debugPanelText.TextColor3 = Color3.fromRGB(110, 110, 125)
debugPanelText.Font = Enum.Font.Code
debugPanelText.TextSize = 8
debugPanelText.TextXAlignment = Enum.TextXAlignment.Left
debugPanelText.TextYAlignment = Enum.TextYAlignment.Top
debugPanelText.Parent = debugPanel

content.CanvasSize = UDim2.fromOffset(0, 910)

-- ================================================================
-- APPEARANCE WINDOW
-- ================================================================
local CUSTOM_WIDTH = 360
local CUSTOM_HEIGHT = 445

local customOutline = Instance.new("Frame")
customOutline.Name = "CustomUIWindow"
customOutline.Size = UDim2.fromOffset(CUSTOM_WIDTH + BORDER * 2, CUSTOM_HEIGHT + BORDER * 2)
customOutline.Position = UDim2.new(0.5, 120, 0.5, -CUSTOM_HEIGHT / 2)
customOutline.BackgroundColor3 = getAccentColor():Lerp(Color3.fromRGB(10, 10, 14), 0.38)
customOutline.BorderSizePixel = 0
customOutline.Visible = false
customOutline.ZIndex = 30
customOutline.Parent = ScreenGui

local customCorner = Instance.new("UICorner")
customCorner.CornerRadius = UDim.new(0, 11)
customCorner.Parent = customOutline

local customStroke = Instance.new("UIStroke")
customStroke.Color = getAccentColor()
customStroke.Transparency = 0.28
customStroke.Thickness = 1
customStroke.Parent = customOutline

local customMain = Instance.new("Frame")
customMain.Size = UDim2.new(1, -BORDER * 2, 1, -BORDER * 2)
customMain.Position = UDim2.fromOffset(BORDER, BORDER)
customMain.BackgroundColor3 = Color3.fromRGB(12, 12, 17)
customMain.BorderSizePixel = 0
customMain.ClipsDescendants = true
customMain.ZIndex = 31
customMain.Parent = customOutline

local customMainCorner = Instance.new("UICorner")
customMainCorner.CornerRadius = UDim.new(0, 8)
customMainCorner.Parent = customMain

local customHeader = Instance.new("Frame")
customHeader.Size = UDim2.new(1, 0, 0, 58)
customHeader.BackgroundColor3 = Color3.fromRGB(15, 15, 21)
customHeader.BorderSizePixel = 0
customHeader.ZIndex = 32
customHeader.Parent = customMain

local customHeaderGradient = Instance.new("UIGradient")
customHeaderGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 24, 36)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 13, 17)),
})
customHeaderGradient.Rotation = 90
customHeaderGradient.Parent = customHeader

local customTitle = Instance.new("TextLabel")
customTitle.Size = UDim2.new(1, -70, 0, 24)
customTitle.Position = UDim2.fromOffset(14, 8)
customTitle.BackgroundTransparency = 1
customTitle.Text = "Appearance"
customTitle.TextColor3 = Color3.fromRGB(245, 245, 250)
customTitle.Font = Enum.Font.GothamBold
customTitle.TextSize = 14
customTitle.TextXAlignment = Enum.TextXAlignment.Left
customTitle.ZIndex = 33
customTitle.Parent = customHeader

local customSubtitle = Instance.new("TextLabel")
customSubtitle.Size = UDim2.new(1, -70, 0, 16)
customSubtitle.Position = UDim2.fromOffset(14, 32)
customSubtitle.BackgroundTransparency = 1
customSubtitle.Text = "ACCENT  •  BRIGHT COLOR GRID"
customSubtitle.TextColor3 = Color3.fromRGB(125, 125, 142)
customSubtitle.Font = Enum.Font.GothamMedium
customSubtitle.TextSize = 8
customSubtitle.TextXAlignment = Enum.TextXAlignment.Left
customSubtitle.ZIndex = 33
customSubtitle.Parent = customHeader

local customClose = Instance.new("TextButton")
customClose.Size = UDim2.fromOffset(28, 28)
customClose.Position = UDim2.new(1, -39, 0, 8)
customClose.BackgroundColor3 = Color3.fromRGB(50, 30, 37)
customClose.BorderSizePixel = 0
customClose.Text = "×"
customClose.TextColor3 = Color3.fromRGB(255, 190, 198)
customClose.Font = Enum.Font.GothamBold
customClose.TextSize = 17
customClose.AutoButtonColor = false
customClose.ZIndex = 33
customClose.Parent = customHeader

local customCloseCorner = Instance.new("UICorner")
customCloseCorner.CornerRadius = UDim.new(0, 7)
customCloseCorner.Parent = customClose

local customContent = Instance.new("ScrollingFrame")
customContent.Name = "AppearanceContent"
customContent.Size = UDim2.new(1, 0, 1, -58)
customContent.Position = UDim2.fromOffset(0, 58)
customContent.BackgroundTransparency = 1
customContent.BorderSizePixel = 0
customContent.ScrollBarThickness = 4
customContent.ScrollBarImageColor3 = getAccentColor()
customContent.ScrollBarImageTransparency = 0.10
customContent.CanvasSize = UDim2.fromOffset(0, 440)
customContent.ZIndex = 32
customContent.Parent = customMain

local palettePanel = Instance.new("Frame")
palettePanel.Name = "AccentPalette"
palettePanel.Size = UDim2.new(1, -28, 0, 410)
palettePanel.Position = UDim2.fromOffset(14, 14)
palettePanel.BackgroundColor3 = Color3.fromRGB(17, 17, 23)
palettePanel.BorderSizePixel = 0
palettePanel.ZIndex = 33
palettePanel.Parent = customContent

local paletteCorner = Instance.new("UICorner")
paletteCorner.CornerRadius = UDim.new(0, 10)
paletteCorner.Parent = palettePanel

local paletteStroke = Instance.new("UIStroke")
paletteStroke.Color = getAccentColor()
paletteStroke.Thickness = 1
paletteStroke.Transparency = 0.38
paletteStroke.Parent = palettePanel

local paletteTitle = Instance.new("TextLabel")
paletteTitle.Size = UDim2.new(1, -20, 0, 22)
paletteTitle.Position = UDim2.fromOffset(10, 9)
paletteTitle.BackgroundTransparency = 1
paletteTitle.Text = "ACCENT COLOR"
paletteTitle.TextColor3 = Color3.fromRGB(235, 235, 242)
paletteTitle.Font = Enum.Font.GothamBold
paletteTitle.TextSize = 10
paletteTitle.TextXAlignment = Enum.TextXAlignment.Left
paletteTitle.ZIndex = 34
paletteTitle.Parent = palettePanel

local paletteHint = Instance.new("TextLabel")
paletteHint.Size = UDim2.new(1, -20, 0, 18)
paletteHint.Position = UDim2.fromOffset(10, 31)
paletteHint.BackgroundTransparency = 1
paletteHint.Text = "Choose the highlight used by active controls, borders and focus states."
paletteHint.TextColor3 = Color3.fromRGB(130, 130, 145)
paletteHint.Font = Enum.Font.Gotham
paletteHint.TextSize = 8
paletteHint.TextXAlignment = Enum.TextXAlignment.Left
paletteHint.ZIndex = 34
paletteHint.Parent = palettePanel

local paletteColors = {
    Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 120, 55), Color3.fromRGB(255, 185, 45),
    Color3.fromRGB(255, 235, 70), Color3.fromRGB(155, 235, 70), Color3.fromRGB(65, 220, 105),
    Color3.fromRGB(40, 235, 170), Color3.fromRGB(35, 220, 235), Color3.fromRGB(45, 165, 255),
    Color3.fromRGB(70, 105, 255), Color3.fromRGB(115, 75, 255), Color3.fromRGB(165, 70, 255),
    Color3.fromRGB(220, 70, 255), Color3.fromRGB(255, 70, 205), Color3.fromRGB(255, 70, 145),
    Color3.fromRGB(255, 105, 125), Color3.fromRGB(235, 95, 75), Color3.fromRGB(205, 145, 65),
    Color3.fromRGB(165, 175, 75), Color3.fromRGB(90, 190, 90), Color3.fromRGB(65, 170, 150),
    Color3.fromRGB(70, 145, 205), Color3.fromRGB(90, 100, 205), Color3.fromRGB(125, 105, 190),
    Color3.fromRGB(175, 105, 205), Color3.fromRGB(215, 100, 170), Color3.fromRGB(245, 245, 250),
    Color3.fromRGB(185, 190, 205), Color3.fromRGB(125, 130, 145), Color3.fromRGB(75, 80, 95),
}

local paletteButtons = {}
local GRID_COLUMNS = 6
local SWATCH_SIZE = 44
local SWATCH_GAP = 8

for index, color in ipairs(paletteColors) do
    local swatch = Instance.new("TextButton")
    swatch.Name = "Color_" .. index
    swatch.Size = UDim2.fromOffset(SWATCH_SIZE, SWATCH_SIZE)
    local column = (index - 1) % GRID_COLUMNS
    local row = math.floor((index - 1) / GRID_COLUMNS)
    swatch.Position = UDim2.fromOffset(12 + column * (SWATCH_SIZE + SWATCH_GAP), 58 + row * (SWATCH_SIZE + SWATCH_GAP))
    swatch.BackgroundColor3 = color
    swatch.BorderSizePixel = 0
    swatch.Text = ""
    swatch.AutoButtonColor = false
    swatch.ZIndex = 34
    swatch.Parent = palettePanel

    local swatchCorner = Instance.new("UICorner")
    swatchCorner.CornerRadius = UDim.new(0, 9)
    swatchCorner.Parent = swatch

    local swatchStroke = Instance.new("UIStroke")
    swatchStroke.Color = Color3.fromRGB(255, 255, 255)
    swatchStroke.Transparency = 0.72
    swatchStroke.Thickness = 1
    swatchStroke.Parent = swatch

    local swatchScale = Instance.new("UIScale")
    swatchScale.Parent = swatch

    paletteButtons[index] = swatch
end

local selectedPreview = Instance.new("Frame")
selectedPreview.Size = UDim2.new(1, -24, 0, 44)
selectedPreview.Position = UDim2.fromOffset(12, 303)
selectedPreview.BackgroundColor3 = getAccentColor()
selectedPreview.BorderSizePixel = 0
selectedPreview.ZIndex = 34
selectedPreview.Parent = palettePanel

local selectedPreviewCorner = Instance.new("UICorner")
selectedPreviewCorner.CornerRadius = UDim.new(0, 9)
selectedPreviewCorner.Parent = selectedPreview

local selectedPreviewText = Instance.new("TextLabel")
selectedPreviewText.Size = UDim2.new(1, -18, 1, 0)
selectedPreviewText.Position = UDim2.fromOffset(9, 0)
selectedPreviewText.BackgroundTransparency = 1
selectedPreviewText.TextColor3 = Color3.fromRGB(255, 255, 255)
selectedPreviewText.Font = Enum.Font.GothamBold
selectedPreviewText.TextSize = 10
selectedPreviewText.TextXAlignment = Enum.TextXAlignment.Center
selectedPreviewText.ZIndex = 35
selectedPreviewText.Parent = selectedPreview

local customHint = Instance.new("TextLabel")
customHint.Size = UDim2.new(1, -24, 0, 24)
customHint.Position = UDim2.fromOffset(12, 360)
customHint.BackgroundTransparency = 1
customHint.Text = "Saved automatically  •  Hover a color to preview"
customHint.TextColor3 = Color3.fromRGB(105, 105, 120)
customHint.Font = Enum.Font.Gotham
customHint.TextSize = 8
customHint.TextXAlignment = Enum.TextXAlignment.Left
customHint.ZIndex = 34
customHint.Parent = palettePanel

customContent.CanvasSize = UDim2.fromOffset(0, 445)

local function setCustomWindowVisible(visible)
    if visible then
        customOutline.Visible = true
        customOutline.Size = UDim2.fromOffset(CUSTOM_WIDTH + BORDER * 2, CUSTOM_HEIGHT + BORDER * 2)
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
        local x = viewport.X * 0.5 + 30
        local y = viewport.Y * 0.5 - (CUSTOM_HEIGHT + BORDER * 2) * 0.5
        x = math.clamp(x, 8, math.max(8, viewport.X - CUSTOM_WIDTH - BORDER * 2 - 8))
        y = math.clamp(y, 8, math.max(8, viewport.Y - CUSTOM_HEIGHT - BORDER * 2 - 8))
        customOutline.Position = UDim2.fromOffset(x, y)
        customContent.CanvasPosition = Vector2.zero
        customOutline.BackgroundTransparency = 0
    else
        customOutline.Visible = false
    end
end

connect(customClose.MouseButton1Click, function()
    setCustomWindowVisible(false)
end)

local customDragging = false
local customDragStart = nil
local customStartPosition = nil

connect(customHeader.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        customDragging = true
        customDragStart = input.Position
        customStartPosition = customOutline.Position
    end
end)

connect(UserInputService.InputChanged, function(input)
    if not customDragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local delta = input.Position - customDragStart
    customOutline.Position = UDim2.new(
        customStartPosition.X.Scale,
        customStartPosition.X.Offset + delta.X,
        customStartPosition.Y.Scale,
        customStartPosition.Y.Offset + delta.Y
    )
end)

connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        customDragging = false
    end
end)

local collapsed = false
content.Visible = true

local function paintButton(button, stroke, label, value, active)
    button.Text = string.format("%-29s %s", label, value)
    button:SetAttribute("Active", active == true)
    local target = active and getAccentColor() or Color3.fromRGB(25, 25, 33)
    local targetStroke = active and getAccentColor() or Color3.fromRGB(43, 43, 54)
    TweenService:Create(button, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = target}):Play()
    TweenService:Create(stroke, TweenInfo.new(0.18), {Color = targetStroke, Transparency = active and 0.02 or 0.25}):Play()
    button.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(226, 226, 235)
end

local function setToggleVisual()
    paintButton(toggleButton, toggleButton:FindFirstChildOfClass("UIStroke"), "AUTO FARM", Config.AutoFarm and "ON" or "OFF", Config.AutoFarm)
    headerState.Text = Config.AutoFarm and "FARMING" or "IDLE"
    headerState.BackgroundColor3 = Config.AutoFarm and getAccentSoft() or Color3.fromRGB(27, 27, 35)
    headerState.TextColor3 = Config.AutoFarm and Color3.fromRGB(245, 245, 250) or Color3.fromRGB(155, 155, 168)
end

local function setModeVisual()
    paintButton(modeButton, modeButton:FindFirstChildOfClass("UIStroke"), "POSITION", Config.UndergroundMode and "UNDER" or "ABOVE", true)
end

local function setAutoAttackVisual()
    paintButton(autoAttackButton, autoAttackButton:FindFirstChildOfClass("UIStroke"), "AUTO ATTACK", Config.AutoAttack and "ON" or "OFF", Config.AutoAttack)
end

local function setDebugVisual()
    paintButton(debugButton, debugButton:FindFirstChildOfClass("UIStroke"), "DEBUG MONITOR", Config.Debug and "ON" or "OFF", Config.Debug)
    debugPanel.Visible = Config.Debug
end

local function setSafeModeVisual()
    paintButton(safeModeButton, safeModeButton:FindFirstChildOfClass("UIStroke"), "SAFE MODE", Config.SafeMode and "ON" or "OFF", Config.SafeMode)
end

local function setEmergencyVisual()
    paintButton(emergencyButton, emergencyButton:FindFirstChildOfClass("UIStroke"), "EMERGENCY ESCAPE", Config.EmergencyEscape and "ON" or "OFF", Config.EmergencyEscape)
end

local function setPerformanceVisual()
    paintButton(performanceButton, performanceButton:FindFirstChildOfClass("UIStroke"), "PERFORMANCE", Config.PerformanceMode and "ON" or "OFF", Config.PerformanceMode)
end

local function setAutoAvoidVisual()
    paintButton(autoAvoidButton, autoAvoidButton:FindFirstChildOfClass("UIStroke"), "AUTO AVOID", Config.AutoAvoid and "ON" or "OFF", Config.AutoAvoid)
end

local function colorToHex(color)
    return string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

local function setThemeVisual()
    local accent = getAccentColor()
    outline.BackgroundColor3 = accent:Lerp(Color3.fromRGB(10, 10, 14), 0.42)
    outlineStroke.Color = accent
    headerAccent.BackgroundColor3 = accent
    themeButton.TextColor3 = accent
    themeStroke.Color = accent
    content.ScrollBarImageColor3 = accent
    statusStroke.Color = accent
    statusTitle.TextColor3 = accent
    debugStroke.Color = accent
    customOutline.BackgroundColor3 = accent:Lerp(Color3.fromRGB(10, 10, 14), 0.38)
    customStroke.Color = accent
    paletteStroke.Color = accent
    customContent.ScrollBarImageColor3 = accent
    selectedPreview.BackgroundColor3 = accent
    selectedPreviewText.Text = "SELECTED ACCENT   " .. colorToHex(accent)
    for _, child in ipairs(content:GetChildren()) do
        if child:IsA("TextLabel") and child.Text ~= "" then
            if child.Text == "FARMING" or child.Text == "COMBAT" or child.Text == "TRAVEL" or child.Text == "PERFORMANCE & SAFETY" or child.Text == "VERTICAL CONTROL" or child.Text == "DEBUG" then
                child.TextColor3 = accent
            end
        end
    end
    setToggleVisual()
    setAutoAttackVisual()
    setAutoAvoidVisual()
    setModeVisual()
    setSafeModeVisual()
    setEmergencyVisual()
    setPerformanceVisual()
    setDebugVisual()
end

connect(themeButton.MouseEnter, function()
    TweenService:Create(themeButton, TweenInfo.new(0.12), {BackgroundColor3 = getAccentSoft()}):Play()
end)
connect(themeButton.MouseLeave, function()
    TweenService:Create(themeButton, TweenInfo.new(0.14), {BackgroundColor3 = Color3.fromRGB(27, 27, 35)}):Play()
end)
connect(themeButton.MouseButton1Click, function()
    setCustomWindowVisible(not customOutline.Visible)
end)

for index, swatch in ipairs(paletteButtons) do
    local color = paletteColors[index]
    local swatchStroke = swatch:FindFirstChildOfClass("UIStroke")
    local swatchScale = swatch:FindFirstChildOfClass("UIScale")
    connect(swatch.MouseEnter, function()
        TweenService:Create(swatchScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1.08}):Play()
        TweenService:Create(swatchStroke, TweenInfo.new(0.12), {Transparency = 0, Thickness = 2}):Play()
    end)
    connect(swatch.MouseLeave, function()
        TweenService:Create(swatchScale, TweenInfo.new(0.12), {Scale = 1}):Play()
        TweenService:Create(swatchStroke, TweenInfo.new(0.12), {Transparency = 0.72, Thickness = 1}):Play()
    end)
    connect(swatch.MouseButton1Click, function()
        setAccentColor(color)
        setThemeVisual()
    end)
end

local function applyHeightInput(input, underground)
    local value = tonumber(input.Text)
    if value == nil then return false end
    value = math.clamp(value, 0, 250)
    if underground then
        Config.UndergroundHeight = value
        _G.UnderGroundHeight = value
    else
        Config.AboveHeight = value
        _G.AboveHeight = value
    end
    if Config.AutoFarm and targetIsValid() then
        lockCombatPosition()
    end
    saveSettings()
    return true
end

connect(aboveInput.FocusLost, function()
    if not applyHeightInput(aboveInput, false) then
        aboveInput.Text = tostring(Config.AboveHeight)
    else
        aboveInput.Text = tostring(Config.AboveHeight)
    end
end)

connect(undergroundInput.FocusLost, function()
    if not applyHeightInput(undergroundInput, true) then
        undergroundInput.Text = tostring(Config.UndergroundHeight)
    else
        undergroundInput.Text = tostring(Config.UndergroundHeight)
    end
end)

connect(aboveInput:GetPropertyChangedSignal("Text"), function()
    local value = tonumber(aboveInput.Text)
    if value then
        Config.AboveHeight = math.clamp(value, 0, 250)
        _G.AboveHeight = Config.AboveHeight
        if Config.AutoFarm and targetIsValid() and not aboveInput:IsFocused() then lockCombatPosition() end
    end
end)

connect(undergroundInput:GetPropertyChangedSignal("Text"), function()
    local value = tonumber(undergroundInput.Text)
    if value then
        Config.UndergroundHeight = math.clamp(value, 0, 250)
        _G.UnderGroundHeight = Config.UndergroundHeight
        if Config.AutoFarm and targetIsValid() and not undergroundInput:IsFocused() then lockCombatPosition() end
    end
end)

-- ================================================================
-- TOOLTIPS
-- ================================================================
local tooltip = Instance.new("Frame")
tooltip.Name = "Tooltip"
tooltip.Size = UDim2.fromOffset(255, 74)
tooltip.BackgroundColor3 = Color3.fromRGB(12, 12, 17)
tooltip.BorderSizePixel = 0
tooltip.Visible = false
tooltip.ZIndex = 100
tooltip.Active = false
tooltip.Parent = ScreenGui

local tooltipCorner = Instance.new("UICorner")
tooltipCorner.CornerRadius = UDim.new(0, 8)
tooltipCorner.Parent = tooltip

local tooltipStroke = Instance.new("UIStroke")
tooltipStroke.Color = getAccentColor()
tooltipStroke.Transparency = 0.25
tooltipStroke.Thickness = 1
tooltipStroke.Parent = tooltip

local tooltipTitle = Instance.new("TextLabel")
tooltipTitle.Size = UDim2.new(1, -16, 0, 19)
tooltipTitle.Position = UDim2.fromOffset(8, 6)
tooltipTitle.BackgroundTransparency = 1
tooltipTitle.TextColor3 = Color3.fromRGB(238, 238, 245)
tooltipTitle.Font = Enum.Font.GothamBold
tooltipTitle.TextSize = 10
tooltipTitle.TextXAlignment = Enum.TextXAlignment.Left
tooltipTitle.ZIndex = 101
tooltipTitle.Parent = tooltip

local tooltipText = Instance.new("TextLabel")
tooltipText.Size = UDim2.new(1, -16, 1, -28)
tooltipText.Position = UDim2.fromOffset(8, 25)
tooltipText.BackgroundTransparency = 1
tooltipText.TextColor3 = Color3.fromRGB(170, 170, 184)
tooltipText.Font = Enum.Font.Gotham
tooltipText.TextSize = 9
tooltipText.TextWrapped = true
tooltipText.TextXAlignment = Enum.TextXAlignment.Left
tooltipText.TextYAlignment = Enum.TextYAlignment.Top
tooltipText.ZIndex = 101
tooltipText.Parent = tooltip

local tooltipToken = 0
local function showTooltip(titleText, bodyText, object)
    tooltipToken += 1
    local token = tooltipToken
    task.delay(0.22, function()
        if token ~= tooltipToken or State.Unloaded or not object.Parent then return end
        tooltipTitle.Text = titleText
        tooltipText.Text = bodyText
        tooltipStroke.Color = getAccentColor()
        tooltip.Visible = true
        local pos, size = object.AbsolutePosition, object.AbsoluteSize
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
        local x = pos.X + size.X + 8
        local y = pos.Y
        if x + tooltip.AbsoluteSize.X > viewport.X - 8 then x = math.max(8, pos.X - tooltip.AbsoluteSize.X - 8) end
        if y + tooltip.AbsoluteSize.Y > viewport.Y - 8 then y = math.max(8, viewport.Y - tooltip.AbsoluteSize.Y - 8) end
        tooltip.Position = UDim2.fromOffset(x, y)
    end)
end

local function hideTooltip()
    tooltipToken += 1
    tooltip.Visible = false
end

local buttonDescriptions = {
    [toggleButton] = {"Auto Farm", "Starts or stops the farming controller. It is OFF when the script launches."},
    [modeButton] = {"Combat Position", "UNDER keeps the character below the target. ABOVE keeps it above the target."},
    [autoAttackButton] = {"Auto Attack", "Automatically attacks a valid nearby target when enabled."},
    [teleportPortalButton] = {"Nearest Exit", "Uses the existing portal/door selection logic to move toward the detected exit."},
    [autoAvoidButton] = {"Auto Avoid", "Uses the existing danger detection to move away from incoming red attacks."},
    [performanceButton] = {"Performance", "Uses the existing lower-work mode intended to reduce client load."},
    [safeModeButton] = {"Safe Mode", "Uses the existing conservative safety distances and behavior."},
    [emergencyButton] = {"Emergency Escape", "Uses the existing emergency escape when danger becomes critical."},
    [debugButton] = {"Debug Monitor", "Shows scan counters and diagnostics in the DEBUG CONSOLE below."},
    [themeButton] = {"Appearance", "Open the color studio and choose a bright accent for the interface."},
}

for button, info in pairs(buttonDescriptions) do
    connect(button.MouseEnter, function() showTooltip(info[1], info[2], button) end)
    connect(button.MouseLeave, hideTooltip)
end

connect(aboveInput.MouseEnter, function() showTooltip("Upper Height", "Vertical offset used when farming above the target. Default is 8.", aboveInput) end)
connect(aboveInput.MouseLeave, hideTooltip)
connect(undergroundInput.MouseEnter, function() showTooltip("Under Height", "Vertical distance used below the target when underground mode is active. Default is 8.", undergroundInput) end)
connect(undergroundInput.MouseLeave, hideTooltip)
connect(minimize.MouseEnter, function() showTooltip("Minimize", "Collapses the main control panel without unloading the script.", minimize) end)
connect(minimize.MouseLeave, hideTooltip)
connect(closeButton.MouseEnter, function() showTooltip("Close / Unload", "Stops the script, disconnects its events, and removes its UI.", closeButton) end)
connect(closeButton.MouseLeave, hideTooltip)

-- ================================================================
-- EXISTING BUTTON EVENTS: unchanged mechanics, only variable names retained.
-- ================================================================
connect(toggleButton.MouseButton1Click, function()
    Config.AutoFarm = not Config.AutoFarm
    _G.AutoFarm = Config.AutoFarm
    State.TargetModel = nil
    State.TargetRoot = nil
    State.TargetHumanoid = nil
    State.RoomClearTimer = 0
    State.VerticalLockTimer = 0
    if Config.AutoFarm then
        State.StageBusy = false
        State.StageCooldown = false
        State.DoorBusy = false
        State.DoorCooldown = false
        State.StageBusyTimer = 0
        State.FallbackTargetTimer = 0
        State.RoomClearTimer = 0
        State.PortalTimer = Config.PortalRefresh
        State.TargetTimer = Config.TargetRefresh
        rebuildPortalCandidates()
        refreshTarget()
        if not targetIsValid() then
            local model, root, humanoid = findNearestTargetFallback()
            State.TargetModel = model
            State.TargetRoot = root
            State.TargetHumanoid = humanoid
        end
    end
    if not Config.AutoFarm then
        if State.Humanoid then
            pcall(function()
                State.Humanoid.PlatformStand = false
                State.Humanoid.AutoRotate = true
                State.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end)
        end
        State.UndergroundPhysics = false
        if State.Root then
            State.Root.AssemblyLinearVelocity = Vector3.zero
            State.Root.AssemblyAngularVelocity = Vector3.zero
        end
    end
    setToggleVisual()
    saveSettings()
end)

connect(modeButton.MouseButton1Click, function()
    Config.UndergroundMode = not Config.UndergroundMode
    _G.UndergroundMode = Config.UndergroundMode
    State.GroundY = nil
    State.GroundTimer = Config.GroundSampleInterval
    State.UndergroundPhysics = false
    State.VerticalLockTimer = 0
    if State.Humanoid then
        pcall(function()
            State.Humanoid.AutoRotate = not Config.UndergroundMode
            State.Humanoid.PlatformStand = Config.UndergroundMode
            if Config.UndergroundMode then
                State.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
            else
                State.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end)
    end
    setModeVisual()
    saveSettings()
end)

connect(autoAttackButton.MouseButton1Click, function()
    Config.AutoAttack = not Config.AutoAttack
    _G.AutoAttack = Config.AutoAttack
    setAutoAttackVisual()
    saveSettings()
end)

connect(teleportPortalButton.MouseButton1Click, function()
    rebuildPortalCandidates()
    teleportNearPortal()
end)

connect(autoAvoidButton.MouseButton1Click, function()
    Config.AutoAvoid = not Config.AutoAvoid
    _G.AutoAvoid = Config.AutoAvoid
    setAutoAvoidVisual()
    saveSettings()
end)

connect(performanceButton.MouseButton1Click, function()
    Config.PerformanceMode = not Config.PerformanceMode
    setPerformanceVisual()
    saveSettings()
end)

connect(safeModeButton.MouseButton1Click, function()
    Config.SafeMode = not Config.SafeMode
    setSafeModeVisual()
    saveSettings()
end)

connect(emergencyButton.MouseButton1Click, function()
    Config.EmergencyEscape = not Config.EmergencyEscape
    setEmergencyVisual()
    saveSettings()
end)

connect(debugButton.MouseButton1Click, function()
    Config.Debug = not Config.Debug
    setDebugVisual()
    saveSettings()
end)

connect(minimize.MouseButton1Click, function()
    collapsed = not collapsed
    if collapsed then
        minimize.Text = "+"
        content.Visible = false
        TweenService:Create(outline, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(WINDOW_WIDTH + BORDER * 2, 58 + BORDER * 2)
        }):Play()
    else
        minimize.Text = "−"
        content.Visible = true
        TweenService:Create(outline, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(WINDOW_WIDTH + BORDER * 2, WINDOW_HEIGHT + BORDER * 2)
        }):Play()
    end
end)

connect(header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        State.Dragging = true
        State.DragStart = input.Position
        State.StartPosition = outline.Position
    end
end)

connect(UserInputService.InputChanged, function(input)
    if not State.Dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local delta = input.Position - State.DragStart
    outline.Position = UDim2.new(
        State.StartPosition.X.Scale,
        State.StartPosition.X.Offset + delta.X,
        State.StartPosition.Y.Scale,
        State.StartPosition.Y.Offset + delta.Y
    )
end)

connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        State.Dragging = false
    end
end)

-- Launch animation: UI-only.
local intro = Instance.new("Frame")
intro.Name = "LaunchOverlay"
intro.Size = UDim2.fromScale(1, 1)
intro.BackgroundColor3 = Color3.fromRGB(6, 6, 10)
intro.BorderSizePixel = 0
intro.ZIndex = 500
intro.Parent = ScreenGui

local introGradient = Instance.new("UIGradient")
introGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(7, 7, 12)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 16, 27)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 6, 10)),
})
introGradient.Rotation = 25
introGradient.Parent = intro

local introTitle = Instance.new("TextLabel")
introTitle.Size = UDim2.new(1, -40, 0, 60)
introTitle.Position = UDim2.new(0, 20, 0.5, -50)
introTitle.BackgroundTransparency = 1
introTitle.Text = "Iron forge Script"
introTitle.TextColor3 = Color3.fromRGB(246, 246, 252)
introTitle.Font = Enum.Font.GothamBlack
introTitle.TextSize = 34
introTitle.TextTransparency = 1
introTitle.TextXAlignment = Enum.TextXAlignment.Center
introTitle.ZIndex = 501
introTitle.Parent = intro

local introLine = Instance.new("Frame")
introLine.Size = UDim2.fromOffset(160, 2)
introLine.Position = UDim2.new(0.5, -80, 0.5, 22)
introLine.BackgroundColor3 = getAccentColor()
introLine.BorderSizePixel = 0
introLine.BackgroundTransparency = 1
introLine.ZIndex = 501
introLine.Parent = intro

local introLineCorner = Instance.new("UICorner")
introLineCorner.CornerRadius = UDim.new(1, 0)
introLineCorner.Parent = introLine

local introSubtitle = Instance.new("TextLabel")
introSubtitle.Size = UDim2.new(1, -40, 0, 24)
introSubtitle.Position = UDim2.new(0, 20, 0.5, 34)
introSubtitle.BackgroundTransparency = 1
introSubtitle.Text = "INITIALIZING INTERFACE"
introSubtitle.TextColor3 = Color3.fromRGB(135, 130, 150)
introSubtitle.Font = Enum.Font.GothamMedium
introSubtitle.TextSize = 10
introSubtitle.TextTransparency = 1
introSubtitle.TextXAlignment = Enum.TextXAlignment.Center
introSubtitle.ZIndex = 501
introSubtitle.Parent = intro

task.spawn(function()
    local fadeIn = TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local fadeOut = TweenInfo.new(0.40, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    TweenService:Create(introTitle, fadeIn, {TextTransparency = 0}):Play()
    TweenService:Create(introLine, fadeIn, {BackgroundTransparency = 0}):Play()
    task.wait(0.12)
    TweenService:Create(introSubtitle, fadeIn, {TextTransparency = 0}):Play()
    task.wait(0.70)
    introSubtitle.Text = "INTERFACE READY"
    task.wait(0.42)
    TweenService:Create(introTitle, fadeOut, {TextTransparency = 1}):Play()
    TweenService:Create(introLine, fadeOut, {BackgroundTransparency = 1}):Play()
    TweenService:Create(introSubtitle, fadeOut, {TextTransparency = 1}):Play()
    TweenService:Create(intro, fadeOut, {BackgroundTransparency = 1}):Play()
    task.wait(0.42)
    if intro and intro.Parent then intro:Destroy() end
end)

setThemeVisual()

local function updateStatusPanel()
    if not statusText or not statusText.Parent then
        return
    end

    local distanceText =
        State.LastTargetDistance < math.huge
        and string.format("%.1f", State.LastTargetDistance)
        or "-"

    local hpText =
        State.TargetHealthPercent > 0
        and string.format("%.0f%%", State.TargetHealthPercent)
        or "-"

    local dangerText =
        State.DangerDistance < math.huge
        and string.format("%.1f", State.DangerDistance)
        or "-"

    local targetName = tostring(State.LastTargetName or "-")
    if #targetName > 22 then
        targetName = string.sub(targetName, 1, 19) .. "..."
    end

    if Config.Debug then
        statusText.Text = string.format(
            "State    %s\nTarget   %s\nDistance %s\nHP       %s\nDanger   %s\nScans    T:%d P:%d D:%d",
            State.CurrentAction,
            targetName,
            distanceText,
            hpText,
            dangerText,
            State.Stats.TargetScans,
            State.Stats.PortalScans,
            State.Stats.DangerScans
        )
    else
        statusText.Text = string.format(
            "State    %s\nTarget   %s\nDistance %s\nHP       %s\nDanger   %s",
            State.CurrentAction,
            targetName,
            distanceText,
            hpText,
            dangerText
        )
    end

    if debugPanelText and debugPanelText.Parent then
        if Config.Debug then
            debugPanelText.Text = string.format(
                "HEARTBEATS  %d    TARGET SCANS  %d\nPORTAL SCANS  %d    DANGER SCANS  %d\nLAST FRAME  %.2f ms",
                State.Stats.Heartbeats,
                State.Stats.TargetScans,
                State.Stats.PortalScans,
                State.Stats.DangerScans,
                State.Stats.LastHeartbeatMs
            )
            debugPanelText.TextColor3 = Color3.fromRGB(185, 185, 198)
        else
            debugPanelText.Text = "Debug is disabled."
            debugPanelText.TextColor3 = Color3.fromRGB(105, 105, 120)
        end
    end
end

local rainbowHue = 0

connect(RunService.Heartbeat, function(dt)
    if State.Unloaded then
        return
    end

    State.Stats.Heartbeats += 1

    State.StatusTimer += dt
    if State.StatusTimer >= Config.StatusInterval then
        State.StatusTimer = 0
        updateStatusPanel()
    end

    if not Config.AutoFarm then
        State.WatchdogTimer = 0
        State.StageBusyTimer = 0
        State.CurrentAction = "Idle"
        return
    end

    if not State.Character
        or not State.Root
        or not State.Humanoid
        or State.Humanoid.Health <= 0 then
        return
    end

    -- Watchdog: prevents a failed/stalled stage task from leaving the
    -- automation permanently in "Portal" with the character standing still.
    State.WatchdogTimer += dt

    if State.StageBusy then
        State.StageBusyTimer += dt

        if State.StageBusyTimer >= 6 then
            State.StageBusy = false
            State.DoorBusy = false
            State.StageBusyTimer = 0
            State.RoomClearTimer = 0
            State.CurrentAction = "Recovering"
        end
    else
        State.StageBusyTimer = 0
    end

    if State.WatchdogTimer >= 2 then
        State.WatchdogTimer = 0

        -- Refresh dynamic exits so newly revealed portals/doors are picked up.
        if Config.AutoProgressStage and not State.StageBusy then
            rebuildPortalCandidates()
        end

        -- If target refresh temporarily missed an enemy, immediately try
        -- another search instead of waiting for the next long interval.
        if not State.TargetRoot or not targetIsValid() then
            local model, root, humanoid = findNearestTarget()

            State.TargetModel = model
            State.TargetRoot = root
            State.TargetHumanoid = humanoid

            if model and root and humanoid then
                State.RoomClearTimer = 0
            end
        end
    end

    -- Room-clear timer is independent of the scan cadence.
    if not State.TargetRoot or not targetIsValid() then
        State.RoomClearTimer += dt
    end

    if State.FallbackTargetTimer > 0 then
        State.FallbackTargetTimer = math.max(
            0,
            State.FallbackTargetTimer - dt
        )
    end

    State.TargetTimer += dt

    local targetInterval =
        Config.PerformanceMode
        and math.max(Config.TargetRefresh, 0.25)
        or math.min(Config.TargetRefresh, 0.50)

    if State.TargetTimer >= targetInterval then
        State.TargetTimer = 0
        refreshTarget()
    end

    State.PortalTimer += dt

    local portalInterval =
        Config.PerformanceMode
        and math.max(Config.PortalRefresh, 1.0)
        or math.min(Config.PortalRefresh, 1.5)

    if State.PortalTimer >= portalInterval then
        State.PortalTimer = 0

        if Config.AutoProgressStage and not State.StageBusy then
            task.spawn(function()
                local ok, err = pcall(moveToNextStage)

                if not ok then
                    State.StageBusy = false
                    State.DoorBusy = false
                    State.RoomClearTimer = 0
                    State.CurrentAction = "Recovering"

                    if Config.Debug then
                        warn("[IronSoul] stage error:", err)
                    end
                end
            end)
        end
    end

    if State.EmergencyBusy then
        State.CurrentAction = "Emergency Escape"
    elseif Config.AutoAvoid and State.DangerPart then
        updateAutoAvoid(dt)
    elseif Config.AutoProgressStage and State.StageBusy then
        -- moveToNextStage sets more specific action text such as
        -- Moving To Portal / Moving To Door.
        if State.CurrentAction == "Farming" then
            State.CurrentAction = "Portal"
        end
    else
        -- Keep combat position independent of the slower scans.
        lockCombatPosition()

        State.AttackTimer += dt
        if State.AttackTimer >= Config.AttackInterval then
            State.AttackTimer = 0
            updateKillAura()
        end

        State.CurrentAction = "Farming"
    end

    State.SkillTimer += dt

    if State.SkillTimer >= Config.SkillInterval then
        State.SkillTimer = 0

        if Config.AutoSkill and targetIsValid() then
            task.spawn(useSkills)
        end
    end
end)

local function unload()
    if State.Unloaded then
        return
    end

    State.Unloaded = true
    Config.AutoFarm = false
    _G.AutoFarm = false

    disconnectList(CharacterConnections)
    disconnectList(Connections)

    if ScreenGui then
        ScreenGui:Destroy()
    end

    State.Character = nil
    State.Humanoid = nil
    State.Root = nil
    State.TargetModel = nil
    State.TargetRoot = nil
    State.TargetHumanoid = nil
    State.Portal = nil

    debugPrint("Unloaded")
end

_G.IronSoulUnload = unload

connect(closeButton.MouseButton1Click, function()
    unload()
end)

setToggleVisual()
setModeVisual()
setAutoAttackVisual()
setAutoAvoidVisual()
setPerformanceVisual()
setSafeModeVisual()
setEmergencyVisual()
setDebugVisual()
setThemeVisual()
updateStatusPanel()

saveSettings()
print("[IronSoul] loaded")
