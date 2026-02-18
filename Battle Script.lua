local turn = 0
local activesModule = require(game.ServerScriptService.ActiveAbilities)
local assetModule = require(game.ReplicatedStorage.AssetsModule)
local descriptionsModule = require(game.ServerScriptService.Descriptions)
local itemsModule = require(game.ReplicatedStorage.ItemData)
local itemFuncs = require(game.ServerScriptService.ItemFuncs) --purely battle functions
local mobData = require(game.ServerScriptService.MobData)
local mobAttacks = game.ServerScriptService.MobAttacks
local weaponsModule = require(game.ServerScriptService.Weapons)
local passiveFunctions = require(game.ServerScriptService.PassiveFunctions)
local passiveAbilities = require(game.ServerScriptService.PassiveAbilities)
local calcModule = require(game.ServerScriptService.CalcFuncs)
local damageDisplayFuncs = require(game.ServerScriptService.DamageDisplayFuncs)
local activeInformation = require(game.ServerScriptService.ActiveInformation)
local calculateStatsModule = require(game.ServerScriptService.CalculateStatsBuffsDebuffs)
local statusControl = require(game.ServerScriptService.StatusControl)
local soulTreeFuncs = require(game.ServerScriptService.SoulTreeFuncs)
local numstoStrings = require(game.ServerScriptService.NumbersToStrings)
local setupMobsModule = require(game.ServerScriptService.CombatModules.HandleMobs)
local dotFunctions = require(game.ServerScriptService.CombatModules.DoTFunctions)
local turnOrderModule = require(game.ServerScriptService.CombatModules.DecideTurnOrder)
local universalActionModule = require(game.ServerScriptService.CombatModules.UniversalActions)
--all modules required to operate various functions remotely

local turnOrder = { --a table that acts as a holder for a turn queue

}

local EXPPot = 0
local GoldPot = 0
local drops = {} --dictionary where ["1"] = {["Name"] = dropName, ["BaseChance"] = baseChance, ["MinAmount"], = x ["MaxAmount"] = y}. data on the drops is obtained from mobData using a key (a mob's name) to access a table containing various datas on the mob.

local playerTeam = {} --table of player objects (game.players, not character models)
local enemyTeam = {} --table of enemy charactermodels



setupMobsModule.setupMobs(script.Parent.Fighters:GetChildren()) --initializes mobs, sets their HP stats, enables their AI scripts, etc
for i, v in ipairs(script.Parent.Fighters:GetChildren()) do
	if v:FindFirstChild("Zombie") then
		mobData.healthChanged(v.Stats, v.HumanoidRootPart.HealthBar) --visually represent a mob's health bar to players
		mobData.energyChanged(v.Stats, v.HumanoidRootPart.HealthBar) --visually show energy
	end
end

local getSong = workspace.MusicBox:GetChildren()[math.random(1,#workspace.MusicBox:GetChildren())] --get a random song from a pool of songs within the musicbox folder
for i, v in ipairs(script.Parent.Fighters:GetChildren()) do
	if game.Players:GetPlayerFromCharacter(v) then
		game.ReplicatedStorage.MusicSwap:FireClient(game.Players:GetPlayerFromCharacter(v),"Battle",getSong.SoundId, getSong.Volume)
	end
end

turnOrder = turnOrderModule.decideTurnOrder(turn, script.Parent.Fighters, script.CanFlee.Value) --calculates turn order based on players' and enemies' SPEED values. dynamically changes within battles based on SPEED Buffs/debuffs, status ailments, etc.
playerTeam, enemyTeam, drops, GoldPot, EXPPot = setupMobsModule.updateTeams(script.Parent.Fighters, drops, GoldPot, EXPPot) 
--update teams returns all players, enemies, an updated version of drops that will add drops to the already existing table of drops incase an enemy's HP is 0, and updates EXP & Gold based on the enemy that died.

local turnFinished = false
local leaveConnection = nil --if a player leaves the game, a playerremoving event will be connected here to catch the player leaving, and skip their turn.
local clickdb = 0 --debouncer
local actionSelected = "Guard" --default action
local caster = nil --character model of the player currently playing
local targets = {} --a holder for the target(s) selected after a player/mob has chosen an ability


local TS = game:GetService("TweenService")
local TInfoSec = TweenInfo.new(1,Enum.EasingStyle.Exponential,Enum.EasingDirection.Out,0,false,0)
local TInfoTimer = TweenInfo.new(15,Enum.EasingStyle.Linear,Enum.EasingDirection.Out,0,false,0)
local timerConnection = nil

local allPlayersDead = true --loop through all players HP values, if any of them aren't 0 then this is set to false, else true & ends battle as a loss.



for ii, vv in ipairs(playerTeam) do
	if vv and vv:FindFirstChild("PlayerGui") then
		calcModule.calculateStats(vv) --sets correct stats to each player, regarding ALL equipment, passives abilities, skill tree, equipment, anything.
		local superclass = numstoStrings.SuperClasses[workspace.PlayerDatas[vv.Name].SaveData.SuperClass.Value]
		local baseclass = numstoStrings.BaseClasses[workspace.PlayerDatas[vv.Name].SaveData.BaseClass.Value]
		local anim = nil--get idle animation and play it based on a player's base/super class 
		if workspace:FindFirstChild("IdleAnim"..vv.Name) then 
			anim = workspace:FindFirstChild("IdleAnim"..vv.Name)
		else
			anim = workspace.IdleAnim:Clone()
			anim.Name = "IdleAnim"..vv.Name
			anim.Parent = workspace
		end
		if superclass ~= "None" then
			anim.AnimationId = assetModule.Animations.SuperClasses[superclass].Idle
			vv.Character.Humanoid.Animator:LoadAnimation(anim):Play()
		else
			anim.AnimationId = assetModule.Animations.BaseClasses[baseclass].Idle
			vv.Character.Humanoid.Animator:LoadAnimation(anim):Play()
		end
	end
end


for ii, vv in ipairs(playerTeam) do --handle start of battle passive abilities for players
	if vv and vv:FindFirstChild("PlayerGui") then
		passiveFunctions.onBattleStart(vv.Character, playerTeam, enemyTeam)
	end
end


local truebreak = false --if this is true, the battle is deemed finished.
local remotes = game.ReplicatedStorage.CombatRemotes --a folder containing remoteevents and remotefunctions for client-server communications

script.ChildAdded:Connect(function(c)
	if c.Value == "Debounce" then --a debouncer for client requests. we don't want exploiters overloading the server with incorrect fireservers!
		task.wait(2)
		c:Destroy()
	end
end)

script.ActionRequest.OnServerEvent:Connect(function(client, actionName, targetList) --all it does is validate your action, and if its valid then turnfinished = true
	if client and actionName and not script:FindFirstChild(client.Name) and client.Character == caster then
		local dbClone = script.SoundID:Clone()
		dbClone.Name = client.Name
		dbClone.Value = "Debounce"
		dbClone.Parent = script
		
		if itemsModule[actionName] then --check if the client submitted a real item, check if the item is a consumable, check if the client still has item uses left in the battle
			if itemsModule[actionName] and itemsModule[actionName].Uses >= 0 and client.Character.Stats.ItemUses.Value >= itemsModule[actionName].Uses then
				actionSelected = actionName
				targets = targetList
				turnFinished = true
			end
		elseif activesModule[actionName] then --check if the client truly knows the ability they submitted, check if their ability submitted is NOT on cooldown, and check if the client has enough energy to cast the ability
			if workspace.PlayerDatas:FindFirstChild(client.Name).SaveData.Actives:FindFirstChild(actionName) and not client.Character.Cooldowns:FindFirstChild(actionName) and client.Character.Stats.Energy.Value >= activeInformation[actionName].EnergyCost then 
				actionSelected = actionName
				targets = targetList
				turnFinished = true
			end
		elseif actionName == "Guard" then
			if client.Character.Statuses:FindFirstChild("Shattered") then --check if the client can guard. this status ailment disables guarding
				
			else
				actionSelected = actionName
				targets = targetList
				turnFinished = true
			end
		elseif actionName == "Meditate" then
			if client.Character.Statuses:FindFirstChild("Zombie") then --check if the client can meditate. zombie and confused disable it.

			elseif client.Character.Statuses:FindFirstChild("Confused") then
					
			else
				actionSelected = actionName
				targets = targetList
				turnFinished = true
			end
		elseif actionName == "Flee" then
			if client.Character.Statuses:FindFirstChild("Crippled") then --check if the client is crippled. if not, they may flee.

			else
				if script.CanFlee.Value <= 0 then --but first, we must check if the battle was instantiated as a battle that you cannot flee from. if so, alert the player with a message.
					remotes.WhosTurn:FireClient(client, "NoFlee")
					actionSelected = "Guard"
				else
					actionSelected = actionName
					targets = targetList
					turnFinished = true
				end
			end
		end
		
	end
end)

task.wait(1)
while script do
	turn += 1
	script.Turn.Value = turn
	turnFinished = false --turnstart for the next player/mob in the queue
	if leaveConnection then --disconnect and null to refresh for next player's turn
		leaveConnection:Disconnect()
		leaveConnection = nil
	end
	task.wait()
	for i, v in ipairs(script.Parent.Fighters:GetChildren()) do --tick ability cooldowns down by 1 for every player and enemy
		if v then
			for ii, vv in ipairs(v.Cooldowns:GetChildren()) do
				if vv and vv:IsA("NumberValue") then
					vv.Value -= 1
					if vv.Value <= 0 then
						vv:Destroy()
					end
				end
			end
		end
	end
	
	for i, v in ipairs(turnOrder) do --turn order holds the enemymodels and players of enemies/players
		actionSelected = "Guard" --guarding is default, should you run out of time to pick an action.
		caster = nil --caster = whoever's turn it currently is. 
		targets = {} --a table of targets. it is dependant on the ability to use. an AoE attack will return a table of all enemy objects, for example.
		
		if timerConnection then --recycle variable to be used for the next player's timer
			timerConnection:Disconnect()
			timerConnection = nil
		end
		playerTeam, enemyTeam, drops, GoldPot, EXPPot = setupMobsModule.updateTeams(script.Parent.Fighters, drops, GoldPot, EXPPot) --update function, as seen previously on line 54. 
		
		for ii, vv in ipairs(playerTeam) do
			if vv and vv:FindFirstChild("PlayerGui") and vv.Character.Stats.CurrentHP.Value > 0 then --if any player is alive, the battle is not over
				allPlayersDead = false
				truebreak = false
				break
			else --else it's over
				truebreak = true
				allPlayersDead = true
			end
		end
		if allPlayersDead == true then --all players were found to be dead, let's end the battle, it's a loss
			truebreak = true
			break
		end
		if #enemyTeam == 0 then --if all enemies are wiped out, the battle is over, it's a win
			truebreak = true
			allPlayersDead = false
			break
		end
		if #playerTeam == 0 then --all players left the battle from escaping/leaving the game/etc, cleanup the battle
			truebreak = true
			allPlayersDead = false
			break
		end
		if truebreak then --safety rail
			break
		end
		task.wait()
		if v and v.Name and  script.Parent.Fighters:FindFirstChild(v.Name) and game.Players:GetPlayerFromCharacter(v) then --if model exists and it's a player then
			function playerTurn()
				--initiate player v's turn
				local onTurnPassives = passiveFunctions.OnTurnStart(v, turn) --handle passive abilities that fire on a turn start
				local cont = turnOrderModule.turnStart(v) --handles ailment ticks, confused/stun/sleep affecting ur turn, energy gain/loss, etc

				if cont == "Continue" then --if turnStart returned "Continue" then you may continue taking an action, else you were either at 0 HP (dead), or had a status ailment that skips your turn
					turnFinished = false
					for ii, vv in ipairs(playerTeam) do --display to everyone that player v's turn is being taken
						if vv then
							remotes.WhosTurn:FireClient(vv, v.Name)
						end
					end				
					local player = game.Players:GetPlayerFromCharacter(v)
					player.Character.SelectedAction.Value = ""
					leaveConnection = game.Players.PlayerRemoving:Connect(function(pLeave) --if you leave, your turn will end as normal.
						if pLeave == player then
							turnFinished = true
						end
					end)

					caster = player.Character
					if v.Statuses:FindFirstChild("Fury") then --if you have fury status, your action is auto selected to be strike on a random enemy.
						actionSelected = "Strike"
						targets = {enemyTeam[math.random(1,#enemyTeam)]}
					else
						remotes.ResetBattleUI:FireClient(player, turn) --tells the client to refresh their Battling UI (Attack, Item, Meditate, Guard, Flee menu)

						local timerFunc = false
						local timerTween = nil
						for index, plrCount in ipairs(script.Parent.Fighters:GetChildren()) do
							if plrCount:FindFirstChild("Humanoid") and timerFunc == false then --found 1 player.
								timerFunc = 1
							elseif plrCount:FindFirstChild("Humanoid") and timerFunc == 1 then --found 2 players, make a timer. we dont want a player spending 3000 years on their turn while another player is waiting for them to take their action!
								timerFunc = true 
								break
							end
						end
						if timerFunc == true and timerFunc ~= 1 then --if there is more than 1 player then create a timer on the player's screen, else there is no need for a timer, because a solo player can take as long as they like.
							player.PlayerGui.BattleGui.FirstFrame.Timer.Visible = true
							player.PlayerGui.BattleGui.FirstFrame.TimerBack.Visible = true
							player.PlayerGui.BattleGui.FirstFrame.Timer.Size = UDim2.new(1,0,0.08,0)
							timerTween = TS:Create(player.PlayerGui.BattleGui.FirstFrame.Timer, TInfoTimer, {Size = UDim2.new(0,0,0.08,0)})
							timerConnection = timerTween.Completed:Connect(function()
								turnFinished = true
							end)
							timerTween:Play()
						else
							player.PlayerGui.BattleGui.FirstFrame.Timer.Visible = false --hide timer
							player.PlayerGui.BattleGui.FirstFrame.TimerBack.Visible = false
						end
						repeat
							task.wait(0.25)
						until 
						turnFinished
						if player then
							remotes.ResetBattleUI:FireClient(player, "Off") --tells a client to hide their battle menu since their turn is over
						end

						if leaveConnection then --recycle variables
							leaveConnection:Disconnect()
							leaveConnection = nil
						end
						if timerConnection then --recycle variables
							timerConnection:Disconnect()
							timerConnection = nil
							if timerTween then
								timerTween:Pause()
							end
						end
					end

					local popupMods = nil
					if activeInformation[actionSelected] then --if the player chose an action, get modifications to the action based on a player's passive abilities
						popupMods = passiveFunctions.AttackModifiers(caster, targets[1], actionSelected, 0, activeInformation[actionSelected].Type, activeInformation[actionSelected].Scaling, {}, {})
						--popupMods = {newBasePower, newAttackElement, newScaling, statusInflictions, debuffInflictions}
					end
					for ii, vv in ipairs(playerTeam) do --display to all players what ability the player is about to use
						if vv then
							remotes.AttackPopup:FireClient(vv, actionSelected, popupMods) --send over the name of the ability, as well as popupMods to all clients. popupMods is sent mainly to showcase the element of the ability being used.
						end
					end	
				
					player.Character.SelectedAction.Value = actionSelected --just incase
					
					local QTEsuccess = nil
					local qtePrompt = nil
					if activeInformation[actionSelected] and activeInformation[actionSelected].QTE ~= "None" then --play a QTE if your selected action is found to have a QTE
						qtePrompt = game.ServerStorage.QTES:FindFirstChild(activeInformation[actionSelected].QTE):Clone()
						qtePrompt.Parent = player.PlayerGui
						qtePrompt.QTEConfig.Enabled = true
						qtePrompt.QTEConfig.GetResult.OnServerEvent:Connect(function(client, result) --gets result from client after their QTE minigame is complete
							if client.Name == player.Name then
								if result == "Success" then
									QTEsuccess = true
								else
									QTEsuccess = false
								end
							end
						end)
					else
						QTEsuccess = true
					end
					
					if QTEsuccess == nil then --if you have a QTE to be played, wait for the player to finish the minigame
						repeat
							task.wait(0.2)
						until
						QTEsuccess ~= nil or not qtePrompt --until you failed/won minigame, or until the qte prompt no longer exists (player left)
					end
					if qtePrompt then
						qtePrompt:Destroy()
					end
					if QTEsuccess then	--if you won the minigame, go through with your ability, else you failed, you do nothing, and your turn is over

						if activesModule[actionSelected] and activeInformation[actionSelected] and player then --an active skill was used
							if activeInformation[actionSelected].Cooldown > 0  and player then
								local newCooldown = Instance.new("NumberValue")
								newCooldown.Name = actionSelected
								newCooldown.Value = activeInformation[actionSelected].Cooldown+1 --add 1 because a 2 cd move would show 1 on ur very next turn otherwise.
								newCooldown.Parent = player.Character.Cooldowns
								if player.Statuses:FindFirstChild("Cold") and not player.Statuses:FindFirstChild("Haste") then
									newCooldown.Value = math.floor(newCooldown.Value*1.5) --cooldowns 50% longer for those inflicted with coldness
								end
								if player.Statuses:FindFirstChild("Haste") and player.Statuses:FindFirstChild("Cold") then
									newCooldown.Value = math.floor(newCooldown.Value/1.5)  --cooldowns shorter for haste
								end
							end

							player.Character.Stats.Energy.Value -= activeInformation[actionSelected].EnergyCost
							local battleFunctionResult = nil

							local success, errorMSG = pcall(function() --pcall as a guard rail so the whole battle doesnt softlock incase of an unexpected error being thrown
								battleFunctionResult = activesModule[actionSelected].battleFunction(targets, caster)  --searches the activeModule library for an active with your name, calls its function. give it the targets table & the caster to read from. It then handles damage calculations, as well as the abilities FX. this thread continues after this function finishes.
							end)
							if not success then
								print("ERROR DURING ACTIVE BATTLE FUNCTION: " .. errorMSG)
							end
							

						elseif itemsModule[actionSelected] and player then --an item was used
							local battleFunctionResult = nil

							--onitem passives
							local itemPassives = passiveFunctions.OnItem(caster, targets[1], actionSelected)
							--incase an item is used on everyone/other targets
							if targets[2] then
								local itemPassives = passiveFunctions.OnItem(caster, targets[2], actionSelected)
							end
							if targets[3] then
								local itemPassives = passiveFunctions.OnItem(caster, targets[3], actionSelected)
							end
							if targets[4] then
								local itemPassives = passiveFunctions.OnItem(caster, targets[4], actionSelected)
							end
							if targets[5] then
								local itemPassives = passiveFunctions.OnItem(caster, targets[5], actionSelected)
							end
							
							caster.Stats.ItemUses.Value -= itemsModule[actionSelected].Uses --players have a limit on how many items can be used per battle 
							workspace.PlayerDatas[caster.Name].SaveData.Inventory:FindFirstChild(actionSelected).Value -= 1 --used item, consume from inventory
							
							local success, errorMSG = pcall(function() --pcall as a guard rail so the whole battle doesnt softlock incase of an unexpected error being thrown
								battleFunctionResult = itemFuncs[actionSelected].battleFunction(targets, caster) --same as the activeModule code comment (see like 365), but for items
							end)
							if not success then
								print("ERROR DURING BATTLE SCRIPT: " .. errorMSG)
							end
						elseif actionSelected == "Guard" and player then
							--if action selected is guard, damage taken is multiplied 0.25x.
							player.Character.SelectedAction.Value = "Guard"
						elseif actionSelected == "Meditate" and player then
							player.Character.SelectedAction.Value = "Meditate"
							universalActionModule.meditate(player) 
						elseif actionSelected == "Flee" and player and script.CanFlee.Value >= 1 then
							player.Character.SelectedAction.Value = "Flee"
							universalActionModule.flee(player, "Default", script.CanFlee.Value)
						end

					else
						local loadFailed = player.Character.Humanoid.Animator:LoadAnimation(game.ServerStorage.FailedQTE)
						loadFailed:Play()
						damageDisplayFuncs.popupText(player.Character, "QTE Failed...", Color3.fromRGB(255, 96, 96), Color3.fromRGB(0,0,0))
						task.wait(1.5)
					end


				elseif cont == "Confused" then --you had Confused status ailment and a random number generator decided you would hit yourself/an ally
					v.SelectedAction.Value = "Confused Strike"
					actionSelected = "Confused Strike"
					targets = {playerTeam[math.random(1,#playerTeam)].Character} --randomly select an ally to hit
					caster = v
					local battleFunctionResult = nil
					task.wait(0.5)
					local success, errorMSG = pcall(function()
						--print("went thru")
						battleFunctionResult = activesModule[actionSelected].battleFunction(targets, caster)  --see line 365 for explanation of this code
					end)
					if not success then
						print("ERROR DURING PLR CONFU ATTACK: " .. errorMSG)
					end

				end--else turn is ended, move on to the next thing
			end
			local success, errorMSG = pcall(playerTurn)
			if not success then
				print("ERROR DURING PLAYER TURN: " .. errorMSG)
			end
		elseif v and v.Name and script.Parent.Fighters:FindFirstChild(v.Name) then
			--initiate NPC, enemy v's turn
			local mobAI = nil

			if v:FindFirstChild("AI") then
				mobAI = require(v.AI)
			elseif v:FindFirstChild("CorruptAI") then --ready to decide what they gonna do
				mobAI = require(v.CorruptAI)
			end
			--corrupt AIs have tweaks to a mob's stats as well as make smarter decisions
			
			local cont = turnOrderModule.turnStart(v, turn, script.CanFlee.Value) --same as line 236, but for mobs
		
			
			if cont == "Continue" then --enemy needs to decide what to do								
				
				local enemyResult = nil --if an enemy's ability returns "again", then he gets multiple turns
				function enemyPlay()
					local originalCFrame = v.PrimaryPart.CFrame --save original position so they can be put back after their ability
					v.SelectedAction.Value = ""
					local mobAbilities = require(mobAttacks:FindFirstChild(v.Zombie.DisplayName.."Attacks"))
					for ii, vv in ipairs(playerTeam) do --display to everyone that someone turn is being taken
						if vv then
							remotes.WhosTurn:FireClient(vv, v.Zombie.DisplayName) 
						end
					end
					mobAI.refreshTeams(playerTeam,enemyTeam) --pass a readable table of players and enemies to the mob currently taking its turn, so it knows what it can and cant target for its abilities
					caster = v
					actionSelected = mobAI.turnAI(turn)
					if not actionSelected or actionSelected == "Nothing" then
						return --no ability chosen, end turn. no possible targets (all players likely had invincible status, leaving no options)
					end
					task.wait(2)
					
					targets = mobAI.passTargets() --targets is now a table of targets passed from mob's AI.
					for ii, vv in ipairs(playerTeam) do --display to everyone that someone turn is done being taken
						if vv and vv:FindFirstChild("PlayerGui") then
							remotes.AttackPopup:FireClient(vv, actionSelected, {nil, mobAbilities[actionSelected].Type}) --pass the type of attack the mob is going to use. no need for popupmods here because enemies dont have passive abilities that can affect their attacks in the same way players do.
						end
					end	
					
					enemyResult = nil
					
					local success, errorMSG = pcall(function()
						enemyResult = mobAbilities[actionSelected].battleFunction(targets, caster)--see like 365 for description of what this does
					end)
					if mobAbilities[actionSelected].Cooldown > 0 and success then 
						local newCooldown = Instance.new("NumberValue")
						newCooldown.Name = actionSelected
						newCooldown.Value = mobAbilities[actionSelected].Cooldown+1 --add 1 bc a 2 cd move would show 1 on ur very next turn otherwise.
						newCooldown.Parent = v.Cooldowns
						if v.Statuses:FindFirstChild("Cold") and not v.Statuses:FindFirstChild("Haste") then
							newCooldown.Value = math.floor(newCooldown.Value*1.5) --cooldowns 50% longer for those inflicted with coldness
						end
						if v.Statuses:FindFirstChild("Haste") and not v.Statuses:FindFirstChild("Cold") then
							newCooldown.Value = math.floor(newCooldown.Value/1.5) --cooldowns shorter for haste
						end
					end
					v.Stats.Energy.Value -= mobAbilities[actionSelected].EnergyCost
					
					if not success then
						print("ERROR FROM ENEMY BATTLE FUNC: " .. errorMSG)
					end
					--player dodging/blocking minigame(s) handled in the battlefunction. 
					v:SetPrimaryPartCFrame(originalCFrame) --for safety
					for indexation, moveEffect in ipairs(v.PrimaryPart:GetChildren()) do
						if moveEffect.Name ~= "Joint" then --during enemy attack, VFX/SFX get parented to primary part. delete all after every turn.
							moveEffect:Destroy()
						end
					end
				end
				
				for integer = 1, v.Stats.Turns.Value, 1 do --some enemies get multiple turns
					task.wait()
					enemyPlay()
				end
				
				if enemyResult and table.find(enemyResult,"Again") then --if the specific ability an enemy used allows them to take another turn, then...
					enemyPlay()
				end
				
				
			elseif cont == "Confused" then--hit self logic
				task.wait(1)
				local originalCFrame = v.PrimaryPart.CFrame
				v.SelectedAction.Value = "Confused Strike"
				local mobAbilities = require(mobAttacks:FindFirstChild(v.Zombie.DisplayName.."Attacks"))
				actionSelected = "Confused Strike"
				targets = {enemyTeam[math.random(1,#enemyTeam)]} --randomly hit an ally
				caster = v
				local battleFunctionResult = nil

				local success, errorMSG = pcall(function()
					--print("went thru")
					battleFunctionResult = mobAbilities[actionSelected].battleFunction(targets, caster)
				end)
				if not success then
					print("ERROR DURING BATTLE SCRIPT: " .. errorMSG)
				end
				v:SetPrimaryPartCFrame(originalCFrame) --for safety
				for indexation, moveEffect in ipairs(v.PrimaryPart:GetChildren()) do
					if moveEffect.Name ~= "Joint" then --during enemy attack, VFX/SFX get parented to primary part. delete all as cleanup after every turn.
						moveEffect:Destroy()
					end
				end
				
			end--else turn is ended, move on to the next thing
		end
	end
	playerTeam, enemyTeam, drops, GoldPot, EXPPot = setupMobsModule.updateTeams(script.Parent.Fighters, drops, GoldPot, EXPPot)
	turnOrderModule.decideTurnOrder(turn,script.Parent.Fighters)
	if truebreak then
		break
	end
end


local finalCoros = {} --a holder for handling multiple functions at onces. we hold them here to close them later
if allPlayersDead == true then --the combat loop was broken by all players being dead, you lost.
	
	for i, v in ipairs(playerTeam) do
		if v then
			v.Character.BuffsDebuffs:ClearAllChildren()--
			v.Character.Statuses:ClearAllChildren()--
			v.Character.Cooldowns:ClearAllChildren()--
			v.Character.Other:ClearAllChildren() --clear all battle modifiers
			v.Character.SelectedAction.Value = ""
			v.Character.Stats.Energy.Value = 0 --reset all things, clean slate for next battle
			v.Character.Humanoid.WalkSpeed = 16
			workspace.PlayerDatas[v.Name].SaveData.InCombat.Value = 0
			game.ReplicatedStorage.MusicSwap:FireClient(v,"Overworld",false)
			v.Character.Parent = workspace
			v.PlayerGui.BattleGui.Enabled = false
			v.PlayerGui.NormalGui.Enabled = true
			v.PlayerGui.BattleGui.BackgroundFrame.Visible = true
			v.Character.HumanoidRootPart.Anchored = false
			
			if v.Character.HumanoidRootPart.BeforeBattleCFrame:GetAttribute("ScriptedBattle") == false then
				game.ServerScriptService.DeathHandler.PlayerDied:Fire(v) --fire signal to a new script, alert them that player v has perished
			end
		end
	end
	
else --the combat loop was broken by the enemy team having 0 enemies left, or all players ran away. you won!
	
	for index, player in ipairs(playerTeam) do
		local coro = coroutine.create(function()
			local success, errorMsg = pcall(function()
				player.PlayerGui.BattleGui.Enabled = true --hide battle UI, show overworld UI
				player.PlayerGui.NormalGui.Enabled = false
				player.PlayerGui.BattleGui.BackgroundFrame.Visible = true
				player.Character.BuffsDebuffs:ClearAllChildren()
				player.Character.Statuses:ClearAllChildren()
				player.Character.Cooldowns:ClearAllChildren()
				player.Character.Other:ClearAllChildren() --clean slate for next battle
				
				player.Character.SelectedAction.Value = ""
				game.ReplicatedStorage.MusicSwap:FireClient(player,"Overworld",false) --swap music
				player.Character.HumanoidRootPart.Anchored = false
				player.Character.Stats.Energy.Value = 0
				workspace.PlayerDatas[player.Name].SaveData.InCombat.Value = 0
				TS:Create(player.PlayerGui.BattleGui.BackgroundFrame, TInfoSec, {BackgroundTransparency = 0}):Play() --transition VFX
				local encounterRegen = player.Character.Stats.MaxHP.Value * (0.4 + soulTreeFuncs.getEncounterRegen(player)) --gain some HP back after battle
				universalActionModule.setHP(player.Character.Stats.CurrentHP, player.Character.Stats.MaxHP, -encounterRegen) --setHP is the mutator method for HP, pass it the player's MaxHP to serve as a clamp
				task.wait(1)
				local encounterSafety = game.ServerStorage.VFX.EncounterSafety:Clone() --with this, encounterScript can read this and know not to give the player a new battle until this tag is gone
				encounterSafety.Control.Enabled = true --lets it delete itself after a set amount of time
				encounterSafety.Parent = player.Character.HumanoidRootPart
				player.Character.Parent = workspace --eject from battle means to remove them from the fighters folder.
				game.ReplicatedStorage.IssueTeleport:FireClient(player, player.Character.HumanoidRootPart.BeforeBattleCFrame.Value) --teleport a player from the battlescene back to the original vector3 position they were in before the battle started
				task.wait(0.5)
				TS:Create(player.PlayerGui.BattleGui.BackgroundFrame, TInfoSec, {BackgroundTransparency = 1}):Play() --transition VFX 
				player.PlayerGui.BattleGui.Enabled = false
				player.PlayerGui.NormalGui.Enabled = true
				player.PlayerGui.BattleGui.BackgroundFrame.Visible = false
				task.wait(0.5)
				local soulTreeRewards = soulTreeFuncs.getRewards(player) --returns multipliers {EXPMult, GoldMult} based on your skill tree upgrades
				player.Character.Humanoid.WalkSpeed = 16
				workspace.PlayerDatas[player.Name].SaveData.Gold.Value += math.round(GoldPot*soulTreeRewards[2])
				workspace.PlayerDatas[player.Name].SaveData.EXP.Value += math.round(EXPPot*soulTreeRewards[1])
				for i, tableOfDropData in ipairs(drops) do --read from the table of drops
					local itemName = tableOfDropData["Name"] --whats the name of the drop?
					local dropChance = tableOfDropData["BaseChance"] --whats the chance (1,1000) that you gain an item between 1000 = 100%, and 1 = 0.1%?
					local minAmount = tableOfDropData["MinAmount"] --whats the minimum amount u can get of this item?
					local maxAmount = tableOfDropData["MaxAmount"] --whats the maximum amount u can get of this item?
					local plrLCK = player.Character.Stats.LCK.Value
					local EffectiveDropRate = dropChance * (1 + (plrLCK / 50) * (dropChance / 100)) --increase the dropchance based on player's LUCK stat
					--check client passives
					if workspace.PlayerDatas[player.Name].SaveData.Passives:FindFirstChild("LuckyDrops") then
						EffectiveDropRate *= 1.2 --increase drop date by 20% if you have the LuckyDrops passive ability
					end
					
					if workspace.PlayerDatas[player.Name].SaveData.Gear1.Value == 24 then --check equipment slots to see if you have treasure bag equipped, increase drop rate if so
						EffectiveDropRate *= 1.5
					elseif workspace.PlayerDatas[player.Name].SaveData.Gear2.Value == 24 then
						EffectiveDropRate *= 1.5
					elseif workspace.PlayerDatas[player.Name].SaveData.Gear3.Value == 24 then
						EffectiveDropRate *= 1.5
					elseif workspace.PlayerDatas[player.Name].SaveData.Gear4.Value == 24 then
						EffectiveDropRate *= 1.5
					end
					
					if math.random(1,1000) <= EffectiveDropRate then --random number determines if you gain the drop or not
						local newItem = nil
						local rr = math.random(minAmount,maxAmount)
						
						if itemName == "Scroll" or itemName == "Scrypt" then --choose random one from a universal pool
							--TODO, HAVENT GOTTEN TO THIS YET
						end
						 
						--if you already have some of itemName in your inventory, just add to the count
						if workspace.PlayerDatas[player.Name].SaveData.Inventory:FindFirstChild(itemName) then
							newItem = workspace.PlayerDatas[player.Name].SaveData.Inventory:FindFirstChild(itemName) --this is the true inventory add, handled ON SERVER
							newItem.Value += rr
						else --else create a new numbervalue to put in your inventory.
							newItem = Instance.new("NumberValue")
							newItem.Name = itemName
							newItem.Value = rr
							newItem.Parent = workspace.PlayerDatas[player.Name].SaveData.Inventory --this is the true inventory add, handled ON SERVER
						end
						for integer = 1, rr, 1 do
							game.ReplicatedStorage.InventoryAdd:FireClient(player, "+"..itemName) --only a visual add for the client to easily see what items they got
						end
					end

				end
			end)
			if not success then
				print("LOOT DROPPING ERROR: " .. errorMsg)
			end
		end)
		table.insert(finalCoros,coro)
		coroutine.resume(coro)
	end
	
end

task.wait(3)
for i, v in ipairs(finalCoros) do
	if v then
		coroutine.close(v)
	end
end
print("battle ended successfully")
script.Parent:Destroy() --remove the playing field
