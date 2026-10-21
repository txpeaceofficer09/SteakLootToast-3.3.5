local TOAST_WIDTH = 440
local TOAST_HEIGHT = 100
local TOAST_DURATION = 4
local ICON_SIZE = 64

local toastQueue = {}
local showingToast = false
local currentItem = nil

local QUALITY_COLORS = {
	[3] = { 0.00, 0.44, 0.87 }, -- Rare
	[4] = { 0.64, 0.21, 0.93 }, -- Epic
	[5] = { 1.00, 0.50, 0.00 } -- Legendary
}

local QUALITY_FRAME_COORDS = {
	[3] = { 890, 946, 0, 60 }, -- Rare
	[4] = { 949, 1006, 0, 60 }, -- Epic
	[5] = { 829, 886, 0, 60 } -- Legendary
}

local function GetItemID(itemLink)
	if not itemLink then return nil end

	return tonumber(itemLink:match("item:(%d+)"))
end

local function SetQualityFrame(texture, quality)
	local coords = QUALITY_FRAME_COORDS[quality]

	if not coords then
		texture:Hide()
		return
	end

	texture:SetTexture("Interface\\FrameXML\\Rebuffed\\ItemUpgrade\\Media\\LootToast")
	texture:SetTexCoord(coords[1] / 1024, coords[2] / 1024, coords[3] / 256, coords[4] / 256)
	texture:SetVertexColor(1, 1, 1, 1)
	texture:Show()
end

local Toast = CreateFrame("Frame", "SteakLootToastFrame", UIParent)
Toast:SetSize(TOAST_WIDTH, TOAST_HEIGHT)
Toast:SetPoint("TOP", UIParent, "TOP", 0, -180)
Toast:SetFrameStrata("DIALOG")
Toast:SetFrameLevel(100)
Toast:Hide()

Toast.bg = Toast:CreateTexture(nil, "BACKGROUND")
Toast.bg:SetTexture("Interface\\FrameXML\\Rebuffed\\ItemUpgrade\\Media\\LootToast")
Toast.bg:SetTexCoord(300 / 1024, 555 / 1024, 158 / 256, 233 / 256)
Toast.bg:SetAllPoints(Toast)

Toast.icon = Toast:CreateTexture(nil, "ARTWORK")
Toast.icon:SetSize(ICON_SIZE, ICON_SIZE)
Toast.icon:SetPoint("LEFT", Toast, "LEFT", 34, 0)
Toast.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

Toast.iconBorder = Toast:CreateTexture(nil, "OVERLAY")
Toast.iconBorder:SetSize(ICON_SIZE + 14, ICON_SIZE + 14)
Toast.iconBorder:SetPoint("CENTER", Toast.icon, "CENTER")
Toast.iconBorder:Hide()

Toast.title = Toast:CreateFontString(nil, "OVERLAY")
Toast.title:SetFont("Interface\\AddOns\\SteakLootToast\\Audiowide-Regular.ttf", 14, "OUTLINE")
Toast.title:SetPoint("TOPLEFT", Toast.icon, "TOPRIGHT", 32, -26)
Toast.title:SetText("ITEM RECEIVED")
Toast.title:SetTextColor(1, 0.82, 0)

Toast.itemName = Toast:CreateFontString(nil, "OVERLAY")
Toast.itemName:SetFont("Interface\\AddOns\\SteakLootToast\\Audiowide-Regular.ttf", 16, "OUTLINE")
Toast.itemName:SetPoint("TOPLEFT", Toast.title, "BOTTOMLEFT", 0, -7)
Toast.itemName:SetPoint("RIGHT", Toast, "RIGHT", -14, 0)
Toast.itemName:SetJustifyH("LEFT")
Toast.itemName:SetWordWrap(false)

function Toast:ShowLoot(itemLink)
	local itemID = GetItemID(itemLink)

	if not itemID then return false end

	local itemName, resolvedLink, quality, _, _, _, _, _, equipLoc, itemTexture = GetItemInfo(itemID)

	if not itemName or not quality then return false end
	if not QUALITY_COLORS[quality] then return false end
	if not equipLoc or equipLoc == "" then return false end

	local r, g, b = unpack(QUALITY_COLORS[quality])

	self.icon:SetTexture(itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
	SetQualityFrame(self.iconBorder, quality)

	self.itemName:SetText(itemName)
	self.itemName:SetTextColor(r, g, b)

	self.timer = 0
	self:SetAlpha(1)
	self:Show()

	PlaySoundFile("Interface\\FrameXML\\Rebuffed\\ItemUpgrade\\Media\\ui_epicloot_toast_01.ogg")

	currentItem = itemID
	return true
end

function Toast:QueueLoot(itemLink)
	if not itemLink then return end

	table.insert(toastQueue, { link = itemLink })

	self:ShowNextToast()
end

function Toast:ShowNextToast()
	if showingToast then return end

	while #toastQueue > 0 do
		local entry = table.remove(toastQueue, 1)

		if self:ShowLoot(entry.link) then
			showingToast = true
			return
		end
	end
end

local function OnEvent(self, event, message)
	if not message then return end

	if not 	(message:find("You receive loot:", 1, true) or message:find("You receive item:", 1, true) or message:find("You loot:", 1, true) or message:find("You receive", 1, true)) then return end

	local itemLink = message:match("(|c%x+|Hitem:[^|]+|h%[[^]]+%]|h|r)")

	if itemLink then Toast:QueueLoot(itemLink) end
end

local function OnUpdate(self, elapsed)
	if not self:IsShown() then return end

	self.timer = (self.timer or 0) + elapsed
	if self.timer < TOAST_DURATION then return end

	local curAlpha = self:GetAlpha()

	if curAlpha > 0 then
		self:SetAlpha(curAlpha - 0.02)
	else
		self:Hide()
		self:SetAlpha(1)
		showingToast = false
		currentItem = nil
	end

	Toast:ShowNextToast()
end

Toast:SetScript("OnUpdate", OnUpdate)
Toast:SetScript("OnEvent", OnEvent)

Toast:RegisterEvent("CHAT_MSG_LOOT")
