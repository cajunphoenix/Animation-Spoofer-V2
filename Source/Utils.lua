local module, values = {}, {}
local TS = game:GetService('TweenService')
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService('RunService')

local Letters ={"a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"}
local Numbers ={"1","2","3","4","5","6","7","8","9","0"}

local blacklistParts = {
	['Head'] = true, ['HumanoidRootPart'] = true
}

--#Main functions
function modifyFrame(position, Modify, Scale, Clamp, Tweeninfo)
	do
		Tweeninfo, Scale, Clamp, values['sharedValues']['FocusLost'] = Tweeninfo or TweenInfo.new(.05, Enum.EasingStyle.Quad), Scale or {0, 0}, Clamp or {{-2e9, 2e9}, {-2e9, 2e9}}, false
		local saveM = Modify[1][Modify[2]]

		while not values['sharedValues']['FocusLost'] do task.wait()
			TS:Create(Modify[1], Tweeninfo, {[Modify[2]] = UDim2.new(Scale[1], math.clamp((saveM.X.Offset + (values['Mouse'].X - position.X)), Clamp[1][1], Clamp[1][2]), Scale[2], math.clamp((saveM.Y.Offset + (values['Mouse'].Y - position.Y)), Clamp[2][1], Clamp[2][2]))}):Play();
		end
	end
end

--#Module Functions
function module.setValues(Tbl)
	for _, v in pairs(Tbl) do
		values[v[1]] = v[2]
	end	
end

function module.Combine(Tbl1, Tbl2)
	Tbl1 = Tbl1 or {}
	
	for name, v in pairs(Tbl2) do
		Tbl1[name] =v
	end
	
	return Tbl1
end

function module.getDescendantsByClass(Obj:Instance, ClassName:string, returnString:BoolValue, findRig, customLimit)
	local format, type_, counter, custom = {}, tostring(returnString), 0, typeof(findRig) == 'string' and findRig

	for i, int in pairs(Obj:GetDescendants()) do
		counter += 1

		if counter >= (customLimit or 60) then --Stops lag spikes from big animations
			counter = 0; RunService.Heartbeat:Wait()
		end

		if (type_ == 'normal' and int.ClassName == ClassName) or type_ ~= 'normal' and int:IsA(ClassName) or ClassName == 'Any' then
			if not custom and findRig and not blacklistParts[int.Name] and (findRig[int.Name]) then
				return findRig[int.Name]
			else
				format[int.Name] = type_ == 'special' and (custom or true) or (table.insert(format, type_ == 'normal' and int or type_ == 'single' and (custom or int.Name) or {int.Parent.Name, returnString and int.Name or int}) and nil) or nil
			end
		end
	end

	return not custom and findRig and 'R6' or format
end

function module.destroyItem(tbl, Set:BoolValue)
	if not tbl then
		print('Failed to find table'); return
	end

	for i = 1, #tbl do
		tbl[i] = type(tbl[i]) == 'table' and (tbl[i][1]:FindFirstChild(tbl[i][2]) or nil) or type(tbl[i]) ~= 'table' and tbl[i]

		if tbl[i] then
			tbl[i]:Destroy(); tbl[i] = nil
		end
	end
end

function module.sortTable(Tbl, Set:BoolValue)
	for i, v in pairs(Tbl) do
		local strFind = Tbl[i].Name:split('$T')[2]
		local output =  Set and (Tbl[i].Ignore and Tbl[i].Name or Set[Tbl[i].Type or '']) or strFind and Tbl[strFind] or ''

		Tbl[i].Name = Set and Tbl[i].err and output == '' and Tbl[i].err or output

		if Tbl[i].Ui then Tbl[i].Ui.Text = Tbl[i].Name end
	end
end

function module.findType(Tbl, Type, Check, data)
	for pos, v in pairs(Tbl) do
		if (type(v) == 'table' and v[Type] and v[Type] == Check) or tostring(Type) == '%Index' and v == Check then
			return (typeof(data) == 'string' and data == 'pos' and pos or data and v) or true
		end
	end

	return false
end

function module.createCustomScroll(Parent, customPixel) --#Its just that shrimple
	customPixel = customPixel or ((Parent.Size.Y.Offset / 5))
	
	local Frame = Instance.new('Frame', Parent.Parent)
	Frame.Name = Parent.Name .. '_%Scroll'
	Frame.Active, Frame.BackgroundTransparency, Frame.Position, Frame.Size = true, 1, Parent.Position, Parent.Size
	
	values['sharedValues']['customTypes'][Frame] = {Set = Parent, Type = 1, Pixel = customPixel}
end


function module.createDraggable(Main, Parent)
	Main.MouseButton1Down:connect(function()
		modifyFrame(Vector2.new(values['Mouse'].X, values['Mouse'].Y), {Parent, 'Position'}, {.5, .5})
	end)
end

return module