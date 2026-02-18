local dataService = game:GetService("DataStoreService")
local DS = dataService:GetDataStore("PlayerData14")
local freshData = require(game.ServerScriptService.FreshData)
local numsToStrings = require(game.ServerScriptService.NumbersToStrings)

local newData = table.clone(freshData.FileData)
local saveFileData = table.clone(freshData.SaveFile)





local dataModule = {
	
}

function dataModule.saveData(userIDWITHFILENUMBER, newSaveFileData, loggedBattleClone) --this is saving infile data, like level, experience, etc
	local theirData = DS:GetAsync(userIDWITHFILENUMBER) --get player save file data, targets exact save file when the function is called.
	if theirData then
		DS:UpdateAsync(userIDWITHFILENUMBER,function()
			if newSaveFileData.Ver.Value == theirData.Ver then
				newSaveFileData.Ver.Value += 1 --increment save file version
				local prototypeData = table.clone(freshData.SaveFile)
				for i, v in ipairs(newSaveFileData:GetChildren()) do
					if v:IsA("NumberValue") and v.Name ~= "FILENUMBER" then --filenumber value is only used for certain thing
						prototypeData[v.Name] = v.Value  --update values like Level, EXP, currentHP, etc.
					elseif v:IsA("Folder") then
						for index, skill in ipairs(v:GetChildren()) do
							prototypeData[v.Name][skill.Name] = skill.Value --inserts skill name into active or passive save file table in datastore.
							--or, inserts soullTree upgrades, in which both the name and the number are important. the number = the tier of upgrade it's at.
							--OR, inserts skillpoints, in which the numbers are important so the game remembers where you put your stats when level up.
							--OR, puts whatever mobs you mark in your Bestiary. the number doesn't matter here either, unless you want to put number defeated.
							--ORR, records what level of progression you are with all NPCs. this saves things like sidequests, puzzles completed, etc.
							--handles every folder of save data lol
						end
					end
				end
				if loggedBattleClone ~= {} and loggedBattleClone ~= nil and prototypeData.InCombat == 1 then
					prototypeData.LoggedBattle = table.clone(loggedBattleClone)
					prototypeData.currentHP -= math.round(prototypeData.currentHP*0.1) --you deserve to lose SOME hp
					if prototypeData.currentHP <= 0 then
						prototypeData.currentHP = 0.1 --i dont wanna kill anyone off from this
					end
				end
				print("Success save")
				return prototypeData
			else
				warn("Versions didn't match, not saving data. (saveData)")
				return nil
			end
		end)
	else
		warn("No data was found for this player. (saveData)")
		return nil
	end
end

function dataModule.saveFILEDATA(userID, newFilesData) --THIS is saving which files you have bought with robux.
	local theirData = DS:GetAsync(userID) --get player save file data
	if theirData then
		DS:UpdateAsync(userID,function()
			if newFilesData.Ver.Value == theirData.Ver then
				newFilesData.Ver.Value += 1 --increment save file version
				local protoTypeData = table.clone(freshData.FileData)
				for i, v in ipairs(newFilesData:GetChildren()) do
					if v:IsA("NumberValue") then
						protoTypeData[v.Name] = v.Value  --update Files values. 
					elseif v:IsA("Folder") then
						for index, soulUpgrade in ipairs(v:GetChildren()) do
							protoTypeData[v.Name][soulUpgrade.Name] = soulUpgrade.Value --stores each soul tree upgrade u have along with its level
						end
					end
				end
				
				print("Success save")
				return protoTypeData
			else
				warn("Versions didn't match, not saving data, returning old data. (saveFILEDATA)")
				return theirData
			end
		end)
	else
		warn("No data was found for this player. (saveFILEDATA)")
		return nil
	end
	
end



function dataModule.fileIndexing(client, fileNumber) --counts the number of savefiles you own, and displays information of the file depending on which one you're looking at
	local userID = client.UserId
	local playersDS = DS:GetAsync(userID.."File"..fileNumber)
	if not playersDS then
		playersDS = saveFileData
	end
	client.PlayerGui.JoinedGame.Frame.PlayOrBuy.Text = "Play"
	local temp = DS:GetAsync(client.UserId)
	local temp2 = 0
	for i, v in pairs(temp) do
		temp2 += 1
	end
	client.PlayerGui.JoinedGame.Frame.FileNumber.Text = "File " .. fileNumber .. "/" .. temp2-3 --file 1 out of x files
	client.PlayerGui.JoinedGame.Frame.Information.Text = "Level: " .. playersDS.Level .. "\nRace: " .. numsToStrings.Races[playersDS.Race] .. "\nGold: " .. playersDS.Gold .. "\nBase Class: " .. numsToStrings.BaseClasses[playersDS.BaseClass] .. "\nSuper Class: " .. numsToStrings.SuperClasses[playersDS.SuperClass]
	
	
end



return dataModule
