Softresit = LibStub("AceAddon-3.0"):NewAddon("Softresit", "AceEvent-3.0")

local defaults = {
	factionrealm = {
		minimapButton = { 
			hide = false 
		},
		softreserves = ""
	}
}

softreserves = {}

function Softresit:InitMinimapIcon()
	LibStub("LibDBIcon-1.0"):Register("Softresit", LibStub("LibDataBroker-1.1"):NewDataObject("Softresit",
		{
			type = "data source",
			text = "Softres.it",
			icon = "Interface\\Icons\\Inv_misc_bag_10_black",
			OnClick = function(self, button)
				if (button == "LeftButton") then
					Softresit:Open()
				end
			end,
			OnTooltipShow = function(tooltip)
				tooltip:AddLine("Softresit");
				tooltip:AddLine("|cFFCFCFCFLeft Click: |rOpen");
			end
		}), self.db.factionrealm.minimapButton);
end

function Softresit:parseCSV (info, payload)
	self.db.factionrealm.softreserves = payload

	local csv = {select(1,strsplit("\n",payload))}
	local fmtMap = {}
	for k,v in pairs({strsplit(",",csv[1])}) do fmtMap[v] = k end

	for k,v in pairs(csv) do
	    -- replace commas between quotation marks before splitting, may need to replace back
	    local commaStrip = v:gsub('"([^,]*,[^,]*)"',function(s) return  s:gsub(",","#") end)
	    local columns = {strsplit(",",commaStrip)}
	    
	    local itemId = tonumber(columns[fmtMap.ItemId])
	    
	    if itemId then        
	        local name = columns[fmtMap.Name]
	        local class = columns[fmtMap.Class]
	        local note = columns[fmtMap.Note]
	        itemId = tonumber(itemId)
	        tinsert(softreserves,{name=name,class=class,note=note})
	    end
	end
end

function Softresit:reset()
	self.db.factionrealm.softreserves = ""
	softreserves = {}
end

function Softresit:display () 
	return ""
end

function Softresit:InitOptions()
	local options = { 
		name = "Softres.it",
		type = "group",
		handler = Softresit,
		childGroups ="tab",
		args = {
			raid ={
				order = 20,
				type ="group",
				name = "Soft-reserves",
				desc = "List",			
				args = {
					_wipe = {
						order = 20,
						type = "execute",
						name = "Clear",
						func = "reset",
						desc = "Clears the list",
						width = "full",
					},
					list = {
						order = 30,
						type = "input",
						width = "full",
						name = "Softres.it CSV:",
						desc = "Copied from softres.it",
						multiline = 8,
						set = "parseCSV",
 						get = function(info) return self.db.factionrealm.softreserves end
					},
					drafted = {	
						order = 35,
						type = "input",
						disabled = true,
						name = "Soft-reservers:",
						desc = "Soft-reservers",
						get = "display",
						width = "full",
						multiline = 8,
					}
				},
			},				
		},
	}

	self.options = options

	LibStub("AceConfig-3.0"):RegisterOptionsTable("Softresit", options)
end

function Softresit:Open()
	LibStub("AceConfigDialog-3.0"):Open("Softresit")
end

function Softresit:OnInitialize() 
	self.db = LibStub("AceDB-3.0"):New("SRIDB", defaults)
	Softresit:InitMinimapIcon()
	Softresit:InitOptions()
end
