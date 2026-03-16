-- StatsGlobal - Client Logic
-- Multiplayer hosted: Events.OnCreatePlayer + OnPlayerUpdate para distância real

require("ISUI/ISPanel")
require("StatsGlobalUI")

StatsGlobalClient = {}
StatsGlobalClient.data = {
    zombies = 0,
    hunger  = 0,
    thirst  = 0,
    km      = 0,
    meters  = 0,
    temp    = 37.0,
}

local distanceTiles = 0
local lastX, lastY  = nil, nil
local hooksAdded    = false

-- Distância via delta XY — mesmo método do mod original
local function onPlayerUpdate(eventPlayer)
    local player = getPlayer()
    if not player or eventPlayer ~= player then return end

    local x = player:getX()
    local y = player:getY()

    if lastX == nil then
        lastX, lastY = x, y
        return
    end

    local dx = x - lastX
    local dy = y - lastY
    local d  = math.sqrt(dx * dx + dy * dy)
    lastX, lastY = x, y

    -- Ignora teleportes e saltos extremos de veículo
    local inVehicle = player.getVehicle and player:getVehicle() ~= nil
    local maxStep   = inVehicle and 120.0 or 25.0
    if d <= 0 or d ~= d or d > maxStep then return end

    distanceTiles = distanceTiles + d
end

-- Atualiza stats a cada tick (sem intervalo — fome/sede precisam ser em tempo real)
local function onTick()
    local player = getPlayer()
    if not player then return end

    local stats = player:getStats()
    if not stats then return end

    StatsGlobalClient.data.zombies = player:getZombieKills()

    -- getHunger/getThirst retornam float onde:
    --   < 0  = positivo (Satiated/Well Fed/Stuffed/Full) — personagem acabou de comer
    --   0.0  = neutro
    --   0.15 = Peckish | 0.25 = Hungry | 0.45 = Very Hungry | 0.70 = Starving
    --   Sede: 0.13 = Slightly | 0.25 = Thirsty | 0.70 = Parched | 0.85 = Dying
    -- Guardamos o valor raw sem clamp para o UI interpretar corretamente
    StatsGlobalClient.data.hunger  = stats:getHunger()   -- raw -1.0 a 1.0
    StatsGlobalClient.data.thirst  = stats:getThirst()   -- raw -1.0 a 1.0
    StatsGlobalClient.data.km      = math.floor(distanceTiles / 1000)
    StatsGlobalClient.data.meters  = math.floor(distanceTiles % 1000)
    StatsGlobalClient.data.temp    = player:getBodyTemperature()
end

local function createHUD()
    if StatsGlobalUI.instance then return end
    local screenH = getCore():getScreenHeight()
    local ui = StatsGlobalUI:new(10, screenH - 200)
    ui:initialise()
    ui:addToUIManager()
end

local function onCreatePlayer(_, player)
    local localPlayer = getPlayer()
    if not localPlayer or player ~= localPlayer then return end

    distanceTiles = 0
    lastX, lastY  = nil, nil

    createHUD()

    if not hooksAdded then
        hooksAdded = true
        Events.OnPlayerUpdate.Add(onPlayerUpdate)
        Events.OnTick.Add(onTick)
    end
end

local function onDisconnect()
    if StatsGlobalUI.instance then
        StatsGlobalUI.instance:removeFromUIManager()
        StatsGlobalUI.instance = nil
    end
    if hooksAdded then
        Events.OnPlayerUpdate.Remove(onPlayerUpdate)
        Events.OnTick.Remove(onTick)
        hooksAdded = false
    end
    distanceTiles = 0
    lastX, lastY  = nil, nil
end

Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnDisconnect.Add(onDisconnect)
