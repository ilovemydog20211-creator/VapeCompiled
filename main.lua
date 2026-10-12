repeat task.wait() until game:IsLoaded()

if shared.VapeKeyAuthorized ~= true then
	local promptParent = (gethui and gethui()) or game:GetService('CoreGui')
	local tweenService = game:GetService('TweenService')

	local previousPrompt = promptParent:FindFirstChild('VapeKeyPrompt')
	if previousPrompt then
		previousPrompt:Destroy()
	end

	local screenGui = Instance.new('ScreenGui')
	screenGui.Name = 'VapeKeyPrompt'
	screenGui.DisplayOrder = 10000
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = promptParent

	local backdrop = Instance.new('Frame')
	backdrop.Name = 'Backdrop'
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(5, 8, 15)
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.Parent = screenGui

	local frame = Instance.new('Frame')
	frame.Name = 'Panel'
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(360, 250)
	frame.BackgroundColor3 = Color3.fromRGB(19, 22, 31)
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local panelStroke = Instance.new('UIStroke')
	panelStroke.Color = Color3.fromRGB(72, 83, 112)
	panelStroke.Transparency = 0.35
	panelStroke.Thickness = 1
	panelStroke.Parent = frame

	local panelScale = Instance.new('UIScale')
	panelScale.Scale = 0.88
	panelScale.Parent = frame

	local accent = Instance.new('Frame')
	accent.Name = 'Accent'
	accent.Position = UDim2.fromOffset(24, 82)
	accent.Size = UDim2.new(1, -48, 0, 2)
	accent.BackgroundColor3 = Color3.fromRGB(91, 130, 255)
	accent.BorderSizePixel = 0
	accent.Parent = frame

	local accentGradient = Instance.new('UIGradient')
	accentGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(76, 211, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(113, 107, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(76, 211, 255))
	})
	accentGradient.Parent = accent

	local badge = Instance.new('Frame')
	badge.Position = UDim2.fromOffset(24, 23)
	badge.Size = UDim2.fromOffset(42, 42)
	badge.BackgroundColor3 = Color3.fromRGB(37, 48, 78)
	badge.BorderSizePixel = 0
	badge.Parent = frame

	local badgeCorner = Instance.new('UICorner')
	badgeCorner.CornerRadius = UDim.new(0, 10)
	badgeCorner.Parent = badge

	local badgeText = Instance.new('TextLabel')
	badgeText.BackgroundTransparency = 1
	badgeText.Size = UDim2.fromScale(1, 1)
	badgeText.Font = Enum.Font.GothamBold
	badgeText.Text = 'VC'
	badgeText.TextColor3 = Color3.fromRGB(133, 179, 255)
	badgeText.TextSize = 15
	badgeText.Parent = badge

	local title = Instance.new('TextLabel')
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(78, 23)
	title.Size = UDim2.new(1, -102, 0, 26)
	title.Font = Enum.Font.GothamBold
	title.Text = 'Welcome back'
	title.TextColor3 = Color3.fromRGB(244, 246, 255)
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local subtitle = Instance.new('TextLabel')
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromOffset(79, 51)
	subtitle.Size = UDim2.new(1, -103, 0, 18)
	subtitle.Font = Enum.Font.Gotham
	subtitle.Text = 'Enter your access key to continue'
	subtitle.TextColor3 = Color3.fromRGB(145, 153, 174)
	subtitle.TextSize = 12
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Parent = frame

	local keyLabel = Instance.new('TextLabel')
	keyLabel.BackgroundTransparency = 1
	keyLabel.Position = UDim2.fromOffset(24, 101)
	keyLabel.Size = UDim2.new(1, -48, 0, 16)
	keyLabel.Font = Enum.Font.GothamMedium
	keyLabel.Text = 'ACCESS KEY'
	keyLabel.TextColor3 = Color3.fromRGB(180, 188, 207)
	keyLabel.TextSize = 11
	keyLabel.TextXAlignment = Enum.TextXAlignment.Left
	keyLabel.Parent = frame

	local keyBox = Instance.new('TextBox')
	keyBox.Position = UDim2.fromOffset(24, 123)
	keyBox.Size = UDim2.new(1, -48, 0, 42)
	keyBox.BackgroundColor3 = Color3.fromRGB(27, 31, 43)
	keyBox.BorderSizePixel = 0
	keyBox.ClearTextOnFocus = false
	keyBox.Font = Enum.Font.Gotham
	keyBox.PlaceholderText = 'Enter key...'
	keyBox.Text = ''
	keyBox.TextColor3 = Color3.fromRGB(239, 242, 252)
	keyBox.PlaceholderColor3 = Color3.fromRGB(111, 120, 142)
	keyBox.TextSize = 15
	keyBox.TextXAlignment = Enum.TextXAlignment.Left
	keyBox.Parent = frame

	local keyBoxCorner = Instance.new('UICorner')
	keyBoxCorner.CornerRadius = UDim.new(0, 7)
	keyBoxCorner.Parent = keyBox

	local keyBoxPadding = Instance.new('UIPadding')
	keyBoxPadding.PaddingLeft = UDim.new(0, 13)
	keyBoxPadding.Parent = keyBox

	local inputStroke = Instance.new('UIStroke')
	inputStroke.Color = Color3.fromRGB(53, 61, 81)
	inputStroke.Transparency = 0.15
	inputStroke.Thickness = 1
	inputStroke.Parent = keyBox

	local status = Instance.new('TextLabel')
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(24, 169)
	status.Size = UDim2.new(1, -48, 0, 18)
	status.Font = Enum.Font.Gotham
	status.Text = ''
	status.TextColor3 = Color3.fromRGB(255, 100, 100)
	status.TextSize = 12
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = frame

	local submit = Instance.new('TextButton')
	submit.Position = UDim2.fromOffset(24, 198)
	submit.Size = UDim2.new(1, -48, 0, 40)
	submit.BackgroundColor3 = Color3.fromRGB(91, 130, 255)
	submit.BorderSizePixel = 0
	submit.Font = Enum.Font.GothamBold
	submit.Text = 'Unlock'
	submit.TextColor3 = Color3.fromRGB(255, 255, 255)
	submit.TextSize = 14
	submit.Parent = frame

	local submitCorner = Instance.new('UICorner')
	submitCorner.CornerRadius = UDim.new(0, 7)
	submitCorner.Parent = submit

	local submitGradient = Instance.new('UIGradient')
	submitGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(69, 143, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(126, 91, 255))
	})
	submitGradient.Parent = submit

	local function tween(instance, duration, properties, style, direction)
		local animation = tweenService:Create(
			instance,
			TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
			properties
		)
		animation:Play()
		return animation
	end

	tween(backdrop, 0.3, {BackgroundTransparency = 0.42})
	tween(panelScale, 0.42, {Scale = 1}, Enum.EasingStyle.Back)
	tween(panelStroke, 0.4, {Transparency = 0.12})
	local accentAnimation = tweenService:Create(
		accentGradient,
		TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{Rotation = 360}
	)
	accentAnimation:Play()

	keyBox.Focused:Connect(function()
		tween(inputStroke, 0.18, {Color = Color3.fromRGB(100, 157, 255), Transparency = 0})
	end)
	keyBox.FocusLost:Connect(function()
		tween(inputStroke, 0.18, {Color = Color3.fromRGB(53, 61, 81), Transparency = 0.15})
	end)

	submit.MouseEnter:Connect(function()
		tween(submit, 0.16, {BackgroundColor3 = Color3.fromRGB(112, 147, 255)})
	end)
	submit.MouseLeave:Connect(function()
		tween(submit, 0.16, {BackgroundColor3 = Color3.fromRGB(91, 130, 255)})
	end)

	local checking = false
	local function checkKey()
		if checking then return end
		checking = true

		if keyBox.Text == '3971' then
			status.TextColor3 = Color3.fromRGB(104, 226, 166)
			status.Text = 'Access granted.'
			submit.Text = 'Unlocked'
			tween(panelStroke, 0.18, {Color = Color3.fromRGB(104, 226, 166), Transparency = 0})
			tween(panelScale, 0.2, {Scale = 1.03})
			task.wait(0.2)
			shared.VapeKeyAuthorized = true
			screenGui:Destroy()
		else
			status.Text = 'Incorrect key. Try again or just ask the owner u jobless bastered.'
			keyBox.Text = ''
			keyBox:CaptureFocus()
			local center = frame.Position
			for _, offset in {-9, 9, -6, 6, 0} do
				local animation = tween(frame, 0.045, {Position = center + UDim2.fromOffset(offset, 0)})
				animation.Completed:Wait()
			end
			checking = false
		end
	end

	submit.Activated:Connect(checkKey)
	keyBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			checkKey()
		end
	end)

	repeat task.wait() until shared.VapeKeyAuthorized == true
end

if shared.vape then shared.vape:Uninject() end

local vape
local _loadstring = loadstring
local loadstring = function(...)
	local res, err
	if type(_loadstring) == 'function' then
		res, err = _loadstring(...)
	else
		error('loadstring is unavailable in this environment')
	end
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/ilovemydog20211-creator/VapeCompiled/'..readfile('newvape/profiles/commit.txt')..'/'..select(1, path:gsub('newvape/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function finishLoading()
	vape.Init = nil
	vape:Load()
	task.spawn(function()
		repeat
			vape:Save()
			task.wait(10)
		until not vape.Loaded
	end)

	local teleportedServers
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if (not teleportedServers) and (not shared.VapeIndependent) then
			teleportedServers = true
			local teleportScript = [[
				shared.VapeKeyAuthorized = true
				shared.vapereload = true
				if shared.VapeDeveloper then
					loadstring(readfile('newvape/loader.lua'), 'loader')()
				else
					loadstring(game:HttpGet('https://raw.githubusercontent.com/ilovemydog20211-creator/VapeCompiled/'..readfile('newvape/profiles/commit.txt')..'/loader.lua', true), 'loader')()
				end
			]]

			if shared.VapeDeveloper then
				teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
			end

			if shared.VapeCustomProfile then
				teleportScript = 'shared.VapeCustomProfile = "'..shared.VapeCustomProfile..'"\n'..teleportScript
			end

			vape:Save()
			queue_on_teleport(teleportScript)
		end
	end))

	if not shared.vapereload then
		if not vape.Categories then return end
		if vape.Settings.GUI.Options['GUI bind indicator'].Enabled then
			vape:CreateNotification('Finished Loading', vape.VapeButton and 'Press the button in the top right to open GUI' or 'Press '..table.concat(vape.GUIBind.Keys, ' + '):upper()..' to open GUI', 5)
		end
	end
end

if not isfile('newvape/profiles/gui.txt') then
	writefile('newvape/profiles/gui.txt', 'new')
end
local gui = 'new'--readfile('newvape/profiles/gui.txt')

if not isfolder('newvape/assets/'..gui) then
	makefolder('newvape/assets/'..gui)
end
vape = loadstring(downloadFile('newvape/guis/'..gui..'.lua'), 'gui')()
shared.vape = vape

if not shared.VapeIndependent then
	loadstring(downloadFile('newvape/games/universal.lua'), 'universal')()
	if isfile('newvape/games/'..game.PlaceId..'.lua') then
		loadstring(readfile('newvape/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(...)
	else
		if not shared.VapeDeveloper then
			local success, data = pcall(downloadFile, 'newvape/games/'..game.PlaceId..'.lua')
			if success then
				loadstring(data, tostring(game.PlaceId))(...)
			end
		end
	end
	finishLoading()
else
	vape.Init = finishLoading
	return vape
end
