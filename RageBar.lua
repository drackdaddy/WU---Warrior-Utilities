local addonName, ns = ...
local db, LEM = ns.db, ns.LibEditMode

--------------------------------------------------------------------------------
-- Rage bar
-- The bar: rage fill and number, two marks with a glow past each, three
-- styles (Rage has a choice of borders), four colors, size, "only show in
-- combat", and switches to turn off the marks or the whole bar. It is moved
-- and set up in Blizzard's Edit Mode (see Edit Mode below).
-- Marks are a percent of max rage (100 for warriors). The glow alpha comes
-- from UnitPowerPercent curves, so it works even when rage is secret.
-- Rage changes only redraw the fill, number and glow; showing or hiding the
-- bar is checked on combat, Edit Mode and setting changes.
-- Events: UNIT_POWER_UPDATE, UNIT_MAXPOWER (player), PLAYER_ENTERING_WORLD,
--   PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED
-- SavedVariables: barOff, marksOff, mark1, mark2, hideTicks, layouts,
--   combatOnly, scale, style, color, border
--------------------------------------------------------------------------------
local RAGE = Enum.PowerType.Rage
local ASSET = "Interface\\AddOns\\" .. addonName .. "\\Assets\\"
local FONT = "Fonts\\FRIZQT__.TTF"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local BASE_W, BASE_H = 268, 38 -- bar size at 100%
local BORDER = { 0.32, 0.28, 0.22, 1 } -- Modern panel edge
local holder, bar, label, glow, glow2, plate, trough
local ticks = {}
local loCurve, hiCurve

--------------------------------------------------------------------------------
-- Marks, glow and value
--------------------------------------------------------------------------------
-- Curve that returns 0 below at (0..1 of max rage) and 1 from at upward.
local function GateCurve(at)
  at = math.min(0.99, math.max(0.01, at))
  local c = C_CurveUtil.CreateCurve()
  c:AddPoint(0, 0)
  c:AddPoint(at - 0.002, 0)
  c:AddPoint(at, 1)
  c:AddPoint(1, 1)
  return c
end

local function BuildCurves()
  loCurve = GateCurve(math.min(db.mark1, db.mark2) / 100)
  hiCurve = GateCurve(math.max(db.mark1, db.mark2) / 100)
end

-- Places the two marks and shows or hides them, their values and the glow
-- ("Disable Marks" turns off both the marks and the glow).
local function ApplyMarks()
  local w, h = bar:GetWidth(), bar:GetHeight()
  for i, tick in ipairs(ticks) do
    local mark = db["mark" .. i]
    tick:ClearAllPoints()
    tick:SetPoint("CENTER", bar, "LEFT", w * mark / 100, 0)
    tick:SetHeight(h + 6)
    tick:SetShown(not db.marksOff)
    tick.text:SetText(mark)
    tick.text:SetShown(not db.hideTicks)
  end
  glow:SetShown(not db.marksOff)
  glow2:SetShown(not db.marksOff)
end

-- Draws the current rage: fill, number and glow. UnitPower may be secret in
-- combat; it is only displayed, and the glow comes from curves.
local function UpdateRage()
  local rage = UnitPower("player", RAGE)
  bar:SetValue(rage)
  label:SetText(rage)
  glow:SetAlpha(UnitPowerPercent("player", RAGE, false, loCurve))
  glow2:SetAlpha(UnitPowerPercent("player", RAGE, false, hiCurve))
end

local function UpdateMax()
  bar:SetMinMaxValues(0, UnitPowerMax("player", RAGE))
  UpdateRage()
end

-- Shows or hides the bar, and redraws it when shown. The bar always shows in
-- Edit Mode so it can be selected even when "only show in combat" or
-- "Disable Rage Bar" would hide it; a disabled bar is shown faded there.
local function UpdateShown()
  local show = LEM:IsInEditMode() or not db.barOff and (not db.combatOnly or UnitAffectingCombat("player"))
  holder:SetShown(show)
  holder:SetAlpha(db.barOff and 0.4 or 1)
  if show then UpdateMax() end
end

ns.On("UNIT_POWER_UPDATE", function() if holder:IsShown() then UpdateRage() end end)
ns.On("UNIT_MAXPOWER", function() if holder:IsShown() then UpdateMax() end end)
ns.On("PLAYER_ENTERING_WORLD", UpdateShown)
ns.On("PLAYER_REGEN_DISABLED", UpdateShown)
ns.On("PLAYER_REGEN_ENABLED", UpdateShown)

-- Nearest whole number to n (number or text), limited to 1..99.
local function MarkValue(n)
  return math.min(99, math.max(1, math.floor((tonumber(n) or 1) + 0.5)))
end

-- Sets both marks from numbers or text and redraws the bar.
function ns.SetMarks(a, b)
  db.mark1, db.mark2 = MarkValue(a), MarkValue(b)
  BuildCurves()
  ApplyMarks()
  UpdateShown()
end

--------------------------------------------------------------------------------
-- Styles and colors
--------------------------------------------------------------------------------
-- inset: bar inset in the holder (left, top, right, bottom)
-- fill / tint: bar texture for red / other colors
-- frame: overlay art (Rage uses the chosen border instead, see BORDERS)
-- trough: background art (Classic also uses full-size glow)
-- label: anchor point, x offset, width; font: size bonus
local STYLES = {
  modern = {
    inset = { 8, 10, 36, 8 }, fill = WHITE, tint = WHITE, bg = { 0.05, 0.04, 0.03, 0.9 },
    label = { "RIGHT", -8, 28 }, font = 0, outline = "", text = { 1, 1, 1 }, tick = { 0.93, 0.88, 0.78, 3 },
  },
  classic = {
    inset = { 3, 3, 3, 3 }, fill = ASSET .. "classic-rage", tint = ASSET .. "classic-tint", bg = { 0, 0, 0, 0 },
    frame = ASSET .. "classic-frame", trough = ASSET .. "classic-bg",
    label = { "CENTER", 0, 72 }, font = 0, outline = "OUTLINE", text = { 1, 0.82, 0 }, tick = { 1, 0.82, 0.2, 2 },
  },
  rage = {
    inset = { 6, 6, 6, 6 }, fill = ASSET .. "fury-fill", tint = ASSET .. "fury-tint", bg = { 0.05, 0.02, 0.01, 0.9 },
    label = { "RIGHT", -10, 40 }, font = 1, outline = "OUTLINE", text = { 1, 0.9, 0.72 }, tick = { 1, 0.42, 0.18, 2 },
  },
}

-- Rage style borders ("none" has no entry). out: how far the art sticks out
-- past the holder (left, top, right, bottom) in px at 100% size, for spikes,
-- chains and blade tips. Every border leaves the bar's 6 px inset clear.
local NO_OUT = { 0, 0, 0, 0 }
local BORDERS = {
  iron = { file = "border-iron", out = NO_OUT },
  riveted = { file = "border-riveted", out = { 2, 2, 2, 2 } },
  spiked = { file = "border-spiked", out = { 1, 8, 1, 8 } },
  bronze = { file = "border-bronze", out = { 1, 1, 1, 1 } },
  chain = { file = "border-chain", out = { 2, 5, 2, 5 } },
  molten = { file = "border-molten", out = NO_OUT },
  lava = { file = "border-lava", out = { 4, 4, 4, 4 } },
  blade = { file = "border-blade", out = { 12, 4, 12, 4 } },
}

local COLORS = {
  red = { bar = { 0.86, 0.18, 0.14 }, glow = { 0.95, 0.16, 0.08 }, glow2 = { 0.70, 0.28, 0.08 } },
  blue = { bar = { 0.25, 0.55, 1.0 }, glow = { 0.15, 0.40, 1.0 }, glow2 = { 0.30, 0.50, 0.70 } },
  yellow = { bar = { 1.0, 0.78, 0.12 }, glow = { 1.0, 0.72, 0.08 }, glow2 = { 0.70, 0.58, 0.22 } },
  green = { bar = { 0.20, 0.85, 0.28 }, glow = { 0.10, 0.70, 0.18 }, glow2 = { 0.28, 0.62, 0.24 } },
}

local function ApplyStyle()
  local s, c = STYLES[db.style], COLORS[db.color]
  local red = db.color == "red"
  local tex = red and s.fill or s.tint

  -- Background: Modern draws the holder panel; the others use their art.
  local panel = db.style == "modern"
  holder:SetBackdropColor(0.07, 0.07, 0.08, panel and 0.82 or 0)
  holder:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], panel and 1 or 0)
  local b = db.style == "rage" and BORDERS[db.border]
  local frame, out, p = b and ASSET .. b.file or s.frame, b and b.out or NO_OUT, db.scale / 100
  plate:ClearAllPoints()
  plate:SetPoint("TOPLEFT", -out[1] * p, out[2] * p)
  plate:SetPoint("BOTTOMRIGHT", out[3] * p, -out[4] * p)
  plate:SetTexture(frame)
  plate:SetShown(frame ~= nil)
  trough:SetTexture(s.trough)
  trough:SetShown(s.trough ~= nil)

  -- Fill: red art keeps its own colors, everything else is tinted.
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", s.inset[1], -s.inset[2])
  bar:SetPoint("BOTTOMRIGHT", -s.inset[3], s.inset[4])
  bar:SetStatusBarTexture(tex)
  if red and tex ~= WHITE then bar:SetStatusBarColor(1, 1, 1) else bar:SetStatusBarColor(unpack(c.bar)) end
  bar.bg:SetColorTexture(unpack(s.bg))

  -- Glow: Classic glows in the bar's art shape, the others are a flat inset fill.
  local inset = s.trough and 0 or 1
  for i, g in ipairs({ glow, glow2 }) do
    g.tex:SetTexture(s.trough and tex or WHITE)
    g.tex:SetVertexColor(unpack(i == 1 and c.glow or c.glow2))
    g:ClearAllPoints()
    g:SetPoint("TOPLEFT", inset, -inset)
    g:SetPoint("BOTTOMRIGHT", -inset, inset)
  end

  -- Rage number, scaled with bar size.
  label:ClearAllPoints()
  label:SetPoint(s.label[1], holder, s.label[1], s.label[2], 0)
  label:SetWidth(s.label[3])
  label:SetJustifyH(s.label[1])
  label:SetFont(FONT, math.max(10, math.floor(12 * db.scale / 100)) + s.font, s.outline)
  label:SetTextColor(unpack(s.text))

  for _, tick in ipairs(ticks) do
    tick:SetWidth(s.tick[4])
    tick.tex:SetVertexColor(s.tick[1], s.tick[2], s.tick[3])
    tick.text:SetTextColor(s.tick[1], s.tick[2], s.tick[3])
  end
  ApplyMarks()
end

local function ApplySize()
  local p = db.scale / 100
  holder:SetSize(BASE_W * p, BASE_H * p)
  ApplyStyle()
end

--------------------------------------------------------------------------------
-- Edit Mode: position and settings
-- LibEditMode registers the bar with Blizzard's Edit Mode: it draws the
-- selection highlight, handles dragging, arrow-key nudges and "Reset To
-- Default Position", shows the settings panel when the bar is selected, and
-- reports the active Edit Mode layout. Positions are saved per layout name in
-- db.layouts, so each layout keeps its own spot; layouts created as copies,
-- renamed or deleted are kept in step. Panel settings are per character (the
-- same in every layout). Outside Edit Mode the bar takes no mouse input, so
-- clicks pass through to the world.
-- LibEditMode does not snap custom frames to the grid or to other frames.
--------------------------------------------------------------------------------
local DEFAULT_POS = { point = "CENTER", x = 0, y = -170 }
local layoutName -- active Edit Mode layout; nil until the game reports it

local function ApplyPosition()
  local p = layoutName and db.layouts[layoutName] or DEFAULT_POS
  holder:ClearAllPoints()
  holder:SetPoint(p.point, UIParent, p.point, p.x, p.y)
end

-- LibEditMode callback after the bar is dragged, nudged or reset in Edit Mode.
local function OnMoved(_, layout, point, x, y)
  db.layouts[layout] = { point = point, x = x, y = y }
end

-- One panel setting bound to db[key]: apply runs after a change, disabled
-- greys it out, extra holds the kind's own fields. The layout name LibEditMode
-- passes is ignored because these settings are per character.
local function Option(kind, name, key, apply, disabled, extra)
  local s = {
    kind = kind, name = name, default = ns.DEFAULTS[key], disabled = disabled,
    get = function() return db[key] end,
    set = function(_, value)
      db[key] = value
      apply()
    end,
  }
  for k, v in pairs(extra or {}) do s[k] = v end
  return s
end

-- Dropdown entries for a ns.LISTS choice list.
local function Choices(key)
  local values = {}
  for _, o in ipairs(ns.LISTS[key]) do values[#values + 1] = { text = o[2], value = o[1] } end
  return { values = values }
end

local function BarOff() return db.barOff end
local function NotRage() return db.style ~= "rage" end
local function MarksOff() return db.barOff or db.marksOff end

local function ApplyMarkValues()
  ns.SetMarks(db.mark1, db.mark2)
end

local function RegisterEditMode()
  local T = LEM.SettingType
  local mark = { minValue = 1, maxValue = 99, valueStep = 1 }
  local borders = Choices("border")
  borders.hidden = NotRage -- the Style dropdown refreshes the panel, so this follows it
  LEM:AddFrame(holder, OnMoved, DEFAULT_POS, "WU Rage Bar")
  LEM:AddFrameSettings(holder, {
    Option(T.Checkbox, "Disable Rage Bar", "barOff", UpdateShown),
    Option(T.Checkbox, "Only Show in Combat", "combatOnly", UpdateShown, BarOff),
    Option(T.Slider, "Bar Size (%)", "scale", ApplySize, BarOff, { minValue = 50, maxValue = 200, valueStep = 5 }),
    Option(T.Dropdown, "Style", "style", ApplyStyle, BarOff, Choices("style")),
    Option(T.Dropdown, "Border", "border", ApplyStyle, BarOff, borders),
    Option(T.Dropdown, "Color", "color", ApplyStyle, BarOff, Choices("color")),
    Option(T.Checkbox, "Disable Marks", "marksOff", ApplyMarks, BarOff),
    Option(T.Slider, "Mark I", "mark1", ApplyMarkValues, MarksOff, mark),
    Option(T.Slider, "Mark II", "mark2", ApplyMarkValues, MarksOff, mark),
    Option(T.Checkbox, "Hide Mark Values", "hideTicks", ApplyMarks, MarksOff),
  })
  LEM:RegisterCallback("layout", function(name)
    layoutName = name
    ApplyPosition()
  end)
  LEM:RegisterCallback("create", function(name, _, source)
    if source and db.layouts[source] then db.layouts[name] = CopyTable(db.layouts[source]) end
  end)
  LEM:RegisterCallback("rename", function(old, new)
    db.layouts[new], db.layouts[old] = db.layouts[old], nil
  end)
  LEM:RegisterCallback("delete", function(name) db.layouts[name] = nil end)
  LEM:RegisterCallback("enter", UpdateShown)
  LEM:RegisterCallback("exit", UpdateShown)
end

--------------------------------------------------------------------------------
-- Building the bar
--------------------------------------------------------------------------------
-- Plain frame over the holder at a fixed level above it.
local function Layer(level)
  local f = CreateFrame("Frame", nil, holder)
  f:SetAllPoints()
  f:SetFrameLevel(holder:GetFrameLevel() + level)
  return f
end

-- Glow layer over the fill. UpdateRage gates its alpha by rage; the pulse
-- (from -> to alpha over dur seconds) loops forever.
local function FlashLayer(from, to, dur)
  local gate = CreateFrame("Frame", nil, bar)
  gate:SetAlpha(0)
  local flash = CreateFrame("Frame", nil, gate)
  flash:SetAllPoints()
  gate.tex = flash:CreateTexture(nil, "ARTWORK")
  gate.tex:SetAllPoints()
  gate.tex:SetBlendMode("ADD")
  local ag = flash:CreateAnimationGroup()
  ag:SetLooping("BOUNCE")
  local a = ag:CreateAnimation("Alpha")
  a:SetFromAlpha(from)
  a:SetToAlpha(to)
  a:SetDuration(dur)
  ag:Play()
  return gate
end

local function MakeTick()
  local f = CreateFrame("Frame", nil, holder)
  f:SetFrameLevel(holder:GetFrameLevel() + 8)
  f.tex = f:CreateTexture(nil, "OVERLAY")
  f.tex:SetAllPoints()
  f.tex:SetColorTexture(1, 1, 1, 1)
  f.tex:SetBlendMode("ADD")
  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.text:SetPoint("BOTTOM", f, "TOP", 0, 2)
  return f
end

-- Applies every bar setting: marks, position, size, style and visibility.
-- Used when the bar is built and after /wu reset.
function ns.RefreshBar()
  BuildCurves()
  ApplyPosition()
  ApplySize()
  UpdateShown()
end

function ns.BuildBar()
  -- Flat panel with a 1px edge; ApplyStyle sets its colors per style.
  holder = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  holder:SetClampedToScreen(true)
  holder:SetBackdrop({
    bgFile = WHITE, edgeFile = WHITE, tile = true, tileSize = 8, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })

  trough = holder:CreateTexture(nil, "BACKGROUND")
  trough:SetAllPoints()

  bar = CreateFrame("StatusBar", nil, holder)
  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints()
  bar:SetScript("OnSizeChanged", ApplyMarks)
  glow = FlashLayer(0.22, 0.55, 0.70)
  glow2 = FlashLayer(0.16, 0.38, 0.36)

  plate = Layer(12):CreateTexture(nil, "ARTWORK") -- anchored by ApplyStyle
  label = Layer(14):CreateFontString(nil, "OVERLAY")
  ticks[1], ticks[2] = MakeTick(), MakeTick()

  ns.RefreshBar()
  RegisterEditMode()
end
