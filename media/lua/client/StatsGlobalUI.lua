-- StatsGlobal - HUD UI
-- Ícones do mod TwisTonFire + ícones nativos do PZ via MoodleUI
-- Progress bars em tempo real

require("ISUI/ISPanel")

StatsGlobalUI = ISPanel:derive("StatsGlobalUI")
StatsGlobalUI.instance = nil

-- Layout
local ICON_SIZE = 24
local BAR_W     = 110
local BAR_H     = 12
local PAD       = 6
local ROW_H     = ICON_SIZE + PAD
local PANEL_W   = PAD + ICON_SIZE + PAD + BAR_W + PAD
local PANEL_H   = 0  -- calculado abaixo

local NUM_ROWS  = 5
PANEL_H = NUM_ROWS * ROW_H + PAD * 2

-- Cores das barras
local C = {
    zombies = {r=0.55, g=0.95, b=0.3 },
    hunger  = {r=0.95, g=0.65, b=0.2 },
    thirst  = {r=0.3,  g=0.75, b=1.0 },
    km      = {r=0.75, g=0.75, b=0.75},
    temp    = {r=1.0,  g=0.35, b=0.35},
}

-- Texturas (carregadas uma vez)
local texZombies  = nil
local texTravel   = nil
local texHunger   = nil
local texThirst   = nil
local texTemp     = nil

local function loadTextures()
    -- Ícones do mod TwisTonFire (copiados para nossa pasta)
    texZombies = getTexture("media/ui/StatsGlobal/zedkills.png")
    texTravel  = getTexture("media/ui/StatsGlobal/travelled.png")
    -- Ícones nativos do PZ (moodles)
    texHunger  = getTexture("media/textures/Moodles/Hungry.png")
    texThirst  = getTexture("media/textures/Moodles/Thirsty.png")
    texTemp    = getTexture("media/textures/Moodles/HotTemp.png")
    -- Fallback: se moodle não existir, usa peso.png do TwisTonFire
    if not texHunger then texHunger = getTexture("media/ui/StatsGlobal/peso.png") end
    if not texThirst then texThirst = getTexture("media/ui/StatsGlobal/peso.png") end
    if not texTemp   then texTemp   = getTexture("media/ui/StatsGlobal/peso.png") end
end

function StatsGlobalUI:new(x, y)
    local o = ISPanel.new(self, x, y, PANEL_W, PANEL_H)
    o.backgroundColor = {r=0.05, g=0.05, b=0.05, a=0.72}
    o.borderColor     = {r=1,    g=1,    b=1,    a=0.06}
    o.moveWithMouse   = true
    StatsGlobalUI.instance = o
    return o
end

function StatsGlobalUI:initialise()
    ISPanel.initialise(self)
    loadTextures()
end

function StatsGlobalUI:prerender()
    ISPanel.prerender(self)
end

-- Desenha uma linha: ícone + barra + valor
local function drawRow(ui, rowY, tex, barColor, pct, valStr)
    local ix = PAD
    local iy = rowY + (ROW_H - ICON_SIZE) / 2 - PAD / 2

    -- ícone
    if tex then
        ui:drawTextureScaled(tex, ix, iy, ICON_SIZE, ICON_SIZE, 1, 1, 1, 1)
    else
        -- fallback: quadrado colorido
        ui:drawRect(ix, iy, ICON_SIZE, ICON_SIZE, 0.6, barColor.r, barColor.g, barColor.b)
    end

    local bx = PAD + ICON_SIZE + PAD
    local by = rowY + (ROW_H - BAR_H) / 2 - PAD / 2

    -- fundo da barra
    ui:drawRect(bx, by, BAR_W, BAR_H, 0.5, 0.08, 0.08, 0.08)

    -- preenchimento
    local fillW = math.max(0, math.floor(BAR_W * math.max(0, math.min(1, pct))))
    if fillW > 0 then
        ui:drawRect(bx, by, fillW, BAR_H, 0.9, barColor.r, barColor.g, barColor.b)
    end

    -- borda sutil na barra
    ui:drawRectBorder(bx, by, BAR_W, BAR_H, 0.25, 1, 1, 1)

    -- texto do valor
    local ty = by + (BAR_H - getTextManager():getFontHeight(UIFont.Small)) / 2
    ui:drawText(valStr, bx + 4, ty, 1, 1, 1, 0.95, UIFont.Small)
end

function StatsGlobalUI:render()
    ISPanel.render(self)

    local data = StatsGlobalClient and StatsGlobalClient.data
    if not data then return end

    local y = PAD

    -- Zumbis (soft cap 500 pra barra)
    local zPct = math.min(1, (data.zombies or 0) / 500)
    drawRow(self, y, texZombies, C.zombies, zPct,
        string.format("%d zeds", data.zombies or 0))
    y = y + ROW_H

    -- Fome: raw -1.0 (Full to Bursting) a 1.0 (Starving)
    -- Thresholds: Peckish=0.15, Hungry=0.25, Very Hungry=0.45, Starving=0.70
    -- Barra mostra "saciedade": 1.0 = cheio, 0.0 = faminto
    -- Valores negativos = positivo (acabou de comer) → barra cheia + cor verde
    local hRaw   = data.hunger or 0
    local hPct   = math.max(0, math.min(1, 1 - hRaw))  -- inverte: 0 raw = 100% barra
    local hColor = C.hunger
    local hLabel
    if hRaw < 0 then
        hColor = {r=0.3, g=0.9, b=0.3}  -- verde = bem alimentado
        hLabel = "Satisfeito"
    elseif hRaw < 0.15 then
        hLabel = "Normal"
    elseif hRaw < 0.25 then
        hColor = {r=1.0, g=0.85, b=0.2}
        hLabel = "Com fome"
    elseif hRaw < 0.45 then
        hColor = {r=1.0, g=0.55, b=0.1}
        hLabel = "Faminto"
    elseif hRaw < 0.70 then
        hColor = {r=1.0, g=0.3,  b=0.1}
        hLabel = "Muito faminto"
    else
        hColor = {r=1.0, g=0.1,  b=0.1}
        hLabel = "Morrendo de fome"
    end
    drawRow(self, y, texHunger, hColor, hPct, hLabel)
    y = y + ROW_H

    -- Sede: raw -1.0 a 1.0
    -- Thresholds: Slightly=0.13, Thirsty=0.25, Parched=0.70, Dying=0.85
    local tRaw   = data.thirst or 0
    local tPct   = math.max(0, math.min(1, 1 - tRaw))
    local tColor = C.thirst
    local tLabel
    if tRaw < 0 then
        tColor = {r=0.3, g=0.9, b=0.3}
        tLabel = "Hidratado"
    elseif tRaw < 0.13 then
        tLabel = "Normal"
    elseif tRaw < 0.25 then
        tColor = {r=0.5, g=0.85, b=1.0}
        tLabel = "Levemente sedento"
    elseif tRaw < 0.70 then
        tColor = {r=1.0, g=0.75, b=0.2}
        tLabel = "Sedento"
    elseif tRaw < 0.85 then
        tColor = {r=1.0, g=0.4,  b=0.1}
        tLabel = "Desidratado"
    else
        tColor = {r=1.0, g=0.1,  b=0.1}
        tLabel = "Morrendo de sede"
    end
    drawRow(self, y, texThirst, tColor, tPct, tLabel)
    y = y + ROW_H

    -- Km andados (soft cap 50km)
    local km  = data.km or 0
    local mts = data.meters or 0
    local kPct = math.min(1, (km + mts / 1000) / 50)
    drawRow(self, y, texTravel, C.km, kPct,
        string.format("%d km %d m", km, mts))
    y = y + ROW_H

    -- Temperatura (35°C=normal, 40°C=febre; barra mostra desvio)
    local temp  = data.temp or 37
    local tpPct = math.max(0, math.min(1, (temp - 35) / 5))
    local tpColor = C.temp
    if temp < 36 then tpColor = {r=0.3, g=0.6, b=1.0} end  -- azul = frio
    drawRow(self, y, texTemp, tpColor, tpPct,
        string.format("%.1f°C", temp))
end
