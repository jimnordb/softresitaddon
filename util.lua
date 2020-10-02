function Softresit:getIdFromLink(link)
	local _, _, _, _, id = string.find(link, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+)")

	return tonumber(id)
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

		        if debugEnabled then
		        	print("loaded soft-reserve:" .. cName .. " with item " .. link)
		        end

		        tinsert(softReserves,{name=name, cName=cName, from=from, class=class, note=note, id=itemId, link=link, icon=icon})
		    end
	    end
	end

	return softReserves
end

-- yoinked straight from WeakAuras
local IterateGroupMembers = function(reversed, forceParty)
	local unit = (not forceParty and IsInRaid()) and 'raid' or 'party'
	local numGroupMembers = unit == 'party' and GetNumSubgroupMembers() or GetNumGroupMembers()
	local i = reversed and numGroupMembers or (unit == 'party' and 0 or 1)
	return function()
	  	local ret
	  	if i == 0 and unit == 'party' then
			ret = 'player'
	  	elseif i <= numGroupMembers and i > 0 then
			ret = unit .. i
	  	end
	  	i = i + (reversed and -1 or 1)
	  	return ret
	end
end

function Softresit:GetGroupLeader() 
	for unit in IterateGroupMembers() do 
		if UnitIsGroupLeader(unit) then return UnitName(unit) end
	end
	return nil
end

function Softresit:GetMasterLooter() 
	if IsInGroup() then 
		local method,partyid,raidid = GetLootMethod()
		if method ~= "master" then 
			return nil 
		elseif IsInRaid() then 
			return UnitName("raid"..raidid)
		elseif partyid ~= 0 then
			return UnitName("party"..partyid)
		else
			return UnitName("player")
		end
	else
		return nil
	end	
end

function Softresit:UnitIsMasterLooter(player)
	return player and self.GetMasterLooter() == UnitName(player)
end

function Softresit:UnitIsValidSource(player) 
	-- TODO integrate option to accept all/temporarily accept all or something
	return self.debug or UnitIsGroupLeader(player) or self.UnitIsMasterLooter(player)
end

function Softresit:AddonChannel()
	if IsInRaid() then return "RAID"
	elseif IsInGroup() then return "PARTY" 
	end
end


