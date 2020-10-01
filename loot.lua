-- loot window event
function Softresit:LOOT_OPENED()
	for i = 1, GetNumLootItems() do
		Softresit:NotifyLoot(GetLootSlotLink(i))
	end
end

-- handle group loot event
function Softresit:START_LOOT_ROLL(_, rollId)
	Softresit:NotifyLoot(GetLootRollItemLink(rollId))
end

function Softresit:NotifyLoot(link)
	if link ~= nil then
		local itemId = Softresit:getIdFromLink(link)

		if debugEnabled then print(itemId) end

		local reservers = Softresit:getReservesItem(itemId)

		if #(reservers) > 0 then
			for k,v in pairs(reservers) do
				print(v.cName .. ":" .. v.link)
			end
		end
	end
end