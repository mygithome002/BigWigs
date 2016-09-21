--[[
    by Dorann
    https://github.com/xorann/BigWigs
    
	This is a small plugin to help mages track their ignite stack and hopefully prevents them from drawing aggro.
--]]

-- todo: sulfuron kill doesn't open the window

assert( BigWigs, "BigWigs not found!")

-----------------------------------------------------------------------
--      Are you local?
-----------------------------------------------------------------------

local L = AceLibrary("AceLocale-2.2"):new("BigWigsIgnite")
local LC = AceLibrary("AceLocale-2.2"):new("BigWigs")

local frame = nil

local syncName = {
	stop = "BWIgniteStop",
}

-----------------------------------------------------------------------
--      Localization
-----------------------------------------------------------------------

L:RegisterTranslations("enUS", function() return {
    ["Ignite"] = true,
	["ignite"] = true,
	["Disabled"] = true,
    ["Options for the ignite Display."] = true,
    ["Show frame"] = true,
    ["Show the ignite frame."] = true,
    ["Reset position"] = true,
	["Reset the frame position."] = true,
    ["font"] = "Fonts\\FRIZQT__.TTF",
	
	["Stacks"] = true,
	["Damage"] = true,
	["Owner"] = true,
	["Threat"] = true,
	["n/a"] = true, -- no threat data available
    ["Stop"] = true,
    ["your"] = true,
	["Your"] = true,

	fire_test = "^([%w]+)([%s's]*) ([%w%s:]+) crits ([%w%s:]+) for ([%d]+) ([%w]+) damage.",
	ignite_stack_test = "^([%w%s:]+) is afflicted by Ignite.[%s%(]*([%d]*)",
	ignite_damage_test = "^([%w%s:]+) suffers ([%d]+) Fire damage from ([%w]+)([%s's]*) Ignite.",
	ignite_fade_test = "^Ignite fades from ([%w%s:]+).",
	
	["Fireball"] = true,
	["Scorch"] = true,
	["Fire Blast"] = true,
	["Blastwave"] = true,
	["Flamestrike"] = true,
	["Pyroblast"] = true,
} end)

L:RegisterTranslations("deDE", function() return {
	["Disabled"] = "Deaktivieren",
	["Options for the ignite Display."] = "Optionen für die Entzündenanzeige",
    ["Show frame"] = "Fenster anzeigen",
	["Show the ignite frame."] = "Das Entzündenfenster anzeigen",
    ["Reset position"] = "Position zurücksetzen",
	["Reset the frame position."] = "Die Fensterposition zurücksetzen (bewegt das Fenster zur Ursprungsposition).",
	["font"] = "Fonts\\FRIZQT__.TTF",
	
	["Stacks"] = "Stapel",
	["Damage"] = "Schaden",
	["Owner"] = "Besitzer",
	["Threat"] = "Bedrohung",
	["n/a"] = "kA", -- no threat data available
    ["your"] = "euer", -- check this
	["Your"] = "Euer",
	
	fire_test = "^([%w]+)([%s's]*) ([%w%s:]+) trifft ([%w%s:]+) kritisch für ([%d]+) ([%w]+)schaden.", -- Saandro's Feuerball trifft Wächter des Anubisath kritisch für 2779 Feuerschaden.
	ignite_stack_test = "^([%w%s:]+) ist von Entzünden [%s%(]*([%d]*) betroffen.",
	ignite_damage_test = "^([%w%s:]+) erleidet ([%d]+) Feuerschaden von ([%w]+)([%s's]*) (durch Entzünden).",
	ignite_fade_test = "^Entzünden schwindet von ([%w%s:]+).",
	
	["Fireball"] = "Feuerball",
	["Scorch"] = "Versengen",
	["Fire Blast"] = "Feuerschlag",
	["Blastwave"] = "Druckwelle",
	["Flamestrike"] = "Flammenstoss",
	["Pyroblast"] = true,
} end)

-----------------------------------------------------------------------
--      Module Declaration
-----------------------------------------------------------------------

BigWigsIgnite = BigWigs:NewModule("Ignite")
BigWigsIgnite.revision = 20004
BigWigsIgnite.external = true
BigWigsIgnite.defaultDB = {
    posx = nil,
	posy = nil,
    isVisible = nil,
}
BigWigsIgnite.stacks = 0
BigWigsIgnite.damage = 0
BigWigsIgnite.owner = ""
BigWigsIgnite.threat = 0
BigWigsIgnite.seconds = nil
BigWigsIgnite.target = nil

BigWigsIgnite.consoleCmd = L["Ignite"]
BigWigsIgnite.consoleOptions = {
	type = "group",
	name = L["Ignite"],
	desc = L["Options for the ignite Display."],
	handler = BigWigsIgnite,
	pass = true,
	get = function(key)
		return BigWigsIgnite.db.profile[key]
	end,
	set = function(key, value)
		BigWigsIgnite.db.profile[key] = value
		if key == "disabled" then
			if value then
				BigWigsIgnite:Hide()
			else
				BigWigsIgnite:Show()
			end
		end
	end,
	args = {
        show = {
            type = "toggle",
            name = L["Show frame"],
            desc = L["Show the ignite frame."],
            order = 100,
            get = function() return BigWigsIgnite.db.profile.isVisible end,
            set = function(v) 
                BigWigsIgnite.db.profile.isVisible = v
                if v then
                    BigWigsIgnite:Show()
                else
                    BigWigsIgnite:Hide()
                end
            end,
        },
        reset = {
            type = "execute",
			name = L["Reset position"],
			desc = L["Reset the frame position."],
			order = 103,
			func = function() BigWigsIgnite:ResetPosition() end,
        },
		--[[spacer = {
			type = "header",
			name = " ",
			order = 104,
		},]]
	}
}

-----------------------------------------------------------------------
--      Initialization
-----------------------------------------------------------------------

function BigWigsIgnite:OnRegister()
	--BigWigs:RegisterBossOption("proximity", L["proximity"], L["proximity_desc"], OnOptionToggled)
end

function BigWigsIgnite:OnEnable()    
	self:RegisterEvent("BigWigs_RecvSync")
	
	self:RegisterEvent("BigWigsIgnite_Show", "Show")
	self:RegisterEvent("BigWigsIgnite_Hide", "Hide")
	
	self:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "PlayerDamageEvents")
	self:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE", "PlayerDamageEvents")
	self:RegisterEvent("CHAT_MSG_SPELL_PET_DAMAGE", "PlayerDamageEvents")
	self:RegisterEvent("CHAT_MSG_SPELL_PARTY_DAMAGE", "PlayerDamageEvents")
	self:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE", "PlayerDamageEvents")
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	self:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
	
	self:SetupFrames()

	self:DataReset()
	self.target = UnitName("target")
	
	--self.db.profile.isVisible = false
	if self.db.profile.isVisible then
		self:Show()
	end
end

function BigWigsIgnite:OnDisable()
	self:Hide()
end

-----------------------------------------------------------------------
--      Event Handlers
-----------------------------------------------------------------------

function BigWigsIgnite:Show()
    if not frame then
        self:SetupFrames()
    end
    self:Update() -- reset if necessary
    frame:Show()
    BigWigsIgnite.db.profile.isVisible = true
end

function BigWigsIgnite:Hide()
    if frame then 
        frame:Hide() 
        self:DebugMessage("BigWigsIgnite:Hide()")
        BigWigsIgnite.db.profile.isVisible = false
    end
end

-- reset data if your target dies
function BigWigsIgnite:CHAT_MSG_COMBAT_HOSTILE_DEATH(msg)
	if self.target then
        if msg == string.format(UNITDIESOTHER, self.target) or msg == string.format(LC["You have slain %s!"], self.target) then
            self.target = nil
            self:DataReset()
        end
    end
end

-- reset data if you change your target
function BigWigsIgnite:PLAYER_TARGET_CHANGED(msg)
	local target = UnitName("target")
	if target ~= self.target then		
		self:DataReset()
		self.target = target
	end
end

function BigWigsIgnite:PlayerDamageEvents(msg)
	--vulnerability_direct_test = "^[%w]+[%s's]* ([%w%s:]+) ([%w]+) Chromaggus for ([%d]+) ([%w]+) damage%.[%s%(]*([%d]*)", -- [Fashu's] [Firebolt] [hits] Battleguard Sartura for [44] [Fire] damage. ([14] resisted)
	--local name, s, spell, hitType, dmg, school, partial = string.find(msg, L["vulnerability_direct_test"]) 


	--direct_test = "^[%w]+[%s's]* ([%w%s:]+) crits [%w] for ([%d]+) Fire damage.", -- [Skrilla]['s] [Fireball] crits [Battleguard Sartura] for [3423] Fire damage.
	--local name, s, spell, hitType, victim, dmg = string.find(msg, L["direct_test"]) 
    
    -- check for fire spell crit
    --local fire_test = "^([%w]+)([%s's]*) ([%w%s:]+) crits ([%w%s:]+) for ([%d]+) ([%w]+) damage."
    local start, ending, name, _, spell, victim, dmg, school = string.find(msg, L["fire_test"])
	if name and spell and victim and self:IsMage(name) and self:IsIgniteSpell(spell) and self.target == victim then
		self:DebugMessage("mage fire spell crit: " .. name .. " " .. spell .. " " .. victim)
		if self.stacks == 0 and not self.owner then
			self.owner = name
		end
        return
	end
    
    -- check for ignite stacks
    --local ignite_stack_test = "^([%w%s:]+) is afflicted by Ignite.[%s%(]*([%d]*)"
    local start, ending, victim, stacks = string.find(msg, L["ignite_stack_test"])
    if victim and victim == self.target then
        if not stacks or stacks == "" then
            stacks = 1
        end
        self:DebugMessage(stacks .. " ignite stacks")
        self.stacks = stacks
        
        self:Update()
		return
    end
    
    -- check for ignite damage
    --local ignite_damage_test = "^([%w%s:]+) suffers ([%d]+) Fire damage from ([%w]+)([%s's]*) Ignite."
    local start, ending, victim, damage, owner = string.find(msg, L["ignite_damage_test"])
    if victim and victim == self.target and damage and owner then
        if owner == L["your"] then
            owner = UnitName("player")
        end
        self:DebugMessage("Ignite damage: owner: " .. owner .. " damage: " .. damage .. " victim: " .. victim)
        self.owner = owner
        self.damage = damage
		
		if self.stacks == 0 then
			--self.stacks = 5 -- assume 5 stacks if there is no information
			-- todo: check target debuffs
			for i = 1, 16 do
				local debuff, count = UnitDebuff("target", i) -- check count
				if debuff and debuff == "Interface\\Icons\\Spell_Fire_Incinerate" then
                    -- how do I find out how many stacks there are?
                    if count then
                        self:DebugMessage("stacks: " .. count)
                        self.stacks = count
                    else
                        self.stacks = 5
                    end
				end
			end
		end
        
        self:Update()
		--return
    end
    
    -- check for ignite fade
    --local ignite_fade_test = "^Ignite fades from ([%w%s:]+)."
    local start, ending, victim = string.find(msg, L["ignite_fade_test"])
    if victim and victim == self.target then
        self:DebugMessage("Ignite fades: victim: " .. victim)
        self:DataReset()
        self:HideWarning()
		
        self:Update()
		return
    end
    
    -- /run BigWigsIgnite:PlayerDamageEvents("Coyra's Fireball crits Ragged Timber Wolf for 3423 Fire damage.")
    -- /run BigWigs:Print(string.find("Coyra's Fireball crits Ragged Timber Wolf for 3423 Fire damage.", "^([%w]+)([%s's]*) ([%w%s:]+) crits ([%w%s:]+) for ([%d]+) ([%w]+) damage."))
    -- /run BigWigsIgnite:PlayerDamageEvents("Ragged Timber Wolf is afflicted by Ignite.")
    -- /run BigWigsIgnite:PlayerDamageEvents("Ragged Timber Wolf suffers 2812 Fire damage from Coyra's Ignite.")
    -- /run BigWigs:Print(string.find("Ragged Timber Wolf suffers 2812 Fire damage from your Ignite.", "^([%w%s:]+) suffers ([%d]+) Fire damage from ([%w]+)([%s's]*) Ignite."))
    -- /run BigWigsIgnite:PlayerDamageEvents("Ignite fades from Ragged Timber Wolf.")
end

--[[
Battleguard Sartura is afflicted by Ignite.
Battleguard Sartura is afflicted by Ignite (2).
Battleguard Sartura suffers 2812 Fire damage from Rokhart's Ignite.
Ignite fades from Battleguard Sartura.

Skrilla's Fireball crits Battleguard Sartura for 3423 Fire damage.
Nifexx's Scorch crits Battleguard Sartura for 1198 Fire damage.
Murc's Fire Blast crits Battleguard Sartura for 1857 Fire damage.

Blast Wave?
Flamestrike?
anything else?
]]

function BigWigsIgnite:BigWigs_RecvSync(sync, rest, nick)
	if sync == syncName.stop then
		self:ShowWarning()
	end
end

function BigWigsIgnite:ShowWarning()
	self:Message("Stop Firespells!", "Urgent", true, "Alarm")
	frame:SetBackdropColor(200/255, 30/255, 30/255)
end
function BigWigsIgnite:HideWarning()
	frame:SetBackdropColor(24/255, 24/255, 24/255)
end

-----------------------------------------------------------------------
--      Util
-----------------------------------------------------------------------
function BigWigsIgnite:DataReset()
	self.owner = ""
    self.damage = 0
    self.stacks = 0
	self.threat = L["n/a"]
	self.seconds = nil
	--self.target = nil
end

function BigWigsIgnite:IsMage(aName) 
	if aName then
		local num = GetNumRaidMembers()
		for i = 1, num do
			local raidUnit = string.format("raid%s", i)
			if UnitExists(raidUnit) then
				local name = UnitName(raidUnit)
				if name == aName then
                    local _, class = UnitClass(raidUnit)
					if class == "Mage" then
                        return true
                    end
				end
			end
		end
	end
	return false
end
function BigWigsIgnite:IsIgniteSpell(spell)
	if spell == L["Fireball"] or spell == L["Scorch"] or spell == L["Fire Blast"] or spell == L["Blastwave"] or spell == L["Flamestrike"] then
		return true
	end
	return false
end

function BigWigsIgnite:Update()
	--[[
	Stacks: 5
	Damage: 1234
	Owner: Nifexx
	Threat: 99% (5s)
	]]

	self:UpdateThreat(self.owner)	
	
	local text = ""
    text = L["Stacks"] .. ": " .. self.stacks .."\n"
	text = text .. L["Damage"] .. ": " .. self.damage .."\n"
	text = text .. L["Owner"] .. ": " .. self.owner .."\n"
	text = text .. L["Threat"] .. ": " .. self.threat
	
	if self.seconds then
		text = text .. " " .. self.seconds
	end
	
	if not frame then 
		self:SetupFrames() 
	end
    frame.text:SetText(tostring(text))
	
    -- update displayed text
    local function red(t)
        return "|cffff0000" .. t .. "|r"
    end
    local function green(t)
        return "|cff00ff00" .. t .. "|r"
    end
end

function BigWigsIgnite:UpdateThreat(name)
	if name and IsAddOnLoaded("KLHThreatMeter") then
		local data, playerCount, threat100 = KLHTM_GetRaidData()
		local okay = false
		for i = 1, table.getn(data) do
			if name == data[i].name then
				self.threat = data[i].threat / threat100 * 100
				self.threat = tonumber(string.format("%.0f", self.threat))
				self.threat = self.threat .. "%"
				okay = true
				break
			end
		end
		
		if okay then
			-- calculate how long it would take to draw aggro with the current ignite
			if self.owner and self.damage then
				local difference = threat100 - self.threat
				self.seconds = difference / (self.damage / 2) -- todo: threat multiplier, calculate for 130% instead of 100%?
				self.seconds = tonumber(string.format("%.0f", self.seconds))
				self.seconds = "(" .. self.seconds .. "s)"
			end
		else
			self.threat = L["n/a"]
			self.seconds = nil
		end
	else
		self.threat = L["n/a"]
		self.seconds = nil
	end
end


------------------------------
--    Create the Frame     --
------------------------------

function BigWigsIgnite:SetupFrames()
	if frame then return end

    frame = CreateFrame("Frame", "BigWigsIgniteFrame", UIParent)
	frame:Hide()

	frame:SetWidth(130)
	frame:SetHeight(130)

	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16,
		edgeFile = "Interface\\AddOns\\BigWigs\\Textures\\otravi-semi-full-border", edgeSize = 32,
        --edgeFile = "", edgeSize = 32,
		insets = {left = 1, right = 1, top = 20, bottom = 1},
	})

	frame:SetBackdropColor(24/255, 24/255, 24/255)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetMovable(true)
	frame:SetScript("OnDragStart", function() this:StartMoving() end)
	frame:SetScript("OnDragStop", function()
		this:StopMovingOrSizing()
		self:SavePosition()
	end)

	local cheader = frame:CreateFontString(nil, "OVERLAY")
	cheader:ClearAllPoints()
	cheader:SetWidth(120)
	cheader:SetHeight(15)
	cheader:SetPoint("TOP", frame, "TOP", 0, -14)
	cheader:SetFont(L["font"], 12)
	cheader:SetJustifyH("LEFT")
	cheader:SetText(L["Ignite"])
	cheader:SetShadowOffset(.8, -.8)
	cheader:SetShadowColor(0, 0, 0, 1)
	frame.cheader = cheader

	local text = frame:CreateFontString(nil, "OVERLAY")
	text:ClearAllPoints()
	text:SetWidth( 120 )
	text:SetHeight( 130 )
	text:SetPoint( "TOP", frame, "TOP", 0, -35 )
	text:SetJustifyH("CENTER")
	text:SetJustifyV("TOP")
	text:SetFont(L["font"], 12)
	frame.text = text

	--[[local stopbutton = CreateFrame("Button", nil)
    stopbutton:ClearAllPoints()
	stopbutton:SetParent(frame)
	stopbutton:SetWidth(40)
	stopbutton:SetHeight(25)
	stopbutton:SetPoint("CENTER", frame, "CENTER", 0, 25) -- position the button
	stopbutton:SetScript("OnClick", function() self:Sync(syncName.stop) end)
	frame.stopbutton = stopbutton]]
    stopbutton = CreateFrame("Button", nil, frame)
	stopbutton.owner = self
	stopbutton:SetWidth(40)
	stopbutton:SetHeight(25)
	stopbutton:SetPoint("CENTER", frame, "CENTER", 0, -35)
	stopbutton:SetScript("OnClick", function() self:Sync(syncName.stop) end)
    
    local texture = stopbutton:CreateTexture()
	texture:SetWidth(50)
	texture:SetHeight(32)
	texture:SetPoint("CENTER", stopbutton, "CENTER")
	texture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
	texture:SetTexCoord(0, 0.625, 0, 0.6875)
	stopbutton:SetNormalTexture(texture)

	texture = stopbutton:CreateTexture(nil, "BACKGROUND")
	texture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Down")
	texture:SetTexCoord(0, 0.625, 0, 0.6875)
	texture:SetAllPoints(stopbutton)
	stopbutton:SetPushedTexture(texture)

	texture = stopbutton:CreateTexture()
	texture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
	texture:SetTexCoord(0, 0.625, 0, 0.6875)
	texture:SetAllPoints(stopbutton)
	texture:SetBlendMode("ADD")
	stopbutton:SetHighlightTexture(texture)
	local stopbuttontext = stopbutton:CreateFontString(nil,"OVERLAY")
	stopbuttontext:SetFontObject(GameFontHighlight)
	stopbuttontext:SetText(L["Stop"])
	stopbuttontext:SetAllPoints(stopbutton)
    
	
	local close = frame:CreateTexture(nil, "ARTWORK")
	close:SetTexture("Interface\\AddOns\\BigWigs\\Textures\\otravi-close")
	close:SetTexCoord(0, .625, 0, .9333)

	close:SetWidth(20)
	close:SetHeight(14)
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -7, -15)

	local closebutton = CreateFrame("Button", nil)
	closebutton:SetParent(frame)
	closebutton:SetWidth(20)
	closebutton:SetHeight(14)
	closebutton:SetPoint("CENTER", close, "CENTER")
	closebutton:SetScript( "OnClick", function() self:Hide() end )

	local x = self.db.profile.posx
	local y = self.db.profile.posy
	if x and y then
		local s = frame:GetEffectiveScale()
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s, y / s)
	else
		self:ResetPosition()
	end
    
    self:Update()
end

function BigWigsIgnite:ResetPosition()
	if not frame then self:SetupFrames() end
	frame:ClearAllPoints()
	--frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 1000, 500)
	self.db.profile.posx = nil
	self.db.profile.posy = nil
end

function BigWigsIgnite:SavePosition()
	if not frame then self:SetupFrames() end

	local s = frame:GetEffectiveScale()
	self.db.profile.posx = frame:GetLeft() * s
	self.db.profile.posy = frame:GetTop() * s
end
