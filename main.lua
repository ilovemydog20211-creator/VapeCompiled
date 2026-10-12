repeat task.wait() until game:IsLoaded()

if shared.VapeKeyAuthorized ~= true then
	local promptParent = (gethui and gethui()) or game:GetService('CoreGui')

	local previousPrompt = promptParent:FindFirstChild('VapeKeyPrompt')
	if previousPrompt then
		previousPrompt:Destroy()
	end

	local screenGui = Instance.new('ScreenGui')
	screenGui.Name = 'VapeKeyPrompt'
	screenGui.DisplayOrder = 10000
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = promptParent

	local frame = Instance.new('Frame')
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(320, 180)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new('TextLabel')
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(20, 14)
	title.Size = UDim2.new(1, -40, 0, 28)
	title.Font = Enum.Font.GothamBold
	title.Text = 'Enter key to continue'
	title.TextColor3 = Color3.fromRGB(245, 245, 250)
	title.TextSize = 18
	title.Parent = frame

	local keyBox = Instance.new('TextBox')
	keyBox.Position = UDim2.fromOffset(20, 56)
	keyBox.Size = UDim2.new(1, -40, 0, 38)
	keyBox.BackgroundColor3 = Color3.fromRGB(43, 43, 51)
	keyBox.BorderSizePixel = 0
	keyBox.ClearTextOnFocus = false
	keyBox.Font = Enum.Font.Gotham
	keyBox.PlaceholderText = 'Key'
	keyBox.Text = ''
	keyBox.TextColor3 = Color3.fromRGB(245, 245, 250)
	keyBox.TextSize = 16
	keyBox.Parent = frame

	local keyBoxCorner = Instance.new('UICorner')
	keyBoxCorner.CornerRadius = UDim.new(0, 6)
	keyBoxCorner.Parent = keyBox

	local status = Instance.new('TextLabel')
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(20, 98)
	status.Size = UDim2.new(1, -40, 0, 20)
	status.Font = Enum.Font.Gotham
	status.Text = ''
	status.TextColor3 = Color3.fromRGB(255, 100, 100)
	status.TextSize = 13
	status.Parent = frame

	local submit = Instance.new('TextButton')
	submit.Position = UDim2.fromOffset(20, 126)
	submit.Size = UDim2.new(1, -40, 0, 38)
	submit.BackgroundColor3 = Color3.fromRGB(70, 120, 220)
	submit.BorderSizePixel = 0
	submit.Font = Enum.Font.GothamBold
	submit.Text = 'Unlock'
	submit.TextColor3 = Color3.fromRGB(255, 255, 255)
	submit.TextSize = 15
	submit.Parent = frame

	local submitCorner = Instance.new('UICorner')
	submitCorner.CornerRadius = UDim.new(0, 6)
	submitCorner.Parent = submit

	local function checkKey()
		if keyBox.Text == '3971' then
			shared.VapeKeyAuthorized = true
			screenGui:Destroy()
		else
			status.Text = 'Incorrect key. Try again or just ask the owner u jobless bastered.'
			keyBox.Text = ''
			keyBox:CaptureFocus()
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
