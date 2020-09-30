Softresit = LibStub("AceAddon-3.0"):NewAddon("Softresit", "AceEvent-3.0")
local AceGUI = LibStub("AceGUI-3.0")

local defaults = {
	factionrealm = {
		minimapButton = { 
			hide = false 
		},
		csv = ""
	}
}

local opened = false
frameIndex = 0
frames = {}
local raidFrameTooltip;

softReserves = {}
raidRoster = {}

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

function Softresit:parseCSV(payload)
	local softReserves = {}
	local csv = {select(1,strsplit("\n",payload))}
	local fmtMap = {}

	for k,v in pairs({strsplit(",",csv[1])}) do fmtMap[v] = k end
	for k,v in pairs(csv) do
	    -- replace commas between quotation marks before splitting, may need to replace back
	    local commaStrip = v:gsub('"([^,]*,[^,]*)"',function(s) return  s:gsub(",","#") end)
	    local columns = {strsplit(",",commaStrip)}
	    
	    local itemId = tonumber(columns[fmtMap.ItemId])

	    if itemId then
	    	local _, link = GetItemInfo(itemId)
	    	if link then 
	    		local icon = GetItemIcon(itemId)
		        local name = columns[fmtMap.Name]
		        local class = columns[fmtMap.Class]
		        local note = columns[fmtMap.Note]
		        local from = columns[fmtMap.From]

		        local color = select(4, GetClassColor(strupper(class)))
		        local cName = name

		        if color then
		        	cName = "|c" .. strupper(color) .. name .. "|r"
		        end

		        tinsert(softReserves,{name=name, cName=cName, from=from, class=class, note=note, id=itemId, link=link, icon=icon})
		    end
	    end
	end

	return softReserves
end

function Softresit:GetRaiders() 
	local raid = {}

	 for i = 1, 40 do
        local name, _, _ = GetRaidRosterInfo(i)
        if name then
            tinsert(raid, name)
        end
    end

    return raid
end

function Softresit:getReservesItem(id, T)
	local reservers = {}

	for k,v in pairs(T) do
		if v.id == id then
			tinsert(reservers, v)
		end
	end

	return reservers
end

function Softresit:initRaidTooltip() 
	raidFrameTooltip = CreateFrame( "GameTooltip", "RaidOverviewFrameTooltip", nil, "GameTooltipTemplate" ); -- Tooltip name cannot be nil
	raidFrameTooltip:SetOwner( UIParent, "ANCHOR_NONE" );
end

function Softresit:OpenOptions()

end

function Softresit:CSVFrame(container)
	local editMode = false
	local changed = false
	local editButton = AceGUI:Create("Button")
	local csvEditBox = AceGUI:Create("MultiLineEditBox")
	local resetButton = AceGUI:Create("Button")
	
	editButton:SetCallback("OnClick", function()
		if editMode then
			if changed then
				self.db.factionrealm.csv = csvEditBox:GetText()

				Softresit:loadReserves()

		    	editMode = false
		    	editButton:SetText("Edit CSV")
				csvEditBox:SetDisabled(true)
				resetButton:SetDisabled(false)
			else
				editMode = false
		    	editButton:SetText("Edit CSV")
				csvEditBox:SetDisabled(true)
			end
	    else 
	    	csvEditBox:SetDisabled(false)
	    	csvEditBox:SetFocus()
			editButton:SetText("Cancel")
	    	editMode = true
	    	changed = false
		end
	end)
	editButton:SetText("Edit CSV")
	editButton:SetRelativeWidth(0.5)

	csvEditBox:SetFullWidth(true)
	csvEditBox:SetNumLines(15)
	csvEditBox:SetLabel("Softres.it CSV")
	csvEditBox:SetCallback("OnTextChanged", function(widget, arg1, text)
		changed = true
		editButton:SetDisabled(false)
		editButton:SetText("Save")

		if strlen(text) > 0 then
			resetButton:SetDisabled(false)
		else
			resetButton:SetDisabled(true)
		end
	end)

	if strlen(self.db.factionrealm.csv) > 0 then
		csvEditBox:SetDisabled(true)
	else
		editMode = true
		csvEditBox:SetFocus()
		editButton:SetDisabled(true)
		resetButton:SetDisabled(true)
	end

	csvEditBox:SetText(self.db.factionrealm.csv)
	csvEditBox:DisableButton(true)
	container:AddChild(csvEditBox)
	container:AddChild(editButton)

	resetButton:SetCallback("OnClick", function()
		csvEditBox:SetText("")
		self.db.factionrealm.csv = ""
		softReserves = {}
		resetButton:SetDisabled(true)
		editButton:SetDisabled(true)
		editMode = true
    	changed = false
		csvEditBox:SetDisabled(false)
		csvEditBox:SetFocus()
	end)
	resetButton:SetText("Reset CSV")
	resetButton:SetRelativeWidth(0.5)
	container:AddChild(resetButton)
end

function Softresit:RaidFrame(container)
	local itemIds = {}
	local scrollcontainer = AceGUI:Create("SimpleGroup")
	scrollcontainer:SetFullWidth(true)
	scrollcontainer:SetFullHeight(true)
	scrollcontainer:SetLayout("Fill")
	container:AddChild(scrollcontainer)

	local scroll = AceGUI:Create("ScrollFrame")
	scroll:SetLayout("Flow")

	for k,v in pairs(softReserves) do
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

				for k,v in pairs(Softresit:getReservesItem(v.id, softReserves)) do
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
   end
end

function Softresit:OpenFrame(current)
	if opened == false then 
		opened = true
		local frame = AceGUI:Create("Window")
		frame:SetTitle("Softres.it")
		frame:SetStatusText("")
		frame:SetCallback("OnClose", function(widget) 
			AceGUI:Release(widget)
			opened = false
		end)
		frame:SetLayout("Fill")

		local tab = AceGUI:Create("TabGroup")
		tab:SetLayout("Flow")
		tab:SetTabs({{text="CSV", value="csv"}, {text="Raid Overview", value="raid"}})
		tab:SetCallback("OnGroupSelected", SelectTab)
		tab:SelectTab(current)
		frame:AddChild(tab)

		frameIndex = frameIndex + 1
		tinsert(frames, frame)
	end
end

function Softresit:loadReserves()
	softReserves = Softresit:parseCSV(self.db.factionrealm.csv)
end

function Softresit:OnInitialize() 
	self.db = LibStub("AceDB-3.0"):New("SRIDB", defaults)
	Softresit:InitMinimapIcon()
	Softresit:loadReserves()
end
