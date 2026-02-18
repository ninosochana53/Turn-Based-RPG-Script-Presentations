local player = script.Parent.Parent.Parent
if player:IsA("Player") then 
	
	local data = workspace.PlayerDatas:WaitForChild(player.Name).SaveData --get a player's save data
	player.Character:WaitForChild("Stats")
	local inventoryframe = script.Parent.InventoryFrame
	local inventory = data.Inventory
	local itemList = inventory:GetChildren() --sort items in inventory alphabetically
	local db = script.Debounce --we want it as a var that can be accessed globally so that items can set the value to true when being used. we dont want you to be able to switch items while drinking a potion, for example.
	local selectedItem = nil --holder for buttonclones you click, effectively selecting an item in ur inventory
	local statFrame = script.Parent.StatFrame
	local skillsFrame = script.Parent.SkillsFrame
	local constr = inventoryframe.UIAspectRatioConstraint
	--local constrTWO = skillsFrame.UIAspectRatioConstraint
	local calcModule = require(game.ServerScriptService.CalcFuncs)
	local numsToStrings = require(game.ServerScriptService.NumbersToStrings)
	local assetModule = require(game.ReplicatedStorage.AssetsModule)
	local activeModule = require(game.ServerScriptService.ActiveInformation)
	local passiveModule = require(game.ServerScriptService.PassiveAbilities)
	local itemsModule = require(game.ReplicatedStorage.ItemData)
	local scrollsModule = require(game.ServerScriptService.Scrolls)
	local gearsModule = require(game.ServerScriptService.Gears)
	local TS = game:GetService("TweenService")
	local TInfoAbility = TweenInfo.new(0.7,Enum.EasingStyle.Sine,Enum.EasingDirection.Out,0,false,0)
	local abilityTab = "Actives" --actives or passives
	local selectedAbility = nil --holder for any active/passive abilitiy you have selected while viewing your skills, to display information about them
	
	local returnedCalculatedStats = nil --{finalATK, finalMAG, finalSPEED, finalLCK, finalCritChance, finalCritDmg, finalIncoming, finalOutgoing, maxItemUses, maxEnergy, finalHP}
	function updateStats()
		--present an updated stat distribution to the player after all necessary calcs
		returnedCalculatedStats = calcModule.calculateStats(player) --sets correct stats to each player, regarding ALL equipment, passives, soul tree, gears, anything.
		--display the amount of points you have invested per stat (you get 5 points for level up), then present in parenthesis your TOTAL for that stat based on equipments & skill tree upgrades that enhance your stats
		statFrame.LCK.Text = "LCK: " .. data.SkillPoints.LCK.Value .. "(" .. returnedCalculatedStats[4] .. ")" 
		statFrame.SPEED.Text = "SPD: " .. data.SkillPoints.SPEED.Value .. "(" .. returnedCalculatedStats[3] .. ")"
		statFrame.STR.Text = "ATK: " .. data.SkillPoints.ATK.Value .. "(" .. returnedCalculatedStats[1] .. ")"
		statFrame.MAG.Text = "MAG: " .. data.SkillPoints.MAG.Value .. "(" .. returnedCalculatedStats[2] .. ")"
		statFrame.HP.Text = "HP: " .. data.SkillPoints.HP.Value .. "(" .. returnedCalculatedStats[11] .. ")"
		
		--display your equipments
		statFrame.Armor.Text = "Armor: " .. numsToStrings.Armors[data.Armor.Value]
		statFrame.Artifact.Text = "Artifact: " .. numsToStrings.Artifacts[data.Artifact.Value]
		statFrame.Gear1.Text = gearsModule[data.Gear1.Value].Name
		statFrame.Gear2.Text = gearsModule[data.Gear2.Value].Name
		statFrame.Gear3.Text = gearsModule[data.Gear3.Value].Name
		statFrame.Gear4.Text = gearsModule[data.Gear4.Value].Name
		statFrame.Enchant.Text = "Enchant: " .. numsToStrings.Enchants[data.Enchant.Value]

		--display your classes
		statFrame.BaseClass.Text = "Base Class: " .. numsToStrings.BaseClasses[data.BaseClass.Value]
		statFrame.SubClass.Text = "Sub Class: " .. numsToStrings.SubClasses[data.SubClass.Value]
		statFrame.SuperClass.Text = "Super Class: " .. numsToStrings.SuperClasses[data.SuperClass.Value]

		--display other stuff
		statFrame.Weapon.Text = "Weapon: " .. numsToStrings.Weapons[data.Weapon.Value]
		statFrame.Race.Text = "Race: " .. numsToStrings.Races[data.Race.Value]
		--display miscellaneous stats
		statFrame.IncomingHealing.Text = "Incoming Healing: " .. (returnedCalculatedStats[7]/100) .. "x" --divide by 100 to present values clearly. ex: 100 = 1x healing, 150 would be translated and written to client as 1.5x healing, etc.
		statFrame.OutgoingHealing.Text = "Outgoing Healing: " .. (returnedCalculatedStats[8]/100) .. "x"
		statFrame.CritDamage.Text = "Crit Damage: " .. (returnedCalculatedStats[6]/100) .. "x"
		statFrame.CritChance.Text = "Crit Chance: " .. (returnedCalculatedStats[5]/10) .. "%"
		
		--display attack %'s so you know how much your ATK and MAG truly affect your damage output. 1 point of ATK/MAG upgrades the respective percentile by 2%. The starting value is 100% of course, so 50 points in ATK will show you 200% Attack %
		statFrame.PhysicalPercent.Text = "ATK Percent: " .. math.round(((returnedCalculatedStats[1]+50)/50) * 100) .. "%"
		statFrame.MagicPercent.Text = "MAG Percent: " .. math.round(((returnedCalculatedStats[2]+50)/50) * 100) .. "%"

		
		
	end

	function updateItems() --update your backpack UI
		db.Value = true
		updateStats() --do this first incase you just equipped something that modifies your stats.
		for i, v in ipairs(inventory:GetChildren()) do
			if not itemsModule[v.Name] then --if you somehow have an item that doesnt even exist, then remove it (EX: i removed an item from the game because it was too strong)
				print("ILLEGAL ITEM: " .. v.Name .. " DELETED") 
				v:Destroy()
			end
		end
		itemList = inventory:GetChildren() --get a table of your inventory
		table.sort(itemList, function(a,b) --sort alphabetically
			return a.Name < b.Name
		end)
		inventoryframe.CanvasSize = UDim2.new(0,0,0.5,0) --default size for any inventory with 20 items or less
		if #itemList > 20 then --make a scalable scrolling bar based on how many items you have
			local leftOvers = #itemList-20
			repeat
				leftOvers -= 4 --space for items is needed in multiples of 4. an inventory with 20 items only needs 0.5 canvas size. 21 = 0.6. 24 = 0.6 still. 25 = 0.7, as it starts the mark of a new inventory row, each row holds 4 items.
				inventoryframe.CanvasSize = inventoryframe.CanvasSize + UDim2.new(0,0,0.1,0) --add space for a new row of items for each time
			until
			leftOvers <= 0
		end

		local newButtons = {} --create buttons so that when you click a button in your inventory, your character will hold the item out, and the item will be usable if applicable
		constr.Parent = script --dont wanna clear constr
		inventoryframe:ClearAllChildren() --refresh inventory
		constr.Parent = inventoryframe
		for i, numbervalue in ipairs(itemList) do --loops thru ur inventory which is a folder containing number values.
			local buttonClone = script.PROTOTYPEBUTTON:Clone() --create new UI element, a text button
			buttonClone.Name = numbervalue.Name --name is equal to itemname
			buttonClone.Count.Text = "x" .. numbervalue.Value -- display how many you currently own
			buttonClone.Text = numbervalue.Name --text is equal to itemname
			buttonClone.Visible = true
			buttonClone.Parent = inventoryframe
			local xScale = 0.1
			local yScale = 0.025
			if i == 2 then
				xScale = 0.3
			elseif i == 3 then
				xScale = 0.5
			elseif i == 4 then
				xScale = 0.7
			else
				xScale = 0.1 + (((i-1)%4)*0.2)
				yScale = 0.025 + (0.2 * math.floor((i-1)/4))
			end
			buttonClone.Position = UDim2.new(xScale,0,yScale,0) --position correctly based on index
			local getItemData = itemsModule[numbervalue.Name] --get necessary item data such as item description & rarity
			local newColor = buttonClone.BackgroundColor3
			local newDesc = "..." --default
			if getItemData then
				newColor = getItemData.Color --get color based on rarity
				newDesc = getItemData.Description
			end
			buttonClone.BackgroundColor3 = newColor
			buttonClone.MouseEnter:Connect(function() --when your mouse enters the textbutton, display a descriptor of the item description, and color the button based on the item's rarity
				script.Parent.ITEMDESCRIPTIOR.Text = newDesc
				script.Parent.ITEMDESCRIPTIOR.BackgroundColor3 = newColor
				script.Parent.ITEMDESCRIPTIOR.Visible = true
			end)
			buttonClone.MouseLeave:Connect(function() --hide descriptor when your mouse leaves
				script.Parent.ITEMDESCRIPTIOR.Visible = false
			end)
			
			local function inventoryButtonClicked() --when you select an item in your inventory, do this function for it
				if db.Value == false then
					db.Value = true
					if selectedItem and selectedItem.Text == buttonClone.Text then --if you have selected something in your inventory and its this button, unequip it
						buttonClone.BorderSizePixel = 0
						if player.Character:FindFirstChildOfClass("Tool") then
							player.Character:FindFirstChildOfClass("Tool"):Destroy() --visual unequip
						end
						selectedItem = nil
					else --unequip something if you had something equipped, and set a new equipped (selectedItem) equal to this textbutton item
						if selectedItem then
							selectedItem.BorderSizePixel = 0
						end
						if player.Character:FindFirstChildOfClass("Tool") then --unequip something if u were holding it
							player.Character:FindFirstChildOfClass("Tool"):Destroy() --visual unequip
						end
						task.wait()
						selectedItem = buttonClone --update selected item
						buttonClone.BorderSizePixel = 2 --highlight border indicating you have equipped this item
						local itemTool = game.ServerStorage.ItemTools:FindFirstChild(buttonClone.Text) --get visual equip to be put onto your character model visually
						if itemTool then
							local newItem = itemTool:Clone()
							newItem.Parent = player.Character
							if newItem:FindFirstChild("ItemScript") then --if your item is usable in the overworld, enable it on click
								newItem.ItemScript.Enabled = true
							end
							newItem.Destroying:Once(function() --if the item is destroyed (you used it), unequip it
								buttonClone.BorderSizePixel = 0 --using it is the same as unequipping it.
								selectedItem = nil
							end)
						end
						--In essense:
						--parents the item to the player as a tool. find this tool in a holder for all in game items by findfirstchild via buttonclone.Text or name.
						--that's all that needs to be done. if the item can be used outside of combat for something, the tool will have a script that uses a function to do something when the player clicks.
					end
					task.wait(0.05)
					db.Value = false
				end
			end
			buttonClone.MouseButton1Click:Connect(inventoryButtonClicked)
			buttonClone.TouchTap:Connect(inventoryButtonClicked)
			
		end
		task.wait(0.1)
		db.Value = false
	end
	
	function updateSkills()
		--constrTWO.Parent = script
		skillsFrame:ClearAllChildren() --refresh skill list
		--constrTWO.Parent = skillsFrame
		inventoryframe.CanvasSize = UDim2.new(0,0,0.25,0)
		local newList = nil
		local newButton = nil
		selectedAbility = nil
		if abilityTab == "Actives" then
			for i, v in ipairs(data.Actives:GetChildren()) do
				if not activeModule[v.Name] then --if you have an ability that i removed from the game then delete it
					print("ILLEGAL ACTIVE: " .. v.Name .. " DELETED") 
					v:Destroy()
				end
			end
			newList = data.Actives:GetChildren()
		else
			for i, v in ipairs(data.Passives:GetChildren()) do
				if not passiveModule[v.Name] then
					print("ILLEGAL PASSIVE: " .. v.Name .. " DELETED") 
					v:Destroy()
				end
			end
			newList = data.Passives:GetChildren()
		end
		
		table.sort(newList, function(a,b) --sort 
			return a.Name < b.Name
		end)
		if #newList > 4 then --scale a scrollable UI canvas to hold your skills
			local leftOvers = #newList-4
			repeat
				leftOvers -= 1 --need 0.1 of scale space per active/passive button
				inventoryframe.CanvasSize = inventoryframe.CanvasSize + UDim2.new(0,0,0.1,0) --add space for a new row of items for each time
			until
			leftOvers <= 0
		end
		local newButtons = {}
		if abilityTab == "Actives" then --create new UI element depending on whether you are viewing your active or passive abilities
			newButton = script.ACTIVEPROTOTYPE
		else
			newButton = script.PASSIVEPROTOTYPE
		end
		
		
		for i, numbervalue in ipairs(newList) do --loops thru ur skills
			
			local buttonClone = newButton:Clone() --create new UI element
			buttonClone.Name = numbervalue.Name --give its name and text equal to the skill's name
			buttonClone.Button.Text = numbervalue.Name
			buttonClone.Visible = true
			if abilityTab == "Actives" then --if it's an active, also present the element of the attack, modifiy its color based on the element, and display the cooldown/energy cost
				buttonClone.AttackType.Image = assetModule.Type[activeModule[numbervalue.Name].Type].Image
				buttonClone.ImageColor3 = assetModule.Type[activeModule[numbervalue.Name].Type].Color
				buttonClone.Cooldown.Text = activeModule[numbervalue.Name].Cooldown
				buttonClone.EnergyCost.Text = activeModule[numbervalue.Name].EnergyCost
			end
			buttonClone.Parent = skillsFrame
			local xScale = 0.1
			local yScale = 0.05
			yScale = 0.025 + (0.2 * (i-1))
			buttonClone.Position = UDim2.new(xScale,0,yScale,0) --position the button based on index
			
			local function skillClicked() --if you click a skill, then it will show you the description
				if db.Value == false then
					db.Value = true
					local prevColor = buttonClone.ImageColor3 --store the color of an unselected button
					buttonClone.ImageColor3 = Color3.fromRGB(buttonClone.ImageColor3.R/2, buttonClone.ImageColor3.G/2, buttonClone.ImageColor3.B/2) --present darker color to indicate you have selected this ability for viewing
					game.ReplicatedStorage.PlayLocalSound:FireClient(player, 179235828, 0.33) 
					if selectedAbility == buttonClone.Name then --if you clicked the skill you already were viewing, unview and unselect
						selectedAbility = nil
						script.Parent.SkillsFrameBG.KnowledgeBG.Visible = false
					else --else update selectedAbility to the new one you want to view
						selectedAbility = buttonClone.Name
						if abilityTab == "Actives" then --find description of the ability if it's an active or passive
							script.Parent.SkillsFrameBG.KnowledgeBG.Button.Text = activeModule[buttonClone.Name].Description
						else
							script.Parent.SkillsFrameBG.KnowledgeBG.Button.Text = passiveModule[buttonClone.Name].Description
						end

						script.Parent.SkillsFrameBG.KnowledgeBG.Visible = true
					end

					if numsToStrings.Scrolls["Scroll of " .. buttonClone.Name] or numsToStrings.Scrypts[data.LostScrypt.Value] == "Lost Scrypt of " .. buttonClone.Name then
						script.Parent.SkillsFrameBG.KnowledgeBG.Unequip.Visible = true
						--if this ability comes from a scroll or Lost Scrypt, then you can unequip it, because you only have 5 slots for these, so you don't want to be stuck with one after equipping one.
					else
						--you cannot unequip naturally learned skills from base classes/innate race abilities/etc.
						script.Parent.SkillsFrameBG.KnowledgeBG.Unequip.Visible = false
					end
					task.wait(0.05)
					buttonClone.ImageColor3 = prevColor
					db.Value = false
				end
			end
			buttonClone.Button.MouseButton1Click:Connect(skillClicked)
			buttonClone.Button.TouchTap:Connect(skillClicked)
			
			
			
		end
	end
	inventory.ChildAdded:Connect(function(c) --when something is parented to your inventory, it's gonna be an item obviously. so tie this function to it.
		
		c:GetPropertyChangedSignal("Value"):Connect(function() --when the amount of this item you have is changed, do this:
			if c.Value <= 0 then
				c:Destroy() --if u have no more of this item, delete it from ur inventory
				--dont need to use updateItems() here because upon destroying it, line 296 is fired.
			else
				updateItems() --now update the list
			end
		end)
		updateItems() --now update the list

	end)
	inventory.ChildRemoved:Connect(updateItems)


	script.Parent.SkillsFrameBG.KnowledgeBG.Unequip.Button.MouseButton1Down:Connect(function() --if you're clicking unequip, fire lambda function
		if db.Value == false then
			db.Value = true
			if numsToStrings.Scrolls["Scroll of " .. selectedAbility] then --if you're unequipping a valid scroll then
				script.Parent.SkillsFrameBG.KnowledgeBG.Unequip.Button.MouseButton1Down:Once(function()
					script.Parent.SkillsFrameBG.KnowledgeBG.Visible = false --hide description
					game.ReplicatedStorage.PlayLocalSound:FireClient(player, 179235828, 0.33)
					
					--add a scroll to your inventory since you unequipped it
					if inventory:FindFirstChild("Scroll of " .. selectedAbility) then
						inventory:FindFirstChild("Scroll of " .. selectedAbility).Value += 1
					else
						local insta = Instance.new("NumberValue")
						insta.Value = 1
						insta.Name = "Scroll of " .. selectedAbility
						insta.Parent = inventory
					end
					data.Scrolls:FindFirstChild("Scroll of " .. selectedAbility):Destroy() --delete it from your scrolls data, freeing up space for you to equip a different one
					data.Actives:FindFirstChild(selectedAbility):Destroy() --unlearn active ability that came from the scroll
					game.ReplicatedStorage.InventoryAdd:FireClient(player, "+Scroll of " .. selectedAbility) --only a visual add to your inventory
				end)
			elseif numsToStrings.Scrypts[data.LostScrypt.Value] == "Lost Scrypt of " .. selectedAbility then --same functionality as scroll above
				script.Parent.SkillsFrameBG.KnowledgeBG.Unequip.Button.MouseButton1Down:Once(function()
					script.Parent.SkillsFrameBG.KnowledgeBG.Visible = false --hide knowledge
					game.ReplicatedStorage.PlayLocalSound:FireClient(player, 179235828, 0.33)
					--add a scrypt to your inventory
					if inventory:FindFirstChild("Lost Scrypt of " .. selectedAbility) then
						inventory:FindFirstChild("Lost Scrypt of " .. selectedAbility).Value += 1
					else
						local insta = Instance.new("NumberValue")
						insta.Value = 1
						insta.Name = "Lost Scrypt of " .. selectedAbility
						insta.Parent = inventory
					end
					data.LostScrypt.Value = 0 --none equipped now
					data.Actives:FindFirstChild(selectedAbility):Destroy() --unlearn scrypt
					game.ReplicatedStorage.InventoryAdd:FireClient(player, "+Lost Scrypt of " .. selectedAbility) --only a visual add
				end)
			end
			
			task.wait(0.2)
			db.Value = false
		end
		
	end)

	function toggleBackpack()--toggle UI of your inventory
		if db.Value == false then
			db.Value = true
			game.ReplicatedStorage.PlayLocalSound:FireClient(player, 3834495137, 1)
			if inventoryframe.Visible == false then --if you dont have your inventory open then open it & your stat screen
				updateItems()
				inventoryframe.Visible = true
				statFrame.Visible = true
				skillsFrame.Visible = false
				script.Parent.SkillsFrameBG.Visible = false
			else --else hide them
				inventoryframe.Visible = false
				statFrame.Visible = false
				skillsFrame.Visible = false
				script.Parent.SkillsFrameBG.Visible = false
			end
			task.wait(0.05)
			db.Value = false
		end
	end
	script.Parent.BackpackButton.MouseButton1Down:Connect(toggleBackpack)
	script.Parent.BackpackButton.TextButton.MouseButton1Down:Connect(toggleBackpack)

	script.KeyBPressed.OnServerEvent:Connect(function(client) --same as toggleBackpack(), but adds checks to make sure the client who pressed B matches the player parent of this script
		if client and client.Name == player.Name and script.Parent.Enabled == true and db.Value == false then --extra safety checks i guess
			db.Value = true
			game.ReplicatedStorage.PlayLocalSound:FireClient(player, 3834495137, 1)
			if inventoryframe.Visible == false then
				updateItems()
				inventoryframe.Visible = true
				statFrame.Visible = true
				skillsFrame.Visible = false
				script.Parent.SkillsFrameBG.Visible = false
			else
				inventoryframe.Visible = false
				statFrame.Visible = false
				skillsFrame.Visible = false
				script.Parent.SkillsFrameBG.Visible = false
			end
			task.wait(0.05)
			db.Value = false
		end
	end)
	
	statFrame.ViewSkills.Button.MouseButton1Down:Connect(function() --when you want to view your skills, present a clean slate of it & hide other UIs
		if db.Value == false then
			db.Value = true
			game.ReplicatedStorage.PlayLocalSound:FireClient(player, 179235828, 0.33)
			updateSkills()
			script.Parent.SkillsFrameBG.KnowledgeBG.Visible = false
			inventoryframe.Visible = false
			statFrame.Visible = false
			skillsFrame.Visible = true
			script.Parent.SkillsFrameBG.Visible = true
			task.wait(0.05)
			db.Value = false
		end
	end)
	
	for i, v in ipairs(data.SkillPoints:GetChildren()) do --anytime any of these stats are changed, call updateStats
		v:GetPropertyChangedSignal("Value"):Connect(updateStats)
	end
	--anytime any of these stats are changed, call updateStats
	data.Armor:GetPropertyChangedSignal("Value"):Connect(updateStats)
	data.Artifact:GetPropertyChangedSignal("Value"):Connect(updateStats)
	data.BaseClass:GetPropertyChangedSignal("Value"):Connect(updateStats)
	data.Enchant:GetPropertyChangedSignal("Value"):Connect(updateStats)
	data.Gear1:GetPropertyChangedSignal("Value"):Connect(updateStats)
	data.Gear2:GetPropertyChangedSignal("Value"):Connect(updateStats)
	data.Gear3:GetPropertyChangedSignal("Value"):Connect(updateStats)
	data.Gear4:GetPropertyChangedSignal("Value"):Connect(updateStats)
	data.Race:GetPropertyChangedSignal("Value"):Connect(updateStats)
	data.SuperClass:GetPropertyChangedSignal("Value"):Connect(updateStats)
	data.SubClass:GetPropertyChangedSignal("Value"):Connect(updateStats)
	data.Weapon:GetPropertyChangedSignal("Value"):Connect(updateStats)
	--when an ability is added/forgotten, call updateSkills
	data.Actives.ChildAdded:Connect(updateSkills)
	data.Actives.ChildRemoved:Connect(updateSkills)
	data.Passives.ChildAdded:Connect(updateSkills)
	data.Passives.ChildRemoved:Connect(updateSkills)
	
	--for each gear, connect a function
	statFrame.Gear1Unequip.Button.MouseButton1Down:Connect(function()
		if data.Gear1.Value ~= 0 then --if you have a gear with a valid ID equipped
			
			local gearName = gearsModule[data.Gear1.Value].Name --read equipped gear's name based on ID
			data.Gear1.Value = 0 --set your gear equip to nothing since you are unequipping
			game.ReplicatedStorage.PlayLocalSound:FireClient(player, 179235828, 0.33)
			--give back to your inventory since you unequipped
			if inventory:FindFirstChild(gearName) then 
				inventory:FindFirstChild(gearName).Value += 1
			else
				local newItem = Instance.new("NumberValue")
				newItem.Value = 1
				newItem.Name = gearName
				newItem.Parent = inventory --this is the true inventory add, handled ON SERVER
			end
			game.ReplicatedStorage.InventoryAdd:FireClient(player, "+"..gearName) --visual add for the client
		end
	end)
	
	statFrame.Gear2Unequip.Button.MouseButton1Down:Connect(function()--see lines 427-444
		if data.Gear2.Value ~= 0 then
			local gearName = gearsModule[data.Gear2.Value].Name
			data.Gear2.Value = 0
			game.ReplicatedStorage.PlayLocalSound:FireClient(player, 179235828, 0.33)
			if inventory:FindFirstChild(gearName) then
				inventory:FindFirstChild(gearName).Value += 1
			else
				local newItem = Instance.new("NumberValue")
				newItem.Value = 1
				newItem.Name = gearName
				newItem.Parent = inventory --this is the true inventory add, handled ON SERVER
			end
			game.ReplicatedStorage.InventoryAdd:FireClient(player, "+"..gearName) --only a visual add
		end
	end)
	
	statFrame.Gear3Unequip.Button.MouseButton1Down:Connect(function()--see lines 427-444
		if data.Gear3.Value ~= 0 then
			local gearName = gearsModule[data.Gear3.Value].Name
			data.Gear3.Value = 0
			game.ReplicatedStorage.PlayLocalSound:FireClient(player, 179235828, 0.33)
			if inventory:FindFirstChild(gearName) then
				inventory:FindFirstChild(gearName).Value += 1
			else
				local newItem = Instance.new("NumberValue")
				newItem.Value = 1
				newItem.Name = gearName
				newItem.Parent = inventory --this is the true inventory add, handled ON SERVER
			end
			game.ReplicatedStorage.InventoryAdd:FireClient(player, "+"..gearName) --only a visual add
		end
	end)
	
	statFrame.Gear4Unequip.Button.MouseButton1Down:Connect(function()--see lines 427-444
		if data.Gear4.Value ~= 0 then
			local gearName = gearsModule[data.Gear4.Value].Name
			data.Gear4.Value = 0
			game.ReplicatedStorage.PlayLocalSound:FireClient(player, 179235828, 0.33)
			if inventory:FindFirstChild(gearName) then
				inventory:FindFirstChild(gearName).Value += 1
			else
				local newItem = Instance.new("NumberValue")
				newItem.Value = 1
				newItem.Name = gearName
				newItem.Parent = inventory --this is the true inventory add, handled ON SERVER
			end
			game.ReplicatedStorage.InventoryAdd:FireClient(player, "+"..gearName) --only a visual add
		end
	end)
	
	statFrame.WeaponUnequip.Button.MouseButton1Down:Connect(function()--see lines 427-444, but for equipped weapon instead of equipped gears
		if data.Weapon.Value ~= 0 then
			local weaponName = numsToStrings.Weapons[data.Weapon.Value]
			data.Weapon.Value = 0
			game.ReplicatedStorage.PlayLocalSound:FireClient(player, 179235828, 0.33)
			if inventory:FindFirstChild(weaponName) then
				inventory:FindFirstChild(weaponName).Value += 1
			else
				local newItem = Instance.new("NumberValue")
				newItem.Value = 1
				newItem.Name = weaponName
				newItem.Parent = inventory --this is the true inventory add, handled ON SERVER
			end
			game.ReplicatedStorage.InventoryAdd:FireClient(player, "+"..weaponName) --only a visual add
		end
	end)
	
	statFrame.ArtiUnequip.Button.MouseButton1Down:Connect(function()--see lines 427-444, but for equipped artifact instead of equipped gear
		if data.Artifact.Value ~= 0 then
			local artifactName = numsToStrings.Artifacts[data.Artifact.Value]
			data.Artifact.Value = 0
			game.ReplicatedStorage.PlayLocalSound:FireClient(player, 179235828, 0.33)
			if inventory:FindFirstChild(artifactName) then
				inventory:FindFirstChild(artifactName).Value += 1
			else
				local newItem = Instance.new("NumberValue")
				newItem.Value = 1
				newItem.Name = artifactName
				newItem.Parent = inventory --this is the true inventory add, handled ON SERVER
			end
			game.ReplicatedStorage.InventoryAdd:FireClient(player, "+"..artifactName) --only a visual add
		end
	end)
	script.Parent.SkillsFrameBG.PassiveButton.Button.MouseButton1Down:Connect(function() --while viewing skills, click the passive button to switch the tab to your passives to instead view your passive abilities
		if db.Value == false then
			db.Value = true
			game.ReplicatedStorage.PlayLocalSound:FireClient(player, 179235828, 0.33)
			abilityTab = "Passives"
			script.Parent.SkillsFrameBG.ActiveButton.ImageColor3 = Color3.fromRGB(255,255,255)
			script.Parent.SkillsFrameBG.PassiveButton.ImageColor3 = Color3.fromRGB(116,116,116)
			script.Parent.SkillsFrameBG.KnowledgeBG.Visible = false
			updateSkills()
			task.wait(0.1)
			db.Value = false
		end
	end)
	script.Parent.SkillsFrameBG.ActiveButton.Button.MouseButton1Down:Connect(function()--while viewing skills, click the active button to switch the tab to your actives to instead view your actives abilities
		if db.Value == false then
			db.Value = true
			game.ReplicatedStorage.PlayLocalSound:FireClient(player, 179235828, 0.33)
			abilityTab = "Actives"
			script.Parent.SkillsFrameBG.ActiveButton.ImageColor3 = Color3.fromRGB(116,116,116)
			script.Parent.SkillsFrameBG.PassiveButton.ImageColor3 = Color3.fromRGB(255,255,255)
			script.Parent.SkillsFrameBG.KnowledgeBG.Visible = false
			updateSkills()
			task.wait(0.1)
			db.Value = false
		end
	end)
	
end

