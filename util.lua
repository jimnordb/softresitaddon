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