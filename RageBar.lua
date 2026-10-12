local _, ns = ...
local db, WHITE, BORDER, LEM = ns.db, ns.WHITE, ns.BORDER, ns.LibEditMode

--------------------------------------------------------------------------------
-- Rage bar
-- The bar: rage fill and number, two marks with a glow past each, three
-- styles, four colors, size, "only show in combat", and switches to turn off
-- the marks or the whole bar. It is moved and set up in Blizzard's Edit Mode
-- (see Edit Mode below).
-- Marks are a percent of max rage (100 for warriors). The glow alpha comes
-- from UnitPowerPercent curves, so it works even when rage is secret.
-- Events: UNIT_POWER_UPDATE, UNIT_MAXPOWER (player), PLAYER_ENTERING_WORLD,
--   PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED
-- SavedVariables: barOff, marksOff, mark1, mark2, hideTicks, layouts,
--   combatOnly, scale, style, color
--------------------------------------------------------------------------------
local RAGE = Enum.PowerType.Rage
local ASSET = ns.ROOT .. "Assets\\"
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
ns.BuildCurves = BuildCurves

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

function ns.SetMarks(a, b)
  db.mark1, db.mark2 = ns.Clamp(a, 1, 99), ns.Clamp(b, 1, 99)
  BuildCurves()
  ApplyMarks()
end

-- Shows or hides the bar and draws the current rage. The bar always shows in
-- Edit Mode so it can be selected even when "only show in combat" or
-- "Disable Rage Bar" would hide it; a disabled bar is shown faded there.
local function Update()
  local show = LEM:IsInEditMode() or not db.barOff and (not db.combatOnly or ns.InCombat())
  holder:SetShown(show)
  if not show then return end
  holder:SetAlpha(db.barOff and 0.4 or 1)
  local rage = UnitPower("player", RAGE)
  bar:SetMinMaxValues(0, UnitPowerMax("player", RAGE))
  bar:SetValue(rage)
  label:SetText(rage)
  glow:SetAlpha(UnitPowerPercent("player", RAGE, false, loCurve))
  glow2:SetAlpha(UnitPowerPercent("player", RAGE, false, hiCurve))
end
ns.Update = Update

ns.On("UNIT_POWER_UPDATE", Update)
ns.On("UNIT_MAXPOWER", Update)
ns.On("PLAYER_ENTERING_WORLD", Update)
ns.On("PLAYER_REGEN_DISABLED", Update)
ns.On("PLAYER_REGEN_ENABLED", Update)

--------------------------------------------------------------------------------
-- Styles and colors
--------------------------------------------------------------------------------
-- inset: bar inset in the holder (left, top, right, bottom)
-- fill / tint: bar texture for red / other colors
-- frame: overlay art; trough: background art (Classic also uses full-size glow)
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
    frame = ASSET .. "fury-frame",
    label = { "RIGHT", -10, 40 }, font = 1, outline = "OUTLINE", text = { 1, 0.9, 0.72 }, tick = { 1, 0.42, 0.18, 2 },
  },
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
  holder:SetBackdropColor(0.07, 0.07, 0.08, s.frame and 0 or 0.82)
  holder:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], s.frame and 0 or 1)
  plate:SetTexture(s.frame)
  plate:SetShown(s.frame ~= nil)
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
  label:SetFont(ns.FONT, math.max(10, math.floor(12 * db.scale / 100)) + s.font, s.outline)
  label:SetTextColor(unpack(s.text))

  for _, tick in ipairs(ticks) do
    tick:SetWidth(s.tick[4])
    tick.tex:SetVertexColor(s.tick[1], s.tick[2], s.tick[3])
    tick.text:SetTextColor(s.tick[1], s.tick[2], s.tick[3])
  end
  ApplyMarks()
end
ns.ApplyStyle = ApplyStyle

function ns.ApplySize()
  local p = db.scale / 100
  holder:SetSize(ns.BASE_W * p, ns.BASE_H * p)
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

function ns.ApplyPosition()
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
local function MarksOff() return db.barOff or db.marksOff end

local function ApplyMarkValues()
  ns.SetMarks(db.mark1, db.mark2)
  Update()
end

local function RegisterEditMode()
  local T = LEM.SettingType
  local mark = { minValue = 1, maxValue = 99, valueStep = 1 }
  LEM:AddFrame(holder, OnMoved, DEFAULT_POS, "WU Rage Bar")
  LEM:AddFrameSettings(holder, {
    Option(T.Checkbox, "Disable Rage Bar", "barOff", Update),
    Option(T.Checkbox, "Only Show in Combat", "combatOnly", Update, BarOff),
    Option(T.Slider, "Bar Size (%)", "scale", ns.ApplySize, BarOff, { minValue = 50, maxValue = 200, valueStep = 5 }),
    Option(T.Dropdown, "Style", "style", ApplyStyle, BarOff, Choices("style")),
    Option(T.Dropdown, "Color", "color", ApplyStyle, BarOff, Choices("color")),
    Option(T.Checkbox, "Disable Marks", "marksOff", ApplyMarks, BarOff),
    Option(T.Slider, "Mark I", "mark1", ApplyMarkValues, MarksOff, mark),
    Option(T.Slider, "Mark II", "mark2", ApplyMarkValues, MarksOff, mark),
    Option(T.Checkbox, "Hide Mark Values", "hideTicks", ApplyMarks, MarksOff),
  })
  LEM:RegisterCallback("layout", function(name)
    layoutName = name
    ns.ApplyPosition()
  end)
  LEM:RegisterCallback("create", function(name, _, source)
    if source and db.layouts[source] then db.layouts[name] = CopyTable(db.layouts[source]) end
  end)
  LEM:RegisterCallback("rename", function(old, new)
    db.layouts[new], db.layouts[old] = db.layouts[old], nil
  end)
  LEM:RegisterCallback("delete", function(name) db.layouts[name] = nil end)
  LEM:RegisterCallback("enter", Update)
  LEM:RegisterCallback("exit", Update)
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

-- Glow layer over the fill. Update gates its alpha by rage; the pulse
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

function ns.BuildBar()
  holder = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  holder:SetClampedToScreen(true)
  ns.Paint(holder, 0.82)

  trough = holder:CreateTexture(nil, "BACKGROUND")
  trough:SetAllPoints()

  bar = CreateFrame("StatusBar", nil, holder)
  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints()
  bar:SetScript("OnSizeChanged", ApplyMarks)
  glow = FlashLayer(0.22, 0.55, 0.70)
  glow2 = FlashLayer(0.16, 0.38, 0.36)

  plate = Layer(12):CreateTexture(nil, "ARTWORK")
  plate:SetAllPoints()
  label = Layer(14):CreateFontString(nil, "OVERLAY")
  ticks[1], ticks[2] = MakeTick(), MakeTick()

  BuildCurves()
  ns.ApplyPosition()
  ns.ApplySize()
  RegisterEditMode()
end
