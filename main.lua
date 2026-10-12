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

	local snowLayer = Instance.new('Frame')
	snowLayer.Name = 'Snowfall'
	snowLayer.Size = UDim2.fromScale(1, 1)
	snowLayer.BackgroundTransparency = 1
	snowLayer.BorderSizePixel = 0
	snowLayer.Active = false
	snowLayer.Parent = backdrop

	local dismissed = false
	local snowRandom = Random.new()
	for _ = 1, 96 do
		task.spawn(function()
			local snowflake = Instance.new('Frame')
			snowflake.AnchorPoint = Vector2.new(0.5, 0.5)
			snowflake.BackgroundColor3 = Color3.fromRGB(214, 231, 255)
			snowflake.BackgroundTransparency = snowRandom:NextNumber(0.12, 0.48)
			snowflake.BorderSizePixel = 0
			local flakeSize = snowRandom:NextInteger(2, 6)
			snowflake.Size = UDim2.fromOffset(flakeSize, flakeSize)
			snowflake.Rotation = snowRandom:NextInteger(0, 45)
			snowflake.Parent = snowLayer

			local snowCorner = Instance.new('UICorner')
			snowCorner.CornerRadius = UDim.new(1, 0)
			snowCorner.Parent = snowflake

			while screenGui.Parent and not dismissed do
				local startX = snowRandom:NextNumber(0, 1)
				local endX = math.clamp(startX + snowRandom:NextNumber(-0.2, 0.2), 0, 1)
				snowflake.Position = UDim2.fromScale(startX, -0.04)
				snowflake.BackgroundTransparency = snowRandom:NextNumber(0.12, 0.48)
				local fall = tweenService:Create(
					snowflake,
					TweenInfo.new(snowRandom:NextNumber(3, 7), Enum.EasingStyle.Linear),
					{
						Position = UDim2.fromScale(endX, 1.05),
						Rotation = snowflake.Rotation + 180,
						BackgroundTransparency = 0.85
					}
				)
				fall:Play()
				fall.Completed:Wait()
				task.wait(snowRandom:NextNumber(0, 1.5))
			end

			snowflake:Destroy()
		end)
	end

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
	badgeText.Text = 'ZV'
	badgeText.TextColor3 = Color3.fromRGB(133, 179, 255)
	badgeText.TextSize = 15
	badgeText.Parent = badge

	local title = Instance.new('TextLabel')
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(78, 23)
	title.Size = UDim2.new(1, -102, 0, 26)
	title.Font = Enum.Font.GothamBold
	title.Text = 'zachv4 | Welcome back'
	title.TextColor3 = Color3.fromRGB(244, 246, 255)
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local closeButton = Instance.new('TextButton')
	closeButton.Name = 'Close'
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -16, 0, 18)
	closeButton.Size = UDim2.fromOffset(30, 30)
	closeButton.BackgroundColor3 = Color3.fromRGB(34, 39, 53)
	closeButton.BorderSizePixel = 0
	closeButton.AutoButtonColor = false
	closeButton.Font = Enum.Font.Gotham
	closeButton.Text = 'X'
	closeButton.TextColor3 = Color3.fromRGB(163, 172, 193)
	closeButton.TextSize = 16
	closeButton.Parent = frame

	local closeCorner = Instance.new('UICorner')
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton

	local closeScale = Instance.new('UIScale')
	closeScale.Parent = closeButton

	local subtitle = Instance.new('TextLabel')
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromOffset(79, 51)
	subtitle.Size = UDim2.new(1, -103, 0, 18)
	subtitle.Font = Enum.Font.Gotham
	subtitle.Text = 'Enter your zachv4 access key to continue'
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

	closeButton.MouseEnter:Connect(function()
		tween(closeButton, 0.16, {BackgroundColor3 = Color3.fromRGB(142, 55, 72), TextColor3 = Color3.fromRGB(255, 255, 255)})
		tween(closeScale, 0.16, {Scale = 1.1})
	end)
	closeButton.MouseLeave:Connect(function()
		tween(closeButton, 0.16, {BackgroundColor3 = Color3.fromRGB(34, 39, 53), TextColor3 = Color3.fromRGB(163, 172, 193)})
		tween(closeScale, 0.16, {Scale = 1})
	end)

	local function closePrompt()
		if dismissed or shared.VapeKeyAuthorized == true then return end
		dismissed = true
		closeButton.Active = false
		tween(backdrop, 0.24, {BackgroundTransparency = 1})
		tween(panelScale, 0.24, {Scale = 0.86}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.25)
		screenGui:Destroy()
	end

	closeButton.Activated:Connect(closePrompt)

	local checking = false
	local function validateAccessKey(key)
		local apiUrl = shared.VapeKeyApiUrl or 'http://fi16.bot-hosting.cloud:26061'

		local httpRequest = request or http_request or (syn and syn.request)
		if type(httpRequest) ~= 'function' then
			return false, 'This executor does not support HTTP requests.'
		end

		local httpService = game:GetService('HttpService')
		local success, response = pcall(httpRequest, {
			Url = apiUrl:gsub('/+$', '')..'/validate',
			Method = 'POST',
			Headers = {['Content-Type'] = 'application/json'},
			Body = httpService:JSONEncode({key = key})
		})
		if not success then
			return false, 'Could not reach the key service. Try again.'
		end
		if type(response) ~= 'table' then
			return false, 'The key service returned an invalid response.'
		end

		local statusCode = tonumber(response.StatusCode or response.Status)
		if statusCode ~= 200 then
			if statusCode == 429 then
				return false, 'Too many attempts. Wait a minute and try again.'
			end
			return false, 'The key service is unavailable. Try again later.'
		end

		local decoded, payload = pcall(function()
			return httpService:JSONDecode(response.Body or response.body or '')
		end)
		if not decoded or type(payload) ~= 'table' or type(payload.valid) ~= 'boolean' then
			return false, 'The key service returned an invalid response.'
		end
		if payload.valid then
			return true
		end
		return false, 'Invalid or revoked key.'
	end

	local function checkKey()
		if checking or dismissed then return end
		checking = true

		status.TextColor3 = Color3.fromRGB(150, 190, 255)
		status.Text = 'Checking key...'
		submit.Text = 'Checking...'
		submit.Active = false
		local valid, message = validateAccessKey(keyBox.Text:match('^%s*(.-)%s*$'))
		if dismissed then
			checking = false
			return
		end

		if valid then
			status.TextColor3 = Color3.fromRGB(104, 226, 166)
			status.Text = 'Access granted.'
			submit.Text = 'Unlocked'
			tween(panelStroke, 0.18, {Color = Color3.fromRGB(104, 226, 166), Transparency = 0})
			tween(panelScale, 0.2, {Scale = 1.03})
			task.wait(0.2)
			if dismissed then return end
			shared.VapeKeyAuthorized = true
			screenGui:Destroy()
		else
			status.TextColor3 = Color3.fromRGB(255, 100, 100)
			status.Text = message
			keyBox.Text = ''
			keyBox:CaptureFocus()
			submit.Text = 'Unlock'
			submit.Active = true
			local center = frame.Position
			for _, offset in {-9, 9, -6, 6, 0} do
				local animation = tween(frame, 0.045, {Position = center + UDim2.fromOffset(offset, 0)})
				animation.Completed:Wait()
				if dismissed then break end
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

	repeat task.wait() until shared.VapeKeyAuthorized == true or dismissed
	if dismissed then return end
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
