-- Cursor Reticle: rings, a dot or crosshair, health and a spell's cooldown around the cursor,
-- with an options window (/cr).

local ADDON_NAME = "CursorReticle";
local MEDIA = "Interface\\AddOns\\CursorReticle\\Textures\\";
local THICKNESS_NAMES = { "Hairline", "Thin", "Medium", "Thick", "Heavy" };
-- Texture shapes (see make-ring-textures.ps1): the rings' outer radius and the line width of
-- ring1 .. ring5 as a share of their size, the band widths of edge1 .. edgeN in texture
-- pixels of 128, and the dot's radius as a share of its size.
local RING_OUTER = 62 / 128;
local RING_WIDTH = { 3 / 128, 5 / 128, 8 / 128, 12 / 128, 17 / 128 };
local EDGE_OUTER = 62;
local EDGE_WIDTHS = { 0.5, 0.75, 1, 1.25, 1.5, 2, 2.5, 3, 3.5, 4, 5, 6, 7, 8, 10, 12, 14, 17, 20, 24, 30 };
local DOT_RADIUS = 14.5 / 32;

local TAB_NAMES = { "Circle", "Health circle", "Center", "Low health", "Cooldown sweep", "Text" };
local TAB_SIZES = { { 540, 492 }, { 590, 420 }, { 540, 500 }, { 540, 310 }, { 590, 500 }, { 540, 440 } };

-- Where the text goes around the rings: the text's anchor point, and the direction away from
-- the cursor.
local TEXT_POSITIONS = { "below", "above", "right", "left" };
local TEXT_POSITION_NAMES = { below = "Below the circle", above = "Above the circle", right = "Right of the circle", left = "Left of the circle" };
-- The text's font: the four fonts every 1.12 client has, and Barlow Semi Condensed, which
-- comes with the addon (SIL Open Font License, in the Fonts folder).
local TEXT_FONTS = { "friz", "barlow", "arial", "skurri", "morpheus" };
local TEXT_FONT_NAMES = {
	friz = "Friz Quadrata", barlow = "Barlow Semi Condensed", arial = "Arial Narrow",
	skurri = "Skurri", morpheus = "Morpheus",
};
local TEXT_FONT_FILES = {
	friz = "Fonts\\FRIZQT__.TTF", arial = "Fonts\\ARIALN.TTF",
	skurri = "Fonts\\skurri.ttf", morpheus = "Fonts\\MORPHEUS.TTF",
	barlow = "Interface\\AddOns\\CursorReticle\\Fonts\\BarlowSemiCondensed-SemiBold.ttf",
};
local TEXT_ANCHORS = {
	below = { "TOP", 0, -1 }, above = { "BOTTOM", 0, 1 },
	right = { "LEFT", 1, 0 }, left = { "RIGHT", -1, 0 },
};
local TEXT_GAP = 4;           -- space between the outermost ring and the text

-- The ring shown beside the cooldown sweep: where, and which one.
local RING_POSITIONS = { "hidden", "inside", "outside" };
local RING_POSITION_NAMES = { hidden = "Hidden", inside = "Inside the sweep", outside = "Outside the sweep" };
local RING_TYPES = { "ring", "health" };
local RING_TYPE_NAMES = { ring = "Main circle", health = "Health circle" };

local PI = 3.14159265;
local SWEEP_MAX_DOTS = 200;
local SWEEP_SPACING = 0.4;    -- gap between a fill's dots, as a share of their size
local RING_GAP = 2;           -- space between the sweep and a ring beside it
local PULSE_SPEED = 1.5;      -- pulses per second
local PULSE_GROW = 0.2;       -- how much bigger the rings get at the top of a pulse
local GREYED = 0.4;           -- opacity of options that don't apply right now
local PREVIEW_COOLDOWN = 2.5; -- the test cooldown the sweep preview repeats
local RETRY_SHARE = 0.5;      -- a ready spell's restart shorter than this share of its
                              -- cooldown is a retry, not a cast (see UpdateSweep)
local HEALTH_PREVIEW = 5;     -- seconds the health preview takes to drain from full
local HEALTH_MISSING = 0.3;   -- opacity of the health ring's missing part, in the fill color
-- The health preview with a shield: steps of { seconds, health from, to, shield from, to },
-- as shares of max health. A shield takes the damage first, so health holds while it lasts.
local SHIELD_PREVIEW = {
	{ 1.5, 1, 1, 0.3, 0 },        -- a shield at full health is used up
	{ 2.5, 1, 0.5, 0, 0 },        -- then health drops
	{ 1.5, 0.5, 0.5, 0.4, 0 },    -- a new shield goes up and is used up
	{ 2.5, 0.5, 0, 0, 0 },        -- then health drains to nothing
};
-- Colors by health: { share of full health, r, g, b }, blended in between.
local HEALTH_COLORS = {
	{ 0, 1, 0.1, 0.1 },        -- red
	{ 0.33, 1, 0.5, 0 },       -- orange
	{ 0.66, 1, 0.9, 0.1 },     -- yellow
	{ 1, 0.1, 0.9, 0.1 },      -- green
};
local RUN_PHASES = { playing = true, choosing = true, paused = true };

-- Colors are stored as <prefix>r, <prefix>g, <prefix>b: "" ring, "ro" ring outline,
-- "h" health fill, "hs" health shield, "ho" health outline, "c" center, "co" center outline,
-- "l" low health, "sm" sweep main, "s" sweep fill, "so" sweep outline, "t" text.
local DEFAULTS = {
	enabled = true,            -- the whole addon

	showRing = true,
	size = 35,
	thickness = 4,
	alpha = 100,
	r = 0.2, g = 1, b = 1,
	ringOutline = false,
	ringOutlineWidth = 1,
	ror = 0, rog = 0, rob = 0,

	-- The health ring takes the ring's place: it fills with health, in the fill color (or
	-- colored by health), and shows the missing part in the same color, faintly.
	healthEnabled = false,
	healthSync = true,         -- use the main ring's size and thickness
	healthSize = 35,
	healthThickness = 4,
	healthGradient = true,     -- green to red by health, instead of the fill color
	hr = 0.2, hg = 1, hb = 0.2,
	healthAlpha = 100,         -- fill opacity
	healthShield = false,      -- the absorb shield over the end of the health fill
	hsr = 0.4, hsg = 0.75, hsb = 1,
	healthOutline = false,
	healthOutlineWidth = 1,
	hor = 0, hog = 0, hob = 0,

	centerDot = false,         -- at most one of centerDot and centerCross is on
	centerCross = false,
	centerSize = 12,
	centerThickness = 2,       -- crosshair line width
	centerAlpha = 100,
	centerByHealth = false,    -- colored by health, like the health ring, instead of its color
	cr = 0.2, cg = 1, cb = 1,
	centerOutline = false,
	centerOutlineWidth = 1,
	cor = 0, cog = 0, cob = 0,

	lowRed = false,            -- the main ring turns the warning color
	lowCenter = false,         -- the dot / crosshair turns the warning color
	lowSweepMain = false,      -- the sweep's main ring turns the warning color
	lowSweepFill = false,      -- the sweep's fill turns the warning color
	lowPulse = false,
	lowAt = 30,
	lr = 1, lg = 0.1, lb = 0.1,

	-- The cooldown sweep takes the place of the other rings: a ring in the main color that
	-- fills with the fill color as the spell recharges. The main ring or the health ring can
	-- stay beside it, inside or outside.
	sweepEnabled = false,
	track = {},                -- class key -> the AZS_SPELLS key the sweep follows
	seen = {},                 -- class key -> every AZS_SPELLS key seen for that class
	sweepRingPos = "hidden",
	sweepRingType = "ring",
	sweepSync = true,          -- use the ring's size and thickness (while no ring is beside it)
	sweepRingSize = 35,
	sweepRingThickness = 4,
	sweepAlpha = 25,           -- main color opacity
	smr = 1, smg = 1, smb = 1,
	sweepFillAlpha = 100,
	sr = 0.2, sg = 1, sb = 1,
	sweepOutline = true,
	sweepOutlineWidth = 1,
	sor = 0, sog = 0, sob = 0,

	-- Text beside the rings.
	textHealth = false,        -- health %
	textShield = false,        -- the absorb shield after the health %, as a share of max health
	textCooldown = false,      -- seconds left on the sweep's spell
	textPos = "below",
	textSize = 12,
	textFont = "friz",
	textByHealth = true,       -- health % colored by health
	tr = 1, tg = 1, tb = 1,
};

-- Ability keys whose name can't be worked out from the key itself.
local SPELL_NAMES = {
	sw_pain = "Shadow Word: Pain",
	pw_shield = "Power Word: Shield",
	demo_shout = "Demoralizing Shout",
	hunters_mark = "Hunter's Mark",
};

local PRESETS = {
	{ 1, 1, 1 },        -- white
	{ 1, 0.82, 0 },     -- gold
	{ 1, 0.5, 0 },      -- orange
	{ 1, 0.1, 0.1 },    -- red
	{ 1, 0.35, 0.8 },   -- pink
	{ 0.6, 0.3, 1 },    -- purple
	{ 0.2, 0.5, 1 },    -- blue
	{ 0.2, 1, 1 },      -- cyan
	{ 0.2, 1, 0.2 },    -- green
};

local db;
local options;
local refreshing = false;   -- true while the options window copies db into its widgets

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd200Cursor Reticle:|r " .. msg);
end

---------------------------------------------------------------------------
-- Game data
---------------------------------------------------------------------------

local function Phase()
	if ( AZS_GetPhase ) then
		return AZS_GetPhase();
	end
end

local function RunTime()
	return AZS_GetRunTime and AZS_GetRunTime() or 0;
end

-- Health and absorb shield as shares of max health, during a run (nil outside one).
local function HealthFraction()
	local run = AZS_RUN;
	if ( not RUN_PHASES[Phase()] or type(run) ~= "table" or not run.hp or not run.hpm or run.hpm <= 0 ) then
		return nil;
	end
	return run.hp / run.hpm, (run.sh or 0) / run.hpm;
end

local function CurrentClass()
	local zone = AZS_ZONE;
	if ( type(zone) == "table" and zone.class and zone.class ~= "" ) then
		return zone.class, zone.cname;
	end
end

local function TrackedKey()
	local class = CurrentClass();
	if ( class ) then
		return db.track[class];
	end
end

local function FindSpell(key)
	local spells = AZS_SPELLS;
	if ( type(spells) ~= "table" ) then return nil; end
	for i = 1, table.getn(spells) do
		if ( spells[i].key == key ) then
			return spells[i];
		end
	end
end

-- "frost_nova" or "frostNova" -> "Frost Nova".
local function Prettify(key)
	local s = string.gsub(key, "_", " ");
	s = string.gsub(s, "(%l)(%u)", "%1 %2");
	s = string.gsub(s, "(%a)([%w']*)", function(first, rest) return string.upper(first) .. rest; end);
	return s;
end

local function SpellName(key)
	if ( SPELL_NAMES[key] ) then return SPELL_NAMES[key]; end
	local entry = FindSpell(key);
	if ( entry and GetSpellInfo ) then
		local name = GetSpellInfo(entry.spell);
		if ( name ) then return name; end
	end
	return Prettify(key);
end

-- The game only lists the spells of the current run, so every spell seen is remembered per
-- class (in the saved variables): the sweep can then be set to a spell before it is learned
-- in a later run.
local seenIndex = {};   -- class key -> set of the keys in db.seen[class], built on first use

local function RecordSpells()
	local class = CurrentClass();
	local spells = AZS_SPELLS;
	if ( not class or type(spells) ~= "table" ) then return; end
	local seen = db.seen[class];
	if ( not seen ) then
		seen = {};
		db.seen[class] = seen;
	end
	local index = seenIndex[class];
	if ( not index ) then
		index = {};
		for i = 1, table.getn(seen) do
			index[seen[i]] = true;
		end
		seenIndex[class] = index;
	end
	for i = 1, table.getn(spells) do
		local key = spells[i].key;
		if ( key and not index[key] ) then
			index[key] = true;
			table.insert(seen, key);
		end
	end
end

-- The spells seen for the class as { key, name }, sorted by name.
local function SeenSpells(class)
	local list = {};
	local seen = db.seen[class] or {};
	for i = 1, table.getn(seen) do
		table.insert(list, { key = seen[i], name = SpellName(seen[i]) });
	end
	table.sort(list, function(a, b) return a.name < b.name; end);
	return list;
end

---------------------------------------------------------------------------
-- What is drawn
---------------------------------------------------------------------------

-- One ring sits around the cursor: the cooldown sweep if it is on, else the health ring if
-- it is on, else the main ring. Beside the sweep, the main ring or the health ring can stay.
local function ExtraRingShown()
	return db.sweepEnabled and db.sweepRingPos ~= "hidden";
end

-- Whether ring <kind> ("ring" or "health") is the one shown beside the sweep.
local function BesideSweep(kind)
	return ExtraRingShown() and db.sweepRingType == kind;
end

local function MainRingVisible()
	if ( db.sweepEnabled ) then return BesideSweep("ring"); end
	return db.showRing and not db.healthEnabled;
end

local function HealthRingVisible()
	if ( db.sweepEnabled ) then return BesideSweep("health"); end
	return db.healthEnabled;
end

-- Whether a ring of any kind is drawn, for the pulse.
local function AnyRing()
	return db.sweepEnabled or db.healthEnabled or db.showRing;
end

-- The sweep shares the ring's size and thickness only while no ring is beside it.
local function SweepSynced()
	return db.sweepSync and not ExtraRingShown();
end

local function SweepSize()
	return SweepSynced() and db.size or db.sweepRingSize;
end

local function SweepThickness()
	return SweepSynced() and db.thickness or db.sweepRingThickness;
end

local function RingOutlineWidth()
	return db.ringOutline and db.ringOutlineWidth or 0;
end

local function HealthOutlineWidth()
	return db.healthOutline and db.healthOutlineWidth or 0;
end

local function SweepOutlineWidth()
	return db.sweepOutline and db.sweepOutlineWidth or 0;
end

local function CenterOutlineWidth()
	return db.centerOutline and db.centerOutlineWidth or 0;
end

-- The size that puts a ring of thickness <k>, with an outline <w> wide, just inside or
-- outside the sweep.
local function SizeBesideSweep(k, w)
	local s = SweepSize();
	local outer = s * RING_OUTER;
	local inner = outer - s * RING_WIDTH[SweepThickness()];
	local gap = SweepOutlineWidth() + w + RING_GAP;
	if ( db.sweepRingPos == "inside" ) then
		return math.max(4, (inner - gap) / RING_OUTER);
	end
	-- Outside: the ring's inner edge at outer + gap; its line is a fixed share of its size.
	return (outer + gap) / (RING_OUTER - RING_WIDTH[k]);
end

local function MainRingSize()
	if ( BesideSweep("ring") ) then
		return SizeBesideSweep(db.thickness, RingOutlineWidth());
	end
	return db.size;
end

local function HealthThickness()
	return db.healthSync and db.thickness or db.healthThickness;
end

local function HealthRingSize()
	if ( BesideSweep("health") ) then
		return SizeBesideSweep(HealthThickness(), HealthOutlineWidth());
	end
	return db.healthSync and db.size or db.healthSize;
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local function SetSize(region, width, height)
	region:SetWidth(width);
	region:SetHeight(height);
end

local function ShowIf(region, shown)
	if ( shown ) then region:Show(); else region:Hide(); end
end

-- Shows <t> as a band <width> wide whose outer edge is <radius> from the center: the edge
-- texture whose band, scaled to put its outer edge at <radius>, comes closest to <width>.
-- Outlines are drawn this way, beside the line rather than under it, so a see-through line
-- doesn't show its outline through it.
local function PlaceEdge(t, radius, width)
	if ( width <= 0 or radius <= width ) then
		t:Hide();
		return;
	end
	local want = width / radius * EDGE_OUTER;
	local best = 1;
	for i = 2, table.getn(EDGE_WIDTHS) do
		if ( math.abs(EDGE_WIDTHS[i] - want) < math.abs(EDGE_WIDTHS[best] - want) ) then
			best = i;
		end
	end
	t:SetTexture(MEDIA .. "Edges\\edge" .. best);
	SetSize(t, radius / RING_OUTER, radius / RING_OUTER);
	t:Show();
end

-- A ring: its line, and the outline's bands outside and inside it.
local function CreateRingObject(parent)
	local o = {};
	o.line = parent:CreateTexture(nil, "ARTWORK");
	o.outerEdge = parent:CreateTexture(nil, "BORDER");
	o.innerEdge = parent:CreateTexture(nil, "BORDER");
	o.line:SetPoint("CENTER", parent, "CENTER", 0, 0);
	o.outerEdge:SetPoint("CENTER", parent, "CENTER", 0, 0);
	o.innerEdge:SetPoint("CENTER", parent, "CENTER", 0, 0);
	return o;
end

-- Draws ring <o> <size> wide at thickness <k> in <r, g, b> at opacity <a>, with an outline
-- <w> wide (none for 0) in the color <prefix>r/g/b; or hides it.
local function DrawRing(o, shown, size, k, r, g, b, a, w, prefix)
	ShowIf(o.line, shown);
	if ( not shown or w <= 0 ) then
		o.outerEdge:Hide();
		o.innerEdge:Hide();
	end
	if ( not shown ) then return; end
	o.line:SetTexture(MEDIA .. "Rings\\ring" .. k);
	SetSize(o.line, size, size);
	o.line:SetVertexColor(r, g, b, a);
	if ( w > 0 ) then
		local outer = size * RING_OUTER;
		PlaceEdge(o.outerEdge, outer + w, w);
		PlaceEdge(o.innerEdge, outer - size * RING_WIDTH[k], w);
		o.outerEdge:SetVertexColor(db[prefix .. "r"], db[prefix .. "g"], db[prefix .. "b"]);
		o.innerEdge:SetVertexColor(db[prefix .. "r"], db[prefix .. "g"], db[prefix .. "b"]);
	end
end

-- A fill: dots along a ring's line, shown from the top clockwise up to a share of the way
-- round, in a frame of its own (above the rings) for its opacity.
local function CreateFill(parent)
	local frame = CreateFrame("Frame", nil, parent);
	frame:SetFrameStrata("TOOLTIP");
	frame:SetWidth(1);
	frame:SetHeight(1);
	frame:SetPoint("CENTER", parent, "CENTER", 0, 0);
	-- count: dots in use for the current size; lit: dots shown, -1 while hidden
	return { frame = frame, dots = {}, count = 0, lit = -1 };
end

-- Follows the cursor and holds everything else.
local holder = CreateFrame("Frame", "CursorReticleFrame", UIParent);
holder:SetFrameStrata("TOOLTIP");
holder:SetWidth(1);
holder:SetHeight(1);
holder:Hide();

-- The rings, in a frame of their own so the pulse can scale them together.
local body = CreateFrame("Frame", nil, holder);
body:SetFrameStrata("TOOLTIP");
body:SetWidth(1);
body:SetHeight(1);
body:SetPoint("CENTER", holder, "CENTER", 0, 0);
local ringObj = CreateRingObject(body);    -- the main ring
local hpObj = CreateRingObject(body);      -- the health ring's missing part
local trackObj = CreateRingObject(body);   -- the sweep's main color
local hpFill = CreateFill(body);           -- the health ring's fill
local shieldFill = CreateFill(body);       -- the health ring's shield, over the health's end
local sweepFill = CreateFill(body);        -- the sweep's fill
shieldFill.frame:SetFrameLevel(hpFill.frame:GetFrameLevel() + 1);

-- The center mark, above everything, in a frame of its own for its opacity.
local centerFrame = CreateFrame("Frame", nil, holder);
centerFrame:SetFrameStrata("TOOLTIP");
centerFrame:SetAllPoints(holder);
centerFrame:SetFrameLevel(body:GetFrameLevel() + 3);

local function CenterTexture(layer, texture)
	local t = centerFrame:CreateTexture(nil, layer);
	if ( texture ) then
		t:SetTexture(texture);
	else
		t:SetTexture(1, 1, 1);
	end
	t:SetPoint("CENTER", centerFrame, "CENTER", 0, 0);
	return t;
end

local dot = CenterTexture("ARTWORK", MEDIA .. "dot");
local dotEdge = CenterTexture("BORDER");
local crossH = CenterTexture("ARTWORK");
local crossV = CenterTexture("ARTWORK");
-- The crosshair's outline: strips around the edge of the "+", none under its lines (see
-- LayoutCrossOutline).
local crossOutline = {};
for i = 1, 12 do
	crossOutline[i] = CenterTexture("BORDER");
end

-- The text beside the rings, above everything, unaffected by the pulse.
local textFrame = CreateFrame("Frame", nil, holder);
textFrame:SetFrameStrata("TOOLTIP");
textFrame:SetAllPoints(holder);
textFrame:SetFrameLevel(body:GetFrameLevel() + 4);
local readout = textFrame:CreateFontString(nil, "OVERLAY");

local lowHealth = false;
local pulseTime = 0;
local ringScale = 1;

-- Previews from the options window: low health as if health were low, the sweep on a
-- repeating test cooldown, and the health ring draining. They aren't saved.
local previewLow, previewSweep, previewHealth = false, false, false;
local previewStart, previewHealthStart = 0, 0;

local function Pulsing()
	return lowHealth and db.lowPulse and AnyRing();
end

-- The color <prefix>r/g/b, or the warning color when health is low and <warnKey> is on.
local function WarnableColor(prefix, warnKey)
	if ( lowHealth and db[warnKey] ) then
		return db.lr, db.lg, db.lb;
	end
	return db[prefix .. "r"], db[prefix .. "g"], db[prefix .. "b"];
end

-- The main ring, and the sweep's main color.
local function LayoutRings()
	local r, g, b = WarnableColor("", "lowRed");
	DrawRing(ringObj, MainRingVisible(), MainRingSize(), db.thickness, r, g, b, db.alpha / 100,
		RingOutlineWidth(), "ro");

	r, g, b = WarnableColor("sm", "lowSweepMain");
	DrawRing(trackObj, db.sweepEnabled, SweepSize(), SweepThickness(), r, g, b,
		db.sweepAlpha / 100, SweepOutlineWidth(), "so");
end

-- The health color at <f> (0..1) of full health: green, then yellow, orange and red.
local function HealthColor(f)
	for i = 2, table.getn(HEALTH_COLORS) do
		local hi = HEALTH_COLORS[i];
		if ( f <= hi[1] ) then
			local lo = HEALTH_COLORS[i - 1];
			local t = (f - lo[1]) / (hi[1] - lo[1]);
			return lo[2] + (hi[2] - lo[2]) * t, lo[3] + (hi[3] - lo[3]) * t, lo[4] + (hi[4] - lo[4]) * t;
		end
	end
	local last = HEALTH_COLORS[table.getn(HEALTH_COLORS)];
	return last[2], last[3], last[4];
end

-- The health preview's health and shield at this moment: a plain drain, or with a shield
-- shown, the steps of SHIELD_PREVIEW on a loop.
local function PreviewHealth()
	local t = GetTime() - previewHealthStart;
	if ( not (db.healthShield or db.textShield) ) then
		return 1 - math.mod(t, HEALTH_PREVIEW) / HEALTH_PREVIEW, 0;
	end
	local total = 0;
	for i = 1, table.getn(SHIELD_PREVIEW) do
		total = total + SHIELD_PREVIEW[i][1];
	end
	t = math.mod(t, total);
	for i = 1, table.getn(SHIELD_PREVIEW) do
		local s = SHIELD_PREVIEW[i];
		if ( t < s[1] or i == table.getn(SHIELD_PREVIEW) ) then
			local p = math.min(1, t / s[1]);
			return s[2] + (s[3] - s[2]) * p, s[4] + (s[5] - s[4]) * p;
		end
		t = t - s[1];
	end
end

-- The shares of health and shield to show: the health preview's while it runs, else the
-- player's during a run (nil outside one).
local function HealthShare()
	if ( previewHealth ) then
		return PreviewHealth();
	end
	return HealthFraction();
end

-- Outlines a "+" of arms <s> long and <t> thick with strips <w> wide around its edge, so a
-- see-through crosshair doesn't show the outline through its lines: a cap at each arm's
-- end, and a strip along each side of each arm. The horizontal arms' strips cover the inner
-- corners, so no two strips overlap.
local function LayoutCrossOutline(shown, s, t, w)
	local h, a = s / 2, t / 2;
	local along = h - a;          -- a horizontal arm's side, from the center lines out
	local up = h - a - w;         -- a vertical arm's side, clear of the corners
	local rects = {
		{ 0, h + w / 2, t + 2 * w, w }, { 0, -(h + w / 2), t + 2 * w, w },
		{ -(h + w / 2), 0, w, t + 2 * w }, { h + w / 2, 0, w, t + 2 * w },
		{ -(a + along / 2), a + w / 2, along, w }, { -(a + along / 2), -(a + w / 2), along, w },
		{ a + along / 2, a + w / 2, along, w }, { a + along / 2, -(a + w / 2), along, w },
		{ -(a + w / 2), a + w + up / 2, w, up }, { a + w / 2, a + w + up / 2, w, up },
		{ -(a + w / 2), -(a + w + up / 2), w, up }, { a + w / 2, -(a + w + up / 2), w, up },
	};
	for i = 1, table.getn(crossOutline) do
		local o, r = crossOutline[i], rects[i];
		if ( shown and r[3] > 0 and r[4] > 0 ) then
			o:SetPoint("CENTER", centerFrame, "CENTER", r[1], r[2]);
			SetSize(o, r[3], r[4]);
			o:SetVertexColor(db.cor, db.cog, db.cob);
			o:Show();
		else
			o:Hide();
		end
	end
end

local centerColoredAt;   -- the health the center mark was last colored for

-- The dot and crosshair's color: the warning color at low health, else by health or its own.
local function ColorCenter()
	local r, g, b = WarnableColor("c", "lowCenter");
	if ( db.centerByHealth and not (lowHealth and db.lowCenter) ) then
		r, g, b = HealthColor(centerColoredAt or 1);
	end
	dot:SetVertexColor(r, g, b);
	crossH:SetVertexColor(r, g, b);
	crossV:SetVertexColor(r, g, b);
end

-- Recolors the center mark when it is colored by health and health moved on.
local function UpdateCenterHealthColor()
	if ( not db.centerByHealth ) then return; end
	local f = HealthShare() or 1;
	if ( not centerColoredAt or math.abs(f - centerColoredAt) >= 0.01 ) then
		centerColoredAt = f;
		ColorCenter();
	end
end

local function LayoutCenter()
	local s, t, w = db.centerSize, db.centerThickness, CenterOutlineWidth();
	centerFrame:SetAlpha(db.centerAlpha / 100);
	centerColoredAt = db.centerByHealth and (HealthShare() or 1) or nil;
	ColorCenter();

	SetSize(dot, s, s);
	ShowIf(dot, db.centerDot);
	if ( db.centerDot and w > 0 ) then
		PlaceEdge(dotEdge, s * DOT_RADIUS + w, w);
		dotEdge:SetVertexColor(db.cor, db.cog, db.cob);
	else
		dotEdge:Hide();
	end

	SetSize(crossH, s, t);
	SetSize(crossV, t, s);
	ShowIf(crossH, db.centerCross);
	ShowIf(crossV, db.centerCross);
	LayoutCrossOutline(db.centerCross and w > 0, s, t, w);
end

local function ColorFill(f, r, g, b)
	for i = 1, f.count do
		f.dots[i]:SetVertexColor(r, g, b);
	end
end

-- Places fill <f>'s dots along the middle of the line of a ring <size> wide at thickness <k>,
-- close enough that they overlap into a smooth line; or clears it when not <shown>. Without
-- an outline the fill is a little wider than the line, to cover its soft edges; with one
-- (<w> wide), the extra width would spill onto the outline instead.
local function LayoutFill(f, shown, size, k, w, alpha)
	local width = size * RING_WIDTH[k];
	local radius = size * RING_OUTER - width / 2;
	local dotSize = w > 0 and width or width + 2;
	local n = 0;
	if ( shown and radius >= 4 ) then
		n = math.floor(2 * PI * radius / (dotSize * SWEEP_SPACING));
		n = math.max(12, math.min(SWEEP_MAX_DOTS, n));
	end
	f.frame:SetAlpha(alpha);
	for i = 1, n do
		if ( not f.dots[i] ) then
			f.dots[i] = f.frame:CreateTexture(nil, "ARTWORK");
			f.dots[i]:SetTexture(MEDIA .. "dot");
		end
		local a = (i - 0.5) / n * 2 * PI;
		f.dots[i]:SetPoint("CENTER", f.frame, "CENTER", radius * math.sin(a), radius * math.cos(a));
		SetSize(f.dots[i], dotSize, dotSize);
	end
	for i = 1, table.getn(f.dots) do
		f.dots[i]:Hide();
	end
	f.count = n;
	f.lit = -1;
	f.first, f.last = nil, nil;
end

-- Shows <f>'s dots from share <from> to share <to> of the way round; nil hides them all.
-- Only the dots between the old and the new range are touched.
local function SetFillRange(f, from, to)
	local first, last = 1, 0;
	if ( from and to and to > from ) then
		first = math.floor(from * f.count + 0.5) + 1;
		last = math.floor(to * f.count + 0.5);
	end
	if ( first == f.first and last == f.last ) then return; end
	-- Dots outside the old range are hidden (LayoutFill hides them all), so only the old and
	-- the new range need touching.
	local wasShown = f.first and f.last >= f.first;
	local lo, hi = first, last;
	if ( wasShown and last >= first ) then
		lo, hi = math.min(first, f.first), math.max(last, f.last);
	elseif ( wasShown ) then
		lo, hi = f.first, f.last;
	end
	f.first, f.last = first, last;
	for i = lo, hi do
		ShowIf(f.dots[i], i >= first and i <= last);
	end
end

-- progress 0..1 fills that share of <f>; nil hides it. Only the dots that change are shown
-- or hidden.
local function SetFillProgress(f, progress)
	local lit = progress and math.floor(progress * f.count + 0.5) or -1;
	if ( lit == f.lit ) then return; end
	local first, last = 1, f.count;
	if ( lit >= 0 and f.lit >= 0 ) then
		first, last = math.min(lit, f.lit) + 1, math.max(lit, f.lit);
	end
	f.lit = lit;
	for i = first, last do
		ShowIf(f.dots[i], i <= lit);
	end
end

local function LayoutSweepFill()
	LayoutFill(sweepFill, db.sweepEnabled, SweepSize(), SweepThickness(), SweepOutlineWidth(),
		db.sweepFillAlpha / 100);
	ColorFill(sweepFill, WarnableColor("s", "lowSweepFill"));
end

local hpColored;   -- the health the ring was last colored for, or nil to color it again

-- The health ring's fill and colors: the share of health (or the preview's) during a run.
-- The fill and the missing part share one color: the fill color, or the color by health.
local function UpdateHealthRing()
	UpdateCenterHealthColor();
	local shown = HealthRingVisible();
	local f, shield;
	if ( shown ) then
		f, shield = HealthShare();
	end
	SetFillProgress(hpFill, f);
	-- The shield colors the end of the health fill, as much of it as the shield is worth, so
	-- it shrinks back toward where health ends as it is used up.
	if ( f and db.healthShield and shield and shield > 0 ) then
		SetFillRange(shieldFill, math.max(0, f - shield), f);
	else
		SetFillRange(shieldFill, nil);
	end
	if ( not shown ) then return; end
	-- Outside a run the ring shows as full.
	local colorAt = f or 1;
	if ( not hpColored or (db.healthGradient and math.abs(colorAt - hpColored) >= 0.01) ) then
		hpColored = colorAt;
		local r, g, b = db.hr, db.hg, db.hb;
		if ( db.healthGradient ) then
			r, g, b = HealthColor(colorAt);
		end
		ColorFill(hpFill, r, g, b);
		hpObj.line:SetVertexColor(r, g, b, HEALTH_MISSING);
	end
end

local function LayoutHealthRing()
	local shown, size, k, w = HealthRingVisible(), HealthRingSize(), HealthThickness(), HealthOutlineWidth();
	DrawRing(hpObj, shown, size, k, 1, 1, 1, HEALTH_MISSING, w, "ho");
	LayoutFill(hpFill, shown, size, k, w, db.healthAlpha / 100);
	LayoutFill(shieldFill, shown and db.healthShield, size, k, w, db.healthAlpha / 100);
	ColorFill(shieldFill, db.hsr, db.hsg, db.hsb);
	hpColored = nil;
	UpdateHealthRing();
end

local function SetRingScale(scale)
	ringScale = scale;
	body:SetScale(scale);
end

-- The sweep reads the spell's cooldown when AZS_SPELLS changes and counts it down on the
-- run's clock in between, so it moves smoothly and stops while the run is paused.
local sweepKey, sweepStamp, sweepLeft, sweepMax, sweepStart;
local cooldownLeft;   -- seconds left on the sweep's spell as last drawn, for the text; nil if none

local function UpdateSweep()
	cooldownLeft = nil;
	if ( previewSweep ) then
		local p = math.mod(GetTime() - previewStart, PREVIEW_COOLDOWN) / PREVIEW_COOLDOWN;
		SetFillProgress(sweepFill, p);
		cooldownLeft = PREVIEW_COOLDOWN * (1 - p);
		return;
	end
	local key = db.sweepEnabled and RUN_PHASES[Phase()] and TrackedKey();
	if ( not key ) then
		SetFillProgress(sweepFill, nil);
		return;
	end
	if ( key ~= sweepKey ) then
		sweepKey = key;
		sweepStamp = -1;
		sweepMax = nil;
	end
	if ( AZS_SPELLS_UPDATED ~= sweepStamp ) then
		sweepStamp = AZS_SPELLS_UPDATED;
		local entry = FindSpell(key);
		if ( entry and entry.cdmax and entry.cdmax > 0 ) then
			local cd = entry.cd or 0;
			-- A ready spell that can't be cast (a melee spell with nothing in reach) keeps
			-- retrying on a short cooldown. A restart that short while it was ready is such a
			-- retry, not a cast, so the sweep stays full instead of flickering.
			local wasReady = sweepMax and sweepLeft - (RunTime() - sweepStart) <= 0;
			if ( wasReady and cd < entry.cdmax * RETRY_SHARE ) then
				cd = 0;
			end
			sweepLeft, sweepMax, sweepStart = cd, entry.cdmax, RunTime();
		else
			sweepMax = nil;
		end
	end
	if ( not sweepMax ) then
		SetFillProgress(sweepFill, nil);
		return;
	end
	local left = sweepLeft - (RunTime() - sweepStart);
	if ( left < 0 ) then left = 0; end
	SetFillProgress(sweepFill, 1 - left / sweepMax);
	cooldownLeft = left;
end

-- The outermost edge of whatever is drawn around the cursor, for placing the text.
local function OuterRadius()
	local r = (db.centerDot or db.centerCross) and db.centerSize / 2 + CenterOutlineWidth() or 0;
	if ( MainRingVisible() ) then
		r = math.max(r, MainRingSize() * RING_OUTER + RingOutlineWidth());
	end
	if ( HealthRingVisible() ) then
		r = math.max(r, HealthRingSize() * RING_OUTER + HealthOutlineWidth());
	end
	if ( db.sweepEnabled ) then
		r = math.max(r, SweepSize() * RING_OUTER + SweepOutlineWidth());
	end
	return r;
end

local function LayoutText()
	readout:SetFont(TEXT_FONT_FILES[db.textFont], db.textSize, "OUTLINE");
	readout:SetTextColor(db.tr, db.tg, db.tb);
	local anchor = TEXT_ANCHORS[db.textPos];
	local d = OuterRadius() + TEXT_GAP;
	readout:ClearAllPoints();
	readout:SetPoint(anchor[1], textFrame, "CENTER", anchor[2] * d, anchor[3] * d);
	readout:SetJustifyH(anchor[1] == "LEFT" and "LEFT" or anchor[1] == "RIGHT" and "RIGHT" or "CENTER");
	readout.shown = nil;
end

-- "|cffRRGGBB" for coloring part of a text.
local function ColorCode(r, g, b)
	return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255);
end

-- The text: health % (colored by health, if chosen) with the shield after it, and the
-- seconds left on the sweep's spell while it recharges, a line each. Only set when it changes.
local function UpdateText()
	local health, cooldown;
	if ( db.textHealth ) then
		local f, shield = HealthShare();
		if ( f ) then
			health = math.floor(f * 100 + 0.5) .. "%";
			if ( db.textByHealth ) then
				health = ColorCode(HealthColor(f)) .. health .. "|r";
			end
			-- The shield as a share of max health, like health %, so the two add up.
			if ( db.textShield and shield and shield > 0 ) then
				health = health .. " " .. ColorCode(db.hsr, db.hsg, db.hsb)
					.. "+" .. math.floor(shield * 100 + 0.5) .. "%|r";
			end
		end
	end
	if ( db.textCooldown and db.sweepEnabled and cooldownLeft and cooldownLeft > 0 ) then
		if ( cooldownLeft < 10 ) then
			cooldown = string.format("%.1f", cooldownLeft);
		else
			cooldown = tostring(math.ceil(cooldownLeft));
		end
	end
	local text = health and cooldown and (health .. "\n" .. cooldown) or health or cooldown or "";
	if ( text ~= readout.shown ) then
		readout.shown = text;
		readout:SetText(text);
	end
end

-- Works out whether health is low (or previewed as low); returns true when that changed.
local function CheckLowHealth()
	local low = previewLow;
	if ( not low and (db.lowRed or db.lowCenter or db.lowPulse or db.lowSweepMain or db.lowSweepFill) ) then
		local f = HealthFraction();
		low = (f ~= nil and f * 100 <= db.lowAt);
	end
	if ( low == lowHealth ) then return false; end
	lowHealth = low;
	return true;
end

local function UpdateLowHealth()
	if ( not CheckLowHealth() ) then return; end
	LayoutRings();
	LayoutCenter();
	ColorFill(sweepFill, WarnableColor("s", "lowSweepFill"));
	if ( not lowHealth ) then
		pulseTime = 0;
		SetRingScale(1);
	end
end

local lastX, lastY, lastScale;
local healthTimer = 0;
holder:SetScript("OnUpdate", function()
	local elapsed = arg1;
	-- Only re-anchor when the cursor (or the UI scale) changed since the last frame.
	local x, y = GetCursorPosition();
	local scale = UIParent:GetEffectiveScale();
	if ( x ~= lastX or y ~= lastY or scale ~= lastScale ) then
		lastX, lastY, lastScale = x, y, scale;
		this:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale);
	end

	UpdateSweep();

	-- Health changes at most five times a second, and the text shows tenths of a second, so
	-- both update ten times a second; the health preview moves every frame.
	healthTimer = healthTimer + elapsed;
	if ( healthTimer >= 0.1 ) then
		healthTimer = 0;
		UpdateLowHealth();
		UpdateHealthRing();
		UpdateText();
	elseif ( previewHealth ) then
		UpdateHealthRing();
	end
	if ( Pulsing() ) then
		pulseTime = pulseTime + elapsed;
		SetRingScale(1 + PULSE_GROW * (1 - math.cos(pulseTime * PULSE_SPEED * 2 * PI)) / 2);
	end
end);

local function ApplySettings()
	if ( not db.enabled ) then
		previewLow = false;
	end
	if ( not (db.enabled and db.sweepEnabled) ) then
		previewSweep = false;
	end
	if ( not (db.enabled and (HealthRingVisible() or db.centerByHealth or db.textHealth)) ) then
		previewHealth = false;
	end
	CheckLowHealth();
	if ( not Pulsing() ) then
		pulseTime = 0;
		ringScale = 1;
	end
	SetRingScale(ringScale);
	LayoutRings();
	LayoutCenter();
	LayoutSweepFill();
	LayoutHealthRing();
	LayoutText();
	UpdateText();
	sweepKey = nil;
	ShowIf(holder, db.enabled);
	if ( options and options:IsVisible() ) then
		options.Refresh();
	end
end

local function SetColor(prefix, r, g, b)
	db[prefix .. "r"], db[prefix .. "g"], db[prefix .. "b"] = r, g, b;
	ApplySettings();
end

-- Moves settings saved by older versions to their current form.
local function MigrateSettings()
	if ( db.center == "dot" ) then db.centerDot = true; end
	if ( db.center == "cross" ) then db.centerCross = true; end
	db.center = nil;
	db.hideCursor = nil;
	if ( db.sweepEnabled == nil and type(db.track) == "table" and next(db.track) ) then
		db.sweepEnabled = true;     -- a spell was chosen before the sweep had its own switch
	end
	if ( db.lowSweepMain == nil and db.lowRed ) then
		db.lowSweepMain = true;     -- "Color the ring" used to color the sweep's main ring too
	end

	-- One outline switch for everything, then one per part with a shared width and color,
	-- now an outline per tab.
	if ( db.outline ~= nil ) then
		db.outlineRing, db.outlineDot, db.outlineCross, db.outlineSweep =
			db.outline, db.outline, db.outline, db.outline;
	end
	if ( db.outlineRing ~= nil ) then
		local w = db.outlineWidth or 1;
		local r, g, b = db.olr or 0, db.olg or 0, db.olb or 0;
		db.ringOutline, db.ringOutlineWidth, db.ror, db.rog, db.rob = db.outlineRing, w, r, g, b;
		db.centerOutline = db.outlineDot or db.outlineCross;
		db.centerOutlineWidth, db.cor, db.cog, db.cob = w, r, g, b;
		db.sweepOutline = db.outlineSweep or db.outlineRing;
		db.sweepOutlineWidth, db.sor, db.sog, db.sob = w, r, g, b;
	end
	db.outline, db.outlineRing, db.outlineDot, db.outlineCross, db.outlineSweep = nil;
	db.outlineWidth, db.olr, db.olg, db.olb = nil;

	-- The sweep used to sit inside, on or outside the ring, with its own dot thickness and
	-- the recharging part dimmed.
	db.sweepPos, db.sweepThickness, db.sweepDim = nil;

	-- The main ring used to fill with health itself; now the health ring is a ring of its own.
	if ( db.healthFill ~= nil ) then
		db.healthEnabled = db.healthFill;
		db.healthFill = nil;
	end
	db.healthDivider = nil;      -- the shield had a divider for a while
end

local function FillDefaults(reset)
	MigrateSettings();
	for k, v in pairs(DEFAULTS) do
		if ( reset or db[k] == nil ) then
			if ( type(v) == "table" ) then
				db[k] = {};
			else
				db[k] = v;
			end
		end
	end
	if ( not RING_POSITION_NAMES[db.sweepRingPos] ) then
		db.sweepRingPos = DEFAULTS.sweepRingPos;
	end
	if ( not RING_TYPE_NAMES[db.sweepRingType] ) then
		db.sweepRingType = DEFAULTS.sweepRingType;
	end
	if ( not TEXT_FONT_NAMES[db.textFont] ) then
		db.textFont = DEFAULTS.textFont;
	end
	if ( not TEXT_POSITION_NAMES[db.textPos] ) then
		db.textPos = DEFAULTS.textPos;
	end
	if ( db.centerDot and db.centerCross ) then
		db.centerCross = false;
	end
end

local function TogglePreviewLow()
	previewLow = not previewLow;
	ApplySettings();
end

local function TogglePreviewSweep()
	previewSweep = not previewSweep;
	previewStart = GetTime();
	ApplySettings();
end

local function TogglePreviewHealth()
	previewHealth = not previewHealth;
	previewHealthStart = GetTime();
	ApplySettings();
end

local function StopPreviews()
	if ( previewLow or previewSweep or previewHealth ) then
		previewLow, previewSweep, previewHealth = false, false, false;
		ApplySettings();
	end
end

-- The settings each tab's "Reset to defaults" puts back, in tab order.
local TAB_SETTINGS = {
	{ "showRing", "size", "thickness", "alpha", "r", "g", "b",
	  "ringOutline", "ringOutlineWidth", "ror", "rog", "rob" },
	{ "healthEnabled", "healthSync", "healthSize", "healthThickness", "healthGradient", "hr", "hg", "hb",
	  "healthAlpha", "healthShield", "hsr", "hsg", "hsb",
	  "healthOutline", "healthOutlineWidth", "hor", "hog", "hob" },
	{ "centerDot", "centerCross", "centerSize", "centerThickness", "centerAlpha", "centerByHealth",
	  "cr", "cg", "cb", "centerOutline", "centerOutlineWidth", "cor", "cog", "cob" },
	{ "lowRed", "lowCenter", "lowSweepMain", "lowSweepFill", "lowPulse", "lowAt", "lr", "lg", "lb" },
	{ "sweepEnabled", "track", "sweepRingPos", "sweepRingType", "sweepSync", "sweepRingSize",
	  "sweepRingThickness", "sweepAlpha", "smr", "smg", "smb", "sweepFillAlpha", "sr", "sg", "sb",
	  "sweepOutline", "sweepOutlineWidth", "sor", "sog", "sob" },
	{ "textHealth", "textShield", "textCooldown", "textPos", "textFont", "textSize", "textByHealth",
	  "tr", "tg", "tb" },
};

-- Resets the settings of tab <id> (the spells seen so far are kept).
local function ResetTab(id)
	local keys = TAB_SETTINGS[id];
	for i = 1, table.getn(keys) do
		local v = DEFAULTS[keys[i]];
		if ( type(v) == "table" ) then
			db[keys[i]] = {};
		else
			db[keys[i]] = v;
		end
	end
	ApplySettings();
end

-- Resets every setting but keeps the spells seen so far.
local function ResetSettings()
	local seen = db.seen;
	FillDefaults(true);
	db.seen = seen;
	ApplySettings();
end

-- The color picker is shared with the rest of the UI, so it is raised above the options
-- window only while ours is open, and put back once it closes.
local pickerWatcher = CreateFrame("Frame");
pickerWatcher:Hide();
pickerWatcher:SetScript("OnUpdate", function()
	if ( not ColorPickerFrame:IsVisible() ) then
		ColorPickerFrame:SetFrameStrata(this.strata);
		this:Hide();
	end
end);

-- Lets the color picker be dragged by its title. The color wheel is part of the picker
-- itself, so the drag goes on a handle over the title instead of on the picker. Leaves it
-- alone if something else already handles dragging it.
local pickerHandle;
local function MakePickerMovable()
	if ( pickerHandle or ColorPickerFrame:GetScript("OnDragStart") ) then return; end
	ColorPickerFrame:SetMovable(true);
	pickerHandle = CreateFrame("Frame", nil, ColorPickerFrame);
	pickerHandle:SetWidth(150);
	pickerHandle:SetHeight(30);
	pickerHandle:SetPoint("TOP", ColorPickerFrame, "TOP", 0, 12);
	pickerHandle:EnableMouse(true);
	pickerHandle:RegisterForDrag("LeftButton");
	pickerHandle:SetScript("OnDragStart", function() ColorPickerFrame:StartMoving(); end);
	pickerHandle:SetScript("OnDragStop", function() ColorPickerFrame:StopMovingOrSizing(); end);
end

local function OpenColorPicker(prefix)
	local r, g, b = db[prefix .. "r"], db[prefix .. "g"], db[prefix .. "b"];
	MakePickerMovable();
	if ( not pickerWatcher:IsShown() ) then
		pickerWatcher.strata = ColorPickerFrame:GetFrameStrata();
	end
	ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG");
	-- Set the callbacks before the color: SetColorRGB fires ColorPickerFrame.func.
	ColorPickerFrame.hasOpacity = false;
	ColorPickerFrame.func = function()
		local nr, ng, nb = ColorPickerFrame:GetColorRGB();
		SetColor(prefix, nr, ng, nb);
	end;
	ColorPickerFrame.cancelFunc = function()
		SetColor(prefix, r, g, b);
	end;
	ColorPickerFrame:SetColorRGB(r, g, b);
	ColorPickerFrame:Hide();
	ShowUIPanel(ColorPickerFrame);
	pickerWatcher:Show();
end

---------------------------------------------------------------------------
-- Options window
---------------------------------------------------------------------------

-- The options window's helpers, in one table: a Lua 5.0 function can use at most 32
-- locals from around it, and a file at most 200 locals of its own.
local UI = {};

function UI.ShowTooltip(owner, text)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT");
	GameTooltip:SetText(text, 1, 1, 1, 1, 1);
	GameTooltip:Show();
end

function UI.AddTooltip(frame, text)
	frame:SetScript("OnEnter", function() UI.ShowTooltip(this, text); end);
	frame:SetScript("OnLeave", function() GameTooltip:Hide(); end);
end

-- Dims a control when it doesn't apply, and stops it taking clicks when it can't be used.
-- A control is a frame; its clickable parts are listed in .buttons (or it is one itself).
function UI.SetControlState(c, active, clickable)
	c:SetAlpha(active and 1 or GREYED);
	local buttons = c.buttons or { c };
	for i = 1, table.getn(buttons) do
		local b = buttons[i];
		if ( b.isSlider ) then
			b:EnableMouse(clickable);
		elseif ( clickable ) then
			b:Enable();
		else
			b:Disable();
		end
	end
end

-- A frame holding a row of widgets, so they can be greyed out together.
function UI.CreateRow(parent, x, y, width, height)
	local row = CreateFrame("Frame", nil, parent);
	row:SetWidth(width);
	row:SetHeight(height);
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y);
	row.buttons = {};
	return row;
end

function UI.CreateSwatch(parent, size)
	local b = CreateFrame("Button", nil, parent);
	b:SetWidth(size);
	b:SetHeight(size);
	local border = b:CreateTexture(nil, "BACKGROUND");
	border:SetAllPoints(b);
	border:SetTexture(0.5, 0.5, 0.5);
	local fill = b:CreateTexture(nil, "ARTWORK");
	fill:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2);
	fill:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2);
	fill:SetTexture(1, 1, 1);
	b.fill = fill;
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square");
	b:GetHighlightTexture():SetBlendMode("ADD");
	return b;
end

function UI.CreateLabel(parent, text, x, y)
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y);
	label:SetText(text);
	return label;
end

-- A label and a swatch that opens the color picker for <prefix>r/g/b.
function UI.CreateColorRow(parent, text, x, y, prefix)
	local row = UI.CreateRow(parent, x, y, 110, 20);
	local label = UI.CreateLabel(row, text, 0, -3);
	local swatch = UI.CreateSwatch(row, 20);
	swatch:SetPoint("LEFT", label, "RIGHT", 8, 0);
	swatch:SetScript("OnClick", function() OpenColorPicker(prefix); end);
	UI.AddTooltip(swatch, "Click to choose a color.");
	row.swatch = swatch;
	row.prefix = prefix;
	table.insert(row.buttons, swatch);
	return row;
end

-- A row of one-click color presets for <prefix>r/g/b.
function UI.CreatePresetRow(parent, x, y, prefix)
	local row = UI.CreateRow(parent, x, y, 220, 18);
	for i = 1, table.getn(PRESETS) do
		local c = PRESETS[i];
		local s = UI.CreateSwatch(row, 18);
		s:SetPoint("TOPLEFT", row, "TOPLEFT", (i - 1) * 24, 0);
		s.fill:SetVertexColor(c[1], c[2], c[3]);
		s:SetScript("OnClick", function() SetColor(prefix, c[1], c[2], c[3]); end);
		table.insert(row.buttons, s);
	end
	return row;
end

-- A small button at the right end of a section title that turns a preview on and off.
function UI.CreatePreviewButton(parent, x, y, tooltip, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate");
	b:SetWidth(110);
	b:SetHeight(18);
	b:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 130, y + 2);
	b:SetScript("OnClick", onClick);
	UI.AddTooltip(b, tooltip);
	b.SetRunning = function(running)
		b:SetText(running and "Stop preview" or "Preview");
	end;
	return b;
end

-- A gold section title with a faint line under it.
function UI.CreateHeader(parent, text, x, y)
	local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	h:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y);
	h:SetText(text);
	local line = parent:CreateTexture(nil, "ARTWORK");
	line:SetTexture(1, 1, 1, 0.15);
	line:SetHeight(1);
	line:SetWidth(240);
	line:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -3);
end

-- Small grey text, for notes under an option.
function UI.CreateNote(parent, x, y)
	local note = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall");
	note:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y);
	note:SetWidth(240);
	note:SetJustifyH("LEFT");
	return note;
end

function UI.CreateCheck(parent, name, text, x, y, tooltip, onClick)
	local c = CreateFrame("CheckButton", name, parent, "OptionsCheckButtonTemplate");
	c:SetWidth(26);
	c:SetHeight(26);
	c:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y);
	local label = getglobal(name .. "Text");
	label:SetText(text);
	-- The template makes a long strip right of the box clickable, which can reach over a
	-- checkbox placed next to it; make only the box and its own label clickable.
	c:SetHitRectInsets(0, -label:GetStringWidth() - 4, 0, 0);
	c:SetScript("OnClick", function()
		onClick(this:GetChecked() and true or false);
	end);
	if ( tooltip ) then
		UI.AddTooltip(c, tooltip);
	end
	return c;
end

function UI.CreateSlider(parent, name, x, y, minValue, maxValue, lowText, highText, label, onChange)
	local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate");
	s:SetWidth(220);
	s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y);
	s:SetMinMaxValues(minValue, maxValue);
	s:SetValueStep(1);
	s.isSlider = true;
	getglobal(name .. "Low"):SetText(lowText);
	getglobal(name .. "High"):SetText(highText);
	s:SetScript("OnValueChanged", function()
		local v = math.floor(this:GetValue() + 0.5);
		getglobal(name .. "Text"):SetText(label(v));
		if ( not refreshing ) then
			onChange(v);
		end
	end);
	return s;
end

-- An outline section: a checkbox with its color beside it and its width below, for the
-- settings <key>, <key>Width and the color <prefix>r/g/b. Returns the three controls.
function UI.CreateOutlineOptions(parent, name, x, y, key, prefix, tooltip)
	UI.CreateHeader(parent, "Outline", x, y);
	local check = UI.CreateCheck(parent, name, "Outline", x, y - 18, tooltip,
		function(v) db[key] = v; ApplySettings(); end);
	local color = UI.CreateColorRow(parent, "Color:", x + 130, y - 21, prefix);
	local width = UI.CreateSlider(parent, name .. "Width", x + 6, y - 66, 1, 3, "1", "3",
		function(v) return "Width: " .. v; end,
		function(v) db[key .. "Width"] = v; ApplySettings(); end);
	return check, color, width;
end

-- A label and a standard drop-down menu; init fills the menu each time it opens.
-- The drop-down menus open a list of their own instead of the game's shared one: the game
-- closes the shared one whenever the target changes, which in a fight is all the time.

-- Whether the cursor is over <frame>.
function UI.MouseOver(frame)
	local x, y = GetCursorPosition();
	local scale = frame:GetEffectiveScale();
	x, y = x / scale, y / scale;
	local left, right, bottom, top = frame:GetLeft(), frame:GetRight(), frame:GetBottom(), frame:GetTop();
	return left and x >= left and x <= right and y >= bottom and y <= top;
end

-- The one menu list, made on first use. It closes when an item is picked, when its button
-- is clicked again, with the options window, or when the mouse has been away for 2 seconds.
function UI.Menu()
	if ( UI.menu ) then return UI.menu; end
	local m = CreateFrame("Frame", nil, UIParent);
	m:SetFrameStrata("FULLSCREEN_DIALOG");
	m:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	});
	m:SetBackdropColor(0, 0, 0, 0.9);
	m:EnableMouse(true);
	m:Hide();
	m.rows = {};
	m.away = 0;
	m:SetScript("OnUpdate", function()
		if ( UI.MouseOver(this) or UI.MouseOver(this.anchor) ) then
			this.away = 0;
		else
			this.away = this.away + arg1;
			if ( this.away > 2 ) then this:Hide(); end
		end
	end);
	UI.menu = m;
	return m;
end

function UI.CloseMenu()
	if ( UI.menu ) then UI.menu:Hide(); end
end

-- A row of the menu list: a check mark, the text, and a highlight under the mouse.
function UI.MenuRow(m, i)
	if ( m.rows[i] ) then return m.rows[i]; end
	local b = CreateFrame("Button", nil, m);
	b:SetHeight(16);
	b:SetPoint("TOPLEFT", m, "TOPLEFT", 8, -8 - (i - 1) * 16);
	b.check = b:CreateTexture(nil, "ARTWORK");
	b.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check");
	b.check:SetWidth(16);
	b.check:SetHeight(16);
	b.check:SetPoint("LEFT", b, "LEFT", 0, 0);
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	b.text:SetPoint("LEFT", b, "LEFT", 18, 0);
	b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");
	b:GetHighlightTexture():SetBlendMode("ADD");
	b:SetScript("OnClick", function()
		UI.CloseMenu();
		this.item.onClick(this.item.value);
	end);
	m.rows[i] = b;
	return b;
end

-- Opens the menu under drop-down <dd> with the items <init> adds, or closes it if it is
-- already open there.
function UI.ToggleMenu(dd, init)
	local m = UI.Menu();
	if ( m:IsShown() and m.anchor == dd ) then
		m:Hide();
		return;
	end
	UI.items = {};
	init();
	local width = 0;
	for i = 1, table.getn(UI.items) do
		local item, b = UI.items[i], UI.MenuRow(m, i);
		b.item = item;
		b.text:SetText(item.text);
		if ( item.title ) then
			b.text:SetTextColor(1, 0.82, 0);
			b:Disable();
		else
			b.text:SetTextColor(1, 1, 1);
			b:Enable();
		end
		if ( item.checked ) then b.check:Show(); else b.check:Hide(); end
		b:Show();
		width = math.max(width, b.text:GetStringWidth() + 22);
	end
	for i = table.getn(UI.items) + 1, table.getn(m.rows) do
		m.rows[i]:Hide();
	end
	for i = 1, table.getn(UI.items) do
		m.rows[i]:SetWidth(width);
	end
	m:SetWidth(width + 16);
	m:SetHeight(table.getn(UI.items) * 16 + 16);
	m.anchor = dd;
	m.away = 0;
	m:ClearAllPoints();
	m:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 16, 6);
	m:Show();
end

-- Adds an item to the menu being built: <onClick>(value) runs when it is picked.
function UI.AddMenuItem(text, value, checked, onClick)
	table.insert(UI.items, { text = text, value = value, checked = checked, onClick = onClick });
end

-- Adds a gold title line, which can't be picked.
function UI.AddMenuTitle(text)
	table.insert(UI.items, { text = text, title = true });
end

-- A label and a drop-down: the game's drop-down look, with the list above.
function UI.CreateDropDown(parent, name, x, y, labelText, init)
	local row = UI.CreateRow(parent, x, y, 240, 24);
	UI.CreateLabel(row, labelText, 0, 0);
	local dd = CreateFrame("Frame", name, row, "UIDropDownMenuTemplate");
	dd:SetPoint("TOPLEFT", row, "TOPLEFT", 52, 9);
	-- 1.12 takes (width, frame); later clients take (frame, width).
	if ( not pcall(UIDropDownMenu_SetWidth, 140, dd) ) then
		pcall(UIDropDownMenu_SetWidth, dd, 140);
	end
	local button = getglobal(name .. "Button");
	button:SetScript("OnClick", function() UI.ToggleMenu(dd, init); end);
	table.insert(row.buttons, button);
	row.SetValueText = function(text)
		getglobal(name .. "Text"):SetText(text);
	end;
	return row;
end

local function SelectSpell(key)
	local class = CurrentClass();
	if ( not class ) then return; end
	db.track[class] = key;
	ApplySettings();
end

local function InitSpellMenu()
	local class, className = CurrentClass();
	if ( not class ) then
		UI.AddMenuTitle("Start a run to choose a spell");
		return;
	end
	RecordSpells();
	local current = db.track[class];
	local spells = SeenSpells(class);
	if ( table.getn(spells) == 0 ) then
		UI.AddMenuTitle("No " .. (className or class) .. " spells seen yet");
		return;
	end
	UI.AddMenuTitle((className or class) .. " spells seen so far");
	for i = 1, table.getn(spells) do
		local key, text = spells[i].key, spells[i].name;
		if ( not FindSpell(key) ) then
			text = text .. " |cff808080(not this run)|r";
		end
		UI.AddMenuItem(text, key, key == current, SelectSpell);
	end
end

-- A menu choosing the setting <key> among <values>, shown by <names>.
function UI.ChoiceMenu(key, values, names)
	return function()
		for i = 1, table.getn(values) do
			local v = values[i];
			UI.AddMenuItem(names[v], v, v == db[key], function(value)
				db[key] = value;
				ApplySettings();
			end);
		end
	end;
end

-- While the sweep shares the ring's size and thickness, its sliders change the ring's.
local function SweepSizeKey()
	return SweepSynced() and "size" or "sweepRingSize";
end

local function SweepThicknessKey()
	return SweepSynced() and "thickness" or "sweepRingThickness";
end

-- Likewise for the health ring.
local function HealthSizeKey()
	return db.healthSync and "size" or "healthSize";
end

local function HealthThicknessKey()
	return db.healthSync and "thickness" or "healthThickness";
end

-- For a control's onChange: saves the value under <key> and applies it.
function UI.Setter(key)
	return function(v) db[key] = v; ApplySettings(); end;
end

function UI.SizeLabel(v) return "Size: " .. v; end
function UI.ThicknessLabel(v) return "Thickness: " .. THICKNESS_NAMES[v]; end
function UI.OpacityLabel(v) return "Opacity: " .. v .. "%"; end

-- The tab pages: each builds its controls into <c>, the table Refresh updates them from.
-- A column is 240 wide; each tab's left edge (and the second column's on the two-column
-- tabs) centers its columns in the window.
local TAB_LEFT = { 150, 35, 150, 150, 35, 150 };
local RIGHT_COLUMN = 315;

local function BuildRingTab(page, c)
	local L = TAB_LEFT[1];
	UI.CreateHeader(page, "Main circle", L, -66);
	c.showRing = UI.CreateCheck(page, "CursorReticleOptionsShowRing", "Show circle", L, -84, nil, UI.Setter("showRing"));
	c.ringNote = UI.CreateNote(page, L + 6, -110);
	c.size = UI.CreateSlider(page, "CursorReticleOptionsSize", L + 6, -150, 16, 200, "16", "200",
		UI.SizeLabel, UI.Setter("size"));
	c.thickness = UI.CreateSlider(page, "CursorReticleOptionsThickness", L + 6, -192, 1, 5, "Thin", "Thick",
		UI.ThicknessLabel, UI.Setter("thickness"));
	c.alpha = UI.CreateSlider(page, "CursorReticleOptionsAlpha", L + 6, -234, 10, 100, "10%", "100%",
		UI.OpacityLabel, UI.Setter("alpha"));

	UI.CreateHeader(page, "Color", L, -268);
	c.ringColor = UI.CreateColorRow(page, "Color:", L + 6, -290, "");
	c.ringPresets = UI.CreatePresetRow(page, L + 6, -314, "");

	c.ringOutlineCheck, c.ringOutlineColor, c.ringOutlineWidth = UI.CreateOutlineOptions(page,
		"CursorReticleOptionsRingOutline", L, -346, "ringOutline", "ro",
		"A dark edge around the circle, so it stays visible on bright ground.");

	table.insert(c.colorRows, c.ringColor);
	table.insert(c.colorRows, c.ringOutlineColor);
end

local function BuildHealthTab(page, c)
	local L, R = TAB_LEFT[2], RIGHT_COLUMN;
	-- Left column: the health ring, its shape and its outline.
	UI.CreateHeader(page, "Health circle", L, -66);
	c.healthPreview = UI.CreatePreviewButton(page, L, -66,
		"Shows the health circle draining from full to empty on a loop, with your current "
		.. "settings. With Shield on, shields go up and take the hits first, like in a run.",
		TogglePreviewHealth);
	c.healthEnable = UI.CreateCheck(page, "CursorReticleOptionsHealthEnable", "Show health circle", L, -84,
		"A circle that fills as far round as your health goes, during a run. It takes the main "
		.. "circle's place.",
		UI.Setter("healthEnabled"));
	c.healthNote = UI.CreateNote(page, L + 6, -110);
	c.healthSync = UI.CreateCheck(page, "CursorReticleOptionsHealthSync", "Same size and thickness as the main circle", L, -146,
		"Uses the main circle's size and thickness, so changing them here changes the main "
		.. "circle's too.",
		UI.Setter("healthSync"));
	c.healthSize = UI.CreateSlider(page, "CursorReticleOptionsHealthSize", L + 6, -194, 16, 200, "16", "200",
		UI.SizeLabel, function(v) db[HealthSizeKey()] = v; ApplySettings(); end);
	c.healthThickness = UI.CreateSlider(page, "CursorReticleOptionsHealthThickness", L + 6, -236, 1, 5, "Thin", "Thick",
		UI.ThicknessLabel, function(v) db[HealthThicknessKey()] = v; ApplySettings(); end);

	c.healthOutlineCheck, c.healthOutlineColor, c.healthOutlineWidth = UI.CreateOutlineOptions(page,
		"CursorReticleOptionsHealthOutline", L, -270, "healthOutline", "ho",
		"A dark edge around the health circle, so it stays visible on bright ground.");

	-- Right column: its color.
	UI.CreateHeader(page, "Color", R, -66);
	c.healthGradient = UI.CreateCheck(page, "CursorReticleOptionsHealthGradient", "Color by health", R, -84,
		"Colors the circle by health: green when full, then yellow, orange and red as it drops.",
		UI.Setter("healthGradient"));
	c.healthColor = UI.CreateColorRow(page, "Fill color:", R + 6, -114, "h");
	c.healthPresets = UI.CreatePresetRow(page, R + 6, -138, "h");
	c.healthAlpha = UI.CreateSlider(page, "CursorReticleOptionsHealthAlpha", R + 6, -182, 10, 100, "10%", "100%",
		function(v) return "Fill opacity: " .. v .. "%"; end, UI.Setter("healthAlpha"));
	local missingNote = UI.CreateNote(page, R + 6, -208);
	missingNote:SetText("The missing health shows in the same color at "
		.. (HEALTH_MISSING * 100) .. "% opacity.");
	c.healthShield = UI.CreateCheck(page, "CursorReticleOptionsHealthShield", "Shield", R, -246,
		"Shows your absorb shield over the end of your health, as much of it as the shield is "
		.. "worth as a share of your max health; it shrinks back as the shield is used up.",
		UI.Setter("healthShield"));
	c.healthShieldColor = UI.CreateColorRow(page, "Color:", R + 130, -249, "hs");

	table.insert(c.colorRows, c.healthColor);
	table.insert(c.colorRows, c.healthShieldColor);
	table.insert(c.colorRows, c.healthOutlineColor);
end

local function BuildCenterTab(page, c)
	local L = TAB_LEFT[3];
	UI.CreateHeader(page, "Center", L, -66);
	-- Dot and crosshair are one or the other: turning one on turns the other off.
	c.centerDot = UI.CreateCheck(page, "CursorReticleOptionsCenterDot", "Dot", L, -84, nil,
		function(v)
			db.centerDot = v;
			if ( v ) then db.centerCross = false; end
			ApplySettings();
		end);
	c.centerCross = UI.CreateCheck(page, "CursorReticleOptionsCenterCross", "Crosshair", L + 90, -84, nil,
		function(v)
			db.centerCross = v;
			if ( v ) then db.centerDot = false; end
			ApplySettings();
		end);
	c.centerSize = UI.CreateSlider(page, "CursorReticleOptionsCenterSize", L + 6, -132, 2, 32, "2", "32",
		UI.SizeLabel, UI.Setter("centerSize"));
	c.centerThickness = UI.CreateSlider(page, "CursorReticleOptionsCenterThickness", L + 6, -174, 1, 8, "1", "8",
		function(v) return "Crosshair thickness: " .. v; end, UI.Setter("centerThickness"));
	c.centerAlpha = UI.CreateSlider(page, "CursorReticleOptionsCenterAlpha", L + 6, -216, 10, 100, "10%", "100%",
		UI.OpacityLabel, UI.Setter("centerAlpha"));

	UI.CreateHeader(page, "Color", L, -250);
	c.centerByHealth = UI.CreateCheck(page, "CursorReticleOptionsCenterByHealth", "Color by health", L, -268,
		"Colors the dot or crosshair by health, like the health circle: green when full, then "
		.. "yellow, orange and red as it drops.",
		UI.Setter("centerByHealth"));
	c.centerColor = UI.CreateColorRow(page, "Color:", L + 6, -298, "c");
	c.centerPresets = UI.CreatePresetRow(page, L + 6, -322, "c");

	c.centerOutlineCheck, c.centerOutlineColor, c.centerOutlineWidth = UI.CreateOutlineOptions(page,
		"CursorReticleOptionsCenterOutline", L, -354, "centerOutline", "co",
		"A dark edge around the dot or crosshair, so it stays visible on bright ground.");

	table.insert(c.colorRows, c.centerColor);
	table.insert(c.colorRows, c.centerOutlineColor);
end

local function BuildLowHealthTab(page, c)
	local L = TAB_LEFT[4];
	UI.CreateHeader(page, "Low health", L, -66);
	c.lowPreview = UI.CreatePreviewButton(page, L, -66,
		"Shows the low health warning with your current settings, as if your health were low.",
		TogglePreviewLow);
	c.lowRed = UI.CreateCheck(page, "CursorReticleOptionsLowRed", "Color the main circle", L, -84,
		"Shows the main circle in the warning color. Needs the main circle to be shown.", UI.Setter("lowRed"));
	c.lowPulse = UI.CreateCheck(page, "CursorReticleOptionsLowPulse", "Pulse the circles", L + 160, -84,
		"Makes the circles pulse.", UI.Setter("lowPulse"));
	c.lowCenter = UI.CreateCheck(page, "CursorReticleOptionsLowCenter", "Color the dot / crosshair", L, -108,
		"Shows the dot or crosshair in the warning color. Needs one of them to be on.",
		UI.Setter("lowCenter"));
	c.lowSweepMain = UI.CreateCheck(page, "CursorReticleOptionsLowSweepMain", "Color the sweep's main circle", L, -132,
		"Shows the cooldown sweep's main color in the warning color. Needs the sweep to be on.",
		UI.Setter("lowSweepMain"));
	c.lowSweepFill = UI.CreateCheck(page, "CursorReticleOptionsLowSweepFill", "Color the sweep's fill", L, -156,
		"Shows the cooldown sweep's fill in the warning color. Needs the sweep to be on.",
		UI.Setter("lowSweepFill"));
	c.lowColor = UI.CreateColorRow(page, "Warning color:", L + 6, -186, "l");
	c.lowAt = UI.CreateSlider(page, "CursorReticleOptionsLowAt", L + 6, -226, 5, 75, "5%", "75%",
		function(v) return "When below " .. v .. "% health"; end, UI.Setter("lowAt"));

	table.insert(c.colorRows, c.lowColor);
end

local function BuildSweepTab(page, c)
	local L, R = TAB_LEFT[5], RIGHT_COLUMN;
	-- Left column: the spell, the sweep's shape, and the ring beside it.
	UI.CreateHeader(page, "Cooldown sweep", L, -66);
	c.sweepPreview = UI.CreatePreviewButton(page, L, -66,
		"Shows the sweep with your current settings on a test cooldown of "
		.. PREVIEW_COOLDOWN .. " seconds, even outside a run.",
		TogglePreviewSweep);
	c.sweepEnable = UI.CreateCheck(page, "CursorReticleOptionsSweepEnable", "Enable", L, -84,
		"Shows a spell's cooldown as a circle that fills up as the spell recharges. It takes the "
		.. "place of the other circles; the main circle or the health circle can stay beside it.",
		UI.Setter("sweepEnabled"));
	c.spellMenu = UI.CreateDropDown(page, "CursorReticleOptionsSpell", L + 6, -118, "Spell:", InitSpellMenu);
	c.spellHint = UI.CreateNote(page, L + 6, -142);

	UI.CreateHeader(page, "Shape", L, -184);
	c.sweepSync = UI.CreateCheck(page, "CursorReticleOptionsSweepSync", "Same size and thickness as the main circle", L, -202,
		"Uses the main circle's size and thickness, so changing them here changes the main "
		.. "circle's too. Only while no circle is shown beside the sweep.",
		UI.Setter("sweepSync"));
	c.sweepSize = UI.CreateSlider(page, "CursorReticleOptionsSweepSize", L + 6, -250, 16, 200, "16", "200",
		UI.SizeLabel, function(v) db[SweepSizeKey()] = v; ApplySettings(); end);
	c.sweepThickness = UI.CreateSlider(page, "CursorReticleOptionsSweepThickness", L + 6, -292, 1, 5, "Thin", "Thick",
		UI.ThicknessLabel, function(v) db[SweepThicknessKey()] = v; ApplySettings(); end);

	UI.CreateHeader(page, "Circle beside it", L, -326);
	c.ringPosMenu = UI.CreateDropDown(page, "CursorReticleOptionsRingPos", L + 6, -350, "Where:",
		UI.ChoiceMenu("sweepRingPos", RING_POSITIONS, RING_POSITION_NAMES));
	c.ringTypeMenu = UI.CreateDropDown(page, "CursorReticleOptionsRingType", L + 6, -380, "Circle:",
		UI.ChoiceMenu("sweepRingType", RING_TYPES, RING_TYPE_NAMES));
	c.ringPosNote = UI.CreateNote(page, L + 6, -406);

	-- Right column: the main color, the fill color and the outline.
	UI.CreateHeader(page, "Main color", R, -66);
	c.sweepMainColor = UI.CreateColorRow(page, "Color:", R + 6, -88, "sm");
	c.sweepMainPresets = UI.CreatePresetRow(page, R + 6, -112, "sm");
	c.sweepAlpha = UI.CreateSlider(page, "CursorReticleOptionsSweepAlpha", R + 6, -156, 10, 100, "10%", "100%",
		UI.OpacityLabel, UI.Setter("sweepAlpha"));

	UI.CreateHeader(page, "Fill color", R, -190);
	c.sweepFillColor = UI.CreateColorRow(page, "Color:", R + 6, -212, "s");
	c.sweepFillPresets = UI.CreatePresetRow(page, R + 6, -236, "s");
	c.sweepFillAlpha = UI.CreateSlider(page, "CursorReticleOptionsSweepFillAlpha", R + 6, -280, 10, 100, "10%", "100%",
		UI.OpacityLabel, UI.Setter("sweepFillAlpha"));

	c.sweepOutlineCheck, c.sweepOutlineColor, c.sweepOutlineWidth = UI.CreateOutlineOptions(page,
		"CursorReticleOptionsSweepOutline", R, -314, "sweepOutline", "so",
		"A dark edge around the sweep, so it stays visible on bright ground.");

	table.insert(c.colorRows, c.sweepMainColor);
	table.insert(c.colorRows, c.sweepFillColor);
	table.insert(c.colorRows, c.sweepOutlineColor);
end

local function BuildTextTab(page, c)
	local L = TAB_LEFT[6];
	UI.CreateHeader(page, "Text", L, -66);
	c.textHealth = UI.CreateCheck(page, "CursorReticleOptionsTextHealth", "Health %", L, -84,
		"Your health as a percentage, during a run.", UI.Setter("textHealth"));
	c.textShield = UI.CreateCheck(page, "CursorReticleOptionsTextShield", "Shield", L + 20, -108,
		"Adds your absorb shield after the health %, in the shield color: \"80% +30%\".\n\n"
		.. "The shield is shown as a share of your max health, the same as health %, so the two "
		.. "add up: 80% +30% means you can take damage worth 110% of your max health before "
		.. "dying. It is not how much of the shield itself is left.\n\n"
		.. "Shown only while you have a shield. Needs Health % to be on.",
		UI.Setter("textShield"));
	c.textCooldown = UI.CreateCheck(page, "CursorReticleOptionsTextCooldown", "Cooldown seconds", L, -132,
		"The seconds left on the cooldown sweep's spell while it recharges. Needs the sweep to be on.",
		UI.Setter("textCooldown"));

	UI.CreateHeader(page, "Style", L, -166);
	c.textPosMenu = UI.CreateDropDown(page, "CursorReticleOptionsTextPos", L + 6, -190, "Where:",
		UI.ChoiceMenu("textPos", TEXT_POSITIONS, TEXT_POSITION_NAMES));
	c.textFontMenu = UI.CreateDropDown(page, "CursorReticleOptionsTextFont", L + 6, -220, "Font:",
		UI.ChoiceMenu("textFont", TEXT_FONTS, TEXT_FONT_NAMES));
	c.textSize = UI.CreateSlider(page, "CursorReticleOptionsTextSize", L + 6, -266, 8, 24, "8", "24",
		UI.SizeLabel, UI.Setter("textSize"));
	c.textByHealth = UI.CreateCheck(page, "CursorReticleOptionsTextByHealth", "Color health % by health", L, -300,
		"Colors the health % like the health circle: green when full, then yellow, orange and red.",
		UI.Setter("textByHealth"));
	c.textColor = UI.CreateColorRow(page, "Color:", L + 6, -330, "t");
	c.textPresets = UI.CreatePresetRow(page, L + 6, -354, "t");

	table.insert(c.colorRows, c.textColor);
end

local TAB_BUILDERS = { BuildRingTab, BuildHealthTab, BuildCenterTab, BuildLowHealthTab, BuildSweepTab, BuildTextTab };

-- The notes on the Ring, Health and Cooldown sweep tabs about which ring is shown where.
local function RingNotes()
	local where = string.lower(RING_POSITION_NAMES[db.sweepRingPos]);
	local beside = "Shown " .. where .. ": the settings here apply, but its size follows the sweep.";
	local hidden = "Hidden: the cooldown sweep takes its place. It can be shown beside the "
		.. "sweep from the Cooldown sweep tab.";
	local ring, health;
	if ( db.sweepEnabled ) then
		ring = BesideSweep("ring") and beside or hidden;
		health = BesideSweep("health") and beside or hidden;
	else
		ring = db.healthEnabled and "Hidden: the health circle takes its place." or nil;
		health = "Takes the main circle's place. It fills with your health during a run.";
	end
	local sweep = "Show the main circle or the health circle inside or outside the sweep.";
	if ( ExtraRingShown() ) then
		sweep = "Uses the " .. (db.sweepRingType == "health" and "Health circle" or "Circle")
			.. " tab's settings. Its size follows the sweep.";
	end
	return ring, health, sweep;
end

-- Copies the settings into the options window's controls <c>.
local function RefreshValues(c)
	c.enable:SetChecked(db.enabled);

	c.showRing:SetChecked(db.showRing);
	c.size:SetValue(db.size);
	c.thickness:SetValue(db.thickness);
	c.alpha:SetValue(db.alpha);
	c.ringOutlineCheck:SetChecked(db.ringOutline);
	c.ringOutlineWidth:SetValue(db.ringOutlineWidth);

	c.healthEnable:SetChecked(db.healthEnabled);
	c.healthSync:SetChecked(db.healthSync);
	c.healthSize:SetValue(db[HealthSizeKey()]);
	c.healthThickness:SetValue(db[HealthThicknessKey()]);
	c.healthGradient:SetChecked(db.healthGradient);
	c.healthAlpha:SetValue(db.healthAlpha);
	c.healthShield:SetChecked(db.healthShield);
	c.healthOutlineCheck:SetChecked(db.healthOutline);
	c.healthOutlineWidth:SetValue(db.healthOutlineWidth);
	c.healthPreview.SetRunning(previewHealth);

	c.centerDot:SetChecked(db.centerDot);
	c.centerCross:SetChecked(db.centerCross);
	c.centerSize:SetValue(db.centerSize);
	c.centerThickness:SetValue(db.centerThickness);
	c.centerAlpha:SetValue(db.centerAlpha);
	c.centerByHealth:SetChecked(db.centerByHealth);
	c.centerOutlineCheck:SetChecked(db.centerOutline);
	c.centerOutlineWidth:SetValue(db.centerOutlineWidth);

	c.lowRed:SetChecked(db.lowRed);
	c.lowPulse:SetChecked(db.lowPulse);
	c.lowCenter:SetChecked(db.lowCenter);
	c.lowSweepMain:SetChecked(db.lowSweepMain);
	c.lowSweepFill:SetChecked(db.lowSweepFill);
	c.lowAt:SetValue(db.lowAt);
	c.lowPreview.SetRunning(previewLow);

	c.sweepEnable:SetChecked(db.sweepEnabled);
	c.sweepSync:SetChecked(db.sweepSync);
	c.sweepSize:SetValue(db[SweepSizeKey()]);
	c.sweepThickness:SetValue(db[SweepThicknessKey()]);
	c.sweepAlpha:SetValue(db.sweepAlpha);
	c.sweepFillAlpha:SetValue(db.sweepFillAlpha);
	c.sweepOutlineCheck:SetChecked(db.sweepOutline);
	c.sweepOutlineWidth:SetValue(db.sweepOutlineWidth);
	c.ringPosMenu.SetValueText(RING_POSITION_NAMES[db.sweepRingPos]);
	c.ringTypeMenu.SetValueText(RING_TYPE_NAMES[db.sweepRingType]);
	c.sweepPreview.SetRunning(previewSweep);

	c.textHealth:SetChecked(db.textHealth);
	c.textShield:SetChecked(db.textShield);
	c.textCooldown:SetChecked(db.textCooldown);
	c.textPosMenu.SetValueText(TEXT_POSITION_NAMES[db.textPos]);
	c.textFontMenu.SetValueText(TEXT_FONT_NAMES[db.textFont]);
	c.textSize:SetValue(db.textSize);
	c.textByHealth:SetChecked(db.textByHealth);

	for i = 1, table.getn(c.colorRows) do
		local row = c.colorRows[i];
		local p = row.prefix;
		row.swatch.fill:SetVertexColor(db[p .. "r"], db[p .. "g"], db[p .. "b"]);
	end

	local class, className = CurrentClass();
	local key = TrackedKey();
	c.spellMenu.SetValueText(key and SpellName(key) or "Choose a spell");
	if ( not class ) then
		c.spellHint:SetText("Start a run to choose a spell.");
	else
		c.spellHint:SetText("Lists the spells you've had in a run as " .. (className or class)
			.. ". They stay listed for later runs (" .. table.getn(db.seen[class] or {})
			.. " so far).");
	end

	local ringNote, healthNote, sweepNote = RingNotes();
	c.ringNote:SetText(ringNote or "");
	ShowIf(c.ringNote, ringNote);
	c.healthNote:SetText(healthNote);
	c.ringPosNote:SetText(sweepNote);
end

-- Greys out the controls in <c> that don't apply; with the addon off, nothing can be
-- changed.
local function RefreshStates(c)
	local on = db.enabled;
	local sweepOn = db.sweepEnabled;
	local ringOn = MainRingVisible();
	local hpOn = HealthRingVisible();
	local center = db.centerDot or db.centerCross;
	local warnColor = (db.lowRed and ringOn) or (db.lowCenter and center)
		or ((db.lowSweepMain or db.lowSweepFill) and sweepOn);
	local function State(name, active)
		UI.SetControlState(c[name], active, on and active);
	end
	c.main:SetAlpha(on and 1 or GREYED);

	State("showRing", not sweepOn and not db.healthEnabled);
	State("size", ringOn and not BesideSweep("ring"));
	State("thickness", ringOn);
	State("alpha", ringOn);
	State("ringColor", ringOn);
	State("ringPresets", ringOn);
	State("ringOutlineCheck", ringOn);
	State("ringOutlineColor", ringOn and db.ringOutline);
	State("ringOutlineWidth", ringOn and db.ringOutline);

	State("healthEnable", not sweepOn);
	State("healthPreview", hpOn or (center and db.centerByHealth) or db.textHealth);
	State("healthSync", hpOn);
	State("healthSize", hpOn and not BesideSweep("health"));
	State("healthThickness", hpOn);
	State("healthGradient", hpOn);
	State("healthColor", hpOn and not db.healthGradient);
	State("healthPresets", hpOn and not db.healthGradient);
	State("healthAlpha", hpOn);
	State("healthShield", hpOn);
	State("healthShieldColor", hpOn and db.healthShield);
	State("healthOutlineCheck", hpOn);
	State("healthOutlineColor", hpOn and db.healthOutline);
	State("healthOutlineWidth", hpOn and db.healthOutline);

	State("centerDot", true);
	State("centerCross", true);
	State("centerSize", center);
	State("centerThickness", db.centerCross);
	State("centerAlpha", center);
	State("centerByHealth", center);
	State("centerColor", center and not db.centerByHealth);
	State("centerPresets", center and not db.centerByHealth);
	State("centerOutlineCheck", center);
	State("centerOutlineColor", center and db.centerOutline);
	State("centerOutlineWidth", center and db.centerOutline);

	State("lowRed", ringOn);
	State("lowPulse", AnyRing());
	State("lowCenter", center);
	State("lowSweepMain", sweepOn);
	State("lowSweepFill", sweepOn);
	State("lowColor", warnColor);
	State("lowAt", warnColor or (db.lowPulse and AnyRing()));
	State("lowPreview", warnColor or (db.lowPulse and AnyRing()));

	State("sweepEnable", true);
	State("sweepPreview", sweepOn);
	State("spellMenu", sweepOn);
	State("sweepSync", sweepOn and not ExtraRingShown());
	State("sweepSize", sweepOn);
	State("sweepThickness", sweepOn);
	State("ringPosMenu", sweepOn);
	State("ringTypeMenu", ExtraRingShown());
	State("sweepMainColor", sweepOn);
	State("sweepMainPresets", sweepOn);
	State("sweepAlpha", sweepOn);
	State("sweepFillColor", sweepOn);
	State("sweepFillPresets", sweepOn);
	State("sweepFillAlpha", sweepOn);
	State("sweepOutlineCheck", sweepOn);
	State("sweepOutlineColor", sweepOn and db.sweepOutline);
	State("sweepOutlineWidth", sweepOn and db.sweepOutline);

	local anyText = db.textHealth or (db.textCooldown and sweepOn);
	State("textHealth", true);
	State("textShield", db.textHealth);
	State("textCooldown", sweepOn);
	State("textPosMenu", anyText);
	State("textFontMenu", anyText);
	State("textSize", anyText);
	State("textByHealth", db.textHealth);
	State("textColor", anyText);
	State("textPresets", anyText);
end

-- Brings the options window up to date: in two functions, as a Lua 5.0 function can use
-- at most 32 locals from around it.
local function RefreshOptions(c)
	refreshing = true;
	RefreshValues(c);
	RefreshStates(c);
	refreshing = false;
end

local function CreateOptions()
	local f = CreateFrame("Frame", "CursorReticleOptions", UIParent);
	f:SetPoint("TOP", UIParent, "TOP", 0, -120);
	f:SetFrameStrata("HIGH");
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	});
	-- A dark layer over the dialog background, inside the border, to darken it a little.
	local shade = f:CreateTexture(nil, "BACKGROUND");
	shade:SetTexture(0, 0, 0, 0.35);
	shade:SetPoint("TOPLEFT", f, "TOPLEFT", 11, -12);
	shade:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 11);
	f:EnableMouse(true);
	f:SetMovable(true);
	f:RegisterForDrag("LeftButton");
	f:SetScript("OnDragStart", function() this:StartMoving(); end);
	f:SetScript("OnDragStop", function() this:StopMovingOrSizing(); end);
	f:Hide();
	-- Escape closes it.
	table.insert(UISpecialFrames, "CursorReticleOptions");

	local header = f:CreateTexture(nil, "ARTWORK");
	header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header");
	header:SetWidth(256);
	header:SetHeight(64);
	header:SetPoint("TOP", f, "TOP", 0, 12);
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	title:SetPoint("TOP", header, "TOP", 0, -14);
	title:SetText("Cursor Reticle");

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton");
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5);
	close:SetScript("OnClick", function() f:Hide(); end);

	local enable = UI.CreateCheck(f, "CursorReticleOptionsEnable", "Enable addon", 24, -30,
		"Turns everything Cursor Reticle draws on or off.", UI.Setter("enabled"));

	-- The tabs' pages, in one frame so they can be greyed out at once while the addon is off.
	local main = CreateFrame("Frame", nil, f);
	main:SetAllPoints(f);

	-- Standard bottom tabs, one page each. The window takes each tab's size, keeping its top
	-- edge in place, and remembers the last tab while the game runs.
	local pages = {};
	local SelectTab;
	for i = 1, table.getn(TAB_NAMES) do
		local page = CreateFrame("Frame", nil, main);
		page:SetAllPoints(main);
		page:Hide();
		pages[i] = page;

		local tab = CreateFrame("Button", "CursorReticleOptionsTab" .. i, f, "CharacterFrameTabButtonTemplate");
		tab:SetID(i);
		tab:SetText(TAB_NAMES[i]);
		if ( i == 1 ) then
			tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 12, 7);
		else
			tab:SetPoint("LEFT", getglobal("CursorReticleOptionsTab" .. (i - 1)), "RIGHT", -15, 0);
		end
		tab:SetScript("OnClick", function()
			SelectTab(this:GetID());
			PlaySound("igCharacterInfoTab");
		end);
	end
	PanelTemplates_SetNumTabs(f, table.getn(TAB_NAMES));
	SelectTab = function(id)
		local left, top = f:GetLeft(), f:GetTop();
		if ( left and top ) then
			f:ClearAllPoints();
			f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top);
		end
		f:SetWidth(TAB_SIZES[id][1]);
		f:SetHeight(TAB_SIZES[id][2]);
		-- Line the addon's checkbox up with the tab's content.
		enable:ClearAllPoints();
		enable:SetPoint("TOPLEFT", f, "TOPLEFT", TAB_LEFT[id] - 4, -30);
		f.tabId = id;
		UI.CloseMenu();
		PanelTemplates_SetTab(f, id);
		for i = 1, table.getn(pages) do
			ShowIf(pages[i], i == id);
		end
	end;
	SelectTab(1);

	-- The controls Refresh updates, in one table: a 1.12 function can use at most 60 locals
	-- from around it, so Refresh reads them all from here.
	local c = { main = main, enable = enable, colorRows = {} };
	for i = 1, table.getn(pages) do
		TAB_BUILDERS[i](pages[i], c);
	end

	local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate");
	reset:SetWidth(130);
	reset:SetHeight(22);
	reset:SetPoint("BOTTOM", f, "BOTTOM", 0, 22);
	reset:SetText("Reset to defaults");
	reset:SetScript("OnClick", function() ResetTab(f.tabId); end);
	UI.AddTooltip(reset, "Resets the settings on this tab. The spells seen so far are kept.");

	f.Refresh = function() RefreshOptions(c); end;
	f:SetScript("OnShow", f.Refresh);
	f:SetScript("OnHide", function()
		StopPreviews();
		UI.CloseMenu();
	end);

	return f;
end

local function ToggleOptions()
	if ( not options ) then
		options = CreateOptions();
	end
	if ( options:IsVisible() ) then
		options:Hide();
	else
		options:Show();
	end
end

---------------------------------------------------------------------------
-- Saved settings and slash command
---------------------------------------------------------------------------

local loader = CreateFrame("Frame");
loader:RegisterEvent("ADDON_LOADED");
loader:SetScript("OnEvent", function()
	if ( event == "ADDON_LOADED" ) then
		if ( arg1 ~= ADDON_NAME ) then return; end
		if ( type(CursorReticleDB) ~= "table" ) then
			-- Settings saved under the addon's old name (Cursor Ring), if its saved
			-- variables file was renamed to go with it, are taken over once.
			CursorReticleDB = type(CursorRingDB) == "table" and CursorRingDB or {};
		end
		CursorRingDB = nil;
		db = CursorReticleDB;
		FillDefaults(false);
		RecordSpells();
		ApplySettings();
		this:UnregisterEvent("ADDON_LOADED");
		this:RegisterEvent("CHAT_MSG_ADDON");
	elseif ( arg1 == "AZSSPELLS" or arg1 == "AZSZONE" ) then
		-- The game's parser has already updated AZS_SPELLS / AZS_ZONE.
		RecordSpells();
	end
end);

SLASH_CURSORRETICLE1 = "/cr";
SLASH_CURSORRETICLE2 = "/creticle";
SlashCmdList["CURSORRETICLE"] = function(msg)
	msg = string.lower(msg or "");
	if ( msg == "on" ) then
		db.enabled = true;
		ApplySettings();
	elseif ( msg == "off" ) then
		db.enabled = false;
		ApplySettings();
	elseif ( msg == "toggle" ) then
		db.enabled = not db.enabled;
		ApplySettings();
	elseif ( msg == "reset" ) then
		ResetSettings();
		Print("settings reset.");
	elseif ( msg == "" ) then
		ToggleOptions();
	else
		Print("/cr opens the options; /cr on | off | toggle | reset");
	end
end;
