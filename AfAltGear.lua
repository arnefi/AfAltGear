-----------------------------------------------------------------------------------------------
-- Client Lua Script for AfAltGear
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "GameLib"
require "Item"
 

-----------------------------------------------------------------------------------------------
-- AfAltGear Module Definition
-----------------------------------------------------------------------------------------------

local AfAltGear = {} 

 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------

local strVersion = "@project-version@"

 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------

function AfAltGear:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
	o.Sets = {}
	o.AutoOpen = true
    return o
end


function AfAltGear:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- AfAltGear OnLoad
-----------------------------------------------------------------------------------------------

function AfAltGear:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("AfAltGear.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
	Apollo.LoadSprites("AfAltGearSprites.xml", "AfAltGearSprites")
end


-----------------------------------------------------------------------------------------------
-- AfAltGear OnDocLoaded
-----------------------------------------------------------------------------------------------

function AfAltGear:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "AfAltGearForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
		self.wndMain:FindChild("version"):SetText(strVersion)
		
	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("afalt", "OnAfAltGearOn", self)
		Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
		Apollo.RegisterEventHandler("AfAltGear_Show", "OnAfAltGearOn", self)
		
		
		Apollo.RegisterEventHandler("LootRollUpdate",		"OnLootRollUpdate", self)
	    Apollo.RegisterTimerHandler("LootUpdateTimer", 		"OnUpdateTimer", self)
	
		Apollo.CreateTimer("LootUpdateTimer", 1.0, false)
		Apollo.StopTimer("LootUpdateTimer")
		
		--self.timer = ApolloTimer.Create(1.0, true, "OnTimer", self)

		-- Do additional Addon initialization here
	end
end


-----------------------------------------------------------------------------------------------
-- AfAltGear: Insert Menu Ion
-----------------------------------------------------------------------------------------------

function AfAltGear:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "afAltGear", {"AfAltGear_Show", "", "AfAltGearSprites:gear"})
end


-----------------------------------------------------------------------------------------------
-- AfAltGear: Save and Restore Settings
-----------------------------------------------------------------------------------------------

function AfAltGear:OnSave(eType)
	if eType == GameLib.CodeEnumAddonSaveLevel.Account then
		local tSavedData = {}
		tSavedData.location2 = self.location and self.location:ToTable() or nil
		return tSavedData		
	end
	if eType == GameLib.CodeEnumAddonSaveLevel.Character then
		local tSavedData = {}
		tSavedData.Sets = self.Sets
		tSavedData.lastSet = self.currentSet or nil
		tSavedData.AutoOpen = self.AutoOpen
		return tSavedData
	end
	return
end


function AfAltGear:OnRestore(eType, tSavedData)
	if eType == GameLib.CodeEnumAddonSaveLevel.Account then
		if tSavedData.location2 ~= nil then self.location = WindowLocation.new(tSavedData.location2) end
	end
	if eType == GameLib.CodeEnumAddonSaveLevel.Character then
		if tSavedData.Sets ~= nil then self.Sets = tSavedData.Sets end
		if tSavedData.lastSet ~= nil then
			self.lastSet = tSavedData.lastSet
			self.currentSet = tSavedData.lastSet
		end
		if tSavedData.AutoOpen ~= nil then self.AutoOpen = tSavedData.AutoOpen end
	end
end


-----------------------------------------------------------------------------------------------
-- AfAltGear: Rolling for Loot
-----------------------------------------------------------------------------------------------

function AfAltGear:OnLootRollUpdate()
	if not self.bTimerRunning then
		Apollo.StartTimer("LootUpdateTimer")
		self.bTimerRunning = true
		
	end
end


function AfAltGear:UpdateKnownLoot()
	self.tLootRolls = GameLib.GetLootRolls()
	if (not self.tLootRolls or #self.tLootRolls == 0) then
		self.tLootRolls = nil
		return
	end
end


function AfAltGear:OnUpdateTimer()
	self:UpdateKnownLoot()
	
	if self.tLootRolls and #self.tLootRolls > 0 then
		Apollo.StartTimer("LootUpdateTimer")
		if self.AutoOpen then
			local doShow = false
			for idx, iitem in pairs(self.tLootRolls) do
				theItem = iitem.itemDrop
				self:log(theItem:GetItemFamilyName())
				self:log(theItem:GetItemTypeName())
				if theItem:CanEquip() then
					doShow = true
				end
			end
			if doShow then
				if not self.wndMain:IsShown() then
					self.wndMain:Invoke()
				end
			else
				if self.wndMain:IsShown() then
					self.wndMain:Show(false)
				end
			end
		end
	else
		self.bTimerRunning = false
		if self.AutoOpen then
			self.wndMain:Show(false)
		end
	end
end


-----------------------------------------------------------------------------------------------
-- AfAltGear: Build List of Saved Sets
-----------------------------------------------------------------------------------------------

function AfAltGear:RefreshSetList()
	local wndSetList = self.wndMain:FindChild("SetList")
	wndSetList:DestroyChildren()
	
	for idx, entry in pairs(self.Sets) do
		local wndCurr = Apollo.LoadForm(self.xmlDoc, "Listentry", wndSetList, self)
		wndCurr:SetData(idx)
		wndCurr:FindChild("lblEntry"):SetText(entry["name"])
	end
	wndSetList:ArrangeChildrenVert()
end


-----------------------------------------------------------------------------------------------
-- AfAltGear: Show Main Window - invoked by Slash Command and Menu Icon
-----------------------------------------------------------------------------------------------

function AfAltGear:OnAfAltGearOn()
	if self.wndMain:IsShown() then 
		self.location = self.wndMain:GetLocation()
		self.wndMain:Close() 
		return
	end
	self.wndMain:Invoke()
	if self.lastSet then
		self:LoadSet(self.lastSet)
		self.lastSet = nil
	end
	self.wndMain:FindChild("chkAutoOpen"):SetCheck(self.AutoOpen)
	if self.location then self.wndMain:MoveToLocation(self.location) end
	self:RefreshSetList()
end


-----------------------------------------------------------------------------------------------
-- AfAltGear: log to system chat
-----------------------------------------------------------------------------------------------

function AfAltGear:log (strMeldung)
	if strMeldung == nil then strMeldung = "nil" end
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, strMeldung, "afAltGear")
end


-----------------------------------------------------------------------------------------------
-- AfAltGear: Timer - not used right now
-----------------------------------------------------------------------------------------------

function AfAltGear:OnTimer()
	-- Do your timer-related stuff here.
end


-----------------------------------------------------------------------------------------------
-- AfAltGear: FORM SPECIFIC FUNCTIONS
-----------------------------------------------------------------------------------------------


-----------------------------------------------------------------------------------------------
-- AfAltGear: OK-Button
-----------------------------------------------------------------------------------------------

function AfAltGear:OnOK()
	self.location = self.wndMain:GetLocation()
	self.wndMain:Close()
end


-----------------------------------------------------------------------------------------------
-- AfAltGear: Save Current Gear as new Set
-----------------------------------------------------------------------------------------------

function AfAltGear:OnSaveSet(wndHandler, wndControl, eMouseButton)
	local equip = GameLib.GetPlayerUnit():GetEquippedItems()
	local sName = self.wndMain:FindChild("txtSetName"):GetText()
	if sName == "" then
		sName = "new set"
	end
	
	local equip_ids = {}
	for idx, entry in pairs(equip) do
		equip_ids[entry:GetInventoryId()] = entry:GetItemId()
	end
	local Set = { ["name"] = sName, ["equip"] = equip_ids }
	table.insert(self.Sets, Set)
	self:RefreshSetList()	
end


-----------------------------------------------------------------------------------------------
-- AfAltGear: Overwrite Current Set with current Gear
-----------------------------------------------------------------------------------------------

function AfAltGear:OnOverwriteSet( wndHandler, wndControl, eMouseButton )
	if self.currentSet == nil then return end
	if self.Sets[self.currentSet] == nil then return end
	local equip = GameLib.GetPlayerUnit():GetEquippedItems()
	local equip_ids = {}
	for idx, entry in pairs(equip) do
		equip_ids[entry:GetInventoryId()] = entry:GetItemId()
	end	
	self.Sets[self.currentSet]["equip"] = equip_ids
	self:ReSet()
	self.currentSet = nil
end


-----------------------------------------------------------------------------------------------
-- AfAltGear: Delete Current Set
-----------------------------------------------------------------------------------------------

function AfAltGear:OnDeleteSet( wndHandler, wndControl, eMouseButton )
	if self.currentSet == nil then return end
	if self.Sets[self.currentSet] == nil then return end
	self.Sets[self.currentSet] = nil
	self:RefreshSetList()
	self:ReSet()
	self.currentSet = nil
end


-----------------------------------------------------------------------------------------------
-- AfAltGear: Build Permanent Tooltip for Selected Item
-----------------------------------------------------------------------------------------------

function AfAltGear:OnItemClicked(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation)
	local sName = wndControl:GetName()
	local id
	for match in string.gmatch(sName, "item(%d+)d") do id = tonumber(match) end
	if id == nil then return end
	if self.Sets[self.currentSet]["equip"][id] == nil then return end
	local item = Item.GetDataFromId(self.Sets[self.currentSet]["equip"][id])
	
	local wndChatItemToolTip = Apollo.LoadForm(self.xmlDoc, "ToolTipWindow", nil, self)
	
	wndChatItemToolTip:SetData(item)
	
	local itemEquipped = false

	local wndLink = Tooltip.GetItemTooltipForm(self, wndControl:GetParent(), item, {bPermanent = true, wndParent = wndChatItemToolTip, bSelling = false, bNotEquipped = true})

	local nLeftWnd, nTopWnd, nRightWnd, nBottomWnd = wndChatItemToolTip:GetAnchorOffsets()
	local nLeft, nTop, nRight, nBottom = wndLink:GetAnchorOffsets()

	wndChatItemToolTip:SetAnchorOffsets(nLeftWnd, nTopWnd, nLeftWnd + nRight + 15, nBottom + 75)
	--self.wndMain:Show(false)
end


-----------------------------------------------------------------------------------------------
-- AfAltGear: Delete All Icons and Tooltips
-----------------------------------------------------------------------------------------------

function AfAltGear:ReSet()
	local filter = {[0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [7] = true, [8] = true, [10] = true, [11] = true, [15] = true, [16] = true}
	for idx,_ in pairs(filter) do
		local feld = self.wndMain:FindChild("item"..idx.."d")
		feld:SetSprite()
		feld:SetTooltip("")
		self.wndMain:FindChild("lblSetName"):SetText("No set selected")
	end
end


-----------------------------------------------------------------------------------------------
-- AfAltGear: Load Set
-----------------------------------------------------------------------------------------------

function AfAltGear:OnSetClicked( wndHandler, wndControl, eMouseButton )
	local idx = wndHandler:GetParent():GetData()
	self:LoadSet(idx)
end


-----------------------------------------------------------------------------------------------
-- AfAltGear: Load set
-----------------------------------------------------------------------------------------------

function AfAltGear:LoadSet(idx)
	self.currentSet = idx
	local filter = {[0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [7] = true, [8] = true, [10] = true, [11] = true, [15] = true, [16] = true}
	
	for idx,_ in pairs(filter) do
		local feld = self.wndMain:FindChild("item"..idx.."d")
		feld:SetSprite()
		feld:SetTooltip("")
	end
	
	if self.Sets[idx] then
		self.wndMain:FindChild("lblSetName"):SetText("Current set: "..self.Sets[idx]["name"])
		
		local equip = self.Sets[idx]["equip"]
		
		for slot, itemID in pairs(equip) do 
			if filter[slot] then 
				local feld = self.wndMain:FindChild("item"..slot.."d")
				local itemInfo = Item.GetDataFromId(itemID)
				if feld then
					feld:SetSprite(itemInfo:GetIcon())
					wndTooltip = Tooltip.GetItemTooltipForm(self, feld, itemInfo, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
				end
			end
		end			
		
	else
		self.wndMain:FindChild("lblSetName"):SetText("Set not found")
	end
end


---------------------------------------------------------------------------------------------------
-- AfAltGear: AutoLoot Setting
---------------------------------------------------------------------------------------------------

function AfAltGear:OnToggleAutoLoot(wndHandler, wndControl, eMouseButton)
	self.AutoOpen = wndControl:IsChecked()
end


-----------------------------------------------------------------------------------------------
-- AfAltGear: Tooltip Close Button
-----------------------------------------------------------------------------------------------

function AfAltGear:OnCloseItemTooltipWindow( wndHandler, wndControl, eMouseButton )
	wndControl:GetParent():Destroy()
end


-----------------------------------------------------------------------------------------------
-- AfAltGear Instance
-----------------------------------------------------------------------------------------------
local AfAltGearInst = AfAltGear:new()
AfAltGearInst:Init()
