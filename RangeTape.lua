local addonName, ns = ...

--------------------------------------------------------------------------------
-- Range tape (warriors only; part of the range display, see Range.lua)
-- Adapted from Good Range's display by Andrii Zolotarenko (MIT, see
-- LICENSE-GoodRange.txt). Draws a distance in one of four looks:
--   tape    a ruler sliding under a gold needle, ticks every 0.1 yd (fewer when
--           the scale would crowd them), the distance above it
--   label   a zone badge (MELEE, CHARGE, OUT OF RANGE ...) and the distance
--   badge   the zone badge alone
--   number  the distance alone
-- Everything is coloured by zone: green melee, blue another range the warrior
-- can use right now, red the dead zone between them, grey out of range. With no
-- range answer at all it turns grey, half transparent, and says "no data".
-- Cheap to run: the ticks sit on one ruler frame that is moved as a whole each
-- frame and are only restyled when the tape passes a tick.
-- Events: none
-- SavedVariables: none (Range.lua passes the settings in)
--------------------------------------------------------------------------------
local ASSET = "Interface\\AddOns\\" .. addonName .. "\\Assets\\"
local FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"
local SLICES = 28 -- backing plate columns, each a vertical gradient
local BASE_H = 40 -- design height; tick sizes scale with height / BASE_H
local TICK_GAP = 5 -- px; ticks closer than this run together, so fewer are drawn
local DIVS = { 10, 5, 4, 2, 1 } -- ticks per yard to choose from, finest first
local YD_GAP = 2 -- px between the number and its unit

-- Font files by saved value (see ns.LISTS.rangeTextFont in Core.lua).
local FONTS = {
  changa = ASSET .. "Changa-Bold.ttf", skurri = "Fonts\\skurri.ttf", arial = "Fonts\\ARIALN.TTF",
  ["2002"] = "Fonts\\2002B.ttf", friz = FALLBACK_FONT, nimrod = "Fonts\\NIM_____.ttf",
  morpheus = "Fonts\\MORPHEUS.TTF",
}
-- Where the digits sit, as parts of the font size S, for a string placed by its
-- centre: digit height D * S, digit middle R * S above the centre. Changa's
-- values were measured in game; the default is a close guess for the others.
local DIGIT = { changa = { D = 0.725, R = 0.13 } }
local DEFAULT_DIGIT = { D = 0.72, R = 0.1 }

local COLORS = {
  primary = { 0.373, 0.878, 0.416 },
  secondary = { 0.302, 0.659, 1 },
  dead = { 0.95, 0.33, 0.31 },
  far = { 0.545, 0.565, 0.6 },
}
-- Every badge text Range.lua uses, so the badge is as wide as the longest.
local LABELS = { "MELEE", "CHARGE", "THROW", "SHOOT", "DEAD ZONE", "OUT OF RANGE", "NO DATA" }

-- Most translations call the game's yard a metre without converting the number,
-- so only the label changes.
local METRES = { deDE = true, esES = true, esMX = true, frFR = true, itIT = true, ptBR = true,
  ruRU = true, koKR = true }
local UNIT = METRES[GetLocale()] and "m" or "yd"

local Tape = {}
Tape.__index = Tape
ns.RangeTape = Tape

-- Alpha of a column at x on a plate whose middle is cx: 1 in the middle,
-- fading to 0 at the sides.
local function Fade(x, cx)
  local f = 1 - (math.abs(x - cx) / cx) ^ 2.2
  return f > 0 and f or 0
end

local function SetFont(fs, font, size, flags)
  if not fs:SetFont(font, size, flags) then fs:SetFont(FALLBACK_FONT, size, flags) end
end

-- Creates the display inside parent, centred on it. Returns the tape; its
-- root frame is sized by SetLayout.
function Tape.New(parent)
  local self = setmetatable({ ticks = {}, tickH = {}, plate = {} }, Tape)
  local root = CreateFrame("Frame", nil, parent)
  root:SetPoint("CENTER")
  self.root = root

  self.area = CreateFrame("Frame", nil, root)
  self.area:SetClipsChildren(true)
  self.ruler = CreateFrame("Frame", nil, self.area)
  self.ruler:SetSize(1, 1)

  self.number = root:CreateFontString(nil, "OVERLAY")
  self.unit = root:CreateFontString(nil, "OVERLAY")

  -- Badge: a rounded rectangle from three slices of one texture, with the zone
  -- name in capitals.
  self.badge = CreateFrame("Frame", nil, root)
  local function Slice(left, right)
    local t = self.badge:CreateTexture(nil, "BACKGROUND")
    t:SetTexture(ASSET .. "range-badge")
    t:SetTexCoord(left, right, 0, 1)
    return t
  end
  self.capL, self.mid, self.capR = Slice(0, 0.25), Slice(0.25, 0.75), Slice(0.75, 1)
  self.caps = { self.capL, self.mid, self.capR }
  self.capL:SetPoint("TOPLEFT")
  self.capL:SetPoint("BOTTOMLEFT")
  self.capR:SetPoint("TOPRIGHT")
  self.capR:SetPoint("BOTTOMRIGHT")
  self.mid:SetPoint("TOPLEFT", self.capL, "TOPRIGHT")
  self.mid:SetPoint("BOTTOMRIGHT", self.capR, "BOTTOMLEFT")
  self.badgeText = self.badge:CreateFontString(nil, "OVERLAY")

  -- Needle: head, stretched stem and tip, sliced from one texture, on its own
  -- frame so it draws over the ruler.
  self.needle = CreateFrame("Frame", nil, self.area)
  self.needle:SetAllPoints(self.area)
  self.needle:SetFrameLevel(self.ruler:GetFrameLevel() + 5)
  local function NeedlePart(top, bottom)
    local t = self.needle:CreateTexture(nil, "OVERLAY", nil, 7)
    t:SetTexture(ASSET .. "range-needle")
    t:SetTexCoord(0, 1, top / 16, bottom / 16)
    return t
  end
  self.head = NeedlePart(0, 9.5)
  self.stem = NeedlePart(9.5, 11)
  self.tip = NeedlePart(11.5, 16)

  for i = 1, SLICES do
    local t = self.area:CreateTexture(nil, "BACKGROUND")
    t:SetColorTexture(1, 1, 1, 1)
    self.plate[i] = t
  end
  return self
end

-- zoneAt(d) -> kind ("primary", "secondary", "dead" or "far"), badge text.
-- Call again when the zones change: it restyles on the next draw.
function Tape:SetZones(zoneAt)
  self.zoneAt = zoneAt
  self.first, self.zone = nil, nil
  if self.value then self:Draw(self.value, self.label) end
end

-- look: "tape", "label", "badge" or "number". width, height: the tape's size.
-- fontSize: the distance's size. ppy: tape pixels per yard. font: a FONTS key.
-- showUnit: false hides "yd" after the number.
function Tape:SetLayout(look, width, height, fontSize, ppy, font, showUnit)
  self.width, self.height, self.fontSize, self.ppy = width, height, fontSize, ppy
  self.showTape = look == "tape"
  self.showBadge = look == "label" or look == "badge"
  self.showNumber = look ~= "badge"
  self.showUnit = self.showNumber and showUnit
  local k = height / BASE_H
  self.k = k
  self.base = math.floor(height - 12 * k + 0.5) -- tick baseline, from the ruler's top
  self.area:ClearAllPoints()
  self.area:SetPoint("BOTTOMLEFT")
  self.area:SetPoint("BOTTOMRIGHT")
  self.area:SetHeight(height)
  self.area:SetShown(self.showTape)
  self.badge:SetShown(self.showBadge)
  self.number:SetShown(self.showNumber)
  self.unit:SetShown(self.showUnit)

  local path = FONTS[font]
  local unitSize = math.max(8, math.floor(fontSize * 0.45 + 0.5))
  SetFont(self.number, path, fontSize, "OUTLINE")
  SetFont(self.unit, path, unitSize, "OUTLINE")
  for _, fs in ipairs({ self.number, self.unit }) do
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.9)
  end
  self.unit:SetText(UNIT) -- only once a font is set: text on a font-less string errors

  local m = DIGIT[font] or DEFAULT_DIGIT
  local digitH = math.max(6, math.floor(fontSize * m.D + 0.5))

  -- Badge: as tall as the digits, and one width for every label so nothing shifts.
  local badgeH = digitH
  self.badge:SetHeight(badgeH)
  self.capL:SetWidth(badgeH / 2)
  self.capR:SetWidth(badgeH / 2)
  local textSize = math.max(7, math.floor(badgeH * 0.5 + 0.5))
  SetFont(self.badgeText, path, textSize, "")
  -- Capitals sit above the middle of their line like digits do: lower the text by that much.
  self.badgeText:ClearAllPoints()
  self.badgeText:SetPoint("CENTER", self.badge, "CENTER", 0, -m.R * textSize)
  self.badgeText:SetTextColor(0.06, 0.06, 0.07)
  local longest = 0
  for _, text in ipairs(LABELS) do
    self.badgeText:SetText(text)
    longest = math.max(longest, self.badgeText:GetStringWidth())
  end
  local badgeW = math.floor(longest + badgeH * 0.9 + 0.5)
  self.badge:SetWidth(badgeW)

  self.number:ClearAllPoints()
  self.unit:ClearAllPoints()
  self.badge:ClearAllPoints()
  -- A two-digit number's width, so the layout never shifts as it changes.
  self.number:SetText("88")
  local slot = self.number:GetStringWidth()
  local unitW = self.showUnit and YD_GAP + self.unit:GetStringWidth() or 0
  if self.showTape then
    -- The number centred over the needle, 3 px above the tape.
    self.root:SetSize(width, height + digitH + 4)
    self.number:SetJustifyH("CENTER")
    self.number:SetPoint("CENTER", self.area, "TOP", 0, 3 + digitH / 2 - m.R * fontSize)
  elseif not self.showNumber then
    self.root:SetSize(badgeW, badgeH)
    self.badge:SetPoint("CENTER")
  elseif not self.showBadge then
    -- Centred on its digits, "yd" hanging off the right.
    self.root:SetSize(slot + 2 * unitW, digitH + 4)
    self.number:SetJustifyH("CENTER")
    self.number:SetPoint("CENTER", self.root, "CENTER", 0, -m.R * fontSize)
  else
    -- [ badge ] number yd, left-aligned so only "yd" moves.
    local gap = math.floor(fontSize * 0.25 + 0.5)
    self.root:SetSize(badgeW + gap + slot + unitW, digitH + 4)
    self.badge:SetPoint("LEFT")
    self.number:SetJustifyH("LEFT")
    self.number:SetPoint("LEFT", self.root, "LEFT", badgeW + gap, -m.R * fontSize)
  end
  -- "yd" stands on the digits' baseline.
  self.unit:SetPoint("LEFT", self.number, "RIGHT", YD_GAP, (m.R - m.D / 2) * (fontSize - unitSize))

  -- Backing plate: darkest at the ruler's bottom edge, clear towards the number
  -- and to the sides. Whole-pixel edges so columns meet without seams.
  local sw = width / SLICES
  for i, t in ipairs(self.plate) do
    local a = 0.6 * Fade((i - 0.5) * sw, width / 2)
    local x0, x1 = math.floor((i - 1) * sw + 0.5), math.floor(i * sw + 0.5)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", self.area, "TOPLEFT", x0, 0)
    t:SetSize(x1 - x0, self.base)
    t:SetGradient("VERTICAL", CreateColor(0, 0, 0, a), CreateColor(0, 0, 0, 0))
  end

  -- Needle, centred: head by the number, tip at the ruler's bottom edge.
  local nw = 16 * k
  self.head:ClearAllPoints()
  self.head:SetPoint("TOP", self.area, "TOP")
  self.head:SetSize(nw, 9.5 * k)
  self.tip:ClearAllPoints()
  self.tip:SetPoint("BOTTOM", self.area, "BOTTOM")
  self.tip:SetSize(nw, 4.5 * k)
  self.stem:ClearAllPoints()
  self.stem:SetPoint("TOP", self.head, "BOTTOM")
  self.stem:SetPoint("BOTTOM", self.tip, "TOP")
  self.stem:SetWidth(nw)

  -- Ticks laid out once across the visible span, standing on the baseline.
  local div = DIVS[#DIVS]
  for _, d in ipairs(DIVS) do
    if ppy / d >= TICK_GAP then
      div = d
      break
    end
  end
  self.div = div
  local step = ppy / div
  local need = math.ceil(width / step) + 4
  self.count = need
  for i = 1, need do
    local t = self.ticks[i]
    if not t then
      t = self.ruler:CreateTexture(nil, "ARTWORK")
      t:SetColorTexture(1, 1, 1, 1)
      self.ticks[i] = t
    end
    t:ClearAllPoints()
    t:SetPoint("BOTTOM", self.ruler, "TOPLEFT", (i - 1) * step, -self.base)
    t:Hide()
    self.tickH[i] = 0
  end
  for i = need + 1, #self.ticks do self.ticks[i]:Hide() end

  self.first, self.drawn, self.text, self.zone = nil, nil, nil, nil
  self.number:SetText("")
  if self.noData then
    self:SetNoData(true)
  elseif self.value then
    self:Draw(self.value, self.label)
  end
end

-- Colour, size and side fade for the ticks from tick index first on (1 / div
-- yd each), with the tape at v.
function Tape:Restyle(first, v)
  self.first = first
  local k, tickH, cx, ppy, div = self.k, self.tickH, self.width / 2, self.ppy, self.div
  for n = 1, self.count do
    local i = first + n - 1
    local tick = self.ticks[n]
    local f = Fade(cx + (i / div - v) * ppy, cx)
    if i < 0 or f <= 0.01 then
      if tickH[n] ~= 0 then
        tick:Hide()
        tickH[n] = 0
      end
    else
      local major, half = i % div == 0, 2 * i % div == 0
      local c = COLORS[self.zoneAt(i / div)]
      local h = (major and 20 or half and 12 or 6) * k
      if tickH[n] ~= h then
        if tickH[n] == 0 then tick:Show() end
        tick:SetSize(2, h)
        tickH[n] = h
      end
      tick:SetVertexColor(c[1], c[2], c[3], f * (major and 1 or half and 0.9 or 0.75))
    end
  end
end

-- The root's alpha: a (half while there is no data) times the player's opacity.
function Tape:SetAlpha(a)
  self.alpha = a
  self.root:SetAlpha(a * (self.opacity or 1))
end

-- o: the Opacity setting, 0 to 1.
function Tape:SetOpacity(o)
  self.opacity = o
  self:SetAlpha(self.alpha or 1)
end

-- No range answer at all: grey, half transparent, "no data" where the value
-- goes (on the badge when there is one), the ruler hidden.
function Tape:SetNoData(on)
  self.noData = on
  self:SetAlpha(on and 0.5 or 1)
  self.ruler:SetShown(not on)
  self.unit:SetShown(not on and self.showUnit)
  if on then
    local c = COLORS.far
    self.number:SetText(self.showBadge and "" or "no data")
    self.number:SetTextColor(c[1], c[2], c[3])
    if self.showBadge then
      self.badgeText:SetText("NO DATA")
      for _, t in ipairs(self.caps) do t:SetVertexColor(c[1], c[2], c[3], 0.95) end
    end
  end
  self.first, self.drawn, self.text, self.zone = nil, nil, nil, nil -- redraw in full once data is back
end

-- v: distance in yd (fractional, drives the tape). label: the text shown
-- (whole yards, or "12+" past the last step that answered).
function Tape:Draw(v, label)
  self.value, self.label = v, label
  if not self.width or not self.zoneAt or self.noData then return end
  if v == self.drawn and label == self.text and self.zone then return end
  self.drawn = v

  if self.showTape then
    local cx, ppy, div = self.width / 2, self.ppy, self.div
    local first = math.floor((v - cx / ppy) * div) - 1
    if first ~= self.first then self:Restyle(first, v) end
    -- tick n sits at ruler x (n - 1) * step and stands for (first + n - 1) / div
    self.ruler:ClearAllPoints()
    self.ruler:SetPoint("TOPLEFT", self.area, "TOPLEFT", cx + (first / div - v) * ppy, 0)
  end

  local zone, badge = self.zoneAt(v)
  if label ~= self.text or zone ~= self.zone or badge ~= self.badgeLabel then
    self.text, self.zone, self.badgeLabel = label, zone, badge
    local c = COLORS[zone]
    self.number:SetText(label)
    self.number:SetTextColor(c[1], c[2], c[3])
    self.unit:SetTextColor(c[1], c[2], c[3])
    if self.showBadge then
      self.badgeText:SetText(badge)
      for _, t in ipairs(self.caps) do t:SetVertexColor(c[1], c[2], c[3], 0.95) end
    end
  end
end
