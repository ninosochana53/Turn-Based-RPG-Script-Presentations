local player = script.Parent.Parent.Parent.Parent
local clickdb = 0
if player:IsA("Player") then --make sure we're configuring a battle menu for a player
	
	function LSFX(SoundID, volume) --player SFX that can only be heared by the local player
		local clone = game.Players.LocalPlayer.PlayerGui.LocalSound:Clone()
		clone.PlayOnRemove = true
		clone.Name = "LSFXClone"
		clone.Parent = game.Players.LocalPlayer.PlayerGui
		clone.SoundId = "rbxassetid://"..SoundID
		clone.Volume = volume
		clone:Destroy()
	end
	
	local actives = nil --will serve as a table that holds abilities of a player
	local weaponType = nil --fist, staff, sword, spear, dagger, or shield
	local modifications = nil --serves to visually alter UI based on player passives. for example, if i have a passive ability that shifts a certain attack's element from physical to magical, this will return magical, so that my UI shows me 'hey, your attack will be magical type', instead of what it would've shown me normally (physical)
	local activeInfo = nil --attack cooldown, energycost, weapon required to use the attack, target(s), and attack description
	local frame = script.Parent
	local remotes = game.ReplicatedStorage.CombatRemotes

	function createActivesList()
		actives = workspace.PlayerDatas[player.Name].SaveData.Actives:GetChildren() --sort actives alphabetically
		table.sort(actives, function(a,b)
			return a.Name < b.Name --sort abilities alphebetically
		end)
		frame.AttacksFrame:ClearAllChildren() --clear the frame to refresh things such as cooldowns per turn
		if #actives > 5 then --scale scrolling frame
			frame.AttacksFrame.CanvasSize = UDim2.new(0,0,#actives*0.2,0)
		else
			frame.AttacksFrame.CanvasSize = UDim2.new(0,0,1,0)
		end
		weaponType = remotes.GetWeaponType:InvokeServer() --gets what weapon type u have on
		modifications = remotes.GetModifiedActive:InvokeServer(actives)
		--{newBasePower, newAttackElement, newScaling, statusInflictions, debuffInflictions}
		activeInfo = remotes.GetActiveInformation:InvokeServer(actives)
		--{Cooldown, EnergyCost, WeaponReq, Target, Description}
	end
	remotes.CreateActives.OnClientEvent:Connect(createActivesList) --the server has alerted the player that they've started a battle, and that they need to read their actives so that our battle menus can be preloaded to display our abilities
	local highlight = workspace:WaitForChild("VFX"):WaitForChild("TargetHighlight"):Clone() --used to show a highlight on who you are targeting.
	local assetModule = require(game.ReplicatedStorage.AssetsModule) --get visuals for our UI
	local itemsModule = require(game.ReplicatedStorage.ItemData) --read item data such as descriptions and usage
	
	local actionSelected = nil
	local targets = nil
	local TS = game:GetService("TweenService")
	local TInfoSec = TweenInfo.new(1,Enum.EasingStyle.Exponential,Enum.EasingDirection.Out,0,false,0)
	function resetUI(turn) --displays a clean slate battle menu (Attacks, Items, Meditate, Guard, Flee)
		if turn == "Off" then --hide or show based on whether the server has indicated our turn is on or off
			frame.Visible = false
		else
			frame.Visible = true
		end
		targets = nil
		actionSelected = nil
		
		if player.Character.Statuses:FindFirstChild("Shattered") then --*if we have certain status ailments, alter the appearance of certain actions on our UI to indicate that they cannot be used
			player.PlayerGui.BattleGui.FirstFrame.GuardBack.ImageColor3 = Color3.fromRGB(50,50,50)
			player.PlayerGui.BattleGui.FirstFrame.Guard.TextStrokeColor3 = Color3.fromRGB(255,0,0)
		else
			player.PlayerGui.BattleGui.FirstFrame.GuardBack.ImageColor3 = Color3.fromRGB(255,255,255)
			player.PlayerGui.BattleGui.FirstFrame.Guard.TextStrokeColor3 = Color3.fromRGB(255,255,255)
		end
		if player.Character.Statuses:FindFirstChild("Crippled") then
			player.PlayerGui.BattleGui.FirstFrame.FleeBack.ImageColor3 = Color3.fromRGB(50,50,50)
			player.PlayerGui.BattleGui.FirstFrame.Flee.TextStrokeColor3 = Color3.fromRGB(255,0,0)
		else
			player.PlayerGui.BattleGui.FirstFrame.FleeBack.ImageColor3 = Color3.fromRGB(255,255,255)
			player.PlayerGui.BattleGui.FirstFrame.Flee.TextStrokeColor3 = Color3.fromRGB(255,255,255)
		end
		if player.Character.Statuses:FindFirstChild("Confused") then
			player.PlayerGui.BattleGui.FirstFrame.FleeBack.ImageColor3 = Color3.fromRGB(50,50,50)
			player.PlayerGui.BattleGui.FirstFrame.Flee.TextStrokeColor3 = Color3.fromRGB(255,0,0)
		elseif player.Character.Statuses:FindFirstChild("Zombie") then
			player.PlayerGui.BattleGui.FirstFrame.FleeBack.ImageColor3 = Color3.fromRGB(50,50,50)
			player.PlayerGui.BattleGui.FirstFrame.Flee.TextStrokeColor3 = Color3.fromRGB(255,0,0)
		else
			player.PlayerGui.BattleGui.FirstFrame.FleeBack.ImageColor3 = Color3.fromRGB(255,255,255)
			player.PlayerGui.BattleGui.FirstFrame.Flee.TextStrokeColor3 = Color3.fromRGB(255,255,255)
		end--*
		
		frame.AttacksFrame.Visible = false --hide any sub menus
		frame.ItemsFrame.Visible = false
		frame.TargetsFrame.Visible = false
	
		frame.Back.Visible = false
		frame.Back_Ground.Visible = false

		frame.Attack.Visible = true --present the starting menus
		frame.Item.Visible = true
		frame.Flee.Visible = true
		frame.Meditate.Visible = true
		frame.Guard.Visible = true
		frame.ItemBack.Visible = true
		frame.GuardBack.Visible = true
		frame.MedBack.Visible = true
		frame.FleeBack.Visible = true
		frame.AttackBack.Visible = true
		frame.ItemUses.Visible = false
		frame.Descriptor.Visible = false
		frame.TurnNumber.Visible = true
		if turn then
			frame.TurnNumber.Text = "Turn " .. turn --show us what turn it currently is
		end
	end
	
	
	function attackPopup(atkName, modifications) -- a visual popup of what move is about to be used by whoever's turn it is. 
		frame.Parent.Header.Text = ""
		local popupText = script.PopupText:Clone() --create a new UI text label element
		popupText.Text = atkName --the text is equal to the ability name being used
		popupText.Size = UDim2.new(0,0,0,0) --animate its size from 0 to whatever
		local popupBack = script.PopupBack:Clone() --background for it
		popupBack.Size = UDim2.new(0,0,0,0)

		--modifications = {newBasePower, newAttackElement, newScaling, statusInflictions, debuffInflictions}
		if modifications then --if your attack was modified then
			popupBack.BackgroundColor3 = assetModule.Type[modifications[2]].Color --change the color of the background of the ability pop being shown, 
			popupBack.AttackType.Image = assetModule.Type[modifications[2]].Image --as well as change the elemental icon to the new type
		end
		popupBack.Parent = frame.Parent
		popupText.Parent = frame.Parent
		TS:Create(popupText,TInfoSec,{TextTransparency = 0}):Play()
		TS:Create(popupText,TInfoSec,{Position = UDim2.new(0.2,0,0.725,0)}):Play()
		TS:Create(popupText,TInfoSec,{Size = script.PopupText.Size}):Play() --VFX
		
		TS:Create(popupBack,TInfoSec,{BackgroundTransparency = 0}):Play()
		TS:Create(popupBack,TInfoSec,{Size = script.PopupBack.Size}):Play()
		TS:Create(popupBack,TInfoSec,{Position = UDim2.new(0,0,0.7,0)}):Play()
		TS:Create(popupBack.AttackType,TInfoSec,{ImageTransparency = 0}):Play()
		task.wait(2) --the tweens have finished after 1 second, but give people an extra sec to read what ability is being used
		TS:Create(popupBack,TInfoSec,{BackgroundTransparency = 1}):Play()
		TS:Create(popupBack.AttackType,TInfoSec,{ImageTransparency = 1}):Play() --fade out
		
		TS:Create(popupText,TInfoSec,{TextTransparency = 1}):Play()
		task.wait(1)
		popupText:Destroy()
		popupBack:Destroy() 
	end
	remotes.AttackPopup.OnClientEvent:Connect(attackPopup) --server has told us "hey, someone is using an ability atkName, also here's the modifications of it so you know what element the attack is after passive abilities have been accounted for."
	remotes.ResetBattleUI.OnClientEvent:Connect(resetUI) --server has told us "hey, it's your turn, present a clean slate of your battle menu"
	remotes.WhosTurn.OnClientEvent:Connect(function(playerName) --server is giving us a message
		if playerName == "NoFlee" then --you tried to flee in a battle that cannot be fled from (a boss battle). server tells us "hey, you cannot do that!"
			local prevText = frame.Parent.Header.Text
			frame.Parent.Header.Text = "You can't do that right now!"
			LSFX(3774415505, 1)
			task.wait(1.5)
			frame.Parent.Header.Text = prevText
		else
			frame.Parent.Header.Text = playerName .. " is deciding what to do..." --server is simply telling us "a player is deciding what ability they want to use..."
		end
	end)
	
	
	
	function attack() --you selected the attack option from your battle menu. now opens a submenu of all your abilities!
		if clickdb == 0 then
			clickdb = 1
			frame.AttacksFrame:ClearAllChildren() --clear the submenu first
			LSFX(421058925,1)
			local playerTeam = {} --holds players incase your ability is a skill where you will target you and/or allies, likely a supportive/healing skill
			local enemyTeam = {} --holds enemies incase your ability is an offensive attack where you will target enemies
			for j, charMdl in ipairs(player.Character.Parent:GetChildren()) do --search fighters folder
				if charMdl:FindFirstChild("Humanoid") then --player
					table.insert(playerTeam, game.Players:GetPlayerFromCharacter(charMdl))
				else --enemies
					table.insert(enemyTeam, charMdl)
				end
			end

			for index, active in ipairs(actives) do --make buttons for each ability in a player's kit & position them in a scrollable list that scales based on the # of abilities you have. abilities have been preloaded so all we have to do is read from them, see line 39

				local clone = script.Strike:Clone()
				local cloneBack = script.StrikeBack:Clone() --create new UI elements

				clone.Name = active.Name
				clone.Text = active.Name --display ability name

				cloneBack.AttackType.Image = assetModule.Type[modifications[index][2]].Image --display element type
				cloneBack.Cooldown.Text = activeInfo[index][1] --display cooldown of ability

				clone.Position = UDim2.new(0.2,0,0.05+(0.2*(index-1))) --position based on index
				cloneBack.Position = UDim2.new(0,0,0.025+(0.2*(index-1)))
				clone.Parent = frame.AttacksFrame
				cloneBack.Parent = frame.AttacksFrame
				cloneBack.EnergyCost.Text = activeInfo[index][2] --show energy needed to cast ability
				cloneBack.ImageColor3 = assetModule.Type[modifications[index][2]].Color --change button color based on ability's element
				
				if activeInfo[index][2] > 0 and player.Character.Stats.Energy.Value < activeInfo[index][2] then --you dont have enough energy.

					local blackoverlay = script.StrikeBack:Clone()  --darker background, cant use this move due to missing energy
					blackoverlay:ClearAllChildren()
					blackoverlay.ImageColor3 = Color3.fromRGB(0,0,0)
					blackoverlay.ZIndex =  2
					blackoverlay.Parent = frame.AttacksFrame
					blackoverlay.Position = cloneBack.Position

				elseif player.Character.Cooldowns:FindFirstChild(active.Name) then --a cooldown on your attack was found.

					local blackoverlay = script.StrikeBack:Clone()  --darker background, cant use this move due to cooldown.
					blackoverlay:ClearAllChildren()
					blackoverlay.ImageColor3 = Color3.fromRGB(0,0,0)
					blackoverlay.ZIndex =  2
					blackoverlay.Parent = frame.AttacksFrame
					blackoverlay.Position = cloneBack.Position
					local cooldownText = clone:Clone()
					cooldownText.Text = player.Character.Cooldowns:FindFirstChild(active.Name).Value --display how many turns left before you can use it
					cooldownText.ZIndex = 3
					cooldownText.Parent = frame.AttacksFrame

				else --you can do your move freely, depending on weapon held
					local cont = false
					if table.find(activeInfo[index][3], "Any") then
						cont = true --anyone can use this move, let an on-click event be connected
					else
						if table.find(activeInfo[index][3], weaponType) then
							cont = true
						end
					end
					if cont then --sufficient energy, ability not on Cooldown, and you have the correct weapon to use this ability. create a function that fires upon button click!
						local function cloneClicked()
							if clickdb == 0 then
								clickdb = 1
								LSFX(421058925, 1)
								frame.TargetsFrame:ClearAllChildren() --clear target list to refresh button connections and stuff
								frame.AttacksFrame.Visible = false --hide the submenu of your abilities in order to present the next and last submenu (if applicable, AoE skills dont need because their targets is automatically set to the entire enemy/player team), a submenu of which target you are going to select!
								
								if activeInfo[index][4] == "Player" or  activeInfo[index][4] == "AdjacentPlayer" then --a supporting move targets an ally

									for j, plr in ipairs(playerTeam) do --each player needs a text button for target
										if plr and plr:FindFirstChild("PlayerGui") then
											local textClone = script.Strike:Clone()
											local targetBack = script.NormalBack:Clone() --create new UI elements

											textClone.Name = plr.Name
											textClone.Text = plr.Name --show the name of the target player

											textClone.Position = UDim2.new(0.2,0,0.05+(0.2*(j-1)))
											targetBack.Position = UDim2.new(0,0,0.025+(0.2*(j-1))) --position properly
											textClone.Parent = frame.TargetsFrame
											targetBack.Parent = frame.TargetsFrame

											textClone.MouseEnter:Connect(function() --make a highlight over who you're about to target if your mouse hovers over the UI button that matches the target's name
												highlight.Enabled = true
												highlight.Parent = plr.Character
											end)
											textClone.MouseLeave:Connect(function() --remote highlight when mouse leaves
												highlight.Enabled = false
												highlight.Parent = script
											end)

											local function targetClicked()
												if clickdb == 0 then
													clickdb = 1
													LSFX(421058925, 1)
													targets = {plr.Character} -- you selected this character
													actionSelected = active.Name
													player.Character.Parent.Parent:FindFirstChild("ActionRequest", true):FireServer(actionSelected, targets) --server validates your action request. see lines 115-168 of battlescript
													task.wait(0.35)
													clickdb = 0
												end
											end
											textClone.MouseButton1Click:Connect(targetClicked)
											textClone.TouchTap:Connect(targetClicked)
										end
									end
									frame.TargetsFrame.Visible = true

								elseif activeInfo[index][4] == "Enemy" or activeInfo[index][4] == "AdjacentEnemy" then --same as above, but for enemytargets, reading from enemyteam table

									for j, enemy in ipairs(enemyTeam) do --each enemy needs a text button for target
										local textClone = script.Strike:Clone()
										local targetBack = script.NormalBack:Clone()

										textClone.Name = enemy.Name
										textClone.Text = enemy.Zombie.DisplayName

										textClone.Position = UDim2.new(0.2,0,0.05+(0.2*(j-1)))
										targetBack.Position = UDim2.new(0,0,0.025+(0.2*(j-1)))
										textClone.Parent = frame.TargetsFrame
										targetBack.Parent = frame.TargetsFrame

										textClone.MouseEnter:Connect(function() --make a highlight of who you're about to target
											highlight.Enabled = true
											highlight.Parent = enemy
										end)
										textClone.MouseLeave:Connect(function()
											highlight.Enabled = false
											highlight.Parent = script
										end)

										
										local function targetClicked()
											if clickdb == 0 then
												clickdb = 1
												LSFX(421058925, 1)
												targets = {enemy} -- you selected this enemy
												actionSelected = active.Name
												player.Character.Parent.Parent:FindFirstChild("ActionRequest", true):FireServer(actionSelected, targets)
												task.wait(0.35)
												clickdb = 0
											end
										end
										textClone.MouseButton1Click:Connect(targetClicked)
										textClone.TouchTap:Connect(targetClicked)
									end
									frame.TargetsFrame.Visible = true

								elseif activeInfo[index][4] == "Self" then --could be a buffing move. self doesnt need target submenu because the target is always auto selected as self.
									--skip target frame
									actionSelected = active.Name
									targets = {player.Character}
									player.Character.Parent.Parent:FindFirstChild("ActionRequest", true):FireServer(actionSelected, targets)
								elseif activeInfo[index][4] == "Players" then --probably a supporting all move
									--skip target frame because the target will always be the entire ally team

									actionSelected = active.Name
									targets = playerTeam --all players
									player.Character.Parent.Parent:FindFirstChild("ActionRequest", true):FireServer(actionSelected, targets)
								elseif activeInfo[index][4] == "Enemies" then --probably an AoE attack
									--skip target frame because the target will always be the entire enemy team

									actionSelected = active.Name
									targets = enemyTeam --all enemies
									player.Character.Parent.Parent:FindFirstChild("ActionRequest", true):FireServer(actionSelected, targets)
								elseif activeInfo[index][4] == "DeadPlayer" then --revives and stuff

									for j, plr in ipairs(playerTeam) do --each player needs a text button for target
										if plr and plr:FindFirstChild("PlayerGui") and plr.Character.Stats.CurrentHP.Value <= 0 then --dead player, can be targeted
											local textClone = script.Strike:Clone()
											local targetBack = script.NormalBack:Clone()

											textClone.Name = plr.Name
											textClone.Text = plr.Name

											textClone.Position = UDim2.new(0.2,0,0.05+(0.2*(j-1)))
											targetBack.Position = UDim2.new(0,0,0.025+(0.2*(j-1)))
											textClone.Parent = frame.TargetsFrame
											targetBack.Parent = frame.TargetsFrame

											textClone.MouseEnter:Connect(function() --make a highlight of who you're about to target
												highlight.Enabled = true
												highlight.Parent = plr.Character
											end)
											textClone.MouseLeave:Connect(function()
												highlight.Enabled = false
												highlight.Parent = script
											end)

											local function targetClicked()
												if clickdb == 0 then
													clickdb = 1
													LSFX(421058925, 1)
													targets = {plr.Character} -- you selected this character
													actionSelected = active.Name
													player.Character.Parent.Parent:FindFirstChild("ActionRequest", true):FireServer(actionSelected, targets)
													task.wait(0.35)
													clickdb = 0
												end
											end
											
											textClone.MouseButton1Click:Connect(targetClicked)
											textClone.TouchTap:Connect(targetClicked)
										end
									end
									frame.TargetsFrame.Visible = true

								end
								task.wait(0.25)
								clickdb = 0
							end
						end
						clone.MouseButton1Click:Connect(cloneClicked)
						clone.TouchTap:Connect(cloneClicked)
						
					else
						local blackoverlay = script.StrikeBack:Clone()  --darker background, cant use this move due to not having correct weapon.
						blackoverlay:ClearAllChildren()
						blackoverlay.ImageColor3 = Color3.fromRGB(0,0,0)
						blackoverlay.ZIndex =  2
						blackoverlay.Parent = frame.AttacksFrame
						blackoverlay.Position = cloneBack.Position

					end

				end

				clone.MouseEnter:Connect(function() --display attack description
					frame.Descriptor.Visible = true
					frame.Descriptor.Text = activeInfo[index][5]
				end)
				clone.MouseLeave:Connect(function() --remove attack description
					frame.Descriptor.Visible = false
				end)

			end


			frame.AttacksFrame.Visible = true --show attack list submenu
			frame.ItemsFrame.Visible = false
			frame.TargetsFrame.Visible = false --hide other submenus
			frame.Back.Visible = true --show back button to be able to return to the main battle menu
			
			frame.Back_Ground.Visible = true
			--hide main menu buttons
			frame.Attack.Visible = false
			frame.Item.Visible = false 
			frame.Flee.Visible = false
			frame.Meditate.Visible = false
			frame.Guard.Visible = false
			frame.ItemBack.Visible = false
			frame.GuardBack.Visible = false
			frame.MedBack.Visible = false
			frame.FleeBack.Visible = false
			frame.AttackBack.Visible = false
			frame.ItemUses.Visible = false
			frame.Descriptor.Visible = false
			frame.TurnNumber.Visible = false
			task.wait(0.25)
			clickdb = 0
		end
	end
	
	frame.Attack.MouseButton1Click:Connect(attack)
	frame.Attack.TouchTap:Connect(attack)
	
	function item() --item() behaves nearly identically to attack() only instead configured for a player's items rather than their attacks, so im not going to have as precise code comments
		if clickdb == 0 then
			clickdb = 1
			LSFX(421058925, 1)
			local playerTeam = {}
			for j, charMdl in ipairs(player.Character.Parent:GetChildren()) do --search fighters folder
				if charMdl:FindFirstChild("Humanoid") then
					table.insert(playerTeam, game.Players:GetPlayerFromCharacter(charMdl))
				end
			end
			local enemyTeam = {}
			for j, charMdl in ipairs(player.Character.Parent:GetChildren()) do --search fighters folder
				if charMdl:FindFirstChild("Zombie") then
					table.insert(enemyTeam, charMdl)
				end
			end
			--items works like actives loop at bottom of this pcall, however need to be called everytime
			frame.ItemsFrame:ClearAllChildren()
			local items = workspace.PlayerDatas[player.Name].SaveData.Inventory:GetChildren() --sort items alphabetically
			local usableItems = {}
			for i, numberValue in ipairs(items) do --loops through your entire inventory, but only stores actual in-battle consumable items in usableItems
				if numberValue and itemsModule[numberValue.Name].Uses >= 0 then 
					table.insert(usableItems, numberValue)
				end
			end

			table.sort(usableItems, function(a,b) --sort usableItems alphabetically, then bind functions to them later similar to active abilities 
				return a.Name < b.Name
			end)
			
			if #usableItems > 5 then --scale scrolling frame
				frame.ItemsFrame.CanvasSize = UDim2.new(0,0,#usableItems*0.2,0)
			else
				frame.ItemsFrame.CanvasSize = UDim2.new(0,0,1,0)
			end
			for index, item in ipairs(usableItems) do --make buttons for them & position them

				local clone = script.Strike:Clone()
				local cloneBack = script.ItemBack:Clone()

				clone.Name = item.Name
				clone.Text = item.Name

				cloneBack.Count.Text = "x"..item.Value

				clone.Position = UDim2.new(0.2,0,0.05+(0.2*(index-1)))
				cloneBack.Position = UDim2.new(0,0,0.025+(0.2*(index-1)))
				clone.Parent = frame.ItemsFrame
				cloneBack.Parent = frame.ItemsFrame


				if player.Character.Stats.ItemUses.Value < itemsModule[item.Name].Uses then --not enough uses
					local blackoverlay = script.StrikeBack:Clone()  --darker background, cant use this item, not enough uses.
					blackoverlay:ClearAllChildren()
					blackoverlay.ImageColor3 = Color3.fromRGB(0,0,0)
					blackoverlay.ZIndex =  2
					blackoverlay.Parent = frame.AttacksFrame
					blackoverlay.Position = cloneBack.Position
				else

					local function cloneClicked()
						if clickdb == 0 then
							clickdb = 1
							LSFX(421058925, 1)
							frame.TargetsFrame:ClearAllChildren() --clear target list to refresh button connections and stuff
							frame.ItemsFrame.Visible = false
							if itemsModule[item.Name].Target == "Player" or itemsModule[item.Name].Target == "AdjacentPlayer" then --could be a supporting move

								for j, plr in ipairs(playerTeam) do --each player needs a text button for target
									if plr and plr:FindFirstChild("PlayerGui") then
										local textClone = script.Strike:Clone()
										local targetBack = script.NormalBack:Clone()

										textClone.Name = plr.Name
										textClone.Text = plr.Name

										textClone.Position = UDim2.new(0.2,0,0.05+(0.2*(j-1)))
										targetBack.Position = UDim2.new(0,0,0.025+(0.2*(j-1)))
										textClone.Parent = frame.TargetsFrame
										targetBack.Parent = frame.TargetsFrame

										textClone.MouseEnter:Connect(function() --make a highlight of who you're about to target
											highlight.Enabled = true
											highlight.Parent = plr.Character
										end)
										textClone.MouseLeave:Connect(function()
											highlight.Enabled = false
											highlight.Parent = script
										end)

										local function targetClicked()
											if clickdb == 0 then
												clickdb = 1
												LSFX(421058925, 1)
												targets = {plr.Character} -- you selected this character
												actionSelected = item.Name
												player.Character.Parent.Parent:FindFirstChild("ActionRequest", true):FireServer(actionSelected, targets)
												task.wait(0.25)
												clickdb = 0
											end
										end
										textClone.MouseButton1Click:Connect(targetClicked)
										textClone.TouchTap:Connect(targetClicked)
									end
								end
								frame.TargetsFrame.Visible = true

							elseif itemsModule[item.Name].Target == "Enemy" or itemsModule[item.Name].Target == "AdjacentEnemy" then

								for j, enemy in ipairs(enemyTeam) do --each enemy needs a text button for target
									local textClone = script.Strike:Clone()
									local targetBack = script.NormalBack:Clone()

									textClone.Name = enemy.Name
									textClone.Text = enemy.Zombie.DisplayName

									textClone.Position = UDim2.new(0.2,0,0.05+(0.2*(j-1)))
									targetBack.Position = UDim2.new(0,0,0.025+(0.2*(j-1)))
									textClone.Parent = frame.TargetsFrame
									targetBack.Parent = frame.TargetsFrame

									textClone.MouseEnter:Connect(function() --make a highlight of who you're about to target
										highlight.Enabled = true
										highlight.Parent = enemy
									end)
									textClone.MouseLeave:Connect(function()
										highlight.Enabled = false
										highlight.Parent = script
									end)

									local function targetClicked()
										if clickdb == 0 then
											clickdb = 1
											LSFX(421058925, 1)
											targets = {enemy} -- you selected this enemy
											actionSelected = item.Name
											player.Character.Parent.Parent:FindFirstChild("ActionRequest", true):FireServer(actionSelected, targets)
											task.wait(.25)
											clickdb = 0
										end
									end
									textClone.MouseButton1Click:Connect(targetClicked)
									textClone.TouchTap:Connect(targetClicked)
								end
								frame.TargetsFrame.Visible = true

							elseif itemsModule[item.Name].Target == "Self" then --could be a buffing move
								--skip target frame
								actionSelected = item.Name
								targets = {player.Character}
								player.Character.Parent.Parent:FindFirstChild("ActionRequest", true):FireServer(actionSelected, targets)
							elseif itemsModule[item.Name].Target == "Players" then --probably a supporting all item
								--skip target frame
								actionSelected = item.Name
								targets = playerTeam --all players
								player.Character.Parent.Parent:FindFirstChild("ActionRequest", true):FireServer(actionSelected, targets)
							elseif itemsModule[item.Name].Target == "Enemies" then --probably an AoE attacking item, like a grenade 
								--skip target frame
								actionSelected = item.Name
								targets = enemyTeam --all enemies
								player.Character.Parent.Parent:FindFirstChild("ActionRequest", true):FireServer(actionSelected, targets)
							elseif itemsModule[item.Name].Target == "DeadPlayer" then --revives n stuff? idk

								for j, plr in ipairs(playerTeam) do --each player needs a text button for target
									if plr and plr:FindFirstChild("PlayerGui") and plr.Character.Stats.CurrentHP.Value <= 0 then
										local textClone = script.Strike:Clone()
										local targetBack = script.NormalBack:Clone()

										textClone.Name = plr.Name
										textClone.Text = plr.Name

										textClone.Position = UDim2.new(0.2,0,0.05+(0.2*(j-1)))
										targetBack.Position = UDim2.new(0,0,0.025+(0.2*(j-1)))
										textClone.Parent = frame.TargetsFrame
										targetBack.Parent = frame.TargetsFrame

										textClone.MouseEnter:Connect(function() --make a highlight of who you're about to target
											highlight.Enabled = true
											highlight.Parent = plr.Character
										end)
										textClone.MouseLeave:Connect(function()
											highlight.Enabled = false
											highlight.Parent = script
										end)

										local function targetClicked()
											if clickdb == 0 then
												clickdb = 1
												LSFX(421058925, 1)
												targets = {plr.Character} -- you selected this character
												actionSelected = item.Name
												player.Character.Parent.Parent:FindFirstChild("ActionRequest", true):FireServer(actionSelected, targets)
												task.wait(.25)
												clickdb = 0
											end
										end
										textClone.MouseButton1Click:Connect(targetClicked)
										textClone.TouchTap:Connect(targetClicked)
									end
								end
								frame.TargetsFrame.Visible = true
							end
							task.wait(0.25)
							clickdb = 0
						end
					end
					clone.MouseButton1Click:Connect(cloneClicked)
					clone.TouchTap:Connect(cloneClicked)


				end

				clone.MouseEnter:Connect(function() --display item description
					frame.Descriptor.Visible = true
					frame.Descriptor.Text = itemsModule[item.Name].Description
				end)
				clone.MouseLeave:Connect(function() --remove item description
					frame.Descriptor.Visible = false
				end)
			end

			frame.AttacksFrame.Visible = false
			frame.TargetsFrame.Visible = false
			frame.ItemsFrame.Visible = true
			frame.Back.Visible = true
			frame.Back_Ground.Visible = true
			frame.ItemUses.Visible = true
			frame.ItemUses.Text = "Uses: " .. player.Character.Stats.ItemUses.Value

			frame.Attack.Visible = false
			frame.Item.Visible = false
			frame.Flee.Visible = false
			frame.Meditate.Visible = false
			frame.Guard.Visible = false
			frame.ItemBack.Visible = false
			frame.GuardBack.Visible = false
			frame.MedBack.Visible = false
			frame.FleeBack.Visible = false
			frame.AttackBack.Visible = false
			frame.TurnNumber.Visible = false

			task.wait(0.25)
			clickdb = 0
		end
	end
	frame.Item.MouseButton1Click:Connect(item)
	frame.Item.TouchTap:Connect(item)
	
	--guard, meditate, and flee are much more simpler as they are always targetting yourself, and fire as soon as you press the button.
	function guard()
		if clickdb == 0 then
			clickdb = 1
			if frame.Guard.TextStrokeColor3 == Color3.fromRGB(255,0,0) then

			else
				LSFX(421058925, 1)
				actionSelected = "Guard"
				player.Character.Parent.Parent:FindFirstChild("ActionRequest", true):FireServer(actionSelected)
				task.wait(0.25)
			end
			clickdb = 0
		end
	end
	frame.Guard.MouseButton1Click:Connect(guard)
	frame.Guard.TouchTap:Connect(guard)
	
	function meditate()
		if clickdb == 0 then
			clickdb = 1
			if frame.Meditate.TextStrokeColor3 == Color3.fromRGB(255,0,0) then

			else
				LSFX(421058925, 1)
				actionSelected = "Meditate"
				player.Character.Parent.Parent:FindFirstChild("ActionRequest", true):FireServer(actionSelected)
				task.wait(0.25)
			end
			clickdb = 0
		end
	end
	frame.Meditate.MouseButton1Click:Connect(meditate)
	frame.Meditate.TouchTap:Connect(meditate)
	
	function flee()
		if clickdb == 0 then
			clickdb = 1
			if frame.Flee.TextStrokeColor3 == Color3.fromRGB(255,0,0) then

			else
				LSFX(421058925, 1)
				actionSelected = "Flee"
				player.Character.Parent.Parent:FindFirstChild("ActionRequest", true):FireServer(actionSelected)
				task.wait(0.25)
			end
			clickdb = 0
		end
	end
	frame.Flee.MouseButton1Click:Connect(flee)
	frame.Flee.TouchTap:Connect(flee)
	
	function back() --back button was clicked, hide any & all submenus, present main battle menu once again (Attacks, Items, Meditate, Guard, Flee)
		if clickdb == 0 then
			clickdb = 1
			resetUI()
			LSFX(421058925, 1)
			task.wait(0.25)
			clickdb = 0
		end
	end
	frame.Back.MouseButton1Click:Connect(back)
	frame.Back.TouchTap:Connect(back)
end