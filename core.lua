Softresit = LibStub("AceAddon-3.0"):NewAddon("Softresit", "AceEvent-3.0", "AceHook-3.0", "AceComm-3.0")
local AceGUI = LibStub("AceGUI-3.0")

local defaults = {
	factionrealm = {
		minimapButton = {
			hide = false
		},
		csv = "",
		softReserves = {},
		itemQueue = {},
	}
}


Softresit.opened = false
Softresit.debug = true

Softresit.frameIndex = 0
Softresit.frames = {}

--define print fn in my addon so it is easy to turn ViragDevTool off
local function vdt_log(strName, tData)
	if ViragDevTool_AddData and Softresit.debug then
		ViragDevTool_AddData(tData, "Softresit: " .. strName)
	end
end

function Softresit:InitMinimapIcon()
	LibStub("LibDBIcon-1.0"):Register("Softresit", LibStub("LibDataBroker-1.1"):NewDataObject("Softresit",
		{
			type = "data source",
			text = "Softres.it",
			icon = "Interface\\Icons\\Inv_misc_bag_10_black",
			OnClick = function(self, button)
				if (button == "LeftButton") then
					Softresit:OpenFrame("csv")
				end

				if (button == "MiddleButton") then
					Softresit:OpenOptions()
				end

				if (button == "RightButton") then
					Softresit:OpenFrame("raid")
				end

			end,
			OnTooltipShow = function(tooltip)
				tooltip:AddLine("Softres.it");
				tooltip:AddLine("|cFFCFCFCFLeft Click: |rOpen CSV Dialog");
				tooltip:AddLine("|cFFCFCFCFRight Click: |rOpen Raid Overview");
				tooltip:AddLine("|cFFCFCFCFMiddle Click: |rOpen Config");
			end
		}), self.db.factionrealm.minimapButton);
end

function Softresit:GetRaiders()
	local raid = {}

	if IsInRaid() then
		for i = 1, 40 do
			local name, _, _ = GetRaidRosterInfo(i)
			if name then
				tinsert(raid, name)
			end
		end
	end

    return raid
end

function Softresit:getReservesItem(id)
	local reservers = {}

	for k,v in pairs(Softresit:getReserves()) do
		if v.id == id then
			tinsert(reservers, v)
		end
	end

	return reservers
end

function Softresit:getReservesName(name)
	local items = {}

	for k,v in pairs(Softresit:getReserves()) do
		if v.name == name then
			tinsert(items, v)
		end
	end

	return items
end

function Softresit:initRaidTooltip()
	raidFrameTooltip = CreateFrame( "GameTooltip", "RaidOverviewFrameTooltip", nil, "GameTooltipTemplate" ); -- Tooltip name cannot be nil
	raidFrameTooltip:SetOwner( UIParent, "ANCHOR_NONE" );
end

function Softresit:getReserves()
	return self.db.factionrealm.softReserves
end

function Softresit:resetReserves()
	self.db.factionrealm.softReserves = {}
end

function Softresit:ItemLabel(itemId)
	local itemLabel = AceGUI:Create("InteractiveLabel")
	local _,link,_,_,_,_,_,_,_,icon = GetItemInfo(itemId)
	itemLabel:SetText(link);
	itemLabel:SetImage(icon);
	itemLabel:SetImageSize(16,16)
	itemLabel:SetCallback("OnEnter", function(widget, arg1, arg2)
		GameTooltip:SetOwner(widget.frame, "ANCHOR_TOPRIGHT")
		GameTooltip:SetHyperlink(link);
		GameTooltip:Show();
	end)
	itemLabel:SetCallback("OnLeave", function(widget, arg1, arg2)
		GameTooltip:SetOwner(UIParent, "ANCHOR_TOPRIGHT")
		GameTooltip:Hide();
	end)
	return itemLabel
end

-- TODO
-- make item label function to avoid duplication, maybe player label too
-- figure out how to resize the scroll list once items are dismissed, maybe need to manually from children
function Softresit:AnnounceItem(itemId) print("announcing",(GetItemInfo(itemId)))end

function Softresit:LootFrame(itemId)
	local group = AceGUI:Create("SimpleGroup")
	group:SetFullWidth(true)

	local itemlabel = self:ItemLabel(itemId)
	itemlabel:SetRelativeWidth(0.5);

	local announceBtn = AceGUI:Create("Button")
	announceBtn:SetText("Announce")
	announceBtn:SetCallback("OnClick", function()
		self:AnnounceItem(itemId)
	end)
	announceBtn:SetRelativeWidth(0.25)

	local dismissBtn = AceGUI:Create("Button")
	dismissBtn:SetText("Dismiss")
	dismissBtn:SetCallback("OnClick", function()
		local tbl = self.db.factionrealm.itemQueue
		tbl[itemId] = tbl[itemId] - 1
		self:SetDB("itemQueue",tbl)
	end)
	dismissBtn:SetRelativeWidth(0.25)

	group:SetLayout("Flow")
	group:AddChild(itemlabel)
	group:AddChild(announceBtn)
	group:AddChild(dismissBtn)

	for _,raider in pairs(Softresit:getReservesItem(itemId)) do
			local label = AceGUI:Create("InteractiveLabel")
			label:SetText(raider.cName)
			label:SetWidth(80)
			group:AddChild(label)
	end

	local spacer = AceGUI:Create("Heading")
	spacer:SetFullWidth(true)
	group:AddChild(spacer)

	return group
end

function Softresit:LootWindow()
	local window = AceGUI:Create("Window")
	window:SetTitle("Loot")
	window:SetLayout("Fill")
	window:SetWidth(500)

	local scrollContainer = AceGUI:Create("SimpleGroup")
	scrollContainer:SetFullWidth(true)
	scrollContainer:SetFullHeight(true)
	scrollContainer:SetLayout("Fill")

	window:AddChild(scrollContainer)

	local scrollFrame = AceGUI:Create("ScrollFrame")
	scrollFrame:SetLayout("Flow")
	scrollContainer:AddChild(scrollFrame)

	local function populate()
		scrollFrame:ReleaseChildren() -- clear and repopulate seems to be the only way of doing this
		for itemId,amount in pairs(self.db.factionrealm.itemQueue) do
			if amount > 0 then
				scrollFrame:AddChild(Softresit:LootFrame(itemId))
			end
		end
	end
	self:OnDB(scrollFrame,"itemQueue",populate)
	populate()
end


function Softresit:CSVFrame(container)
	local editMode = false
	local editButton = AceGUI:Create("Button")
	local csvEditBox = AceGUI:Create("MultiLineEditBox")
	local resetButton = AceGUI:Create("Button")
	local synchGroup = AceGUI:Create("InlineGroup")

	editButton:SetCallback("OnClick", function()
		if editMode then
			self.db.factionrealm.csv = csvEditBox:GetText()
			self.db.factionrealm.softReserves = self:parseCSV(csvEditBox:GetText())
			self.db.factionrealm.csvSource = "Edited by you | " .. date("%m/%d/%y %H:%M:%S")
			self.UpdateCsvSourceText()

	    	editMode = false
	    	editButton:SetText("Edit CSV")
			csvEditBox:SetDisabled(true)
	    else
	    	csvEditBox:SetDisabled(false)
	    	csvEditBox:SetFocus()
			editButton:SetText("Save")
	    	editMode = true
		end
	end)
	editButton:SetText("Edit CSV")
	editButton:SetRelativeWidth(0.5)

	csvEditBox:SetFullWidth(true)
	csvEditBox:SetNumLines(15)
	csvEditBox:SetLabel("Softres.it CSV")
	csvEditBox:SetCallback("OnTextChanged", function(widget, arg1, text)
		if strlen(text) > 0 then
			resetButton:SetDisabled(false)
			editButton:SetText("Save")
		else
			resetButton:SetDisabled(true)
		end
	end)

	if strlen(self.db.factionrealm.csv) > 0 then
		csvEditBox:SetDisabled(true)
	else
		editMode = true
		csvEditBox:SetFocus()
	end

	csvEditBox:SetText(self.db.factionrealm.csv)
	csvEditBox:DisableButton(true)
	container:AddChild(csvEditBox)
	container:AddChild(editButton)

	resetButton:SetCallback("OnClick", function()
		csvEditBox:SetText("")
		self.db.factionrealm.csv = ""
		self.db.factionrealm.csvSource = "Edited by you | " .. date("%m/%d/%y %H:%M:%S")
		self.UpdateCsvSourceText()
		Softresit:resetReserves()
		resetButton:SetDisabled(true)
		editButton:SetDisabled(true)
		editMode = true
		csvEditBox:SetDisabled(false)
		csvEditBox:SetFocus()
	end)
	resetButton:SetText("Reset CSV")
	resetButton:SetRelativeWidth(0.5)
	container:AddChild(resetButton)

	local broadcastBtn = AceGUI:Create("Button")
	broadcastBtn:SetCallback("OnClick",function()
		if self:AddonChannel() then
			self:SendCommMessage("SRITCSV", self.db.factionrealm.csv, self:AddonChannel(), "BULK")
		elseif self.debug then
			self:SendCommMessage("SRITCSV", self.db.factionrealm.csv, "WHISPER", UnitName("player"), "BULK")
		end
	end)
	broadcastBtn:SetText("Share")
	broadcastBtn:SetRelativeWidth(1)

	local csvSourceText = AceGUI:Create("Label")
	csvSourceText:SetText("Source: " .. self.db.factionrealm.csvSource)
	csvSourceText:SetRelativeWidth(1)
	-- kind of awkward way to update from other functions, would like some sort of render method with an update state thing maybe
	self.UpdateCsvSourceText = function()
		csvSourceText:SetText(self.db.factionrealm.csvSource)
	end
	--self.UpdateCsvSourceText()

	local requestBtn = AceGUI:Create("Button")
	requestBtn:SetCallback("OnClick",function()
		local target = self:GetGroupLeader()
		if not target and self.debug then target = UnitName("player") end
		if target then self:SendCommMessage("SRITREQ", "-", "WHISPER", target) end
	end)
	requestBtn:SetText("Request")
	requestBtn:SetRelativeWidth(1)

	synchGroup:SetTitle("CSV Sharing")
	synchGroup:SetRelativeWidth(0.4)
	synchGroup:SetLayout("Flow")
	synchGroup:AddChild(broadcastBtn)
	synchGroup:AddChild(requestBtn)
	synchGroup:AddChild(csvSourceText)

	container:AddChild(synchGroup)
end

function Softresit:RaidFrame(container)

end

function Softresit:SoftReservesFrame(container)
	local itemIds = {}
	local scrollcontainer = AceGUI:Create("SimpleGroup")
	scrollcontainer:SetFullWidth(true)
	scrollcontainer:SetFullHeight(true)
	scrollcontainer:SetLayout("Fill")
	container:AddChild(scrollcontainer)

	local scroll = AceGUI:Create("ScrollFrame")
	scroll:SetLayout("Flow")

	vdt_log("soft reserves",Softresit:getReserves())

	for k,v in pairs(Softresit:getReserves()) do
		if not tContains(itemIds, v.id) then
			tinsert(itemIds, v.id);

			local group = AceGUI:Create("SimpleGroup")
				-- local itemIcon = AceGUI:Create("Icon")
				-- itemIcon:SetImage(v.icon)
				-- itemIcon:SetImageSize(20,20)
				-- icon:SetColor(GetClassColor(strupper(v.class)));
				-- group:AddChild(itemIcon)

				local itemlabel = AceGUI:Create("InteractiveLabel")
				itemlabel:SetFullWidth(true);
				itemlabel:SetText(v.link);
				itemlabel:SetImage(v.icon);
				itemlabel:SetImageSize(16,16)
				itemlabel:SetCallback("OnEnter", function(widget, arg1, arg2)
					GameTooltip:SetOwner(widget.frame, "ANCHOR_TOPRIGHT")
					GameTooltip:SetHyperlink(v.link);
    				GameTooltip:Show();
				end)
				itemlabel:SetCallback("OnLeave", function(widget, arg1, arg2)
					GameTooltip:SetOwner(UIParent, "ANCHOR_TOPRIGHT")
					GameTooltip:Hide();
				end)
				group:AddChild(itemlabel)

				for k,v in pairs(Softresit:getReservesItem(v.id)) do
					local raider = AceGUI:Create("InteractiveLabel")

					raider:SetText(v.cName)
					raider:SetWidth(80)
					group:AddChild(raider)
				end
			scroll:AddChild(group)
		end
	end

	scrollcontainer:AddChild(scroll)
end

local function SelectTab(container, event, group)
   container:ReleaseChildren()
   if group == "csv" then
      Softresit:CSVFrame(container)
   elseif group == "raid" then
      Softresit:RaidFrame(container)
   elseif group == "softreserves" then
      Softresit:SoftReservesFrame(container)
   end
end

function Softresit:OpenFrame(current)
	if Softresit.opened == false then
		Softresit.opened = true
		local frame = AceGUI:Create("Window")
		frame:SetTitle("Softres.it")
		frame:SetStatusText("")
		frame:SetCallback("OnClose", function(widget)
			AceGUI:Release(widget)
			Softresit.opened = false
		end)
		frame:SetLayout("Fill")

		local tab = AceGUI:Create("TabGroup")
		tab:SetLayout("Flow")
		tab:SetTabs({{text="CSV", value="csv"}, {text="Raid Overview", value="raid"}, {text="Soft-reserves", value="softreserves"}})
		tab:SetCallback("OnGroupSelected", SelectTab)
		tab:SelectTab(current)
		frame:AddChild(tab)

		Softresit.frameIndex = Softresit.frameIndex + 1
		tinsert(Softresit.frames, frame)
	end
end

function Softresit:OnTooltipSetItem(tooltip)
	if tooltip:GetItem() ~= nil then
		local _, itemlink = tooltip:GetItem();
		if itemlink ~= nil then
			local id = Softresit:getIdFromLink(itemlink)
			local reservers = Softresit:getReservesItem(id)

			if #(reservers) > 0 then
				local t = {}
				for k,v in pairs(reservers) do
					tinsert(t, v.cName)
				end

				tooltip:AddLine("Softreservers: " .. table.concat(t, ", "), 1, 1, 1, true)
			end
		end
	end
end

function Softresit:OnTooltipSetUnit(tooltip)
	if tooltip:GetUnit() ~= nil then
		local name, server = tooltip:GetUnit();

		if UnitIsPlayer(name) and IsInRaid(name) and (InCombatLockdown() == false) then
			local items = Softresit:getReservesName(name)

			if #(items) > 0 then
				tooltip:AddLine("Soft-reserves", 1, 1, 1, true)

				for k,v in pairs(items) do
					tooltip:AddLine(v.link, 1, 1, 1, true);
				end
			end
		end
	end
end

function Softresit:OnCommReceived(...)
	vdt_log("received stray addon message",{...})
end

function Softresit:Comm_Request(prefix,msg,channel,source)
	if self.debug or UnitInParty(source) or UnitInRaid(source) then
		self:SendCommMessage("SRITCSV", self.db.factionrealm.csv, "WHISPER", source, "BULK")
		vdt_log("recv csv request from ".. source .. " over " .. channel, {msg = msg, reserves = self:parseCSV(msg)})
	end
end

function Softresit:Comm_CSV(prefix,msg,channel,source)
	if self:UnitIsValidSource(source) then
		self.db.factionrealm.csv = msg
		self.db.factionrealm.csvSource = string.format("%s | %s",
			source,
			date("%m/%d/%y %H:%M:%S")
		)
		self:UpdateCsvSourceText()
		vdt_log("received csv from "..source.." over "..channel,{msg = msg, reserves = self:parseCSV(msg)})
	end
end

function Softresit:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("SRIDB", defaults)
	Softresit:InitMinimapIcon()
	Softresit:HookScript(GameTooltip, "OnTooltipSetItem")
	Softresit:HookScript(GameTooltip, "OnTooltipSetUnit")
	Softresit:RegisterEvent("LOOT_OPENED")
	Softresit:RegisterEvent("START_LOOT_ROLL")
	self:RegisterComm("SRITREQ","Comm_Request")
	self:RegisterComm("SRITCSV","Comm_CSV")

	local testItems = {19387,19398,19406,19363,16950,19360,19381,19002}
	Softresit.db.factionrealm.itemQueue = {}
	for _,v in pairs(testItems) do Softresit.db.factionrealm.itemQueue[v] = 1 end

	self:LootWindow()
end


local dbListeners = {}

function Softresit:OnDB(widget,field,func)
	if not dbListeners[field] then dbListeners[field] = {} end
	dbListeners[field][widget] = func
	-- if setcallback overwrites previous, will require a rewrite
	vdt_log("dbListeners",dbListeners)
	widget:SetCallback("OnRelease",function() dbListeners[field][widget] = nil end)
end

function Softresit:SetDB(field,value)
	self.db.factionrealm[field] = value
	if dbListeners[field] then
		for _,func in pairs(dbListeners[field]) do
			if func then
				func(value)
			end
		end
	end
end