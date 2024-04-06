--[[	
	Animation Spoofer
	By kylethornton
--]]

if game:GetService("RunService"):IsRunning() then 
	print'Animation Spoofer cannot run while game is running'; return
end

--#Plugin Locals
local Version_Id = 'v21004' -- [2] Version [1] Minor update [0 0 3] Patches

local toolBar = plugin:CreateToolbar("Animation Spoofer [v2]")
local button = toolBar:CreateButton("Animation Spoofer", "anothing fine gui", "rbxassetid://3444268497")

--#Locals
local MktplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService('RunService')
local TextService = game:GetService("TextService")
local Tween = game:GetService('TweenService')
local ChangeService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local UserInputService = game:GetService("UserInputService")
local KeyframeService = game:GetService('KeyframeSequenceProvider')
local Mouse, Camera = plugin:GetMouse(), Instance.new("Camera")

local defaultText = '   Animation Spoofer [v2]'
local Offset = CFrame.new(0, 1, -6)
local UiCooldown, WaitCooldown, ObjectCooldown, WaitTime = tick(), tick(), tick(), 1
local lastText, SavePos, _1xy, _2xy, idCheck, isRunning = nil, 0, -203, -610, 0, false

local Utils, UserId = require(script.Utils), game:GetService("StudioService"):GetUserId()
local currentObject, currentRig, currentFolder, folderName

--#Ui elements
local Assets, UIParent = script:WaitForChild('Assets'), game:GetService('CoreGui')

local Gui = script:WaitForChild('UI')
local Main_Ui = Gui.Main

local versionFrame = Main_Ui.vNumber

local Tab = Main_Ui.Tab
local ConvetUi = Main_Ui.Convert
local Settings = Main_Ui.Settings

local Input = ConvetUi.Input
local Viewer = ConvetUi.Viewer.view
local Details = ConvetUi.Details
local Copy = ConvetUi.Copy

local iName = Details.item_name
local iDate = Details.item_date
local iDetail = Details.item_detail
local iRig = iName.item_rig

local close = Assets.close

local image1, image2 = Main_Ui.Image1, Main_Ui.Image2

--#Tables
local Saves, PartUpdater, Connections, table_Body, currentGuiObject, settingsClass = {}, {}, {}, {}, {}, {}
local query = {Bool = false, Count = 0,  Message = ''}
local sharedValues = {['FocusLost'] = false, ['customTypes'] = {}}
local BindableEvents = {['Selection'] = Instance.new("BindableEvent", Assets)}

local states = {
	['FallingDown'] = false, ['Running'] = false, ['RunningNoPhysics'] = false,
	['Climbing'] = false, ['StrafingNoPhysics'] = false, ['Ragdoll'] = false,
	['GettingUp'] = false, ['Jumping'] = false, ['Landed'] = false,
	['Flying'] = false, ['Freefall'] = false, ['Seated'] = false,
	['PlatformStanding'] = false, ['Dead'] = false, ['Swimming'] = false,
	['Physics'] = false
}

local textData = {
	['rig'] = {Name = '', Ui = iRig, Ignore = true},
	['item_name'] = {Name = '', Ui = iName, Type = 'Name'},
	['item_date'] = {Name = '', Ui = iDate, Type = 'Created'},
	['item_detail'] = {Name = '', Ui = iDetail, Type = 'Description', err = 'No description available.'},
	['item_rig'] = {Name = '', Ui = iRig, Type = '$Trig'},
}

local validLinks = {
	{'https://www.roblox.com/library/', 5},
	{'http://www.roblox.com/asset/', 2, '?id='},
	{'rbxassetid://', 3}
}

local validClasses = {
	["MeshPart"] = true; ["Part"] = true; ["Accoutrement"] = true;
	["Pants"] = true; ["Shirt"] = true;
	["Humanoid"] = true;
}

local Config = {
	['Auto Upload'] = true,
	['Disable Preview'] = false,
	['Ranv2'] = false
}

local settingsTable = { -- '%textbox%
	{
		Header = 'defaultSettings', Show = false,
		Spacer = false,
		Content = {
			['1_Auto_Upload'] = {Name = 'Auto Upload', Desc = 'Automatically upload converted animations', Toggle = 'Auto Upload'},
			['2_Disable_Pre'] = {Name = 'Disable Preview', Desc = 'Disables the animation preview window', Toggle = 'Disable Preview'},
			['3_Upload_All'] = {Name = 'Upload converted animation(s)', Desc = 'Uploads all keyframesequences from current selection', Func = 'Upload_All'},
			['4_Convert_All'] = {Name = 'Dump animation(s)', Desc = 'Dumps all animations from current selection into a folder', Func = 'Convert_All'} -- keyframesequence	
		}
	},

	{
		Header = 'Experimental Features', Show = true,
		Spacer = true,
		Content = {
			['Replace_All'] = {Name = 'Replace all animations', Desc = [[Replaces all animation ids within the game with newly converted ones. 

*This feature is experimental and is very buggy if not used correctly:
  1. Make sure your inventory is public.
  2. Do not cancel the upload of the animation
  3. Do not upload any other animations during this process
  4. After each successful upload, deselect the current selection or press ESC in studio
  |make sure the select tool is active|]], Func = 'Replace_All'}		
		}
	}
}

--#Setup Config
if plugin:GetSetting('Ranv2') then
	for name, v in pairs(Config) do
		Config[name] = plugin:GetSetting(name)
	end
end

--#Main functions
function formatText(str:string)
	for i, v in pairs(validLinks) do
		if str:find(v[1]) then
			return str:split(v[3] or '/')[v[2]]
		end
	end

	return str
end

local function connectionHandler(Type, reConnect)
	for i, value in pairs(Type) do
		if reConnect then
			Connections[value.Name] = value.Type:Connect(value.Func)
		elseif Connections[value.Name] then
			Connections[value.Name]:Disconnect(); Connections[value.Name] = nil
		end
	end
end

local function filterAnimation(Tbl, Type)
	local foundAnimation = {}

	for _, v in pairs(Tbl) do
		if v.ClassName ~= (Type or 'Animation') then
			return false
		else
			table.insert(foundAnimation, v)
		end
	end

	return #foundAnimation > 0 and foundAnimation or nil
end

local function extractPages() -- https://create.roblox.com/docs/reference/engine/classes/KeyframeSequenceProvider
	local array, pagesObject = {}, KeyframeService:GetAnimations(UserId)

	while true do
		if pagesObject.IsFinished then
			for _, v in pairs(pagesObject:GetCurrentPage()) do
				table.insert(array, v)
			end

			break
		end

		pagesObject:AdvanceToNextPageAsync()
	end

	return #array > 0 and array[#array] or 0
end

function Reset()
	Utils.destroyItem({currentObject, {workspace.CurrentCamera, folderName}, Viewer:FindFirstChild('')})
	--PartUpdater = {}; 
	Utils.sortTable(textData)
end

--#Animation functions
local function RenderHumanoid(Model, Parent, MainModel)
	local ModelParts = Model:GetDescendants()

	for i=1, #ModelParts do
		local Part = ModelParts[i]

		if validClasses[Part.ClassName] then
			local a = Part.Archivable
			Part.Archivable	= true

			local RenderClone = Part:Clone()
			Part.Archivable	= a

			if Part.ClassName == "MeshPart" or Part.ClassName == "Part" or Part:IsA("Accoutrement") then
				table.insert(PartUpdater, {Table = ModelParts, TInt = i, Part = RenderClone, Type = Part:IsA("Accoutrement") and 'Handle' or nil, Destroy = true})
			elseif Part.ClassName == "Humanoid" then
				for name, bool in pairs(states) do
					RenderClone:SetStateEnabled(Enum.HumanoidStateType[name], bool)
				end
			end

			RenderClone.Parent = Parent
		end 
	end
end

local function Render()
	Viewer:ClearAllChildren()
	local Char = Instance.new("Model", Viewer); Char.Name = ""

	RenderHumanoid(currentRig, Char)
end

local function viewrig(rig, animation)
	wait(.5)

	Viewer.CurrentCamera = Camera
	local animID = KeyframeService:RegisterKeyframeSequence(animation)

	local Animation0 = Instance.new("Animation", rig)
	Animation0.Name, Animation0.AnimationId = "Anim", animID

	rig.DescendantAdded:Connect(Render)
	Render()
	
	if not rig:FindFirstChild('Humanoid') then
		return
	end
	
	rig.Humanoid:LoadAnimation(Animation0):Play()
	table.insert(PartUpdater, {Table = {workspace.CurrentCamera}, TInt = 1, Part = rig, StepAnimation = true, FindChild = folderName})
end

local function getMarketData(Id, falseReturn)
	local success, Contents = pcall(function()
		return MktplaceService:GetProductInfo(Id, Enum.InfoType.Asset)
	end)
	
	return success and Contents or falseReturn and {AssetTypeId = 0, Description = '', Failed = true} or nil
end

local function grabAnimation(Input:string, Name:string, Folder, Message, FParent)
	local Type = typeof(Input) == 'Instance'
	local success, Contents = Type and true, Type and Input:Clone()

	if not success then
		success, Contents = pcall(function()
			return game:GetObjects("rbxassetid://" .. Input)[1]
		end)
		
		RunService.Heartbeat:Wait()
	end

	if success and Contents then
		if Folder then
			local folderName_, folderParent_ = (typeof(Folder) == 'string' and Folder or 'Imported Animations | '), (FParent or workspace)

			if typeof(Folder) ~= 'Instance' and not folderParent_:FindFirstChild(folderName_ .. folderName) then
				Instance.new('Folder', folderParent_).Name = (folderName_ .. folderName)
			end

			Contents.Parent = typeof(Folder) == 'Instance' and Folder or folderParent_:FindFirstChild(folderName_ .. folderName)
		elseif not Folder and Name and not Utils.findType(Saves, 'Id', Input) then
			SavePos += 1; table.insert(Saves, 1, {Name = Name, Pos = SavePos, Id = Input, Time = os.time(), Connection = nil})
		end	
	elseif not success and Message then
		uiMessage(Message, 1.5)
	end

	return success and Contents or nil
end

local function saveAnimation(Obj, Bypass)
	if typeof(Obj) ~= 'Instance' and not Config['Auto Upload'] or Bypass then
		Obj = typeof(Obj) == 'Instance' and Obj or grabAnimation(Obj or tostring(lastText), nil, true)

		Selection:Set({Obj})			
	else
		Selection:Set({typeof(Obj) == 'Instance' and Obj or currentObject})
		wait()

		plugin:SaveSelectedToRoblox()			
	end	
end

--#Connection Functions
local function tabCheck(Return)
	local Obj = UIParent:GetGuiObjectsAtPosition(Mouse.X, Mouse.Y)

	if #currentGuiObject >= 1 and (#Obj < 1 or not Obj[1]:IsDescendantOf(Gui)) then
		currentGuiObject, close.Parent = {}, Assets
		
		return false
	end	
	
	return Return and Obj or true
end

local function Heartbeat(dt)
	local currentTick = tick()
	
	if currentTick - UiCooldown >= .02 then --#May be scuffed but i dont feel like reworking any part of the ui
		_2xy = _1xy == -203 and -609 or _2xy+1; _1xy = _2xy == -203 and -609 or _1xy+1

		image1.Position, image2.Position, UiCooldown = UDim2.new(0.498771548, _1xy, 0.498069495, -129), UDim2.new(0.498771548, _2xy, 0.498069495, -129), tick()
	end
	
	if query.Bool and currentTick - WaitCooldown >= WaitTime then
		query.Count, WaitCooldown = query.Count >= 3 and 0 or query.Count + 1, tick()
		Tab.Tag.Text = defaultText .. (#query.Message > 1 and ' | ' or '') .. query.Message .. string.rep('.', query.Count)
	end

	for i, v in pairs(PartUpdater) do
		local Part, RenderClone = v.Table[v.TInt], v.Type and v.Part:FindFirstChild(v.Type) or not v.Type and v.Part

		if (v.FindChild and Part:FindFirstChild(v.FindChild) or not v.FindChild and Part) and Part.Parent then
			Part = v.Type and Part:FindFirstChild(v.Type) or Part

			if v.StepAnimation and RenderClone:FindFirstChild('HumanoidRootPart') then 
				Camera.CFrame = CFrame.new(RenderClone.HumanoidRootPart.CFrame:toWorldSpace(Offset).p, RenderClone.HumanoidRootPart.CFrame.p); RenderClone:WaitForChild('Humanoid').Animator:StepAnimations(dt)	
			else 
				RenderClone.CFrame = Part.CFrame 
			end
		else
			if v.Destroy and PartUpdater[i].Part.Destroy then
				PartUpdater[i].Part:Destroy()				
			end

			PartUpdater[i] = nil
		end
	end
end

local function InputChanged(input, gameProcessedEvent)
	if input.UserInputType == Enum.UserInputType.MouseWheel and currentGuiObject[1] and tabCheck() then	
		Tween:Create(currentGuiObject[1].Set, TweenInfo.new(.2, Enum.EasingStyle.Quad), {['CanvasPosition'] = Vector2.new(currentGuiObject[1].Set.CanvasPosition.X, currentGuiObject[1].Set.CanvasPosition.Y + (input.Position.Z <= 0 and currentGuiObject[1].Pixel or -currentGuiObject[1].Pixel))}):Play()
	end
end

local function InputEnded(input, gameProcessedEvent)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		sharedValues['FocusLost'] = true
		
		do
			local tab = tabCheck(true)
			
			if currentGuiObject[2] and tab then
				currentGuiObject[2][Utils.findType(tab, '%Index', close) and currentGuiObject[2].Close and 'Close' or 'Func'](unpack(currentGuiObject[2].Data))
			end			
		end
	elseif input.UserInputType == Enum.KeyCode.F10 then
		isRunning = false --#Just in case something happens
	end
end

Settings.MouseMoved:Connect(function()
	local guisAtPosition, Set = UIParent:GetGuiObjectsAtPosition(Mouse.X, Mouse.Y), {}
	
	for _, gui in pairs(guisAtPosition) do
		local checkType = sharedValues['customTypes'][gui]

		if gui:IsA("GuiObject") and checkType then
			Set[checkType.Type or 1] = checkType
			
			Set['Parent'] = checkType.Type == 2 and gui or nil
		end
	end

	close.Parent = Set[2] and Set['Parent'] or Assets
	
	if #Set >= 1 then
		currentGuiObject = Set; return
	end

	currentGuiObject = {}
end)

local function SelectionF()
	local SelectedInstance = Selection:Get() --#WHY ISNT THIS WORKING MUST MORE BLOOD BE SHED?!

	if (not SelectedInstance or not SelectedInstance[1]) and tick() - ObjectCooldown > .6 then
		ObjectCooldown = tick()

		BindableEvents['Selection']:Fire()
	end
end

--#Settings Functions
local function grabAnimationTypes(Sel, Type, Time, Query, Return)
	if isRunning then return nil end
	
	local hasAnim = filterAnimation(Sel, Type)
	isRunning = true
	
	if #Sel > 1 and not hasAnim then
		uiMessage(not hasAnim and 'Object found in selection' or 'Too many items selected', 3)
		
		return nil
	end

	uiMessage('Starting conversion', Query and 'query' or nil)
	local animTable = hasAnim or Utils.getDescendantsByClass((#Sel == 1 and Sel[1] or game), Type, 'normal', nil, 110)
	
	if Return then
		return animTable
	end
	
	for i, v in pairs(animTable) do
		if v.ClassName == Type then
			uiMessage('Converting ' .. tostring(i) .. '/' .. tostring(#animTable))
				
			if Type == 'KeyframeSequence' then
				saveAnimation(v)
				BindableEvents['Selection'].Event:Wait()
			else
				local Id = formatText(tostring(v.AnimationId))
				local mrkData = getMarketData(Id)
				
				if not mrkData or tonumber(mrkData.Creator.Id) <= 2 then
					continue --uiMessage('Skipping Roblox animation ' .. tostring(Id));
				end
				
				grabAnimation(Id, nil, true)
			end
			
			task.wait(Time or nil)
		end
	end
	
	isRunning = false
	uiMessage('Conversion completed!', 2)
end

--#Settings Class
settingsClass.init = function(self, value, ...)
	if self['s_'..value] then
		self['s_'..value](...)
	else
		print('failed to find function')
	end
end

settingsClass['s_Upload_All'] = function(sel, ...)
	grabAnimationTypes(sel, 'KeyframeSequence', nil, true)
end

settingsClass['s_Convert_All'] = function(sel, ...)
	grabAnimationTypes(sel, 'Animation', .04, true)
end

settingsClass['s_Replace_All'] = function(sel, ...)
	local animTable = grabAnimationTypes(sel, 'Animation', .04, true, true)
	
	if not animTable then return end

	local idTable = {}
	local success, BlacklistId = pcall(extractPages)

	if not success then
		uiMessage('Failed to execute [extractPages]', 3); print('[AnimationSpoofer v2] Note: Could be that the api is deprecated or page failed to load')

		return
	end

	idTable[BlacklistId] = {New = BlacklistId, Old = 0}

	for i, v in pairs(animTable) do
		if v.ClassName == 'Animation' then
			local hasCopy, Id = Utils.findType(idTable, 'Old', tostring(v.AnimationId), true), formatText(v.AnimationId)
			local mrkData = getMarketData(Id)
			
			if not mrkData or tonumber(mrkData.Creator.Id) <= 2 or hasCopy then
				uiMessage(not success and 'Failed to get MarketInfo' or (hasCopy and 'Replaced id of animation (C) ' or 'Roblox animation ') .. tostring(Id))
				v.AnimationId = hasCopy and hasCopy.New or v.AnimationId; wait(.2)

				continue
			end

			uiMessage('Converting ' .. tostring(i) .. '/' .. tostring(#animTable))
			
			local Obj = grabAnimation(Id, nil, 'TempAnimation_', ('Failed to grab animation number ' .. tostring(Id)), workspace.CurrentCamera)
			if not Obj then wait(1.5) continue end
			
			game.Debris:AddItem(Obj, 150)
			saveAnimation(Obj)

			BindableEvents['Selection'].Event:Wait()
			if Obj and Obj.Parent then (Obj.Parent.Name:find('Temp') and Obj.Parent or Obj):Destroy() end

			uiMessage('Checking id', 'query')
			
			local newId = extractPages()
			if idTable[newId] then
				uiMessage('Failed to update animation number ' .. tostring(Id)); wait(1.5)

				continue
			end

			idTable[newId] = {New = newId, Old = tostring(v.AnimationId)}
			v.AnimationId = ('rbxassetid://' .. formatText(tostring(newId))) --Just in case roblox updates anything

			uiMessage('Replaced id of animation ' .. tostring(Id)); task.wait()
		end
	end
	
	isRunning = false
	uiMessage('Conversion completed!', 2)
end

--#Ui Functions
if not Config['Ranv2'] then --#Like ya cut g
	Main_Ui.Popup_Temp.Visible = true

	Main_Ui.Popup_Temp.close.button.MouseButton1Down:Connect(function()
		Main_Ui.Popup_Temp:Destroy()
	end)
else
	Main_Ui.Popup_Temp:Destroy()
end

local function closeSave(Id, bool)
	local idCheck = Utils.findType(Saves, 'Id', tostring(Id), 'pos')
	
	if idCheck and Saves[idCheck] then
		local Frame = Settings.Saves:FindFirstChild(tostring(Saves[idCheck].Pos))
		close.Parent, Saves[idCheck], currentGuiObject[2] = Assets, nil, nil

		if Frame then
			Frame:Destroy()
		end
	end
end

local function loadSaves(clean:BoolValue)
	for amout, v in pairs(clean and Settings.Saves:GetChildren() or Saves) do
		if clean then
			if v.ClassName ~= 'UIListLayout' then 
				if Connections[v.Name] then	
					Connections[v.Name]:Disconnect();Connections[v.Name]=nil
				end

				v:Destroy() 
			end
		else
			if amout >= 50 then break end

			local saveButton = Assets.Saves['%s']:Clone()
			saveButton.Parent, saveButton.Name, saveButton['object.name'].Text = Settings.Saves, v.Pos, '   ' .. (v.Name or 'error')

			sharedValues['customTypes'][saveButton] = {Func = saveAnimation, Data = {v.Id, true}, Type = 2, Close  = closeSave}
		end
	end
end

local function setupSettings(settingsTable, Parent)
	Connections['Saves'] = Tab.Saves.MouseButton1Down:Connect(function()
		Settings.Visible, ConvetUi.Visible = ConvetUi.Visible, Settings.Visible

		loadSaves(ConvetUi.Visible)
	end)

	for cName, cV in pairs(settingsTable) do
		if cV.Show then
			local header = Assets.Settings.header:Clone()
			header.Text, header.Parent = '==' .. tostring(cV.Header) .. '==', Parent
		end

		for name, v in pairs(cV.Content) do
			local ui = Assets.Settings.Settings_Frame:Clone()

			local type_Button = Assets.Settings[v.Toggle and 'toggle' or 'icon']:Clone()
			local type_Name = Assets.Settings[v.Desc == '%textbox%' and 'InputFrame' or 'desc']:Clone()

			ui.name.Text, type_Button.Visible = v.Name or name, not v.Toggle and true or Config[v.Toggle]

			if v.Desc ~= '%textbox%' then 
				type_Name.Text, textSize = v.Desc, TextService:GetTextSize(v.Desc, 14, Enum.Font.SourceSansItalic, Vector2.new(221, 221))

				type_Name.Size = UDim2.new(0, 221, 0, math.clamp(textSize.Y, 16, 300) + 1)
				ui.Size = UDim2.new(0, 221, 0, 21 + type_Name.Size.Y.Offset)
			end

			Connections[name] = ui.button.MouseButton1Down:connect(function()
				if v.Toggle then
					Config[v.Toggle], type_Button.Visible = not Config[v.Toggle], not Config[v.Toggle]
				else
					settingsClass:init(v.Func, Selection:Get())
				end
			end)

			if type_Name:FindFirstChild('Input') then
				type_Name:FindFirstChild('Input'):GetPropertyChangedSignal("Text"):Connect(function()
					type_Name:FindFirstChild('Input').TextScaled = #type_Name:FindFirstChild('Input').Text >= 35
				end)
			end

			type_Button.Parent, type_Name.Parent, ui.Parent = ui.button, ui.name, Parent
		end	

		if cV.Spacer then Assets.Space:Clone().Parent = Parent end
	end
end

function uiMessage(message, Option, id)
	query.Bool, idCheck = false, math.random(0, 100000)

	if id and id ~= idCheck then
		return
	elseif type(Option) == 'number' then
		task.delay(Option, uiMessage, '', idCheck)
	elseif tostring(Option) == 'query' then
		query.Bool, query.Count, query.Message, WaitCooldown = true, 0, message, tick()
	end

	Tab.Tag.Text = defaultText .. (#message > 1 and ' | ' or '') .. message	
end

--#Update vals
folderName, Gui.Name = string.sub(HttpService:GenerateGUID(false), 1, 16), string.sub(HttpService:GenerateGUID(false), 1, 16)
table_Body = Utils.Combine(Utils.getDescendantsByClass(script.DummyR15, 'BasePart', 'special', 'R15'), Utils.getDescendantsByClass(script.DummyR6, 'BasePart', 'special', 'R6'))

--#Connections
Connections['Input'] = Input:GetPropertyChangedSignal("Text"):Connect(function()
	wait(.1)

	if formatText(Input.Text) ~= lastText then
		local Input = formatText(Input.Text); Reset()
		local mrkData = getMarketData(Input)
		lastText, textData['item_detail'].Ui.Text = Input, Input ~= '' and (not mrkData and 'Failed to grab object' or mrkData and 'Object is not a valid animation') or ''

		if mrkData and mrkData.AssetTypeId == 24 then
			local rand = math.random(80000, 100000)	
			textData['item_detail'].Ui.Text = ''
			currentObject = grabAnimation(Input, mrkData.Name)

			if not currentObject then
				textData['item_detail'].Ui.Text = 'Failed to grab animation'; return print'Failed to grab animation'
			end

			Utils.destroyItem({workspace.CurrentCamera:FindFirstChild(folderName)})

			currentFolder, textData['rig'].Name = Instance.new("Folder", workspace.CurrentCamera), Utils.getDescendantsByClass(currentObject, 'Any', 'special', table_Body, nil, nil, 40); 
			currentObject.Parent, currentFolder.Name = currentFolder, folderName

			Utils.sortTable(textData, mrkData)
			
			local sizeText = #textData['item_detail'].Name >= 70
			textData['item_detail'].Ui.TextScaled, textData['item_detail'].Ui.TextWrapped = sizeText, sizeText

			if not Config['Disable Preview'] then
				currentRig = script:WaitForChild('Dummy' .. textData['rig'].Name):Clone()
				currentRig.HumanoidRootPart.CFrame, currentRig.Parent = CFrame.new(rand, rand / 10, rand), currentFolder

				viewrig(currentRig, currentObject)
				ChangeService:SetEnabled(true); ChangeService:SetWaypoint(currentRig)	
			end
		end
	end
end)

Connections['copyButton'] = Copy.MouseButton1Down:connect(function()
	if getMarketData(lastText, true).AssetTypeId == 24 and currentObject then
		saveAnimation()
	end
end)

Connections['pluginButton'] = button.Click:connect(function()
	Gui.Parent, Input.Text = Gui.Parent == script and UIParent or script, ''
	connectionHandler({{Name = 'Heartbeat', Type = RunService.Heartbeat, Func = Heartbeat}, {Name = 'Selection', Type = Selection.SelectionChanged, Func = SelectionF}, {Name = 'InputChanged', Type = UserInputService.InputChanged, Func = InputChanged}, {Name = 'InputEnded', Type = UserInputService.InputEnded, Func = InputEnded}}, Gui.Parent == UIParent)
	
	--#Save settings
	for name, bool in pairs(Config) do
		plugin:SetSetting(name, bool)
	end
end)

Utils.setValues({{'Mouse', Mouse}, {'Main Frame', Settings}, {'UIParent', UIParent}, {'sharedValues', sharedValues}})
Utils.createDraggable(Tab, Main_Ui)

Utils.createCustomScroll(Settings.Saves)
Utils.createCustomScroll(Settings.Details.Settings)

Tab.Tag.Text, versionFrame.Text = defaultText, getMarketData(2537608092, true).Description:find(Version_Id) and Version_Id or 'Running old version | '..Version_Id
setupSettings(settingsTable, Settings.Details.Settings)

Config['Ranv2'] = true; print("Loaded Cajuns Animation Spoofer v2")