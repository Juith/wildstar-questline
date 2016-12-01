---------------------------------------------------------------------------------------------------
-- Questline 1.3
--
-- Questline changes the default quest interface to conversational rpg-ish scenes.
--
-- Credits:
-- 
--   * QuestLog, Dialog and CommDisplay: WidlStar built-in addons by Carbine  
--   * UnitedDialogs: Widlstar addon by Jos_eu 
---------------------------------------------------------------------------------------------------

require "Window"
require "DialogSys"
require "Quest"
require "DialogResponse"
require "QuestLib"
require "GameLib"
require "CommunicatorLib"
require "Apollo"
require "MailSystemLib"
require "Sound" 
require "Tooltip"
require "XmlDoc"
require "PlayerPathLib"
require "Unit"
require "CommDialog"
require "WindowLocation"

local Questline = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:NewAddon("Questline", true, {}, "Gemini:Hook-1.0")

local Strings = 
{
	Language   = "English",
	Continue   = "Continue",
	Accept     = "Accept",
	PickTopic  = "Pick a topic",
	PickReward = "Pick a reward"
}

local karEvalColors =
{
	[Item.CodeEnumItemQuality.Inferior]  = ApolloColor.new("ItemQuality_Inferior"),
	[Item.CodeEnumItemQuality.Average]   = ApolloColor.new("ItemQuality_Average"),
	[Item.CodeEnumItemQuality.Good]      = ApolloColor.new("ItemQuality_Good"),
	[Item.CodeEnumItemQuality.Excellent] = ApolloColor.new("ItemQuality_Excellent"),
	[Item.CodeEnumItemQuality.Superb]    = ApolloColor.new("ItemQuality_Superb"),
	[Item.CodeEnumItemQuality.Legendary] = ApolloColor.new("ItemQuality_Legendary"),
	[Item.CodeEnumItemQuality.Artifact]  = ApolloColor.new("ItemQuality_Artifact"),
}

local ktConToUI =
{
	{ "CRB_Basekit:kitFixedProgBar_1", "ff9aaea3", Apollo.GetString("QuestLog_Trivial") },
	{ "CRB_Basekit:kitFixedProgBar_2", "ff37ff00", Apollo.GetString("QuestLog_Easy") },
	{ "CRB_Basekit:kitFixedProgBar_3", "ff46ffff", Apollo.GetString("QuestLog_Simple") },
	{ "CRB_Basekit:kitFixedProgBar_4", "ff3052fc", Apollo.GetString("QuestLog_Standard") },
	{ "CRB_Basekit:kitFixedProgBar_5", "ffffffff", Apollo.GetString("QuestLog_Average") },
	{ "CRB_Basekit:kitFixedProgBar_6", "ffffd400", Apollo.GetString("QuestLog_Moderate") },
	{ "CRB_Basekit:kitFixedProgBar_7", "ffff6a00", Apollo.GetString("QuestLog_Tough") },
	{ "CRB_Basekit:kitFixedProgBar_8", "ffff0000", Apollo.GetString("QuestLog_Hard") },
	{ "CRB_Basekit:kitFixedProgBar_9", "fffb00ff", Apollo.GetString("QuestLog_Impossible") }
}

local HideableHudFroms =
{ -- StockUI
	{ Name = "ChatWindow"            , IsVisible = nil , AutoHide = true },
	{ Name = "InventoryBag"          , IsVisible = nil , AutoHide = true },
	{ Name = "Art"                   , IsVisible = nil , AutoHide = true },
	{ Name = "BaseBarCornerArt"      , IsVisible = nil , AutoHide = true },
	{ Name = "InventoryInvokeForm"   , IsVisible = nil , AutoHide = true },
	{ Name = "Minimap"               , IsVisible = nil , AutoHide = true },
	{ Name = "ObjectiveTrackerForm"  , IsVisible = nil , AutoHide = true },
	{ Name = "ActionBarFrameForm"    , IsVisible = nil , AutoHide = true },
	{ Name = "InterfaceMenuListForm" , IsVisible = nil , AutoHide = true },
	{ Name = "Bar2ButtonContainer"   , IsVisible = nil , AutoHide = true },
	{ Name = "Bar3ButtonContainer"   , IsVisible = nil , AutoHide = true },
	{ Name = "Resources"             , IsVisible = nil , AutoHide = true },
	{ Name = "BaseBarCornerForm"     , IsVisible = nil , AutoHide = true },
	{ Name = "NameplateNew"          , IsVisible = nil , AutoHide = true },
	{ Name = "RecallFrameForm"       , IsVisible = nil , AutoHide = true },
	{ Name = "MountFlyout"           , IsVisible = nil , AutoHide = true },
	{ Name = "CommDisplayForm"       , IsVisible = nil , AutoHide = true },
}

local IsHideableHudFromsUpdated  = false
local kcrDefaultOptionColor      = ApolloColor.new("UI_TextHoloBody")
local kcrHighlightOptionColor    = ApolloColor.new("UI_TextHoloBodyHighlight")
local kstrRewardColor            = "UI_TextHoloTitle "
local kstrVendorColor            = "UI_BtnTextHoloListNormal"
local kstrGoodbyeColor           = "UI_TextHoloBody"
local kcrMoreInfoColor           = "UI_TextHoloBody"
local kcrDefaultColor            = ApolloColor.new("UI_BtnTextHoloListNormal")
local knMaxRewardItemsShown      = 4
local DrakenTargetModelLoaded    = false
local IsInScene                  = false
local IsDebugMode                = true
local DebugData                  = {}

--
-- Addons stuff
--

function Questline:OnSave(level)
	if level ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return nil
	end

	local save = {}

	return save
end

function Questline:OnRestore(level, data)
	if level ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return nil
	end
end

function Questline:Debug(key, val)
	if IsDebugMode then
		if (key == nil or key == '') then
			return
		end

		local message = key

		if val ~= nil then
			message = key .. " : " .. val

			table.insert(DebugData, {key = key, val = val})
		end

		Print("-- Questline: " .. message)
	end
end

function Questline:RestoreAfterPause()
	GameLib.PauseGameActionInput(false)
end

function Questline:OnInitialize() 
	self.xmlDoc = XmlDoc.CreateFromFile("Questline.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", Questline)
end

function Questline:OnDocumentReady() 
	if  self.xmlDoc == nil then
		return
	end

	-- Detect language
	if(Apollo.GetString(1) == "Annuler") then
		Strings = {
			Language   = "French",
			Continue   = "Continuer",
			Accept     = "Accepter",
			PickTopic  = "Choisissez un sujet",
			PickReward = "Choisissez votre récompense"
		}
	elseif(Apollo.GetString(1) == "Abbrechen") then
		Strings = {
			Language   = "German",
			Continue   = "Fortsetzen",
			Accept     = "Akzeptieren",
			PickTopic  = "Wählen Sie ein Thema",
			PickReward = "Wählen Sie Ihre Belohnung"
		}
	end

	Apollo.LoadSprites("UI\\Dialog\\DialogSprites.xml") -- Old
	Apollo.RegisterEventHandler("Dialog_ShowState", "OnDialog_ShowState", self)
	Apollo.RegisterEventHandler("Dialog_Close", "OnDialog_Close", self)
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", "OnTutorial_RequestUIAnchor", self)

	self.wndMainOne = Apollo.LoadForm(self.xmlDoc, "QuestWindow", nil, self)

	self.wndPlayer = self.wndMainOne:FindChild("PlayerWindow")
	self.wndPlayer:ToFront()
	self.nWndPlayerLeft, self.nWndPlayerTop, self.nWndPlayerRight, self.nWndPlayerBottom = self.wndPlayer:GetAnchorOffsets()
	self.wndPlayer:Show(false, true)

	-- QuestGiverName
	local unitPlayer = GameLib.GetPlayerUnit()

	self.wndMainOne:SetScale(0.01) 
	self.wndMainOne:Show(true)

	self.bRewardPicked = false

	self.timerUpdateNPCAO = ApolloTimer.Create(6, true, "OnUpdateTimerNPCAO", self)
	self.timerUpdateNPCAO:Stop()

	self.timerUpdatePlayerAO = ApolloTimer.Create(6, true, "OnUpdateTimerPlayerAO", self)
	self.timerUpdatePlayerAO:Stop()

	self.wndMainOne:FindChild("QuestTargetPortrait"):SetCostumeToCreatureId(32864)
	self.wndMainOne:FindChild("QuestTargetPortrait"):SetSpin(-35)
	self.wndMainOne:FindChild("QuestTargetPortrait"):SetModelSequence(7755) 

	self.wndMainOne:FindChild("QuestPlayerPortrait"):SetCostumeToCreatureId(32853)
	self.wndMainOne:FindChild("QuestPlayerPortrait"):SetSpin(35)
	self.wndMainOne:FindChild("QuestPlayerPortrait"):SetModelSequence(7723)

	self.QuestGiverName = ""
	self.QuestGiverId = 0
	self.QuestSeenMoreInfo = {}
	
	self.wndMainOne:FindChild("QuestDetailsContainer"):Show(false)

	-- Measure Windows 
	local wndMeasure = Apollo.LoadForm(self.xmlDoc, "ObjectivesItem", nil, self)
	self.knObjectivesItemHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	local QuestDialog = self.wndMainOne:FindChild("QuestDetailsForm")
	
	self.nRewardRecListHeight = QuestDialog:FindChild("QuestInfoRewardRecFrame"):GetHeight()
	self.nRewardChoListHeight = QuestDialog:FindChild("QuestInfoRewardChoFrame"):GetHeight()
	self.nSummaryContainer    = QuestDialog:FindChild("SummaryContainer"):GetHeight()

	Questline:Compatibilitize()

	Apollo.RegisterEventHandler("SystemKeyDown", "OnSystemKeyDown", self)	
end

function Questline:OnSystemKeyDown(key)
	if IsInScene == false
	or not self.wndMainOne
	then
		return
	end

	local btn = self.wndMainOne:FindChild("GoodbyeBtn")

	if btn then
		self:OnResponseGoodbyeBtnClick(btn, btn)
	end
end

--
-- Compatibility stuff. I'm pretty sure I'll regret this at some point, but meh.. worth.
--

function Questline:Compatibilitize() -- let make this a word.
	-- StockUi TargetFrame
	local TargetFrame = Apollo.GetAddon("TargetFrame")

	if TargetFrame then
		self:PostHook(TargetFrame, "OnFrame")
	end

	-- Perspective
	local Perspective = Apollo.GetAddon("Perspective")

	if Perspective then
		Perspective = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:GetAddon("Perspective")

		if Perspective then
			self:PostHook(Perspective, "OnNextFrame")
		end
	end

	-- Jita
	local Jita = Apollo.GetAddon("Jita")

	if Jita then
		table.insert(HideableHudFroms, { Name = "JCC_ChatWindow", IsVisible = nil , AutoHide = true })
	end

	-- ForgeUI
	local ForgeUI = Apollo.GetAddon("ForgeUI")

	if ForgeUI then
		table.insert(HideableHudFroms, { Name = "ForgeUI_Overlay"       , IsVisible = nil , AutoHide = true })
		table.insert(HideableHudFroms, { Name = "ForgeUI_Bar"           , IsVisible = nil , AutoHide = true })
		table.insert(HideableHudFroms, { Name = "ForgeUI_InfoBar"       , IsVisible = nil , AutoHide = true })
		table.insert(HideableHudFroms, { Name = "ForgeUI_Form"          , IsVisible = nil , AutoHide = true })
		table.insert(HideableHudFroms, { Name = "ForgeUI_InterfacesForm", IsVisible = nil , AutoHide = true })

		table.insert(HideableHudFroms, { Name = "ForgeUI_PlayerFrame"   , IsVisible = nil , AutoHide = true })
		table.insert(HideableHudFroms, { Name = "ForgeUI_TargetFrame"   , IsVisible = nil , AutoHide = true })
		table.insert(HideableHudFroms, { Name = "ForgeUI_ToTFrame"      , IsVisible = nil , AutoHide = true })
		table.insert(HideableHudFroms, { Name = "ForgeUI_FocusFrame"    , IsVisible = nil , AutoHide = true })
	end

	-- LUI_Frames
	local LUI_Frames = Apollo.GetAddon("LUI_Frames")

	if LUI_Frames then
		table.insert(HideableHudFroms, { Name = "LUI_Frames" , IsVisible = nil , AutoHide = true })
		table.insert(HideableHudFroms, { Name = "LUI_Infobar", IsVisible = nil , AutoHide = true })
		table.insert(HideableHudFroms, { Name = "LUI_Menubar", IsVisible = nil , AutoHide = true })
	end

	-- LUI_Aura 
	local LUI_Aura = Apollo.GetAddon("LUI_Aura")

	if LUI_Aura then
		table.insert(HideableHudFroms, { Name = "LUIGroup"     , IsVisible = nil , AutoHide = true })
		table.insert(HideableHudFroms, { Name = "LUIGroupFixed", IsVisible = nil , AutoHide = true })
		table.insert(HideableHudFroms, { Name = "LUIAura"      , IsVisible = nil , AutoHide = true })
		table.insert(HideableHudFroms, { Name = "LUIAuraFixed" , IsVisible = nil , AutoHide = true })
	end

	-- CandyBars. meh, can't be damned to used spacenames.
	-- local CandyBars = Apollo.GetAddon("CandyBars")

	-- if CandyBars then
		-- table.insert(HideableHudFroms, { Name = "ActionBarForm"   , IsVisible = nil , AutoHide = true })
		-- table.insert(HideableHudFroms, { Name = "SecondaryBarForm", IsVisible = nil , AutoHide = true })
		-- table.insert(HideableHudFroms, { Name = "UtilityBarForm"  , IsVisible = nil , AutoHide = true })
		-- table.insert(HideableHudFroms, { Name = "ShortcutBar"     , IsVisible = nil , AutoHide = true })
	-- end

	-- DarkMeter 
	local DarkMeter = Apollo.GetAddon("DarkMeter")

	if DarkMeter then
		table.insert(HideableHudFroms, { Name = "DarkMeterForm", IsVisible = nil , AutoHide = true })
	end

	-- SimpleQuestTracker 
	local SimpleQuestTracker = Apollo.GetAddon("SimpleQuestTracker")

	if SimpleQuestTracker then
		table.insert(HideableHudFroms, { Name = "SimpleQuestTrackerForm", IsVisible = nil , AutoHide = true })
	end

	-- Killroy 
	local Killroy = Apollo.GetAddon("Killroy")

	if Killroy then
		table.insert(HideableHudFroms, { Name = "KillroyForm", IsVisible = nil , AutoHide = true })
	end

	-- KuronaBags
	local KuronaBags = Apollo.GetAddon("KuronaBags")

	if KuronaBags then
		table.insert(HideableHudFroms, { Name = "MainBagForm", IsVisible = nil , AutoHide = true })
	end
                                                                
	-- Arcompass                                                            
	local Arcompass = Apollo.GetAddon("Arcompass")

	if Arcompass then
		table.insert(HideableHudFroms, { Name = "Arcompass", IsVisible = nil , AutoHide = true })
	end

	-- Revolver
	local Revolver = Apollo.GetAddon("Revolver")

	if Revolver then
		table.insert(HideableHudFroms, { Name = "RevolverMain"   , IsVisible = nil , AutoHide = true })
		table.insert(HideableHudFroms, { Name = "RevolverButtons", IsVisible = nil , AutoHide = true })
		table.insert(HideableHudFroms, { Name = "RevolverForm"   , IsVisible = nil , AutoHide = true })
	end

	-- KuronaPets
	local KuronaPets = Apollo.GetAddon("KuronaPets")

	if KuronaPets then
		table.insert(HideableHudFroms, { Name = "KuronaPetsForm", IsVisible = nil , AutoHide = true })
		table.insert(HideableHudFroms, { Name = "PetFlyout"     , IsVisible = nil , AutoHide = true })
	end

	-- NearbyPlayers
	local NearbyPlayers = Apollo.GetAddon("NearbyPlayers")

	if NearbyPlayers then
		table.insert(HideableHudFroms, { Name = "NearbyPlayersForm", IsVisible = nil , AutoHide = true })
	end

	-- GuardMiniMap
	local GuardMiniMap = Apollo.GetAddon("GuardMiniMap")

	if GuardMiniMap then
		table.insert(HideableHudFroms, { Name = "SquareMinimap", IsVisible = nil , AutoHide = true })
	end

	-- Disable CommDisplay for quests
	local CommDisplay = Apollo.GetAddon("CommDisplay")

	if CommDisplay then
		function CommDisplay:OnCommunicator_ShowQueuedMsg(tMessage)
			if tMessage == nil then
				return
			end

			if tMessage.strType == "Quest" then
				return
			end

			if tMessage.strType == "Spam" then
				local knDefaultWidth  = 500
				local knDefaultHeight = 173

				CommDisplay:OnShowCommDisplay()

				if CommunicatorLib.PlaySpamVO(tMessage.idMsg) then
					-- if we can play a real VO, then wait for the signal that that VO ended
					CommDisplay.wndMain:SetAnimElapsedTime(9.0)
					CommDisplay.wndMain:PauseAnim()
					Sound.Play(Sound.PlayUIDatachronSpam)
				else
					CommDisplay.wndMain:PlayAnim(0)
					Sound.Play(Sound.PlayUIDatachronSpamNoVO)
				end

				CommDisplay.wndCommPortraitLeft:PlayTalkSequence()
				CommDisplay.wndCommPortraitRight:PlayTalkSequence()
			
				local tOffsets = {CommDisplay.wndMain:GetAnchorOffsets()}
				CommDisplay.tDefaultOffsets = {tOffsets[1], tOffsets[2], tOffsets[1] + knDefaultWidth, tOffsets[2] + knDefaultHeight}
			
				CommDisplay.wndMain:FindChild("CloseBtn"):Show(true)
				CommDisplay:DrawText(tMessage.strMessageText, "", true, tMessage.tLayout, tMessage.idCreature, nil, nil) -- 2nd argument: bIsCommCall
			end
		end
	end
end

function Questline:OnFrame(luaCaller)
	local TargetFrame = Apollo.GetAddon("TargetFrame")

	-- TargetFrame is a .. pain.
	if IsInScene == true then
		TargetFrame.luaUnitFrame.wndMainClusterFrame:Show(false)
		TargetFrame.luaTargetFrame.wndMainClusterFrame:Show(false)
		TargetFrame.luaFocusFrame.wndMainClusterFrame:Show(false)

		TargetFrame.luaUnitFrame.wndMainClusterFrame:SetScale(0.01)
		TargetFrame.luaTargetFrame.wndMainClusterFrame:SetScale(0.01)
		TargetFrame.luaFocusFrame.wndMainClusterFrame:SetScale(0.01)
	else
		TargetFrame.luaUnitFrame.wndMainClusterFrame:SetScale(1.0)
		TargetFrame.luaTargetFrame.wndMainClusterFrame:SetScale(1.0)
		TargetFrame.luaFocusFrame.wndMainClusterFrame:SetScale(1.0)
	end
end

function Questline:OnNextFrame(luaCaller)
	if IsInScene == false then
		return
	end

	local Perspective = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:GetAddon("Perspective")

	if Perspective then
		Perspective.Overlay:DestroyAllPixies()
	end
end

--
-- Timers
--

function Questline:OnUpdateTimerNPCAO(strVarName, nCount) 
	if self.wndMainOne ~= nil then
		if self.wndMainOne:FindChild("QuestTargetPortrait") ~= nil then
			self.wndMainOne:FindChild("QuestTargetPortrait"):SetModelSequence(150) 
		end	
	end

	self.timerUpdateNPCAO:Stop()
end

function Questline:OnUpdateTimerPlayerAO(strVarName, nCount) 
	if self.wndMainOne ~= nil then
		if self.wndMainOne:FindChild("QuestPlayerPortrait") ~= nil then
			self.wndMainOne:FindChild("QuestPlayerPortrait"):SetModelSequence(150) 
		end	
	end

	self.timerUpdatePlayerAO:Stop()
end

--
-- UI
--

function Questline:OnTargetModelLoaded( wndHandler, wndControl )
	if DrakenTargetModelLoaded == true then
		return
	end

	if IsInScene == false then
		self.wndMainOne:Show(false)
	end

	ChatSystemLib.PostOnChannel(2, "Questline loaded.")

	DrakenTargetModelLoaded = true
end

function Questline:OnDialog_ShowState(eState, queCurrent)
	IsInScene = true

	if DrakenTargetModelLoaded == false then
		ChatSystemLib.PostOnChannel(2, "Questline is still loading.. ")
	end

	-- Update visible default uis
	if IsHideableHudFromsUpdated == false then
		for _, data in pairs(HideableHudFroms) do
			if data.AutoHide == true then
				if Apollo.FindWindowByName(data.Name) ~= nil then
					if Apollo.FindWindowByName(data.Name):IsShown() then
						HideableHudFroms[_].IsVisible = true  

						Apollo.FindWindowByName(data.Name):Show(false)
					else
						HideableHudFroms[_].IsVisible = false
					end
				end
			end
		end

		IsHideableHudFromsUpdated = true
	end

	self.wndMainOne:SetScale(1.0)
 
	local idQuest = 0
	if queCurrent and queCurrent:GetId() then
		idQuest = queCurrent:GetId()
		self.wndMainOne:FindChild("QuestTitle"):SetText( queCurrent:GetTitle() )
		self.wndMainOne:FindChild("QuestTitle"):Show(true)
	else
		self.wndMainOne:FindChild("QuestTitle"):Show(false)
	end

	self.bRewardPicked = false

	if eState == DialogSys.DialogState_Inactive or
		eState == DialogSys.DialogState_Vending or
		eState == DialogSys.DialogState_Training or
		eState == DialogSys.DialogState_TradeskillTraining or
		eState == DialogSys.DialogState_CraftingStation then

		self:OnDialog_Close() -- Close if they click vending/training, as we open another window

		return
	end


	-- Player Window
	local tResponseList = DialogSys.GetResponses(idQuest)

	if not tResponseList or #tResponseList == 0 then
		self:OnDialog_Close()

		return
	end
	
	self.QuestGiverName = "N.A."

	-- QuestGiverName
	local unitPlayer = GameLib.GetPlayerUnit()
	
	self.wndMainOne:FindChild("QuestPlayerPortrait"):SetCostume(unitPlayer)

	local unitNpc = DialogSys.GetNPC()

	if  unitNpc and unitNpc:GetId() then 
		self.QuestGiverName = unitNpc:GetName()
		self.wndMainOne:FindChild("QuestTargetPortrait"):SetCostume(unitNpc)
	else
		if queCurrent and queCurrent:GetContactInfo() then
			local contactInfo  = queCurrent:GetContactInfo()
			local contactId    = contactInfo.idUnit
			local contactName  = Creature_GetName(contactId)

			if self.QuestGiverName ~= contactName then
				if self.QuestGiverId ~= contactId then
					self.QuestGiverId = contactId 
					self.wndMainOne:FindChild("QuestTargetPortrait"):SetCostumeToCreatureId(self.QuestGiverId)
				end
				self.QuestGiverName = Creature_GetName(contactId)
			end
		else
			local unitTarget = unitPlayer:GetTarget()

			if unitTarget then
				local targetName = unitTarget:GetName()
				
				if self.QuestGiverName ~= targetName then 
					self.wndMainOne:FindChild("QuestTargetPortrait"):SetCostume(unitTarget)
					self.QuestGiverName = targetName
				end
			end
		end
	end

	self.QuestShowMoreInfo = false
	self.QuestPickTopic    = false

	self:DrawSceneModels()
	self:DrawSceneDialog(eState, idQuest)
	self:DrawSceneResponses(eState, idQuest, tResponseList)

	-- NPC Window or Item Window when it's not a comm call
	if DialogSys.GetNPC() and not DialogSys.IsItemQuestGiver() and DialogSys.GetCommCreatureId() == nil then
		-- Print("IsCreature")
	elseif DialogSys.GetCommCreatureId() == nil then
		-- Print("IsItem")

		if not DialogSys.IsItemQuestGiver() then
			self.QuestGiverName = "Inventory Item"
			self.wndMainOne:FindChild("QuestGiverName"):SetText(self.QuestGiverName)
			self.wndMainOne:FindChild("QuestTargetPortrait"):SetCostume(nil)
		end

		if eState == 1 then
			self.wndMainOne:FindChild("PickTopicOrRewardTitle"):Show(true)
			self.wndMainOne:FindChild("PickTopicOrRewardTitle"):SetText(Strings.PickTopic)
			self.wndMainOne:FindChild("DialogContainer"):Show(false)
			self.wndPlayer:SetSprite("Dialog:sprHolo_Speech_Item")
			self.wndPlayer:SetScale(1.0)
			self.wndPlayer:Invoke()
		end
	end

	self.wndMainOne:Show(true)
end

function Questline:OnDialog_Close()  
	-- Show default ui
	for _, data in pairs(HideableHudFroms) do
		if Apollo.FindWindowByName(data.Name) then
			if data.IsVisible == true then
				Apollo.FindWindowByName(data.Name):Show(true)
			end
		end
	end

	IsHideableHudFromsUpdated = false

	self.wndPlayer:Close() 

	self.QuestGiverName = ""
	self.QuestGiverId = 0
	self.QuestSeenMoreInfo = {}

	self.wndMainOne:FindChild("ContinuePlayerContainer"):Show(false)
	self.wndMainOne:FindChild("ContinueNPCContainer"):Show(false)
	self.wndMainOne:FindChild("AcceptContainer"):Show(false)

	self.wndMainOne:Show(false)

	self.wndMainOne:FindChild("QuestTargetPortrait"):SetCostumeToCreatureId(32864)
	self.wndMainOne:FindChild("QuestTargetPortrait"):SetSpin(-35)
	self.wndMainOne:FindChild("QuestTargetPortrait"):SetModelSequence(7755) 

	self.wndMainOne:FindChild("QuestPlayerPortrait"):SetCostumeToCreatureId(32853)
	self.wndMainOne:FindChild("QuestPlayerPortrait"):SetSpin(35)
	self.wndMainOne:FindChild("QuestPlayerPortrait"):SetModelSequence(7723)

	IsInScene = false
end

function Questline:OnWindowClosed(wndHandler, wndControl) -- The 'esc' key from xml
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end

	DialogSys.End()
end

function Questline:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	local tAnchors =
	{
		[GameLib.CodeEnumTutorialAnchor.QuestIntroduction] = true,
		[GameLib.CodeEnumTutorialAnchor.QuestAccept]       = true,
	}

	if not tAnchors[eAnchor] or not self.wndPlayer then
		return
	end

	if not self.wndPlayer:FindChild("ResponseItemBtn") then
		self.tPendingTutorialData = {eAnchor = eAnchor, idTutorial = idTutorial, strPopupText = strPopupText}
	else	
		local tAnchorMapping = 
		{
			[GameLib.CodeEnumTutorialAnchor.QuestIntroduction] = self.wndPlayer:FindChild("ResponseItemBtn"),
			[GameLib.CodeEnumTutorialAnchor.QuestAccept]       = self.wndPlayer:FindChild("ResponseItemBtn"),
		}

		if tAnchorMapping[eAnchor] then
			Event_FireGenericEvent("Tutorial_ShowCallout", eAnchor, idTutorial, strPopupText, tAnchorMapping[eAnchor])
		end
	end
end

--

function Questline:DrawSceneModels()
	local unitPlayer = GameLib.GetPlayerUnit()

	self.wndMainOne:FindChild("QuestPlayerPortrait"):SetCostume(unitPlayer)
	self.wndMainOne:FindChild("QuestPlayerPortrait"):SetCamera("Paperdoll")
	self.wndMainOne:FindChild("QuestPlayerPortrait"):SetSpin(35)
	self.wndMainOne:FindChild("QuestPlayerPortrait"):SetSheathed(true)
	self.wndMainOne:FindChild("QuestPlayerPortrait"):SetModelSequence(150)

	self.wndMainOne:FindChild("QuestTargetPortrait"):SetCamera("Paperdoll")
	self.wndMainOne:FindChild("QuestTargetPortrait"):SetSpin(-35)
	self.wndMainOne:FindChild("QuestTargetPortrait"):SetSheathed(true)
	self.wndMainOne:FindChild("QuestTargetPortrait"):PlayTalkSequence()

	self.timerUpdatePlayerAO:Stop()
	self.timerUpdateNPCAO:Stop()
	self.timerUpdateNPCAO:Start()
end

function Questline:DrawSceneDialog(eState, idQuest)
	-- Text
	local cdDialog = DialogSys.GetNPCText(idQuest)

	if cdDialog == nil then
		return
	end

	local strText = cdDialog:GetText()

	if not strText or Apollo.StringLength(strText) == 0 then
		return
	end

	self.wndMainOne:FindChild("QuestGiverName"):SetText(self.QuestGiverName)
	self.wndMainOne:FindChild("DialogBox"):SetAML("<P Font=\"CRB_HeaderLarge\" Valign=\"CENTER\" >"..strText.."</P>")
	self.wndMainOne:FindChild("DialogBox"):SetVScrollPos(0)

	if cdDialog:HasVO() then
		cdDialog:PlayVO()
	end 
end

function Questline:DrawSceneResponses(eState, idQuest, tResponseList) 
	self.wndMainOne:FindChild("QuestDetailsContainer"):Show(false)

	self.wndPlayer:FindChild("ResponseItemContainer"):DestroyChildren()
	self.wndMainOne:FindChild("GoodbyeContainer"):Show(false)
	self.wndPlayer:FindChild("VendorContainer"):Show(false)
	self.wndPlayer:FindChild("TopSummaryText"):Show(false)
	self.wndPlayer:FindChild("QuestTaskText"):Show(false)
	
	self.wndMainOne:FindChild("ContinuePlayerContainer"):Show(false)
	self.wndMainOne:FindChild("ContinueNPCContainer"):Show(false)
	self.wndMainOne:FindChild("AcceptContainer"):Show(false)
	self.wndMainOne:FindChild("PickTopicContainer"):Show(false)
	self.wndMainOne:FindChild("PickRewardContainer"):Show(false)
	self.wndMainOne:FindChild("PickTopicOrRewardTitle"):Show(false)

	local nOnGoingHeight = 0

	-- Top Summary Text (only shows up for quests and if there are rewards)
	local queCurr = DialogSys.GetViewableQuest(idQuest)
	local strTopResponseText = DialogSys.GetResponseText()

	if queCurr and queCurr:GetRewardData() and #queCurr:GetRewardData() > 0 and strTopResponseText and Apollo.StringLength(strTopResponseText) > 0 then
		self.wndPlayer:FindChild("TopSummaryText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\""..kstrRewardColor.."\">"..strTopResponseText.."</P>")
		self.wndPlayer:FindChild("TopSummaryText"):SetHeightToContentHeight()
		self.wndPlayer:FindChild("TopSummaryText"):Show(true)
		local nLeft, nTop, nRight, nBottom = self.wndPlayer:FindChild("TopSummaryText"):GetAnchorOffsets()
		self.wndPlayer:FindChild("TopSummaryText"):SetAnchorOffsets(nLeft, nTop, nRight, nBottom + 8) -- TODO: Hardcoded!  -- +8 is bottom padding
		nOnGoingHeight = nOnGoingHeight + (nBottom - nTop) + 8
	end
 
	local ShowMoreInfo = true
	local ShowPickTopic = true
	local tQuestAccept = true
	local hidePlayerCtl = false

	local nQuestCompleteItems = 0

	-- Rest of Responses
	local nResponseHeight = 0
	for idx, drResponse in ipairs(tResponseList) do
		local eResponseType = drResponse:GetType()
		local wndCurr = nil
		if eResponseType == DialogResponse.DialogResponseType_ViewVending then

			wndCurr = self.wndPlayer:FindChild("VendorContainer")
			wndCurr:FindChild("VendorText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\""..kstrVendorColor.."\">"..drResponse:GetText().."</P>")
			wndCurr:FindChild("VendorIcon"):SetSprite(self:HelperComputeIconPath(eResponseType))
			wndCurr:FindChild("VendorBtn"):SetData(drResponse)
			wndCurr:Show(true)
			nOnGoingHeight = nOnGoingHeight + self.wndPlayer:FindChild("VendorContainer"):GetHeight()

		elseif eResponseType == DialogResponse.DialogResponseType_Goodbye then

			wndCurr = self.wndMainOne:FindChild("GoodbyeContainer")
			wndCurr:FindChild("GoodbyeText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\""..kstrGoodbyeColor.."\">"..drResponse:GetText().."</P>")
			wndCurr:FindChild("GoodbyeIcon"):SetSprite(self:HelperComputeIconPath(eResponseType))
			self.wndMainOne:FindChild("CloseBtn"):SetData(drResponse)
			wndCurr:FindChild("GoodbyeBtn"):SetData(drResponse)
			wndCurr:Show(true)

		elseif eResponseType == DialogResponse.DialogResponseType_QuestComplete then 
			wndCurr = Apollo.LoadForm(self.xmlDoc, "ResponseSelectRewardItem", self.wndPlayer:FindChild("ResponseItemContainer"), self)
			self:HelperComputeRewardIcon(wndCurr, drResponse:GetRewardId(), queCurr:GetRewardData().arRewardChoices)
			wndCurr:FindChild("ResponseItemText"):SetData(drResponse:GetText())
			wndCurr:FindChild("ResponseItemText"):SetText(drResponse:GetText())
			wndCurr:FindChild("ResponseItemText"):SetFont("CRB_InterfaceMedium")
			wndCurr:FindChild("ResponseItemText"):SetTextColor(self:HelperComputeRewardTextColor(drResponse:GetRewardId(), DialogSys.GetViewableQuest(idQuest):GetRewardData()))
			wndCurr:FindChild("ResponseItemBtn"):SetData(drResponse)
			nResponseHeight = nResponseHeight + wndCurr:GetHeight()

			wndCurr = self.wndMainOne:FindChild("AcceptContainer")
			wndCurr:FindChild("AcceptText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\"ff7fffb9\">" .. drResponse:GetText() .. "</P>")
			wndCurr:FindChild("AcceptIcon"):SetSprite(self:HelperComputeIconPath(eResponseType))
			wndCurr:FindChild("AcceptBtn"):SetData(drResponse)
			wndCurr:Show(true)

			nQuestCompleteItems = nQuestCompleteItems + 1
		else 
			if eResponseType == DialogResponse.DialogResponseType_QuestMoreInfo then 
				if ShowMoreInfo == true then
					if Questline:IsSeenMoreInfo(drResponse:GetQuestId(), drResponse) == false then
						self.wndMainOne:FindChild("AcceptContainer"):Show(false)
						
						ShowMoreInfo = false
						tQuestAccept = false

						wndCurr = self.wndMainOne:FindChild("ContinuePlayerContainer") 
						wndCurr:FindChild("ContinueText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\"ffffffff\">" .. Strings.Continue .. "</P>")
						wndCurr:FindChild("ContinueIcon"):SetSprite(self:HelperComputeIconPath(eResponseType))
						wndCurr:FindChild("ContinueBtn"):SetData(drResponse)
						wndCurr:Show(true)
						hidePlayerCtl = true
					end
				end
			else
				if eResponseType == DialogResponse.DialogResponseType_QuestAccept then
					if tQuestAccept == true then  
						wndCurr = self.wndMainOne:FindChild("AcceptContainer")
						wndCurr:FindChild("AcceptText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\"ff7fffb9\">" .. drResponse:GetText() .. "</P>")
						wndCurr:FindChild("AcceptIcon"):SetSprite(self:HelperComputeIconPath(eResponseType))
						wndCurr:FindChild("AcceptBtn"):SetData(drResponse)
						wndCurr:Show(true)
						hidePlayerCtl = true
					end
				else
					local queResponse = DialogSys.GetViewableQuest(drResponse:GetQuestId())
					local nConLevel = queResponse and queResponse:GetTitle() == drResponse:GetText() and queResponse:GetConLevel() or 0
					local strText = nConLevel > 0 and string.format("%s (%s)", drResponse:GetText(), nConLevel) or drResponse:GetText()
					
					local crTextColor = eResponseType == DialogResponse.DialogResponseType_QuestMoreInfo and kcrMoreInfoColor or kcrDefaultColor
					wndCurr = Apollo.LoadForm(self.xmlDoc, "ResponseItem", self.wndPlayer:FindChild("ResponseItemContainer"), self)
					wndCurr:FindChild("ResponseItemIcon"):SetSprite(self:HelperComputeIconPath(eResponseType))
					wndCurr:FindChild("ResponseItemText"):SetText(strText)
					wndCurr:FindChild("ResponseItemText"):SetFont("CRB_InterfaceMedium")
					wndCurr:FindChild("ResponseItemText"):SetTextColor(crTextColor)
					wndCurr:FindChild("ResponseItemBtn"):SetData(drResponse)
					nResponseHeight = nResponseHeight + wndCurr:GetHeight()
				end
			end
		end
	end
	self.wndPlayer:FindChild("ResponseItemContainer"):ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop, function(a,b) return b:FindChild("ResponseItemCantUse"):IsShown() end)

	local nLeft, nTop, nRight, nBottom = self.wndPlayer:FindChild("ResponseItemContainer"):GetAnchorOffsets()
	self.wndPlayer:FindChild("ResponseItemContainer"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nResponseHeight)

	self.wndPlayer:FindChild("PlayerWindowContainer"):ArrangeChildrenVert()

	Event_FireGenericEvent("Test_MouseReturnSignal") -- TODO: possibly remove

	if eState == DialogSys.DialogState_TopicChoice then
		wndCurr = self.wndMainOne:FindChild("PickTopicContainer")
		wndCurr:FindChild("PickTopicText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\"ffffffff\">" .. Strings.PickTopic .. "</P>")
		wndCurr:FindChild("PickTopicIcon"):SetSprite( self:HelperComputeIconPath( DialogResponse.DialogResponseType_ViewQuestAccept ) )
		wndCurr:Show(true)

		wndCurr = self.wndMainOne:FindChild("PickTopicOrRewardTitle")
		wndCurr:SetText(Strings.PickTopic) 
	end

	local rHeight = self.wndPlayer:FindChild("RewardsContainer"):GetHeight()
	self.wndPlayer:SetAnchorOffsets(self.nWndPlayerLeft, self.nWndPlayerTop, self.nWndPlayerRight, self.nWndPlayerBottom + nOnGoingHeight + nResponseHeight - 76)

	self.wndPlayer:SetSprite("")

	if self.tPendingTutorialData then
		Event_FireGenericEvent("Tutorial_ShowCallout", self.tPendingTutorialData.eAnchor, self.tPendingTutorialData.idTutorial, self.tPendingTutorialData.strPopupText, self.wndPlayer:FindChild("ResponseItemBtn"))

		self.tPendingTutorialData = nil
	end

	if nQuestCompleteItems > 1 then
		wndCurr = self.wndMainOne:FindChild("AcceptContainer")
		wndCurr:Show(false)

		wndCurr = self.wndMainOne:FindChild("PickRewardContainer")
		wndCurr:FindChild("PickRewardText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\"ff7fffb9\">" .. Strings.PickReward .. "</P>")
		wndCurr:FindChild("PickRewardIcon"):SetSprite( "IconSprites:Icon_Windows32_UI_CRB_InterfaceMenu_Gift" )
		wndCurr:Show(true)
	end

	self.wndPlayer:SetScale(0.01)

	if queCurr ~= nil then	 
		self:DrawQuestDetails(eState, queCurr, idQuest, tResponseList)
	end
end

function Questline:DrawQuestDetails(state, quest, questId, questResponses)
	-- If quest selected, show its info
	if not quest then 
		return
	end

	local QuestDialog = self.wndMainOne:FindChild("QuestDetailsForm")
	
	if not QuestDialog then 
		return
	end

	local eQuestState = state

	-- Difficulty
	local tConData = ktConToUI[quest:GetColoredDifficulty() or 1]
	QuestDialog:FindChild("QuestInfoDifficultyPic"):SetSprite(tConData[1])
	QuestDialog:FindChild("QuestInfoDifficultyPic"):SetTooltip(String_GetWeaselString(Apollo.GetString("QuestLog_Difficulty"), tConData[3])..". "..String_GetWeaselString(Apollo.GetString("QuestLog_IntendedLevel"), quest:GetTitle(), quest:GetConLevel()))

	QuestDialog:FindChild("Difficulty"):Show(true) 

	-- Objectives
	QuestDialog:FindChild("QuestInfoObjectivesList"):DestroyChildren()

	if eQuestState == Quest.QuestState_Achieved then
		local wndObj = Apollo.LoadForm(self.xmlDoc, "ObjectivesItem", QuestDialog:FindChild("QuestInfoObjectivesList"), self)
		local strAchieved = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"UI_TextHoloBody\">%s</T>", quest:GetCompletionObjectiveText())

		wndObj:FindChild("ObjectivesItemText"):SetAML(strAchieved)
		QuestDialog:FindChild("QuestInfoObjectivesTitle"):SetText(Apollo.GetString("QuestLog_ReadyToTurnIn"))
	elseif eQuestState == Quest.QuestState_Completed then
		for key, tObjData in pairs(quest:GetVisibleObjectiveData()) do
			if tObjData.nCompleted < tObjData.nNeeded then
				local wndObj = Apollo.LoadForm(self.xmlDoc, "ObjectivesItem", QuestDialog:FindChild("QuestInfoObjectivesList"), self)
				wndObj:FindChild("ObjectivesItemText"):SetAML(self:HelperBuildObjectiveTitleString(quest, tObjData))
			end
		end

		QuestDialog:FindChild("QuestInfoObjectivesTitle"):SetText(Apollo.GetString("QuestLog_Objectives"))
	elseif eQuestState ~= Quest.QuestState_Mentioned then
		for key, tObjData in pairs(quest:GetVisibleObjectiveData()) do
			if tObjData.nCompleted < tObjData.nNeeded then
				local wndObj = Apollo.LoadForm(self.xmlDoc, "ObjectivesItem", QuestDialog:FindChild("QuestInfoObjectivesList"), self)
				wndObj:FindChild("ObjectivesItemText"):SetAML(self:HelperBuildObjectiveTitleString(quest, tObjData))
			end

			-- Objective Spell
			if quest:GetSpell(tObjData.nIndex) then
				wndSpell = Apollo.LoadForm(self.xmlDoc, "SpellItem", QuestDialog:FindChild("QuestInfoObjectivesList"), self)

				wndSpell:FindChild("SpellItemBtn"):SetContentId(quest, tObjData.nIndex)
				wndSpell:FindChild("SpellItemBtn"):SetText(String_GetWeaselString(GameLib.GetKeyBinding("CastObjectiveAbility")))				
			end
		end

		QuestDialog:FindChild("QuestInfoObjectivesTitle"):SetText(Apollo.GetString("QuestLog_Objectives"))
	end

	QuestDialog:FindChild("QuestInfoObjectivesList"):ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)

	-- Rewards Received
	local tRewardInfo = quest:GetRewardData()

	QuestDialog:FindChild("QuestInfoRewardRecList"):DestroyChildren()

	for key, tReward in pairs(tRewardInfo.arFixedRewards) do
		local wndReward = Apollo.LoadForm(self.xmlDoc, "RewardItem", QuestDialog:FindChild("QuestInfoRewardRecList"), self)
		self:HelperBuildRewardsRec(wndReward, tReward, true)
	end

	-- XP Received
	local nRewardXP = quest:CalcRewardXP()

	if nRewardXP > 0 then
		local wndReward = Apollo.LoadForm(self.xmlDoc, "RewardItem", QuestDialog:FindChild("QuestInfoRewardRecList"), self)	
		self:HelperBuildXPRewardsRec(wndReward, nRewardXP)
	end

	-- Rewards To Choose
	QuestDialog:FindChild("QuestInfoRewardChoList"):DestroyChildren()

	for key, tReward in pairs(tRewardInfo.arRewardChoices) do
		local wndReward = Apollo.LoadForm(self.xmlDoc, "RewardItem", QuestDialog:FindChild("QuestInfoRewardChoList"), self)
		self:HelperBuildRewardsRec(wndReward, tReward, false)
	end

	-- Special reward formatting for finished quests
	if eQuestState == Quest.QuestState_Completed then
		QuestDialog:FindChild("QuestInfoRewardRecTitle"):SetText(Apollo.GetString("QuestLog_YouReceived"))
		QuestDialog:FindChild("QuestInfoRewardChoTitle"):SetText(Apollo.GetString("QuestLog_YouChoseFrom"))
	else
		QuestDialog:FindChild("QuestInfoRewardRecTitle"):SetText(Apollo.GetString("QuestLog_WillReceive"))
		QuestDialog:FindChild("QuestInfoRewardChoTitle"):SetText(Apollo.GetString("QuestLog_CanChooseOne"))
	end

	local nWidth, nHeight, nLeft, nTop, nRight, nBottom

	-- Objectives Content
	for key, wndObj in pairs(QuestDialog:FindChild("QuestInfoObjectivesList"):GetChildren()) do

		if wndObj:FindChild("ObjectivesItemText") then
		nWidth, nHeight = wndObj:FindChild("ObjectivesItemText"):SetHeightToContentHeight()
		end

		if wndObj:FindChild("QuestProgressItem") then
			nHeight = nHeight + wndObj:FindChild("QuestProgressItem"):GetHeight()
		end

		if wndObj:FindChild("SpellItemBtn") then
			nHeight = nHeight + wndObj:FindChild("SpellItemBtn"):GetHeight()
		end

		nLeft, nTop, nRight, nBottom = wndObj:GetAnchorOffsets()
		wndObj:SetAnchorOffsets(nLeft, nTop, nRight, nTop + math.max(self.knObjectivesItemHeight, nHeight + 8)) -- TODO: Hardcoded formatting of text pad
	end

	-- Objectives Frame
	nHeight = QuestDialog:FindChild("QuestInfoObjectivesList"):ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
	nLeft, nTop, nRight, nBottom = QuestDialog:FindChild("QuestInfoObjectivesFrame"):GetAnchorOffsets()
	QuestDialog:FindChild("QuestInfoObjectivesFrame"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + 40)
	QuestDialog:FindChild("QuestInfoObjectivesFrame"):Show(#QuestDialog:FindChild("QuestInfoObjectivesList"):GetChildren() > 0)
	QuestDialog:FindChild("PaddingObjective"):Show(#QuestDialog:FindChild("QuestInfoObjectivesList"):GetChildren() > 0)

	-- Rewards Received
	nHeight = QuestDialog:FindChild("QuestInfoRewardRecList"):ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
	nLeft, nTop, nRight, nBottom = QuestDialog:FindChild("QuestInfoRewardRecFrame"):GetAnchorOffsets()
	QuestDialog:FindChild("QuestInfoRewardRecFrame"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + self.nRewardRecListHeight - 10 ) -- TODO: Hardcoded footer padding
	QuestDialog:FindChild("QuestInfoRewardRecFrame"):Show(#QuestDialog:FindChild("QuestInfoRewardRecList"):GetChildren() > 0)
	QuestDialog:FindChild("PaddingReward"):Show(#QuestDialog:FindChild("QuestInfoRewardRecList"):GetChildren() > 0)

	-- Rewards to Choose
	nHeight = QuestDialog:FindChild("QuestInfoRewardChoList"):ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop, function(a,b) return b:FindChild("RewardItemCantUse"):IsShown() end)
	nLeft, nTop, nRight, nBottom = QuestDialog:FindChild("QuestInfoRewardChoFrame"):GetAnchorOffsets()
	QuestDialog:FindChild("QuestInfoRewardChoFrame"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + self.nRewardChoListHeight) -- TODO: Hardcoded footer padding
	QuestDialog:FindChild("QuestInfoRewardChoFrame"):Show(#QuestDialog:FindChild("QuestInfoRewardChoList"):GetChildren() > 0)
	QuestDialog:FindChild("PaddingRewardChoice"):Show(#QuestDialog:FindChild("QuestInfoRewardChoList"):GetChildren() > 0)

	-- Summary
	local questSummary = ""
	if eQuestState == Quest.QuestState_Completed and string.len(quest:GetCompletedSummary()) > 0 then
		questSummary = quest:GetCompletedSummary() 
	elseif string.len(quest:GetSummary()) > 0 then
		questSummary = quest:GetSummary() 
	end

	QuestDialog:FindChild("SummaryBox"):SetAML("<P Font=\"CRB_Interface11\" TextColor=\"ff56b381\">" .. questSummary .. "</P>")
	QuestDialog:FindChild("SummaryBox"):SetHeightToContentHeight()
	nHeight = QuestDialog:FindChild("SummaryBox"):GetHeight()
	nLeft, nTop, nRight, nBottom = QuestDialog:FindChild("SummaryContainer"):GetAnchorOffsets()
	QuestDialog:FindChild("SummaryContainer"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + self.nSummaryContainer - 20) -- TODO: Hardcoded footer padding

	-- Rearrange quest dialog
	QuestDialog:ArrangeChildrenVert(0)
	QuestDialog:RecalculateContentExtents()
	QuestDialog:SetVScrollPos(0)
	QuestDialog:Show(true) 
end

--
-- Btn events
--

function Questline:OnQuestDetailsViewBtnClick(wndHandler, wndControl, eMouseButton) 
	self.wndMainOne:FindChild("DialogContainer"):Show(false)
	self.wndMainOne:FindChild("QuestDetailsContainer"):Show(true) 
end

function Questline:OnQuestDetailsCloseBtnClick(wndHandler, wndControl, eMouseButton) 
	self.wndMainOne:FindChild("DialogContainer"):Show(true)
	self.wndMainOne:FindChild("QuestDetailsContainer"):Show(false) 
end

--

function Questline:OnResponseBtnClick(wndHandler, wndControl, eMouseButton)
	if not wndHandler or not wndHandler:GetData() then
		return
	end

	-- Early exit if context menu
	if eMouseButton == GameLib.CodeEnumInputMouse.Right then
		-- OnLootItemMouseUp should be fired instead
		return
	end

	self.wndMainOne:FindChild("DialogContainer"):Show(true)

	wndHandler:GetData():Select() -- All the work is done in DialogSys's Select Method
end

function Questline:OnResponseContinueBtnClick(wndHandler, wndControl, eMouseButton)
	if not wndHandler or not wndHandler:GetData() then
		return
	end

	self.wndPlayer:SetSprite("")
	self.wndMainOne:FindChild("DialogContainer"):Show(true)

	-- Early exit if context menu
	if eMouseButton == GameLib.CodeEnumInputMouse.Right then
		return
	end
	
	local drResponse = wndHandler:GetData()

	table.insert(self.QuestSeenMoreInfo, {QuestID = drResponse:GetQuestId(), drResponse = drResponse})

	local unitPlayer = GameLib.GetPlayerUnit()
	local unitPlayerName = unitPlayer:GetName()

	self.wndMainOne:FindChild("QuestGiverName"):SetText(unitPlayerName)
	self.wndMainOne:FindChild("DialogBox"):SetAML("<P Font=\"CRB_HeaderLarge\">"..drResponse:GetText().."</P>")
	self.wndMainOne:FindChild("DialogBox"):SetVScrollPos(0)

	self.wndMainOne:FindChild("QuestTargetPortrait"):SetModelSequence(150) 
	self.wndMainOne:FindChild("QuestPlayerPortrait"):PlayTalkSequence() 

	self.timerUpdateNPCAO:Stop()
	self.timerUpdatePlayerAO:Stop()
	self.timerUpdatePlayerAO:Start()

	local eResponseType = drResponse:GetType()
	local wndCurr = nil
		
	wndCurr = self.wndMainOne:FindChild("ContinuePlayerContainer")
	wndCurr:Show(false)

	wndCurr = self.wndMainOne:FindChild("ContinueNPCContainer")
	wndCurr:FindChild("ContinueText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\"ffffffff\">" .. Strings.Continue .. "</P>")
	wndCurr:FindChild("ContinueIcon"):SetSprite(self:HelperComputeIconPath(eResponseType))
	wndCurr:FindChild("ContinueBtn"):SetData(drResponse)
	wndCurr:Show(true)
end

function Questline:OnResponseGoodbyeBtnClick(wndHandler, wndControl, eMouseButton)
	if not wndHandler or not wndHandler:GetData() then
		return
	end

	local drResponse = wndHandler:GetData()

	-- Early exit if context menu
	if eMouseButton == GameLib.CodeEnumInputMouse.Right then
		-- OnLootItemMouseUp should be fired instead
		return
	end

	drResponse:Select() -- All the work is done in DialogSys's Select Method

	self.wndMainOne:FindChild("DialogContainer"):Show(true)
end

function Questline:OnResponsePickTopicBtnClick(wndHandler, wndControl, eMouseButton)
	self.wndMainOne:FindChild("QuestTitle"):Show(false)
	self.wndMainOne:FindChild("PickTopicOrRewardTitle"):Show(true)
	self.wndMainOne:FindChild("PickTopicOrRewardTitle"):SetText(Strings.PickTopic)
	self.wndMainOne:FindChild("DialogContainer"):Show(false)
	self.wndPlayer:SetSprite("Dialog:sprHolo_Speech_Item")
	self.wndPlayer:SetScale(1.0)
	self.wndPlayer:Invoke()
end

function Questline:OnResponsePickRewardBtnClick(wndHandler, wndControl, eMouseButton)
	self.wndMainOne:FindChild("QuestTitle"):Show(false)
	self.wndMainOne:FindChild("PickTopicOrRewardTitle"):Show(true)
	self.wndMainOne:FindChild("PickTopicOrRewardTitle"):SetText(Strings.PickReward)
	self.wndMainOne:FindChild("DialogContainer"):Show(false)
	self.wndPlayer:SetSprite("Dialog:sprHolo_Speech_Item")
	self.wndPlayer:SetScale(1.0)
	self.wndPlayer:Invoke()
end

function Questline:OnResponseSelectRewardBtnClick(wndHandler, wndControl, eMouseButton)
	if not wndHandler or not wndHandler:GetData() then
		return
	end

	-- Early exit if context menu
	if eMouseButton == GameLib.CodeEnumInputMouse.Right then
		-- OnLootItemMouseUp should be fired instead
		return
	end

	local drResponse = wndHandler:GetData()

	if drResponse:GetRewardId() and drResponse:GetRewardId() ~= 0 and drResponse:GetRewardId() ~= self.bRewardPicked then
		-- Reset text first
		for idx, wndCurr in pairs(self.wndPlayer:FindChild("ResponseItemContainer"):GetChildren()) do
			if wndCurr:FindChild("ResponseItemText") and wndCurr:FindChild("ResponseItemText"):GetData() then
				wndCurr:FindChild("ResponseItemText"):SetText(wndCurr:FindChild("ResponseItemText"):GetData())
				wndCurr:FindChild("ResponseItemText"):SetTextColor(kcrDefaultOptionColor)
			end
		end
		self.bRewardPicked = drResponse:GetRewardId()
		wndHandler:FindChild("ResponseItemText"):SetText(String_GetWeaselString(Apollo.GetString("Dialog_TakeItem"), wndHandler:FindChild("ResponseItemText"):GetData()))
		wndHandler:FindChild("ResponseItemText"):SetTextColor(kcrHighlightOptionColor)
	else
		drResponse:Select() -- All the work is done in DialogSys's Select Method
		
		self.wndMainOne:FindChild("DialogContainer"):Show(true)
	end
end

--

function Questline:OnResponseItemMouseUp(wndHandler, wndControl, eMouseButton)
	if eMouseButton == GameLib.CodeEnumInputMouse.Right and wndHandler:GetData() then
		Event_FireGenericEvent("GenericEvent_ContextMenuItem", wndHandler:GetData())
	end
end

function Questline:OnDestroyTooltip(wndHandler, wndControl)
	if wndHandler == wndControl then
		wndHandler:SetTooltipDoc(nil)
	end
end

function Questline:OnGenerateTooltip(wndHandler, wndControl, eType, arg1, arg2)
	if wndHandler ~= wndControl	then
		return
	end

	if eType == Tooltip.TooltipGenerateType_ItemData then
		local itemCurr = arg1
		local itemEquipped = itemCurr:GetEquippedItemForItemType()
		Tooltip.GetItemTooltipForm(self, wndControl, itemCurr, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})

	elseif eType == Tooltip.TooltipGenerateType_Reputation or eType == Tooltip.TooltipGenerateType_TradeSkill then
		local xml = nil
		xml = XmlDoc.new()
		xml:StartTooltip(Tooltip.TooltipWidth)
		xml:AddLine(arg1)
		wndControl:SetTooltipDoc(xml)
	elseif eType == Tooltip.TooltipGenerateType_Money then
		local xml = nil
		xml = XmlDoc.new()
		xml:StartTooltip(Tooltip.TooltipWidth)
		xml:AddLine(arg1:GetMoneyString(), kcrDefaultColor, "CRB_InterfaceMedium")
		wndControl:SetTooltipDoc(xml)
	elseif wndHandler:GetData() then
		local itemCurr = wndHandler:GetData()
		local itemEquipped = itemCurr:GetEquippedItemForItemType()
		Tooltip.GetItemTooltipForm(self, wndControl, itemCurr, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
	else
		wndControl:SetTooltipDoc(nil)
	end
end

function Questline:OnLootItemMouseUp(wndHandler, wndControl, eMouseButton)
	if eMouseButton == GameLib.CodeEnumInputMouse.Right and wndHandler:GetData() then
		Event_FireGenericEvent("GenericEvent_ContextMenuItem", wndHandler:GetData())
	end
end

function Questline:OnRewardIconMouseUp(wndHandler, wndControl, eMouseButton)
	if eMouseButton == GameLib.CodeEnumInputMouse.Right and wndHandler:GetData() then
		Event_FireGenericEvent("GenericEvent_ContextMenuItem", wndHandler:GetData())
	end
end

function Questline:IsSeenMoreInfo(QuestId, drResponse)
	for id, data in ipairs(self.QuestSeenMoreInfo) do
		if data.QuestID == QuestId and data.drResponse:GetText() == drResponse:GetText() then
			return true
		end
	end

	return false
end

--
-- Helpers
--

function Questline:HelperBuildObjectiveProgBar(queQuest, tObjective, wndObjective, bComplete)
	if tObjective.nNeeded > 1 and queQuest:DisplayObjectiveProgressBar(tObjective.nIndex) then
		local wndObjectiveProg = self:FactoryCacheProduce(wndObjective, "QuestProgressItem", "QuestProgressItem")
		local nCompleted = bComplete and tObjective.nNeeded or tObjective.nCompleted
		local nNeeded = tObjective.nNeeded

		wndObjectiveProg:FindChild("QuestProgressBar"):SetMax(nNeeded)
		wndObjectiveProg:FindChild("QuestProgressBar"):SetProgress(nCompleted)
		wndObjectiveProg:FindChild("QuestProgressBar"):EnableGlow(nCompleted > 0 and nCompleted ~= nNeeded)
	end
end

function Questline:HelperBuildRewardsRec(wndReward, tRewardData, bReceived)
	if not tRewardData then
		return
	end

	local strText   = ""
	local strSprite = ""

	if tRewardData.eType == Quest.Quest2RewardType_Item then
		if not tRewardData.itemReward then
			wndReward:Destroy()
			return
		end

		strText = tRewardData.itemReward:GetName()
		strSprite = tRewardData.itemReward:GetIcon()
		Tooltip.GetItemTooltipForm(self, wndReward, tRewardData.itemReward, {bPrimary = true, bSelling = false, itemCompare = tRewardData.itemReward:GetEquippedItemForItemType()})
		wndReward:FindChild("RewardItemCantUse"):Show(self:HelperPrereqFailed(tRewardData.itemReward))
		wndReward:FindChild("RewardItemText"):SetTextColor(karEvalColors[tRewardData.itemReward:GetItemQuality()])
		wndReward:FindChild("RewardIcon"):SetText(tRewardData.nAmount > 1 and tRewardData.nAmount or "")
		wndReward:FindChild("RewardIcon"):SetData(tRewardData.itemReward)
	elseif tRewardData.eType == Quest.Quest2RewardType_Reputation then
		strText = String_GetWeaselString(Apollo.GetString("Dialog_FactionRepReward"), tRewardData.nAmount, tRewardData.strFactionName)
		strSprite = "Icon_ItemMisc_UI_Item_Parchment"
		wndReward:SetTooltip(strText)
	elseif tRewardData.eType == Quest.Quest2RewardType_TradeSkillXp then
		strText = String_GetWeaselString(Apollo.GetString("Dialog_TradeskillXPReward"), tRewardData.nXP, tRewardData.strTradeskill)
		strSprite = "Icon_ItemMisc_tool_0001"
		wndReward:SetTooltip(strText)
	elseif tRewardData.eType == Quest.Quest2RewardType_Money then
		if tRewardData.eCurrencyType == Money.CodeEnumCurrencyType.Credits then
			local nInCopper = tRewardData.nAmount
			if nInCopper >= 1000000 then
				strText = String_GetWeaselString(Apollo.GetString("CRB_Platinum"), math.floor(nInCopper / 1000000))
			end
			if nInCopper >= 10000 then
				strText = strText .. " " .. String_GetWeaselString(Apollo.GetString("CRB_Gold"), math.floor(nInCopper % 1000000 / 10000))
			end
			if nInCopper >= 100 then
				strText = strText .. " " .. String_GetWeaselString(Apollo.GetString("CRB_Silver"), math.floor(nInCopper % 10000 / 100))
			end
			strText = strText .. " " .. String_GetWeaselString(Apollo.GetString("CRB_Copper"), math.floor(nInCopper % 100))
			strSprite = "ClientSprites:Icon_ItemMisc_bag_0001"
			wndReward:SetTooltip(strText)
		else
			local tDenomInfo = GameLib.GetPlayerCurrency(tRewardData.eCurrencyType or tRewardData.idObject):GetDenomInfo()
			if tDenomInfo ~= nil then
				strText = tRewardData.nAmount .. " " .. tDenomInfo[1].strName
				strSprite = "ClientSprites:Icon_ItemMisc_bag_0001"
				wndReward:SetTooltip(strText)
			end
		end
	end

	wndReward:FindChild("RewardIcon"):SetSprite(strSprite)
	wndReward:FindChild("RewardItemText"):SetText(strText)
end

function Questline:HelperBuildObjectiveProgBar(queQuest, tObjective, wndObjective, bComplete)
	if tObjective.nNeeded > 1 and queQuest:DisplayObjectiveProgressBar(tObjective.nIndex) then
		local wndObjectiveProg = self:FactoryCacheProduce(wndObjective, "QuestProgressItem", "QuestProgressItem")
		local nCompleted = bComplete and tObjective.nNeeded or tObjective.nCompleted
		local nNeeded = tObjective.nNeeded

		wndObjectiveProg:FindChild("QuestProgressBar"):SetMax(nNeeded)
		wndObjectiveProg:FindChild("QuestProgressBar"):SetProgress(nCompleted)
		wndObjectiveProg:FindChild("QuestProgressBar"):EnableGlow(nCompleted > 0 and nCompleted ~= nNeeded)
	end
end

function Questline:HelperBuildXPRewardsRec(wndReward, bReceived)
	if not bReceived then
		return
	end

	local strText = String_GetWeaselString(Apollo.GetString("CRB_XPAmountInteger"), bReceived)
	local strSprite = "IconSprites:Icon_Modifier_xp_001"

	wndReward:FindChild("RewardIcon"):SetSprite(strSprite)
	wndReward:FindChild("RewardItemText"):SetText(strText)
	wndReward:SetTooltip(strText)
end

function Questline:HelperBuildObjectiveTitleString(queQuest, tObjective, bIsTooltip)
	local strResult = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"UI_TextHoloBody\">%s</T>", tObjective.strDescription)

	-- Prefix Optional or Progress if it hasn't been finished yet
	if tObjective.nCompleted < tObjective.nNeeded then
		if tObjective and not tObjective.bIsRequired then
			strResult = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"UI_TextHoloBody\">%s</T>%s", Apollo.GetString("QuestLog_Optional"), strResult)
		end

		local bQuestIsNotCompleted = queQuest:GetState() ~= Quest.QuestState_Completed -- if quest is complete, hide the % readouts.

		if tObjective.nNeeded > 1 and queQuest:DisplayObjectiveProgressBar(tObjective.nIndex) and bQuestIsNotCompleted then
			local nCompleted = queQuest:GetState() == Quest.QuestState_Completed and tObjective.nNeeded or tObjective.nCompleted
			local nPercentText = String_GetWeaselString(Apollo.GetString("CRB_Percent"), math.floor(nCompleted / tObjective.nNeeded * 100))
			strResult = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"UI_TextHoloBody\">%s </T>%s", nPercentText, strResult)
		elseif tObjective.nNeeded > 1 and bQuestIsNotCompleted then
			local nCompleted = queQuest:GetState() == Quest.QuestState_Completed and tObjective.nNeeded or tObjective.nCompleted
			local nPercentText = String_GetWeaselString(Apollo.GetString("QuestTracker_ValueComplete"), Apollo.FormatNumber(nCompleted, 0, true), Apollo.FormatNumber(tObjective.nNeeded, 0, true))
			strResult = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"UI_TextHoloBody\">%s </T>%s", nPercentText, strResult)
		end
	end

	return strResult
end

function Questline:HelperComputeIconPath(eResponseType)
	local strSprite = "BK3:btnHolo_CloseNormal"
	if eResponseType == DialogResponse.DialogResponseType_ViewVending then
		strSprite = "CRB_DialogSprites:sprDialog_Icon_Vendor"
	elseif eResponseType == DialogResponse.DialogResponseType_ViewTraining then
		strSprite = "CRB_DialogSprites:sprDialog_Icon_Trainer"
	elseif eResponseType == DialogResponse.DialogResponseType_ViewCraftingStation then
		strSprite = "CRB_DialogSprites:sprDialog_Icon_Vendor"
	elseif eResponseType == DialogResponse.DialogResponseType_ViewTradeskillTraining then
		strSprite = "CRB_DialogSprites:sprDialog_Icon_Tradeskill"
	elseif eResponseType == DialogResponse.DialogResponseType_ViewQuestAccept then
		strSprite = "CRB_MegamapSprites:sprMap_IconCompletion_TaskQuest"
	elseif eResponseType == DialogResponse.DialogResponseType_ViewQuestComplete then
		strSprite = "CRB_DialogSprites:sprDialog_Icon_Check"
	elseif eResponseType == DialogResponse.DialogResponseType_ViewQuestIncomplete then
		strSprite = "CRB_DialogSprites:sprDialog_Icon_DisabledCheck"
	elseif eResponseType == DialogResponse.DialogResponseType_Goodbye then
		strSprite = "BK3:btnHolo_CloseNormal"
	elseif eResponseType == DialogResponse.DialogResponseType_QuestAccept then
		strSprite = "charactercreate:sprCharC_HeaderStepComplete"
	elseif eResponseType == DialogResponse.DialogResponseType_QuestMoreInfo then
		strSprite = "charactercreate:sprCharC_HeaderStepIncomplete"
	elseif eResponseType == DialogResponse.DialogResponseType_QuestComplete then
		strSprite = "CRB_DialogSprites:sprDialog_Icon_Check"
	end
	return strSprite
end

function Questline:HelperComputeRewardTextColor(idReward, tChoiceRewardData)
	if idReward == 0 then
		return kcrDefaultOptionColor
	end

	for idx, tCurrReward in ipairs(tChoiceRewardData) do
		if tCurrReward and tCurrReward.idReward == idReward then
			if tCurrReward.eType == Quest.Quest2RewardType_Item then
				return karEvalColors[tCurrReward.itemReward:GetItemQuality()]
			end
			break
		end
	end

	return kcrDefaultOptionColor
end

function Questline:HelperComputeRewardIcon(wndCurr, idReward, tChoiceRewardData)
	if idReward == 0 then
		return
	end

	local tFoundRewardData = nil
	for idx, tCurrReward in ipairs(tChoiceRewardData) do
		if tCurrReward.idReward == idReward then
			tFoundRewardData = tCurrReward
			break
		end
	end

	if tFoundRewardData and wndCurr then
		local strIconSprite = ""
		if tFoundRewardData.eType == Quest.Quest2RewardType_Item then
			strIconSprite = tFoundRewardData.itemReward:GetIcon()
			wndCurr:SetData(tFoundRewardData.itemReward) -- For OnGenerateTooltip and Right Click
		elseif tFoundRewardData.eType == Quest.Quest2RewardType_Reputation then
			strIconSprite = "Icon_ItemMisc_UI_Item_Parchment"
			wndCurr:SetTooltip(String_GetWeaselString(Apollo.GetString("Dialog_FactionRepReward"), tFoundRewardData.nAmount, tFoundRewardData.strFactionName))
		elseif tFoundRewardData.eType == Quest.Quest2RewardType_TradeSkillXp then
			strIconSprite = "ClientSprites:Icon_ItemMisc_tool_0001"
			wndCurr:SetTooltip(String_GetWeaselString(Apollo.GetString("Dialog_TradeskillXPReward"), tFoundRewardData.nXP, tFoundRewardData.strTradeskill)) --hardcoded
		elseif tFoundRewardData.eType == Quest.Quest2RewardType_GrantTradeskill then
			strIconSprite = "ClientSprites:Icon_ItemMisc_tool_0001"
			wndCurr:SetTooltip("")
		elseif tFoundRewardData.eType == Quest.Quest2RewardType_Money then
			if tFoundRewardData.eCurrencyType == Money.CodeEnumCurrencyType.Credits then
				local strText = ""
				local nInCopper = tFoundRewardData.nAmount
				if nInCopper >= 1000000 then
					strText = strText .. String_GetWeaselString(Apollo.GetString("CRB_Platinum"), math.floor(nInCopper / 1000000))
				end
				if nInCopper >= 10000 then
					strText = strText .. String_GetWeaselString(Apollo.GetString("CRB_Gold"), math.floor(nInCopper % 1000000 / 10000))
				end
				if nInCopper >= 100 then
					strText = strText .. String_GetWeaselString(Apollo.GetString("CRB_Silver"), math.floor(nInCopper % 10000 / 100))
				end
				wndCurr:SetTooltip(strText .. String_GetWeaselString(Apollo.GetString("CRB_Copper"), math.floor(nInCopper % 100)))
				strIconSprite = "ClientSprites:Icon_ItemMisc_bag_0001"
			else
				local tDenomInfo = GameLib.GetPlayerCurrency(tFoundRewardData.eCurrencyType):GetDenomInfo()
				if tDenomInfo ~= nil then
					strText = tFoundRewardData.nAmount .. " " .. tDenomInfo[1].strName
					strIconSprite = "ClientSprites:Icon_ItemMisc_bag_0001"
					wndCurr:SetTooltip(strText)
				end
			end
		end

		wndCurr:FindChild("ResponseItemIcon"):Show(false)
		wndCurr:FindChild("ResponseItemRewardBG"):Show(true)
		wndCurr:FindChild("ResponseItemRewardIcon"):SetSprite(strIconSprite)
		wndCurr:FindChild("ResponseItemCantUse"):Show(self:HelperPrereqFailed(tFoundRewardData.itemReward))
	end
end

function Questline:HelperPrereqFailed(itemCurr)
	return itemCurr and itemCurr:IsEquippable() and not itemCurr:CanEquip()
end
