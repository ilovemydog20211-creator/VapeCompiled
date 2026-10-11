-- bedwars ingame

local _runCount = 0
local _runBusy = false
local run = function(func)
	if not _runBusy then
		_runBusy = true
		_runCount = _runCount + 1
		if _runCount % 8 == 0 then
			task.wait()
		end
		local ok, err = pcall(func)
		_runBusy = false
		if not ok then
			warn('[niggawear] module failed to load: ' .. tostring(err))
		end
		return
	end
	local ok, err = pcall(func)
	if not ok then
		warn('[niggawear] module failed to load: ' .. tostring(err))
	end
end
task.wait()
local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})
getgenv().vapeEvents = vapeEvents

local cloneref = cloneref or function(obj)
	return obj
end

local function safeGetProto(func, index)
    if not func then return nil end
    local success, proto = pcall(debug.getconstant, func, index)
    if success then
        return proto
    end
end

local inventoryDebounce = false
local function fireInventoryChanged()
    if inventoryDebounce then return end
    inventoryDebounce = true
    task.spawn(function()
        task.wait() 
        vapeEvents.InventoryChanged:Fire()
        inventoryDebounce = false
    end)
end

local playersService = cloneref(game:GetService('Players'))
local collectionService = cloneref(game:GetService('CollectionService'))
local function getLocalKits()
	local raw = playersService.LocalPlayer:GetAttribute('PlayingAsKits')
	local list = {}
	if type(raw) == 'string' then
		for kit in raw:gmatch('[%w_]+') do
			if kit ~= '' and kit ~= 'none' then
				table.insert(list, kit)
			end
		end
	end
	return list
end
getgenv().aeroTeamColors = {
	[1] = {name = 'blue',   color = Color3.fromRGB(85, 150, 255)},
	[2] = {name = 'orange', color = Color3.fromRGB(255, 150, 50)},
	[3] = {name = 'pink',   color = Color3.fromRGB(255, 100, 200)},
	[4] = {name = 'yellow', color = Color3.fromRGB(255, 255, 50)},
	[5] = {name = 'brown',  color = Color3.fromRGB(139, 69, 19)},  
	[6] = {name = 'white',  color = Color3.fromRGB(255, 255, 255)}, 
	[7] = {name = 'cyan',   color = Color3.fromRGB(120, 255, 255)}, 
	[8] = {name = 'purple', color = Color3.fromRGB(180, 90, 255)},  
}
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local httpService = cloneref(game:GetService('HttpService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local collectionService = cloneref(game:GetService('CollectionService'))
local contextActionService = cloneref(game:GetService('ContextActionService'))
local guiService = cloneref(game:GetService('GuiService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local starterGui = cloneref(game:GetService('StarterGui'))
local VirtualInputManager = game:GetService("VirtualInputManager")
local lightingService = cloneref(game:GetService('Lighting'))

local isnetworkowner = identifyexecutor and table.find({'Delta', 'Volt'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
if vape and not vape.Clean then
	vape.Clean = function(self, conn)
		if not conn then return end
		
		if not vape.Connections then
			vape.Connections = {}
		end

		if self and self.Enabled then
			vape.Connections[conn] = true
			return conn
		else
			if vape.Connections[conn] then
				if typeof(conn) == "RBXScriptConnection" then
					pcall(conn.Disconnect, conn)
				end
				vape.Connections[conn] = nil
			end
		end
	end
end
if vape and not vape.Remove then
    vape.Remove = function(module) 
		return module 
	end
end
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local uipallet = vape.Libraries.uipallet
local tween = vape.Libraries.tween
local color = vape.Libraries.color
local whitelist = { get = function() return nil, true end, tag = function() return '' end, customtags = {} }
local prediction = vape.Libraries.prediction
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local store = {
    attackReach = 0,
    attackReachUpdate = tick(),
    hand = {},
    inventory = {
        inventory = {
            items = {},
            armor = {}
        },
        hotbar = {}
    },
    inventories = setmetatable({}, { __mode = "k" }), 
    matchState = 0,
    queueType = 'bedwars_test',
    tools = {},
    lastToolUpdate = 0,
	lastKrystalUpdateCheck = 0,
	BedAlarmNotifyTick = 0,
	BedAlarmIsTrigged = false,
	BedAlarmHighlightedEnimes = {},
	BedAlarm = {},
	BedAlarmSoundTick = 0,
	silasAbilityTime = 0,
	terraStompTime = 0,
	terraKickTime = 0,
}
getgenv().store = store
local Reach = {}
local HitBoxes = {}
local TrapDisabler
local AntiFallPart
local bedwars, remotes, sides, oldinvrender, oldSwing = {}, {}, {}, {}, {}

local function getReach(tool)
	local itemMeta = tool and bedwars.ItemMeta and bedwars.ItemMeta[tool.Name]
	return itemMeta and itemMeta.sword and itemMeta.sword.attackRange or 14.4
end
getgenv().getReach = getReach

local _missingRemotes = {}
setmetatable(remotes, {
	__index = function(_, key)
		if not _missingRemotes[key] then
			_missingRemotes[key] = true
			task.delay(10, function()
				if rawget(remotes, key) == nil then
					pcall(function()
						vape.Notify('[aerov4] remote "' .. tostring(key) .. '" changed or removed some features may not work bru (dm @5qvx for fix)', 6)
					end)
				end
			end)
		end
		return nil
	end
})
local originalKnit

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getcustomasset('aerov4/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local readyGate = getgenv().aeroReadyGate or {}
getgenv().aeroReadyGate = readyGate

function readyGate.Release()
	if not readyGate.Held then
		return
	end
	readyGate.Held = false
	local heldRemote = readyGate.Remote
	readyGate.Remote = nil
	if heldRemote then
		heldRemote:FireServer()
	end
end

if not readyGate.Hooked and hookmetamethod and not lplr:GetAttribute('PlayerConnected') then
	readyGate.Hooked = true
	readyGate.Held = true
	readyGate.Started = os.clock()
	local wrap = newcclosure or function(f) return f end
	local oldNamecall
	oldNamecall = hookmetamethod(game, '__namecall', wrap(function(...)
		local self = ...
		if readyGate.Held and not checkcaller() and getnamecallmethod() == 'FireServer' and tostring(self) == 'PlayerReady' then
			readyGate.Remote = self
			return
		end
		return oldNamecall(...)
	end))
	task.delay(45, function()
		if not readyGate.Claimed then
			readyGate.Release()
		end
	end)
end
vape:Clean(function()
	readyGate.Release()
end)

local function notif(...) return
	vape:CreateNotification(...)
end

local function collection(tags, module, customadd, customremove)
	tags = typeof(tags) ~= 'table' and {tags} or tags
	local objs, connections = {}, {}

	for _, tag in tags do
		table.insert(connections, collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			if customadd then
				customadd(objs, v, tag)
				return
			end
			table.insert(objs, v)
		end))
		table.insert(connections, collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if customremove then
				customremove(objs, v, tag)
				return
			end
			local idx = table.find(objs, v)
			if idx then
				local last = #objs
				objs[idx] = objs[last]
				objs[last] = nil
			end
		end))

		for _, v in collectionService:GetTagged(tag) do
			if customadd then
				customadd(objs, v, tag)
				continue
			end
			table.insert(objs, v)
		end
	end

	local cleanFunc = function(self)
		for _, v in connections do
			v:Disconnect()
		end
		table.clear(connections)
		table.clear(objs)
		table.clear(self)
	end
	if module then
		module:Clean(cleanFunc)
	end
	return objs, cleanFunc
end

local function scanDescendants(root, fn, module)
	local state = {cancelled = false}
	if module then
		module:Clean(function() state.cancelled = true end)
	end
	task.spawn(function()
		local stack = {root or workspace}
		local budget = 0
		while #stack > 0 do
			if state.cancelled then return end
			local node = stack[#stack]
			stack[#stack] = nil
			local kids = node:GetChildren()
			for i = 1, #kids do
				local child = kids[i]
				stack[#stack + 1] = child
				fn(child)
			end
			budget += #kids
			if budget >= 700 then
				budget = 0
				task.wait()
				if state.cancelled then return end
			end
		end
	end)
	return state
end

local function cleanThread(module, thread)
	module:Clean(function()
		if thread then
			pcall(task.cancel, thread)
			thread = nil
		end
	end)
	return thread
end

local function getBestArmor(slot)
	local closest, mag = nil, 0

	for _, item in store.inventory.inventory.items do
		local meta = item and bedwars.ItemMeta[item.itemType] or {}

		if meta.armor and meta.armor.slot == slot then
			local newmag = (meta.armor.damageReductionMultiplier or 0)

			if newmag > mag then
				closest, mag = item, newmag
			end
		end
	end

	return closest
end

local function getBow()
	local bestBow, bestBowSlot, bestBowDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local _bowItemMeta = bedwars.ItemMeta[item.itemType]
        local bowMeta = _bowItemMeta and _bowItemMeta.projectileSource
		if bowMeta and table.find(bowMeta.ammoItemTypes, 'arrow') then
			local bowDamage = bedwars.ProjectileMeta[bowMeta.projectileType('arrow')].combat.damage or 0
			if bowDamage > bestBowDamage then
				bestBow, bestBowSlot, bestBowDamage = item, slot, bowDamage
			end
		end
	end
	return bestBow, bestBowSlot
end

local function getItem(itemName, inv)
	for slot, item in (inv or store.inventory.inventory.items) do
		if item.itemType == itemName then
			return item, slot
		end
	end
	return nil
end

local function GetItems(item: string): table
	local Items: table = {};
	for _, v in next, Enum[item]:GetEnumItems() do 
		table.insert(Items, v["Name"]) ;
	end;
	return Items;
end;

local function getRoactRender(func)
	return debug.getupvalue(debug.getupvalue(debug.getupvalue(func, 3).render, 2).render, 1)
end

local function getSword()
	local bestSword, bestSwordSlot, bestSwordDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local _swordItemMeta = bedwars.ItemMeta[item.itemType]
        local swordMeta = _swordItemMeta and _swordItemMeta.sword
		if swordMeta then
			local swordDamage = swordMeta.damage or 0
			if swordDamage > bestSwordDamage then
				bestSword, bestSwordSlot, bestSwordDamage = item, slot, swordDamage
			end
		end
	end
	return bestSword, bestSwordSlot
end

local function getTool(breakType)
	local bestTool, bestToolSlot, bestToolDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local _toolItemMeta = bedwars.ItemMeta[item.itemType]
        local toolMeta = _toolItemMeta and _toolItemMeta.breakBlock
		if toolMeta then
			local toolDamage = toolMeta[breakType] or 0
			if toolDamage > bestToolDamage then
				bestTool, bestToolSlot, bestToolDamage = item, slot, toolDamage
			end
		end
	end
	return bestTool, bestToolSlot
end

local function getWool()
	for _, wool in store.inventory.inventory.items do
		if wool.itemType:find('wool') then
			return wool and wool.itemType, wool and wool.amount
		end
	end
end

local function getStrength(plr)
	if not plr or not plr.Player then
		return 0
	end

	local strength = 0
	for _, v in (store.inventories[plr.Player] or {items = {}}).items do
		local itemmeta = bedwars.ItemMeta[v.itemType]
		if itemmeta and itemmeta.sword and itemmeta.sword.damage > strength then
			strength = itemmeta.sword.damage
		end
	end

	return strength
end

local function getPlacedBlock(pos)
	if not pos then
		return
	end
	local roundedPosition = bedwars.BlockController:getBlockPosition(pos)
	return bedwars.BlockController:getStore():getBlockAt(roundedPosition), roundedPosition
end

local function getBlocksInPoints(s, e)
	local blocks, list = bedwars.BlockController:getStore(), {}
	for x = s.X, e.X do
		for y = s.Y, e.Y do
			for z = s.Z, e.Z do
				local vec = Vector3.new(x, y, z)
				if blocks:getBlockAt(vec) then
					table.insert(list, vec * 3)
				end
			end
		end
	end
	return list
end

local function getNearGround(range)
	range = Vector3.new(3, 3, 3) * (range or 10)
	local localPosition, mag, closest = entitylib.character.RootPart.Position, 60
	local blocks = getBlocksInPoints(bedwars.BlockController:getBlockPosition(localPosition - range), bedwars.BlockController:getBlockPosition(localPosition + range))

	for _, v in blocks do
		if not getPlacedBlock(v + Vector3.new(0, 3, 0)) then
			local newmag = (localPosition - v).Magnitude
			if newmag < mag then
				mag, closest = newmag, v + Vector3.new(0, 3, 0)
			end
		end
	end

	table.clear(blocks)
	return closest
end

local itemSkinMetaFn
local function getItemSkinMeta(skin)
	if itemSkinMetaFn == nil then
		itemSkinMetaFn = false
		pcall(function()
			for _, m in replicatedStorage.TS.games.bedwars['item-skin']:GetDescendants() do
				if m:IsA('ModuleScript') then
					local ok, res = pcall(require, m)
					if ok and type(res) == 'table' and type(res.getItemSkinMeta) == 'function' then
						itemSkinMetaFn = res.getItemSkinMeta
						break
					end
				end
			end
		end)
	end
	if not itemSkinMetaFn then return nil end
	local ok, res = pcall(itemSkinMetaFn, skin)
	return ok and res or nil
end

local skinSoundBackup = {}
local function applySkinSounds(itemType, skin)
	local meta = bedwars.ItemMeta and bedwars.ItemMeta[itemType]
	if not meta then return end
	local backup = skinSoundBackup[itemType]
	if backup then
		for _, v in backup do
			v[1][v[2]] = v[3]
		end
		skinSoundBackup[itemType] = nil
	end
	local skinmeta = skin and getItemSkinMeta(skin)
	if type(skinmeta) ~= 'table' then return end
	local saved = {}
	for section, data in skinmeta do
		local target = meta[section]
		if type(data) == 'table' and type(target) == 'table' then
			for key, val in data do
				if type(key) == 'string' and key:lower():find('sound') then
					table.insert(saved, {target, key, target[key]})
					target[key] = val
				end
			end
		end
	end
	if #saved > 0 then
		skinSoundBackup[itemType] = saved
	end
end

local function getShieldAttribute(char)
	local total = char:GetAttribute('TotalShield')
	if type(total) == 'number' then
		return math.max(total, 0)
	end
	local returned = 0
	for name, val in char:GetAttributes() do
		if name:find('Shield') and type(val) == 'number' and val > 0 then
			returned += val
		end
	end
	return returned
end

local function getSpeed()
	local multi, increase, modifiers = 0, true, bedwars.SprintController:getMovementStatusModifier():getModifiers()

	local modifiers2 = bedwars.SprintController:getMovementStatusModifier():getModifiers()
	for _, v in modifiers do
		if type(v) == 'table' then
			local val = v.constantSpeedMultiplier and v.constantSpeedMultiplier or 0
			if val and val > math.max(multi, 1) then
				increase = false
				multi = val - (0.06 * math.round(val))
			end
		end
	end

	for _, v in modifiers2 do
		if type(v) == 'table' then
			multi += math.max((v.moveSpeedMultiplier or 0) - 1, 0)
		end
	end

	if multi > 0 and increase then
		multi += 0.16 + (0.02 * math.round(multi))
	end

	return 20 * (multi + 1)
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do
		ind += 1
	end
	return ind
end

local function hotbarSwitch(slot)
	if slot and store.inventory.hotbarSlot ~= slot then
		bedwars.Store:dispatch({
			type = 'InventorySelectHotbarSlot',
			slot = slot
		})
		vapeEvents.InventoryChanged.Event:Wait()
		return true
	end
	return false
end

local function getHotbar(tool)
	for i, v in (store.inventory.hotbar or {}) do
		if v.item and v.item.tool == tool then
			return i - 1
		end
	end
	return nil
end
getgenv().getHotbar = getHotbar

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local function roundPos(vec)
    return Vector3.new(
        math.round(vec.X / 3) * 3,
        math.round(vec.Y / 3) * 3,
        math.round(vec.Z / 3) * 3
    )
end

local function switchItem(tool, delayTime)
	delayTime = delayTime or 0.05
	local check = lplr.Character and lplr.Character:FindFirstChild('HandInvItem') or nil
	if check and check.Value ~= tool and tool.Parent ~= nil then
		task.spawn(function()
			bedwars.Client:Get(remotes.EquipItem):CallServerAsync({hand = tool})
		end)
		check.Value = tool
		if delayTime > 0 then
			task.wait(delayTime)
		end
		return true
	end
end

local function waitForChildOfType(obj, name, timeout, prop)
	local check, returned = tick() + timeout
	repeat
		returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
		if (returned and returned.Name ~= 'UpperTorso') or check < tick() then
			break
		end
		task.wait()
	until false
	return returned
end

local frictionTable, oldfrict = {}, {}
local lastUpdate = {}
local lagConnections = {}
local frictionConnection
local frictionState

local function modifyVelocity(v)
	if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
		oldfrict[v] = v.CustomPhysicalProperties or 'none'
		v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
	end
end

local function updateVelocity(force)
	local newState = getTableSize(frictionTable) > 0
	if frictionState ~= newState or force then
		if frictionConnection then
			frictionConnection:Disconnect()
		end
		if newState then
			if entitylib.isAlive then
				for _, v in entitylib.character.Character:GetDescendants() do
					modifyVelocity(v)
				end
				frictionConnection = entitylib.character.Character.DescendantAdded:Connect(modifyVelocity)
			end
		else
			for i, v in oldfrict do
				i.CustomPhysicalProperties = v ~= 'none' and v or nil
			end
			table.clear(oldfrict)
		end
	end
	frictionState = newState
end

local function isEveryoneDead()
	return #bedwars.Store:getState().Party.members <= 0
end
	
local function joinQueue()
	if not bedwars.Store:getState().Game.customMatch and bedwars.Store:getState().Party.leader.userId == lplr.UserId and bedwars.Store:getState().Party.queueState == 0 then
		bedwars.QueueController:joinQueue(store.queueType)
	end
end

local function lobby()
    bedwars.Client:Get(remotes.TeleportToLobby):FireServer()
end

local kitorder = {
	hannah = 5,
	spirit_assassin = 4,
	dasher = 3,
	jade = 2,
	regent = 1
}

local function HasSeed(character)
    if not character then return false end
    return character:FindFirstChild("Seed", true) ~= nil
end

local sortmethods = {
	Threat = function(a, b)
		if not a.Entity then return false end
		if not b.Entity then return true end
		return getStrength(a.Entity) > getStrength(b.Entity)
	end,
	Health = function(a, b)
		if not a.Entity then return false end
		if not b.Entity then return true end
		return a.Entity.Health < b.Entity.Health
	end,
	Angle = function(a, b)
		if not a.Entity or not a.Entity.RootPart then return false end
		if not b.Entity or not b.Entity.RootPart then return true end
		local selfrootpos = entitylib.character.RootPart.Position
		local rawFacing = (getgenv().ViewMode and getgenv().ViewMode.Value == 'Third Person') and gameCamera.CFrame.LookVector or entitylib.character.RootPart.CFrame.LookVector
		local flatFacing = Vector3.new(rawFacing.X, 0, rawFacing.Z)
		if flatFacing.Magnitude < 0.001 then return false end
		local localFacing = flatFacing.Unit
		local deltaA = Vector3.new(a.Entity.RootPart.Position.X - selfrootpos.X, 0, a.Entity.RootPart.Position.Z - selfrootpos.Z)
		local deltaB = Vector3.new(b.Entity.RootPart.Position.X - selfrootpos.X, 0, b.Entity.RootPart.Position.Z - selfrootpos.Z)
		if deltaA.Magnitude < 0.001 or deltaB.Magnitude < 0.001 then return deltaA.Magnitude < deltaB.Magnitude end
		local angle = math.acos(math.clamp(localFacing:Dot(deltaA.Unit), -1, 1))
		local angle2 = math.acos(math.clamp(localFacing:Dot(deltaB.Unit), -1, 1))
		return angle < angle2
	end,
	Distance = function(a, b)
		if not a.Entity or not a.Entity.RootPart then return false end
		if not b.Entity or not b.Entity.RootPart then return true end
		local selfpos = entitylib.character.RootPart.Position
		local distA = (a.Entity.RootPart.Position - selfpos).Magnitude
		local distB = (b.Entity.RootPart.Position - selfpos).Magnitude
		return distA < distB
	end,
	Cursor = function(a, b)
		if not a.Entity or not a.Entity.RootPart then return false end
		if not b.Entity or not b.Entity.RootPart then return true end
		local camera = gameCamera
		local mousePos = inputService:GetMouseLocation()
		local function screenDist(ent)
			local rootPart = ent.RootPart
			if not rootPart then return math.huge end
			local screenPos, onScreen = camera:WorldToScreenPoint(rootPart.Position)
			if not onScreen then return math.huge end
			return (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
		end
		local distA = screenDist(a.Entity)
		local distB = screenDist(b.Entity)
		if distA == math.huge and distB == math.huge then
			local selfpos = entitylib.character.RootPart.Position
			local worldA = (a.Entity.RootPart.Position - selfpos).Magnitude
			local worldB = (b.Entity.RootPart.Position - selfpos).Magnitude
			return worldA < worldB
		end
		return distA < distB
	end,
	Forest = function(a, b)
		if not a.Entity then return false end
		if not b.Entity then return true end
		local aHasSeed = HasSeed(a.Entity.Character)
		local bHasSeed = HasSeed(b.Entity.Character)
		if aHasSeed and not bHasSeed then return true end
		if not aHasSeed and bHasSeed then return false end
		if not a.Entity.RootPart then return false end
		if not b.Entity.RootPart then return true end
		local selfpos = entitylib.character.RootPart.Position
		local distA = (a.Entity.RootPart.Position - selfpos).Magnitude
		local distB = (b.Entity.RootPart.Position - selfpos).Magnitude
		return distA < distB
	end
}

local function getSortList(priority)
	local methods = {}
	for _, v in ipairs(priority or {}) do
		table.insert(methods, v)
	end
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	return methods
end

run(function()
	local oldstart = entitylib.start
	local function customEntity(ent)
		if ent:HasTag('inventory-entity') and not ent:HasTag('Monster') then
			return
		end

		entitylib.addEntity(ent, nil, ent:HasTag('Drone') and function(self)
			local droneplr = playersService:GetPlayerByUserId(self.Character:GetAttribute('PlayerUserId'))
			return not droneplr or lplr:GetAttribute('Team') ~= droneplr:GetAttribute('Team')
		end or function(self)
			return lplr:GetAttribute('Team') ~= self.Character:GetAttribute('Team')
		end)
	end

	entitylib.start = function()
		if entitylib.Running then entitylib.stop() end

		local function customEntity(ent)
			if playersService:GetPlayerFromCharacter(ent) then return end
			if collectionService:HasTag(ent.Parent, 'entity') then return end
			local teamFunc = function(self)
				local npcTeam = self.Character:GetAttribute('Team')
				if not npcTeam then return true end
				return lplr:GetAttribute('Team') ~= npcTeam
			end
			entitylib.addEntity(ent, nil, teamFunc)
		end

		table.insert(entitylib.Connections, playersService.PlayerAdded:Connect(function(v)
			entitylib.addPlayer(v)
		end))
		table.insert(entitylib.Connections, playersService.PlayerRemoving:Connect(function(v)
			entitylib.removePlayer(v)
		end))

		for _, v in playersService:GetPlayers() do
			entitylib.addPlayer(v)
		end

		for _, ent in collectionService:GetTagged('entity') do
			customEntity(ent)
		end

		table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('entity'):Connect(customEntity))
		table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('entity'):Connect(function(ent)
			entitylib.removeEntity(ent)
		end))

		local function addDesertPot(pot)
			if not pot:IsA('Model') then return end
			entitylib.addEntity(pot, nil, function() return true end)
		end
		for _, v in collectionService:GetTagged('desert_pot') do
			addDesertPot(v)
		end
		table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('desert_pot'):Connect(addDesertPot))
		table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('desert_pot'):Connect(function(v)
			entitylib.removeEntity(v)
		end))

		table.insert(entitylib.Connections, workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
			gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
		end))

		entitylib.Running = true
	end

	entitylib.addPlayer = function(plr)
		if entitylib.PlayerConnections[plr] then
			for _, conn in ipairs(entitylib.PlayerConnections[plr]) do
				if conn and typeof(conn) == "RBXScriptConnection" then
					conn:Disconnect()
				end
			end
		end

		if plr.Character then
			entitylib.refreshEntity(plr.Character, plr)
		end
		entitylib.PlayerConnections[plr] = {
			plr.CharacterAdded:Connect(function(char)
				entitylib.refreshEntity(char, plr)
			end),
			plr.CharacterRemoving:Connect(function(char)
				entitylib.removeEntity(char, plr == lplr)
			end),
			plr:GetAttributeChangedSignal('Team'):Connect(function()
				if plr == lplr then
					for _, v in entitylib.List do
						local newTargetable = entitylib.targetCheck(v)
						if v.Targetable ~= newTargetable then
							v.Targetable = newTargetable
							entitylib.Events.EntityUpdated:Fire(v)
						end
					end
				else
					entitylib.refreshEntity(plr.Character, plr)
					for _, v in entitylib.List do
						if v.Player ~= plr and v.Targetable ~= entitylib.targetCheck(v) then
							local newTargetable = entitylib.targetCheck(v)
							v.Targetable = newTargetable
							entitylib.Events.EntityUpdated:Fire(v)
						end
					end
				end
			end)
		}
	end

	entitylib.addEntity = function(char, plr, teamfunc)
		if not char then return end
		entitylib.EntityThreads[char] = task.spawn(function()
			local hum, humrootpart, head
			if plr then
				hum = waitForChildOfType(char, 'Humanoid', 10)
				humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
				head = char:WaitForChild('Head', 10) or humrootpart
			else
				hum = {HipHeight = 0.5}
				humrootpart = waitForChildOfType(char, 'PrimaryPart', 10, true)
				head = humrootpart
			end
			local updateobjects = {}
			if plr and plr ~= lplr then
				local names = {'ArmorInvItem_0', 'ArmorInvItem_1', 'ArmorInvItem_2', 'HandInvItem'}
				for _, name in names do
					local found = char:FindFirstChild(name)
					if found then
						table.insert(updateobjects, found)
					end
				end
			end

			if hum and humrootpart then
				local entity = {
					Connections = {},
					Character = char,
					Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char),
					Head = head,
					Humanoid = hum,
					HumanoidRootPart = humrootpart,
					HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
					Jumps = 0,
					JumpTick = tick(),
					Jumping = false,
					LandTick = tick(),
					MaxHealth = char:GetAttribute('MaxHealth') or 100,
					NPC = plr == nil,
					Player = plr,
					RootPart = humrootpart,
					TeamCheck = teamfunc
				}

				if plr == lplr then
					entity.AirTime = tick()
					entitylib.character = entity
					entitylib.isAlive = true
					entitylib.Events.LocalAdded:Fire(entity)
					table.insert(entity.Connections, char.AttributeChanged:Connect(function(attr)
						vapeEvents.AttributeChanged:Fire(attr)
					end))
				else
					entity.Targetable = entitylib.targetCheck(entity)

					if not plr then
						table.insert(entity.Connections, char.AttributeChanged:Connect(function(attr)
							if attr == 'Team' then
								entity.Targetable = entitylib.targetCheck(entity)
								entitylib.Events.EntityUpdated:Fire(entity)
							end
						end))
					end

					for _, v in entitylib.getUpdateConnections(entity) do
						table.insert(entity.Connections, v:Connect(function()
							entity.Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char)
							entity.MaxHealth = char:GetAttribute('MaxHealth') or 100
							entitylib.Events.EntityUpdated:Fire(entity)
						end))
					end

					local invUpdatePending = {}

					for _, v in updateobjects do
						table.insert(entity.Connections, v:GetPropertyChangedSignal('Value'):Connect(function()
							if invUpdatePending[entity] then return end
							invUpdatePending[entity] = true
							task.delay(0.1, function()
								invUpdatePending[entity] = nil
								if bedwars.getInventory then
									store.inventories[plr] = bedwars.getInventory(plr)
									entitylib.Events.EntityUpdated:Fire(entity)
								end
							end)
						end))
					end

					if plr then
						local anim = char:FindFirstChild('Animate')
						if anim then
							pcall(function()
								local jumpAnimId = anim.jump:FindFirstChildWhichIsA('Animation').AnimationId
								table.insert(entity.Connections, hum.StateChanged:Connect(function(old, new)
									if new == Enum.HumanoidStateType.Jumping then
										entity.JumpTick = tick()
										entity.Jumps += 1
										entity.LandTick = tick() + 1
										entity.Jumping = entity.Jumps > 1
									elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running or new == Enum.HumanoidStateType.Freefall then
										entity.Jumping = false
									end
								end))
							end)
						end

						local inventoryThread
						inventoryThread = task.spawn(function()
							local waitTime = 0.3
							while plr and plr.Parent and entity.Character and entity.Character.Parent do
								if bedwars.getInventory then
									local inv = bedwars.getInventory(plr)
									if inv then
										local old = store.inventories[plr]
										store.inventories[plr] = inv
										local changed = true
										if old then
											local oh = old.hand and old.hand.itemType or ''
											local nh = inv.hand and inv.hand.itemType or ''
											local oa = ''
											local na = ''
											for i = 4, 6 do
												oa = oa .. '|' .. tostring(old.armor and old.armor[i] and old.armor[i].itemType or '')
												na = na .. '|' .. tostring(inv.armor and inv.armor[i] and inv.armor[i].itemType or '')
											end
											changed = (oh ~= nh) or (oa ~= na)
										end
										if changed then
											entitylib.Events.EntityUpdated:Fire(entity)
										end
									end
								end
								task.wait(waitTime)
								if waitTime < 0.6 then
									waitTime = math.min(0.6, waitTime + 0.1)
								end
							end
							inventoryThread = nil
						end)
						table.insert(entity.Connections, {
							Disconnect = function()
								if inventoryThread then
									pcall(task.cancel, inventoryThread)
									inventoryThread = nil
								end
							end
						})
					end
					table.insert(entitylib.List, entity)
					entitylib.Events.EntityAdded:Fire(entity)
				end

				table.insert(entity.Connections, char.ChildRemoved:Connect(function(part)
					if part == humrootpart or part == hum or part == head then
						if part == humrootpart and hum.RootPart then
							humrootpart = hum.RootPart
							entity.RootPart = hum.RootPart
							entity.HumanoidRootPart = hum.RootPart
							return
						end
						entitylib.removeEntity(char, plr == lplr)
					end
				end))
			end
			entitylib.EntityThreads[char] = nil
		end)
	end

	entitylib.getUpdateConnections = function(ent)
		local char = ent.Character
		local tab = {
			char:GetAttributeChangedSignal('Health'),
			char:GetAttributeChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {Disconnect = function() end}
				end
			}
		}

		if ent.Player then
			table.insert(tab, ent.Player:GetAttributeChangedSignal('PlayingAsKit'))
			table.insert(tab, ent.Player:GetAttributeChangedSignal('PlayingAsKits'))

			local vkSignal = {
				Connect = function(_, func)
					local conn = ent.Player:GetAttributeChangedSignal('VoidKnightTier'):Connect(function()
						lastUpdate[ent] = 0
						func()
					end)
					return conn
				end
			}
			table.insert(tab, vkSignal)
		end

		local blockKickerSignal = {
			Connect = function(_, func)
				local conn = char.AttributeChanged:Connect(function(attr)
					if attr == 'BlockKickerKit_BlockCount' then
						lastUpdate[ent] = 0
						func()
					end
				end)
				return conn
			end
		}
		table.insert(tab, blockKickerSignal)

		local shieldSignal = {
			Connect = function(_, func)
				local conn = char.AttributeChanged:Connect(function(attr)
					if attr:find('Shield') then
						func()
					end
				end)
				return conn
			end
		}
		table.insert(tab, shieldSignal)

		return tab
	end

	entitylib.targetCheck = function(ent)
		if ent.Character and ent.Character:HasTag('petrified-player') then return false end
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then
			local npcTeam = ent.Character and ent.Character:GetAttribute('Team')
			if not npcTeam then return true end
			return lplr:GetAttribute('Team') ~= npcTeam
		end
		if isFriend(ent.Player) then return false end
		return lplr:GetAttribute('Team') ~= ent.Player:GetAttribute('Team')
	end
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
end)
entitylib.start()

run(function()
	local KnitInit, Knit
	repeat
		KnitInit, Knit = pcall(function()
			return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9)
		end)
		if KnitInit then break end
		task.wait()
	until KnitInit

	if not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end

	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local InventoryUtil = require(replicatedStorage.TS.inventory['inventory-util']).InventoryUtil
	local Client = require(replicatedStorage.TS.remotes).default.Client
	local OldGet, OldBreak = Client.Get

	local rakNet = false
	run(function()
		rakNet = typeof(raknet) == 'table'
	end)

	bedwars = setmetatable({
		RankMeta = require(replicatedStorage.TS.rank['rank-meta']).RankMeta,
        BalanceFile = require(replicatedStorage.TS.balance["balance-file"]).BalanceFile,
        ClientSyncEvents = require(lplr.PlayerScripts.TS['client-sync-events']).ClientSyncEvents,
        SyncEventPriority = require(replicatedStorage.rbxts_include.node_modules['@easy-games']['sync-event'].out),
		AbilityId = require(replicatedStorage.TS.ability['ability-id']).AbilityId,
        IdUtil = require(replicatedStorage.TS.util['id-util']).IdUtil,
		BlockSelector = require(game:GetService("ReplicatedStorage").rbxts_include.node_modules["@easy-games"]["block-engine"].out.client.select["block-selector"]).BlockSelector,
		KnockbackUtilInstance = replicatedStorage.TS.damage['knockback-util'],
		BedwarsKitSkin = require(replicatedStorage.TS.games.bedwars['kit-skin']['bedwars-kit-skin-meta']).BedwarsKitSkinMeta,
		KitController = Knit.Controllers.KitController,
		FishermanUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.fisherman['fisherman-util']).FishermanUtil,
		FishMeta = require(replicatedStorage.TS.games.bedwars.kit.kits.fisherman['fish-meta']),
	 	MatchHistoryApp = require(lplr.PlayerScripts.TS.controllers.global["match-history"].ui["match-history-moderation-app"]).MatchHistoryModerationApp,
	 	MatchHistoryController = Knit.Controllers.MatchHistoryController,
		BlockEngine = require(game:GetService("ReplicatedStorage").rbxts_include.node_modules["@easy-games"]["block-engine"].out).BlockEngine,
		BlockSelectorMode = require(game:GetService("ReplicatedStorage").rbxts_include.node_modules["@easy-games"]["block-engine"].out.client.select["block-selector"]).BlockSelectorMode,
		EntityUtil = require(game:GetService("ReplicatedStorage").TS.entity["entity-util"]).EntityUtil,
		GamePlayer = require(replicatedStorage.TS.player['game-player']),
		OfflinePlayerUtil = require(replicatedStorage.TS.player['offline-player-util']),
		PlayerUtil = require(replicatedStorage.TS.player['player-util']),
		KKKnitController = require(lplr.PlayerScripts.TS.lib.knit['knit-controller']),
		AbilityController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/ability/ability-controller@AbilityController'),
		CooldownController = Flamework.resolveDependency("@easy-games/game-core:client/controllers/cooldown/cooldown-controller@CooldownController"),
		CooldownIDS = require(replicatedStorage.TS.cooldown["cooldown-id"]).CooldownId,		
		AnimationType = require(replicatedStorage.TS.animation['animation-type']).AnimationType,
		AnimationUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out['shared'].util['animation-util']).AnimationUtil,
		AppController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.controllers['app-controller']).AppController,
		BedBreakEffectMeta = require(replicatedStorage.TS.locker['bed-break-effect']['bed-break-effect-meta']).BedBreakEffectMeta,
		BedwarsKitMeta = require(replicatedStorage.TS.games.bedwars.kit['bedwars-kit-meta']).BedwarsKitMeta,
		BlockBreaker = Knit.Controllers.BlockBreakController.blockBreaker,
		BlockController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out).BlockEngine,
		BlockEngine = require(lplr.PlayerScripts.TS.lib['block-engine']['client-block-engine']).ClientBlockEngine,
		BlockPlacer = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.client.placement['block-placer']).BlockPlacer,
		BowConstantsTable = (Knit.Controllers.ProjectileController and Knit.Controllers.ProjectileController.enableBeam) and debug.getupvalue(Knit.Controllers.ProjectileController.enableBeam, 5) or {},
		ClickHold = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.ui.lib.util['click-hold']).ClickHold,
		Client = Client,
		ClientConstructor = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts'].net.out.client),
		ClientDamageBlock = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.shared.remotes).BlockEngineRemotes.Client,
		CombatConstant = require(replicatedStorage.TS.combat['combat-constant']).CombatConstant,
		SharedConstants = require(replicatedStorage.TS['shared-constants']).CpsConstants,
		DamageIndicator = Knit.Controllers.DamageIndicatorController.spawnDamageIndicator,
		DefaultKillEffect = require(lplr.PlayerScripts.TS.controllers.global.locker['kill-effect'].effects['default-kill-effect']),
		EmoteType = require(replicatedStorage.TS.locker.emote['emote-type']).EmoteType,
		EmoteMeta = require(replicatedStorage.TS.locker.emote['emote-meta']).EmoteMeta,
		GameAnimationUtil = require(replicatedStorage.TS.animation['animation-util']).GameAnimationUtil,
		NotificationController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/notification-controller@NotificationController'),
		getIcon = function(item, showinv)
			local itemmeta = bedwars.ItemMeta[item.itemType]
			return itemmeta and showinv and itemmeta.image or ''
		end,
		getInventory = function(plr)
			local suc, res = pcall(function()
				return InventoryUtil.getInventory(plr)
			end)
			return suc and res or {
				items = {},
				armor = {}
			}
		end,
		MatchHistoryController = require(lplr.PlayerScripts.TS.controllers.global['match-history']['match-history-controller']),
		PlayerProfileUIController = require(lplr.PlayerScripts.TS.controllers.global['player-profile']['player-profile-ui-controller']),
		HudAliveCount = require(lplr.PlayerScripts.TS.controllers.global['top-bar'].ui.game['hud-alive-player-counts']).HudAlivePlayerCounts,
		ItemMeta = (function()
			local fn = require(replicatedStorage.TS.item['item-meta']).getItemMeta
			for i = 1, 6 do
				local v = debug.getupvalue(fn, i)
				if type(v) == 'table' and next(v) then return v end
			end
			return {}
		end)(),
		KillEffectMeta = require(replicatedStorage.TS.locker['kill-effect']['kill-effect-meta']).KillEffectMeta,
		KillFeedController = Flamework.resolveDependency('client/controllers/game/kill-feed/kill-feed-controller@KillFeedController'),
		Knit = Knit,
		KnockbackUtil = require(replicatedStorage.TS.damage['knockback-util']).KnockbackUtil,
		MageKitUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.mage['mage-kit-util']).MageKitUtil,
		NametagController = Knit.Controllers.NametagController,
		PartyController = Flamework.resolveDependency("@easy-games/lobby:client/controllers/party-controller@PartyController"),
		ProjectileMeta = require(replicatedStorage.TS.projectile['projectile-meta']).ProjectileMeta,
		QueryUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil,
		QueueCard = require(lplr.PlayerScripts.TS.controllers.global.queue.ui['queue-card']).QueueCard,
		QueueMeta = require(replicatedStorage.TS.game['queue-meta']).QueueMeta,
		Roact = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts']['roact'].src),
		RuntimeLib = require(replicatedStorage['rbxts_include'].RuntimeLib),
		SoundList = require(replicatedStorage.TS.sound['game-sound']).GameSound,
		SoundManager = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).SoundManager,
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
		TeamUpgradeMeta = debug.getupvalue(require(replicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-meta']).getTeamUpgradeMetaForQueue, 2) or {},
		UILayers = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).UILayers,
		VisualizerUtils = require(lplr.PlayerScripts.TS.lib.visualizer['visualizer-utils']).VisualizerUtils,
		WeldTable = require(replicatedStorage.TS.util['weld-util']).WeldUtil,
		WinEffectMeta = require(replicatedStorage.TS.locker['win-effect']['win-effect-meta']).WinEffectMeta,
		ZapNetworking = require(lplr.PlayerScripts.TS.lib.network),
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})

	getgenv().bedwars = bedwars

	local remoteNames = {
		AfkStatus = safeGetProto(Knit.Controllers.AfkController.KnitStart, 1),
		AttackEntity = Knit.Controllers.SwordController.sendServerRequest,
		BeePickup = Knit.Controllers.BeeNetController.trigger,
		CannonAim = safeGetProto(Knit.Controllers.CannonController.startAiming, 5),
		CannonLaunch = Knit.Controllers.CannonHandController.launchSelf,
		ConsumeBattery = safeGetProto(Knit.Controllers.BatteryController.onKitLocalActivated, 1),
		ConsumeItem = safeGetProto(Knit.Controllers.ConsumeController.onEnable, 1),
		ConsumeSoul = Knit.Controllers.GrimReaperController.consumeSoul,
		ConsumeTreeOrb = safeGetProto(Knit.Controllers.EldertreeController.createTreeOrbInteraction, 1),
		DepositPinata = safeGetProto(safeGetProto(Knit.Controllers.PiggyBankController.KnitStart, 2), 5),
		DragonBreath = safeGetProto(Knit.Controllers.VoidDragonController.onKitLocalActivated, 5),
		DragonEndFly = safeGetProto(Knit.Controllers.VoidDragonController.flapWings, 1),
		DragonFly = Knit.Controllers.VoidDragonController.flapWings,
		DropItem = Knit.Controllers.ItemDropController.dropItemInHand,
		EquipItem = safeGetProto(require(replicatedStorage.TS.entity.entities['inventory-entity']).InventoryEntity.equipItem, 3),
		FireProjectile = safeGetProto(Knit.Controllers.ProjectileController.launchProjectileWithValues, 2) or function() end,
		GroundHit = Knit.Controllers.FallDamageController.KnitStart,
		GuitarHeal = Knit.Controllers.GuitarController.performHeal,
		HannahKill = safeGetProto(Knit.Controllers.HannahController.registerExecuteInteractions, 1),
		HarvestCrop = safeGetProto(safeGetProto(Knit.Controllers.CropController.KnitStart, 4), 1),
		KaliyahPunch = safeGetProto(Knit.Controllers.DragonSlayerController.onKitLocalActivated, 1),
		MageSelect = safeGetProto(Knit.Controllers.MageController.registerTomeInteraction, 1),
		PickupItem = Knit.Controllers.ItemDropController.checkForPickup,
		PickupMetal = safeGetProto(Knit.Controllers.HiddenMetalController.onKitLocalActivated, 4),
		ReportPlayer = require(lplr.PlayerScripts.TS.controllers.global.report['report-controller']).default.reportPlayer,
		ResetCharacter = safeGetProto(Knit.Controllers.ResetController.createBindable, 1),
		SummonerClawAttack = Knit.Controllers.SummonerClawHandController.attack,
		WarlockTarget = safeGetProto(Knit.Controllers.WarlockStaffController.KnitStart, 2)
	}

	local function dumpRemote(tab)
		local ind
		for i, v in tab do
			if v == 'Client' then
				ind = i
				break
			end
		end
		return ind and tab[ind + 1] or ''
	end

	local preDumped = {
		EquipItem = 'SetInvItem',
		ActivateGravestone = 'ActivateGravestone',
		CollectCollectableEntity = 'CollectCollectableEntity',
		DefenderRequestPlaceBlock = 'DefenderRequestPlaceBlock',
		RequestDragonPunch = 'RequestDragonPunch',
		Harvest = 'CropHarvest',
		DepositCoins = 'DepositCoins',
		BedwarsPurchaseItem = 'BedwarsPurchaseItem',
		BedBreakEffectTriggered = 'BedBreakEffectTriggered',
		BloodAssassinSelectContract = 'BloodAssassinSelectContract',
		Mimic = 'MimicBlock',
		StyxPortal = 'UseStyxPortalFromClient',
		StyxExitPortal = 'StyxOpenExitPortalFromServer',
		StyxSpawnExitPortal = 'StyxSpawnExitPortalFromServer',
		StyxSpawnEntrancePortal = 'StyxSpawnEntrancePortalFromServer',
		TryOpenStyxPortalExit = 'StyxTryOpenExitPortalFromClient',
		TeleportToLobby = 'TeletoLobby',
		FishCaught = 'FishCaught',
		BountyHunterTargetChanged = 'BountyHunterTargetChanged',
		SpawnRaven = 'SpawnRaven',
		PaladinAbilityRequest = 'PaladinAbilityRequest',
		OwlActionAbilities = 'OwlActionAbilities',
		DrillAttack = 'DrillAttack',
		UpgradeFrostyHammer = 'UpgradeFrostyHammer',
		UpgradeFlamethrower = 'UpgradeFlamethrower',
		TryBlockKick = 'TryBlockKick',   
		Ranks = 'FetchRanks',
		ResearchEnchant = 'EnchantTableResearch',
		DropDroneItem = 'DropDroneItem',
		AttemptFireOasisProjectiles = 'AttemptFireOasisProjectiles',
		WinEffectTriggered = 'WinEffectTriggered',
		ExtractFromDrill = 'ExtractFromDrill',
		HannahPromptTrigger = 'HannahPromptTrigger',
		DragonFlap = 'DragonFlap',
		DragonBreath = 'DragonBreath',
		AttemptCardThrow = 'AttemptCardThrow',
		LearnElementTome = 'LearnElementTome',
		RequestMoveSlime = 'RequestMoveSlime',
		SummonOwl = 'SummonOwl',
		RemoveOwl = 'RemoveOwl',
		OwlFireProjectile = 'OwlFireProjectile',
		OwlAiming = 'OwlAiming',
		MimicBlockPickPocketPlayer = 'MimicBlockPickPocketPlayer',
		DestroyPetrifiedPlayer = 'DestroyPetrifiedPlayer',
		UseAbility = 'useAbility',
		FishFound = 'FishFound',
	}

	for k, v in pairs(preDumped) do
		if not remotes[k] then
			remotes[k] = v
		end
	end

	for i, v in remoteNames do
		local remote
		if type(v) == "string" then
			remote = v
		elseif type(v) == "function" then
			local consts = debug.getconstants(v)
			remote = dumpRemote(consts)
		else
			remote = ""
		end

		if remote == '' or remote == nil then
			if not preDumped[i] then
				notif('aerov4', 'Failed to grab remote ('..tostring(i)..')', 10, 'alert')
			end
			remote = preDumped[i] or ''
		end
		remotes[i] = remote
	end

	pcall(function()
		local net = game:GetService('ReplicatedStorage').rbxts_include.node_modules['@rbxts'].net.out._NetManaged
		local knownFixes = {
			FireProjectile = 'ProjectileFire',
			AttackEntity = 'SwordHit',
		}
		for k, v in pairs(remotes) do
			if type(v) == 'string' and v ~= '' and not net:FindFirstChild(v) then
				if knownFixes[k] and net:FindFirstChild(knownFixes[k]) then
					remotes[k] = knownFixes[k]
				elseif preDumped[k] and net:FindFirstChild(preDumped[k]) then
					remotes[k] = preDumped[k]
				end
			end
		end
	end)

	getgenv().remotes = remotes

	OldBreak = bedwars.BlockController.isBlockBreakable

	Client.Get = function(self, remoteName, ...)
		local call = OldGet(self, remoteName, ...)

		if remoteName == remotes.AttackEntity then
			return {
				instance = call.instance,
				SendToServer = function(_, attackTable, ...)
					local suc, plr = pcall(function()
						return playersService:GetPlayerFromCharacter(attackTable.entityInstance)
					end)

					local selfpos = attackTable.validate.selfPosition.value
					local targetpos = attackTable.validate.targetPosition.value
					store.attackReach = ((selfpos - targetpos).Magnitude * 100) // 1 / 100
					store.attackReachUpdate = tick() + 1

					if Reach.Enabled or HitBoxes.Enabled then
						local delta = targetpos - selfpos
						attackTable.validate.raycast = attackTable.validate.raycast or {}
						attackTable.validate.selfPosition.value += delta.Magnitude > 0.001 and delta.Unit * math.max(delta.Magnitude - (getReach(attackTable.weapon) - 0.001), 0) or Vector3.zero
					end

					return call:SendToServer(attackTable, ...)
				end
			}
		elseif remoteName == 'StepOnSnapTrap' and TrapDisabler and TrapDisabler.Enabled then
			return {SendToServer = function() end}
		end

		return call
	end

	local bedtms = {}

	local cache, blockhealthbar = {}, {blockHealth = -1, breakingBlockPosition = Vector3.zero}
	
	local cacheCleanThread = task.spawn(function()
		while vape.Loaded do
			task.wait(60)
			if vape.Loaded then
				table.clear(cache)
				table.clear(bedtms)
			end
		end
	end)
	vape:Clean(function() task.cancel(cacheCleanThread) end)

	store.blockPlacer = bedwars.BlockPlacer.new(bedwars.BlockEngine, 'wool_white')

	local function getBlockHealth(block, blockpos)
		local blockdata = bedwars.BlockController:getStore():getBlockData(blockpos)
		return (blockdata and (blockdata:GetAttribute('1') or blockdata:GetAttribute('Health')) or block:GetAttribute('Health'))
	end

	local function getBreakType(block)
		if not block then return nil end
		if block.Name == 'gumdrop_bounce_pad' then return 'stone' end
		local meta = bedwars.ItemMeta[block.Name]
		return meta and meta.block and meta.block.breakType
	end

	local function getBlockHits(block, blockpos)
		if not block then return 0 end
		local breaktype = getBreakType(block)
		local tool = breaktype and store.tools[breaktype]
		local toolMeta = tool and bedwars.ItemMeta[tool.itemType]
		local dmg = (toolMeta and toolMeta.breakBlock and toolMeta.breakBlock[breaktype]) or 2
		local health = getBlockHealth(block, bedwars.BlockController:getBlockPosition(blockpos)) or 10
		return health / dmg
	end

	local function calculatePath(target, blockpos, angle, anchor)
		if not anchor and cache[blockpos] then
			if tick() - (cache[blockpos].timestamp or 0) < 1 then
				return unpack(cache[blockpos])
			else
				cache[blockpos] = nil
			end
		end
		angle = angle or 360
		local root = entitylib.character and entitylib.character.RootPart
		if not root then return end
		local origin = root.Position
		local camFlat = gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
		local useAngle = angle < 360 and camFlat.Magnitude > 0.01
		local halfAngle = math.rad(angle) / 2
		local visited = {}
		local distances = {[blockpos] = 0}
		local open = {blockpos}
		local path = {}
		local pos, cost = nil, math.huge

		for _ = 1, 4000 do
			local bestI, bestD = nil, math.huge
			for i = 1, #open do
				local d = distances[open[i]]
				if d < bestD then
					bestI, bestD = i, d
				end
			end
			if not bestI then break end

			local node = open[bestI]
			open[bestI] = open[#open]
			open[#open] = nil
			if visited[node] then continue end
			visited[node] = true

			if not anchor and bestD >= cost then break end

			for _, side in sides do
				local neighbor = node + side
				if visited[neighbor] then continue end

				local block = getPlacedBlock(neighbor)
				if not block then
					local score = bestD
					if anchor then
						local delta = node - anchor
						score = (delta * Vector3.new(1, 0, 1)).Magnitude + math.abs(delta.Y) * 2 + bestD * 0.02
					end
					if score < cost then
						pos, cost = node, score
					end
					continue
				end

				if block == target or block:GetAttribute('NoBreak') then continue end
				if (neighbor - origin).Magnitude > 30 then continue end

				if useAngle then
					local blockFlat = (neighbor - origin) * Vector3.new(1, 0, 1)
					if blockFlat.Magnitude > 0.01 and math.acos(math.clamp(camFlat.Unit:Dot(blockFlat.Unit), -1, 1)) > halfAngle then
						continue
					end
				end

				local curdist = getBlockHits(block, neighbor) + bestD
				if curdist < (distances[neighbor] or math.huge) then
					distances[neighbor] = curdist
					path[neighbor] = node
					table.insert(open, neighbor)
				end
			end
		end

		if pos then
			if not anchor then
				cache[blockpos] = {pos, cost, path, timestamp = tick()}
			end
			return pos, cost, path
		end
	end
	bedwars.calculatePath = calculatePath

	bedwars.placeBlock = function(pos, item)
		if getItem(item) then
			store.blockPlacer.blockType = item
			local ok, result = pcall(function()
				return store.blockPlacer:placeBlock(bedwars.BlockController:getBlockPosition(pos))
			end)
			if ok then return result end
		end
	end

	bedwars.breakBlock = function(block, effects, anim, customHealthbar, visualise, angle, anchor)
		if lplr:GetAttribute('DenyBlockBreak') or not entitylib.isAlive then return end
		local handler = bedwars.BlockController:getHandlerRegistry():getHandler(block.Name)
		local cost, pos, target, path = math.huge, nil, nil, nil
		local playerPos = entitylib.character.RootPart.Position

		local mag = 9e9
		for _, v in (handler and handler:getContainedPositions(block) or {block.Position / 3}) do
			local dpos, dcost, dpath = calculatePath(block, v * 3, angle or 360, anchor)
			local dmag = dpos and (playerPos - dpos).Magnitude or 9e9
			if dpos and (dcost < cost or (dcost == cost and dmag < mag)) then
				cost, pos, target, path, mag = dcost, dpos, v * 3, dpath, dmag
			end
		end

		if pos then
			if (entitylib.character.RootPart.Position - pos).Magnitude > 30 then return end
			local dblock, dpos = getPlacedBlock(pos)
			if not dblock and target then
				dblock, dpos = getPlacedBlock(target)
			end
			if not dblock then
				dblock, dpos = block, bedwars.BlockController:getBlockPosition(block.Position)
			end
			if not dblock or not dpos then return end

			if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.4 then
				local breaktype = getBreakType(dblock)
				local tool = breaktype and store.tools[breaktype]
				if tool then
					if visualise then
						local found = false
						for i, v in store.inventory.hotbar do
							if v.item and v.item.tool == tool.tool and i ~= (store.inventory.hotbarSlot + 1) then
								hotbarSwitch(i - 1)
								found = true
								break
							end
						end
						if not found then
							switchItem(tool.tool)
						end
					else
						switchItem(tool.tool)
					end
				end
			end

			if blockhealthbar.blockHealth == -1 or dpos ~= blockhealthbar.breakingBlockPosition then
				blockhealthbar.blockHealth = getBlockHealth(dblock, dpos) or 0
				blockhealthbar.breakingBlockPosition = dpos
			end

			bedwars.ClientDamageBlock:Get('DamageBlock'):CallServerAsync({
				blockRef = {blockPosition = dpos},
				hitPosition = pos,
				hitNormal = Vector3.FromNormalId(Enum.NormalId.Top)
			}):andThen(function(result)
				if result then
					if result == 'cancelled' then
						table.clear(cache)
						return
					end
					if result == 'destroyed' then
						table.clear(cache) 
					end
					if effects then
						local nowHealth = result == 'destroyed' and 0 or (getBlockHealth(dblock, dpos) or blockhealthbar.blockHealth)
						local blockdmg = math.max(blockhealthbar.blockHealth - nowHealth, 0)
						local dmeta = bedwars.ItemMeta[dblock.Name]
						local maxHealth = dblock:GetAttribute('MaxHealth') or (dmeta and dmeta.block and dmeta.block.health) or math.max(blockhealthbar.blockHealth, 1)
						customHealthbar = customHealthbar or bedwars.BlockBreaker.updateHealthbar
						pcall(customHealthbar, bedwars.BlockBreaker, {blockPosition = dpos}, blockhealthbar.blockHealth, maxHealth, blockdmg, dblock)
						blockhealthbar.blockHealth = math.max(blockhealthbar.blockHealth - blockdmg, 0)
						pcall(function()
							if blockhealthbar.blockHealth <= 0 then
								bedwars.BlockBreaker.breakEffect:playBreak(dblock.Name, dpos, lplr)
								bedwars.BlockBreaker.healthbarMaid:DoCleaning()
								blockhealthbar.breakingBlockPosition = Vector3.zero
							else
								bedwars.BlockBreaker.breakEffect:playHit(dblock.Name, dpos, lplr)
							end
						end)
					end
					if anim then
						local animation = bedwars.AnimationUtil:playAnimation(lplr, bedwars.BlockController:getAnimationController():getAssetId(1))
						bedwars.ViewmodelController:playAnimation(15)
						task.wait(0.3)
						animation:Stop()
						animation:Destroy()
					end
				end
			end)

			return pos, path, target
		end
	end

	for _, v in Enum.NormalId:GetEnumItems() do
		table.insert(sides, Vector3.FromNormalId(v) * 3)
	end

	local function updateStore(new, old)
		if new.Bedwars ~= old.Bedwars then
			store.equippedKit = new.Bedwars.kit ~= 'none' and new.Bedwars.kit or ''
		end
		if new.Game ~= old.Game then
			store.matchState = new.Game.matchState
			store.queueType = new.Game.queueType or 'bedwars_test'
		end

		if new.Inventory ~= old.Inventory then
			local newinv = (new.Inventory and new.Inventory.observedInventory or {inventory = {}})
			local oldinv = (old.Inventory and old.Inventory.observedInventory or {inventory = {}})
			store.inventory = newinv

			if newinv ~= oldinv then
				fireInventoryChanged()
			end

			if newinv.inventory.items ~= oldinv.inventory.items then
				vapeEvents.InventoryAmountChanged:Fire()
				store.tools.sword = getSword()
				local now = tick()
				if not store.lastToolUpdate or now - store.lastToolUpdate > 0.5 then
					store.lastToolUpdate = now
					for _, v in {'stone', 'wood', 'wool'} do
						store.tools[v] = getTool(v)
					end
				elseif not store.toolUpdatePending then
					store.toolUpdatePending = true
					task.delay(0.5, function()
						store.toolUpdatePending = false
						store.lastToolUpdate = tick()
						for _, v in {'stone', 'wood', 'wool'} do
							store.tools[v] = getTool(v)
						end
					end)
				end
			end

			if newinv.inventory.hand ~= oldinv.inventory.hand then
				store.lastToolUpdate = tick()
				store.tools.sword = getSword()
				for _, v in {'stone', 'wood', 'wool'} do
					store.tools[v] = getTool(v)
				end
				local currentHand, toolType = new.Inventory.observedInventory.inventory.hand, ''
				if currentHand then
					local handData = bedwars.ItemMeta[currentHand.itemType]
					toolType = handData.sword and 'sword' or handData.block and 'block' or currentHand.itemType:find('bow') and 'bow'
				end

				store.hand = {
					tool = currentHand and currentHand.tool,
					amount = currentHand and currentHand.amount or 0,
					toolType = toolType
				}
			end
		end
	end

	local storeChanged = bedwars.Store.changed:connect(updateStore)
	vape:Clean(function() storeChanged:disconnect() end)
	updateStore(bedwars.Store:getState(), {})

	for _, event in {'MatchEndEvent', 'EntityDeathEvent', 'BedwarsBedBreak', 'BalloonPopped', 'AngelProgress', 'GrapplingHookFunctions'} do
		if not vape.Connections then return end
		bedwars.Client:WaitFor(event):andThen(function(connection)
			vape:Clean(connection:Connect(function(...)
				vapeEvents[event]:Fire(...)
			end))
		end)
	end

	local _dmgEventData = {entityInstance=nil,damage=nil,damageType=nil,fromPosition=nil,fromEntity=nil,knockbackMultiplier=nil,knockbackId=nil,disableDamageHighlight=nil}
	vape:Clean(bedwars.ZapNetworking.EntityDamageEventZap.On(function(...)
		_dmgEventData.entityInstance = ...
		_dmgEventData.damage = select(2, ...)
		_dmgEventData.damageType = select(3, ...)
		_dmgEventData.fromPosition = select(4, ...)
		_dmgEventData.fromEntity = select(5, ...)
		_dmgEventData.knockbackMultiplier = select(6, ...)
		_dmgEventData.knockbackId = select(7, ...)
		_dmgEventData.disableDamageHighlight = select(13, ...)
		vapeEvents.EntityDamageEvent:Fire(_dmgEventData)
	end))

	vape:Clean(playersService.PlayerRemoving:Connect(function(plr)
		store.inventories[plr] = nil
	end))

	for _, event in {'PlaceBlockEvent', 'BreakBlockEvent'} do
		vape:Clean(bedwars.ZapNetworking[event..'Zap'].On(function(...)
			local pos = ...
			local plr = select(5, ...)
			task.spawn(function()
				pcall(function()
					vapeEvents[event]:Fire({blockRef = {blockPosition = pos}, player = plr})
				end)
			end)
		end))
	end

	store.blocks = collection('block', vape)
	store.shop = collection({'BedwarsItemShop', 'TeamUpgradeShopkeeper'}, vape, function(tab, obj)
		table.insert(tab, {
			Id = obj.Name,
			RootPart = obj,
			Shop = obj:HasTag('BedwarsItemShop'),
			Upgrades = obj:HasTag('TeamUpgradeShopkeeper')
		})
	end)
	store.enchant = collection({'enchant-table', 'broken-enchant-table'}, vape, nil, function(tab, obj, tag)
		if obj:HasTag('enchant-table') and tag == 'broken-enchant-table' then return end
		obj = table.find(tab, obj)
		if obj then
			table.remove(tab, obj)
		end
	end)

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')

	local mapname = 'Unknown'
	sessioninfo:AddItem('Map', 0, function()
		return mapname
	end, false)

	task.delay(1, function()
		games:Increment()
	end)

	task.spawn(function()
		pcall(function()
			repeat task.wait() until store.matchState ~= 0 or vape.Loaded == nil
			if vape.Loaded == nil then return end
			store.map = waitForChildYield(workspace, 9e9, 'Map', 'Worlds'):GetChildren()[1]
			mapname = store.map.Name
			mapname = string.gsub(string.split(mapname, '_')[2] or mapname, '-', '') or 'Blank'
			if store.map then
				vape:Clean(store.map.Blocks.ChildAdded:Connect(function(v) 
					task.delay(0, function()
						if v:GetAttribute('Block') and (v:GetAttribute('PlacedByUserId') or 0) ~= 0 then
							local data = {
								blockRef = {
									blockPosition = v.Position / 3,
								},
								player = playersService:GetPlayerByUserId(v:GetAttribute('PlacedByUserId')),
							}
							for i, v in cache do
								if ((data.blockRef.blockPosition * 3) - v[1]).Magnitude <= 30 then
									table.clear(v[3])
									table.clear(v)
									cache[i] = nil
								end
							end
							vapeEvents.PlaceBlockEvent:Fire(data)
						end
					end)
				end))
			end
		end)
	end)

	vape:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
		if bedTable.player and bedTable.player.UserId == lplr.UserId then
			beds:Increment()
		end
	end))

	vape:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winTable)
		if (bedwars.Store:getState().Game.myTeam or {}).id == winTable.winningTeamId or lplr.Neutral then
			wins:Increment()
		end
	end))

	vape:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
		local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
		local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
		if not killed or not killer then return end

		if killed ~= lplr and killer == lplr then
			kills:Increment()
		end
	end))

	pcall(function()
		bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
		bedwars.ShopItems = bedwars.Shop.ShopItems
		bedwars.Shop.getShopItem('iron_sword', lplr)
		store.shopLoaded = true
	end)

	vape:Clean(function()
		Client.Get = OldGet
		bedwars.BlockController.isBlockBreakable = OldBreak
		store.blockPlacer:disable()
		for _, v in vapeEvents do
			v:Destroy()
		end
		for _, v in cache do
			table.clear(v[3])
			table.clear(v)
		end
		table.clear(store.blockPlacer)
		table.clear(vapeEvents)
		table.clear(bedwars)
		table.clear(store)
		table.clear(cache)
		table.clear(sides)
		table.clear(remotes)
		storeChanged:disconnect()
		storeChanged = nil

		if entitylib.Connections then
			for _, conn in ipairs(entitylib.Connections) do
				if conn and type(conn) == "userdata" and conn.Connected then
					conn:Disconnect()
				end
			end
			table.clear(entitylib.Connections)
		end

		if entitylib.PlayerConnections then
			for _, plrConns in pairs(entitylib.PlayerConnections) do
				if type(plrConns) == "table" then
					for _, conn in ipairs(plrConns) do
						if conn and type(conn) == "userdata" and conn.Connected then
							conn:Disconnect()
						end
					end
				end
			end
			table.clear(entitylib.PlayerConnections)
		end

		if entitylib.EntityThreads then
			for char, thread in pairs(entitylib.EntityThreads) do
				if thread and task.cancel then
					task.cancel(thread)
				end
			end
			table.clear(entitylib.EntityThreads)
		end

		if entitylib.List then
			for _, ent in ipairs(entitylib.List) do
				if ent.Connections then
					for _, conn in ipairs(ent.Connections) do
						if conn and type(conn) == "userdata" and conn.Connected then
							conn:Disconnect()
						end
					end
					table.clear(ent.Connections)
				end
			end
			table.clear(entitylib.List)
		end
		if entitylib.stop then
			entitylib.stop()
		end
		for playerId, data in pairs(lagConnections) do
			if data and data.connection then
				pcall(function() data.connection:Disconnect() end)
			end
		end
		table.clear(lagConnections)
	end)
end)

for _, v in {'AntiRagdoll', 'TriggerBot', 'SilentAim', 'AutoRejoin', 'Rejoin', 'Disabler', 'Timer', 'ServerHop', 'MouseTP', 'MurderMystery', 'NameTags', 'Killaura', 'AimAssist', 'AutoClicker', 'Reach', 'AntiFall', 'Fly', 'HitBoxes', 'LongJump', 'Speed', 'Swim', 'PlayerModel', 'Search', 'Waypoints', 'Blink', 'StaffDetector', ''} do
	vape:Remove(v)
end

local Fly
local LongJump

local kitImageIds = {
	['none'] = "rbxassetid://16493320215",
	["random"] = "rbxassetid://79773209697352",
	["cowgirl"] = "rbxassetid://9155462968",
	["davey"] = "rbxassetid://9155464612",
	["warlock"] = "rbxassetid://15186338366",
	["ember"] = "rbxassetid://9630017904",
	["black_market_trader"] = "rbxassetid://18922642482",
	["yeti"] = "rbxassetid://9166205917",
	["scarab"] = "rbxassetid://137137517627492",
	["defender"] = "rbxassetid://131690429591874",
	["cactus"] = "rbxassetid://104436517801089",
	["oasis"] = "rbxassetid://120283205213823",
	["berserker"] = "rbxassetid://90258047545241",
	["sword_shield"] = "rbxassetid://131690429591874",
	["airbender"] = "rbxassetid://74712750354593",
	["gun_blade"] = "rbxassetid://138231219644853",
	["frost_hammer_kit"] = "rbxassetid://11838567073",
	["spider_queen"] = "rbxassetid://95237509752482",
	["archer"] = "rbxassetid://9224796984",
	["axolotl"] = "rbxassetid://9155466713",
	["baker"] = "rbxassetid://9155463919",
	["barbarian"] = "rbxassetid://9166207628",
	["builder"] = "rbxassetid://9155463708",
	["necromancer"] = "rbxassetid://11343458097",
	["cyber"] = "rbxassetid://9507126891",
	["sorcerer"] = "rbxassetid://97940108361528",
	["bigman"] = "rbxassetid://9155467211",
	["spirit_assassin"] = "rbxassetid://10406002412",
	["farmer_cletus"] = "rbxassetid://9155466936",
	["ice_queen"] = "rbxassetid://9155466204",
	["grim_reaper"] = "rbxassetid://9155467410",
	["spirit_gardener"] = "rbxassetid://132108376114488",
	["hannah"] = "rbxassetid://10726577232",
	["shielder"] = "rbxassetid://9155464114",
	["summoner"] = "rbxassetid://18922378956",
	["glacial_skater"] = "rbxassetid://84628060516931",
	["dragon_sword"] = "rbxassetid://16215630104",
	["lumen"] = "rbxassetid://9630018371",
	["flower_bee"] = "rbxassetid://101569742252812",
	["jellyfish"] = "rbxassetid://18129974852",
	["melody"] = "rbxassetid://9155464915",
	["mimic"] = "rbxassetid://14783283296",
	["miner"] = "rbxassetid://9166208461",
	["nazar"] = "rbxassetid://18926951849",
	["seahorse"] = "rbxassetid://11902552560",
	["elk_master"] = "rbxassetid://15714972287",
	["rebellion_leader"] = "rbxassetid://18926409564",
	["void_hunter"] = "rbxassetid://122370766273698",
	["taliyah"] = "rbxassetid://13989437601",
	["angel"] = "rbxassetid://9166208240",
	["harpoon"] = "rbxassetid://18250634847",
	["void_walker"] = "rbxassetid://78915127961078",
	["spirit_summoner"] = "rbxassetid://95760990786863",
	["triple_shot"] = "rbxassetid://9166208149",
	["void_knight"] = "rbxassetid://73636326782144",
	["regent"] = "rbxassetid://9166208904",
	["vulcan"] = "rbxassetid://9155465543",
	["owl"] = "rbxassetid://12509401147",
	["dasher"] = "rbxassetid://9155467645",
	["disruptor"] = "rbxassetid://11596993583",
	["wizard"] = "rbxassetid://13353923546",
	["aery"] = "rbxassetid://9155463221",
	["agni"] = "rbxassetid://17024640133",
	["alchemist"] = "rbxassetid://9155462512",
	["spearman"] = "rbxassetid://9166207341",
	["beekeeper"] = "rbxassetid://9312831285",
	["falconer"] = "rbxassetid://17022941869",
	["bounty_hunter"] = "rbxassetid://9166208649",
	["blood_assassin"] = "rbxassetid://12520290159",
	["battery"] = "rbxassetid://10159166528",
	["steam_engineer"] = "rbxassetid://15380413567",
	["vesta"] = "rbxassetid://9568930198",
	["beast"] = "rbxassetid://9155465124",
	["dino_tamer"] = "rbxassetid://9872357009",
	["drill"] = "rbxassetid://12955100280",
	["elektra"] = "rbxassetid://13841413050",
	["fisherman"] = "rbxassetid://9166208359",
	["queen_bee"] = "rbxassetid://12671498918",
	["card"] = "rbxassetid://13841410580",
	["frosty"] = "rbxassetid://9166208762",
	["gingerbread_man"] = "rbxassetid://9155464364",
	["ghost_catcher"] = "rbxassetid://9224802656",
	["tinker"] = "rbxassetid://17025762404",
	["ignis"] = "rbxassetid://13835258938",
	["oil_man"] = "rbxassetid://9166206259",
	["jade"] = "rbxassetid://9166306816",
	["dragon_slayer"] = "rbxassetid://10982192175",
	["paladin"] = "rbxassetid://11202785737",
	["pinata"] = "rbxassetid://10011261147",
	["merchant"] = "rbxassetid://9872356790",
	["metal_detector"] = "rbxassetid://9378298061",
	["slime_tamer"] = "rbxassetid://15379766168",
	["nyoka"] = "rbxassetid://17022941410",
	["midnight"] = "rbxassetid://9155462763",
	["pyro"] = "rbxassetid://9155464770",
	["raven"] = "rbxassetid://9166206554",
	["santa"] = "rbxassetid://9166206101",
	["sheep_herder"] = "rbxassetid://9155465730",
	["smoke"] = "rbxassetid://9155462247",
	["spirit_catcher"] = "rbxassetid://9166207943",
	["star_collector"] = "rbxassetid://9872356516",
	["styx"] = "rbxassetid://17014536631",
	["block_kicker"] = "rbxassetid://15382536098",
	["trapper"] = "rbxassetid://9166206875",
	["hatter"] = "rbxassetid://12509388633",
	["ninja"] = "rbxassetid://15517037848",
	["jailor"] = "rbxassetid://11664116980",
	["warrior"] = "rbxassetid://9166207008",
	["mage"] = "rbxassetid://10982191792",
	["void_dragon"] = "rbxassetid://10982192753",
	["cat"] = "rbxassetid://15350740470",
	["wind_walker"] = "rbxassetid://9872355499",
	['skeleton'] = "rbxassetid://120123419412119",
	['winter_lady'] = "rbxassetid://83274578564074",
	['soul_broker'] = 'rbxassetid://130409166262430'
}

local function isFirstPerson()
    if not (lplr.Character and lplr.Character:FindFirstChild("Head")) then
        return false
    end
    return (lplr.Character.Head.Position - gameCamera.CFrame.Position).Magnitude < 2
end

local function isFrozen(entity, threshold)
    threshold = threshold or 10
    local char
    if type(entity) == "table" and entity.Character then
        char = entity.Character
    elseif type(entity) == "Instance" and entity:IsA("Model") then
        char = entity
    elseif entity == nil then
        if not entitylib.isAlive then return false end
        char = entitylib.character.Character
    else
        return false
    end

    local stacks = char:GetAttribute("ColdStacks") or char:GetAttribute("FrostStacks")
               or char:GetAttribute("FreezeStacks") or char:GetAttribute("FROZEN_STACKS")
    if stacks and stacks >= threshold then return true end

    local statusEffects = char:GetAttribute("StatusEffects")
    if type(statusEffects) == "table" then
        for effectName, stackCount in pairs(statusEffects) do
            local nameLower = tostring(effectName):lower()
            if nameLower:match("cold") or nameLower:match("frost") or nameLower:match("freeze") then
                if type(stackCount) == "number" then
                    if stackCount >= threshold then return true end
                elseif stackCount then
                    return true
                end
            end
        end
    end

    if char:FindFirstChild("IceBlock") or char:FindFirstChild("FrozenBlock") or char:FindFirstChild("IceShell") then
        return true
    end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.WalkSpeed <= 2 then
        return true
    end

    return false
end

local sharedRaycast = RaycastParams.new()
sharedRaycast.FilterType = Enum.RaycastFilterType.Include
sharedRaycast.FilterDescendantsInstances = {workspace:FindFirstChild('Map') or workspace}

local function cloneRaycast()
    local r = RaycastParams.new()
    r.FilterType = sharedRaycast.FilterType
    r.FilterDescendantsInstances = sharedRaycast.FilterDescendantsInstances
    r.RespectCanCollide = sharedRaycast.RespectCanCollide
    return r
end

local function isSword()
    return store.hand and store.hand.toolType == 'sword'
end

local function hasValidWeapon()
    if not store.hand or not store.hand.tool then return false end
    local toolType = store.hand.toolType
    local toolName = store.hand.tool.Name:lower()
    if toolName:find('headhunter') then return true end
    return toolType == 'sword' or toolType == 'bow' or toolType == 'crossbow'
end

local function fixPosition(pos)
    if bedwars and bedwars.BlockController and bedwars.BlockController.getBlockPosition then
        return bedwars.BlockController:getBlockPosition(pos) * 3
    end
    return pos * 3
end

local function getAmmoForProjectile(check)
    for _, item in store.inventory.inventory.items do
        if check.ammoItemTypes and table.find(check.ammoItemTypes, item.itemType) then
            return item.itemType
        end
    end
end

local function getProjectileItems(ammoFilter)
    local items = {}
    for _, item in store.inventory.inventory.items do
        local _itemMeta = bedwars.ItemMeta[item.itemType]
        local proj = _itemMeta and _itemMeta.projectileSource
        local ammo = proj and getAmmoForProjectile(proj)
        if ammo and table.find(ammoFilter, ammo) then
            table.insert(items, {item, ammo, proj.projectileType(ammo), proj})
        end
    end
    return items
end

local function isHoldingItem(keywords, includeProjectileSource)
    if not store.hand or not store.hand.tool then return false end
    local toolName = store.hand.tool.Name:lower()
    for _, kw in ipairs(keywords) do
        if toolName:find(kw) then return true end
    end
    if includeProjectileSource then
        return bedwars.ItemMeta[toolName] and bedwars.ItemMeta[toolName].projectileSource and true or false
    end
    return false
end

local function isHoldingBowCrossbow(includeProjectileSource)
    return isHoldingItem({'bow', 'crossbow', 'headhunter'}, includeProjectileSource)
end

local function isHoldingPickaxe()
    return isHoldingItem({'pickaxe'})
end

local function isEnemy(ent)
    if not ent then return false end
    if ent.Character and ent.Character:HasTag('petrified-player') then return false end
    if ent.Player then
        local myTeam = lplr:GetAttribute('Team')
        local theirTeam = ent.Player:GetAttribute('Team')
        if not myTeam or not theirTeam or myTeam == theirTeam then return false end
        return true
    elseif ent.NPC then
        local npcTeam = ent.Character:GetAttribute('Team')
        if npcTeam then return lplr:GetAttribute('Team') ~= npcTeam end
        return true
    end
    return false
end

local function getShopNPC()
    local shop, items, upgrades, newid = nil, false, false, nil
    if entitylib.isAlive then
        local localPosition = entitylib.character.RootPart.Position
        for _, v in store.shop do
            if (v.RootPart.Position - localPosition).Magnitude <= 20 then
                shop = v.Upgrades or v.Shop or nil
                upgrades = upgrades or v.Upgrades
                items = items or v.Shop
                newid = v.Shop and v.Id or newid
            end
        end
    end
    return shop, items, upgrades, newid
end

local function isTeammate(player)
    if not lplr or not player then return false end
    local myTeam = lplr:GetAttribute('Team')
    local theirTeam = player:GetAttribute('Team')
    return myTeam and theirTeam and myTeam == theirTeam
end

local function getPlayerName(player, useDisplayName)
    if not player then return '' end
    return (useDisplayName and player.DisplayName ~= "" and player.DisplayName) or player.Name
end

local armorTiers = {'none','leather_chestplate','iron_chestplate','diamond_chestplate','emerald_chestplate'}
local function getArmorTier(player)
    if not player or not store.inventories[player] then return 0 end
    local chest = store.inventories[player].armor and store.inventories[player].armor[5]
    if not chest or chest == 'empty' then return 1 end
    return table.find(armorTiers, chest.itemType) or 1
end

local function checkFaceAdjacent(pos, faces)
    faces = faces or {
        Vector3.new(3,0,0), Vector3.new(-3,0,0), Vector3.new(0,3,0),
        Vector3.new(0,-3,0), Vector3.new(0,0,3), Vector3.new(0,0,-3)
    }
    for _, v in ipairs(faces) do
        if getPlacedBlock(pos + v) then return true end
    end
    return false
end

local _isAboveVoidParams = RaycastParams.new()
_isAboveVoidParams.FilterType = Enum.RaycastFilterType.Exclude
local function isAboveVoid(position)
    if not entitylib.isAlive or not entitylib.character then return false end
    _isAboveVoidParams.FilterDescendantsInstances = {entitylib.character.Character}
    local result = workspace:Raycast(position, Vector3.new(0, -500, 0), _isAboveVoidParams)
    return result == nil
end

local function hasFaceBelowOrSide(pos)
    if getPlacedBlock(pos - Vector3.new(0,3,0)) then return true end
    local sides = {Vector3.new(3,0,0), Vector3.new(-3,0,0), Vector3.new(0,0,3), Vector3.new(0,0,-3)}
    for _, v in ipairs(sides) do
        if getPlacedBlock(pos + v) then return true end
    end
    return false
end

local function nearCorner(poscheck, pos)
    local start = poscheck - Vector3.new(3,3,3)
    local fin = poscheck + Vector3.new(3,3,3)
    local dir = (pos - poscheck).Unit * 100
    local check = poscheck + dir
    return Vector3.new(
        math.clamp(check.X, start.X, fin.X),
        math.clamp(check.Y, start.Y, fin.Y),
        math.clamp(check.Z, start.Z, fin.Z)
    )
end

local function blockProximity(pos, rangeBlocks)
    rangeBlocks = rangeBlocks or 21
    local mag, best = 60, nil
    local blocks = getBlocksInPoints(
        bedwars.BlockController:getBlockPosition(pos - Vector3.new(rangeBlocks,rangeBlocks,rangeBlocks)),
        bedwars.BlockController:getBlockPosition(pos + Vector3.new(rangeBlocks,rangeBlocks,rangeBlocks))
    )
    for _, v in ipairs(blocks) do
        local bp = nearCorner(v, pos)
        local d = (pos - bp).Magnitude
        if hasFaceBelowOrSide(bp) and d < mag then
            mag, best = d, bp
        end
    end
    return best
end

local function isGUIOpen()
    return bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN)
        or bedwars.AppController:isLayerOpen(bedwars.UILayers.DIALOG)
        or bedwars.AppController:isLayerOpen(bedwars.UILayers.POPUP)
        or bedwars.AppController:isAppOpen('BedwarsItemShopApp')
        or (bedwars.Store:getState().Inventory and bedwars.Store:getState().Inventory.open)
end

local function isTargetValid(ent, maxDist, checkWalls)
    if not ent or not ent.RootPart or not ent.Character then return false end
    if not entitylib.isAlive then return false end
    local dist = (ent.RootPart.Position - entitylib.character.RootPart.Position).Magnitude
    if dist > maxDist then return false end
    if checkWalls then
        local ray = workspace:Raycast(
            entitylib.character.RootPart.Position,
            (ent.RootPart.Position - entitylib.character.RootPart.Position),
            sharedRaycast
        )
        if ray then return false end
    end
    local hum = ent.Character:FindFirstChild("Humanoid")
    return hum and hum.Health > 0
end

local function getTargetByPriority(originPos, range, opts)
    opts = opts or {}
    local players = opts.players == nil and true or opts.players
    local npcs = opts.npcs or false
    local walls = opts.walls or false
    local sort = opts.sort or 'distance' -- 'health','armor','damage'
    local damageTracker = opts.damageTracker 

    local valid = {}
    for _, ent in ipairs(entitylib.List) do
        if (players and ent.Player) or (npcs and ent.NPC) then
            if isEnemy(ent) and ent.RootPart then
                local dist = (ent.RootPart.Position - originPos).Magnitude
                if dist <= range then
                    if walls then
                        local ray = workspace:Raycast(originPos, (ent.RootPart.Position - originPos), sharedRaycast)
                        if not ray then
                            table.insert(valid, ent)
                        end
                    else
                        table.insert(valid, ent)
                    end
                end
            end
        end
    end
    if #valid == 0 then return nil end

    if sort == 'distance' then
        table.sort(valid, function(a,b)
            return (a.RootPart.Position - originPos).Magnitude < (b.RootPart.Position - originPos).Magnitude
        end)
    elseif sort == 'damage' and damageTracker then
        table.sort(valid, function(a,b)
            local keyA = a.Player and a.Player.UserId or tostring(a)
            local keyB = b.Player and b.Player.UserId or tostring(b)
            return (damageTracker[keyA] or 0) > (damageTracker[keyB] or 0)
        end)
    elseif sort == 'health' then
        table.sort(valid, function(a,b)
            return a.Health < b.Health
        end)
    elseif sort == 'armor' then
        table.sort(valid, function(a,b)
            return getArmorTier(a.Player) < getArmorTier(b.Player)
        end)
    end
    return valid[1]
end

local isMobile = inputService.TouchEnabled and not inputService.KeyboardEnabled and not inputService.MouseEnabled

local function getTeammates(namesOnly)
    local result = {}
    local myTeam = lplr:GetAttribute('Team')
    if not myTeam then return result end
    for _, player in playersService:GetPlayers() do
        if player ~= lplr and player:GetAttribute('Team') == myTeam then
            if namesOnly then
                table.insert(result, player.Name)
            elseif player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
                table.insert(result, player)
            end
        end
    end
    if namesOnly then
        table.sort(result)
    end
    return result
end

local function getNearestTeammateInRange(range, condition)
    if not entitylib.isAlive then return nil end
    local myPos = entitylib.character.RootPart.Position
    local nearest = nil
    local nearestDist = math.huge
    for _, player in ipairs(getTeammates()) do
        if player.Character and player.Character.PrimaryPart then
            local dist = (player.Character.PrimaryPart.Position - myPos).Magnitude
            if dist <= range then
                if condition and not condition(player) then continue end
                if dist < nearestDist then
                    nearestDist = dist
                    nearest = player
                end
            end
        end
    end
    return nearest
end

local function getPlayerHealth(player)
    if not player or not player.Character then return 0, 100 end
    local health = player.Character:GetAttribute('Health') or (player.Character:FindFirstChildOfClass('Humanoid') and player.Character.Humanoid.Health) or 0
    local maxHealth = player.Character:GetAttribute('MaxHealth') or (player.Character:FindFirstChildOfClass('Humanoid') and player.Character.Humanoid.MaxHealth) or 100
    return health, maxHealth
end

local function getPlayerHealthPercent(player)
    local health, maxHealth = getPlayerHealth(player)
    if maxHealth == 0 then return 0 end
    return (health / maxHealth) * 100
end

local function leftClick()
	pcall(function()
		VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
		task.wait(0.05)
		VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
	end)
end

local function getWorldFolder()
    local Map = workspace:FindFirstChild("Map")
    if not Map then return nil end
    local Worlds = Map:FindFirstChild("Worlds")
    if not Worlds then return nil end
    for _, world in Worlds:GetChildren() do
        return world
    end
    return nil
end

local function getPickaxeSlot()
	for i, v in store.inventory.hotbar do
		if v.item and bedwars.ItemMeta[v.item.itemType] then
			local meta = bedwars.ItemMeta[v.item.itemType]
			if meta.breakBlock then
				return i - 1
			end
		end
	end
	return nil
end

local function getScaffoldBlockForModule(limitItem)
	if limitItem.Enabled then
		if store.hand.toolType == 'block' then
			return store.hand.tool.Name
		end
		return nil
	else
		local wool = getWool()
		if wool then
			return wool
		else
			for _, item in store.inventory.inventory.items do
				local meta = bedwars.ItemMeta[item.itemType]
				if meta and meta.block then
					return item.itemType
				end
			end
		end
	end
	return nil
end

local function safeIsBreakable(pos)
    if not bedwars.BlockController then return false end
    local ok, result = pcall(function()
        return bedwars.BlockController:isBlockBreakable({blockPosition = pos / 3}, lplr)
    end)
    return ok and result
end

--[[
	Combat Modules
]]

run(function()
    local Mode
    local Expand
    local AutoToggle
    local Visible
    local VisibleColor
    local Targets
    local objects = {}
    local set = false
    local hitboxesActive = false
    local autoToggleConnection = nil
    local autoToggleFrameCounter = 0

    local vector3new = Vector3.new
    local vector3one = Vector3.one

    local colorList = {
        Red = Color3.fromRGB(255, 0, 0),
        Blue = Color3.fromRGB(0, 100, 255),
        Green = Color3.fromRGB(0, 255, 0),
        Yellow = Color3.fromRGB(255, 255, 0),
        Orange = Color3.fromRGB(255, 140, 0),
        Purple = Color3.fromRGB(180, 0, 255),
        White = Color3.fromRGB(255, 255, 255),
        Cyan = Color3.fromRGB(0, 255, 255),
        Pink = Color3.fromRGB(255, 50, 150),
        Black = Color3.fromRGB(0, 0, 0)
    }

    local function shouldCreateHitbox(ent)
        if not ent.Targetable then return false end
        if ent.Player and Targets and Targets.Players and Targets.Players.Enabled then return true end
        if not ent.Player and Targets and Targets.NPCs and Targets.NPCs.Enabled then return true end
        return false
    end

    local _wallRayParams = RaycastParams.new()
    _wallRayParams.FilterType = Enum.RaycastFilterType.Exclude
    local function isTargetBehindWall(ent)
        if not Targets or not Targets.Walls or not Targets.Walls.Enabled then return false end
        if not ent.RootPart then return false end
        if not entitylib.isAlive or not entitylib.character or not entitylib.character.RootPart then return false end
        local origin = entitylib.character.RootPart.Position
        local target = ent.RootPart.Position
        local direction = target - origin
        _wallRayParams.FilterDescendantsInstances = {entitylib.character, ent.Character}
        local result = workspace:Raycast(origin, direction, _wallRayParams)
        if result then
            local hitDist = (result.Position - origin).Magnitude
            local targetDist = direction.Magnitude
            if hitDist < targetDist - 0.5 then return true end
        end
        return false
    end

    local cachedExpandSize = vector3new(3, 6, 3)
    local lastExpandValue = 0
    local function updateExpandSize(val)
        if val ~= lastExpandValue then
            lastExpandValue = val
            cachedExpandSize = vector3new(3, 6, 3) + vector3one * (val / 5)
        end
    end

    local function createHitbox(ent)
        if not shouldCreateHitbox(ent) then return end
        if isTargetBehindWall(ent) then return end
        if objects[ent] then return end
        local hitbox = Instance.new('Part')
        hitbox.Size = cachedExpandSize
        hitbox.Position = ent.RootPart.Position
        hitbox.CanCollide = false
        hitbox.Massless = true
        hitbox.Transparency = Visible and Visible.Enabled and 0.5 or 1
        if Visible and Visible.Enabled and VisibleColor then
            hitbox.Color = colorList[VisibleColor.Value] or colorList.Red
        end
        hitbox.Parent = ent.Character
        local weld = Instance.new('Motor6D')
        weld.Part0 = hitbox
        weld.Part1 = ent.RootPart
        weld.Parent = hitbox
        local ev = Instance.new('ObjectValue')
        ev.Name = 'EntityValue'
        ev.Value = ent.Character
        ev.Parent = hitbox
        game:GetService('CollectionService'):AddTag(hitbox, 'Hitbox')
        hitbox:GetPropertyChangedSignal('Transparency'):Connect(function()
            local want = Visible and Visible.Enabled and 0.5 or 1
            if hitbox.Transparency ~= want then
                hitbox.Transparency = want
            end
        end)
        objects[ent] = hitbox
    end

    local function clearHitboxes()
        for _, part in pairs(objects) do part:Destroy() end
        table.clear(objects)
    end

    local function refreshAllHitboxes()
        clearHitboxes()
        local entityList = entitylib.List
        for i = 1, #entityList do
            createHitbox(entityList[i])
        end
    end

    local function handleAutoToggle()
        if not AutoToggle or not AutoToggle.Enabled then return end
        if not HitBoxes.Enabled or Mode.Value ~= 'Player' then return end
        local holdingSword = isSword()
        if holdingSword and not hitboxesActive then
            hitboxesActive = true
            refreshAllHitboxes()
        elseif not holdingSword and hitboxesActive then
            hitboxesActive = false
            clearHitboxes()
        end
    end

    HitBoxes = vape.Categories.Utility:CreateModule({
        Name = 'HitBoxes',
        Function = function(callback)
            if callback then
                updateExpandSize(Expand.Value)
                if Mode.Value == 'Sword' then
                    debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (Expand.Value / 3))
                    set = true
                else
                    HitBoxes:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
                        if AutoToggle and AutoToggle.Enabled then
                            if hitboxesActive then createHitbox(ent) end
                        else
                            createHitbox(ent)
                        end
                    end))
                    HitBoxes:Clean(entitylib.Events.EntityRemoving:Connect(function(ent)
                        local obj = objects[ent]
                        if obj then obj:Destroy() objects[ent] = nil end
                    end))
                    if AutoToggle and AutoToggle.Enabled then
                        handleAutoToggle()
                        if not autoToggleConnection or not autoToggleConnection.Connected then
                            autoToggleFrameCounter = 0
                            autoToggleConnection = runService.Heartbeat:Connect(function()
                                autoToggleFrameCounter = autoToggleFrameCounter + 1
                                if autoToggleFrameCounter % 5 == 0 then
                                    handleAutoToggle()
                                end
                            end)
                            HitBoxes:Clean(autoToggleConnection)
                        end
                    else
                        refreshAllHitboxes()
                    end
                    local hitboxThrottleCounter = 0
                    HitBoxes:Clean(runService.Heartbeat:Connect(function()
                        if not Targets or not Targets.Walls or not Targets.Walls.Enabled then return end
                        hitboxThrottleCounter = hitboxThrottleCounter + 1
                        if hitboxThrottleCounter % 20 ~= 0 then return end
                        for ent, part in pairs(objects) do
                            if isTargetBehindWall(ent) then
                                part:Destroy()
                                objects[ent] = nil
                            end
                        end
                        local entityList = entitylib.List
                        for i = 1, #entityList do
                            local ent = entityList[i]
                            if not objects[ent] then
                                if AutoToggle and AutoToggle.Enabled then
                                    if hitboxesActive then createHitbox(ent) end
                                else
                                    createHitbox(ent)
                                end
                            end
                        end
                    end))
                end
            else
                hitboxesActive = false
                if set then
                    debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, 3.8)
                    set = false
                end
                clearHitboxes()
            end
        end,
        Tooltip = 'increases attack hitbox'
    })

    Targets = HitBoxes:CreateTargets({
        Players = true,
        Walls = false,
        NPCs = false,
        Function = function()
            if HitBoxes.Enabled and Mode.Value == 'Player' then
                if AutoToggle and AutoToggle.Enabled then
                    if hitboxesActive then refreshAllHitboxes() end
                else
                    refreshAllHitboxes()
                end
            end
        end
    })

    Mode = HitBoxes:CreateDropdown({
        Name = 'Mode',
        List = {'Sword', 'Player'},
        Function = function(val)
            local isPlayer = val == 'Player'
            if AutoToggle then AutoToggle.Object.Visible = isPlayer end
            if Visible then Visible.Object.Visible = isPlayer end
            if VisibleColor then VisibleColor.Object.Visible = isPlayer and Visible.Enabled end
            if HitBoxes.Enabled then HitBoxes:Toggle() HitBoxes:Toggle() end
        end,
    })

    Expand = HitBoxes:CreateSlider({
        Name = 'Expand amount',
        Min = 0,
        Max = 30,
        Default = 14.4,
        Decimal = 10,
        Function = function(val)
            updateExpandSize(val)
            if HitBoxes.Enabled then
                if Mode.Value == 'Sword' then
                    debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (val / 3))
                else
                    for _, part in pairs(objects) do part.Size = cachedExpandSize end
                end
            end
        end,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })

    AutoToggle = HitBoxes:CreateToggle({
        Name = 'Auto Toggle',
        Default = false,
        Tooltip = 'enables hitbox when holding sword, disable when not',
        Function = function(callback)
            if callback then
                if autoToggleConnection then autoToggleConnection:Disconnect() end
                hitboxesActive = false
                autoToggleFrameCounter = 0
                autoToggleConnection = runService.Heartbeat:Connect(function()
                    autoToggleFrameCounter = autoToggleFrameCounter + 1
                    if autoToggleFrameCounter % 5 == 0 then
                        handleAutoToggle()
                    end
                end)
                HitBoxes:Clean(autoToggleConnection)
                handleAutoToggle()
            else
                if autoToggleConnection then
                    autoToggleConnection:Disconnect()
                    autoToggleConnection = nil
                end
                hitboxesActive = false
                if HitBoxes.Enabled and Mode.Value == 'Player' then
                    refreshAllHitboxes()
                end
            end
        end
    })

    Visible = HitBoxes:CreateToggle({
        Name = 'Visible',
        Default = false,
        Function = function(callback)
            if VisibleColor then VisibleColor.Object.Visible = callback end
            if HitBoxes.Enabled and Mode.Value == 'Player' then
                local transparency = callback and 0.5 or 1
                local col = callback and VisibleColor and (colorList[VisibleColor.Value] or colorList.Red) or nil
                for _, part in pairs(objects) do
                    part.Transparency = transparency
                    if col then part.Color = col end
                end
            end
        end
    })

    VisibleColor = HitBoxes:CreateDropdown({
        Name = 'Hitbox Color',
        List = {'Red', 'Blue', 'Green', 'Yellow', 'Orange', 'Purple', 'White', 'Cyan', 'Pink', 'Black'},
        Default = 'Red',
        Visible = false,
        Function = function(val)
            if HitBoxes.Enabled and Mode.Value == 'Player' and Visible.Enabled then
                local col = colorList[val] or colorList.Red
                for _, part in pairs(objects) do part.Color = col end
            end
        end
    })

    task.spawn(function()
        repeat task.wait() until Mode and Mode.Value
        local isPlayer = Mode.Value == 'Player'
        AutoToggle.Object.Visible = isPlayer
        Visible.Object.Visible = isPlayer
    end)

    task.defer(function()
        if VisibleColor and VisibleColor.Object then
            VisibleColor.Object.Visible = false
        end
    end)
end)

run(function()
    local ShopAutoClicker 
    local CPS
    local holding = false
    local clickThread
    
    local function getShopId()
        if not entitylib.isAlive then return nil end
        local localPosition = entitylib.character.RootPart.Position
        local id
        for _, v in store.shop do
            if v.Shop and (v.RootPart.Position - localPosition).Magnitude <= 20 then
                id = v.Id
            end
        end
        return id
    end
    
    local function getHoveredItem(pos)
        local mousepos = (pos or inputService:GetMouseLocation()) - guiService:GetGuiInset()
        for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
            local obj = v
            while obj and obj ~= lplr.PlayerGui do
                local itemType = obj.Name:match('^(.+)_ShopItemCard$')
                if itemType then
                    return itemType
                end
                obj = obj.Parent
            end
        end
    end
    
    local function canBuy(item)
        if item.ignoredByKit and table.find(item.ignoredByKit, store.equippedKit or '') then return false end
        if item.lockedByForge or item.disabled then return false end
        if item.require and item.require.teamUpgrade then
            if (bedwars.Store:getState().Bedwars.teamUpgrades[item.require.teamUpgrade.upgradeId] or -1) < item.require.teamUpgrade.lowestTierIndex then
                return false
            end
        end
        local currency = getItem(item.currency)
        return (currency and currency.amount or 0) >= item.price
    end
    
    local function purchase(itemType, shopId)
        if bedwars.BedwarsShopController.alreadyPurchasedMap[itemType] ~= nil then return end
    
        local item = bedwars.Shop.getShopItem(itemType, lplr, {shopId = shopId})
        if not item or not canBuy(item) then return end
    
        bedwars.Client:Get('BedwarsPurchaseItem'):CallServerAsync({
            shopItem = item,
            shopId = shopId
        }):andThen(function(suc)
            if not suc then return end
            bedwars.SoundManager:playSound(bedwars.SoundList.BEDWARS_PURCHASE_ITEM)
            bedwars.Store:dispatch({
                type = 'BedwarsAddItemPurchased',
                itemType = itemType
            })
            if item.tiered then
                bedwars.BedwarsShopController.alreadyPurchasedMap[itemType] = true
            end
        end)
    end
    
    local function startClicking(itemType)
        if clickThread then
            task.cancel(clickThread)
        end
        clickThread = task.spawn(function()
            repeat
                local shopId = bedwars.AppController:isAppOpen('BedwarsItemShopApp') and store.shopLoaded and getShopId()
                if shopId then
                    purchase(itemType, shopId)
                end
                task.wait(1 / CPS.Value)
            until not holding
            clickThread = nil
        end)
    end
    
    ShopAutoClicker = vape.Categories.Utility:CreateModule({
        Name = 'ShopAutoClicker',
        Tooltip = 'hold on a shop item to buy - idea from seven (cv)',
        Function = function(callback)
            if callback then
                ShopAutoClicker:Clean(inputService.InputBegan:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
                    if not bedwars.AppController:isAppOpen('BedwarsItemShopApp') then return end
    
                    local pos
                    if input.UserInputType == Enum.UserInputType.Touch then
                        pos = Vector2.new(input.Position.X, input.Position.Y)
                    end
                    local itemType = getHoveredItem(pos)
                    if not itemType then return end
    
                    holding = true
                    task.delay(0.1, function() 
                        if holding and getHoveredItem(pos) == itemType then
                            startClicking(itemType)
                        end
                    end)
                end))
    
                ShopAutoClicker:Clean(inputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        holding = false
                    end
                end))
            else
                holding = false
                if clickThread then
                    task.cancel(clickThread)
                    clickThread = nil
                end
            end
        end
    })
    CPS = ShopAutoClicker:CreateSlider({
        Name = 'CPS',
        Min = 1,
        Max = 20,
        Default = 20
    })
end)

run(function()
	local AimAssist
	local Targets
	local Sort
	local AimSpeed
	local Smoothness
	local SmoothnessToggle
	local Distance
	local AngleSlider
	local KillauraTarget
	local ClickAim
	local ShopCheck
	local AimPart
	local ViewMode
	local PriorityMode
	local ShakeToggle
	local ShakeAmount
	local WorkWithProjectiles
	local ProjectileDistance
	local activeRange = 25

	local function getHeldProjectileMeta()
		local tool = store.hand and store.hand.tool
		local itemMeta = tool and bedwars.ItemMeta[tool.Name]
		local source = itemMeta and itemMeta.projectileSource
		if not source or not source.projectileType then return nil end
		local ammo = tool.Name
		if source.ammoItemTypes and #source.ammoItemTypes > 0 then
			ammo = nil
			for _, item in store.inventory.inventory.items do
				if table.find(source.ammoItemTypes, item.itemType) then
					ammo = item.itemType
					break
				end
			end
		end
		if not ammo then return nil end
		local ok, projType = pcall(source.projectileType, ammo)
		local projMeta = ok and projType and bedwars.ProjectileMeta[projType]
		if projMeta and type(projMeta.launchVelocity) == 'number' then
			return projMeta
		end
		return nil
	end
	local lockedTarget = nil
	local lastValidTarget = nil
	local lastValidTime = 0
	local GRACE_PERIOD = 0.15
	local rng = Random.new()
	local shakeTime = 0
	local shakeSeed = rng:NextNumber() * 1000

	local function getAimAlpha(speedVal, smoothVal, dt)
		local baseAlpha = math.clamp(speedVal * 0.025, 0.005, 0.98)
		if smoothVal then
			local smoothFactor = math.max(1 - ((smoothVal - 1) / 9) * 0.85, 0.05)
			baseAlpha = baseAlpha * smoothFactor
		end
		return 1 - (1 - baseAlpha) ^ (dt * 60)
	end

	local function getClosestPartToCursor(character)
		local mousePos = inputService.TouchEnabled and (gameCamera.ViewportSize / 2) or inputService:GetMouseLocation()
		local mouseRay = gameCamera:ViewportPointToRay(mousePos.X, mousePos.Y, 0)
		local bestAngle = math.huge
		local bestPart = nil
		local partNames = {
			'Head', 'UpperTorso', 'LowerTorso', 'HumanoidRootPart',
			'LeftUpperArm', 'RightUpperArm', 'LeftLowerArm', 'RightLowerArm',
			'LeftUpperLeg', 'RightUpperLeg', 'LeftLowerLeg', 'RightLowerLeg',
			'LeftFoot', 'RightFoot', 'LeftHand', 'RightHand'
		}
		for _, partName in partNames do
			local part = character:FindFirstChild(partName)
			if part then
				local dirToPart = (part.Position - mouseRay.Origin).Unit
				local angle = math.acos(math.clamp(mouseRay.Direction:Dot(dirToPart), -1, 1))
				if angle < bestAngle then
					bestAngle = angle
					bestPart = part
				end
			end
		end
		return bestPart
	end

	local function isEntValid(ent)
		if not ent or not ent.RootPart or not ent.Character or not ent.Character.Parent then return false end
		if not entitylib.isAlive or not entitylib.character or not entitylib.character.RootPart then return false end
		local hum = ent.Character:FindFirstChildOfClass('Humanoid')
		if not hum or hum.Health <= 0 then return false end
		local dist = (ent.RootPart.Position - entitylib.character.RootPart.Position).Magnitude
		if dist > Distance.Value then return false end
		if not isEnemy(ent) then return false end
		return true
	end

	local function isInAngle(ent)
		if not ent or not ent.RootPart then return false end
		if not entitylib.character or not entitylib.character.RootPart then return false end
		local delta = (ent.RootPart.Position - entitylib.character.RootPart.Position)
		local localFacing = ((getgenv().ViewMode and getgenv().ViewMode.Value == 'Third Person') and gameCamera.CFrame.LookVector or entitylib.character.RootPart.CFrame.LookVector) * Vector3.new(1, 0, 1)
		local flatDelta = delta * Vector3.new(1, 0, 1)
		if flatDelta.Magnitude <= 0.001 then return false end
		local angle = math.acos(math.clamp(localFacing:Dot(flatDelta.Unit), -1, 1))
		return angle < math.rad(AngleSlider.Value / 2)
	end

	AimAssist = vape.Categories.Combat:CreateModule({
		Name = 'AimAssist',
		Function = function(callback)
			if callback then
				lockedTarget = nil
				lastValidTarget = nil
				lastValidTime = 0
				shakeTime = 0
				local aimBindName = 'vapeAimAssist'
				AimAssist:Clean(function()
					pcall(function() runService:UnbindFromRenderStep(aimBindName) end)
				end)
				runService:BindToRenderStep(aimBindName, Enum.RenderPriority.Camera.Value + 1, (function(dt)

					if not entitylib.isAlive or not entitylib.character or not entitylib.character.RootPart then
						lockedTarget = nil
						return
					end

					local validWeapon = store.hand.toolType == 'sword'
					if WorkWithProjectiles and WorkWithProjectiles.Enabled then
						validWeapon = validWeapon or isHoldingBowCrossbow()
					end
					if not validWeapon then
						lockedTarget = nil
						return
					end

					if ClickAim and ClickAim.Enabled then
						local sc = bedwars.SwordController
						local lastAttack = sc and rawget(sc, 'lastAttack')
						if not lastAttack or (workspace:GetServerTimeNow() - lastAttack) >= 0.4 then
							return
						end
					end

					local inFirstPerson = isFirstPerson()
					if ViewMode.Value == 'First Person' and not inFirstPerson then return end
					if ViewMode.Value == 'Third Person' and inFirstPerson then return end

					if ShopCheck and ShopCheck.Enabled then
						if isGUIOpen() then
							lockedTarget = nil
							return
						end
					end

					local ent = nil

					if KillauraTarget and KillauraTarget.Enabled then
						local ka = store.KillauraTarget
						if ka and ka.RootPart and ka.Character and ka.Character.Parent then
							local hum = ka.Character:FindFirstChildOfClass('Humanoid')
							local dist = ka.RootPart and entitylib.character and entitylib.character.RootPart and (ka.RootPart.Position - entitylib.character.RootPart.Position).Magnitude
							if hum and hum.Health > 0 and dist and dist <= Distance.Value then
								ent = ka
							end
						end
					else
						if PriorityMode and PriorityMode.Enabled and lockedTarget then
							if isEntValid(lockedTarget) and isInAngle(lockedTarget) then
								ent = lockedTarget
							else
								lockedTarget = nil
							end
						end

						if not ent then
							local found = entitylib.EntityPosition({
								Range = Distance.Value,
								Part = 'RootPart',
								Wallcheck = Targets.Walls.Enabled,
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled,
								Sort = sortmethods[Sort.Value]
							})

							if found then
								lastValidTarget = found
								lastValidTime = tick()
								ent = found
							elseif lastValidTarget and (tick() - lastValidTime) < GRACE_PERIOD then
								local hum = lastValidTarget.Character and lastValidTarget.Character:FindFirstChildOfClass('Humanoid')
								if hum and hum.Health > 0 and lastValidTarget.Character.Parent and isInAngle(lastValidTarget) then
									ent = lastValidTarget
								else
									lastValidTarget = nil
								end
							end

							if ent and PriorityMode and PriorityMode.Enabled then
								lockedTarget = ent
							end
						end
					end	

					if not ent then return end

					if not (KillauraTarget and KillauraTarget.Enabled) then
						if not isEntValid(ent) then
							if PriorityMode and PriorityMode.Enabled then lockedTarget = nil end
							lastValidTarget = nil
							return
						end
						if not isInAngle(ent) then
							if PriorityMode and PriorityMode.Enabled then lockedTarget = nil end
							return
						end
					end

					targetinfo.Targets[ent] = tick() + 1

					local aimPosition
					if AimPart.Value == 'Head' then
						local head = ent.Character and ent.Character:FindFirstChild('Head')
						aimPosition = head and head.Position or ent.RootPart.Position
					elseif AimPart.Value == 'Torso' then
						local torso = ent.Character and (ent.Character:FindFirstChild('UpperTorso') or ent.Character:FindFirstChild('Torso'))
						aimPosition = torso and torso.Position or ent.RootPart.Position
					elseif AimPart.Value == 'Closest' then
						local closest = ent.Character and getClosestPartToCursor(ent.Character)
						aimPosition = closest and closest.Position or ent.RootPart.Position
					else
						aimPosition = ent.RootPart.Position
					end

					if ShakeToggle and ShakeToggle.Enabled and ShakeAmount.Value > 0 then
						shakeTime = shakeTime + dt
						local camCF = gameCamera.CFrame
						local dist = (aimPosition - camCF.Position).Magnitude
						local intensity = ShakeAmount.Value * 0.0035 * math.max(dist, 1)
						local driftX = math.noise(shakeTime * 0.8, 0, shakeSeed) * 2
						local driftY = math.noise(0, shakeTime * 0.7, shakeSeed) * 2
						local microX = math.noise(shakeTime * 9.5, shakeSeed, 0) * 2
						local microY = math.noise(shakeSeed, shakeTime * 10.7, 0) * 2
						local sx = (driftX * 0.7 + microX * 0.3) * intensity
						local sy = (driftY * 0.55 + microY * 0.25) * intensity
						aimPosition = aimPosition + camCF.RightVector * sx + camCF.UpVector * sy
					end

					local targetCFrame = CFrame.lookAt(gameCamera.CFrame.p, aimPosition)
					local smoothVal = (SmoothnessToggle and SmoothnessToggle.Enabled and Smoothness) and Smoothness.Value or nil
					local alpha = getAimAlpha(AimSpeed.Value, smoothVal, dt)
					gameCamera.CFrame = gameCamera.CFrame:Lerp(targetCFrame, alpha)
				end))
			else
				lockedTarget = nil
				lastValidTarget = nil
				shakeTime = 0
			end
		end,
		Tooltip = 'aa with smooth tracking'
	})

	Targets = AimAssist:CreateTargets({
		Players = true,
		Walls = true
	})

	Sort = AimAssist:CreateDropdown({
		Name = 'Target Mode',
		List = getSortList({'Damage', 'Distance'}),
		Tooltip = 'prioritize targets'
	})

	AimPart = AimAssist:CreateDropdown({
		Name = 'Aim Part',
		List = {'Torso', 'Head', 'Closest'},
		Default = 'Torso'
	})

	ViewMode = AimAssist:CreateDropdown({
		Name = 'View Mode',
		List = {'First Person', 'Third Person', 'Both'},
		Default = 'Both',
		Tooltip = 'either only aim in first person or third person, or both'
	})
	getgenv().ViewMode = ViewMode

	AimSpeed = AimAssist:CreateSlider({
		Name = 'Aim Speed',
		Min = 1,
		Max = 20,
		Default = 6,
		Tooltip = 'how fast aim assist moves toward the target'
	})

	Distance = AimAssist:CreateSlider({
		Name = 'Distance',
		Min = 1,
		Max = 30,
		Default = 25,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})

	AngleSlider = AimAssist:CreateSlider({
		Name = 'Max Angle',
		Min = 1,
		Max = 360,
		Default = 60,
	})

	SmoothnessToggle = AimAssist:CreateToggle({
		Name = 'Smoothness',
		Default = false,
		Tooltip = 'makes aim assist feels more legit',
		Function = function(callback)
			if Smoothness then Smoothness.Object.Visible = callback end
		end
	})

	Smoothness = AimAssist:CreateSlider({
		Name = 'Smoothness Amount',
		Min = 1,
		Max = 10,
		Default = 5,
		Visible = false
	})

	PriorityMode = AimAssist:CreateToggle({
		Name = 'Priority Mode',
		Default = false,
		Tooltip = 'stays on one target until target is lost'
	})

	ClickAim = AimAssist:CreateToggle({
		Name = 'Click Aim',
		Default = true,
		Tooltip = 'only aims when clicking'
	})

	KillauraTarget = AimAssist:CreateToggle({
		Name = 'Use Killaura Target',
	})

	ShakeToggle = AimAssist:CreateToggle({
		Name = 'Shake',
		Default = false,
		Tooltip = 'shakes your screen for more legitness',
		Function = function(callback)
			if ShakeAmount then ShakeAmount.Object.Visible = callback end
		end
	})

	ShakeAmount = AimAssist:CreateSlider({
		Name = 'Shake Amount',
		Min = 1,
		Max = 10,
		Default = 3,
		Visible = false
	})

	ShopCheck = AimAssist:CreateToggle({
		Name = 'Shop Check',
		Default = false,
	})

	WorkWithProjectiles = AimAssist:CreateToggle({
		Name = 'Work With Projectiles',
		Default = false,
	})

	task.defer(function()
		if Smoothness and Smoothness.Object then
			Smoothness.Object.Visible = SmoothnessToggle and SmoothnessToggle.Enabled or false
		end
		if ShakeAmount and ShakeAmount.Object then
			ShakeAmount.Object.Visible = false
		end
	end)
end)

run(function()
	local KnockbackDisplace
	local KBDirection
	local originalApplyKnockback
	local hookedUtil
	local installedHook
	local hooked = false

	local _cachedKnockbackUtil = nil
	local function findKnockbackUtil()
		if _cachedKnockbackUtil and rawget(_cachedKnockbackUtil, 'applyKnockback') then
			return _cachedKnockbackUtil
		end
		for _, v in getgc(true) do
			if type(v) == 'table' and rawget(v, 'applyKnockback') and rawget(v, 'getDirection') and rawget(v, 'applyKnockbackDirection') then
				_cachedKnockbackUtil = v
				return v
			end
		end
	end

	local function unhookKnockback()
		if hookedUtil and originalApplyKnockback then
			pcall(function()
				if rawget(hookedUtil, 'applyKnockback') == installedHook then
					hookedUtil.applyKnockback = originalApplyKnockback
				end
			end)
		end
		hookedUtil = nil
		installedHook = nil
		originalApplyKnockback = nil
		hooked = false
	end

	KnockbackDisplace = vape.Categories.Combat:CreateModule({
		Name = 'KnockbackDisplace',
		Function = function(callback)
			if callback then
				if hooked then return end
				local util = findKnockbackUtil()
				if not util then
					notif('KnockbackDisplace', 'Failed to hook knockback!', 3)
					KnockbackDisplace:Toggle()
					return
				end
				originalApplyKnockback = util.applyKnockback
				local capturedOriginal = originalApplyKnockback
				local hookFn = function(hrp, mass, sourcePos, modifier)
					if not capturedOriginal then return end
					if not KnockbackDisplace.Enabled then
						return capturedOriginal(hrp, mass, sourcePos, modifier)
					end
					local dir = KBDirection.Value
					if dir == 'Default' then
						return capturedOriginal(hrp, mass, sourcePos, modifier)
					elseif dir == 'Void' then
						hrp:ApplyImpulse(Vector3.new(0, -mass * 60, 0))
						return
					elseif dir == 'Up' then
						hrp:ApplyImpulse(Vector3.new(0, mass * 48, 0))
						return
					else
						local hrpPos = hrp.Position
						local cf = hrp.CFrame
						local fakeSource
						if dir == 'Left' then
							fakeSource = hrpPos + cf.RightVector * 10
						elseif dir == 'Right' then
							fakeSource = hrpPos - cf.RightVector * 10
						elseif dir == 'Reverse' then
							if sourcePos then
								fakeSource = Vector3.new(2 * hrpPos.X - sourcePos.X, sourcePos.Y, 2 * hrpPos.Z - sourcePos.Z)
							end
						end
						return capturedOriginal(hrp, mass, fakeSource or sourcePos, modifier)
					end
				end
				util.applyKnockback = hookFn
				hookedUtil = util
				installedHook = hookFn
				hooked = true
			else
				unhookKnockback()
			end
		end,
		Tooltip = 'changes your knockback direction'
	})

	vape:Clean(unhookKnockback)

	KBDirection = KnockbackDisplace:CreateDropdown({
		Name = 'KBDirection',
		List = {'Default', 'Backwards', 'Up', 'Left', 'Right', 'Reverse'},
		Default = 'Default',
		Tooltip = 'Choose which direction to redirect your knockback'
	})
end)

run(function()
	local Viewmodel
	local Depth
	local Horizontal
	local Vertical
	local NoBob
	local Rots = {}
	local old, oldc1
	
	Viewmodel = vape.Categories.Combat:CreateModule({
		Name = 'Viewmodel',
		Function = function(callback)
			local viewmodel = gameCamera:FindFirstChild('Viewmodel')
			if callback then
				old = bedwars.ViewmodelController.playAnimation
				oldc1 = viewmodel and viewmodel.RightHand.RightWrist.C1 or CFrame.identity
				if NoBob.Enabled then
					bedwars.ViewmodelController.playAnimation = function(self, animtype, ...)
						if bedwars.AnimationType and animtype == bedwars.AnimationType.FP_WALK then return end
						return old(self, animtype, ...)
					end
				end
	
				bedwars.InventoryViewmodelController:handleStore(bedwars.Store:getState())
				if viewmodel then
					gameCamera.Viewmodel.RightHand.RightWrist.C1 = oldc1 * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
				end
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', -Depth.Value)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', Horizontal.Value)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', Vertical.Value)
			else
				bedwars.ViewmodelController.playAnimation = old
				if viewmodel then
					viewmodel.RightHand.RightWrist.C1 = oldc1
				end
	
				bedwars.InventoryViewmodelController:handleStore(bedwars.Store:getState())
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', 0)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', 0)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', 0)
				old = nil
			end
		end,
		Tooltip = 'change viewmodel animations'
	})
	Depth = Viewmodel:CreateSlider({
		Name = 'Depth',
		Min = 0,
		Max = 2,
		Default = 0.8,
		Decimal = 10,
		Function = function(val)
			if Viewmodel.Enabled then
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', -val)
			end
		end
	})
	Horizontal = Viewmodel:CreateSlider({
		Name = 'Horizontal',
		Min = 0,
		Max = 2,
		Default = 0.8,
		Decimal = 10,
		Function = function(val)
			if Viewmodel.Enabled then
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', val)
			end
		end
	})
	Vertical = Viewmodel:CreateSlider({
		Name = 'Vertical',
		Min = -0.2,
		Max = 2,
		Default = -0.2,
		Decimal = 10,
		Function = function(val)
			if Viewmodel.Enabled then
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', val)
			end
		end
	})
	for _, name in {'Rotation X', 'Rotation Y', 'Rotation Z'} do
		table.insert(Rots, Viewmodel:CreateSlider({
			Name = name,
			Min = 0,
			Max = 360,
			Function = function(val)
				if Viewmodel.Enabled then
					gameCamera.Viewmodel.RightHand.RightWrist.C1 = oldc1 * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
				end
			end
		}))
	end
	NoBob = Viewmodel:CreateToggle({
		Name = 'No Bobbing',
		Default = true,
		Function = function()
			if Viewmodel.Enabled then
				Viewmodel:Toggle()
				Viewmodel:Toggle()
			end
		end
	})
end)

run(function()
    if isMobile then
        local AutoClicker
        local CPS
        local BlockCPS = {}
        local Thread

        local function getSafeCPS()
            if store.hand and store.hand.toolType == 'block' and BlockCPS and BlockCPS.GetRandomValue then
                return BlockCPS
            end
            if CPS and CPS.GetRandomValue then
                return CPS
            end
            return nil
        end

        local function AutoClick()
            if Thread then
                task.cancel(Thread)
                Thread = nil
            end

            local initialCPS = getSafeCPS()
            if not initialCPS then return end

            Thread = task.delay(1 / initialCPS.GetRandomValue(), function()
                repeat
                    if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
                        local blockPlacer = bedwars.BlockPlacementController and bedwars.BlockPlacementController.blockPlacer
                        local toolType = store.hand and store.hand.toolType

                        if toolType == 'block' and blockPlacer then
                            task.spawn(function()
                                blockPlacer:autoBridge(workspace:GetServerTimeNow() - bedwars.KnockbackController:getLastKnockbackTime() >= 0.2)
                            end)
                        elseif toolType == 'sword' then
                            bedwars.SwordController:swingSwordAtMouse(0.39)
                        end
                    end

                    local currentCPS = getSafeCPS()
                    if not currentCPS then
                        task.wait(0.1)
                    else
                        task.wait(1 / currentCPS.GetRandomValue())
                    end
                until not AutoClicker.Enabled
            end)
        end

        local function StopClick()
            if Thread then
                task.cancel(Thread)
                Thread = nil
            end
        end

        AutoClicker = vape.Categories.Combat:CreateModule({
            Name = 'AutoClicker',
            Function = function(callback)
                if callback then
                    AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            AutoClick()
                        end
                    end))

                    AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            StopClick()
                        end
                    end))

                    for _, v in {'2', '5'} do
                        pcall(function()
                            AutoClicker:Clean(lplr.PlayerGui.MobileUI[v].MouseButton1Down:Connect(AutoClick))
                            AutoClicker:Clean(lplr.PlayerGui.MobileUI[v].MouseButton1Up:Connect(StopClick))
                        end)
                    end
                else
                    StopClick()
                end
            end,
            Tooltip = 'clicks for you'
        })

        CPS = AutoClicker:CreateTwoSlider({
            Name = 'CPS',
            Min = 1,
            Max = 9,
            DefaultMin = 7,
            DefaultMax = 7
        })

        AutoClicker:CreateToggle({
            Name = 'Place Blocks',
            Default = true,
            Function = function(callback)
                if BlockCPS.Object then
                    BlockCPS.Object.Visible = callback
                end
            end
        })

        BlockCPS = AutoClicker:CreateTwoSlider({
            Name = 'Block CPS',
            Min = 1,
            Max = 20,
            DefaultMin = 12,
            DefaultMax = 12,
            Darker = true
        })

        task.defer(function()
            if BlockCPS and BlockCPS.Object then
                BlockCPS.Object.Visible = PlaceBlocksToggle and PlaceBlocksToggle.Enabled
            end
        end)

    else
        local AutoClicker
        local CPS
        local BlockCPS = {}
        local SwordCPS = {}
        local PlaceBlocksToggle
        local SwingSwordToggle
        local Thread

        local task_wait = task.wait
        local task_spawn = task.spawn
        local workspace_GetServerTimeNow = function() return workspace:GetServerTimeNow() end

        local function getSafeCPS()
            local toolType = store.hand and store.hand.toolType or nil
            if toolType == 'block' and PlaceBlocksToggle and PlaceBlocksToggle.Enabled and BlockCPS and BlockCPS.GetRandomValue then
                return BlockCPS
            elseif toolType == 'sword' and SwingSwordToggle and SwingSwordToggle.Enabled and SwordCPS and SwordCPS.GetRandomValue then
                return SwordCPS
            elseif CPS and CPS.GetRandomValue then
                return CPS
            end
            return nil
        end

        local function AutoClickskid()
            if Thread then task.cancel(Thread) end
            Thread = task_spawn(function()
                repeat
                    if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
                        local toolType = store.hand and store.hand.toolType
                        if PlaceBlocksToggle.Enabled and toolType == 'block' then
                            local blockPlacer = bedwars.BlockPlacementController and bedwars.BlockPlacementController.blockPlacer
                            if blockPlacer then
                                if (workspace_GetServerTimeNow() - bedwars.BlockCpsController.lastPlaceTimestamp) >= ((1 / 12) * 0.5) then
                                    local mouseinfo = blockPlacer.clientManager:getBlockSelector():getMouseInfo(0)
                                    if mouseinfo and mouseinfo.placementPosition == mouseinfo.placementPosition then
                                        task_spawn(blockPlacer.placeBlock, blockPlacer, mouseinfo.placementPosition)
                                    end
                                end
                            end
                        elseif SwingSwordToggle.Enabled and toolType == 'sword' then
                            bedwars.SwordController:swingSwordAtMouse(0.39)
                        end
                    end

                    local currentCPS = getSafeCPS()
                    task_wait(1 / (currentCPS and currentCPS.GetRandomValue() or 7))
                until not AutoClicker.Enabled
            end)
        end

        local function StopAutoClick()
            if Thread then
                task.cancel(Thread)
                Thread = nil
            end
        end

        local MIN_HOLD_TIME = 0.12
        local ActivationScheduled = nil

        AutoClicker = vape.Categories.Combat:CreateModule({
            Name = 'AutoClicker',
            Function = function(callback)
                if callback then
                    AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            ActivationScheduled = task.delay(MIN_HOLD_TIME, function()
                                ActivationScheduled = nil
                                if inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                                    AutoClickskid()
                                end
                            end)
                        end
                    end))
                    AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            if ActivationScheduled then
                                task.cancel(ActivationScheduled)
                                ActivationScheduled = nil
                            end
                            if Thread then
                                task.cancel(Thread)
                                Thread = nil
                            end
                        end
                    end))
                else
                    StopAutoClick()
                end
            end,
            Tooltip = 'clicks for you'
        })

        PlaceBlocksToggle = AutoClicker:CreateToggle({
            Name = 'Place Blocks',
            Default = false,
            Function = function(callback)
                task.defer(function()
                    if BlockCPS and BlockCPS.Object then BlockCPS.Object.Visible = callback end
                end)
            end
        })

        BlockCPS = AutoClicker:CreateTwoSlider({
            Name = 'Block CPS',
            Min = 1,
            Max = 20,
            DefaultMin = 12,
            DefaultMax = 12,
            Darker = true
        })

        SwingSwordToggle = AutoClicker:CreateToggle({
            Name = 'Swing Sword',
            Default = false,
            Function = function(callback)
                if SwordCPS.Object then SwordCPS.Object.Visible = callback end
            end
        })

        SwordCPS = AutoClicker:CreateTwoSlider({
            Name = 'Sword CPS',
            Min = 1,
            Max = 9,
            DefaultMin = 7,
            DefaultMax = 7,
            Darker = true
        })

        task.defer(function()
            if BlockCPS and BlockCPS.Object then
                BlockCPS.Object.Visible = PlaceBlocksToggle and PlaceBlocksToggle.Enabled
            end
            if SwordCPS and SwordCPS.Object then
                SwordCPS.Object.Visible = SwingSwordToggle and SwingSwordToggle.Enabled
            end
        end)
    end
end)  
	
run(function()
	local Attack
	local Mine
	local Place
	local oldAttackReach, oldMineReach, oldPlaceReach
	local SwordReach, MineReach
	local AirReach, AirReachChance
	local airReachState = false
	local airReachRolled = false
	local _airReachThread

	Reach = vape.Categories.Combat:CreateModule({
		Name = 'Reach',
		Function = function(callback)
			if callback then
				if SwordReach and SwordReach.Enabled then
					task.spawn(function()
						repeat task.wait(0.1) until (bedwars.CombatConstant and bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE) or not Reach.Enabled
						if not Reach.Enabled or not SwordReach.Enabled then return end
						oldAttackReach = bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE
						bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Attack.Value + 2
					end)
				end
				
				task.spawn(function()
					repeat task.wait(0.1) until bedwars.BlockBreakController or not Reach.Enabled
					if not Reach.Enabled or not MineReach or not MineReach.Enabled then return end
					
					pcall(function()
						local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
						if blockBreaker then
							oldMineReach = oldMineReach or blockBreaker:getRange()
							blockBreaker:setRange(Mine.Value)
						end
					end)
				end)
				
				local _reachLoopThread = task.spawn(function()
					while Reach.Enabled do
						task.wait(5)
						if not Reach.Enabled then break end
						if SwordReach.Enabled and not (AirReach and AirReach.Enabled) and bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE ~= Attack.Value + 2 then
							bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Attack.Value + 2
						end
						if MineReach.Enabled then
							pcall(function()
								local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
								if blockBreaker and blockBreaker:getRange() ~= Mine.Value then
									blockBreaker:setRange(Mine.Value)
								end
							end)
						end
					end
				end)
				airReachRolled = false
				_airReachThread = task.spawn(function()
					while Reach.Enabled do
						task.wait(0.05)
						if not Reach.Enabled then break end
						if not AirReach or not AirReach.Enabled or not SwordReach.Enabled then
							airReachRolled = false
						else
							local ent = store.KillauraTarget
							local tchar = ent and ent.Character
							local hum = tchar and tchar:FindFirstChildOfClass('Humanoid')
							local inAir = false
							if hum then
								inAir = hum.FloorMaterial == Enum.Material.Air
								if not inAir then
									local st = hum:GetState()
									inAir = st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall
								end
								if not inAir then
									local root = tchar.PrimaryPart
									local vy = root and root.AssemblyLinearVelocity.Y or 0
									inAir = math.abs(vy) > 3
								end
							end
							if not inAir then
								airReachRolled = false
								bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Attack.Value + 2
							else
								if not airReachRolled then
									airReachRolled = true
									airReachState = math.random(1, 100) <= AirReachChance.Value
								end
								bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = airReachState and (Attack.Value + 2) or (oldAttackReach or 14.4)
							end
						end
					end
				end)
				Reach:Clean(function()
					if _airReachThread then
						pcall(task.cancel, _airReachThread)
						_airReachThread = nil
					end
					airReachRolled = false
				end)
				Reach:Clean(function()
					if _reachLoopThread then
						pcall(task.cancel, _reachLoopThread)
						_reachLoopThread = nil
					end
				end)
			else
				if oldAttackReach then
					bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = oldAttackReach
				end
				
				if oldMineReach then
					pcall(function()
						local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
						if blockBreaker then
							blockBreaker:setRange(oldMineReach)
						end
					end)
				end

				oldAttackReach, oldMineReach = nil, nil
			end
		end,
		Tooltip = 'increases reach for attacking, mining'
	})
	
	SwordReach = Reach:CreateToggle({
		Name = 'Sword Reach',
		Default = true,
		Function = function(v)
			if Attack then Attack.Object.Visible = v end
			if Reach.Enabled then
				if v then
					bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Attack.Value + 2
				else
					bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = oldAttackReach or 14.4
				end
			end
		end
	})

	Attack = Reach:CreateSlider({
		Name = 'Attack Range',
		Darker = true,
		Visible = true,
		Min = 0,
		Max = 23,
		Default = 18,
		Function = function(val)
			if Reach.Enabled then
				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = val + 2
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	
	AirReach = Reach:CreateToggle({
		Name = 'Air Reach',
		Default = false,
		Tooltip = 'puts ur reach back to normal when they in the air so it looks legit',
		Function = function(v)
			if AirReachChance then AirReachChance.Object.Visible = v end
			if not v and Reach.Enabled and SwordReach and SwordReach.Enabled then
				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Attack.Value + 2
			end
		end
	})

	AirReachChance = Reach:CreateSlider({
		Name = 'Air Reach Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Suffix = '%',
		Darker = true,
		Visible = false,
		Tooltip = 'how often u still get reach while they jumpin'
	})

	MineReach = Reach:CreateToggle({
		Name = 'Mine Reach',
		Default = false,
		Function = function(v)
			if Mine then Mine.Object.Visible = v end
		end
	})

	Mine = Reach:CreateSlider({
		Name = 'Mine Range',
		Darker = true,
		Visible = false,
		Min = 0,
		Max = 30,
		Default = 18,
		Function = function(val)
			if Reach.Enabled then
				pcall(function()
					local blockBreaker = bedwars.BlockBreakController:getBlockBreaker()
					if blockBreaker then
						blockBreaker:setRange(val)
					end
				end)
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
	local Sprint
	local old
	
	Sprint = vape.Categories.Combat:CreateModule({
		Name = 'Sprint',
		Function = function(callback)
			if callback then
				if inputService.TouchEnabled then 
					pcall(function() 
						lplr.PlayerGui.MobileUI['4'].Visible = false 
					end) 
				end
				old = bedwars.SprintController.stopSprinting
				bedwars.SprintController.stopSprinting = function(...)
					local call = old(...)
					bedwars.SprintController:startSprinting()
					return call
				end
				Sprint:Clean(entitylib.Events.LocalAdded:Connect(function() 
					task.delay(0.1, function() 
						bedwars.SprintController:stopSprinting() 
					end) 
				end))
				bedwars.SprintController:stopSprinting()
			else
				if inputService.TouchEnabled then 
					pcall(function() 
						lplr.PlayerGui.MobileUI['4'].Visible = true 
					end) 
				end
				bedwars.SprintController.stopSprinting = old
				bedwars.SprintController:stopSprinting()
			end
		end,
	})
end)
	
run(function()
	local TriggerBot
	local CPS
	local ProjectileMode
	local ProjectileFireRate
	local ProjectileWaitDelay
	local ProjectileFirstPerson
	local rayParams = cloneRaycast()
	local lastProjectileShot = 0
	local wasHoldingProjectile = false
	local VirtualInputManager = game:GetService("VirtualInputManager")
	local tick = tick
	local task_wait = task.wait
	local pcall = pcall
	local lastClickTime = 0
	local clickCooldown = 0.015
	
	local function leftClick()
		local now = tick()
		if now - lastClickTime < clickCooldown then
			return false
		end
		
		local success = pcall(function()
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
			task_wait(0.02)
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
		end)
		
		if success then
			lastClickTime = now
		end
		return success
	end
	
	local lastProjectileCheck = 0
	local cachedProjectileResult = false
	local lastHotbarSlot = -1
	local cachedSwordRange = nil
	local lastSwordTool = nil
	
	TriggerBot = vape.Categories.Combat:CreateModule({
		Name = 'TriggerBot',
		Function = function(callback)
			if callback then
				local frameCounter = 0
				local lastToolType = nil
				
				repeat
					frameCounter = frameCounter + 1
					local doAttack = false
					local holdingProjectile = isHoldingProjectile()
					
					if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) and entitylib.isAlive then
						if ProjectileMode.Enabled and holdingProjectile then
							if ProjectileFirstPerson.Enabled and not isFirstPerson() then
								wasHoldingProjectile = false
							else
								if holdingProjectile and not wasHoldingProjectile then
									task_wait(ProjectileWaitDelay.Value)
									leftClick()
									lastProjectileShot = tick()
									wasHoldingProjectile = true
								elseif holdingProjectile then
									local currentTime = tick()
									if (currentTime - lastProjectileShot) >= ProjectileFireRate.Value then
										leftClick()
										lastProjectileShot = currentTime
									end
								else
									wasHoldingProjectile = false
								end
							end
						elseif store.hand.toolType == 'sword' and bedwars.DaoController.chargingMaid == nil then
							local currentTool = store.hand.tool
							if currentTool ~= lastSwordTool then
								lastSwordTool = currentTool
								local itemMeta = bedwars.ItemMeta[currentTool.Name]
								cachedSwordRange = itemMeta and itemMeta.sword and itemMeta.sword.attackRange or 14.4
							end
							
							local attackRange = cachedSwordRange or 14.4
							
							if frameCounter % 2 == 0 then
								rayParams.FilterDescendantsInstances = {lplr.Character}
								
								local unit = lplr:GetMouse().UnitRay
								local localPos = entitylib.character.RootPart.Position
								local rayRange = attackRange
								local ray = bedwars.QueryUtil:raycast(unit.Origin, unit.Direction * 200, rayParams)
								
								if ray and (localPos - ray.Instance.Position).Magnitude <= rayRange then
									local entityList = entitylib.List
									for i = 1, #entityList do
										local ent = entityList[i]
										doAttack = ent.Targetable and ray.Instance:IsDescendantOf(ent.Character) and (localPos - ent.RootPart.Position).Magnitude <= rayRange
										if doAttack then
											break
										end
									end
								end
							end
							
							if not doAttack then
								doAttack = bedwars.SwordController:getTargetInRegion(attackRange or 3.8 * 3, 0)
							end
							
							if doAttack then
								bedwars.SwordController:swingSwordAtMouse()
							end
						else
							wasHoldingProjectile = false
						end
					end
					
					if doAttack and not holdingProjectile then
						task_wait(1 / CPS.GetRandomValue())
					else
						task_wait(holdingProjectile and 0.033 or 0.05)
					end
				until not TriggerBot.Enabled
			else
				cachedSwordRange = nil
				lastSwordTool = nil
				lastHotbarSlot = -1
				wasHoldingProjectile = false
			end
		end,
		Tooltip = 'Automatically swings when hovering over a entity'
	})
	
	CPS = TriggerBot:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 9,
		DefaultMin = 7,
		DefaultMax = 7
	})
	
	ProjectileMode = TriggerBot:CreateToggle({
		Name = 'Projectile Mode',
		Tooltip = 'Auto-shoots crossbow/bow when holding projectile weapon'
	})
	
	ProjectileFireRate = TriggerBot:CreateSlider({
		Name = 'Projectile Fire Rate',
		Min = 0.1,
		Max = 3,
		Default = 1.2,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
		Tooltip = 'How fast to auto-fire (1.2 = every 1.2 seconds)',
		Visible = function()
			return ProjectileMode.Enabled
		end
	})
	
	ProjectileWaitDelay = TriggerBot:CreateSlider({
		Name = 'Projectile Wait Delay',
		Min = 0,
		Max = 1,
		Default = 0,
		Decimal = 100,
		Suffix = 's',
		Tooltip = 'Delay before shooting (helps prevent ghosting)',
		Visible = function()
			return ProjectileMode.Enabled
		end
	})
	
	ProjectileFirstPerson = TriggerBot:CreateToggle({
		Name = 'Projectile First Person Only',
		Default = false,
		Tooltip = 'Only works in first person mode',
		Visible = function()
			return ProjectileMode.Enabled
		end
	})
end)

run(function()
	local Velocity
	local Vertical
	local Horizontal
	local Mode
	local DelayGround
	local DelayAir
	local Targetting
	local Chance
	local old = nil
	local rand = Random.new()

	Velocity = vape.Categories.Combat:CreateModule({
		Name = 'Velocity',
		Tooltip = 'control you to edit ur knockback',
		Function = function(callback)
			if callback then
				old = bedwars.KnockbackUtil.applyKnockback
				Velocity:Clean(vapeEvents.TakeKnockback.Event:Connect(function(root, mass, dir, knockback, ...)
					local args = {...}
					local clone = table.clone(knockback)

					local air, ground = false, false
					task.delay(DelayAir.Value / 1000, function()
						clone.horizontal = knockback.horizontal or 1
						air = true
					end)
					task.delay(DelayGround.Value / 1000, function()
						clone.vertical = knockback.vertical or 1
						ground = true
					end)
					repeat task.wait(0.1) until air
					repeat task.wait(0.05) until ground
					old(root, mass, dir, clone, unpack(args))
				end))

				bedwars.KnockbackUtil.applyKnockback = function(root, mass, dir, knockback, ...)
					local chance = rand:NextNumber(0, 100)
					chance = math.floor(chance)
					if Mode.Value == 'Default' then
						if chance >= Chance.Value then return old(root, mass, dir, knockback, ...) end
					end
						
					local check = (not Targetting.Enabled) or entitylib.EntityPosition({
						Range = 20,
						Part = 'RootPart',
						Players = true
					})
		
					if check then
						knockback = knockback or {}
						if Mode.Value == 'Lag' then
							if chance < Chance.Value then
								return vapeEvents.TakeKnockback:Fire(root, mass, dir, knockback, ...)
							end
						else
							if Horizontal.Value == 0 and Vertical.Value == 0 then return end
							knockback.horizontal = (knockback.horizontal or 1) * (Horizontal.Value / 100)
							knockback.vertical = (knockback.vertical or 1) * (Vertical.Value / 100)
						end
					end
						
					return old(root, mass, dir, knockback, ...)
				end
			else
				bedwars.KnockbackUtil.applyKnockback = old
				old = nil
			end
		end
	})
	Mode = Velocity:CreateDropdown({
		Name = "Mode",
		List = {'Lag','Default'},
		Function = function(val)
			local isDefault = val == 'Default'
			if Horizontal then Horizontal.Object.Visible = isDefault end
			if Vertical then Vertical.Object.Visible = isDefault end
			if DelayGround then DelayGround.Object.Visible = not isDefault end
			if DelayAir then DelayAir.Object.Visible = not isDefault end
		end
	})
	Vertical = Velocity:CreateSlider({
		Name = "Vertical",
		Min = 0,
		Max = 100,
		Default = 100,
		Decimal = 1,
		Visible = (Mode.Value == 'Default')
	})
	Horizontal = Velocity:CreateSlider({
		Name = "Horizontal",
		Min = 0,
		Max = 100,
		Default = 100,
		Decimal = 1,
		Visible = (Mode.Value == 'Default')
	})
	DelayGround = Velocity:CreateSlider({
		Name = "Delay Ground",
		Min = 0,
		Max = 3000,
		Default = 1000,
		Suffix = 'ms',
		Decimal = 1,
		Visible = (Mode.Value == 'Lag')
	})
	DelayAir = Velocity:CreateSlider({
		Name = "Delay Air",
		Min = 0,
		Max = 3000,
		Default = 1000,
		Suffix = 'ms',
		Decimal = 1,
		Visible = (Mode.Value == 'Lag')
	})
	Targetting = Velocity:CreateToggle({
		Name = 'Only when targetting',
		Default = false
	})
	Chance = Velocity:CreateSlider({
		Name = "Chance",
		Min = 0,
		Max = 100,
		Default = 100,
		Decimal = 1,
		Suffix = '%',
		Tooltip = 'how often it actually changes ur knockback, 100 means every hit'
	})
end)

--[[
	Blatant Modules
]]


run(function()
	local PlayerAttachModule
	local RangeSlider
	local HeightSlider
	local attachRay = RaycastParams.new()
	local lastGroundTime = tick()

	local function isValidTarget(ent)
		if not ent or not ent.Targetable or not ent.RootPart or not ent.Humanoid then
			return false
		end
		if ent.Humanoid.Health <= 0 then
			return false
		end
		if ent.Player then
			if entitylib.isFriend and entitylib.isFriend(ent.Player) then
				return false
			end
			local myPlayer = game:GetService("Players").LocalPlayer
			if myPlayer and myPlayer.Team and ent.Player.Team and myPlayer.Team == ent.Player.Team then
				return false
			end
		end
		return true
	end

	local function getTarget(myRoot)
		local closestTarget = nil
		local closestDist = RangeSlider.Value
		for _, ent in ipairs(entitylib.List) do
			if isValidTarget(ent) then
				local dist = (ent.RootPart.Position - myRoot.Position).Magnitude
				if dist <= closestDist then
					closestDist = dist
					closestTarget = ent
				end
			end
		end
		return closestTarget
	end

	PlayerAttachModule = vape.Categories.Blatant:CreateModule({
		Name = 'PlayerAttach',
		Function = function(callback)
			frictionTable.PlayerAttach = callback or nil
			if callback then
				local tpTick, tpToggle, oldy = tick(), true
				lastGroundTime = tick()

				PlayerAttachModule:Clean(runService.PreSimulation:Connect(function(dt)
					if not entitylib.isAlive then return end
					local root = entitylib.character.RootPart
					if not root or not isnetworkowner(root) then return end

					local target = getTarget(root)
					if not target then
						lastGroundTime = tick()
						tpToggle = true
						oldy = nil
						return
					end

					local now = tick()
					local humanoid = entitylib.character.Humanoid
					if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
						lastGroundTime = now
					end
					local airTime = now - lastGroundTime

					local oscillation = (now % 0.4 < 0.2) and -1 or 1
					local mass = 1.95 + (6 * oscillation)

					local goalPos = target.RootPart.Position + Vector3.new(0, HeightSlider.Value, 0)

					if tpToggle then
						if airTime > 2 and not oldy then
							attachRay.FilterDescendantsInstances = {lplr.Character, gameCamera}
							attachRay.CollisionGroup = root.CollisionGroup
							local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), attachRay)
							if ray then
								tpToggle = false
								oldy = HeightSlider.Value
								tpTick = now + 0.11
								root.CFrame = CFrame.lookAlong(Vector3.new(root.Position.X, ray.Position.Y + entitylib.character.HipHeight, root.Position.Z), root.CFrame.LookVector)
								root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
								return
							end
						end
						root.CFrame = CFrame.lookAlong(goalPos, root.CFrame.LookVector)
					else
						if oldy then
							if tpTick < now then
								root.CFrame = CFrame.lookAlong(goalPos, root.CFrame.LookVector)
								tpToggle = true
								oldy = nil
								lastGroundTime = now
							else
								return
							end
						end
					end

					root.AssemblyLinearVelocity = Vector3.new(0, mass, 0)
				end))
			else
				if entitylib.isAlive and entitylib.character and entitylib.character.RootPart then
					entitylib.character.RootPart.AssemblyLinearVelocity = Vector3.zero
					entitylib.character.RootPart.AssemblyAngularVelocity = Vector3.zero
				end
			end
		end,
		Tooltip = 'sticks u right above whoever u fightin so u can stay on em the whole time gng'
	})

	RangeSlider = PlayerAttachModule:CreateSlider({
		Name = 'Range',
		Min = 5,
		Max = 30,
		Default = 20,
		Suffix = function(val) return val == 1 and 'stud' or 'studs' end
	})

	HeightSlider = PlayerAttachModule:CreateSlider({
		Name = 'Height',
		Min = 0,
		Max = 20,
		Default = 10,
		Decimal = 10,
		Suffix = 'studs',
		Tooltip = 'how high above em u sit'
	})
end)

run(function()
	local SilentAim
	local Targets
	local TargetPart
	local SortMethod
	local Range
	local FOV
	local SAFOVCircle
	local RandomHeadPercent
	local RandomTorsoPercent
	local OtherProjectiles
	local Blacklist
	local AutoCharge
	local skidChargePercent

	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('Map')}

	local namecall
	local namecallHooked = false
	local lockedRandomPart
	local _saVelHistory = {}
	local _saVelStamp = {}
	local fovConn

	local function getMousePosition()
		if inputService.TouchEnabled then
			return gameCamera.ViewportSize / 2
		end
		return inputService:GetMouseLocation()
	end

	local function getClosestPart(char, mousePos)
		local magnitude, part = 9e9, nil
		for _, v in char:GetChildren() do
			if v:IsA('BasePart') then
				local position, vis = gameCamera:WorldToViewportPoint(v.Position)
				if vis then
					local mag = (mousePos - Vector2.new(position.X, position.Y)).Magnitude
					if mag < magnitude then
						magnitude = mag
						part = v
					end
				end
			end
		end
		return part
	end

	local function pickRandomPart(char)
		local roll = math.random(1, 100)
		local head = char:FindFirstChild('Head')
		local torso = char:FindFirstChild('HumanoidRootPart') or char.PrimaryPart
		if head and roll <= RandomHeadPercent.Value then
			return head
		elseif torso and roll <= (RandomHeadPercent.Value + RandomTorsoPercent.Value) then
			return torso
		end
		return torso or head
	end

	local function getTargetPart(plr)
		local val = TargetPart.Value
		if val == 'Dynamic' then
			local tool = store.hand and store.hand.tool
			local itemType = tostring(tool and tool.Name or ''):lower()
			if itemType:find('headhunter') and plr.Character and plr.Character:FindFirstChild('Head') then
				return plr.Character.Head
			end
			return plr.RootPart
		elseif val == 'Head' then
			return (plr.Character and plr.Character:FindFirstChild('Head')) or plr.RootPart
		elseif val == 'Closest' then
			return (plr.Character and getClosestPart(plr.Character, getMousePosition())) or plr.RootPart
		elseif val == 'Randomize' then
			if lockedRandomPart and lockedRandomPart.Parent ~= plr.Character then
				lockedRandomPart = nil
			end
			if plr.Character and (not lockedRandomPart or not lockedRandomPart.Parent) then
				lockedRandomPart = pickRandomPart(plr.Character)
			end
			return lockedRandomPart or plr.RootPart
		end
		return plr.RootPart
	end

	local function isBlacklisted(projType)
		local key = (projType == 'glue_trap' or projType == 'glue_projectile') and 'gloop' or projType
		if Blacklist and table.find(Blacklist.ListEnabled or Blacklist.Value or {}, key) then
			return true
		end
		return false
	end

	local fovDrawing
	local function isHoldingProjectile()
		local tool = store.hand and store.hand.tool
		local itemType = tool and tool.Name or ''
		local itemMeta = bedwars.ItemMeta and bedwars.ItemMeta[itemType]
		if not (itemMeta and itemMeta.projectileSource) then return false end
		local src = itemMeta.projectileSource
		local isArrow = src.ammoItemTypes and table.find(src.ammoItemTypes, 'arrow')
		local isHeadhunter = itemType:find('headhunter')
		if isArrow or isHeadhunter then return true end
		if OtherProjectiles and OtherProjectiles.Enabled then
			local projectileType = src.projectileType and (type(src.projectileType) == 'function' and src.projectileType('arrow') or src.projectileType) or ''
			for _, black in ipairs(Blacklist and Blacklist.ListEnabled or {}) do
				if tostring(projectileType):find(black) then return false end
			end
			return true
		end
		return false
	end
	local function runFOVCircle(state)
		if fovConn then fovConn:Disconnect() fovConn = nil end
		if fovDrawing then fovDrawing:Destroy() fovDrawing = nil end
		if not state then return end
		fovDrawing = Instance.new('Frame')
		fovDrawing.Name = 'SAFOVCircle'
		fovDrawing.BackgroundTransparency = 1
		fovDrawing.AnchorPoint = Vector2.new(0.5, 0.5)
		fovDrawing.Visible = false
		local stroke = Instance.new('UIStroke')
		stroke.Thickness = 1
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Parent = fovDrawing
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = fovDrawing
		fovDrawing.Parent = vape.gui
		fovConn = runService.RenderStepped:Connect(function()
			if not fovDrawing or not FOV or not FOV.Value then return end
			local shouldShow = SilentAim and SilentAim.Enabled and SAFOVCircle and SAFOVCircle.Enabled and isHoldingProjectile()
			fovDrawing.Visible = shouldShow
			if shouldShow then
				local mousePos
				if inputService.TouchEnabled then
					mousePos = gameCamera.ViewportSize / 2
				else
					local mp = inputService:GetMouseLocation()
					mousePos = Vector2.new(mp.X, mp.Y)
				end
				fovDrawing.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
				fovDrawing.Size = UDim2.fromOffset(FOV.Value * 2, FOV.Value * 2)
			end
		end)
	end

	local function solveSilent(args)
		local origin, velocity, projType = args[4], args[6], args[3]
		if typeof(origin) ~= 'Vector3' then
			origin = args[5]
		end
		if typeof(origin) ~= 'Vector3' or typeof(velocity) ~= 'Vector3' or type(projType) ~= 'string' then
			return
		end

		if (not OtherProjectiles.Enabled) and not projType:find('arrow') then
			return
		end
		if isBlacklisted(projType) then return end

		local meta = bedwars.ProjectileMeta[projType]
		if not meta then return end

		local projSpeed = velocity.Magnitude
		if projSpeed <= 0 then return end
		local gravity = tonumber(meta.gravitationalAcceleration)
		if gravity == nil then gravity = 196.2 end
		if gravity < 1 then gravity = 0 end

		local plr = entitylib.EntityMouse({
			Part = 'RootPart',
			Range = FOV.Value,
			Players = Targets.Players.Enabled,
			NPCs = (Targets.NPCs and Targets.NPCs.Enabled) or false,
			Wallcheck = Targets.Walls.Enabled,
			Sort = sortmethods[SortMethod.Value or 'Cursor'],
			Origin = origin,
		})
		if not plr then return end

		local targetBodyPart = getTargetPart(plr)
		if not targetBodyPart then return end

		local dist = (targetBodyPart.Position - origin).Magnitude
		if dist > Range.Value then return end

		local playerGravity = workspace.Gravity
		local balloons = plr.Character and plr.Character:GetAttribute('InflatedBalloons')
		if balloons and balloons > 0 then
			playerGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
		end
		if plr.Character and plr.Character.PrimaryPart and plr.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
			playerGravity = 6
		end

		local pearl = projType == 'telepearl'
		local rawVel = pearl and Vector3.zero or (plr.RootPart.AssemblyLinearVelocity or plr.RootPart.Velocity or Vector3.zero)
		local _velKey = tostring(plr)
		local _velNow = tick()
		if not _saVelHistory[_velKey] or (_velNow - (_saVelStamp[_velKey] or 0)) > 0.15 then
			_saVelHistory[_velKey] = rawVel
		else
			_saVelHistory[_velKey] = _saVelHistory[_velKey]:Lerp(rawVel, 0.35)
		end
		_saVelStamp[_velKey] = _velNow

		local aimTarget = targetBodyPart.Position
		local _map = workspace:FindFirstChild('Map')
		if _map then rayCheck.FilterDescendantsInstances = {_map} end
		local lifetime = tonumber(meta.predictionLifetimeSec) or tonumber(meta.lifetimeSec) or (projSpeed > 0 and math.min(3, 120 / projSpeed) or 3)
		local spawnPos = prediction.GetSpawnPosition(origin, aimTarget, bedwars.BowConstantsTable.RelX, bedwars.BowConstantsTable.RelY, bedwars.BowConstantsTable.RelZ)
		local calc = prediction.SolveTrajectory(
			spawnPos, projSpeed, gravity,
			aimTarget, _saVelHistory[_velKey],
			playerGravity, plr.HipHeight,
			plr.Jumping and 42.6 or nil,
			rayCheck, nil, targetBodyPart.Position, plr.RootPart, nil, true
		)
		if not calc then return end

		if targetinfo and targetinfo.Targets then
			targetinfo.Targets[plr] = tick() + 1
		end

		return (calc - spawnPos).Unit * projSpeed
	end

	SilentAim = vape.Categories.Utility:CreateModule({
		Name = 'silentaim ',
		Function = function(callback)
			if callback then
				if ProjectileAimbot and ProjectileAimbot.Enabled then
					ProjectileAimbot:Toggle(false)
					notif('SilentAim', 'turned off ProjectileAimbot, they cant both run at once gng', 4)
				end
				if SAFOVCircle and SAFOVCircle.Enabled then
					runFOVCircle(true)
				end
				if not namecallHooked then
					namecallHooked = true
					namecall = hookmetamethod(game, '__namecall', newcclosure(function(...)
						if not SilentAim.Enabled or checkcaller() or getnamecallmethod() ~= 'InvokeServer' then
							return namecall(...)
						end
						local remote = ...
						if typeof(remote) == 'Instance' and remote.Name == 'ProjectileFire' then
							local args = table.pack(select(2, ...))
							local ok, newVelocity = pcall(solveSilent, args)
							if ok and typeof(newVelocity) == 'Vector3' then
								args[6] = newVelocity
								if AutoCharge.Enabled and typeof(args[8]) == 'table' then
									local projType = args[3]
									local dur
									if type(projType) == 'string' and projType:find('arrow') then
										dur = 0.58
									else
										local meta = bedwars.ProjectileMeta[projType]
										dur = (meta and meta.maxDrawDurationSeconds) or 0.8
									end
									args[8].drawDurationSec = dur * (skidChargePercent.Value / 100)
								end
							end
							local self = ...
							return self.InvokeServer(self, table.unpack(args, 1, args.n))
						end
						return namecall(...)
					end))
				end
			else
				lockedRandomPart = nil
				table.clear(_saVelHistory)
				table.clear(_saVelStamp)
				runFOVCircle(false)
			end
		end,
		Tooltip = 'hooks the projectile remote n sends diff args so it hits em where u aim on ur screen'
	})

	Targets = SilentAim:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})

	TargetPart = SilentAim:CreateDropdown({
		Name = 'Part',
		List = {'Dynamic', 'RootPart', 'Head', 'Closest', 'Randomize'},
		Default = 'RootPart',
		Function = function()
			lockedRandomPart = nil
		end
	})

	SortMethod = SilentAim:CreateDropdown({
		Name = 'Sort Method',
		List = getSortList({'Distance', 'Damage', 'Cursor'}),
		Default = 'Cursor',
	})

	Range = SilentAim:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 500,
		Default = 100,
	})

	FOV = SilentAim:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 300,
	})

	SAFOVCircle = SilentAim:CreateToggle({
		Name = 'FOV Circle',
		Function = function(call)
			if SilentAim.Enabled then
				runFOVCircle(call)
			end
		end
	})

	RandomHeadPercent = SilentAim:CreateSlider({
		Name = 'Head Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Darker = true,
		Visible = false
	})

	RandomTorsoPercent = SilentAim:CreateSlider({
		Name = 'Torso Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Darker = true,
		Visible = false,
		Function = function(val)
			if RandomHeadPercent and (RandomHeadPercent.Value + val) > 100 then
				notif('SilentAim', 'head or torso chance is more than 100% so root part will never be picked..', 3)
			end
		end
	})

	local function updateRandomizeVisibility()
		local vis = (TargetPart.Value == 'Randomize')
		RandomHeadPercent.Object.Visible = vis
		RandomTorsoPercent.Object.Visible = vis
	end
	if TargetPart.AddHook then
		TargetPart:AddHook(updateRandomizeVisibility)
	end
	updateRandomizeVisibility()

	OtherProjectiles = SilentAim:CreateToggle({
		Name = 'Other Projectiles',
		Default = true,
		Function = function(call)
			if Blacklist then Blacklist.Object.Visible = call end
		end
	})
	Blacklist = SilentAim:CreateTextList({
		Name = 'Blacklist',
		Darker = true,
		Default = {'telepearl'},
		Visible = OtherProjectiles.Enabled
	})
	AutoCharge = SilentAim:CreateToggle({
		Name = 'AutoCharge',
		Default = true,
		Function = function(v)
			if skidChargePercent and skidChargePercent.Object then skidChargePercent.Object.Visible = v end
		end
	})
	skidChargePercent = SilentAim:CreateSlider({
		Name = 'Charge Percent',
		Min = 1,
		Max = 100,
		Default = 100,
	})
end)

local AntiFallDirection
run(function()
    local AntiFall
    local Mode
    local Material
    local Color
	local rayCheck = cloneRaycast()
    rayCheck.RespectCanCollide = true

    local math_huge = math.huge
    local tick = tick
    local task_wait = task.wait
    local vector3new = Vector3.new
    local vector3zero = Vector3.zero
    
    local cachedLowGround = math_huge
    local lastGroundScan = 0
    local groundScanInterval = 2 
    
    local function getLowGround()
        local now = tick()
        if now - lastGroundScan < groundScanInterval and cachedLowGround ~= math_huge then
            return cachedLowGround
        end
        
        lastGroundScan = now
        local mag = math_huge
        local blockStore = bedwars.BlockController:getStore()
        local allPositions = blockStore:getAllBlockPositions()
        
        for i = 1, #allPositions do
            local pos = allPositions[i] * 3
            if pos.Y < mag and not getPlacedBlock(pos + vector3new(0, 3, 0)) then
                mag = pos.Y
            end
        end
        
        cachedLowGround = mag
        return mag
    end

    AntiFall = vape.Categories.Blatant:CreateModule({
        Name = 'AntiFall',
        Function = function(callback)
            if callback then
                repeat task_wait() until store.matchState ~= 0 or (not AntiFall.Enabled)
                if not AntiFall.Enabled then return end

                local pos, debounce = getLowGround(), tick()
                if pos ~= math_huge then
                    AntiFallPart = Instance.new('Part')
                    AntiFallPart.Size = vector3new(10000, 1, 10000)
                    AntiFallPart.Transparency = 1 - Color.Opacity
                    AntiFallPart.Material = Enum.Material[Material.Value]
                    AntiFallPart.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                    AntiFallPart.Position = vector3new(0, pos - 2, 0)
                    AntiFallPart.CanCollide = Mode.Value == 'Collide'
                    AntiFallPart.Anchored = true
                    AntiFallPart.CanQuery = false
                    AntiFallPart.Parent = workspace
                    AntiFall:Clean(AntiFallPart)
                    
                    AntiFall:Clean(AntiFallPart.Touched:Connect(function(touched)
                        if touched.Parent == lplr.Character and entitylib.isAlive and debounce < tick() then
                            debounce = tick() + 0.1
                            
                            if Mode.Value == 'Normal' then
                                local top = getNearGround()
                                if top then
                                    local lastTeleport = lplr:GetAttribute('LastTeleported')
                                    local connection
                                    local frameCounter = 0
                                    
                                    local vapeModules = vape.Modules
                                    local flyEnabled = vapeModules.Fly
                                    local longJumpEnabled = vapeModules.LongJump
                                    
                                    local yMask = vector3new(1, 0, 1)
                                    local yOnly = vector3new(0, 1, 0)
                                    
                                    connection = runService.PreSimulation:Connect(function()
                                        frameCounter = frameCounter + 1
                                        
                                        if frameCounter % 5 == 0 then
                                            if flyEnabled.Enabled or longJumpEnabled.Enabled then
                                                connection:Disconnect()
                                                AntiFallDirection = nil
                                                return
                                            end
                                        end

                                        if entitylib.isAlive and lplr:GetAttribute('LastTeleported') == lastTeleport then
                                            local root = entitylib.character.RootPart
                                            local rootPos = root.Position
                                            local delta = (top - rootPos) * yMask
                                            
                                            AntiFallDirection = delta.Unit == delta.Unit and delta.Unit or vector3zero
                                            root.Velocity *= yMask
                                            
                                            if frameCounter % 3 == 0 then
                                                rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character}
                                                rayCheck.CollisionGroup = root.CollisionGroup

                                                local ray = workspace:Raycast(rootPos, AntiFallDirection, rayCheck)
                                                if ray then
                                                    for i = 1, 5 do
                                                        local dpos = roundPos(ray.Position + ray.Normal * 1.5) + vector3new(0, 3, 0)
                                                        if not getPlacedBlock(dpos) then
                                                            top = vector3new(top.X, pos.Y, top.Z)
                                                            break
                                                        end
                                                    end
                                                end
                                            end

                                            local yDiff = top.Y - rootPos.Y
                                            root.CFrame += vector3new(0, yDiff, 0)
                                            
                                            if not frictionTable.Speed then
                                                local speed = getSpeed()
                                                local newVelocity = (AntiFallDirection * speed) + vector3new(0, root.AssemblyLinearVelocity.Y, 0)
                                                root.AssemblyLinearVelocity = newVelocity
                                            end

                                            if delta.Magnitude < 1 then
                                                connection:Disconnect()
                                                AntiFallDirection = nil
                                            end
                                        else
                                            connection:Disconnect()
                                            AntiFallDirection = nil
                                        end
                                    end)
                                    AntiFall:Clean(connection)
                                end
                            elseif Mode.Value == 'Velocity' then
                                local rootVel = entitylib.character.RootPart.Velocity
                                entitylib.character.RootPart.Velocity = vector3new(rootVel.X, 100, rootVel.Z)
                            end
                        end
                    end))
                end
            else
                AntiFallDirection = nil
                cachedLowGround = math_huge
                lastGroundScan = 0
            end
        end,
        Tooltip = 'Help\'s you with your Parkinson\'s\nPrevents you from falling into the void.'
    })
    
    Mode = AntiFall:CreateDropdown({
        Name = 'Move Mode',
        List = {'Normal', 'Collide', 'Velocity'},
        Function = function(val)
            if AntiFallPart then
                AntiFallPart.CanCollide = val == 'Collide'
            end
        end,
        Tooltip = 'Normal - Smoothly moves you towards the nearest safe point\nVelocity - Launches you upward after touching\nCollide - Allows you to walk on the part'
    })
    
    local materials = {'ForceField'}
    for _, v in Enum.Material:GetEnumItems() do
        if v.Name ~= 'ForceField' then
            table.insert(materials, v.Name)
        end
    end
    
    Material = AntiFall:CreateDropdown({
        Name = 'Material',
        List = materials,
        Function = function(val)
            if AntiFallPart then
                AntiFallPart.Material = Enum.Material[val]
            end
        end
    })
    
    Color = AntiFall:CreateColorSlider({
        Name = 'Color',
        DefaultOpacity = 0.5,
        Function = function(h, s, v, o)
            if AntiFallPart then
                AntiFallPart.Color = Color3.fromHSV(h, s, v)
                AntiFallPart.Transparency = 1 - o
            end
        end
    })
end)

run(function()
    local _sharedHitBlock = nil
    local _hitBlockPatchers = {}

    getgenv().registerHitBlockPatch = function(key, fn)
        _hitBlockPatchers[key] = fn
        if not _sharedHitBlock and bedwars.BlockBreaker then
            _sharedHitBlock = bedwars.BlockBreaker.hitBlock
        end
        if not bedwars.BlockBreaker then return end
        bedwars.BlockBreaker.hitBlock = function(self, maid, raycastparams, ...)
            for _, patcher in _hitBlockPatchers do
                local result = patcher(self, maid, raycastparams, ...)
                if result ~= nil then return result end
            end
            if _sharedHitBlock then return _sharedHitBlock(self, maid, raycastparams, ...) end
        end
    end

    getgenv().unregisterHitBlockPatch = function(key)
        _hitBlockPatchers[key] = nil
        if not next(_hitBlockPatchers) then
            if bedwars.BlockBreaker then
                bedwars.BlockBreaker.hitBlock = _sharedHitBlock
            end
            _sharedHitBlock = nil
        end
    end

    local FastBreak
    local Time
    local BedCheck
    local Blacklist
    local blocks
    local string_lower = string.lower
    local string_find = string.find
    local task_wait = task.wait
    local currentBlock = nil
    local oldHitBlock = nil
    local lastHotbarSlot = nil
    local bedCache = {}
    local blacklistCache = {}
    local lastCacheClean = 0
    local cacheCleanInterval = 5 
    
    local function isBed(block)
        if not block then return false end
        local cached = bedCache[block]
        if cached ~= nil then return cached end
        
        local result = false
        pcall(function()
            if collectionService:HasTag(block, 'bed') or (block.Parent and collectionService:HasTag(block.Parent, 'bed')) then
                result = true
            elseif string_find(string_lower(block.Name), 'bed', 1, true) then
                result = true
            end
        end)
        
        if result then bedCache[block] = true end
        return result
    end
    
    local cachedBlacklistLower = {}
    local function updateBlacklistCache()
        if not blocks or not blocks.ListEnabled then return end
        
        cachedBlacklistLower = {}
        for _, v in pairs(blocks.ListEnabled) do
            table.insert(cachedBlacklistLower, string_lower(v))
        end
    end
    
    local function isBlacklisted(block)
        if not block or #cachedBlacklistLower == 0 then return false end
        local cached = blacklistCache[block]
        if cached ~= nil then return cached end
        
        local name = string_lower(block.Name)
        local result = false
        for i = 1, #cachedBlacklistLower do
            if string_find(name, cachedBlacklistLower[i], 1, true) then
                result = true
                break
            end
        end
        
        blacklistCache[block] = result
        return result
    end
    
    local function shouldSkip(block)
        if not block then return false end
        if BedCheck and BedCheck.Enabled and isBed(block) then return true end
        if Blacklist and Blacklist.Enabled and isBlacklisted(block) then return true end
        return false
    end
    
    local lastBreakUpdate = 0
    local breakUpdateCooldown = 0.05
    local pendingUpdate = false
    
    local function updateBreakSpeed()
        if not FastBreak or not FastBreak.Enabled then return end
        local now = tick()
        if now - lastBreakUpdate < breakUpdateCooldown then
            pendingUpdate = true
            return
        end
        lastBreakUpdate = now
        pendingUpdate = false
        
        pcall(function()
            local cooldown = (shouldSkip(currentBlock)) and 0.3 or Time.Value
            bedwars.BlockBreakController.blockBreaker:setCooldown(cooldown)
        end)
    end
    
    FastBreak = vape.Categories.Blatant:CreateModule({
        Name = 'FastBreak',
        Function = function(callback)
            if callback then
                lastHotbarSlot = nil

				registerHitBlockPatch('FastBreak', function(self, maid, raycastparams, ...)
					local block = nil
					pcall(function()
						local blockInfo = self.clientManager:getBlockSelector():getMouseInfo(1, {ray = raycastparams})
						if blockInfo and blockInfo.target and blockInfo.target.blockInstance then
							block = blockInfo.target.blockInstance
						end
					end)
					
					local currentSlot = store.inventory and store.inventory.hotbarSlot
					local slotChanged = currentSlot ~= lastHotbarSlot
					if slotChanged then
						lastHotbarSlot = currentSlot
					end

					if block ~= currentBlock or slotChanged then
						currentBlock = block
						updateBreakSpeed()
					end
					end)
                
                updateBlacklistCache()
                
                task.spawn(function()
                    while FastBreak.Enabled do
                        if tick() - lastCacheClean > cacheCleanInterval then
                            lastCacheClean = tick()
                            bedCache = {}
                            blacklistCache = {}
                        end
                        if pendingUpdate then updateBreakSpeed() end
                        task_wait(0.05) 
                    end
                end)
			else
				pcall(function() bedwars.BlockBreakController.blockBreaker:setCooldown(0.3) end)
				unregisterHitBlockPatch('FastBreak')
				currentBlock = nil
				lastHotbarSlot = nil
				bedCache, blacklistCache, cachedBlacklistLower = {}, {}, {}
			end
        end,
        Tooltip = 'mine faster'
    })
    
    Time = FastBreak:CreateSlider({
        Name = 'Break speed',
        Min = 0, Max = 0.3, Default = 0.25, Decimal = 100, Suffix = 'seconds',
        Function = function() updateBreakSpeed() end
    })
    
    BedCheck = FastBreak:CreateToggle({
        Name = 'Bed Check',
        Default = false,
        Tooltip = 'mining is normal when breaking beds',
        Function = function() bedCache = {}; updateBreakSpeed() end
    })
    
    Blacklist = FastBreak:CreateToggle({
        Name = 'Blacklist Blocks',
        Default = false,
        Tooltip = 'mining is normal for blacklisted blocks',
        Function = function(v)
            if blocks then blocks.Object.Visible = v end
            blacklistCache = {}
            if v then updateBlacklistCache() end
            updateBreakSpeed()
        end
    })
    
    blocks = FastBreak:CreateTextList({
        Name = 'Blacklisted Blocks',
        Placeholder = 'bed',
        Visible = false,
        Function = function()
            updateBlacklistCache()
            blacklistCache = {}
            updateBreakSpeed()
        end
    })
end)

run(function()
    local Value
    local VerticalValue
    local WallCheck
    local PopBalloons
    local TP
    local MobileButtons
    local FlyAnywayProgressBar = {Enabled = false}
    local FlyAnywayProgressBarFrame
    local BarColor
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    local up, down, old = 0, 0
    local mobileControls = {}
    local groundtime = nil
    local MAX_FLY_TIME = 2.5
    local tick = tick
    local task_wait = task.wait
    local math_max = math.max
    local math_floor = math.floor
    local string_format = string.format
    local vector3new = Vector3.new
    local vector3zero = Vector3.zero
    local udim2new = UDim2.new
    local cframeLookAlong = CFrame.lookAlong
    local cachedBalloonCount = 0
    local lastBalloonCheck = 0
    local balloonCheckInterval = 0.2 
    local cachedMatchState = 0
    local lastMatchStateCheck = 0
    local lastGroundTime = tick()
    local airTime = 0
    
    local function createMobileButton(name, position, icon)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Size = udim2new(0, 60, 0, 60)
        button.Position = position
        button.BackgroundTransparency = 0.2
        button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        button.BorderSizePixel = 0
        button.Text = icon
        button.TextScaled = true
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.Font = Enum.Font.SourceSansBold
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = button
        return button
    end

    local function cleanupMobileControls()
        for _, control in pairs(mobileControls) do
            if control then
                control:Destroy()
            end
        end
        mobileControls = {}
    end

    local function updateProgressBar()
        if not FlyAnywayProgressBarFrame then return end

        if not entitylib.isAlive then
            FlyAnywayProgressBarFrame.Visible = false
            return
        end
        
        local now = tick()
        if now - lastBalloonCheck > balloonCheckInterval then
            lastBalloonCheck = now
            cachedBalloonCount = lplr.Character:GetAttribute('InflatedBalloons') or 0
            cachedMatchState = store.matchState
        end
        
        local flyAllowed = cachedBalloonCount > 0 or cachedMatchState == 2
        
        if flyAllowed then
            FlyAnywayProgressBarFrame.Frame.Size = udim2new(1, 0, 0, 20)
            FlyAnywayProgressBarFrame.TextLabel.Text = "∞"
            FlyAnywayProgressBarFrame.Visible = FlyAnywayProgressBar.Enabled and Fly.Enabled
            return
        end
        
        local humanoid = entitylib.character.Humanoid
        local onground = humanoid.FloorMaterial ~= Enum.Material.Air

        if onground then
            groundtime = nil
            FlyAnywayProgressBarFrame.Frame.Size = udim2new(1, 0, 0, 20)
            FlyAnywayProgressBarFrame.TextLabel.Text = string_format("%.1fs", MAX_FLY_TIME)
            FlyAnywayProgressBarFrame.Visible = FlyAnywayProgressBar.Enabled and Fly.Enabled
        else
            if not groundtime then
                groundtime = now + MAX_FLY_TIME
            end
            
            local timeLeft = math.clamp(groundtime - now, 0, MAX_FLY_TIME)
            local progress = math.clamp(timeLeft / MAX_FLY_TIME, 0, 1)
            
            FlyAnywayProgressBarFrame.Frame.Size = udim2new(progress, 0, 0, 20)
            FlyAnywayProgressBarFrame.TextLabel.Text = string_format("%.1fs", timeLeft)
            FlyAnywayProgressBarFrame.Visible = FlyAnywayProgressBar.Enabled and Fly.Enabled
        end
    end

    Fly = vape.Categories.Blatant:CreateModule({
        Name = 'Fly',
        Function = function(callback)
            frictionTable.Fly = callback or nil
            updateVelocity()
            if callback then
                up, down, old = 0, 0, bedwars.BalloonController.deflateBalloon
                bedwars.BalloonController.deflateBalloon = function() end
                local tpTick, tpToggle, oldy = tick(), true

                if lplr.Character and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
                    bedwars.BalloonController:inflateBalloon()
                end

                Fly:Clean(vapeEvents.AttributeChanged.Event:Connect(function(changed)
                    if changed == 'InflatedBalloons' then
                        local char = lplr.Character
                        if not char then return end
                        cachedBalloonCount = char:GetAttribute('InflatedBalloons') or 0
                        if cachedBalloonCount == 0 and getItem('balloon') then
                            bedwars.BalloonController:inflateBalloon()
                        end
                    end
                end))

                local renderFrameCounter = 0
                Fly:Clean(runService.RenderStepped:Connect(function(delta)
                    if FlyAnywayProgressBar.Enabled and Fly.Enabled then
                        renderFrameCounter = renderFrameCounter + 1
                        if renderFrameCounter % 2 == 0 then
                            updateProgressBar()
                        end
                    end
                end))

                local preSimFrameCounter = 0
                local lastWallRaycast = 0
                local wallRaycastInterval = 0.05
                
                Fly:Clean(runService.PreSimulation:Connect(function(dt)
                    if entitylib.isAlive and isnetworkowner(entitylib.character.RootPart) then
                        preSimFrameCounter = preSimFrameCounter + 1
                        local now = tick()
                        
                        if preSimFrameCounter % 12 == 0 then
                            cachedBalloonCount = lplr.Character and lplr.Character:GetAttribute('InflatedBalloons') or 0
                            cachedMatchState = store.matchState
                        end

                        local humanoid = entitylib.character.Humanoid
                        if humanoid.FloorMaterial ~= Enum.Material.Air then
                            lastGroundTime = now
                        end
                        airTime = now - lastGroundTime
                        
                        local flyAllowed = cachedBalloonCount > 0 or cachedMatchState == 2
                        
                        local oscillation = (now % 0.4 < 0.2) and -1 or 1
                        local mass = (1.95 + (flyAllowed and 6 or 0) * oscillation) + ((up + down) * VerticalValue.Value)
                        
                        local root = entitylib.character.RootPart
                        local moveDirection = entitylib.character.Humanoid.MoveDirection
                        local velo = getSpeed()
                        local destination = (moveDirection * math_max(Value.Value - velo, 0) * dt)
                        
                        if WallCheck.Enabled and (now - lastWallRaycast) > wallRaycastInterval then
                            lastWallRaycast = now
                            local filterList = {lplr.Character, gameCamera}
                            if AntiVoidPart then table.insert(filterList, AntiVoidPart) end
                            rayCheck.FilterDescendantsInstances = filterList
                            rayCheck.CollisionGroup = root.CollisionGroup

                            if destination.Magnitude > 0.001 then
                                local ray = workspace:Raycast(root.Position, destination, rayCheck)
                                if ray then
                                    destination = ((ray.Position + ray.Normal) - root.Position)
                                end
                            end
                        end

                        if not flyAllowed then
                            if tpToggle then
                                if airTime > 2 then  
                                    if not oldy then
                                        rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiVoidPart}
                                        rayCheck.CollisionGroup = root.CollisionGroup
                                        local ray = workspace:Raycast(root.Position, vector3new(0, -1000, 0), rayCheck)
                                        if ray and TP.Enabled then
                                            tpToggle = false
                                            oldy = root.Position.Y
                                            tpTick = now + 0.11
                                            root.CFrame = cframeLookAlong(vector3new(root.Position.X, ray.Position.Y + entitylib.character.HipHeight, root.Position.Z), root.CFrame.LookVector)
                                        end
                                    end
                                end
                            else
                                if oldy then
                                    if tpTick < now then
                                        local newpos = vector3new(root.Position.X, oldy, root.Position.Z)
                                        root.CFrame = cframeLookAlong(newpos, root.CFrame.LookVector)
                                        tpToggle = true
                                        oldy = nil
                                    else
                                        mass = 0
                                    end
                                end
                            end
                        end

                        root.CFrame += destination
                        root.AssemblyLinearVelocity = (moveDirection * velo) + vector3new(0, mass, 0)
                    end
                end))

                local isMobile = inputService.TouchEnabled and not inputService.KeyboardEnabled and not inputService.MouseEnabled
                local MobileEnabled = MobileButtons.Enabled or isMobile
                if MobileEnabled then
                    local gui = Instance.new("ScreenGui")
                    gui.Name = "FlyControls"
                    gui.ResetOnSpawn = false
                    gui.Parent = lplr.PlayerGui

                    local upButton = createMobileButton("UpButton", udim2new(0.9, -70, 0.7, -140), "↑")
                    local downButton = createMobileButton("DownButton", udim2new(0.9, -70, 0.7, -70), "↓")

                    mobileControls.UpButton = upButton
                    mobileControls.DownButton = downButton
                    mobileControls.ScreenGui = gui

                    upButton.Parent = gui
                    downButton.Parent = gui

                    Fly:Clean(upButton.MouseButton1Down:Connect(function()
                        up = 1
                    end))
                    Fly:Clean(upButton.MouseButton1Up:Connect(function()
                        up = 0
                    end))
                    Fly:Clean(downButton.MouseButton1Down:Connect(function()
                        down = -1
                    end))
                    Fly:Clean(downButton.MouseButton1Up:Connect(function()
                        down = 0
                    end))
                end

                Fly:Clean(inputService.InputBegan:Connect(function(input)
                    if not inputService:GetFocusedTextBox() then
                        if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
                            up = 1
                        elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
                            down = -1
                        end
                    end
                end))
                Fly:Clean(inputService.InputEnded:Connect(function(input)
                    if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
                        up = 0
                    elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
                        down = 0
                    end
                end))
                if inputService.TouchEnabled then
                    pcall(function()
                        local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
                        Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
                            if not mobileControls.UpButton then
                                up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
                            end
                        end))
                    end)
                end
            else
                if FlyAnywayProgressBarFrame then
                    FlyAnywayProgressBarFrame.Visible = false
                end
                groundtime = nil
                bedwars.BalloonController.deflateBalloon = old
                if PopBalloons.Enabled and entitylib.isAlive and (lplr.Character:GetAttribute('InflatedBalloons') or 0) > 0 then
                    for _ = 1, 3 do
                        bedwars.BalloonController:deflateBalloon()
                    end
                end
                cleanupMobileControls()
                cachedBalloonCount = 0
                lastBalloonCheck = 0
                cachedMatchState = 0
            end
        end,
        ExtraText = function()
            return 'Heatseeker'
        end,
        Tooltip = 'makes you go zoom!'
    })
    Value = Fly:CreateSlider({
        Name = 'Speed',
        Min = 1,
        Max = 23,
        Default = 23,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    _G.FlyValue = Value
    VerticalValue = Fly:CreateSlider({
        Name = 'Vertical Speed',
        Min = 1,
        Max = 150,
        Default = 50,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    WallCheck = Fly:CreateToggle({
        Name = 'Wall Check',
        Default = true
    })
    PopBalloons = Fly:CreateToggle({
        Name = 'Pop Balloons',
        Default = true
    })
    FlyAnywayProgressBar = Fly:CreateToggle({
        Name = "Progress Bar",
        Function = function(callback)
            if BarColor and BarColor.Object then
                BarColor.Object.Visible = callback
            end
            if callback then
                FlyAnywayProgressBarFrame = Instance.new("Frame")
                FlyAnywayProgressBarFrame.AnchorPoint = Vector2.new(0.5, 0)
                local isMobile = inputService.TouchEnabled
                FlyAnywayProgressBarFrame.Position = isMobile and udim2new(0.5, 0, 0, 90) or udim2new(0.5, 0, 1, -200)
                FlyAnywayProgressBarFrame.Size = udim2new(isMobile and 0.6 or 0.2, 0, 0, 22)
                FlyAnywayProgressBarFrame.BackgroundTransparency = 0.5
                FlyAnywayProgressBarFrame.BorderSizePixel = 0
                FlyAnywayProgressBarFrame.BackgroundColor3 = Color3.new(0, 0, 0)
                FlyAnywayProgressBarFrame.Visible = false
                FlyAnywayProgressBarFrame.ZIndex = 100
                FlyAnywayProgressBarFrame.Parent = vape.gui
                
                local FlyAnywayProgressBarFrame2 = Instance.new("Frame")
                FlyAnywayProgressBarFrame2.Name = "Frame"
                FlyAnywayProgressBarFrame2.AnchorPoint = Vector2.new(0, 0)
                FlyAnywayProgressBarFrame2.Position = udim2new(0, 0, 0, 0)
                FlyAnywayProgressBarFrame2.Size = udim2new(1, 0, 0, 22)
                FlyAnywayProgressBarFrame2.BackgroundTransparency = 0
                FlyAnywayProgressBarFrame2.BorderSizePixel = 0
                FlyAnywayProgressBarFrame2.BackgroundColor3 = BarColor and Color3.fromHSV(BarColor.Hue, BarColor.Sat, BarColor.Value) or Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
                FlyAnywayProgressBarFrame2.Visible = true
                FlyAnywayProgressBarFrame2.ZIndex = 101
                FlyAnywayProgressBarFrame2.Parent = FlyAnywayProgressBarFrame
                
                local FlyAnywayProgressBartext = Instance.new("TextLabel")
                FlyAnywayProgressBartext.Name = "TextLabel"
                FlyAnywayProgressBartext.Text = "2.5s"
                FlyAnywayProgressBartext.Font = Enum.Font.Gotham
                FlyAnywayProgressBartext.TextStrokeTransparency = 0
                FlyAnywayProgressBartext.TextColor3 = Color3.new(0.9, 0.9, 0.9)
                FlyAnywayProgressBartext.TextSize = 20
                FlyAnywayProgressBartext.Size = udim2new(1, 0, 1, 0)
                FlyAnywayProgressBartext.BackgroundTransparency = 1
                FlyAnywayProgressBartext.Position = udim2new(0, 0, 0, 0)
                FlyAnywayProgressBartext.ZIndex = 102
                FlyAnywayProgressBartext.Parent = FlyAnywayProgressBarFrame
            else
                if FlyAnywayProgressBarFrame then 
                    FlyAnywayProgressBarFrame:Destroy() 
                    FlyAnywayProgressBarFrame = nil 
                end
            end
        end,
        Tooltip = "show amount of time for fly",
        Default = true
    })
    BarColor = Fly:CreateColorSlider({
        Name = 'Bar Color',
        Darker = true,
        Visible = false,
        Function = function(h, s, v, o)
            if FlyAnywayProgressBarFrame then
                FlyAnywayProgressBarFrame:FindFirstChild('Frame').BackgroundColor3 = Color3.fromHSV(h, s, v)
                FlyAnywayProgressBarFrame:FindFirstChild('Frame').BackgroundTransparency = 1 - o
            end
        end
    })

    TP = Fly:CreateToggle({
        Name = 'TP Down',
        Default = true
    })
    MobileButtons = Fly:CreateToggle({
        Name = "Mobile Buttons",
        Visible = false,
        Tooltip = 'puts up n down buttons on ur screen gng',
        Function = function() 
            if Fly.Enabled then
                Fly:Toggle()
                Fly:Toggle()
            end
        end
    })

    task.defer(function()
        if BarColor and BarColor.Object then
            BarColor.Object.Visible = FlyAnywayProgressBar.Enabled
        end
        if MobileButtons and MobileButtons.Object then
            MobileButtons.Object.Visible = inputService.TouchEnabled
        end
    end)
end)

run(function()
	vape.Categories.Blatant:CreateModule({
		Name = 'KeepSprint',
		Function = function(callback)
			debug.setconstant(bedwars.SprintController.startSprinting, 5, callback and 'blockSprinting' or 'blockSprint')
			bedwars.SprintController:stopSprinting()
		end,
		Tooltip = 'allows you to sprint with potions'
	})
end)

run(function()
	local NoSlowDown
    local old
    local SophiaCheck
    local FROZEN_THRESHOLD = 10
    local cachedModifier = nil
    local nsHooked = false
    local origPunch = nil
    local origGroveDisable = nil

    local function hookKitNoSlow()
        if bedwars.DragonSlayerController and not origPunch then
            origPunch = bedwars.DragonSlayerController.playPunchAnimation
            bedwars.DragonSlayerController.playPunchAnimation = function(self, arg2)
                local ok, maid = pcall(function()
                    local imp = debug.getupvalue(origPunch, 1)
                    local anim = debug.getupvalue(origPunch, 2)
                    local plrs = debug.getupvalue(origPunch, 3)
                    local atype = debug.getupvalue(origPunch, 4)
                    local rs = debug.getupvalue(origPunch, 6)
                    local m = imp.new()
                    local track = anim:playAnimation(plrs.LocalPlayer, atype.DRAGON_SLAYER_PUNCH)
                    m:GiveTask(function()
                        if track then track:Stop() end
                    end)
                    m:GiveTask(rs.Heartbeat:Connect(function()
                        local char = plrs.LocalPlayer.Character
                        if not char or not char.PrimaryPart then
                            m:DoCleaning()
                            return
                        end
                        char:PivotTo(CFrame.new(char:GetPrimaryPartCFrame().Position) * arg2)
                    end))
                    task.delay(0.46, function() m:DoCleaning() end)
                    return m
                end)
                if ok and maid then return maid end
                return origPunch(self, arg2)
            end
        end

        if bedwars.SpiritGardenerController and not origGroveDisable then
            origGroveDisable = bedwars.SpiritGardenerController.disableActionsOnCharge
            bedwars.SpiritGardenerController.disableActionsOnCharge = function(self, maid, character)
                if character ~= lplr.Character then
                    return origGroveDisable(self, maid, character)
                end
                local ok = pcall(function()
                    local KnitClient = bedwars.KnitClient
                    KnitClient.Controllers.SwordController:toggleSwordSwing(true)
                    KnitClient.Controllers.BlockPlacementController:disableBlockPlacer()
                    local ClientSyncEvents = debug.getupvalue(origGroveDisable, 3)
                    local projConn = ClientSyncEvents.BeginProjectileTargeting:connect(function(event)
                        event:setCancelled(true)
                    end)
                    local jumpMod = KnitClient.Controllers.JumpHeightController:getJumpModifier():addModifier({
                        jumpHeightMultiplier = 0
                    })
                    maid:GiveTask(function()
                        KnitClient.Controllers.SwordController:toggleSwordSwing(false)
                        KnitClient.Controllers.BlockPlacementController:enableBlockPlacer()
                        projConn:Destroy()
                        jumpMod.Destroy()
                    end)
                end)
                if not ok then
                    return origGroveDisable(self, maid, character)
                end
            end
        end
    end

    local function unhookKitNoSlow()
        if origPunch and bedwars.DragonSlayerController then
            bedwars.DragonSlayerController.playPunchAnimation = origPunch
        end
        origPunch = nil
        if origGroveDisable and bedwars.SpiritGardenerController then
            bedwars.SpiritGardenerController.disableActionsOnCharge = origGroveDisable
        end
        origGroveDisable = nil
    end
    NoSlowdown = vape.Categories.Blatant:CreateModule({
        Name = 'NoSlowdown',
        Function = function(callback)
            if not cachedModifier then
                if not bedwars.SprintController then return end
                cachedModifier = bedwars.SprintController:getMovementStatusModifier()
            end
            local modifier = cachedModifier
            if callback then
                if nsHooked then return end
                hookKitNoSlow()
                old = modifier.addModifier
                if not old then return end
                local orig = old
                nsHooked = true
                modifier.addModifier = function(self, tab)
                    if not orig then return end
                    if SophiaCheck and SophiaCheck.Enabled and isFrozen(nil, FROZEN_THRESHOLD) then
                        return orig(self, tab)
                    end

                    if tab.moveSpeedMultiplier then
                        tab.moveSpeedMultiplier = math.max(tab.moveSpeedMultiplier, 1)
                    end
                    return orig(self, tab)
                end

                for i, v in modifier.modifiers do
                    local mod = type(v) == 'table' and v or (type(i) == 'table' and i or nil)
                    if mod and (mod.moveSpeedMultiplier or 1) < 1 then
                        modifier:removeModifier(mod)
                    end
                end
            else
                unhookKitNoSlow()
                if cachedModifier then
                    cachedModifier.addModifier = old
                    cachedModifier = nil
                end
                old = nil
                nsHooked = false
            end
        end,
        Tooltip = 'prevents slowing down when using items.'
    })

    SophiaCheck = NoSlowdown:CreateToggle({
        Name = 'Sophia Check',
        Default = false
    })
end)

run(function()
	local DamageBoost
	local stack
	
	DamageBoost = vape.Categories.Blatant:CreateModule({
		Name = 'DamageBoost',
		Function = function(callback)
			if callback then
				DamageBoost:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
					if entitylib.isAlive and tick() > (stack or 0) and damageTable.entityInstance == lplr.Character and not vape.Modules.LongJump.Enabled then
						local horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 0)
						knockbackSpeed = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {
							vertical = 0,
							horizontal = horizontal,
						}).Magnitude * (0.9 + (store.ping and store.ping.total or 0))
						stack = tick() + (knockbackSpeed / 45)
						knockbackBoost = tick() + (horizontal / 3.5)
					end
				end))
			end
		end,
		Tooltip = 'makes you go slightly faster when damaged'
	})
end)

run(function()
	local NoFall
	local Chance
	local voidParams = RaycastParams.new()
	voidParams.FilterType = Enum.RaycastFilterType.Exclude
	voidParams.IgnoreWater = true
	local lastVoidCheck = 0
	local cachedVoid = false

	local voidOffsets = {
		Vector3.new(0, 0, 0),
		Vector3.new(2, 0, 0),
		Vector3.new(-2, 0, 0),
		Vector3.new(0, 0, 2),
		Vector3.new(0, 0, -2)
	}

	local function nearVoid(position)
		if not entitylib.isAlive then return false end
		local now = tick()
		if (now - lastVoidCheck) < 0.1 then
			return cachedVoid
		end
		lastVoidCheck = now
		voidParams.FilterDescendantsInstances = {entitylib.character.Character, gameCamera}

		local down = Vector3.new(0, -600, 0)
		for _, off in voidOffsets do
			if workspace:Raycast(position + off, down, voidParams) then
				cachedVoid = false
				return false
			end
		end

		cachedVoid = true
		return true
	end

	NoFall = vape.Categories.Blatant:CreateModule({
		Name = 'NoFall',
		Function = function(callback)
			if callback then
				NoFall:Clean(runService.Heartbeat:Connect(function(dt)
					if entitylib.isAlive and store.matchState == 1 then
						local root = entitylib.character.RootPart
						local v = root.Velocity

						if root.Velocity.Y < -35 and not nearVoid(root.Position) then
							if math.random(1, 100) <= Chance.Value then
								root.Velocity = Vector3.new(0,2.5,0)
								entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
								runService.PreRender:Wait()
								root.Velocity = v
							end
						end
					end
				end))

				NoFall:Clean(entitylib.Events.LocalAdded:Connect(function(char)
					local animator = char.Humanoid:WaitForChild('Animator', 1)
					if animator and NoFall.Enabled then
						task.wait(.5)
						NoFall:Toggle()
						NoFall:Toggle()
					end
				end))
			end
		end,
		Tooltip = 'Take no fall damage.'
	})

	Chance = NoFall:CreateSlider({
		Name = 'Chance',
		Min = 1,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
end)

run(function()
	local FastPickup
	local FastPickupDelay
	local PickupRemote = replicatedStorage:WaitForChild('rbxts_include'):WaitForChild('node_modules'):WaitForChild('@rbxts'):WaitForChild('net'):WaitForChild('out'):WaitForChild('_NetManaged'):WaitForChild('PickupItemDrop')

	FastPickup = vape.Categories.Blatant:CreateModule({
		Name = 'FastPickup',
		Tooltip = 'picks up items fast asl',
		Function = function(callback)
			if callback then
				cleanThread(FastPickup, task.spawn(function()
					while FastPickup.Enabled do
						if entitylib.isAlive then
							for _, drop in pairs(workspace:WaitForChild('ItemDropsCache'):GetChildren()) do
								task.spawn(function()
									task.wait(FastPickupDelay.Value)
									pcall(function()
										PickupRemote:InvokeServer({ itemDrop = drop })
									end)
								end)
							end
						end
						task.wait(0.05)
					end
				end))
			end
		end,
	})

	FastPickupDelay = FastPickup:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 0.5,
		Default = 0,
		Decimal = 100,
		Suffix = 's',
	})
end)

run(function()
	local ProjectileAimbot
	local TargetPart
	local Targets
	local FOV
	local Range
	local OtherProjectiles
	local Blacklist
	local SortMethod
	local skidPAChargePercent
	local RandomHeadPercent
	local RandomTorsoPercent
	local DesirePAWorkMode
	local DesirePAHideCursor
	local DesirePACursorViewMode
	local DesirePACursorLimitBow
	local DesirePACursorShowGUI
	local cursorRenderConnection
	local lastGUIState = false
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	local _rayMap = nil
	local function refreshRayCheck()
		local map = workspace:FindFirstChild('Map')
		if map ~= _rayMap or not map or not map.Parent then
			_rayMap = map
			if map and map.Parent then
				rayCheck.FilterDescendantsInstances = {map}
			else
				rayCheck.FilterType = Enum.RaycastFilterType.Exclude
				rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
				return
			end
			rayCheck.FilterType = Enum.RaycastFilterType.Include
		end
	end
	refreshRayCheck()
	local old
	local math_sqrt = math.sqrt
	local math_rad = math.rad
	local math_cos = math.cos
	local math_clamp = math.clamp
	local math_min = math.min
	local math_max = math.max
	local lockedRandomPart = nil
	local wasHovering = false
	local _paVelHistory = {}
	local CustomPredictions
	local PredictHorizontal
	local PredictVertical
	local PAFOVCircle
	local paFOVCircleDrawing = nil
	local AutoCharge
	local paFOVCircleConnection = nil

	local paFOVCircleDrawing = nil 
	local paFOVCircleConnection = nil

	local function runPAFOVCircle(call)
		if paFOVCircleConnection then
			paFOVCircleConnection:Disconnect()
			paFOVCircleConnection = nil
		end
		if paFOVCircleDrawing then
			paFOVCircleDrawing:Destroy()
			paFOVCircleDrawing = nil
		end
		if not call then return end

		paFOVCircleDrawing = Instance.new('Frame')
		paFOVCircleDrawing.Name = 'PAFOVCircle'
		paFOVCircleDrawing.BackgroundTransparency = 1
		paFOVCircleDrawing.AnchorPoint = Vector2.new(0.5, 0.5)
		paFOVCircleDrawing.Visible = false
		local stroke = Instance.new('UIStroke')
		stroke.Thickness = 1
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Parent = paFOVCircleDrawing
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = paFOVCircleDrawing
		paFOVCircleDrawing.Parent = vape.gui

		paFOVCircleConnection = runService.RenderStepped:Connect(function()
			if not paFOVCircleDrawing or not FOV or not FOV.Value then
				paFOVCircleDrawing.Visible = false
				return
			end

			local shouldShow = false
			if PAFOVCircle and PAFOVCircle.Enabled and ProjectileAimbot and ProjectileAimbot.Enabled then
				local tool = store.hand and store.hand.tool
				local itemType = tool and tool.Name or ""
				local itemMeta = bedwars.ItemMeta and bedwars.ItemMeta[itemType]
				if itemMeta and itemMeta.projectileSource then
					local src = itemMeta.projectileSource
					local isArrow = src.ammoItemTypes and table.find(src.ammoItemTypes, 'arrow')
					local isHeadhunter = itemType:find('headhunter')
					if isArrow or isHeadhunter then
						shouldShow = true
					elseif OtherProjectiles and OtherProjectiles.Enabled then
						local projectileType = src.projectileType and (type(src.projectileType) == 'function' and src.projectileType('arrow') or src.projectileType) or ""
						local blacklisted = false
						for _, black in ipairs(Blacklist and Blacklist.ListEnabled or {}) do
							if tostring(projectileType):find(black) then
								blacklisted = true
								break
							end
						end
						if not blacklisted then
							shouldShow = true
						end
					end
				end
			end

			paFOVCircleDrawing.Visible = shouldShow

			if shouldShow then
				local mousePos
				if inputService.TouchEnabled then
					mousePos = gameCamera.ViewportSize / 2
				else
					local mp = inputService:GetMouseLocation()
					mousePos = Vector2.new(mp.X, mp.Y)
				end
				paFOVCircleDrawing.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
				paFOVCircleDrawing.Size = UDim2.fromOffset(FOV.Value * 2, FOV.Value * 2)
			end
		end)
	end

	local function hasBowEquipped()
		if not store.hand or not store.hand.toolType then return false end
		return store.hand.toolType == 'bow' or store.hand.toolType == 'crossbow'
	end

	local function shouldHideCursor()
		if not DesirePAHideCursor or not DesirePAHideCursor.Enabled then return false end
		if DesirePACursorShowGUI and DesirePACursorShowGUI.Enabled and isGUIOpen() then return false end
		if DesirePACursorLimitBow and DesirePACursorLimitBow.Enabled and not hasBowEquipped() then return false end
		local inFirstPerson = isFirstPerson()
		if DesirePACursorViewMode then
			if DesirePACursorViewMode.Value == 'First Person' then return inFirstPerson
			elseif DesirePACursorViewMode.Value == 'Third Person' then return not inFirstPerson
			end
		end
		return true
	end

	local function updateCursor()
		pcall(function() inputService.MouseIconEnabled = not shouldHideCursor() end)
	end

	local function checkGUIState()
		local currentGUIState = isGUIOpen()
		if lastGUIState ~= currentGUIState then
			updateCursor()
			lastGUIState = currentGUIState
		end
	end

	local paLockedTarget = nil
	local paLockTime = 0

	local function paValidLock(originPos)
		local t = paLockedTarget
		if not t then return nil end
		if tick() - paLockTime > 2 then return nil end
		if not t.Character or not t.Character.Parent then return nil end
		if not t.RootPart or not t.RootPart.Parent then return nil end
		if t.Humanoid and t.Humanoid.Health <= 0 then return nil end
		if (t.RootPart.Position - originPos).Magnitude > Range.Value then return nil end
		return t
	end

	local function shouldPAWork()
		if not DesirePAWorkMode then return true end
		local inFirstPerson = isFirstPerson()
		if DesirePAWorkMode.Value == 'First Person' then return inFirstPerson
		elseif DesirePAWorkMode.Value == 'Third Person' then return not inFirstPerson
		end
		return true
	end

	local function isBlacklisted(projectileName)
		if not OtherProjectiles or not OtherProjectiles.Enabled then
			local isTurret = projectileName:find('turret') ~= nil or projectileName:find('vulcan') ~= nil
			return not projectileName:find('arrow') and not isTurret
		end
		for _, black in ipairs(Blacklist and Blacklist.ListEnabled or {}) do
			if projectileName:find(black) then
				return true
			end
		end
		return false
	end

	local function pickRandomPart(character)
		local roll = math.random(1, 100)
		local headChance = RandomHeadPercent.Value
		local torsoChance = RandomTorsoPercent.Value
		if roll <= headChance then
			return character:FindFirstChild('Head') or character:FindFirstChild('HumanoidRootPart')
		elseif roll <= headChance + torsoChance then
			return character:FindFirstChild('UpperTorso') or character:FindFirstChild('HumanoidRootPart')
		else
			return character:FindFirstChild('HumanoidRootPart')
		end
	end

	local function getClosestPart(character, mousePos)
		local parts = {
			'HumanoidRootPart', 'Head', 'LeftHand', 'RightHand',
			'LeftLowerArm', 'RightLowerArm', 'LeftUpperArm', 'RightUpperArm',
			'LeftFoot', 'RightFoot', 'LeftLowerLeg', 'RightLowerLeg',
			'LeftUpperLeg', 'RightUpperLeg', 'LowerTorso', 'UpperTorso'
		}
		local camera = gameCamera
		local rayOrigin = camera.CFrame.Position
		local rayDir = camera:ScreenPointToRay(mousePos.X, mousePos.Y, 0).Direction
		local bestAngle = math.huge
		local bestPart = nil

		for _, partName in ipairs(parts) do
			local part = character:FindFirstChild(partName)
			if part then
				local dirToPart = (part.Position - rayOrigin).Unit
				local angle = math.acos(math_clamp(rayDir:Dot(dirToPart), -1, 1))
				if angle < bestAngle then
					bestAngle = angle
					bestPart = part
				end
			end
		end
		return bestPart or character:FindFirstChild('HumanoidRootPart')
	end

	ProjectileAimbot = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAimbot',
		Function = function(callback)
			if callback then
				if SilentAim and SilentAim.Enabled then
					SilentAim:Toggle(false)
					notif('ProjectileAimbot', 'turned off SilentAim, they cant both run at once gng', 4)
				end
				if PAFOVCircle then
					runPAFOVCircle(PAFOVCircle.Enabled)
				end
				if DesirePAHideCursor and DesirePAHideCursor.Enabled and not cursorRenderConnection then
					cursorRenderConnection = runService.RenderStepped:Connect(function()
						checkGUIState()
						updateCursor()
					end)
					ProjectileAimbot:Clean(cursorRenderConnection)
				end

				old = bedwars.ProjectileController.calculateImportantLaunchValues
				bedwars.ProjectileController.calculateImportantLaunchValues = function(...)
					local self, projmeta, worldmeta, origin, shootpos = ...
					local originPos = entitylib.isAlive and (shootpos or (entitylib.character and entitylib.character.RootPart and entitylib.character.RootPart.Position)) or Vector3.zero
					if not originPos then return old(...) end

					local plr = entitylib.EntityMouse({
						Part = 'RootPart',
						Range = FOV.Value,
						Players = Targets.Players.Enabled,
						NPCs = (Targets.NPCs and Targets.NPCs.Enabled) or false,
						Wallcheck = Targets.Walls.Enabled,
						Origin = originPos
					})

					if plr then
						paLockedTarget = plr
						paLockTime = tick()
					else
						plr = paValidLock(originPos)
					end

					if not plr then
						paLockedTarget = nil
						wasHovering = false
						return old(...)
					end
					
					if not shouldPAWork() then
						wasHovering = false
						return old(...)
					end

					local targetBodyPart = nil
					if TargetPart.Value == 'Dynamic' then
						local tool = store.hand and store.hand.tool
						local itemType = tostring(tool and tool.Name or ""):lower()
						local isHH = itemType:find("headhunter")
						targetBodyPart = (isHH and plr.Character and plr.Character:FindFirstChild("Head")) or plr.RootPart
					elseif TargetPart.Value == 'RootPart' then
						targetBodyPart = plr.RootPart
					elseif TargetPart.Value == 'Head' then
						targetBodyPart = (plr.Character and plr.Character:FindFirstChild('Head')) or plr.RootPart
					elseif TargetPart.Value == 'Closest' then
						local mousePos = inputService.TouchEnabled and (gameCamera.ViewportSize / 2) or inputService:GetMouseLocation()
						targetBodyPart = plr.Character and getClosestPart(plr.Character, mousePos) or plr.RootPart
					elseif TargetPart.Value == 'Randomize' then
						if lockedRandomPart and lockedRandomPart.Parent ~= plr.Character then
							lockedRandomPart = nil
						end
						if plr.Character and (not lockedRandomPart or not lockedRandomPart.Parent) then
							lockedRandomPart = pickRandomPart(plr.Character)
						end
						targetBodyPart = lockedRandomPart or plr.RootPart
					else
						targetBodyPart = plr.RootPart
					end
					if not targetBodyPart then
						wasHovering = false
						return old(...)
					end
					local dist = (targetBodyPart.Position - originPos).Magnitude
					if dist > Range.Value then
						wasHovering = false
						return old(...)
					end
					local pos = shootpos or self:getLaunchPosition(origin)
					if not pos then
						wasHovering = false
						return old(...)
					end
					local projectileName = projmeta.projectile or ""
					if isBlacklisted(projectileName) then
						wasHovering = false
						return old(...)
					end
					refreshRayCheck()
					local meta = projmeta:getProjectileMeta()
					local lifetime = (worldmeta and meta.predictionLifetimeSec or meta.lifetimeSec or 3)
					local gravityMultiplier = projmeta.gravityMultiplier or 1
					if gravityMultiplier == 0 then gravityMultiplier = 1 end
					local gravity = (meta.gravitationalAcceleration or 196.2) * gravityMultiplier
					local maxDraw = tonumber(projmeta.maxStrengthChargeSec) or tonumber(projmeta.maxDrawDurationSeconds) or tonumber(meta.maxDrawDurationSeconds) or (projmeta.projectile:find('arrow') and 0.65 or 0.8)
					local drawPct = AutoCharge.Enabled and (skidPAChargePercent.Value / 100) or 1
					local customDrawDuration = maxDraw * drawPct
					local paMinScalar = tonumber(projmeta.minStrengthScalar) or 1
					local projSpeed = (meta.launchVelocity or 100) * (paMinScalar + (1 - paMinScalar) * math.clamp(drawPct, 0, 1))
					local safeOffset = (projmeta.projectile == 'owl_projectile') and Vector3.zero or (projmeta.fromPositionOffset or Vector3.zero)
					local offsetpos = pos + safeOffset
					local balloons = plr.Character and plr.Character:GetAttribute('InflatedBalloons')
					local playerGravity = workspace.Gravity
					if balloons and balloons > 0 then
						playerGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
					end
					if plr.Character and plr.Character.PrimaryPart and plr.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
						playerGravity = 6
					end
					if plr.Player and plr.Player:GetAttribute('IsOwlTarget') then
						for _, owl in ipairs(collectionService:GetTagged('Owl')) do
							if owl:GetAttribute('Target') == plr.Player.UserId and owl:GetAttribute('Status') == 2 then
								playerGravity = 0
								break
							end
						end
					end
					local bowRelX = bedwars.BowConstantsTable.RelX or 0
					local bowRelY = bedwars.BowConstantsTable.RelY or 0
					local bowRelZ = bedwars.BowConstantsTable.RelZ or 0
					local rawVel = plr.RootPart.AssemblyLinearVelocity or plr.RootPart.Velocity or Vector3.zero
					local _velKey = tostring(plr)
					if not _paVelHistory[_velKey] then
						_paVelHistory[_velKey] = rawVel
					else
						_paVelHistory[_velKey] = _paVelHistory[_velKey]:Lerp(rawVel, 0.35)
					end
					local smoothVel = _paVelHistory[_velKey]
					smoothVel = Vector3.new(smoothVel.X, rawVel.Y, smoothVel.Z)

					local aimTarget = targetBodyPart.Position
					local solverVelocity = projmeta.projectile == 'telepearl' and Vector3.zero or smoothVel
					local tHum = plr.Character and plr.Character:FindFirstChildOfClass('Humanoid')
					local tAirborne = false
					if tHum then
						tAirborne = tHum.FloorMaterial == Enum.Material.Air
						if not tAirborne then
							local st = tHum:GetState()
							tAirborne = st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall
						end
					end
					if not tAirborne and math.abs(rawVel.Y) > 3 then
						tAirborne = true
					end
					local tJumpPower = 42.6
					if tHum and tHum.UseJumpPower and tHum.JumpPower and tHum.JumpPower > 0 then
						tJumpPower = tHum.JumpPower
					end
					local tJump = (tAirborne or plr.Jumping) and tJumpPower or nil
					local horizLead = 1
					local vertLead = 1
					if CustomPredictions and CustomPredictions.Enabled and projmeta.projectile ~= 'telepearl' then
						horizLead = PredictHorizontal.Value / 100
						vertLead = PredictVertical.Value / 100
					end
					if horizLead ~= 1 or vertLead ~= 1 then
						solverVelocity = Vector3.new(
							solverVelocity.X * horizLead,
							solverVelocity.Y * vertLead,
							solverVelocity.Z * horizLead
						)
					end

					local newlook = CFrame.new(offsetpos, aimTarget) *
						CFrame.new(projmeta.projectile == 'owl_projectile' and Vector3.zero or
							Vector3.new(bowRelX, bowRelY, bowRelZ))
					local calc = prediction.SolveTrajectory(
						newlook.p, projSpeed, gravity,
						aimTarget,
						solverVelocity,
						playerGravity, plr.HipHeight,
						tJump,
						rayCheck,
						tAirborne,
						plr.RootPart.Position,
						plr.RootPart,
						nil,
						true
					)
					if not calc then
						calc = prediction.SolveTrajectory(
							newlook.p, projSpeed, gravity,
							aimTarget,
							solverVelocity,
							playerGravity, plr.HipHeight,
							tJump,
							nil,
							tAirborne,
							plr.RootPart.Position,
							plr.RootPart,
							nil,
							false
						)
					end

					if calc then
						paLockedTarget = plr
						paLockTime = tick()
						if targetinfo and targetinfo.Targets then
							targetinfo.Targets[plr] = tick() + 1
						end
						wasHovering = false
						return {
							initialVelocity = CFrame.new(newlook.Position, calc).LookVector * projSpeed,
							positionFrom = offsetpos,
							deltaT = lifetime,
							gravitationalAcceleration = gravity,
							drawDurationSeconds = customDrawDuration
						}
					end
					wasHovering = false
					return old(...)
				end
			else
				bedwars.ProjectileController.calculateImportantLaunchValues = old
				wasHovering = false
				lockedRandomPart = nil
				table.clear(_paVelHistory)
				if cursorRenderConnection then
					cursorRenderConnection:Disconnect()
					cursorRenderConnection = nil
				end
				runPAFOVCircle(false)
				pcall(function() inputService.MouseIconEnabled = true end)
				task.defer(function()
					pcall(function() inputService.MouseIconEnabled = true end)
					pcall(function() game:GetService('UserInputService').MouseIconEnabled = true end)
				end)
			end
		end,
		Tooltip = 'helps your shitty ass aim'
	})

	Targets = ProjectileAimbot:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})

	TargetPart = ProjectileAimbot:CreateDropdown({
		Name = 'Part',
		List = {'Dynamic', 'RootPart', 'Head', 'Closest', 'Randomize'},
		Default = 'RootPart',
		Function = function()
			lockedRandomPart = nil
			wasHovering = false
		end
	})

	SortMethod = ProjectileAimbot:CreateDropdown({
		Name = 'Sort Method',
		List = getSortList({'Distance', 'Damage', 'Cursor'}),
		Default = 'Cursor',
	})

	DesirePAWorkMode = ProjectileAimbot:CreateDropdown({
		Name = 'PA Work Mode',
		List = {'First Person', 'Third Person', 'Both'},
		Default = 'Both',
	})

	Range = ProjectileAimbot:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 500,
		Default = 100,
	})

	FOV = ProjectileAimbot:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 300,
	})

	PAFOVCircle = ProjectileAimbot:CreateToggle({
		Name = 'FOV Circle',
		Function = function(call)
			runPAFOVCircle(call)
		end
	})

	RandomHeadPercent = ProjectileAimbot:CreateSlider({
		Name = 'Head Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Darker = true,
		Visible = false
	})

	RandomTorsoPercent = ProjectileAimbot:CreateSlider({
		Name = 'Torso Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Darker = true,
		Visible = false,
		Function = function(val)
			if RandomHeadPercent and (RandomHeadPercent.Value + val) > 100 then
				notif('ProjectileAimbot', 'head or torso chance is more than 100% so root part will never be picked..', 3)
			end
		end
	})

	local function updateRandomizeVisibility()
		local vis = (TargetPart.Value == 'Randomize')
		RandomHeadPercent.Object.Visible = vis
		RandomTorsoPercent.Object.Visible = vis
	end
	if TargetPart.AddHook then
		TargetPart:AddHook(updateRandomizeVisibility)
	end
	updateRandomizeVisibility()

	DesirePAHideCursor = ProjectileAimbot:CreateToggle({
		Name = 'Hide Cursor',
		Default = false,
		Tooltip = 'Hides the cursor while aiming',
		Function = function(callback)
			if DesirePACursorViewMode then DesirePACursorViewMode.Object.Visible = callback end
			if DesirePACursorLimitBow then DesirePACursorLimitBow.Object.Visible = callback end
			if DesirePACursorShowGUI then DesirePACursorShowGUI.Object.Visible = callback end
			if callback and ProjectileAimbot.Enabled then
				if not cursorRenderConnection then
					cursorRenderConnection = runService.RenderStepped:Connect(function()
						checkGUIState()
						updateCursor()
					end)
				end
				updateCursor()
			else
				if cursorRenderConnection then
					cursorRenderConnection:Disconnect()
					cursorRenderConnection = nil
				end
				pcall(function() inputService.MouseIconEnabled = true end)
				task.defer(function()
					pcall(function() inputService.MouseIconEnabled = true end)
					pcall(function() game:GetService('UserInputService').MouseIconEnabled = true end)
				end)
			end
		end
	})

	DesirePACursorViewMode = ProjectileAimbot:CreateDropdown({
		Name = 'Cursor View Mode',
		List = {'First Person', 'Third Person', 'Both'},
		Default = 'First Person',
		Darker = true,
		Visible = false,
		Function = function()
			if ProjectileAimbot.Enabled and DesirePAHideCursor.Enabled then
				updateCursor()
			end
		end
	})

	DesirePACursorLimitBow = ProjectileAimbot:CreateToggle({
		Name = 'Limit to Bow',
		Darker = true,
		Visible = false,
		Function = function()
			if ProjectileAimbot.Enabled and DesirePAHideCursor.Enabled then
				updateCursor()
			end
		end
	})

	DesirePACursorShowGUI = ProjectileAimbot:CreateToggle({
		Name = 'Show on GUI',
		Darker = true,
		Visible = false,
		Function = function()
			if ProjectileAimbot.Enabled and DesirePAHideCursor.Enabled then
				updateCursor()
			end
		end
	})

	OtherProjectiles = ProjectileAimbot:CreateToggle({
		Name = 'Other Projectiles',
		Default = true,
		Function = function(call)
			if Blacklist then Blacklist.Object.Visible = call end
		end
	})

	Blacklist = ProjectileAimbot:CreateTextList({
		Name = 'Blacklist',
		Darker = true,
		Default = {'telepearl'},
		Visible = OtherProjectiles.Enabled
	})

	CustomPredictions = ProjectileAimbot:CreateToggle({
		Name = 'Custom Predictions',
		Default = false,
		Tooltip = 'lets u control how much it leads the target urself',
		Function = function(callback)
			if PredictHorizontal then PredictHorizontal.Object.Visible = callback end
			if PredictVertical then PredictVertical.Object.Visible = callback end
		end
	})
	PredictHorizontal = ProjectileAimbot:CreateSlider({
		Name = 'Horizontal',
		Min = 0,
		Max = 300,
		Default = 100,
		Suffix = '%',
		Darker = true,
		Visible = false
	})
	PredictVertical = ProjectileAimbot:CreateSlider({
		Name = 'Vertical',
		Min = 0,
		Max = 300,
		Default = 100,
		Suffix = '%',
		Darker = true,
		Visible = false
	})
	AutoCharge = ProjectileAimbot:CreateToggle({
		Name = "AutoCharge",
		Default = true,
		Function = function(v)
			if skidPAChargePercent and skidPAChargePercent.Object then skidPAChargePercent.Object.Visible = v end
		end
	})
	skidPAChargePercent = ProjectileAimbot:CreateSlider({
		Name = 'Charge Percent',
		Min = 1,
		Max = 100,
		Default = 100,
	})
end)

local Attacking
run(function()
	local Killaura
	local Targets
	local Sort
	local SwingRange
	local AttackRange
	local ChargeTime
	local UpdateRate
	local AngleSlider
	local MaxTargets
	local Mouse
	local Swing
	local GUI
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Face
	local Animation
	local AnimationMode
	local AnimationSpeed
	local AnimationTween
	local Limit
	local LegitAura = {}
	local Particles, Boxes = {}, {}
	local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
	local AttackRemote = {FireServer = function() end}
	task.spawn(function()
		AttackRemote = bedwars.Client:Get(remotes.AttackEntity).instance
	end)

	local function getAttackData()
		if Mouse.Enabled then
			if not inputService:IsMouseButtonPressed(0) then return false end
		end

		if GUI.Enabled then
			if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
		end

		local sword = Limit.Enabled and store.hand or store.tools.sword
		if not sword or not sword.tool then return false end

		local meta = bedwars.ItemMeta[sword.tool.Name]
		if Limit.Enabled then
			if store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid then return false end
		end

		if LegitAura.Enabled then
			if (tick() - bedwars.SwordController.lastSwing) > 0.2 then return false end
		end

		return sword, meta
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = Limit.Enabled
					end)
				end

				if Animation.Enabled and not (identifyexecutor and table.find({'Argon', 'Delta'}, ({identifyexecutor()})[1])) then
					local fake = {
						Controllers = {
							ViewmodelController = {
								isVisible = function()
									return not Attacking
								end,
								playAnimation = function(...)
									if not Attacking then
										bedwars.ViewmodelController:playAnimation(select(2, ...))
									end
								end
							}
						}
					}
					debug.setupvalue(oldSwing or bedwars.SwordController.playSwordEffect, 6, fake)
					debug.setupvalue(bedwars.ScytheController.playLocalAnimation, 3, fake)

					task.spawn(function()
						local started = false
						repeat
							if Attacking then
								if not armC0 then
									armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0
								end
								local first = not started
								started = true

								if AnimationMode.Value == 'Random' then
									anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
								end

								for _, v in anims[AnimationMode.Value] do
									AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
										C0 = armC0 * v.CFrame
									})
									AnimTween:Play()
									AnimTween.Completed:Wait()
									first = false
									if (not Killaura.Enabled) or (not Attacking) then break end
								end
							elseif started then
								started = false
								AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
									C0 = armC0
								})
								AnimTween:Play()
							end

							if not started then
								task.wait(1 / UpdateRate.Value)
							end
						until (not Killaura.Enabled) or (not Animation.Enabled)
					end)
				end

				local swingCooldown = 0
				repeat
					local attacked, sword, meta = {}, getAttackData()
					Attacking = false
					store.KillauraTarget = nil
					if sword then
						local plrs = entitylib.AllPosition({
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = MaxTargets.Value,
							Sort = sortmethods[Sort.Value]
						})

						if #plrs > 0 then
							switchItem(sword.tool, 0)
							local selfpos = entitylib.character.RootPart.Position
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)

							for _, v in plrs do
								local delta = (v.RootPart.Position - selfpos)
								local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
								if angle > (math.rad(AngleSlider.Value) / 2) then continue end

								table.insert(attacked, {
									Entity = v,
									Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
								})
								targetinfo.Targets[v] = tick() + 1

								if not Attacking then
									Attacking = true
									store.KillauraTarget = v
									if not Swing.Enabled and AnimDelay < tick() and not LegitAura.Enabled then
										AnimDelay = tick() + (meta.sword.respectAttackSpeedForEffects and meta.sword.attackSpeed or math.max(ChargeTime.Value, 0.11))
										bedwars.SwordController:playSwordEffect(meta, false)
										if meta.displayName:find(' Scythe') then
											bedwars.ScytheController:playLocalAnimation()
										end

										if vape.ThreadFix then
											setthreadidentity(8)
										end
									end
								end

								if delta.Magnitude > AttackRange.Value then continue end
								if delta.Magnitude < 14.4 and (tick() - swingCooldown) < math.max(ChargeTime.Value, 0.11) then continue end

								local actualRoot = v.Character.PrimaryPart
								if actualRoot then
									local dir = CFrame.lookAt(selfpos, actualRoot.Position).LookVector
									local pos = selfpos + dir * math.max(delta.Magnitude - 14.399, 0)
									swingCooldown = tick()
									bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
									store.attackReach = (delta.Magnitude * 100) // 1 / 100
									store.attackReachUpdate = tick() + 1

									if delta.Magnitude < 14.4 and ChargeTime.Value > 0.11 then
										AnimDelay = tick()
									end

									AttackRemote:FireServer({
										weapon = sword.tool,
										chargedAttack = {chargeRatio = 0},
										lastSwingServerTimeDelta = 0.5,
										entityInstance = v.Character,
										validate = {
											raycast = {
												cameraPosition = {value = pos},
												cursorDirection = {value = dir}
											},
											targetPosition = {value = actualRoot.Position},
											selfPosition = {value = pos}
										}
									})
								end
							end
						end
					end

					for i, v in Boxes do
						v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
						if v.Adornee then
							v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
							v.Transparency = 1 - attacked[i].Check.Opacity
						end
					end

					for i, v in Particles do
						v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
						v.Parent = attacked[i] and gameCamera or nil
					end

					if Face.Enabled and attacked[1] then
						local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
						entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.001, vec.Z))
					end

					--#attacked > 0 and #attacked * 0.02 or
					task.wait(1 / UpdateRate.Value)
				until not Killaura.Enabled
			else
				store.KillauraTarget = nil
				for _, v in Boxes do
					v.Adornee = nil
				end
				for _, v in Particles do
					v.Parent = nil
				end
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = true
					end)
				end
				debug.setupvalue(oldSwing or bedwars.SwordController.playSwordEffect, 6, bedwars.Knit)
				debug.setupvalue(bedwars.ScytheController.playLocalAnimation, 3, bedwars.Knit)
				Attacking = false
				if armC0 then
					AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
						C0 = armC0
					})
					AnimTween:Play()
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({
		Players = true,
		NPCs = true
	})
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 50,
		Default = 20,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 23,
		Default = 20,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	ChargeTime = Killaura:CreateSlider({
		Name = 'Swing time',
		Min = 0,
		Max = 0.5,
		Default = 0.42,
		Decimal = 100
	})
	AngleSlider = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
	UpdateRate = Killaura:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})
	MaxTargets = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 5,
		Default = 5
	})
	Sort = Killaura:CreateDropdown({
		Name = 'Target Mode',
		List = methods
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Swing = Killaura:CreateToggle({Name = 'No Swing'})
	GUI = Killaura:CreateToggle({Name = 'GUI check'})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
					Boxes[i] = box
				end
			else
				for _, v in Boxes do
					v:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})
	BoxSwingColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
	BoxAttackColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Speed = NumberRange.new(16)
					particles.Rate = 128
					particles.Drag = 16
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for _, v in Particles do
					v:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function()
			for _, v in Particles do
				v.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Function = function(val)
			for _, v in Particles do
				v.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
	Face = Killaura:CreateToggle({Name = 'Face target'})
	Animation = Killaura:CreateToggle({
		Name = 'Custom Animation',
		Function = function(callback)
			AnimationMode.Object.Visible = callback
			AnimationTween.Object.Visible = callback
			AnimationSpeed.Object.Visible = callback
			if Killaura.Enabled then
				Killaura:Toggle()
				Killaura:Toggle()
			end
		end
	})
	local animnames = {}
	for i in anims do
		table.insert(animnames, i)
	end
	AnimationMode = Killaura:CreateDropdown({
		Name = 'Animation Mode',
		List = animnames,
		Darker = true,
		Visible = false
	})
	AnimationSpeed = Killaura:CreateSlider({
		Name = 'Animation Speed',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 10,
		Darker = true,
		Visible = false
	})
	AnimationTween = Killaura:CreateToggle({
		Name = 'No Tween',
		Darker = true,
		Visible = false
	})
	Limit = Killaura:CreateToggle({
		Name = 'Limit to items',
		Function = function(callback)
			if inputService.TouchEnabled and Killaura.Enabled then
				pcall(function()
					lplr.PlayerGui.MobileUI['2'].Visible = callback
				end)
			end
		end,
		Tooltip = 'Only attacks when the sword is held'
	})
	LegitAura = Killaura:CreateToggle({
		Name = 'Swing only',
		Tooltip = 'Only attacks while swinging manually'
	})
end)


run(function()
	local ProjectileAura
	local Targets
	local Range
	local List
	local HandCheck
	local FireSpeed
    local rayCheck = cloneRaycast()
	local projectileRemote = {InvokeServer = function() end}
	local FireDelays = {}
	task.spawn(function()
		projectileRemote = replicatedStorage:WaitForChild('rbxts_include'):WaitForChild('node_modules'):WaitForChild('@rbxts'):WaitForChild('net'):WaitForChild('out'):WaitForChild('_NetManaged'):WaitForChild('ProjectileFire')
	end)
	
	local function getAmmo(check)
		for _, item in store.inventory.inventory.items do
			if check.ammoItemTypes and table.find(check.ammoItemTypes, item.itemType) then
				return item.itemType
			end
		end
	end
	
	local function getProjectiles()
		local items = {}
		for _, item in store.inventory.inventory.items do
			local proj = bedwars.ItemMeta[item.itemType].projectileSource
			local ammo = proj and getAmmo(proj)
			if ammo and table.find(List.ListEnabled, ammo) then
				table.insert(items, {
					item,
					ammo,
					proj.projectileType(ammo),
					proj
				})
			end
		end
		return items
	end
	
	ProjectileAura = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAura',
		Function = function(callback)
			if callback then
				repeat
					local holdingCrossbow = store.hand and store.hand.tool and store.hand.tool.Name:find('crossbow')
					local holdingBow = store.hand and store.hand.tool and store.hand.tool.Name:find('bow')
					
					if HandCheck.Enabled and not holdingCrossbow and not holdingBow then
						task.wait(0.1)
						continue
					end
					
					local fightingTarget = store.KillauraTarget
					if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.5 or fightingTarget then
						local ent = fightingTarget or entitylib.EntityPosition({
							Part = 'RootPart',
							Range = Range.Value,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled
						})
	
						if ent and ent.RootPart and ent.Character and ent.Character.Parent
							and (ent.RootPart.Position - entitylib.character.RootPart.Position).Magnitude <= Range.Value then
							local pos = entitylib.character.RootPart.Position
							for _, data in getProjectiles() do
								local item, ammo, projectile, itemMeta = unpack(data)
								if (FireDelays[item.itemType] or 0) < tick() then
									rayCheck.FilterDescendantsInstances = {workspace.Map}
									local meta = bedwars.ProjectileMeta[projectile]
									local projSpeed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2
									local lifetime = tonumber(meta.predictionLifetimeSec) or tonumber(meta.lifetimeSec) or (projSpeed > 0 and math.min(3, 120 / projSpeed) or 3)
									local entGravity = workspace.Gravity
									local balloons = ent.Character and ent.Character:GetAttribute('InflatedBalloons')
									if balloons and balloons > 0 then
										entGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
									end
									local entVel = ent.RootPart.AssemblyLinearVelocity or ent.RootPart.Velocity or Vector3.zero
													local calc = prediction.SolveTrajectory(pos, projSpeed, gravity, ent.RootPart.Position, entVel, entGravity, ent.HipHeight, ent.Jumping and 42.6 or nil, rayCheck, nil, ent.RootPart.Position, ent.RootPart, nil, true)
									if calc then
										targetinfo.Targets[ent] = tick() + 1
										local switched = switchItem(item.tool)
	
										task.spawn(function()
											local dir, id = CFrame.lookAt(pos, calc).LookVector, httpService:GenerateGUID(true)
											local shootPosition = (CFrame.new(pos, calc) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
											
											if holdingCrossbow then
												bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_CROSSBOW_FIRE)
												bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.CROSSBOW_FIRE)
											elseif holdingBow then
												bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_CROSSBOW_FIRE)
												bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.BOW_FIRE)
											else
												local shootAnim = bedwars.ItemMeta[item.tool.Name].thirdPerson and bedwars.ItemMeta[item.tool.Name].thirdPerson.shootAnimation
												if shootAnim then
													bedwars.GameAnimationUtil:playAnimation(lplr, shootAnim)
												end
											end
											
											bedwars.ProjectileController:createLocalProjectile(meta, ammo, projectile, shootPosition, id, dir * projSpeed, {drawDurationSeconds = 1})
											local res = projectileRemote:InvokeServer(item.tool, ammo, projectile, shootPosition, pos, dir * projSpeed, id, {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)
											if not res then
												FireDelays[item.itemType] = tick()
											else
												local shoot = itemMeta.launchSound
												shoot = shoot and shoot[math.random(1, #shoot)] or nil
												if shoot then
													bedwars.SoundManager:playSound(shoot)
												end
											end
										end)
	
										FireDelays[item.itemType] = tick() + ((tonumber(itemMeta.fireDelaySec) or 0.5) / FireSpeed.Value)
										if switched then
											task.wait(0.05)
										end
									end
								end
							end
						end
					end
					task.wait(0.1)
				until not ProjectileAura.Enabled
			end
		end,
		Tooltip = 'Shoots people around you with viewmodel animations'
	})
	Targets = ProjectileAura:CreateTargets({
		Players = true,
		Walls = true
	})
	List = ProjectileAura:CreateTextList({
		Name = 'Projectiles',
		Default = {'arrow', 'snowball'}
	})
	Range = ProjectileAura:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 50,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	FireSpeed = ProjectileAura:CreateSlider({
		Name = 'Fire Speed',
		Min = 0.5,
		Max = 3,
		Default = 1,
		Decimal = 10,
	})
	HandCheck = ProjectileAura:CreateToggle({
		Name = 'Hand Check',
		Default = false,
		Tooltip = 'Only shoot when holding a bow or crossbow'
	})
end)

run(function()
	local Mode
	local Value
	local WallCheck
	local AutoJump
	local AlwaysJump
	local savedImpulseTime
	local rayCheck = cloneRaycast()
	rayCheck.RespectCanCollide = true
	rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
	
	Speed = vape.Categories.Blatant:CreateModule({
		Name = 'Speed',
		Function = function(callback)
			frictionTable.Speed = nil
			updateVelocity()
			pcall(function()
				debug.setconstant(bedwars.WindWalkerController.updateSpeed, 7, callback and 'constantSpeedMultiplier' or 'moveSpeedMultiplier')
			end)
	
			if callback then
				if savedImpulseTime == nil then
					savedImpulseTime = bedwars.StatefulEntityKnockbackController.lastImpulseTime
				end
				Speed:Clean(function()
					pcall(function()
						bedwars.StatefulEntityKnockbackController.lastImpulseTime = (savedImpulseTime ~= nil and savedImpulseTime ~= math.huge) and savedImpulseTime or time()
					end)
					savedImpulseTime = nil
					pcall(function()
						if entitylib.isAlive then
							local root = entitylib.character.RootPart
							root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
						end
					end)
					pcall(function()
						bedwars.SprintController:setSpeed(bedwars.SprintController:isSprinting() and 20 or 14)
					end)
				end)
				Speed:Clean(runService.PreSimulation:Connect(function(dt)
					if not Speed.Enabled then return end
					bedwars.StatefulEntityKnockbackController.lastImpulseTime = math.huge
					if entitylib.isAlive then
						if not (Fly and Fly.Enabled) and not (LongJump and LongJump.Enabled) then
							bedwars.SprintController:setSpeed(Mode.Value == 'CFrame' and 20 or Value.Value)
							if Mode.Value == 'CFrame' then
								local state = entitylib.character.Humanoid:GetState()
								if state == Enum.HumanoidStateType.Climbing then return end
			
								local root, velo = entitylib.character.RootPart, getSpeed()
								local moveDirection = AntiFallDirection or entitylib.character.Humanoid.MoveDirection
								local destination = (moveDirection * math.max(Value.Value - velo, 0) * dt)
			
								if WallCheck.Enabled then
									rayCheck.CollisionGroup = root.CollisionGroup
									local ray = workspace:Raycast(root.Position, destination, rayCheck)
									if ray then
										destination = ((ray.Position + ray.Normal) - root.Position)
									end
								end
			
								root.CFrame += destination
								root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
								if AutoJump.Enabled and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed) and moveDirection ~= Vector3.zero and (Attacking or AlwaysJump.Enabled) then
									entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
								end
							end
						end
					end
				end))
			else
				pcall(function()
					bedwars.StatefulEntityKnockbackController.lastImpulseTime = (savedImpulseTime ~= nil and savedImpulseTime ~= math.huge) and savedImpulseTime or time()
				end)
				savedImpulseTime = nil
				pcall(function()
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
					end
				end)
				pcall(function()
					bedwars.SprintController:setSpeed(bedwars.SprintController:isSprinting() and 20 or 14)
				end)
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'increases your movement with various methods.'
	})
	Mode = Speed:CreateDropdown({
		Name = 'Method',
		List = {'Bedwars', 'CFrame'},
		Default = 'CFrame'
	})
	Value = Speed:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 23,
		Default = 23,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	_G.SpeedValue = Value
	WallCheck = Speed:CreateToggle({
		Name = 'Wall Check',
		Default = true
	})
	AutoJump = Speed:CreateToggle({
		Name = 'AutoJump',
		Function = function(callback)
			AlwaysJump.Object.Visible = callback
		end
	})
	AlwaysJump = Speed:CreateToggle({
		Name = 'Always Jump',
		Visible = false,
		Darker = true
	})
end)

run(function()
    local BCR
    local Value
    local CpsConstants = nil
    
    BCR = vape.Categories.Blatant:CreateModule({
        Name = "BlockCPSRemover",
        Function = function(callback)
            
            if callback then
                task.wait(1)
                
                pcall(function()
                    CpsConstants = require(replicatedStorage.TS['shared-constants']).CpsConstants
                end)
                
                if not CpsConstants then
                    pcall(function()
                        CpsConstants = bedwars.CpsConstants
                    end)
                end
                
                if CpsConstants then
                    local newCPS = Value.Value == 0 and 1000 or Value.Value
                    CpsConstants.BLOCK_PLACE_CPS = newCPS
                    
                    if isMobile then
                        for _, v in {'2', '5'} do
                            pcall(function()
                                BCR:Clean(lplr.PlayerGui.MobileUI[v].MouseButton1Down:Connect(function()
                                    if CpsConstants then
                                        local currentValue = Value.Value == 0 and 1000 or Value.Value
                                        CpsConstants.BLOCK_PLACE_CPS = currentValue
                                    end
                                end))
                            end)
                        end
                    end
                    
                    task.spawn(function()
                        while BCR.Enabled do
                            local currentValue = Value.Value == 0 and 1000 or Value.Value
                            if CpsConstants.BLOCK_PLACE_CPS ~= currentValue then
                                CpsConstants.BLOCK_PLACE_CPS = currentValue
                            end
                            task.wait(0.3)
                        end
                    end)
                end
                
            else
                if CpsConstants then
                    CpsConstants.BLOCK_PLACE_CPS = 12
                end
            end
        end,
        Tooltip = 'place blocks faster'
    })
    
    Value = BCR:CreateSlider({
        Name = "CPS Limit",
        Suffix = "CPS",
        Default = 12,
        Min = 12,
        Max = 20,
        Function = function()
            if BCR.Enabled and CpsConstants then
                local newCPS = Value.Value == 0 and 1000 or Value.Value
                CpsConstants.BLOCK_PLACE_CPS = newCPS
            end
        end,
    })
end)

run(function()
	local Value
	local CameraDir
	local start
	local JumpTick, JumpSpeed, Direction = tick(), 0
	local projectileRemote = {InvokeServer = function() end}
	task.spawn(function()
		projectileRemote = replicatedStorage:WaitForChild('rbxts_include'):WaitForChild('node_modules'):WaitForChild('@rbxts'):WaitForChild('net'):WaitForChild('out'):WaitForChild('_NetManaged'):WaitForChild('ProjectileFire')
	end)
	local handGunRemote = {InvokeServer = function() end}
	task.spawn(function()
		handGunRemote = game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("HandGunFireRequest")
	end)
	
	local function launchProjectile(item, pos, proj, speed, dir)
		if not pos then return end
	
		pos = pos - dir * 0.1
		local shootPosition = (CFrame.lookAlong(pos, Vector3.new(0, -speed, 0)) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ)))
		switchItem(item.tool, 0)
		task.wait(0.1)
		bedwars.ProjectileController:createLocalProjectile(bedwars.ProjectileMeta[proj], proj, proj, shootPosition.Position, '', shootPosition.LookVector * speed, {drawDurationSeconds = 1})
		if projectileRemote:InvokeServer(item.tool, proj, proj, shootPosition.Position, pos, shootPosition.LookVector * speed, httpService:GenerateGUID(true), {drawDurationSeconds = 1}, workspace:GetServerTimeNow() - 0.045) then
			local shoot = bedwars.ItemMeta[item.itemType].projectileSource.launchSound
			shoot = shoot and shoot[math.random(1, #shoot)] or nil
			if shoot then
				bedwars.SoundManager:playSound(shoot)
			end
		end
	end
	
	local LongJumpMethods = {
		cannon = function(_, pos, dir)
			pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
			local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
			bedwars.placeBlock(rounded, 'cannon', false)
	
			task.delay(0, function()
				local block, blockpos = getPlacedBlock(rounded)
				if block and block.Name == 'cannon' and (entitylib.character.RootPart.Position - block.Position).Magnitude < 20 then
					local breaktype = bedwars.ItemMeta[block.Name].block.breakType
					local tool = store.tools[breaktype]
					if tool then
						switchItem(tool.tool)
					end
	
					bedwars.Client:Get(remotes.CannonAim):SendToServer({
						cannonBlockPos = blockpos,
						lookVector = dir
					})
	
					local broken = 0.1
					if bedwars.BlockController:calculateBlockDamage(lplr, {blockPosition = blockpos}) < block:GetAttribute('Health') then
						broken = 0.4
						bedwars.breakBlock(block, true, true)
					end
	
					task.delay(broken, function()
						for _ = 1, 4 do
							local call = bedwars.Client:Get(remotes.CannonLaunch):CallServer({cannonBlockPos = blockpos})
							if call then
								bedwars.breakBlock(block, true, true)
								JumpSpeed = 5.25 * Value.Value
								JumpTick = tick() + 2.3
								Direction = Vector3.new(dir.X, 0, dir.Z).Unit
								break
							end
							task.wait(0.1)
						end
					end)
				end
			end)
		end,
		cat = function(_, _, dir)
			LongJump:Clean(vapeEvents.CatPounce.Event:Connect(function()
				JumpSpeed = 4 * Value.Value
				JumpTick = tick() + 2.5
				Direction = Vector3.new(dir.X, 0, dir.Z).Unit
				entitylib.character.RootPart.Velocity = Vector3.zero
			end))
	
			if not bedwars.AbilityController:canUseAbility('CAT_POUNCE') then
				repeat task.wait() until bedwars.AbilityController:canUseAbility('CAT_POUNCE') or not LongJump.Enabled
			end
	
			if bedwars.AbilityController:canUseAbility('CAT_POUNCE') and LongJump.Enabled then
				bedwars.AbilityController:useAbility('CAT_POUNCE')
			end
		end,
		fireball = function(item, pos, dir)
			launchProjectile(item, pos, 'fireball', 60, dir)
		end,
		grappling_hook = function(item, pos, dir)
			launchProjectile(item, pos, 'grappling_hook_projectile', 140, dir)
		end,
		jade_hammer = function(item, _, dir)
			if not bedwars.AbilityController:canUseAbility(item.itemType..'_jump') then
				repeat task.wait() until bedwars.AbilityController:canUseAbility(item.itemType..'_jump') or not LongJump.Enabled
			end
	
			if bedwars.AbilityController:canUseAbility(item.itemType..'_jump') and LongJump.Enabled then
				bedwars.AbilityController:useAbility(item.itemType..'_jump')
				JumpSpeed = 1.4 * Value.Value
				JumpTick = tick() + 2.5
				Direction = Vector3.new(dir.X, 0, dir.Z).Unit
			end
		end,
		tnt = function(item, pos, dir)
			pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
			local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
			start = Vector3.new(rounded.X, start.Y, rounded.Z) + (dir * (item.itemType == 'pirate_gunpowder_barrel' and 2.6 or 0.2))
			bedwars.placeBlock(rounded, item.itemType, false)
		end,
		wood_dao = function(item, pos, dir)
			if (lplr.Character:GetAttribute('CanDashNext') or 0) > workspace:GetServerTimeNow() or not bedwars.AbilityController:canUseAbility('dash') then
				repeat task.wait() until (lplr.Character:GetAttribute('CanDashNext') or 0) < workspace:GetServerTimeNow() and bedwars.AbilityController:canUseAbility('dash') or not LongJump.Enabled
			end
	
			if LongJump.Enabled then
				if not (LegitAura and LegitAura.Enabled) then
					bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
				end
				switchItem(item.tool, 0.1)
				replicatedStorage['events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'].useAbility:FireServer('dash', {
					direction = dir,
					origin = pos,
					weapon = item.itemType
				})
				JumpSpeed = 4.5 * Value.Value
				JumpTick = tick() + 2.4
				Direction = Vector3.new(dir.X, 0, dir.Z).Unit
			end
		end
	}
	for _, v in {'stone_dao', 'iron_dao', 'diamond_dao', 'emerald_dao'} do
		LongJumpMethods[v] = LongJumpMethods.wood_dao
	end
	LongJumpMethods.void_axe = LongJumpMethods.jade_hammer
	LongJumpMethods.siege_tnt = LongJumpMethods.tnt
	LongJumpMethods.pirate_gunpowder_barrel = LongJumpMethods.tnt
	
	LongJump = vape.Categories.Blatant:CreateModule({
		Name = 'LongJump',
		Function = function(callback)
			frictionTable.LongJump = callback or nil
			updateVelocity()
			if callback then
				LongJump:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
					if damageTable.entityInstance == lplr.Character and damageTable.fromEntity == lplr.Character and (not damageTable.knockbackMultiplier or not damageTable.knockbackMultiplier.disabled) then
						local knockbackBoost = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {
							vertical = 0,
							horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 1)
						}).Magnitude * 1.1
	
						if knockbackBoost >= JumpSpeed then
							local pos = damageTable.fromPosition and Vector3.new(damageTable.fromPosition.X, damageTable.fromPosition.Y, damageTable.fromPosition.Z) or damageTable.fromEntity and damageTable.fromEntity.PrimaryPart.Position
							if not pos then return end
							local vec = (entitylib.character.RootPart.Position - pos)
							JumpSpeed = knockbackBoost
							JumpTick = tick() + 2.5
							Direction = Vector3.new(vec.X, 0, vec.Z).Unit
						end
					end
				end))
				LongJump:Clean(vapeEvents.GrapplingHookFunctions.Event:Connect(function(dataTable)
					if dataTable.hookFunction == 'PLAYER_IN_TRANSIT' then
						local vec = entitylib.character.RootPart.CFrame.LookVector
						JumpSpeed = 2.5 * Value.Value
						JumpTick = tick() + 2.5
						Direction = Vector3.new(vec.X, 0, vec.Z).Unit
					end
				end))
	
				start = entitylib.isAlive and entitylib.character.RootPart.Position or nil
				LongJump:Clean(runService.PreSimulation:Connect(function(dt)
					local root = entitylib.isAlive and entitylib.character.RootPart or nil
	
					if root and isnetworkowner(root) then
						if JumpTick > tick() then
							root.AssemblyLinearVelocity = Direction * (getSpeed() + ((JumpTick - tick()) > 1.1 and JumpSpeed or 0)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
							if entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air and not start then
								root.AssemblyLinearVelocity += Vector3.new(0, dt * (workspace.Gravity - 23), 0)
							else
								root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 15, root.AssemblyLinearVelocity.Z)
							end
							start = nil
						else
							if start then
								root.CFrame = CFrame.lookAlong(start, root.CFrame.LookVector)
							end
							root.AssemblyLinearVelocity = Vector3.zero
							JumpSpeed = 0
						end
					else
						start = nil
					end
				end))

				if store.hand and store.hand.tool and LongJumpMethods[store.hand.tool.Name] then
					task.spawn(LongJumpMethods[store.hand.tool.Name], getItem(store.hand.tool.Name), start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
					return
				end
				
				local foundItem = false
				for i, v in LongJumpMethods do
					local item = getItem(i)
					if item or store.equippedKit == i then
						foundItem = true
						task.spawn(v, item, start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
						break
					end
				end
				if not foundItem then
					notif("LongJump", "unable to find tool to use Long Jump with gng", 3)
					LongJump:Toggle()
					return
				end
			else
				JumpTick = tick()
				Direction = nil
				JumpSpeed = 0
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'lets you jump farther'
	})
	Value = LongJump:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 37,
		Default = 37,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	CameraDir = LongJump:CreateToggle({
		Name = 'Camera Direction'
	})
end)

--[[
	Render Modules
]]

run(function()
	local BedESP
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Added(bed)
		if not BedESP.Enabled then return end
		local BedFolder = Instance.new('Folder')
		BedFolder.Parent = Folder
		Reference[bed] = BedFolder
		local parts = bed:GetChildren()
		table.sort(parts, function(a, b)
			return a.Name > b.Name
		end)
	
		for _, part in parts do
			if part:IsA('BasePart') and part.Name ~= 'Blanket' then
				local handle = Instance.new('BoxHandleAdornment')
				handle.Size = part.Size + Vector3.new(.01, .01, .01)
				handle.AlwaysOnTop = true
				handle.ZIndex = 2
				handle.Visible = true
				handle.Adornee = part
				handle.Color3 = part.Color
				if part.Name == 'Legs' then
					handle.Color3 = Color3.fromRGB(167, 112, 64)
					handle.Size = part.Size + Vector3.new(.01, -1, .01)
					handle.CFrame = CFrame.new(0, -0.4, 0)
					handle.ZIndex = 0
				end
				handle.Parent = BedFolder
			end
		end
	
		table.clear(parts)
	end
	
	BedESP = vape.Categories.Render:CreateModule({
		Name = 'BedESP',
		Function = function(callback)
			if callback then
				BedESP:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(function(bed)
					task.delay(0.2, Added, bed)
				end))
				BedESP:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(bed)
					if Reference[bed] then
						Reference[bed]:Destroy()
						Reference[bed] = nil
					end
				end))
				for _, bed in collectionService:GetTagged('bed') do
					Added(bed)
				end
			else
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'Render Beds through walls'
	})
end)

run(function()
	local LootESP
	local IronToggle
	local DiamondToggle
	local EmeraldToggle
	local GeneratorToggle
	local ScaleToggle
	local ScaleSlider
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui	
	local CollectionService = collectionService
	
	local lootTypes = {
		iron = {
			keywords = {'iron'},
			color = Color3.fromRGB(200, 200, 200),
			icon = 'iron',
			displayName = 'IRON'
		},
		diamond = {
			keywords = {'diamond'},
			color = Color3.fromRGB(85, 200, 255),
			icon = 'diamond',
			displayName = 'DIAMOND'
		},
		emerald = {
			keywords = {'emerald'},
			color = Color3.fromRGB(0, 255, 100),
			icon = 'emerald',
			displayName = 'EMERALD'
		}
	}
	
	local function getLootType(itemName)
		local nameLower = itemName:lower()
		for lootType, config in pairs(lootTypes) do
			for _, keyword in ipairs(config.keywords) do
				if nameLower:find(keyword, 1, true) then 
					return lootType, config
				end
			end
		end
		return nil
	end
	
	local function isLootEnabled(lootType)
		if lootType == 'iron' then
			return IronToggle.Enabled
		elseif lootType == 'diamond' then
			return DiamondToggle.Enabled
		elseif lootType == 'emerald' then
			return EmeraldToggle.Enabled
		end
		return false
	end
	
	local function readDropAttr(handle, attr)
		if not handle then return nil end
		local val = handle:GetAttribute(attr)
		if val == nil and handle.Parent then
			val = handle.Parent:GetAttribute(attr)
		end
		return val
	end
	
	local function isGeneratorDrop(handle)
		return readDropAttr(handle, 'OreGenDrop') == true
	end
	
	local function getDropAmount(handle)
		local amt = readDropAttr(handle, 'Amount')
		if type(amt) ~= 'number' then return 1 end
		return amt
	end
	
	local function getProperIcon(lootType)
		local icon = bedwars.getIcon({itemType = lootType}, true)
		
		if not icon or icon == "" then
			return nil
		end
		
		return icon
	end
	
	local function Added(lootHandle, lootType, config)
		if not isLootEnabled(lootType) then return end
		if Reference[lootHandle] then return end 
		if isGeneratorDrop(lootHandle) and not (GeneratorToggle and GeneratorToggle.Enabled) then return end 
		
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = lootType
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		local ls = (ScaleToggle and ScaleToggle.Enabled and ScaleSlider) and ScaleSlider.Value or 1
		billboard.Size = UDim2.fromOffset(40 * ls, 40 * ls)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = lootHandle
		
		local blur = addBlur(billboard)
		blur.Visible = true 
		
		local iconImage = getProperIcon(config.icon)
		
		if iconImage then
			local image = Instance.new('ImageLabel')
			image.Size = UDim2.fromOffset(40, 40)
			image.Position = UDim2.fromScale(0.5, 0.5)
			image.AnchorPoint = Vector2.new(0.5, 0.5)
			image.BackgroundColor3 = Color3.new(0, 0, 0) 
			image.BackgroundTransparency = 0.3 
			image.BorderSizePixel = 0
			image.Image = iconImage
			image.Parent = billboard
			
			local uicorner = Instance.new('UICorner')
			uicorner.CornerRadius = UDim.new(0, 4)
			uicorner.Parent = image
			
			local amt = Instance.new('TextLabel')
			amt.Name = 'Amt'
			amt.AnchorPoint = Vector2.new(1, 1)
			amt.Position = UDim2.new(1, -1, 1, -1)
			amt.Size = UDim2.fromOffset(40, 14)
			amt.BackgroundTransparency = 1
			amt.Text = tostring(getDropAmount(lootHandle))
			amt.TextColor3 = Color3.fromRGB(255, 255, 255)
			amt.TextStrokeTransparency = 0.4
			amt.TextSize = 13
			amt.Font = Enum.Font.GothamBold
			amt.TextXAlignment = Enum.TextXAlignment.Right
			amt.TextYAlignment = Enum.TextYAlignment.Bottom
			amt.Parent = image
		else
			local frame = Instance.new('Frame')
			frame.Size = UDim2.fromOffset(40, 40)
			frame.Position = UDim2.fromScale(0.5, 0.5)
			frame.AnchorPoint = Vector2.new(0.5, 0.5)
			frame.BackgroundColor3 = Color3.new(0, 0, 0) 
			frame.BackgroundTransparency = 0.3 
			frame.BorderSizePixel = 0
			frame.Parent = billboard
			
			local uicorner = Instance.new('UICorner')
			uicorner.CornerRadius = UDim.new(0, 4)
			uicorner.Parent = frame
			
			local textLabel = Instance.new('TextLabel')
			textLabel.Size = UDim2.fromScale(1, 1)
			textLabel.Position = UDim2.fromScale(0.5, 0.5)
			textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
			textLabel.BackgroundTransparency = 1
			textLabel.Text = config.displayName
			textLabel.TextColor3 = config.color
			textLabel.TextScaled = true
			textLabel.Font = Enum.Font.GothamBold
			textLabel.TextStrokeTransparency = 0.5
			textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
			textLabel.Parent = frame
			
			local amt = Instance.new('TextLabel')
			amt.Name = 'Amt'
			amt.AnchorPoint = Vector2.new(1, 1)
			amt.Position = UDim2.new(1, -1, 1, -1)
			amt.Size = UDim2.fromOffset(40, 14)
			amt.BackgroundTransparency = 1
			amt.Text = tostring(getDropAmount(lootHandle))
			amt.TextColor3 = Color3.fromRGB(255, 255, 255)
			amt.TextStrokeTransparency = 0.4
			amt.TextSize = 13
			amt.Font = Enum.Font.GothamBold
			amt.TextXAlignment = Enum.TextXAlignment.Right
			amt.TextYAlignment = Enum.TextYAlignment.Bottom
			amt.Parent = frame
		end
		
		local content = billboard:FindFirstChild('ImageLabel') or billboard:FindFirstChild('Frame')
		if content then
			local sc = Instance.new('UIScale')
			sc.Name = 'LootScale'
			sc.Scale = ls
			sc.Parent = content
		end

		local amtLabel = billboard:FindFirstChild('Amt', true)
		if amtLabel then
			local src = lootHandle:GetAttribute('Amount') ~= nil and lootHandle or lootHandle.Parent
			if src then
				local conn = src:GetAttributeChangedSignal('Amount'):Connect(function()
					if amtLabel.Parent then
						amtLabel.Text = tostring(getDropAmount(lootHandle))
					end
				end)
				billboard.AncestryChanged:Connect(function()
					if not billboard.Parent then conn:Disconnect() end
				end)
			end
		end
		
		Reference[lootHandle] = billboard
	end
	
	local function Removed(lootHandle)
		if Reference[lootHandle] then
			Reference[lootHandle]:Destroy()
			Reference[lootHandle] = nil
		end
	end
	
	local function findExistingLoot()
		local tagged = CollectionService:GetTagged('ItemDrop')
		for _, drop in ipairs(tagged) do
			local handle = drop:FindFirstChild('Handle')
			if handle then
				local lootType, config = getLootType(drop.Name)
				if lootType and isLootEnabled(lootType) then
					if not Reference[handle] then
						Added(handle, lootType, config)
					end
				end
			end
		end
	end
	
	local function refreshLootType(lootType)
		if not LootESP.Enabled then return end
		
		local enabled = isLootEnabled(lootType)
		
		if not (GeneratorToggle and GeneratorToggle.Enabled) then
			for handle, billboard in pairs(Reference) do
				if isGeneratorDrop(handle) then
					billboard:Destroy()
					Reference[handle] = nil
				end
			end
		end
		
		if not enabled then
			for handle, billboard in pairs(Reference) do
				if billboard.Name == lootType then
					billboard:Destroy()
					Reference[handle] = nil
				end
			end
		else
			local tagged = CollectionService:GetTagged('ItemDrop')
			for _, drop in ipairs(tagged) do
				local handle = drop:FindFirstChild('Handle')
				if handle then
					local dropLootType, config = getLootType(drop.Name)
					if dropLootType == lootType and not Reference[handle] then
						Added(handle, lootType, config)
					end
				end
			end
		end
	end
	
	LootESP = vape.Categories.Render:CreateModule({
		Name = 'LootESP',
		Function = function(callback)
			if callback then
				findExistingLoot()
				
				LootESP:Clean(CollectionService:GetInstanceAddedSignal('ItemDrop'):Connect(function(drop)
					if not LootESP.Enabled then return end
					
					task.defer(function()
						local handle = drop:FindFirstChild('Handle')
						if not handle then return end
						
						local lootType, config = getLootType(drop.Name)
						if lootType and isLootEnabled(lootType) then
							Added(handle, lootType, config)
						end
					end)
				end))
				
				LootESP:Clean(CollectionService:GetInstanceRemovedSignal('ItemDrop'):Connect(function(drop)
					local handle = drop:FindFirstChild('Handle')
					if handle then
						Removed(handle)
					end
				end))
				
			else
				for handle, billboard in pairs(Reference) do
					billboard:Destroy()
				end
				table.clear(Reference)
			end
		end,
		Tooltip = 'esp for loot (iron, emerald, diamonds)'
	})
	
	IronToggle = LootESP:CreateToggle({
		Name = 'Iron',
		Function = function(callback)
			refreshLootType('iron')
		end,
		Default = true
	})
	
	DiamondToggle = LootESP:CreateToggle({
		Name = 'Diamond',
		Function = function(callback)
			refreshLootType('diamond')
		end,
		Default = true
	})
	
	EmeraldToggle = LootESP:CreateToggle({
		Name = 'Emerald',
		Function = function(callback)
			refreshLootType('emerald')
		end,
		Default = true
	})
	
	GeneratorToggle = LootESP:CreateToggle({
		Name = 'Generators',
		Function = function(callback)
			if not LootESP.Enabled then return end
			refreshLootType('iron')
			refreshLootType('diamond')
			refreshLootType('emerald')
		end,
		Tooltip = 'off = loot sittin on a gen gets hidden, only shows stuff ppl dropped. flip it on if u wanna see gen loot too gng'
	})

	local function applyLootScale()
		local val = (ScaleToggle and ScaleToggle.Enabled and ScaleSlider) and ScaleSlider.Value or 1
		for _, billboard in pairs(Reference) do
			billboard.Size = UDim2.fromOffset(40 * val, 40 * val)
			local sc = billboard:FindFirstChild('LootScale', true)
			if sc then sc.Scale = val end
		end
	end

	ScaleToggle = LootESP:CreateToggle({
		Name = 'Custom Scale',
		Function = function(callback)
			if ScaleSlider then ScaleSlider.Object.Visible = callback end
			applyLootScale()
		end,
		Tooltip = 'turn on to pick ur own size for the loot icons'
	})

	ScaleSlider = LootESP:CreateSlider({
		Name = 'Scale',
		Min = 0.5,
		Max = 3,
		Default = 1,
		Decimal = 10,
		Darker = true,
		Visible = false,
		Function = function()
			applyLootScale()
		end,
		Tooltip = 'makes the loot icons bigger or smaller gng'
	})
end)

run(function()
	local StorageESP
	local List
	local Background
	local Color = {}
	local Reference = {}
	local ChestContents = {} 
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function getEnabledItemsSet()
		local set = {}
		for _, v in ipairs(List.ListEnabled) do
			set[v] = true
		end
		return set
	end
	
	local function nearStorageItem(item, enabledSet)
		for itemName in pairs(enabledSet) do
			if item:find(itemName, 1, true) then return itemName end
		end
		return nil
	end
	
	local function refreshAdornee(billboard)
		local chestPart = billboard.Adornee
		local folderValue = chestPart and chestPart:FindFirstChild('ChestFolderValue')
		local chest = folderValue and folderValue.Value or nil

		for _, obj in ipairs(billboard:GetChildren()) do
			if obj:IsA('ImageLabel') and obj.Name == 'Icon' then
				obj:Destroy()
			end
		end

		if not chest then
			billboard.Enabled = false
			return
		end

		local chestitems = chest:GetChildren()
		local enabledSet = getEnabledItemsSet()
		local listIsEmpty = next(enabledSet) == nil

		local matchedItems = {}
		local amounts = {}
		for _, item in ipairs(chestitems) do
			if item:IsA('Accessory') then
				if listIsEmpty or enabledSet[item.Name] or nearStorageItem(item.Name, enabledSet) then
					if amounts[item.Name] == nil then
						amounts[item.Name] = 0
						table.insert(matchedItems, item.Name)
					end
					amounts[item.Name] = amounts[item.Name] + (item:GetAttribute('Amount') or 1)
				end
			end
		end

		local count = #matchedItems
		if count == 0 then
			billboard.Enabled = false
			return
		end

		billboard.Enabled = true
		local iconSize = 36
		local padding = 2
		local totalWidth = count * iconSize + (count - 1) * padding
		billboard.Size = UDim2.fromOffset(totalWidth, iconSize)

		for i, itemName in ipairs(matchedItems) do
			local icon = Instance.new('ImageLabel')
			icon.Name = 'Icon'
			icon.Size = UDim2.fromOffset(iconSize, iconSize)
			icon.Position = UDim2.fromOffset((i - 1) * (iconSize + padding), 0)
			icon.AnchorPoint = Vector2.new(0, 0)
			icon.BackgroundColor3 = Color3.new(0, 0, 0)
			icon.BackgroundTransparency = 0.3
			icon.BorderSizePixel = 0
			icon.Image = bedwars.getIcon({itemType = itemName}, true)
			icon.Parent = billboard

			local uicorner = Instance.new('UICorner')
			uicorner.CornerRadius = UDim.new(0, 4)
			uicorner.Parent = icon

			local amt = Instance.new('TextLabel')
			amt.Name = 'Amt'
			amt.AnchorPoint = Vector2.new(1, 1)
			amt.Position = UDim2.new(1, -1, 1, -1)
			amt.Size = UDim2.fromOffset(iconSize, 14)
			amt.BackgroundTransparency = 1
			amt.Text = tostring(amounts[itemName] or 0)
			amt.TextColor3 = Color3.fromRGB(255, 255, 255)
			amt.TextStrokeTransparency = 0.4
			amt.TextSize = 13
			amt.Font = Enum.Font.GothamBold
			amt.TextXAlignment = Enum.TextXAlignment.Right
			amt.TextYAlignment = Enum.TextYAlignment.Bottom
			amt.Parent = icon
		end
	end
	
	local function Added(v)
		if Reference[v] then return end

		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'chest'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		billboard.Enabled = false

		local blur = addBlur(billboard)

		Reference[v] = billboard

		refreshAdornee(billboard)

		task.defer(function()
			local folderValue = v:FindFirstChild('ChestFolderValue')
			local chest = folderValue and folderValue.Value or nil
			if chest and Reference[v] then
				local conn1 = chest.ChildAdded:Connect(function()
					if Reference[v] then refreshAdornee(Reference[v]) end
				end)
				local conn2 = chest.ChildRemoved:Connect(function()
					if Reference[v] then refreshAdornee(Reference[v]) end
				end)
				billboard.AncestryChanged:Connect(function()
					conn1:Disconnect()
					conn2:Disconnect()
				end)
			end
		end)
	end
	
	local function Removed(v)
		if Reference[v] then
			Reference[v]:Destroy()
			Reference[v] = nil
			ChestContents[v] = nil
		end
	end
	
	StorageESP = vape.Categories.Render:CreateModule({
		Name = 'StorageESP',
		Function = function(callback)
			if callback then
				local tagged = collectionService:GetTagged('chest')
				for _, v in ipairs(tagged) do
					Added(v)
				end
				
				StorageESP:Clean(collectionService:GetInstanceAddedSignal('chest'):Connect(Added))
				StorageESP:Clean(collectionService:GetInstanceRemovedSignal('chest'):Connect(Removed))
				cleanThread(StorageESP, task.spawn(function()
					while StorageESP.Enabled do
						task.wait(0.5)
						if not StorageESP.Enabled then break end
						for chest, billboard in pairs(Reference) do
							if not chest or not chest.Parent then
								Removed(chest)
							else
								refreshAdornee(billboard)
							end
						end
					end
				end))
			else
				for chest in pairs(Reference) do
					Removed(chest)
				end
			end
		end,
		Tooltip = 'shows what items are in a chest'
	})
	
	List = StorageESP:CreateTextList({
		Name = 'Item',
		Function = function()
			table.clear(ChestContents)
			for _, v in pairs(Reference) do
				refreshAdornee(v)
			end
		end
	})
	
	Background = StorageESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then Color.Object.Visible = callback end
			for _, v in pairs(Reference) do
				local icon = v:FindFirstChild('Icon')
				if icon then
					icon.BackgroundTransparency = callback and 0.3 or 1
				end
			end
		end,
		Default = true
	})
	
    Color = StorageESP:CreateColorSlider({
        Name = 'Background Color',
        DefaultValue = 0,
        DefaultOpacity = 0.5,
        Function = function(hue, sat, val, opacity)
            for _, v in pairs(Reference) do
                v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                v.Frame.BackgroundTransparency = 1 - opacity
            end
        end,
        Darker = true
    })

    task.defer(function()
        if Color and Color.Object then
            Color.Object.Visible = Background.Enabled  
        end
    end)
end)

run(function()
	local TrapESP
	local Background = {}
	local Color = {}
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui

	local function Added(v, icon)
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = icon
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v:IsA('Model') and (v.PrimaryPart or v:FindFirstChildWhichIsA('BasePart')) or v
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local image = Instance.new('ImageLabel')
		image.Size = UDim2.fromOffset(36, 36)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		image.BorderSizePixel = 0
		local result = bedwars.getIcon({itemType = icon}, true)
		image.Image = result		
		image.Image = result
		image.Parent = billboard
		local uicorner = Instance.new('UICorner')
		uicorner.CornerRadius = UDim.new(0, 4)
		uicorner.Parent = image
		Reference[v] = billboard
	end
	


	TrapESP = vape.Categories.Render:CreateModule({
		Name = 'TrapESP',
		Function = function(callback)
			if callback then
				TrapESP:Clean(collectionService:GetInstanceAddedSignal('snap_trap'):Connect(function(v)
					if tostring(v:GetAttribute("SnapTrapTeamId")) == lplr.Team.Name then
						return
					end
					Added(v, 'snap_trap')
				end))
				TrapESP:Clean(collectionService:GetInstanceRemovedSignal('snap_trap'):Connect(function(v)
					if tostring(v:GetAttribute("SnapTrapTeamId")) == lplr.Team.Name then
						return
					end
					if Reference[v] then
						Reference[v]:Destroy()
						Reference[v] = nil
					end
				end))
				for _, v in collectionService:GetTagged('snap_trap') do
					if tostring(v:GetAttribute("SnapTrapTeamId")) == lplr.Team.Name then
						return
					end
					Added(v, 'snap_trap')
				end
			else
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'allows you to see invisible traps'
	})
	Background = TrapESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then Color.Object.Visible = callback end
			for _, v in Reference do
				v.ImageLabel.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true,
				Visible = true
	})
	Color = TrapESP:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in Reference do
				v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.ImageLabel.BackgroundTransparency = 1 - opacity
			end
		end,
		Darker = true
	})
end)

run(function()
	local StreamerMode
	local NameBox
	local restored = setmetatable({}, {__mode = 'k'})
	local hooked = setmetatable({}, {__mode = 'k'})
	local textClasses = {TextLabel = true, TextButton = true, TextBox = true}
	local needles = {}
	local minLength = math.huge
	local alias = 'hidden'
	local writing
	local playerClass
	local savedUsername, savedDisplay, savedTag, savedLevel
	local queued = false

	local function readAlias()
		local value = NameBox and NameBox.Value
		if type(value) == 'string' and value ~= '' then
			return value
		end
		return 'hidden'
	end

	local function buildNeedles()
		table.clear(needles)
		minLength = math.huge
		local seen = {}
		for _, name in {lplr.Name, lplr.DisplayName} do
			if type(name) == 'string' and name ~= '' and not seen[name] then
				seen[name] = true
				minLength = math.min(minLength, #name)
				table.insert(needles, {
					plain = name:lower(),
					forms = {name, name:lower(), name:upper()}
				})
			end
		end
	end

	local function maskText(text)
		local out = text
		for _, needle in needles do
			for _, form in needle.forms do
				if form ~= '' and out:find(form, 1, true) then
					out = out:gsub((form:gsub('%W', '%%%0')), alias)
				end
			end
		end
		return out
	end

	local function keepText(object, value)
		writing = object
		object.Text = value
		writing = nil
	end

	local function watchText(object, apply)
		if hooked[object] then return end
		hooked[object] = object:GetPropertyChangedSignal('Text'):Connect(apply)
	end

	local function nearbyName(object)
		local parent = object.Parent
		for _ = 1, 3 do
			if not parent then return nil end
			local label = parent:FindFirstChild('PlayerName', true)
			if label then return label end
			parent = parent.Parent
		end
		return nil
	end

	local function blankLevel(object)
		if writing == object or not textClasses[object.ClassName] then return end
		if not object.Name:lower():find('level', 1, true) then return end
		local owner = nearbyName(object)
		if not owner or not owner.Text:find(alias, 1, true) then return end

		local function apply()
			if writing == object or not object.Parent then return end
			local text = object.Text
			if type(text) ~= 'string' or text == '' then return end
			if restored[object] == nil then
				restored[object] = text
			end
			keepText(object, '')
		end

		apply()
		watchText(object, apply)
	end

	local function sweepLevels(object)
		if not object then return end
		for _, child in object:GetDescendants() do
			blankLevel(child)
		end
	end

	local function maskObject(object)
		if not textClasses[object.ClassName] then return end

		local function apply()
			if writing == object or not object.Parent then return end
			local text = object.Text
			if type(text) ~= 'string' or #text < minLength then return end

			local lower = text:lower()
			local found = false
			for _, needle in needles do
				if lower:find(needle.plain, 1, true) then
					found = true
					break
				end
			end
			if not found then return end

			local masked = maskText(text)
			if masked == text then return end

			if restored[object] == nil then
				restored[object] = text
			end
			keepText(object, masked)
			watchText(object, apply)
			sweepLevels(object.Parent)
		end

		apply()
	end

	local function sweep(root)
		if not root then return end
		if vape.ThreadFix and setthreadidentity then
			pcall(setthreadidentity, 8)
		end

		StreamerMode:Clean(root.DescendantAdded:Connect(function(object)
			if not StreamerMode.Enabled then return end
			maskObject(object)
			blankLevel(object)
		end))

		local clock = os.clock()
		for _, object in root:GetDescendants() do
			maskObject(object)
			blankLevel(object)
			if os.clock() - clock > 0.002 then
				task.wait()
				if not StreamerMode.Enabled then return end
				clock = os.clock()
				if vape.ThreadFix and setthreadidentity then
					pcall(setthreadidentity, 8)
				end
			end
		end
	end

	local function findPlayerClass()
		if playerClass then return playerClass end
		pcall(function()
			local util = bedwars.GamePlayerUtil
			if not util then
				for _, module in replicatedStorage.TS:GetDescendants() do
					if module:IsA('ModuleScript') and module.Name:lower():find('game%-player%-util') then
						local ok, res = pcall(require, module)
						if ok and type(res) == 'table' and type(res.GamePlayerUtil) == 'table' then
							util = res.GamePlayerUtil
							break
						end
					end
				end
			end
			local holder = util and util.getGamePlayer and util.getGamePlayer(lplr)
			local meta = holder and getmetatable(holder)
			playerClass = meta and meta.__index or nil
		end)
		return playerClass
	end

	local function isMe(holder)
		local ok, player = pcall(function()
			return holder:getPlayer()
		end)
		return ok and player ~= nil and player.UserId == lplr.UserId
	end

	local function hookClass()
		local class = findPlayerClass()
		if not class or savedUsername then return end

		savedUsername, savedDisplay = class.getUsername, class.getDisplayName
		savedTag, savedLevel = class.getClanTag, class.getLevel

		class.getUsername = function(self, ...)
			return isMe(self) and alias or savedUsername(self, ...)
		end
		class.getDisplayName = function(self, ...)
			return isMe(self) and alias or savedDisplay(self, ...)
		end
		class.getClanTag = function(self, ...)
			return isMe(self) and '' or savedTag(self, ...)
		end
		class.getLevel = function(self, ...)
			return isMe(self) and -1 or savedLevel(self, ...)
		end
	end

	local function unhookClass()
		local class = playerClass
		if not class or not savedUsername then return end
		class.getUsername, class.getDisplayName = savedUsername, savedDisplay
		class.getClanTag, class.getLevel = savedTag, savedLevel
		savedUsername, savedDisplay, savedTag, savedLevel = nil, nil, nil, nil
	end

	local function reload()
		if queued or not StreamerMode or not StreamerMode.Enabled then return end
		queued = true
		task.delay(0.3, function()
			queued = false
			if StreamerMode.Enabled then
				StreamerMode:Toggle()
				StreamerMode:Toggle()
			end
		end)
	end

	StreamerMode = vape.Categories.Render:CreateModule({
		Name = 'StreamerMode',
		Function = function(callback)
			if callback then
				buildNeedles()
				alias = readAlias()
				for _, needle in needles do
					for _, form in needle.forms do
						if form ~= '' and alias:find(form, 1, true) then
							alias = 'hidden'
						end
					end
				end

				hookClass()

				for _, root in {lplr:FindFirstChildOfClass('PlayerGui'), coreGui, gethui and gethui() or nil, lplr.Character} do
					sweep(root)
				end

				StreamerMode:Clean(lplr.CharacterAdded:Connect(function(char)
					if StreamerMode.Enabled then
						sweep(char)
					end
				end))
			else
				unhookClass()

				if vape.ThreadFix and setthreadidentity then
					pcall(setthreadidentity, 8)
				end

				for object, conn in hooked do
					pcall(function()
						conn:Disconnect()
					end)
				end
				table.clear(hooked)

				for object, text in restored do
					if object.Parent then
						keepText(object, text)
					end
				end
				writing = nil
				table.clear(restored)
			end
		end,
		Tooltip = 'changes ur name everywhere on ur screen so u can screenshare and etc without leaking it',
		ExtraText = function()
			return readAlias()
		end
	})

	NameBox = StreamerMode:CreateTextBox({
		Name = 'name',
		Default = 'zenwear',
		Placeholder = 'type a name...',
		Function = reload
	})
end)

run(function()
	local ArmorTrims
	local TrimType
	local TrimEffect
	local TrimRank
	local TrimColor

	local RS = game:GetService('ReplicatedStorage')
	local ANCHORS = {
		boots_left_trim = 'LeftFoot',
		boots_right_trim = 'RightFoot',
		chestplate_left_shoulder_trim = 'LeftUpperArm',
		chestplate_right_shoulder_trim = 'RightUpperArm',
		chestplate_trim = 'UpperTorso',
		chestplate_lower_trim = 'LowerTorso',
		helmet_trim = 'Head'
	}
	local EFFECTS = {'default', 'void', 'spirit', 'phoenix', 'bat', 'anniversary', 'frosty', 'fire_warm', 'fire_cold', 'fire_red', 'fire_black', 'fire_purple'}
	local RANKS = {'T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'}
	local COLORS = {'RED', 'ORANGE', 'YELLOW', 'GREEN', 'BLUE', 'INDIGO', 'PURPLE', 'WHITE', 'BLACK', 'BROWN', 'PINK'}
	local TRIMS = {}
	for i = 1, 12 do TRIMS[i] = 'trim_' .. i end

	local spawned = {}
	local cache = {}
	local controller = nil
	local applyToken = 0

	local function cached(path, key)
		local id = path .. '|' .. tostring(key)
		local hit = cache[id]
		if hit ~= nil then
			return hit ~= false and hit or nil
		end
		local ok, mod = pcall(function()
			return require(RS.TS['armor-trim'][path])
		end)
		local value = nil
		if ok and type(mod) == 'table' then
			value = key and mod[key] or mod
		end
		cache[id] = value == nil and false or value
		return value
	end

	local function colorIndex()
		local m = cached('armor-trim-colors', 'ArmorTrimColor')
		return m and m[TrimColor.Value] or 0
	end

	local function rankIndex()
		local m = cached('armor-trim-rank', 'ArmorTrimEffectRank')
		return m and m[TrimRank.Value] or 0
	end

	local function colorValue()
		local m = cached('armor-trim-color-meta', 'ArmorTrimColorMeta')
		local entry = m and m[colorIndex()]
		return entry and entry.color or Color3.new(1, 1, 1)
	end

	local function rankMaterial()
		local m = cached('armor-trim-rank', 'ArmorTrimEffectRankMeta')
		local entry = m and m[rankIndex()]
		return entry and entry.material or Enum.Material.Plastic
	end

	local function getController()
		if controller then return controller end
		local ok, Knit = pcall(function()
			return require(RS.rbxts_include.node_modules['@easy-games'].knit.src).KnitClient
		end)
		if ok and Knit then
			controller = Knit.Controllers.ArmorTrimController
		end
		return controller
	end

	local function clearAccessories()
		for _, acc in spawned do
			pcall(function() acc:Destroy() end)
		end
		table.clear(spawned)
	end

	local function setAttributes()
		local char = lplr.Character
		local trim, effect, rank, color = TrimType.Value, TrimEffect.Value, rankIndex(), colorIndex()
		for _, target in {lplr, char} do
			if target then
				pcall(function()
					target:SetAttribute('ArmorTrimType', trim)
					target:SetAttribute('ArmorTrimEffectType', effect)
					target:SetAttribute('ArmorTrimEffectRank', rank)
					target:SetAttribute('ArmorTrimColor', color)
				end)
			end
		end
	end

	local function refreshEffects()
		local char = lplr.Character
		local ctrl = getController()
		if not char or not ctrl then return end
		for _, acc in char:GetChildren() do
			if acc:IsA('Accessory') and ANCHORS[acc.Name] then
				if not pcall(function() ctrl:attachArmorTrim(lplr, acc) end) then
					pcall(function() ctrl:attachArmorTrim(acc, lplr) end)
				end
			end
		end
	end

	local function spawnAccessories()
		clearAccessories()
		local char = lplr.Character
		local hum = char and char:FindFirstChildOfClass('Humanoid')
		if not hum then return end
		local folder = RS:FindFirstChild('Assets')
		folder = folder and folder:FindFirstChild('ArmorTrims')
		folder = folder and folder:FindFirstChild(TrimType.Value)
		if not folder then return end

		local col = colorValue()
		local mat = rankMaterial()

		local owned = {}
		for _, existing in char:GetChildren() do
			if existing:IsA('Accessory') and ANCHORS[existing.Name] then
				owned[existing.Name] = true
			end
		end

		for _, acc in folder:GetChildren() do
			if acc:IsA('Accessory') and ANCHORS[acc.Name] and not owned[acc.Name] then
				local clone = acc:Clone()
				for _, d in clone:GetDescendants() do
					if d:IsA('BasePart') then
						d.Color = col
						d.Material = mat
						d.CanCollide = false
						d.CanQuery = false
						d.CanTouch = false
						d.Massless = true
					elseif d:IsA('TouchTransmitter') then
						pcall(function() d:Destroy() end)
					end
				end
				if not pcall(function() hum:AddAccessory(clone) end) then
					local handle = clone:FindFirstChild('Handle')
					local anchor = char:FindFirstChild(ANCHORS[acc.Name])
					if handle and anchor then
						handle.CFrame = anchor.CFrame
						local weld = Instance.new('WeldConstraint')
						weld.Part0 = anchor
						weld.Part1 = handle
						weld.Parent = handle
						clone.Parent = char
					else
						clone:Destroy()
						clone = nil
					end
				end
				if clone then
					table.insert(spawned, clone)
				end
			end
		end
	end

	local function applyAll()
		if not (ArmorTrims and ArmorTrims.Enabled) then return end
		applyToken = applyToken + 1
		local token = applyToken
		task.spawn(function()
			task.wait(0.1)
			if token ~= applyToken then return end
			if not ArmorTrims.Enabled then return end
			setAttributes()
			spawnAccessories()
			refreshEffects()
		end)
	end

	ArmorTrims = vape.Categories.Render:CreateModule({
		Name = 'ArmorTrims',
		Function = function(callback)
			if callback then
				applyAll()
				ArmorTrims:Clean(lplr.CharacterAdded:Connect(function(char)
					task.spawn(function()
						char:WaitForChild('Humanoid', 10)
						task.wait(1)
						if ArmorTrims.Enabled then applyAll() end
					end)
				end))
				ArmorTrims:Clean(clearAccessories)
			else
				applyToken = applyToken + 1
				clearAccessories()
				local char = lplr.Character
				for _, target in {lplr, char} do
					if target then
						pcall(function()
							target:SetAttribute('ArmorTrimEffectType', nil)
							target:SetAttribute('ArmorTrimEffectRank', nil)
						end)
					end
				end
			end
		end,
		Tooltip = 'gives ur armor a trim with effects, only u can see it'
	})

	vape:Clean(clearAccessories)

	TrimType = ArmorTrims:CreateDropdown({
		Name = 'Trim Type',
		List = TRIMS,
		Default = 'trim_1',
		Function = function() applyAll() end
	})
	TrimEffect = ArmorTrims:CreateDropdown({
		Name = 'Effect',
		List = EFFECTS,
		Default = 'void',
		Function = function() applyAll() end,
		Tooltip = 'the particles on ur trim'
	})
	TrimRank = ArmorTrims:CreateDropdown({
		Name = 'Rank',
		List = RANKS,
		Default = 'T7',
		Function = function() applyAll() end,
		Tooltip = 'higher tier looks crazier, T7 is neon'
	})
	TrimColor = ArmorTrims:CreateDropdown({
		Name = 'Color',
		List = COLORS,
		Default = 'RED',
		Function = function() applyAll() end
	})
end)

run(function()
    local BlockSelectorColor
    local Fill
    local Outline
    local RunService = game:GetService("RunService")
    local updateConnection
    local boxes = {}

    local function applyBox(box)
        box.Color3 = Color3.fromHSV(Outline.Hue, Outline.Sat, Outline.Value)
        box.Transparency = 1 - Outline.Opacity
        box.SurfaceColor3 = Color3.fromHSV(Fill.Hue, Fill.Sat, Fill.Value)
        box.SurfaceTransparency = 1 - Fill.Opacity
    end

    local function UpdateAllBoxes()
        for box in pairs(boxes) do
            if box.Parent then
                applyBox(box)
            else
                boxes[box] = nil
            end
        end
    end

    BlockSelectorColor = vape.Categories.Render:CreateModule({
        Name = 'BlockSelectorColor',
        Function = function(callback)
            if callback then
                table.clear(boxes)
                scanDescendants(workspace, function(box)
                    if box:IsA("SelectionBox") then
                        boxes[box] = true
                    end
                end, BlockSelectorColor)
                BlockSelectorColor:Clean(workspace.DescendantAdded:Connect(function(v)
                    if v:IsA("SelectionBox") then
                        boxes[v] = true
                        applyBox(v)
                    end
                end))
                BlockSelectorColor:Clean(workspace.DescendantRemoving:Connect(function(v)
                    if v:IsA("SelectionBox") then
                        boxes[v] = nil
                    end
                end))
                updateConnection = RunService.RenderStepped:Connect(UpdateAllBoxes)
            else
                if updateConnection then
                    updateConnection:Disconnect()
                    updateConnection = nil
                end
                table.clear(boxes)
            end
        end,
        Tooltip = 'change your block placement outline color'
    })

    Fill = BlockSelectorColor:CreateColorSlider({
        Name = 'Overlay Color',
        DefaultOpacity = 0.5
    })
    Outline = BlockSelectorColor:CreateColorSlider({
        Name = 'Outline Color',
        DefaultOpacity = 1
    })
end)

run(function()
	local NameTags
	local StreamProof
	local Targets
	local Color
	local Background
	local DisplayName
	local Health
	local HealthColorToggle
	local HealthColorFull
	local HealthColorMid
	local HealthColorLow
	local Distance
	local Equipment
	local Loot
	local Potions
	local potionDefs = {
		{name = 'PotSerpent', attr = 'StatusEffect_serpents_touch_potion', item = 'serpents_touch_potion', timed = true},
		{name = 'PotFury', attr = 'StatusEffect_fury_potion', item = 'fury_potion', timed = true},
		{name = 'PotInvis', attr = 'StatusEffect_invisibility', item = 'invisibility_potion', timed = true},
		{name = 'PotJump', attr = 'JumpBoost', item = 'jump_potion', timed = false},
		{name = 'PotPie', attr = 'SpeedPieBuff', item = 'speed_pie', timed = false}
	}
	local function potionActive(char, def)
		if not char then return false end
		local val = char:GetAttribute(def.attr)
		if val == nil then return false end
		if def.timed then
			return type(val) == 'number' and val > workspace:GetServerTimeNow()
		end
		return val ~= false and val ~= 0
	end
	local Boss
	local ShowKits
	local KitTracker
	local Rank
	local DeviceIcon
	local GloopIndicator
	local Enchant
	local Scale
	local FontOption
	local Teammates
	local DistanceCheck
	local DistanceLimit
	local Strings, Sizes, Reference = {}, {}, {}
	local bossNametags = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local methodused
	local Removed
	local lastUpdate = {}
	local kitCache = {}
	local lootCache = {}
	local equipmentCache = {}
	local enchantCache = {}
	local healthCache = {}
	local charCache = {}
	local enchantConnections = {}
	local gloopConnections = {}
	local kitTrackerConnections = {}
	local billboardCache = {}
	local tick = tick
	local math_floor = math.floor
	local math_round = math.round
	local math_clamp = math.clamp
	local math_huge = math.huge
	local string_format = string.format
	local vector2new = Vector2.new
	local vector3new = Vector3.new
	local color3fromHSV = Color3.fromHSV
	local color3new = Color3.new
	
	local function getTeamColor(ent)
		local plr = ent and ent.Player
		if not plr then return nil end
		local theirTeam = tonumber(plr:GetAttribute('Team'))
		if not theirTeam then return nil end
		local myTeam = tonumber(lplr:GetAttribute('Team'))
		if myTeam and myTeam == theirTeam then return nil end
		local entry = getgenv().aeroTeamColors[theirTeam]
		return entry and entry.color
	end
	local udim2fromOffset = UDim2.fromOffset

	local function getChainsawImage(level)
		if not level or level < 1 or level > 5 then return '' end
		local success, img = pcall(function()
			local imageModule = require(game:GetService("ReplicatedStorage"):WaitForChild("TS"):WaitForChild("image"):WaitForChild("image-id"))
			local ids = {
				[1] = imageModule.BedwarsImageId.WOOD_TINKER_MECH,
				[2] = imageModule.BedwarsImageId.IRON_TINKER_MECH,
				[3] = imageModule.BedwarsImageId.DIAMOND_TINKER_MECH,
				[4] = imageModule.BedwarsImageId.EMERALD_TINKER_MECH,
				[5] = imageModule.BedwarsImageId.VOID_TINKER_MECH,
			}
			return ids[level]
		end)
		if success and img then
			return img
		end
		local fallback = {
			[1] = "rbxassetid://1234567890", 
			[2] = "rbxassetid://1234567891", 
			[3] = "rbxassetid://1234567892", 
			[4] = "rbxassetid://1234567893", 
			[5] = "rbxassetid://1234567894", 
		}
		return fallback[level] or ''
	end

	local function splitHealth(ent)
		local shield = ent.Character and getShieldAttribute(ent.Character) or 0
		return math.round((ent.Health or 0) - shield), math.round(shield)
	end

	local function getHealthColor(ent)
		local hp = splitHealth(ent)
		local ratio = math.clamp(hp / (ent.MaxHealth and ent.MaxHealth > 0 and ent.MaxHealth or 1), 0, 1)
		if HealthColorToggle and HealthColorToggle.Enabled then
			local fullC = Color3.fromHSV(HealthColorFull.Hue, HealthColorFull.Sat, HealthColorFull.Value)
			local midC  = Color3.fromHSV(HealthColorMid.Hue,  HealthColorMid.Sat,  HealthColorMid.Value)
			local lowC  = Color3.fromHSV(HealthColorLow.Hue,  HealthColorLow.Sat,  HealthColorLow.Value)
			if ratio >= 0.5 then
				return fullC:Lerp(midC, (1 - ratio) / 0.5)
			else
				return midC:Lerp(lowC, (0.5 - ratio) / 0.5)
			end
		else
			if ratio >= 0.7 then
				return Color3.fromRGB(0, 255, 0)
			elseif ratio >= 0.3 then
				return Color3.fromRGB(255, 255, 0)
			elseif ratio >= 0.1 then
				return Color3.fromRGB(255, 165, 0)
			else
				return Color3.fromRGB(255, 0, 0)
			end
		end
	end

	local function getHealthColorStr(ent)
		local c = getHealthColor(ent)
		return 'rgb('..math.floor(c.R*255)..','..math.floor(c.G*255)..','..math.floor(c.B*255)..')'
	end

	local function healthRich(ent)
		local hp, shield = splitHealth(ent)
		local text = '<font color="'..getHealthColorStr(ent)..'">'..hp..'</font>'
		if shield > 0 then
			text = text..' <font color="rgb(255,255,255)">'..shield..'</font>'
		end
		return text
	end

	local function healthPlain(ent)
		local hp, shield = splitHealth(ent)
		return shield > 0 and (hp..' +'..shield) or tostring(hp)
	end

	local enchantImageMap = nil
	local function buildEnchantMap()
		if enchantImageMap then return enchantImageMap end
		enchantImageMap = {}
		task.spawn(function()
			if vape.ThreadFix then setthreadidentity(8) end
			local ok, meta = pcall(function()
				return require(game:GetService('ReplicatedStorage').TS.enchant['enchant-meta'])
			end)
			if not ok or not meta then return end
			for _, subMeta in pairs({meta.EnchantMeta, meta.ToolEnchantMeta, meta.ArmorEnchantMeta}) do
				if type(subMeta) == 'table' then
					for _, v in pairs(subMeta) do
						if type(v) == 'table' and v.statusEffect and v.image then
							enchantImageMap[v.statusEffect] = v.image
						end
					end
				end
			end
		end)
		return enchantImageMap
	end

	local function getActiveEnchantImage(char)
		if not char then return '' end
		local map = buildEnchantMap()
		for attr, val in pairs(char:GetAttributes()) do
			if attr:sub(1, 13) == 'StatusEffect_' and type(val) == 'number' and val < 0 then
				local effectName = attr:sub(14)
				if not effectName:find('stacks') then
					local img = map[effectName]
					if img and img ~= '' then return img end
				end
			end
		end
		return ''
	end

	local function getBossDisplayName(ent)
		if not ent.NPC or not ent.Character then return nil end
		local char = ent.Character
		if char:GetAttribute("BossType") == "Bhaa" then
			return "Bhaa"
		end
		if char.Name:lower() == "bhaa" then
			return "Bhaa"
		end
		if char:FindFirstChild("BhaaModel") or char:FindFirstChild("BhaaHead") then
			return "Bhaa"
		end
		if char.Name == "Titan" then
			return "Titan"
		end
		return nil
	end

	local function shouldShow(ent)
		if not Targets.Players.Enabled and ent.Player then return false end
		local isBoss = ent.NPC and ent.Character and getBossDisplayName(ent) ~= nil
		if isBoss then
			if not Boss.Enabled then return false end
		else
			if not Targets.NPCs.Enabled and ent.NPC then return false end
			if Teammates.Enabled and (ent.Player and lplr:GetAttribute('Team') and ent.Player:GetAttribute('Team') == lplr:GetAttribute('Team')) and (not ent.Friend) then return false end
		end
		return true
	end

	local Added = {
		Normal = function(ent)
			if Reference[ent] then Removed.Normal(ent) end
			for oldEnt in Reference do
				if oldEnt ~= ent and (not oldEnt.Character or not oldEnt.Character.Parent or (oldEnt.Player and ent.Player and oldEnt.Player == ent.Player)) then
					Removed.Normal(oldEnt)
				end
			end
			if not Targets.Players.Enabled and ent.Player then return end
			local bossDisplayName = ent.NPC and ent.Character and getBossDisplayName(ent) or nil
			local isBoss = bossDisplayName ~= nil
			if isBoss then
				if not Boss.Enabled then return end
			else
				if not Targets.NPCs.Enabled and ent.NPC then return end
				if Teammates.Enabled and (ent.Player and lplr:GetAttribute('Team') and ent.Player:GetAttribute('Team') == lplr:GetAttribute('Team')) and (not ent.Friend) then return end
			end

			local entityName = bossDisplayName or (ent.Player and nil) or ent.Character.Name
			Strings[ent] = ent.Player and (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or entityName

			if Health.Enabled then
				Strings[ent] = Strings[ent]..' '..healthRich(ent)
			end

			if Distance.Enabled then
				Strings[ent] = '[%s] ' .. Strings[ent]
			end
			local textSize = 14 * Scale.Value
			local fontFace = FontOption.Value
			local size = getfontsize(removeTags(Strings[ent]), textSize, fontFace, vector2new(100000, 100000))
			local nametag = Instance.new('TextLabel')
			nametag.Name = ent.Player and ent.Player.Name or ent.Character.Name
			nametag.Size = udim2fromOffset(size.X + 8, size.Y + 7)
			nametag.AnchorPoint = vector2new(0.5, 1)
			nametag.BackgroundColor3 = color3new()
			nametag.BackgroundTransparency = Background.Value
			nametag.BorderSizePixel = 0
			nametag.Visible = false
			nametag.Text = Strings[ent]
			nametag.TextColor3 = getTeamColor(ent) or color3fromHSV(Color.Hue, Color.Sat, Color.Value)
			nametag.RichText = true
			nametag.TextSize = textSize
			nametag.FontFace = fontFace
			nametag.Parent = Folder

			if KitTracker and KitTracker.Enabled and ent.Player then
			  pcall(function()
				local vkRoman = {'I','II','III','IV','V'}
				local ktLabel = Instance.new('TextLabel')
				ktLabel.Name = 'KitTrackerLabel'
				ktLabel.BackgroundTransparency = 1
				ktLabel.TextScaled = false
				ktLabel.TextSize = 13
				ktLabel.FontFace = FontOption.Value
				ktLabel.RichText = true
				ktLabel.AnchorPoint = Vector2.new(1, 0.5)
				ktLabel.Position = UDim2.new(0, -2, 0.5, 0)
				ktLabel.Size = UDim2.new(0, 40, 1, 0)
				ktLabel.ZIndex = 2
				ktLabel.Parent = nametag

				local stroke = Instance.new('UIStroke')
				stroke.Color = Color3.new(0, 0, 0)
				stroke.Thickness = 1.5
				stroke.Parent = ktLabel

				local ktEventsBound = false
				local function updateKtLabel()
					if not KitTracker.Enabled then ktLabel.Text = '' return end
					local playerKit = ent.Player:GetAttribute('PlayingAsKits') or 'none'
					if playerKit == 'void_knight' then
						local tier = ent.Player:GetAttribute('VoidKnightTier') or 0
						if tier > 0 then
							ktLabel.Text = '【' .. (vkRoman[tier] or tostring(tier)) .. '】'
							ktLabel.TextColor3 = Color3.fromRGB(180, 80, 255)
						else
							ktLabel.Text = ''
						end
					elseif playerKit == 'block_kicker' then
						local char = ent.Character
						local count = (char and char:GetAttribute('BlockKickerKit_BlockCount')) or ent.Player:GetAttribute('BlockKickerKit_BlockCount') or 0
						ktLabel.Text = count > 0 and '【' .. tostring(count) .. '】' or ''
						ktLabel.TextColor3 = Color3.fromRGB(100, 210, 100)
					elseif playerKit == 'elk_master' then
						local char = ent.Character
						local isMounted = char and char:FindFirstChild('elk') ~= nil
						if isMounted then
							ktLabel.Text = '【🦌】'
							ktLabel.TextColor3 = Color3.fromRGB(160, 220, 80)
						else
							ktLabel.Text = ''
						end
					elseif playerKit == 'summoner' then
						local tier = ent.Player:GetAttribute("Summoner_ClawLevel") or 0
						if not tier or tier == 0 then ktLabel.Text = '' return end
						ktLabel.Text = '【 ' .. (vkRoman[tier] or tostring(tier)) .. ' 】'
						ktLabel.TextColor3 = Color3.fromRGB(191, 0, 255)
					elseif playerKit == 'paladin' then
						ktLabel.Text = '【 🪽 】'
						ktLabel.TextColor3 = Color3.fromRGB(255, 242, 150)
					elseif playerKit == 'davey' then
						local tier = ent.Character and ent.Character:GetAttribute('StatusEffect_powdered_stacks') or 0
						if tier > 0 then
							ktLabel.Text = '【 ' .. tostring(tier) .. ' 】'
						else
							ktLabel.Text = ''
						end
						ktLabel.TextColor3 = Color3.fromRGB(255, 105, 130)
					elseif playerKit == 'airbender' then
						ktLabel.Text = ''
						ktLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
						if not ktEventsBound then
							ktEventsBound = true
							if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
							task.spawn(function()
								table.insert(kitTrackerConnections[ent], bedwars.Client:Get("Airbender_UseTornadoFromServer"):Connect(function(p12)
									if not KitTracker.Enabled then ktLabel.Text = '' return end
									if p12.tornadoData.owner == ent.Player then
										ktLabel.Text = '【 🌪️ 】'
									end
								end))
								table.insert(kitTrackerConnections[ent], bedwars.Client:Get("Airbender_EndTornadoFromServer"):Connect(function(p13)
									if not KitTracker.Enabled then ktLabel.Text = '' return end
									if p13.tornadoData.owner == ent.Player then
										ktLabel.Text = ''
									end
								end))
							end)
						end
					elseif playerKit == 'hatter' then
						ktLabel.Text = ''
						ktLabel.TextColor3 = Color3.fromRGB(45, 15, 80)
						if not ktEventsBound then
							ktEventsBound = true
							if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
							task.spawn(function()
								if vape.ThreadFix then setthreadidentity(8) end
								table.insert(kitTrackerConnections[ent], bedwars.Client:OnEvent("HatterUseTeleport", function(p14)
									if vape.ThreadFix then setthreadidentity(8) end
									if not KitTracker.Enabled then ktLabel.Text = '' return end
									local dtc = p14.arriveTime - workspace:GetServerTimeNow() + 0.05
									if p14.hatterPlayer == ent.Player then
										ktLabel.Text = '【 🎩 】'
										task.wait(dtc)
										if vape.ThreadFix then setthreadidentity(8) end
										ktLabel.Text = ''
									else
										ktLabel.Text = ''
									end
								end))
							end)
						end
					elseif playerKit == 'black_market_trader' then
						ktLabel.Text = ''
						ktLabel.TextColor3 = Color3.fromRGB(30, 10, 60)
						if not ktEventsBound then
							ktEventsBound = true
							if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
							task.spawn(function()
								table.insert(kitTrackerConnections[ent], bedwars.Client:Get("BlackMarketPlaceShop"):Connect(function(p15)
									if not KitTracker.Enabled then ktLabel.Text = '' return end
									if p15.shopOwnerUserId == ent.Player.UserId then
										ktLabel.Text = '【 🏪 】'
									end
								end))
								local worldFolder = getWorldFolder()
								local blocks = worldFolder:WaitForChild("Blocks", math.huge)
								table.insert(kitTrackerConnections[ent], blocks.ChildAdded:Connect(function(obj)
									if obj.Name == 'black_market_shop' and obj:GetAttribute('PlacedByUserId') == ent.Player.UserId then
									local billboard = Instance.new('BillboardGui')
									billboard.Parent = obj
									billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
									billboard.Size = UDim2.fromOffset(36, 36)
									billboard.AlwaysOnTop = true
									billboard.ClipsDescendants = false
									local blur = addBlur(billboard)
									blur.Visible = Background.Enabled
									local image = Instance.new('ImageLabel')
									image.Size = UDim2.fromOffset(36, 36)
									image.Position = UDim2.fromScale(0.5, 0.5)
									image.AnchorPoint = Vector2.new(0.5, 0.5)
									image.BackgroundColor3 = Color3.fromHSV(0, 0, 0)
									image.BackgroundTransparency = 0.85
									image.BorderSizePixel = 0
									image.Image = bedwars.getIcon({itemType = 'shadow_coin'}, true)
									image.Parent = billboard
									local uicorner = Instance.new('UICorner')
									uicorner.CornerRadius = UDim.new(0, 4)
									uicorner.Parent = image
									if not billboardCache[ent] then billboardCache[ent] = {} end
									table.insert(billboardCache[ent], billboard)
									end
								end))
							end)
						end
					elseif playerKit == 'wizard' then
						ktLabel.TextColor3 = Color3.fromRGB(100, 70, 220)
						local function getStaffTier(v)
							local inv = store.inventories[v] and store.inventories[v].items or {}
							for _, item in inv do
								local nowstr = string.lower(item.itemType or '')
								if string.find(nowstr, 'wizard_staff') then
									return tonumber(item.itemType:sub(#item.itemType, #item.itemType)) or 1
								end
							end
						end
						local tier = getStaffTier(ent.Player)
						if not tier or tier < 0 then ktLabel.Text = '' return end
						ktLabel.Text = '【' .. (vkRoman[tier] or tostring(tier)) .. '】'
					elseif playerKit == 'aery' then
						ktLabel.TextColor3 = Color3.fromRGB(130, 210, 255)
						local stacks = ent.Player:GetAttribute('AeryStacks') or 0
						ktLabel.Text = '【' .. tostring(stacks) .. '】'
					elseif playerKit == 'mimic' then
						ktLabel.TextColor3 = Color3.fromRGB(180, 210, 60)
						ktLabel.Text = ''
						if not ktEventsBound then
							ktEventsBound = true
							if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
							task.spawn(function()
								if vape.ThreadFix then setthreadidentity(8) end
								table.insert(kitTrackerConnections[ent], bedwars.Client:OnEvent("ValidatedMimicBlock", function(p14)
									if not KitTracker.Enabled then ktLabel.Text = '' return end
									if vape.ThreadFix then setthreadidentity(8) end
									if p14.player == ent.Player then
										ktLabel.Text = '【 👔 】'
									else
										ktLabel.Text = ''
									end
								end))
								local val = workspace:FindFirstChild('DisguisedPlayerBlock_' .. ent.Player.UserId) ~= nil
								if val then ktLabel.Text = '【 👔 】' end
							end)
						end
					elseif playerKit == 'disruptor' then
						ktLabel.TextColor3 = Color3.fromRGB(40, 180, 140)
						if not ktEventsBound then
							ktEventsBound = true
							if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
							task.spawn(function()
								local worldFolder = getWorldFolder()
								local blocks = worldFolder:WaitForChild("Blocks", math.huge)
								table.insert(kitTrackerConnections[ent], blocks.ChildAdded:Connect(function(obj)
									if obj.Name == 'satellite_dish' and obj:GetAttribute('PlacedByUserId') == ent.Player.UserId then
									local billboard = Instance.new('BillboardGui')
									billboard.Parent = obj
									billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
									billboard.Size = UDim2.fromOffset(36, 36)
									billboard.AlwaysOnTop = true
									billboard.ClipsDescendants = false
									local blur = addBlur(billboard)
									blur.Visible = Background.Enabled
									local image = Instance.new('ImageLabel')
									image.Size = UDim2.fromOffset(36, 36)
									image.Position = UDim2.fromScale(0.5, 0.5)
									image.AnchorPoint = Vector2.new(0.5, 0.5)
									image.BackgroundColor3 = Color3.fromHSV(0, 0, 0)
									image.BackgroundTransparency = 0.85
									image.BorderSizePixel = 0
									image.Image = bedwars.getIcon({itemType = 'satellite_dish'}, true)
									image.Parent = billboard
									local uicorner = Instance.new('UICorner')
									uicorner.CornerRadius = UDim.new(0, 4)
									uicorner.Parent = image
									if not billboardCache[ent] then billboardCache[ent] = {} end
									table.insert(billboardCache[ent], billboard)
									end
								end))
							end)
						end
						ktLabel.Text = '【 ' .. (ent.Player:GetAttribute('DisruptorTarget') and ent.Player:GetAttribute('DisruptorTarget') .. ' Team' or 'Unknown Team') .. ' 】'
					elseif playerKit == 'winter_lady' then
						ktLabel.TextColor3 = Color3.fromRGB(200, 225, 255)
						local function getWandTier(v)
							local inv = store.inventories[v] and store.inventories[v].items or {}
							for _, item in inv do
								local nowstr = string.lower(item.itemType or '')
								if string.find(nowstr, 'frost_staff') then
									return tonumber(item.itemType:sub(#item.itemType, #item.itemType)) or 1
								end
							end
						end
						local tier = getWandTier(ent.Player)
						if not tier or tier < 0 then ktLabel.Text = '' return end
						ktLabel.Text = '【' .. (vkRoman[tier] or tostring(tier)) .. '】'
					elseif playerKit == 'warrior' then
						ktLabel.TextColor3 = Color3.fromRGB(220, 60, 60)
						local grit = ent.Player:GetAttribute('Grit') or 0
						ktLabel.Text = '【 ' .. tostring(grit) .. '/100】'
					else
						ktLabel.Text = ''
					end
				end

				updateKtLabel()

				if ent.Character then
					if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
					table.insert(kitTrackerConnections[ent], ent.Character.AttributeChanged:Connect(function(attr)
						if attr == 'BlockKickerKit_BlockCount' or attr == 'StatusEffect_powdered_stacks' then
							updateKtLabel()
						end
					end))
					table.insert(kitTrackerConnections[ent], ent.Player.AttributeChanged:Connect(function(attr)
						if attr == 'DisruptorTarget' or attr == 'DisruptorActivation'
						or attr == 'AeryStacks' or attr == 'VoidKnightTier'
						or attr == 'PaladinStartTime' or attr == 'Summoner_ClawLevel'
						or attr == 'Grit' then
							updateKtLabel()
						end
					end))
					table.insert(kitTrackerConnections[ent], ent.Character.ChildAdded:Connect(function(child)
						if child.Name == 'elk' or string.find(child.Name, "wizard_staff") or string.find(child.Name, "frost_staff") then
							updateKtLabel()
						end
					end))
					table.insert(kitTrackerConnections[ent], ent.Character.ChildRemoved:Connect(function(child)
						if child and (child.Name == 'elk' or string.find(child.Name, "wizard_staff") or string.find(child.Name, "frost_staff")) then
							updateKtLabel()
						end
					end))
					table.insert(kitTrackerConnections[ent], workspace.ChildAdded:Connect(function(child)
						if child and child.Name:sub(1, 20) == 'DisguisedPlayerBlock' then
							updateKtLabel()
						end
					end))
					table.insert(kitTrackerConnections[ent], workspace.ChildRemoved:Connect(function(child)
						if child and child.Name:sub(1, 20) == 'DisguisedPlayerBlock' then
							updateKtLabel()
						end
					end))
				end
				if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
				table.insert(kitTrackerConnections[ent], ent.Player:GetAttributeChangedSignal('PlayingAsKits'):Connect(updateKtLabel))
			  end)
			end

			if Potions.Enabled then
				local baseX = Loot.Enabled and 45 or -39
				for i, def in potionDefs do
					local iconSc = Scale.Value
					local Icon = Instance.new('ImageLabel')
					Icon.Name = def.name
					Icon.Size = udim2fromOffset(26 * iconSc, 26 * iconSc)
					Icon.Position = udim2fromOffset((baseX + ((i - 1) * 28)) * iconSc, (Equipment.Enabled and -58 or -30) * iconSc)
					Icon.BackgroundTransparency = 1
					Icon.Image = ''
					Icon.Parent = nametag
				end
			end

			if Loot.Enabled then
				local lootDefs = { LootIron = 'iron', LootDiamond = 'diamond', LootEmerald = 'emerald' }
				for i, v in { 'LootIron', 'LootDiamond', 'LootEmerald' } do
					local iconSc = Scale.Value
					local Icon = Instance.new('ImageLabel')
					Icon.Name = v
					Icon.Size = udim2fromOffset(26 * iconSc, 26 * iconSc)
					Icon.Position = udim2fromOffset((-39 + ((i - 1) * 28)) * iconSc, (Equipment.Enabled and -58 or -30) * iconSc)
					Icon.BackgroundTransparency = 1
					Icon.Image = ''
					Icon.Parent = nametag
					local amt = Instance.new('TextLabel')
					amt.Name = 'Amt'
					amt.AnchorPoint = Vector2.new(0, 1)
					amt.Position = UDim2.new(0, 0, 1, 0)
					amt.Size = UDim2.new(0, 26 * iconSc, 0, 10 * iconSc)
					amt.BackgroundTransparency = 1
					amt.Text = ''
					amt.TextColor3 = Color3.fromRGB(255, 255, 255)
					amt.TextStrokeTransparency = 0.4
					amt.TextSize = 9 * iconSc
					amt.Font = Enum.Font.GothamBold
					amt.TextXAlignment = Enum.TextXAlignment.Center
					amt.TextYAlignment = Enum.TextYAlignment.Bottom
					amt.Parent = Icon
				end

				local function applyLootIcons()
					if not (NameTags.Enabled and Loot.Enabled and nametag and nametag.Parent and ent.Player) then return end
					local inventory = store.inventories[ent.Player]
					if not inventory and bedwars.getInventory then
						inventory = bedwars.getInventory(ent.Player)
						if inventory then store.inventories[ent.Player] = inventory end
					end
					if not inventory then return end
					local counts = { iron = 0, diamond = 0, emerald = 0 }
					for _, it in inventory.items or {} do
						if counts[it.itemType] ~= nil then
							counts[it.itemType] = counts[it.itemType] + (it.amount or 0)
						end
					end
					for slot, nm in lootDefs do
						local ic = nametag:FindFirstChild(slot)
						if ic then
							local c = counts[nm]
							if c > 0 then
								ic.Image = bedwars.getIcon({ itemType = nm }, true)
								if ic.Amt then ic.Amt.Text = tostring(c) end
							else
								ic.Image = ''
								if ic.Amt then ic.Amt.Text = '' end
							end
						end
					end
				end

				applyLootIcons()
				if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
				table.insert(kitTrackerConnections[ent], vapeEvents.InventoryChanged.Event:Connect(function()
					if nametag and nametag.Parent then applyLootIcons() end
				end))
			end

			if Equipment.Enabled then
				for i, v in { 'Hand', 'Helmet', 'Chestplate', 'Boots' } do
					local Icon = Instance.new('ImageLabel')
					Icon.Name = v
					local iconSc = Scale.Value
					Icon.Size = udim2fromOffset(30 * iconSc, 30 * iconSc)
					Icon.Position = udim2fromOffset((-60 + (i * 30)) * iconSc, -30 * iconSc)
					Icon.BackgroundTransparency = 1
					Icon.Image = ''
					Icon.Parent = nametag
					if v == 'Hand' then
						local amt = Instance.new('TextLabel')
						amt.Name = 'Amt'
						amt.AnchorPoint = Vector2.new(0, 1)
						amt.Position = UDim2.new(0, 0, 1, 0)
						amt.Size = UDim2.new(0, 14 * iconSc, 0, 10 * iconSc)
						amt.BackgroundTransparency = 1
						amt.Text = ''
						amt.TextColor3 = Color3.fromRGB(255, 255, 255)
						amt.TextStrokeTransparency = 0.4
						amt.TextSize = 10 * iconSc
						amt.Font = Enum.Font.GothamBold
						amt.TextXAlignment = Enum.TextXAlignment.Left
						amt.TextYAlignment = Enum.TextYAlignment.Bottom
						amt.Parent = Icon
					end
				end

				local equipRetry = nil
				local function applyEquipmentIcons(attempt)
					if not ent.Player then return end
					if not (NameTags.Enabled and Equipment.Enabled and nametag and nametag.Parent) then return end
					local inventory = store.inventories[ent.Player]
					if not inventory and bedwars.getInventory then
						inventory = bedwars.getInventory(ent.Player)
						if inventory then store.inventories[ent.Player] = inventory end
					end
					if not inventory then
						if equipRetry then task.cancel(equipRetry) end
						local wait = math.min(0.1 * (attempt or 1), 1)
						equipRetry = task.delay(wait, function()
							equipRetry = nil
							applyEquipmentIcons((attempt or 1) + 1)
						end)
						return
					end
					local handItem = inventory.hand
					local kit = ent.Player:GetAttribute('PlayingAsKits')
					local handImage = bedwars.getIcon(handItem or { itemType = '' }, true)
					if nametag.Hand then
						nametag.Hand.Image = handImage
						if nametag.Hand.Amt then
							local a = handItem and handItem.amount
							nametag.Hand.Amt.Text = (a and a > 1) and tostring(a) or ''
						end
					end
					if nametag.Helmet then nametag.Helmet.Image = bedwars.getIcon(inventory.armor and inventory.armor[4] or { itemType = '' }, true) end
					local chestImage = bedwars.getIcon(inventory.armor and inventory.armor[5] or { itemType = '' }, true)
					if kit == 'tinker' then
						local level = ent.Player:GetAttribute('TinkerMachineLevel')
						if level and level >= 1 and level <= 5 then
							local mechImg = getChainsawImage(level)
							if mechImg and mechImg ~= '' then
								chestImage = mechImg
							end
						end
					end
					if nametag.Chestplate then nametag.Chestplate.Image = chestImage end
					if nametag.Boots then nametag.Boots.Image = bedwars.getIcon(inventory.armor and inventory.armor[6] or { itemType = '' }, true) end
				end
				applyEquipmentIcons()
				if not kitTrackerConnections[ent] then kitTrackerConnections[ent] = {} end
				table.insert(kitTrackerConnections[ent], vapeEvents.InventoryChanged.Event:Connect(function()
					if nametag and nametag.Parent then
						applyEquipmentIcons()
					end
				end))

				if ent.Player then
					local attrConn = ent.Player:GetAttributeChangedSignal('TinkerMachineLevel'):Connect(function()
						if Equipment.Enabled and nametag and nametag.Parent then
							applyEquipmentIcons()
						end
					end)
					if not kitTrackerConnections[ent] then
						kitTrackerConnections[ent] = {}
					end
					table.insert(kitTrackerConnections[ent], attrConn)
				end
			end

			if ShowKits.Enabled and ent.Player then
				local kitIcon = Instance.new('ImageLabel')
				kitIcon.Name = 'KitIcon'
				kitIcon.Size = udim2fromOffset(30, 30)
				kitIcon.AnchorPoint = vector2new(0.5, 0)
				kitIcon.BackgroundTransparency = 1
				kitIcon.Image = ''

				if Equipment.Enabled then
					kitIcon.Position = udim2fromOffset(110, -30)
				else
					kitIcon.Position = UDim2.new(0.5, 0, 0, -35)
				end

				kitIcon.Parent = nametag

				local kit = ent.Player:GetAttribute('PlayingAsKits')
				if kit then
					local kitImage = kitImageIds[kit:lower()]
					kitIcon.Image = kitImage or kitImageIds["none"]
					kitCache[ent] = kitImage or kitImageIds["none"]
				else
					kitIcon.Image = kitImageIds["none"]
					kitCache[ent] = kitImageIds["none"]
				end
			end

			if DeviceIcon and DeviceIcon.Enabled and ent.Player then
				local function getPlayerDevice(plr)
					local val = plr:GetAttribute('UserInputType') or 'Unknown'
					if not val then return 'Unknown' end
					val = val:upper()
					if val == 'MOBILE' then return 'Mobile'
					elseif val == 'GAMEPAD' or val == 'CONTROLLER' then return 'Controller'
					else return 'PC' end
				end
				local deviceType = getPlayerDevice(ent.Player)
				if deviceType then
					local deviceEmoji = {Mobile = '📱', PC = '🖥', Controller = '🎮', Unknown = '❔'}
					local deviceLabel = Instance.new('TextLabel')
					deviceLabel.Name = 'DeviceIcon'
					deviceLabel.Size = udim2fromOffset(22, 22)
					deviceLabel.AnchorPoint = vector2new(0, 0)
					deviceLabel.Position = UDim2.new(1, 10, 0, -1)
					deviceLabel.BackgroundTransparency = 1
					deviceLabel.BorderSizePixel = 0
					deviceLabel.Text = deviceEmoji[deviceType] or ''
					deviceLabel.RichText = false
					deviceLabel.TextScaled = false
					deviceLabel.TextSize = 16
					deviceLabel.FontFace = Font.fromEnum(Enum.Font.Arial)
					deviceLabel.TextColor3 = Color3.new(1, 1, 1)
					deviceLabel.Parent = nametag
				end
			end

			if Rank.Enabled and ent.Player then
				local rankIcon = Instance.new('ImageLabel')
				rankIcon.Name = 'RankIcon'
				rankIcon.Size = udim2fromOffset(30, 30)
				rankIcon.Position = UDim2.new(1, (DeviceIcon and DeviceIcon.Enabled and 42 or 10), 0, -4)
				rankIcon.BackgroundTransparency = 1
				rankIcon.Image = ''
				rankIcon.Parent = nametag

				task.spawn(function()
					task.wait(math.random() * 0.5)
					if not NameTags.Enabled then return end
					if vape.ThreadFix then setthreadidentity(8) end
					local plr = playersService:GetPlayerFromCharacter(ent.Character)
					if not plr then return end
					if not rankIcon or not rankIcon.Parent then return end

					local ok, success, data = pcall(function()
						return bedwars.Client:Get(remotes.Ranks):CallServerAsync({ plr.UserId }):await()
					end)

					if vape.ThreadFix then setthreadidentity(8) end

					if ok and success and type(data) == "table" then
						local division = data[1] and data[1].rankDivision
						if division and bedwars.RankMeta and bedwars.RankMeta[division] then
							if rankIcon and rankIcon.Parent then
								rankIcon.Image = bedwars.RankMeta[division].image
							end
						end
					end
				end)
			end

			if GloopIndicator and GloopIndicator.Enabled and ent.Character then
				local gloopIcon = Instance.new('ImageLabel')
				gloopIcon.Name = 'GloopIcon'
				gloopIcon.Size = udim2fromOffset(24, 24)
				gloopIcon.BackgroundTransparency = 1
				gloopIcon.Image = bedwars.getIcon({itemType = 'glue_projectile'}, true)
				gloopIcon.Visible = false
				if Rank.Enabled and DeviceIcon and DeviceIcon.Enabled then
					gloopIcon.Position = UDim2.new(1, 74, 0, -2)
				elseif Rank.Enabled or (DeviceIcon and DeviceIcon.Enabled) then
					gloopIcon.Position = UDim2.new(1, 42, 0, -2)
				else
					gloopIcon.Position = UDim2.new(1, 10, 0, -2)
				end
				gloopIcon.Parent = nametag
				local gloopTimer = nil
				if gloopConnections[ent] then gloopConnections[ent]:Disconnect() end
				gloopConnections[ent] = ent.Character.AttributeChanged:Connect(function(attr)
					if attr ~= 'GlueSlow' then return end
					local val = ent.Character:GetAttribute('GlueSlow')
					if val ~= nil and val ~= 0 then
						gloopIcon.Visible = true
						if gloopTimer then task.cancel(gloopTimer) end
						gloopTimer = task.delay(10, function()
							gloopIcon.Visible = false
							gloopTimer = nil
						end)
					end
				end)
			end

			if Enchant.Enabled and ent.Player and ent.Character then
				local Icon = Instance.new('ImageLabel')
				Icon.Name = 'EnchantIcon'
				Icon.Size = udim2fromOffset(30, 30)
				Icon.Position = udim2fromOffset(-30, -4)
				Icon.BackgroundTransparency = 1
				Icon.Image = getActiveEnchantImage(ent.Character)
				Icon.Parent = nametag
				enchantCache[ent] = Icon.Image
				if enchantConnections[ent] then enchantConnections[ent]:Disconnect() end
				enchantConnections[ent] = ent.Character.AttributeChanged:Connect(function(attr)
					if attr:sub(1, 13) ~= 'StatusEffect_' then return end
					local val = ent.Character:GetAttribute(attr)
					if type(val) ~= 'number' then return end
					local newImage = getActiveEnchantImage(ent.Character)
					if enchantCache[ent] ~= newImage then
						Icon.Image = newImage
						enchantCache[ent] = newImage
					end
				end)
			end

			Reference[ent] = nametag
			charCache[ent] = ent.Character
			lastUpdate[ent] = 0
		end,

		Drawing = function(ent)
			if not shouldShow(ent) then return end
			if Reference[ent] then return end

			local bg = Drawing.new('Square')
			bg.Filled = true
			bg.Thickness = 0
			bg.Color = color3new(0, 0, 0)
			bg.Transparency = 1 - Background.Value
			bg.ZIndex = 1
			bg.Visible = false

			local text = Drawing.new('Text')
			text.Center = false
			text.Outline = true
			text.OutlineColor = color3new(0, 0, 0)
			text.Size = math_round(14 * Scale.Value)
			text.Font = 2
			text.Color = getTeamColor(ent) or color3fromHSV(Color.Hue, Color.Sat, Color.Value)
			text.ZIndex = 2
			text.Visible = false

			local baseName = ent.Player and (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or (getBossDisplayName(ent) or (ent.Character and ent.Character.Name)) or ''
			local built = baseName
			if Health.Enabled then built = built .. ' ' .. healthPlain(ent) end
			if ShowKits.Enabled and ent.Player then
				local kit = ent.Player:GetAttribute('PlayingAsKits')
				if kit then
					built = built .. ' (' .. (kit:gsub('_', ' '):gsub('^%l', string.upper)) .. ')'
				end
			end
			if Distance.Enabled then
				Strings[ent] = '[%s] ' .. built
			else
				Strings[ent] = built
				text.Text = built
				bg.Size = vector2new(text.TextBounds.X + 8, text.TextBounds.Y + 7)
			end

			Reference[ent] = {Text = text, BG = bg}
			charCache[ent] = ent.Character
		end
	}

	Removed = {
		Normal = function(ent)
			local v = Reference[ent]
			if v then
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				lastUpdate[ent] = nil
				kitCache = {}
				equipmentCache = {}
				lootCache = {}
				enchantCache = {}
				healthCache[ent] = nil
				charCache[ent] = nil
				if enchantConnections[ent] then
					enchantConnections[ent]:Disconnect()
					enchantConnections[ent] = nil
				end
				if gloopConnections[ent] then
					gloopConnections[ent]:Disconnect()
					gloopConnections[ent] = nil
				end
				if kitTrackerConnections[ent] then
					for _, c in ipairs(kitTrackerConnections[ent]) do
						pcall(function() c:Disconnect() end)
					end
					kitTrackerConnections[ent] = nil
				end
				if billboardCache[ent] then
					for _, b in ipairs(billboardCache[ent]) do
						pcall(function() b:Destroy() end)
					end
					billboardCache[ent] = nil
				end
				v:Destroy()
			end
		end,
		Drawing = function(ent)
			local v = Reference[ent]
			if v then
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				lastUpdate[ent] = nil
				kitCache[ent] = nil
				healthCache[ent] = nil
				if enchantConnections[ent] then
					enchantConnections[ent]:Disconnect()
					enchantConnections[ent] = nil
				end
				if gloopConnections[ent] then
					gloopConnections[ent]:Disconnect()
					gloopConnections[ent] = nil
				end
				if billboardCache[ent] then
					for _, b in ipairs(billboardCache[ent]) do
						pcall(function() b:Destroy() end)
					end
					billboardCache[ent] = nil
				end
				for _, obj in v do
					pcall(function()
						obj.Visible = false
						obj:Remove()
					end)
				end
			end
		end
	}

	local Updated = {
		Normal = function(ent)
			local nametag = Reference[ent]
			if not nametag then return end

			local now = tick()
			if lastUpdate[ent] and (now - lastUpdate[ent]) < 0.2 then return end
			lastUpdate[ent] = now

			Sizes[ent] = nil
			local bossDisplayName = ent.NPC and ent.Character and getBossDisplayName(ent) or nil
			local entityName = bossDisplayName or (ent.Player and nil) or ent.Character.Name
			Strings[ent] = ent.Player and (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or entityName

			if Health.Enabled then
				Strings[ent] = Strings[ent]..' '..healthRich(ent)
			end

			if Distance.Enabled then
				Strings[ent] = '[%s] ' .. Strings[ent]
			end

			if Equipment.Enabled and ent.Player then
				if not store.inventories[ent.Player] and bedwars.getInventory then
					local fetched = bedwars.getInventory(ent.Player)
					if fetched then store.inventories[ent.Player] = fetched end
				end
				local inventory = store.inventories[ent.Player] or {hand = nil, armor = {}}
				local handItem = inventory.hand
				local kit = ent.Player:GetAttribute('PlayingAsKits')
				local handImage = bedwars.getIcon(handItem or { itemType = '' }, true)
				local chestImage = bedwars.getIcon(inventory.armor and inventory.armor[5] or { itemType = '' }, true)
				if kit == 'tinker' then
					local level = ent.Player:GetAttribute('TinkerMachineLevel')
					if level and level >= 1 and level <= 5 then
						local mechImg = getChainsawImage(level)
						if mechImg and mechImg ~= '' then
							chestImage = mechImg
						end
					end
				end
				local currentEquip = {
					tostring(handItem and handItem.itemType or ''),
					tostring((inventory.armor and inventory.armor[4] and inventory.armor[4].itemType) or ''),
					tostring((inventory.armor and inventory.armor[5] and inventory.armor[5].itemType) or ''),
					tostring((inventory.armor and inventory.armor[6] and inventory.armor[6].itemType) or '')
				}
				local equipKey = table.concat(currentEquip, "|")
				if equipmentCache[ent] ~= equipKey then
					equipmentCache[ent] = equipKey
					if nametag.Hand then
						nametag.Hand.Image = handImage
						if nametag.Hand.Amt then
							local a = handItem and handItem.amount
							nametag.Hand.Amt.Text = (a and a > 1) and tostring(a) or ''
						end
					end
					if nametag.Helmet then
						nametag.Helmet.Image = bedwars.getIcon(inventory.armor and inventory.armor[4] or { itemType = '' }, true)
					end
					if nametag.Chestplate then
						nametag.Chestplate.Image = chestImage
					end
					if nametag.Boots then
						nametag.Boots.Image = bedwars.getIcon(inventory.armor and inventory.armor[6] or { itemType = '' }, true)
					end
				end
			end

			local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, vector2new(100000, 100000))
			nametag.Size = udim2fromOffset(size.X + 8, size.Y + 7)
			nametag.Text = Strings[ent]
			nametag.TextColor3 = getTeamColor(ent) or color3fromHSV(Color.Hue, Color.Sat, Color.Value)
		end,

		Drawing = function(ent)
			local nametag = Reference[ent]
			if nametag then
				if vape.ThreadFix then setthreadidentity(8) end
				Sizes[ent] = nil
				local bossDisplayName = ent.NPC and ent.Character and getBossDisplayName(ent) or nil
				local entityName = bossDisplayName or (ent.Player and nil) or ent.Character.Name
				Strings[ent] = ent.Player and (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or entityName

				if Health.Enabled then
					Strings[ent] = Strings[ent]..' '..healthPlain(ent)
					nametag.Text.Color = getHealthColor(ent)
				end

				if Distance.Enabled then
					Strings[ent] = '[%s] ' .. Strings[ent]
					nametag.Text.Text = entitylib.isAlive and string_format(Strings[ent], math_floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent]
				else
					nametag.Text.Text = Strings[ent]
				end

				if ShowKits.Enabled and ent.Player then
					local kit = ent.Player:GetAttribute('PlayingAsKits')
					if kit then
						local kitName = kit:gsub("_", " "):gsub("^%l", string.upper)
						nametag.Text.Text = nametag.Text.Text .. ' (' .. kitName .. ')'
					end
				end

				nametag.BG.Size = vector2new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
				if not Health.Enabled then
					nametag.Text.Color = getTeamColor(ent) or color3fromHSV(Color.Hue, Color.Sat, Color.Value)
				end
			end
		end
	}

	local ColorFunc = {
		Normal = function(hue, sat, val)
			local color = color3fromHSV(hue, sat, val)
			for i, v in Reference do
				v.TextColor3 = getTeamColor(i) or color
			end
		end,
		Drawing = function(hue, sat, val)
			local color = color3fromHSV(hue, sat, val)
			for i, v in Reference do
				if not Health.Enabled then
					v.Text.Color = getTeamColor(i) or color
				end
			end
		end
	}

	local frameCounter = 0
	Loop = {
		Normal = function()
			frameCounter = frameCounter + 1
			local skipVisCheck = frameCounter % 2 ~= 0
			local updateDistText = frameCounter % 3 == 0
			local updateEquipment = frameCounter % 30 == 0
			local forceEquip = frameCounter % 150 == 0
			local updateKit = frameCounter % 30 == 0
			local updateDistanceText = frameCounter % 6 == 0
			local myPos = entitylib.isAlive and entitylib.character.RootPart and entitylib.character.RootPart.Position

			for ent, nametag in Reference do
				if not ent.RootPart or not ent.Character or not ent.Character.Parent or (ent.Health ~= nil and ent.Health <= 0) then
					nametag.Visible = false
					continue
				end
				if DistanceCheck.Enabled then
					local distance = myPos and (myPos - ent.RootPart.Position).Magnitude or math_huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						nametag.Visible = false
						continue
					end
				end

				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + vector3new(0, ent.HipHeight + 1, 0))
				if not skipVisCheck then
					nametag.Visible = headVis
				end
				if not nametag.Visible or not headVis then continue end
				nametag.Position = udim2fromOffset(headPos.X, headPos.Y)

				if Health.Enabled and (frameCounter % 2 == 0) then
					local hp = healthRich(ent)
					if healthCache[ent] ~= hp then
						healthCache[ent] = hp
						local baseName = ent.Player and (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or (getBossDisplayName(ent) or (ent.Character and ent.Character.Name)) or ''
						Strings[ent] = baseName..' '..hp
						if Distance.Enabled then
							Strings[ent] = '[%s] ' .. Strings[ent]
						else
							nametag.Text = Strings[ent]
							local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, vector2new(100000, 100000))
							nametag.Size = udim2fromOffset(size.X + 8, size.Y + 7)
						end
						Sizes[ent] = nil
					end
				end

				if Distance.Enabled and updateDistText then
					local mag = myPos and math_floor((myPos - ent.RootPart.Position).Magnitude) or 0
					if Sizes[ent] ~= mag then
						nametag.Text = string_format(Strings[ent], mag)
						if updateDistanceText then
							local size = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, vector2new(100000, 100000))
							nametag.Size = udim2fromOffset(size.X + 8, size.Y + 7)
						end
						Sizes[ent] = mag
					end
				end

				if Equipment.Enabled and (updateEquipment or forceEquip) then
					if ent.Player and not store.inventories[ent.Player] and bedwars.getInventory then
						local fetched = bedwars.getInventory(ent.Player)
						if fetched then store.inventories[ent.Player] = fetched end
					end
					if ent.Player and store.inventories[ent.Player] then
						local inventory = store.inventories[ent.Player]
						local handItem = inventory.hand
						local currentEquip = {
							(handItem and handItem.itemType) or '',
							(inventory.armor and inventory.armor[4] and inventory.armor[4].itemType) or '',
							(inventory.armor and inventory.armor[5] and inventory.armor[5].itemType) or '',
							(inventory.armor and inventory.armor[6] and inventory.armor[6].itemType) or ''
						}
						local equipKey = table.concat(currentEquip, "|")
						local iconsBlank = nametag.Hand and (nametag.Hand.Image == '' or nametag.Hand.Image == nil)
						if equipmentCache[ent] ~= equipKey or forceEquip or (iconsBlank and equipKey ~= "|||") then
							local kit = ent.Player:GetAttribute('PlayingAsKits')
							local handImage = bedwars.getIcon(handItem or { itemType = '' }, true)
							local chestImage = bedwars.getIcon(inventory.armor and inventory.armor[5] or { itemType = '' }, true)
							if kit == 'tinker' then
								local level = ent.Player:GetAttribute('TinkerMachineLevel')
								if level and level >= 1 and level <= 5 then
									local mechImg = getChainsawImage(level)
									if mechImg and mechImg ~= '' then
										chestImage = mechImg
									end
								end
							end
							equipmentCache[ent] = equipKey
							if nametag.Hand then
								nametag.Hand.Image = handImage
								if nametag.Hand.Amt then
									local a = handItem and handItem.amount
									nametag.Hand.Amt.Text = (a and a > 1) and tostring(a) or ''
								end
							end
							if nametag.Helmet then
								nametag.Helmet.Image = bedwars.getIcon(inventory.armor and inventory.armor[4] or { itemType = '' }, true)
							end
							if nametag.Chestplate then
								nametag.Chestplate.Image = chestImage
							end
							if nametag.Boots then
								nametag.Boots.Image = bedwars.getIcon(inventory.armor and inventory.armor[6] or { itemType = '' }, true)
							end
						end
					elseif ent.Player then
						equipmentCache[ent] = nil
					end
				end

				if Loot.Enabled and (updateEquipment or forceEquip) and ent.Player and nametag.LootIron then
					local inv = store.inventories[ent.Player]
					if not inv and bedwars.getInventory then
						inv = bedwars.getInventory(ent.Player)
						if inv then store.inventories[ent.Player] = inv end
					end
					if inv and inv.items then
						local counts = { iron = 0, diamond = 0, emerald = 0 }
						for _, it in inv.items do
							local c = counts[it.itemType]
							if c then
								counts[it.itemType] = c + (it.amount or 0)
							end
						end
						local lootKey = counts.iron .. '|' .. counts.diamond .. '|' .. counts.emerald
						if lootCache[ent] ~= lootKey or forceEquip then
							lootCache[ent] = lootKey
							for slot, nm in { LootIron = 'iron', LootDiamond = 'diamond', LootEmerald = 'emerald' } do
								local ic = nametag:FindFirstChild(slot)
								if ic then
									local c = counts[nm]
									if c > 0 then
										ic.Image = bedwars.getIcon({ itemType = nm }, true)
										if ic.Amt then ic.Amt.Text = tostring(c) end
									else
										ic.Image = ''
										if ic.Amt then ic.Amt.Text = '' end
									end
								end
							end
						end
					end
				end

				if Potions.Enabled and (updateEquipment or forceEquip) then
					local char = ent.Character
					for _, def in potionDefs do
						local ic = nametag:FindFirstChild(def.name)
						if ic then
							local want = potionActive(char, def) and bedwars.getIcon({itemType = def.item}, true) or ''
							if ic.Image ~= want then
								ic.Image = want
							end
						end
					end
				end

				if ShowKits.Enabled and updateKit then
					local kitIcon = nametag:FindFirstChild('KitIcon')
					if kitIcon and ent.Player then
						local kit = ent.Player:GetAttribute('PlayingAsKits')
						local meta = bedwars.BedwarsKitMeta and kit and bedwars.BedwarsKitMeta[kit]
						local newKitImage = (meta and meta.renderImage) or kitImageIds[kit] or kitImageIds['none']
						if kitCache[ent] ~= newKitImage then
							kitIcon.Image = newKitImage
							kitCache[ent] = newKitImage
						end
					end
				end
			end
		end,

		Drawing = function()
			frameCounter = frameCounter + 1
			local skipFrame = frameCounter % 2 ~= 0

			for ent, nametag in Reference do
				if not ent.RootPart or (ent.Health ~= nil and ent.Health <= 0) then
					if not nametag:GetAttribute('DeadHidden') then
						nametag:SetAttribute('DeadHidden', true)
						for _, child in nametag:GetChildren() do
							if child:IsA('GuiObject') then child.Visible = false end
						end
					end
					continue
				end
				if nametag:GetAttribute('DeadHidden') then
					nametag:SetAttribute('DeadHidden', nil)
					for _, child in nametag:GetChildren() do
						if child:IsA('GuiObject') then child.Visible = true end
					end
				end
				if DistanceCheck.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math_huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						nametag.Text.Visible = false
						nametag.BG.Visible = false
						continue
					end
				end

				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + vector3new(0, ent.HipHeight + 1, 0))
				nametag.Text.Visible = headVis
				nametag.BG.Visible = headVis
				if not headVis then continue end
				if skipFrame then continue end

				if Health.Enabled then
					nametag.Text.Color = getHealthColor(ent)
					local hp = healthPlain(ent)
					if healthCache[ent] ~= hp then
						healthCache[ent] = hp
						local baseName = ent.Player and (DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or (getBossDisplayName(ent) or (ent.Character and ent.Character.Name)) or ''
						local built = baseName..' '..hp
						if ShowKits.Enabled and ent.Player then
							local kit = ent.Player:GetAttribute('PlayingAsKits')
							if kit then
								built = built..' ('..(kit:gsub('_', ' '):gsub('^%l', string.upper))..')'
							end
						end
						if Distance.Enabled then
							Strings[ent] = '[%s] '..built
						else
							Strings[ent] = built
							nametag.Text.Text = built
							nametag.BG.Size = vector2new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
						end
						Sizes[ent] = nil
					end
				end

				if Distance.Enabled then
					local mag = entitylib.isAlive and math_floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
					if Sizes[ent] ~= mag then
						nametag.Text.Text = string_format(Strings[ent], mag)
						nametag.BG.Size = vector2new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
						Sizes[ent] = mag
					end
				end

				nametag.BG.Position = vector2new(headPos.X - (nametag.BG.Size.X / 2), headPos.Y - nametag.BG.Size.Y)
				nametag.Text.Position = nametag.BG.Position + vector2new(4, 3)
			end
		end
	}

	NameTags = vape.Categories.Render:CreateModule({
		Name = 'NameTags',
		Function = function(callback)
			if callback then
				methodused = StreamProof.Enabled and 'Drawing' or 'Normal'
				frameCounter = 0

				if Removed[methodused] then
					NameTags:Clean(entitylib.Events.EntityRemoved:Connect(Removed[methodused]))
				end

				if Added[methodused] then
					for _, v in entitylib.List do
						if Reference[v] then Removed[methodused](v) end
						pcall(Added[methodused], v)
					end
					task.spawn(function()
						task.wait(1)
						if not NameTags.Enabled then return end
						for _, v in entitylib.List do
							if Reference[v] then Removed[methodused](v) end
							pcall(Added[methodused], v)
						end
					end)
					NameTags:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
						task.spawn(function()
							task.wait(0.5)
							if not NameTags.Enabled then return end
							if not ent.Character or not ent.Character.Parent then
								if Reference[ent] then Removed[methodused](ent) end
								return
							end
							if Reference[ent] then Removed[methodused](ent) end
							pcall(Added[methodused], ent)
						end)
					end))
					NameTags:Clean(playersService.PlayerAdded:Connect(function(p)
						NameTags:Clean(p.CharacterAdded:Connect(function()
							task.delay(0.3, function()
								if not NameTags.Enabled then return end
								for _, v in entitylib.List do
									if v.Player == p and not Reference[v] then
										pcall(Added[methodused], v)
									end
								end
							end)
						end))
					end))
				end

				if Updated[methodused] then
					NameTags:Clean(entitylib.Events.EntityUpdated:Connect(function(ent)
						local show = shouldShow(ent)
						if show and not Reference[ent] then
							pcall(Added[methodused], ent)
							return
						elseif not show and Reference[ent] then
							Removed[methodused](ent)
							return
						end
						if Reference[ent] and charCache[ent] ~= ent.Character then
							Removed[methodused](ent)
							pcall(Added[methodused], ent)
							return
						end
						Updated[methodused](ent)
					end))
					for _, v in entitylib.List do
						pcall(Updated[methodused], v)
					end
				end

				if ColorFunc[methodused] then
					NameTags:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
						ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
					end))
				end

				if Loop[methodused] then
					NameTags:Clean(runService.RenderStepped:Connect(Loop[methodused]))
				end

				if Added[methodused] then
					task.spawn(function()
						while NameTags.Enabled do
							task.wait(0.5)
							if not NameTags.Enabled then break end
							for _, v in entitylib.List do
								if v.Character and v.Character.Parent and shouldShow(v) then
									if not Reference[v] then
										pcall(Added[methodused], v)
									elseif charCache[v] ~= v.Character then
										Removed[methodused](v)
										pcall(Added[methodused], v)
									end
								end
							end
						end
					end)
				end
			else
				if Removed[methodused] then
					for i in Reference do
						Removed[methodused](i)
					end
				end
				lastUpdate = {}
				kitCache = {}
				equipmentCache = {}
				enchantCache = {}
				healthCache = {}
				enchantConnections = {}
				gloopConnections = {}
				kitTrackerConnections = {}
				for _, list in pairs(billboardCache) do
					for _, b in ipairs(list) do
						pcall(function() b:Destroy() end)
					end
				end
				billboardCache = {}
			end
		end,
		Tooltip = 'renders nametags on entities through walls.'
	})

	Targets = NameTags:CreateTargets({
		Players = true,
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	FontOption = NameTags:CreateFont({
		Name = 'Font',
		Blacklist = 'Arial',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	Color = NameTags:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			if NameTags.Enabled and ColorFunc[methodused] then
				ColorFunc[methodused](hue, sat, val)
			end
		end
	})

	Scale = NameTags:CreateSlider({
		Name = 'Scale',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = 1,
		Min = 0.1,
		Max = 1.5,
		Decimal = 10
	})

	Background = NameTags:CreateSlider({
		Name = 'Transparency',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = 0.5,
		Min = 0,
		Max = 1,
		Decimal = 10
	})

	Health = NameTags:CreateToggle({
		Name = 'Health',
		Function = function(callback)
			HealthColorToggle.Object.Visible = callback
			HealthColorFull.Object.Visible = callback and HealthColorToggle.Enabled
			HealthColorMid.Object.Visible = callback and HealthColorToggle.Enabled
			HealthColorLow.Object.Visible = callback and HealthColorToggle.Enabled
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	HealthColorToggle = NameTags:CreateToggle({
		Name = 'Custom Health Colors',
		Darker = true,
		Visible = false,
		Function = function(callback)
			HealthColorFull.Object.Visible = callback
			HealthColorMid.Object.Visible = callback
			HealthColorLow.Object.Visible = callback
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	HealthColorFull = NameTags:CreateColorSlider({
		Name = 'Full HP Color',
		Darker = true,
		Visible = false,
		DefaultHue = 0.4,
		DefaultSat = 0.89,
		DefaultValue = 0.75,
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	HealthColorMid = NameTags:CreateColorSlider({
		Name = 'Mid HP Color',
		Darker = true,
		Visible = false,
		DefaultHue = 0.15,
		DefaultSat = 0.89,
		DefaultValue = 0.75,
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	HealthColorLow = NameTags:CreateColorSlider({
		Name = 'Low HP Color',
		Darker = true,
		Visible = false,
		DefaultHue = 0,
		DefaultSat = 0.89,
		DefaultValue = 0.75,
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	Distance = NameTags:CreateToggle({
		Name = 'Distance',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	Loot = NameTags:CreateToggle({
		Name = 'Loot',
		Tooltip = 'shows how much iron/diamond/emerald they got',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Potions = NameTags:CreateToggle({
		Name = 'Potions',
		Tooltip = 'shows if they popped serpent, fury, invis, jump or speed pie',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Equipment = NameTags:CreateToggle({
		Name = 'Equipment',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	ShowKits = NameTags:CreateToggle({
		Name = 'Show Kits',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
	})

	KitTracker = NameTags:CreateToggle({
		Name = 'Kit Tracker',
		Tooltip = 'shows stats for certain kits on a player',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	Rank = NameTags:CreateToggle({
		Name = 'Rank',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	DeviceIcon = NameTags:CreateToggle({
		Name = 'Device Icon',
		Tooltip = 'shows what device the player is using',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	GloopIndicator = NameTags:CreateToggle({
		Name = 'Gloop',
		Default = true,
		Tooltip = 'shows when a player is glooped and not glooped anymore',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	Enchant = NameTags:CreateToggle({
		Name = 'Enchant',
		Tooltip = 'shows the player current enchant',
		Default = true,
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	DisplayName = NameTags:CreateToggle({
		Name = 'Use Displayname',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = true
	})

	Teammates = NameTags:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = true
	})

	StreamProof = NameTags:CreateToggle({
		Name = 'Stream Proof',
		Default = false,
		Tooltip = 'uses drawing api so its stream proof if u record within roblox (text only, no icons)',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	Boss = NameTags:CreateToggle({
		Name = 'Boss',
		Tooltip = 'nametags for titan and bhaa (really good if u use health too!!)',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})

	DistanceCheck = NameTags:CreateToggle({
		Name = 'Distance Check',
		Function = function(callback)
			DistanceLimit.Object.Visible = callback
		end
	})

	DistanceLimit = NameTags:CreateTwoSlider({
		Name = 'Player Distance',
		Min = 0,
		Max = 256,
		DefaultMin = 0,
		DefaultMax = 64,
		Darker = true,
		Visible = false
	})

	task.defer(function()
		if DistanceLimit and DistanceLimit.Object then
			DistanceLimit.Object.Visible = false
		end
		if HealthColorToggle and HealthColorToggle.Object then
			HealthColorToggle.Object.Visible = false
		end
		if HealthColorFull and HealthColorFull.Object then
			HealthColorFull.Object.Visible = false
		end
		if HealthColorMid and HealthColorMid.Object then
			HealthColorMid.Object.Visible = false
		end
		if HealthColorLow and HealthColorLow.Object then
			HealthColorLow.Object.Visible = false
		end
	end)
end)

run(function()
	local GeneratorESP
	DiamondToggle = nil
	EmeraldToggle = nil
	TeamGenToggle = nil
	ShowOwnTeamGen = nil
	ShowEnemyTeamGen = nil
	local UIStyle
	local CompactDiamondToggle
	local CompactEmeraldToggle
	local CollectionService = collectionService
	local RunService = runService
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local CompactFolder = Instance.new('Folder')
	CompactFolder.Parent = vape.gui
	local teamColors = getgenv().aeroTeamColors

	local generatorTypes = {
		diamond = {
			keywords = {'diamond'},
			color = Color3.fromRGB(85, 200, 255),
			icon = 'diamond',
			displayName = 'Diamond',
			isTeamGen = false
		},
		emerald = {
			keywords = {'emerald'},
			color = Color3.fromRGB(0, 255, 100),
			icon = 'emerald',
			displayName = 'Emerald',
			isTeamGen = false
		}
	}

	local compactUI = Instance.new('ScreenGui')
	compactUI.Name = 'GeneratorCompactUI'
	compactUI.Parent = vape.gui
	compactUI.Enabled = false
	compactUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	compactUI.DisplayOrder = 10
	compactUI.ResetOnSpawn = false

	local mainFrame = Instance.new('Frame')
	mainFrame.Name = 'MainFrame'
	mainFrame.Parent = compactUI
	mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	mainFrame.BackgroundTransparency = 0.3
	mainFrame.BorderSizePixel = 0
	mainFrame.Position = UDim2.new(1, -8, 1, -8)
	mainFrame.Size = UDim2.new(0, 120, 0, 100)
	mainFrame.AnchorPoint = Vector2.new(1, 1)

	local uicorner = Instance.new('UICorner')
	uicorner.CornerRadius = UDim.new(0, 8)
	uicorner.Parent = mainFrame

	local title = Instance.new('TextLabel')
	title.Name = 'Title'
	title.Parent = mainFrame
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 25)
	title.Position = UDim2.new(0, 0, 0, 5)
	title.Text = "GEN ESP"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 14
	title.Font = Enum.Font.GothamBold
	title.TextStrokeTransparency = 0.5
	title.TextStrokeColor3 = Color3.new(0, 0, 0)

	local diamondFrame = Instance.new('Frame')
	diamondFrame.Name = 'DiamondFrame'
	diamondFrame.Parent = mainFrame
	diamondFrame.BackgroundTransparency = 1
	diamondFrame.Size = UDim2.new(1, -20, 0, 25)
	diamondFrame.Position = UDim2.new(0, 10, 0, 35)

	local diamondIcon = Instance.new('ImageLabel')
	diamondIcon.Name = 'DiamondIcon'
	diamondIcon.Parent = diamondFrame
	diamondIcon.BackgroundTransparency = 1
	diamondIcon.Size = UDim2.new(0, 18, 0, 18)
	diamondIcon.Position = UDim2.new(0, 0, 0.5, -9)
	diamondIcon.Image = bedwars.getIcon({itemType = 'diamond'}, true)

	local diamondTimer = Instance.new('TextLabel')
	diamondTimer.Name = 'DiamondTimer'
	diamondTimer.Parent = diamondFrame
	diamondTimer.BackgroundTransparency = 1
	diamondTimer.Size = UDim2.new(1, -25, 1, 0)
	diamondTimer.Position = UDim2.new(0, 25, 0, 0)
	diamondTimer.Text = "00"
	diamondTimer.TextColor3 = Color3.fromRGB(85, 200, 255)
	diamondTimer.TextSize = 18
	diamondTimer.Font = Enum.Font.GothamBold
	diamondTimer.TextXAlignment = Enum.TextXAlignment.Left

	local emeraldFrame = Instance.new('Frame')
	emeraldFrame.Name = 'EmeraldFrame'
	emeraldFrame.Parent = mainFrame
	emeraldFrame.BackgroundTransparency = 1
	emeraldFrame.Size = UDim2.new(1, -20, 0, 25)
	emeraldFrame.Position = UDim2.new(0, 10, 0, 65)

	local emeraldIcon = Instance.new('ImageLabel')
	emeraldIcon.Name = 'EmeraldIcon'
	emeraldIcon.Parent = emeraldFrame
	emeraldIcon.BackgroundTransparency = 1
	emeraldIcon.Size = UDim2.new(0, 18, 0, 18)
	emeraldIcon.Position = UDim2.new(0, 0, 0.5, -9)
	emeraldIcon.Image = bedwars.getIcon({itemType = 'emerald'}, true)

	local emeraldTimer = Instance.new('TextLabel')
	emeraldTimer.Name = 'EmeraldTimer'
	emeraldTimer.Parent = emeraldFrame
	emeraldTimer.BackgroundTransparency = 1
	emeraldTimer.Size = UDim2.new(1, -25, 1, 0)
	emeraldTimer.Position = UDim2.new(0, 25, 0, 0)
	emeraldTimer.Text = "00"
	emeraldTimer.TextColor3 = Color3.fromRGB(0, 255, 100)
	emeraldTimer.TextSize = 18
	emeraldTimer.Font = Enum.Font.GothamBold
	emeraldTimer.TextXAlignment = Enum.TextXAlignment.Left

	local diamondTimes = {}
	local emeraldTimes = {}

	local function getMyTeamId()
		local myTeam = lplr:GetAttribute('Team')
		if myTeam == nil then return nil end
		return tonumber(myTeam)
	end

	local function getGeneratorTeamId(generatorId)
		local teamNum = string.match(generatorId, "^(%d+)_generator")
		if teamNum then
			return tonumber(teamNum)
		end
		return nil
	end

	local function isTeamGenerator(generatorId)
		return string.match(generatorId, "^%d+_generator") ~= nil
	end

	local function getGeneratorType(generatorId)
		local idLower = string.lower(generatorId)

		if isTeamGenerator(generatorId) then
			return 'teamgen', {
				color = Color3.fromRGB(200, 200, 200),
				icon = 'iron',
				displayName = 'Team Gen',
				isTeamGen = true
			}
		end

		for genType, config in pairs(generatorTypes) do
			for _, keyword in ipairs(config.keywords) do
				if idLower:find(keyword) then
					return genType, config
				end
			end
		end
		return nil, nil
	end

	local function isGeneratorEnabled(genType, teamId)
		if genType == 'diamond' then
			return DiamondToggle.Enabled
		elseif genType == 'emerald' then
			return EmeraldToggle.Enabled
		elseif genType == 'teamgen' then
			if not TeamGenToggle.Enabled then return false end
			local myTeamId = getMyTeamId()
			if not myTeamId or not teamId then return TeamGenToggle.Enabled end
			if teamId == myTeamId then
				return ShowOwnTeamGen.Enabled
			else
				return ShowEnemyTeamGen.Enabled
			end
		end
		return false
	end

	local function getProperIcon(iconType)
		local icon = bedwars.getIcon({itemType = iconType}, true)
		if not icon or icon == "" then return nil end
		return icon
	end

	local function getTierText(generatorAdornee)
		if not generatorAdornee then return nil end
		if generatorAdornee.Name ~= 'GeneratorAdornee' then return nil end
		local reactTree = generatorAdornee:FindFirstChild('RoactTree')
		if not reactTree then return nil end
		local teamApp = reactTree:FindFirstChild('TeamOreGeneratorApp')
		if not teamApp then return nil end
		local globalGen = teamApp:FindFirstChild('GlobalOreGenerator')
		if globalGen then
			for _, child in pairs(globalGen:GetDescendants()) do
				if child:IsA('TextLabel') then
					local text = child.Text
					if text:find("Tier") or text:match("^[IVX]+$") or text == "0" then
						return child
					end
				end
			end
		end
		local teamGenMain = teamApp:FindFirstChild('TeamGenMain')
		if teamGenMain then
			for _, child in pairs(teamGenMain:GetDescendants()) do
				if child:IsA('TextLabel') then
					local text = child.Text
					if text:find("Tier") or text:match("^[IVX]+$") or text == "0" then
						return child
					end
				end
			end
		end
		return nil
	end

	local function extractTierLevel(tierText)
		if not tierText or tierText == "" then return "0" end
		if tierText == "0" then return "0" end
		local tierMatch = tierText:match("Tier%s+([IVX]+)")
		if tierMatch then return tierMatch end
		if tierText:match("^[IVX]+$") then return tierText end
		local numTier = tierText:match("Tier%s+(%d+)")
		if numTier then
			local num = tonumber(numTier)
			if num == 0 then return "0"
			elseif num == 1 then return "I"
			elseif num == 2 then return "II"
			elseif num == 3 then return "III"
			end
		end
		return "0"
	end

	local function getCountdownText(generatorAdornee)
		if not generatorAdornee then return nil end
		if generatorAdornee.Name ~= 'GeneratorAdornee' then return nil end
		local reactTree = generatorAdornee:FindFirstChild('RoactTree')
		if not reactTree then return nil end
		local teamApp = reactTree:FindFirstChild('TeamOreGeneratorApp')
		if not teamApp then return nil end
		local globalGen = teamApp:FindFirstChild('GlobalOreGenerator')
		if not globalGen then return nil end
		local countdown = globalGen:FindFirstChild('Countdown')
		if not countdown then return nil end
		local textLabel = countdown:FindFirstChild('Text')
		if not textLabel then
			if countdown:IsA('TextLabel') then return countdown end
			return nil
		end
		return textLabel
	end

	local function extractSecondsFromText(text)
		if not text or text == "" then return 0 end
		local seconds = text:match("%[(%d+)%]")
		if seconds then return tonumber(seconds) or 0 end
		local justNumber = text:match("(%d+)")
		if justNumber then return tonumber(justNumber) or 0 end
		return 0
	end

	local function getResourceCount(position, resourceType)
		local count = 0
		for _, drop in pairs(CollectionService:GetTagged('ItemDrop')) do
			if drop:FindFirstChild('Handle') then
				local dropName = drop.Name:lower()
				if dropName:find(resourceType) then
					local dist = (drop.Handle.Position - position).Magnitude
					if dist <= 10 then
						local amount = drop:GetAttribute('Amount') or 1
						count = count + amount
					end
				end
			end
		end
		return count
	end

	local CompactGenerators = {}

	local function rebuildCompactGenerators()
		table.clear(CompactGenerators)
		scanDescendants(workspace, function(obj)
			if obj.Name == 'GeneratorAdornee' then
				local ok, generatorId = pcall(function() return obj:GetAttribute('Id') end)
				if ok and generatorId and type(generatorId) == 'string' and generatorId ~= '' then
					local genType = getGeneratorType(generatorId)
					if genType == 'diamond' or genType == 'emerald' then
						table.insert(CompactGenerators, {obj = obj, genType = genType})
					end
				end
			end
		end)
	end

	local function updateCompactUI()
		if not GeneratorESP.Enabled or UIStyle.Value ~= 'Compact' then
			compactUI.Enabled = false
			return
		end
		compactUI.Enabled = true
		local bestDiamondTime = math.huge
		local bestEmeraldTime = math.huge
		for i = #CompactGenerators, 1, -1 do
			local entry = CompactGenerators[i]
			if not entry.obj or not entry.obj.Parent then
				table.remove(CompactGenerators, i)
				continue
			end
			local countdownText = getCountdownText(entry.obj)
			if countdownText and countdownText.Text then
				local timeLeft = extractSecondsFromText(countdownText.Text)
				if entry.genType == 'diamond' and timeLeft > 0 and timeLeft < bestDiamondTime then
					bestDiamondTime = timeLeft
				elseif entry.genType == 'emerald' and timeLeft > 0 and timeLeft < bestEmeraldTime then
					bestEmeraldTime = timeLeft
				end
			end
		end
		local showDiamond = CompactDiamondToggle and CompactDiamondToggle.Enabled
		local showEmerald = CompactEmeraldToggle and CompactEmeraldToggle.Enabled

		if not showDiamond and not showEmerald then
			compactUI.Enabled = false
			return
		end

		diamondFrame.Visible = showDiamond
		emeraldFrame.Visible = showEmerald

		if showDiamond then
			diamondFrame.Position = UDim2.new(0, 10, 0, 35)
		end
		if showEmerald then
			emeraldFrame.Position = UDim2.new(0, 10, 0, showDiamond and 65 or 35)
		end

		diamondTimes[1] = bestDiamondTime ~= math.huge and bestDiamondTime or 0
		emeraldTimes[1] = bestEmeraldTime ~= math.huge and bestEmeraldTime or 0
		if bestDiamondTime == math.huge then
			diamondTimer.Text = "00"
		else
			diamondTimer.Text = string.format("%02d", bestDiamondTime)
			if bestDiamondTime <= 5 then
				diamondTimer.TextColor3 = Color3.fromRGB(255, 50, 50)
			elseif bestDiamondTime <= 10 then
				diamondTimer.TextColor3 = Color3.fromRGB(255, 165, 0)
			else
				diamondTimer.TextColor3 = Color3.fromRGB(85, 200, 255)
			end
		end
		if bestEmeraldTime == math.huge then
			emeraldTimer.Text = "00"
		else
			emeraldTimer.Text = string.format("%02d", bestEmeraldTime)
			if bestEmeraldTime <= 5 then
				emeraldTimer.TextColor3 = Color3.fromRGB(255, 50, 50)
			elseif bestEmeraldTime <= 10 then
				emeraldTimer.TextColor3 = Color3.fromRGB(255, 165, 0)
			else
				emeraldTimer.TextColor3 = Color3.fromRGB(0, 255, 100)
			end
		end
	end

	local function clearAllESP()
		Folder:ClearAllChildren()
		table.clear(Reference)
		compactUI.Enabled = false
	end

	local function createESP(generatorAdornee, genType, config, position, teamId)
		if not isGeneratorEnabled(genType, teamId) then return end
		if Reference[generatorAdornee] then return end

		if UIStyle.Value == 'Compact' then
			Reference[generatorAdornee] = {
				genType = genType,
				position = position,
				teamId = teamId,
				isTeamGen = config.isTeamGen
			}
			return
		end
		if not generatorAdornee or not generatorAdornee.Parent then return end

		local displayColor = config.color
		local teamName = nil
		if config.isTeamGen and teamId and teamColors[teamId] then
			displayColor = teamColors[teamId].color
			teamName = teamColors[teamId].name
		end

		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'generator-esp-' .. genType
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = generatorAdornee
		billboard.Enabled = true  

		if config.isTeamGen then
			billboard.Size = UDim2.fromOffset(180, 55)
			billboard.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
		else
			billboard.Size = UDim2.fromOffset(80, 30)
			billboard.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
		end

		local blur = pcall(function()
			return addBlur(billboard)
		end) and blur or nil
		if blur then
			blur.Visible = true
		end

		if config.isTeamGen and teamName then
			local dot = Instance.new('Frame')
			dot.Name = 'TeamDot'
			dot.Parent = billboard
			dot.Size = UDim2.fromOffset(8, 8)
			dot.Position = UDim2.new(0, 10, 0, 5)
			dot.BackgroundColor3 = displayColor
			dot.BorderSizePixel = 0
			local dotCorner = Instance.new('UICorner')
			dotCorner.CornerRadius = UDim.new(1, 0)
			dotCorner.Parent = dot

			local teamLabel = Instance.new('TextLabel')
			teamLabel.Name = 'TeamLabel'
			teamLabel.Parent = billboard
			teamLabel.BackgroundTransparency = 1
			teamLabel.Size = UDim2.new(1, 0, 0, 18)
			teamLabel.Position = UDim2.new(0, 0, 0, 0)
			teamLabel.Text = teamName
			teamLabel.TextColor3 = displayColor
			teamLabel.TextSize = 13
			teamLabel.Font = Enum.Font.GothamBold
			teamLabel.TextStrokeTransparency = 0.4
			teamLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
			teamLabel.TextXAlignment = Enum.TextXAlignment.Center
		end

		local frame = Instance.new('Frame')
		frame.Size = config.isTeamGen and UDim2.new(1, 0, 0, 35) or UDim2.fromScale(1, 1)
		frame.Position = config.isTeamGen and UDim2.new(0, 0, 0, 20) or UDim2.new(0, 0, 0, 0)
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BackgroundTransparency = 0.3
		frame.BorderSizePixel = 0
		frame.Parent = billboard

		if config.isTeamGen and teamId and teamColors[teamId] then
			local stripe = Instance.new('Frame')
			stripe.Name = 'TeamStripe'
			stripe.Parent = frame
			stripe.Size = UDim2.new(0, 3, 1, 0)
			stripe.Position = UDim2.new(0, 0, 0, 0)
			stripe.BackgroundColor3 = displayColor
			stripe.BorderSizePixel = 0
			local stripeCorner = Instance.new('UICorner')
			stripeCorner.CornerRadius = UDim.new(0, 3)
			stripeCorner.Parent = stripe
		end

		local uicorner2 = Instance.new('UICorner')
		uicorner2.CornerRadius = UDim.new(0, 6)
		uicorner2.Parent = frame

		if config.isTeamGen then
			local tierLabel = Instance.new('TextLabel')
			tierLabel.Name = 'Tier'
			tierLabel.Size = UDim2.new(0, 25, 1, 0)
			tierLabel.Position = UDim2.new(0, 8, 0, 0)
			tierLabel.BackgroundTransparency = 1
			tierLabel.Text = "0"
			tierLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
			tierLabel.TextSize = 16
			tierLabel.Font = Enum.Font.GothamBold
			tierLabel.TextStrokeTransparency = 0.5
			tierLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
			tierLabel.Parent = frame

			local resources = {
				{name = 'iron',    color = Color3.fromRGB(200, 200, 200), icon = 'iron',    xOffset = 35},
				{name = 'diamond', color = Color3.fromRGB(85, 200, 255),  icon = 'diamond', xOffset = 85},
				{name = 'emerald', color = Color3.fromRGB(0, 255, 100),   icon = 'emerald', xOffset = 135}
			}

			local resourceLabels = {}
			for _, resource in ipairs(resources) do
				local iconImage = getProperIcon(resource.icon)
				if iconImage then
					local image = Instance.new('ImageLabel')
					image.Size = UDim2.fromOffset(18, 18)
					image.Position = UDim2.new(0, resource.xOffset, 0.5, 0)
					image.AnchorPoint = Vector2.new(0, 0.5)
					image.BackgroundTransparency = 1
					image.Image = iconImage
					image.Parent = frame
				end
				local countLabel = Instance.new('TextLabel')
				countLabel.Name = resource.name .. '_count'
				countLabel.Size = UDim2.new(0, 25, 1, 0)
				countLabel.Position = UDim2.new(0, resource.xOffset + 20, 0, 0)
				countLabel.BackgroundTransparency = 1
				countLabel.Text = "0"
				countLabel.TextColor3 = resource.color
				countLabel.TextSize = 16
				countLabel.Font = Enum.Font.GothamBold
				countLabel.TextStrokeTransparency = 0.5
				countLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
				countLabel.TextXAlignment = Enum.TextXAlignment.Left
				countLabel.Parent = frame
				resourceLabels[resource.name] = countLabel
			end

			Reference[generatorAdornee] = {
				billboard = billboard,
				tierLabel = tierLabel,
				ironLabel = resourceLabels.iron,
				diamondLabel = resourceLabels.diamond,
				emeraldLabel = resourceLabels.emerald,
				genType = genType,
				position = position,
				teamId = teamId,
				isTeamGen = true
			}
		else
			local iconImage = getProperIcon(config.icon)
			if iconImage then
				local image = Instance.new('ImageLabel')
				image.Size = UDim2.fromOffset(20, 20)
				image.Position = UDim2.new(0, 5, 0.5, 0)
				image.AnchorPoint = Vector2.new(0, 0.5)
				image.BackgroundTransparency = 1
				image.Image = iconImage
				image.Parent = frame
			end
			local timerLabel = Instance.new('TextLabel')
			timerLabel.Name = 'Timer'
			timerLabel.Size = UDim2.new(0, 30, 1, 0)
			timerLabel.Position = UDim2.new(0.5, 0, 0, 0)
			timerLabel.AnchorPoint = Vector2.new(0.5, 0)
			timerLabel.BackgroundTransparency = 1
			timerLabel.Text = "00"
			timerLabel.TextColor3 = displayColor
			timerLabel.TextSize = 18
			timerLabel.Font = Enum.Font.GothamBold
			timerLabel.TextStrokeTransparency = 0.5
			timerLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
			timerLabel.Parent = frame
			local amountLabel = Instance.new('TextLabel')
			amountLabel.Name = 'Amount'
			amountLabel.Size = UDim2.new(0, 20, 1, 0)
			amountLabel.Position = UDim2.new(1, -20, 0, 0)
			amountLabel.BackgroundTransparency = 1
			amountLabel.Text = "0"
			amountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			amountLabel.TextSize = 16
			amountLabel.Font = Enum.Font.GothamBold
			amountLabel.TextStrokeTransparency = 0.5
			amountLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
			amountLabel.Parent = frame
			Reference[generatorAdornee] = {
				billboard = billboard,
				timerLabel = timerLabel,
				amountLabel = amountLabel,
				genType = genType,
				position = position,
				teamId = teamId,
				isTeamGen = false
			}
		end
		billboard.Enabled = true
	end

	local function updateESP(generatorAdornee)
		local ref = Reference[generatorAdornee]
		if not ref then return end
		if UIStyle.Value == 'Compact' then return end

		if ref.isTeamGen then
			if ref.tierLabel then
				local tierTextLabel = getTierText(generatorAdornee)
				if tierTextLabel and tierTextLabel.Text then
					ref.tierLabel.Text = extractTierLevel(tierTextLabel.Text)
				else
					ref.tierLabel.Text = "0"
				end
			end
			if ref.ironLabel then
				ref.ironLabel.Text = tostring(getResourceCount(ref.position, 'iron'))
			end
			if ref.diamondLabel then
				ref.diamondLabel.Text = tostring(getResourceCount(ref.position, 'diamond'))
			end
			if ref.emeraldLabel then
				ref.emeraldLabel.Text = tostring(getResourceCount(ref.position, 'emerald'))
			end
		else
			local countdownText = getCountdownText(generatorAdornee)
			if countdownText and countdownText.Text then
				local timeLeft = extractSecondsFromText(countdownText.Text)
				if ref.timerLabel then
					ref.timerLabel.Text = string.format("%02d", timeLeft)
					if timeLeft <= 5 then
						ref.timerLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
					elseif timeLeft <= 10 then
						ref.timerLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
					else
						ref.timerLabel.TextColor3 = generatorTypes[ref.genType].color
					end
				end
			else
				if ref.timerLabel then
					ref.timerLabel.Text = "00"
					ref.timerLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
				end
			end
			if ref.amountLabel then
				ref.amountLabel.Text = tostring(getResourceCount(ref.position, ref.genType))
			end
		end
	end

	local function processGeneratorAdornee(obj)
		if obj.Name ~= 'GeneratorAdornee' then return end
		local ok, generatorId = pcall(function() return obj:GetAttribute('Id') end)
		if not ok then return end
		if generatorId == nil then return end
		if type(generatorId) ~= 'string' then return end
		if generatorId == '' then return end

		local position = obj:GetPivot().Position
		local genType, config = getGeneratorType(generatorId)
		if not genType or not config then return end

		local teamId = getGeneratorTeamId(generatorId)
		if isGeneratorEnabled(genType, teamId) then
			createESP(obj, genType, config, position, teamId)
		end
	end

	local function findAllGenerators()
		scanDescendants(workspace, function(obj)
			pcall(processGeneratorAdornee, obj)
		end)
	end

	local function refreshESP()
		clearAllESP()
		if GeneratorESP.Enabled then
			findAllGenerators()
		end
	end

	local updateTimer = 0

	GeneratorESP = vape.Categories.Render:CreateModule({
		Name = 'GeneratorESP',
		Function = function(callback)
			if callback then
				findAllGenerators()
				rebuildCompactGenerators()

				GeneratorESP:Clean(workspace.DescendantAdded:Connect(function(obj)
					if not GeneratorESP.Enabled then return end
					task.wait(0.2)
					pcall(processGeneratorAdornee, obj)
					if obj.Name == 'GeneratorAdornee' then
						rebuildCompactGenerators()
					end
				end))

				GeneratorESP:Clean(runService.Heartbeat:Connect(function(dt)
					if not GeneratorESP.Enabled then return end
					updateTimer = updateTimer + dt
					if updateTimer < 0.2 then return end
					updateTimer = 0
					for generatorAdornee, ref in pairs(Reference) do
						if generatorAdornee and generatorAdornee.Parent then
							updateESP(generatorAdornee)
						else
							if ref.billboard then ref.billboard:Destroy() end
							Reference[generatorAdornee] = nil
						end
					end
					updateCompactUI()
				end))

				GeneratorESP:Clean(workspace.DescendantRemoving:Connect(function(obj)
					if not GeneratorESP.Enabled then return end
					if Reference[obj] then
						if Reference[obj].billboard then Reference[obj].billboard:Destroy() end
						Reference[obj] = nil
					end
				end))
			else
				clearAllESP()
			end
		end,
		Tooltip = 'esp for generators showing timer and items count'
	})

	UIStyle = GeneratorESP:CreateDropdown({
		Name = 'UI Style',
		List = {'Original', 'Compact'},
		Default = 'Original',
		Function = function(val)
			local isOriginal = val == 'Original'
			if DiamondToggle then DiamondToggle.Object.Visible = isOriginal end
			if EmeraldToggle then EmeraldToggle.Object.Visible = isOriginal end
			if TeamGenToggle then TeamGenToggle.Object.Visible = isOriginal end
			if ShowOwnTeamGen then ShowOwnTeamGen.Object.Visible = isOriginal and TeamGenToggle.Enabled end
			if ShowEnemyTeamGen then ShowEnemyTeamGen.Object.Visible = isOriginal and TeamGenToggle.Enabled end
			if CompactDiamondToggle then CompactDiamondToggle.Object.Visible = not isOriginal end
			if CompactEmeraldToggle then CompactEmeraldToggle.Object.Visible = not isOriginal end
			refreshESP()
		end,
		Tooltip = 'pick between the norm billboard esp on generators or a ui with timers for generators '
	})

	DiamondToggle = GeneratorESP:CreateToggle({
		Name = 'Diamond',
		Function = function() refreshESP() end,
		Default = false,
		Visible = true
	})

	EmeraldToggle = GeneratorESP:CreateToggle({
		Name = 'Emerald',
		Function = function() refreshESP() end,
		Default = false,
		Visible = true
	})

	CompactDiamondToggle = GeneratorESP:CreateToggle({
		Name = 'Compact Diamond',
		Default = false,
		Visible = false,
		Function = function()
			refreshESP()
		end
	})

	CompactEmeraldToggle = GeneratorESP:CreateToggle({
		Name = 'Compact Emerald',
		Default = false,
		Visible = false,
		Function = function()
			refreshESP()
		end
	})

	TeamGenToggle = GeneratorESP:CreateToggle({
		Name = 'Team Generators',
		Function = function(callback)
			if ShowOwnTeamGen then ShowOwnTeamGen.Object.Visible = callback end
			if ShowEnemyTeamGen then ShowEnemyTeamGen.Object.Visible = callback end
			refreshESP()
		end,
		Default = true
	})

	ShowOwnTeamGen = GeneratorESP:CreateToggle({
		Name = 'Show Own Team',
		Function = function() refreshESP() end,
		Default = false,
		Visible = true
	})

	ShowEnemyTeamGen = GeneratorESP:CreateToggle({
		Name = 'Show Enemy Teams',
		Function = function() refreshESP() end,
		Default = true,
		Visible = true
	})
end)

run(function()
	local VictoriousKitSkins
	local ItemSkinDropdown
	local SkinTypeDropdown
	local RS = game:GetService('ReplicatedStorage')
	local LocalPlayer = lplr
	local RESKIN_NAME = 'LOCAL_ITEM_RESKIN'
	local state = {
		itemSkin = 'Victorious Lyla',
		skinType = 'Nightmare',
	}
	local ok1, ItemType = pcall(function()
		return require(RS.TS.item['item-type']).ItemType
	end)
	if not ok1 then ItemType = {} end
	local ok2, ItemSkinType = pcall(function()
		return require(RS.TS.games.bedwars['item-skin']['item-skin-types']).ItemSkinType
	end)
	if not ok2 then ItemSkinType = {} end
	local KitSkinCtrl
	pcall(function()
		local KC = require(RS.rbxts_include.node_modules['@easy-games'].knit.src).KnitClient
		KitSkinCtrl = KC.Controllers.KitSkinController
	end)

	local VICTORIOUS_ARCHER_BOW_ROT = CFrame.new(0, 0, 0) * CFrame.Angles(0, -52, math.rad(90))
	local VICTORIOUS_ARCHER_CROSSBOW_ROT = CFrame.new(0.00, 0.00, 0.00) * CFrame.Angles(math.rad(0), math.rad(80), math.rad(0.00))
	local VICTORIOUS_ARCHER_HEADHUNTER_ROT = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(0), 0)
	local STAFF_ROT = CFrame.Angles(0, math.rad(90), 0)
	local VIC_ROT = CFrame.new(0, -1.9, 0) * CFrame.Angles(0, math.rad(360), 0)
	local TRIDENT_ROT = CFrame.new(0, 0.5, 0.05) * CFrame.Angles(0, math.rad(180), 0)
	local LYLA_BOW_ROT = CFrame.new(0, 0, 0) * CFrame.Angles(30, -30, 183.56)
	local LYLA_CROSSBOW_ROT = CFrame.Angles(math.rad(0), math.rad(180), math.rad(0))
	local LYLA_HEADHUNTER_ROT = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(0), 0)
	local CANNON_HAND_SCALE = 0.34
	local CANNON_PLACED_OFFSET = CFrame.new(0, -1.0, 0)
	local CANNON_TOOL_NAME = "cannon"

	local CANNON_SKIN_NAMES = {
		["Victorious Cannon"] = {
			Gold = "cannon_gold_victorious",
			Platinum = "cannon_platinum_victorious",
			Diamond = "cannon_diamond_victorious",
			Emerald = "cannon_emerald_victorious",
			Nightmare = "cannon_nightmare_victorious",
		},
	}
	local CANNON_SOUND_NAMES = {
		Gold = "CANNON_FIRE_VICTORIOUS_NIGHTMARE",
		Platinum = "CANNON_FIRE_VICTORIOUS_NIGHTMARE",
		Diamond = "CANNON_FIRE_VICTORIOUS_DIAMOND",
		Emerald = "CANNON_FIRE_VICTORIOUS_EMERALD",
		Nightmare = "CANNON_FIRE_VICTORIOUS_NIGHTMARE",
	}
	local SKIN_OFFSETS = {
		["nightmare_victorious_flower_bow"] = LYLA_BOW_ROT,
		["emerald_victorious_flower_bow"] = LYLA_BOW_ROT,
		["diamond_victorious_flower_bow"] = LYLA_BOW_ROT,
		["platinum_victorious_flower_bow"] = LYLA_BOW_ROT,
		["gold_victorious_flower_bow"] = LYLA_BOW_ROT,
		["nightmare_victorious_flower_crossbow"] = LYLA_CROSSBOW_ROT,
		["emerald_victorious_flower_crossbow"] = LYLA_CROSSBOW_ROT,
		["diamond_victorious_flower_crossbow"] = LYLA_CROSSBOW_ROT,
		["platinum_victorious_flower_crossbow"] = LYLA_CROSSBOW_ROT,
		["gold_victorious_flower_crossbow"] = LYLA_CROSSBOW_ROT,
		["nightmare_victorious_flower_headhunter"] = LYLA_HEADHUNTER_ROT,
		["emerald_victorious_flower_headhunter"] = LYLA_HEADHUNTER_ROT,
		["diamond_victorious_flower_headhunter"] = LYLA_HEADHUNTER_ROT,
		["platinum_victorious_flower_headhunter"] = LYLA_HEADHUNTER_ROT,
		["gold_victorious_flower_headhunter"] = LYLA_HEADHUNTER_ROT,
		["tactical_headhunter_victorious_nightmare"] = VICTORIOUS_ARCHER_HEADHUNTER_ROT,
		["tactical_headhunter_victorious_emerald"] = VICTORIOUS_ARCHER_HEADHUNTER_ROT,
		["tactical_headhunter_victorious_diamond"] = VICTORIOUS_ARCHER_HEADHUNTER_ROT,
		["tactical_headhunter_victorious_platinum"] = VICTORIOUS_ARCHER_HEADHUNTER_ROT,
		["tactical_headhunter_victorious_gold"] = VICTORIOUS_ARCHER_HEADHUNTER_ROT,
		["wood_bow_victorious_nightmare"] = VICTORIOUS_ARCHER_BOW_ROT,
		["wood_bow_victorious_emerald"] = VICTORIOUS_ARCHER_BOW_ROT,
		["wood_bow_victorious_diamond"] = VICTORIOUS_ARCHER_BOW_ROT,
		["wood_bow_victorious_platinum"] = VICTORIOUS_ARCHER_BOW_ROT,
		["wood_bow_victorious_gold"] = VICTORIOUS_ARCHER_BOW_ROT,
		["tactical_crossbow_victorious_nightmare"] = VICTORIOUS_ARCHER_CROSSBOW_ROT,
		["tactical_crossbow_victorious_emerald"] = VICTORIOUS_ARCHER_CROSSBOW_ROT,
		["tactical_crossbow_victorious_diamond"] = VICTORIOUS_ARCHER_CROSSBOW_ROT,
		["tactical_crossbow_victorious_platinum"] = VICTORIOUS_ARCHER_CROSSBOW_ROT,
		["tactical_crossbow_victorious_gold"] = VICTORIOUS_ARCHER_CROSSBOW_ROT,
		["victorious_gold_triton"] = TRIDENT_ROT,
		["victorious_platinum_triton"] = TRIDENT_ROT,
		["victorious_diamond_triton"] = TRIDENT_ROT,
		["victorious_emerald_triton"] = TRIDENT_ROT,
		["victorious_nightmare_triton"] = TRIDENT_ROT,
		["gold_victorious_wizard_staff"] = STAFF_ROT,
		["gold_victorious_wizard_staff_2"] = STAFF_ROT,
		["gold_victorious_wizard_staff_3"] = STAFF_ROT,
		["platinum_victorious_wizard_staff"] = STAFF_ROT,
		["platinum_victorious_wizard_staff_2"] = STAFF_ROT,
		["platinum_victorious_wizard_staff_3"] = STAFF_ROT,
		["diamond_victorious_wizard_staff"] = STAFF_ROT,
		["diamond_victorious_wizard_staff_2"] = STAFF_ROT,
		["diamond_victorious_wizard_staff_3"] = STAFF_ROT,
		["emerald_victorious_wizard_staff"] = STAFF_ROT,
		["emerald_victorious_wizard_staff_2"] = STAFF_ROT,
		["emerald_victorious_wizard_staff_3"] = STAFF_ROT,
		["nightmare_victorious_wizard_staff"] = STAFF_ROT,
		["nightmare_victorious_wizard_staff_2"] = STAFF_ROT,
		["nightmare_victorious_wizard_staff_3"] = STAFF_ROT,
		["wood_dao_victorious"] = VIC_ROT,
		["stone_dao_victorious"] = VIC_ROT,
		["iron_dao_victorious"] = VIC_ROT,
		["diamond_dao_victorious"] = VIC_ROT,
		["emerald_dao_victorious"] = VIC_ROT,
	}
	local KIT_SKIN_MAP = {
		["Victorious Lyla"] = { Gold = "gold_victorious_lyla", Platinum = "platinum_victorious_lyla", Diamond = "diamond_victorious_lyla", Emerald = "emerald_victorious_lyla", Nightmare = "nightmare_victorious_lyla" },
		["Victorious Archer"] = { Gold = "archer_victorious_gold", Platinum = "archer_victorious_platinum", Diamond = "archer_victorious_diamond", Emerald = "archer_victorious_emerald", Nightmare = "archer_victorious_nightmare" },
		["Victorious Yuzi"] = { Default = "yuzi_victorious" },
		["Victorious Zeno"] = { Gold = "gold_victorious_wizard", Platinum = "platinum_victorious_wizard", Diamond = "diamond_victorious_wizard", Emerald = "emerald_victorious_wizard", Nightmare = "nightmare_victorious_wizard" },
		["Victorious Triton"] = { Gold = "victorious_gold_triton", Platinum = "victorious_platinum_triton", Diamond = "victorious_diamond_triton", Emerald = "victorious_emerald_triton", Nightmare = "victorious_nightmare_triton" },
		["Victorious Cannon"] = { Gold = "gold_victorious_davey", Platinum = "platinum_victorious_davey", Diamond = "diamond_victorious_davey", Emerald = "emerald_victorious_davey", Nightmare = "nightmare_victorious_davey" },
	}
	local function yuziDaoMap(suffix)
		return {
			wood_dao = "wood_dao_" .. suffix,
			stone_dao = "stone_dao_" .. suffix,
			iron_dao = "iron_dao_" .. suffix,
			diamond_dao = "diamond_dao_" .. suffix,
			emerald_dao = "emerald_dao_" .. suffix,
		}
	end
	local SKIN_DATA = {
		["Victorious Lyla"] = function(t)
			local lt = t:lower()
			return {
				flower_bow = lt .. "_victorious_flower_bow",
				flower_crossbow = lt .. "_victorious_flower_crossbow",
				flower_headhunter = lt .. "_victorious_flower_headhunter",
			}
		end,
		["Victorious Archer"] = function(t)
			local lt = t:lower()
			return {
				wood_bow = "wood_bow_victorious_" .. lt,
				tactical_crossbow = "tactical_crossbow_victorious_" .. lt,
				tactical_headhunter = "tactical_headhunter_victorious_" .. lt,
			}
		end,
		["Victorious Triton"] = function(t)
			return { harpoon = "victorious_" .. t:lower() .. "_triton" }
		end,
		["Victorious Yuzi"] = function() return yuziDaoMap("victorious") end,
		["Victorious Zeno"] = function(t)
			local lt = t:lower()
			return {
				wizard_staff = lt .. "_victorious_wizard_staff",
				wizard_staff_2 = lt .. "_victorious_wizard_staff_2",
				wizard_staff_3 = lt .. "_victorious_wizard_staff_3",
			}
		end,
	}
	local TIERED_SKINS = {
		["Victorious Lyla"] = true,
		["Victorious Archer"] = true,
		["Victorious Zeno"] = true,
		["Victorious Triton"] = true,
		["Victorious Cannon"] = true,
	}

	local active = {}
	local hideList = {}
	local hookConns = {}
	local renderConn
	local oldGetKitSkin
	local oldFireCannon
	local oldLaunchSelf
	local soundsHooked = false
	local refreshVersion = 0

	local function normalizeName(s)
		return s:lower():gsub('[_%s%-]', '')
	end

	local function isCannonSkin()
		return CANNON_SKIN_NAMES[state.itemSkin] ~= nil
	end

	local function getCannonSkinName()
		local tbl = CANNON_SKIN_NAMES[state.itemSkin]
		if not tbl then return nil end
		return tbl[state.skinType] or tbl.Default
	end

	local function getCurrentMappings()
		local fn = SKIN_DATA[state.itemSkin]
		if not fn then return {} end
		local ok, res = pcall(fn, state.skinType)
		if ok and type(res) == 'table' then return res end
		return {}
	end

	local function getKitSkinValue()
		local m = KIT_SKIN_MAP[state.itemSkin]
		if not m then return nil end
		return m[state.skinType] or m.Default
	end

	local function itemsFolder()
		return RS:FindFirstChild('Items')
	end

	local function blocksFolder()
		local assets = RS:FindFirstChild('Assets')
		return assets and assets:FindFirstChild('Blocks')
	end

	local function firstBasePart(root)
		if root:IsA('BasePart') then return root end
		for _, d in root:GetDescendants() do
			if d:IsA('BasePart') then return d end
		end
		return nil
	end

	local function setNoCollide(model)
		local function strip(p)
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Massless = true
			p.Anchored = false
		end
		if model:IsA('BasePart') then strip(model) end
		for _, d in model:GetDescendants() do
			if d:IsA('BasePart') then strip(d) end
		end
	end

	local function weldAllTo(anchor, container)
		for _, d in container:GetDescendants() do
			if d:IsA('BasePart') and d ~= anchor then
				local wc = Instance.new('WeldConstraint')
				wc.Part0 = anchor
				wc.Part1 = d
				wc.Parent = anchor
			end
		end
	end

	local function getRigScale(root)
		local node = root
		local hum
		for _ = 1, 6 do
			if not node or node == workspace then break end
			hum = node:FindFirstChildOfClass('Humanoid')
			if hum then break end
			node = node.Parent
		end
		if not hum then return 1 end
		local total, count = 0, 0
		for _, name in {'BodyHeightScale', 'BodyWidthScale', 'BodyDepthScale'} do
			local v = hum:FindFirstChild(name)
			if v and v:IsA('NumberValue') and v.Value > 0 then
				total = total + v.Value
				count = count + 1
			end
		end
		if count == 0 then return 1 end
		return math.clamp(total / count, 0.3, 3)
	end

	local function startRenderLoop()
		if renderConn then return end
		renderConn = runService.RenderStepped:Connect(function()
			for i = #hideList, 1, -1 do
				local p = hideList[i]
				if p and p.Parent then
					p.LocalTransparencyModifier = 1
				else
					table.remove(hideList, i)
				end
			end
		end)
	end

	local function stopRenderLoop()
		if renderConn then
			pcall(function() renderConn:Disconnect() end)
			renderConn = nil
		end
	end

	local function hideDescendant(entry, d)
		if d:IsA('BasePart') then
			entry.parts[#entry.parts + 1] = {d, d.Transparency}
			d.Transparency = 1
			d.LocalTransparencyModifier = 1
			hideList[#hideList + 1] = d
		elseif d:IsA('Decal') or d:IsA('Texture') then
			entry.decals[#entry.decals + 1] = {d, d.Transparency}
			d.Transparency = 1
		end
	end

	local function hideOriginal(entry, root)
		for _, d in root:GetDescendants() do
			if not d:IsDescendantOf(entry.clone) then
				hideDescendant(entry, d)
			end
		end
	end

	local function detach(root)
		local entry = active[root]
		if not entry then return end
		active[root] = nil
		for _, c in entry.conns do
			pcall(function() c:Disconnect() end)
		end
		if entry.clone then
			pcall(function() entry.clone:Destroy() end)
		end
		for _, rec in entry.parts do
			local p = rec[1]
			local idx = table.find(hideList, p)
			if idx then table.remove(hideList, idx) end
			pcall(function()
				if p.Parent then
					p.Transparency = rec[2]
					p.LocalTransparencyModifier = 0
				end
			end)
		end
		for _, rec in entry.decals do
			local d = rec[1]
			pcall(function()
				if d.Parent then d.Transparency = rec[2] end
			end)
		end
	end

	local function detachAll()
		for root in active do
			detach(root)
		end
		table.clear(active)
		table.clear(hideList)
	end

	local function attachReskin(root, skinName, source, opts)
		if not root or not root.Parent then return end
		if active[root] or not source then return end
		opts = opts or {}

		local origHandle = root:FindFirstChild('Handle')
		if not (origHandle and origHandle:IsA('BasePart')) then
			origHandle = firstBasePart(root)
		end
		if not origHandle then return end

		local clone = source:Clone()
		clone.Name = RESKIN_NAME
		for _, d in clone:GetDescendants() do
			if d:IsA('LuaSourceContainer') then
				pcall(function() d:Destroy() end)
			end
		end
		setNoCollide(clone)

		local anchor
		local alignByPivot = false
		if clone:IsA('BasePart') then
			anchor = clone
		else
			local handle = clone:FindFirstChild('Handle')
			if handle and handle:IsA('BasePart') then
				anchor = handle
			else
				alignByPivot = true
				anchor = clone:IsA('Model') and clone.PrimaryPart or nil
				anchor = anchor or firstBasePart(clone)
			end
		end
		if not anchor then
			pcall(function() clone:Destroy() end)
			return
		end
		if clone:IsA('Model') and not clone.PrimaryPart then
			pcall(function() clone.PrimaryPart = anchor end)
		end

		local scale = (opts.scale or 1) * getRigScale(root)
		if clone:IsA('Model') and math.abs(scale - 1) > 0.001 then
			pcall(function() clone:ScaleTo(scale) end)
		end

		local entry = {clone = clone, parts = {}, decals = {}, conns = {}}
		active[root] = entry
		clone.Parent = root

		local offset = (SKIN_OFFSETS[skinName] or CFrame.identity) * (opts.offset or CFrame.identity)
		local target = origHandle.CFrame * offset
		pcall(function()
			if not clone:IsA('Model') then
				anchor.CFrame = target
			elseif alignByPivot then
				clone:PivotTo(target)
			else
				clone:PivotTo(target * anchor.CFrame:ToObjectSpace(clone:GetPivot()))
			end
		end)

		weldAllTo(anchor, clone)

		local weld = Instance.new('WeldConstraint')
		weld.Part0 = origHandle
		weld.Part1 = anchor
		weld.Parent = anchor

		hideOriginal(entry, root)
		startRenderLoop()

		entry.conns[#entry.conns + 1] = root.DescendantAdded:Connect(function(d)
			if entry.clone and entry.clone.Parent and d:IsDescendantOf(entry.clone) then return end
			hideDescendant(entry, d)
		end)
		entry.conns[#entry.conns + 1] = root.AncestryChanged:Connect(function(_, parent)
			if not parent then detach(root) end
		end)
	end

	local function track(conn)
		hookConns[#hookConns + 1] = conn
		return conn
	end

	local function clearHooks()
		for _, c in hookConns do
			pcall(function() c:Disconnect() end)
		end
		table.clear(hookConns)
	end

	local function deferCall(fn, ...)
		local args = table.pack(...)
		task.spawn(function()
			task.wait()
			fn(table.unpack(args, 1, args.n))
		end)
	end

	local function skinNameForChild(childName)
		local mappings = getCurrentMappings()
		local skinName = mappings[childName:lower()]
		if not skinName then
			local norm = normalizeName(childName)
			for k, v in mappings do
				if normalizeName(k) == norm then
					skinName = v
					break
				end
			end
		end
		return skinName
	end

	local function applyItem(child)
		if not (VictoriousKitSkins and VictoriousKitSkins.Enabled) then return end
		if isCannonSkin() or not child or not child.Parent then return end
		local skinName = skinNameForChild(child.Name)
		if not skinName then return end
		local folder = itemsFolder()
		if not folder then return end
		attachReskin(child, skinName, folder:FindFirstChild(skinName))
	end

	local function applyCannon(child, placed)
		if not (VictoriousKitSkins and VictoriousKitSkins.Enabled) then return end
		if not isCannonSkin() or not child or not child.Parent then return end
		if child.Name ~= CANNON_TOOL_NAME then return end
		local skinName = getCannonSkinName()
		if not skinName then return end
		local folder = blocksFolder()
		if not folder then return end
		attachReskin(child, skinName, folder:FindFirstChild(skinName), {
			offset = placed and CANNON_PLACED_OFFSET or CFrame.identity,
			scale = placed and 1 or CANNON_HAND_SCALE,
		})
	end

	local function applyProjectile(inst)
		if not (VictoriousKitSkins and VictoriousKitSkins.Enabled) then return end
		if isCannonSkin() or not inst or not inst.Parent then return end
		if not inst:IsA('Model') or inst.Name ~= 'harpoon_projectile' then return end
		local shooter = inst:GetAttribute('ProjectileShooter')
		if not shooter or tostring(shooter) ~= tostring(LocalPlayer.UserId) then return end
		local skinName = getCurrentMappings().harpoon
		if not skinName then return end
		local folder = itemsFolder()
		if not folder then return end
		attachReskin(inst, skinName, folder:FindFirstChild(skinName))
	end

	local function hookItemContainer(container)
		if not container then return end
		for _, child in container:GetChildren() do
			deferCall(applyItem, child)
		end
		track(container.ChildAdded:Connect(function(child)
			deferCall(applyItem, child)
		end))
	end

	local function hookCannonContainer(container, placed)
		if not container then return end
		for _, child in container:GetChildren() do
			deferCall(applyCannon, child, placed)
		end
		track(container.ChildAdded:Connect(function(child)
			deferCall(applyCannon, child, placed)
		end))
	end

	local function hookViewmodel(vm)
		if not vm then return end
		if isCannonSkin() then
			hookCannonContainer(vm, false)
		else
			hookItemContainer(vm)
		end
	end

	local function hookCamera(cam)
		if not cam then return end
		local vm = cam:FindFirstChild('Viewmodel')
		if vm then hookViewmodel(vm) end
		track(cam.ChildAdded:Connect(function(child)
			if child.Name == 'Viewmodel' then
				deferCall(hookViewmodel, child)
			end
		end))
	end

	local function hookWorldCannons()
		local map = workspace:FindFirstChild('Map')
		if not map then return end
		local worlds = map:FindFirstChild('Worlds')
		if not worlds then return end
		local function hookWorld(world)
			local blocks = world:FindFirstChild('Blocks')
			if blocks then hookCannonContainer(blocks, true) end
		end
		for _, world in worlds:GetChildren() do
			hookWorld(world)
		end
		track(worlds.ChildAdded:Connect(function(world)
			deferCall(hookWorld, world)
		end))
	end

	local function hookProjectiles()
		track(workspace.DescendantAdded:Connect(function(inst)
			if inst.Name == 'harpoon_projectile' then
				deferCall(applyProjectile, inst)
			end
		end))
	end

	local function applyKitSkinHook()
		if not KitSkinCtrl then return end
		local val = getKitSkinValue()
		if not val then return end
		if not oldGetKitSkin then oldGetKitSkin = KitSkinCtrl.getKitSkin end
		local base = oldGetKitSkin
		KitSkinCtrl.getKitSkin = function(self, char)
			if char == LocalPlayer.Character then return val end
			return base(self, char)
		end
	end

	local function removeKitSkinHook()
		if KitSkinCtrl and oldGetKitSkin then
			KitSkinCtrl.getKitSkin = oldGetKitSkin
			oldGetKitSkin = nil
		end
	end

	local function hookCannonSounds()
		if soundsHooked then return end
		if not (bedwars and bedwars.CannonHandController) then return end
		soundsHooked = true
		oldFireCannon = bedwars.CannonHandController.fireCannon
		oldLaunchSelf = bedwars.CannonHandController.launchSelf

		local function replaceSound()
			pcall(function()
				local pool = workspace:FindFirstChild('SoundPool')
				if pool then
					for _, v in pool:GetChildren() do
						if v:IsA('Sound') and v.SoundId == 'rbxassetid://7121064180' then
							v:Destroy()
						end
					end
				end
				local key = CANNON_SOUND_NAMES[state.skinType] or CANNON_SOUND_NAMES.Nightmare
				if bedwars.SoundManager and bedwars.SoundList and bedwars.SoundList[key] then
					bedwars.SoundManager:playSound(bedwars.SoundList[key])
				end
			end)
		end

		if oldFireCannon then
			bedwars.CannonHandController.fireCannon = function(...)
				replaceSound()
				return oldFireCannon(...)
			end
		end
		if oldLaunchSelf then
			bedwars.CannonHandController.launchSelf = function(...)
				replaceSound()
				return oldLaunchSelf(...)
			end
		end
	end

	local function unhookCannonSounds()
		if soundsHooked and bedwars and bedwars.CannonHandController then
			if oldFireCannon then bedwars.CannonHandController.fireCannon = oldFireCannon end
			if oldLaunchSelf then bedwars.CannonHandController.launchSelf = oldLaunchSelf end
		end
		oldFireCannon = nil
		oldLaunchSelf = nil
		soundsHooked = false
	end

	local function hookCharacter(char)
		if not char then return end
		local backpack = LocalPlayer:FindFirstChildOfClass('Backpack')
		if isCannonSkin() then
			hookCannonContainer(char, false)
			hookCannonContainer(backpack, false)
		else
			hookItemContainer(char)
			hookItemContainer(backpack)
		end
	end

	local soundItems = {}

	local function applyKitSounds()
		for base, skin in getCurrentMappings() do
			applySkinSounds(base, skin)
			soundItems[base] = true
		end
	end

	local function clearKitSounds()
		for base in soundItems do
			applySkinSounds(base, nil)
		end
		table.clear(soundItems)
	end

	local function setup()
		if not (VictoriousKitSkins and VictoriousKitSkins.Enabled) then return end
		applyKitSkinHook()
		applyKitSounds()
		hookCamera(workspace.CurrentCamera)
		track(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
			if VictoriousKitSkins.Enabled then hookCamera(workspace.CurrentCamera) end
		end))
		if isCannonSkin() then
			hookCannonSounds()
			hookWorldCannons()
		else
			hookProjectiles()
		end
		hookCharacter(LocalPlayer.Character)
		track(LocalPlayer.CharacterAdded:Connect(function(char)
			task.spawn(function()
				task.wait(0.25)
				if not VictoriousKitSkins.Enabled then return end
				applyKitSkinHook()
				hookCharacter(char)
			end)
		end))
	end

	local function teardown()
		clearHooks()
		detachAll()
		stopRenderLoop()
		removeKitSkinHook()
		clearKitSounds()
		unhookCannonSounds()
	end

	local function refresh()
		if not (VictoriousKitSkins and VictoriousKitSkins.Enabled) then return end
		refreshVersion = refreshVersion + 1
		local version = refreshVersion
		teardown()
		task.defer(function()
			if version ~= refreshVersion then return end
			if VictoriousKitSkins.Enabled then setup() end
		end)
	end

	local function syncSkinTypeVisibility()
		if SkinTypeDropdown and SkinTypeDropdown.Object then
			SkinTypeDropdown.Object.Visible = TIERED_SKINS[state.itemSkin] == true
		end
	end

	local skinNames = {}
	local seenNames = {}
	for name in SKIN_DATA do
		if not seenNames[name] then
			seenNames[name] = true
			skinNames[#skinNames + 1] = name
		end
	end
	for name in CANNON_SKIN_NAMES do
		if not seenNames[name] then
			seenNames[name] = true
			skinNames[#skinNames + 1] = name
		end
	end
	table.sort(skinNames)

	VictoriousKitSkins = vape.Categories.Render:CreateModule({
		Name = 'VictoriousKitSkins',
		Function = function(enabled)
			if enabled then
				setup()
			else
				teardown()
			end
		end,
		Tooltip = 'gives u the victorious kit skins with the sounds, only u can see it so dont trip'
	})

	vape:Clean(function() teardown() end)

	ItemSkinDropdown = VictoriousKitSkins:CreateDropdown({
		Name = 'item skin',
		List = skinNames,
		Tooltip = 'which victorious kit u want the skins from',
		Default = state.itemSkin,
		Function = function(val)
			state.itemSkin = val
			if TIERED_SKINS[val] then
				state.skinType = SkinTypeDropdown and SkinTypeDropdown.Value or state.skinType
			else
				state.skinType = 'Default'
			end
			syncSkinTypeVisibility()
			refresh()
		end,
	})

	SkinTypeDropdown = VictoriousKitSkins:CreateDropdown({
		Name = 'skin type',
		List = {'Gold', 'Platinum', 'Diamond', 'Emerald', 'Nightmare', 'Default'},
		Tooltip = 'which tier of the skin u want, nightmare is the hardest one',
		Default = state.skinType,
		Visible = false,
		Function = function(val)
			if not TIERED_SKINS[state.itemSkin] then return end
			state.skinType = val
			refresh()
		end,
	})

	task.spawn(function()
		for _ = 1, 24 do
			syncSkinTypeVisibility()
			task.wait(0.25)
		end
	end)
end)

run(function()
	local SkinChanger
	local Options = {}
	local CategoryToggles = {}
	local skins, families, groups, order = {}, {}, {}, {}
	local names, familyCategory = {}, {}
	local sounds = {}
	local added = setmetatable({}, {__mode = 'k'})
	local watching, lasthand, queued
	local tiers = {leather = true, chainmail = true, wood = true, stone = true, gold = true, iron = true, diamond = true, emerald = true}
	local categories = {'swords', 'projectiles', 'tools', 'misc'}

	local ItemSkinType = {}
	pcall(function()
		ItemSkinType = require(replicatedStorage.TS.games.bedwars['item-skin']['item-skin-types']).ItemSkinType
	end)

	local viewmodelCtrl
	pcall(function()
		viewmodelCtrl = require(replicatedStorage.rbxts_include.node_modules['@easy-games'].knit.src).KnitClient.Controllers.InventoryViewmodelController
	end)

	local function prettyName(text)
		return (tostring(text):gsub('_', ' '):lower())
	end

	local function itemCategory(itemType)
		local meta = bedwars.ItemMeta[itemType]
		if not meta then return 'misc' end
		if meta.sword then return 'swords' end
		if meta.projectileSource then return 'projectiles' end
		if meta.breakBlock then return 'tools' end
		return 'misc'
	end

	for _, v in ItemSkinType do
		local meta = getItemSkinMeta(v)
		local item = meta and meta.itemType and bedwars.ItemMeta[meta.itemType]
		if item and not item.block then
			local label = `_{v}_`
			for i in meta.itemType:gmatch('[^_]+') do
				label = label:gsub(`_{i}_`, '_')
			end
			label = label:gsub('^_+', ''):gsub('_+$', '')
			label = prettyName(label ~= '' and label or v)
			skins[meta.itemType] = skins[meta.itemType] or {}
			skins[meta.itemType][label] = v
		end
	end

	for i in skins do
		local family = i:gsub('_%d+$', '')
		local tier, base = family:match('^([^_]+)_(.+)$')
		family = tier and tiers[tier] and base or family
		if not groups[family] then
			groups[family] = {}
			table.insert(order, family)
			familyCategory[family] = itemCategory(i)
		end
		families[i] = family
		table.insert(groups[family], i)
	end

	for i, v in groups do
		names[i] = prettyName(#v > 1 and i or v[1])
	end
	table.sort(order, function(a, b)
		return names[a] < names[b]
	end)

	local function pickedSkin(itemType)
		local family = SkinChanger.Enabled and families[itemType]
		local option = family and Options[family]
		local label = option and option.Value
		return label and skins[itemType] and skins[itemType][label] or nil
	end

	local function clearModel(accessory)
		local record = added[accessory]
		if not record then return end
		local handle = accessory:FindFirstChild('Handle')
		local template = replicatedStorage.Items:FindFirstChild(accessory.Name)
		for _, v in record.Parts do
			v:Destroy()
		end
		for _, v in handle and handle:GetChildren() or {} do
			local transparency = v:GetAttribute('SkinHidden')
			if transparency then
				v.Transparency = transparency
				v:SetAttribute('SkinHidden', nil)
			end
		end
		added[accessory] = nil
		if handle then
			if template and handle:IsA('MeshPart') and template.Handle:IsA('MeshPart') then
				handle:ApplyMesh(template.Handle)
			end
			handle.Size = record.Size
			local grip = handle:FindFirstChild('RightGripAttachment')
			if grip and record.Grip then
				grip.CFrame = record.Grip
			end
		end
	end

	local function applyModel(accessory)
		local model = pickedSkin(accessory.Name)
		local handle = accessory:FindFirstChild('Handle')
		local template = replicatedStorage.Items:FindFirstChild(model or '')
		if not handle or not template or added[accessory] then return end

		local grip = handle:FindFirstChild('RightGripAttachment')
		local templategrip = template.Handle:FindFirstChild('RightGripAttachment')
		local record = {Parts = {}, Size = handle.Size, Grip = grip and grip.CFrame or nil}
		added[accessory] = record

		for _, v in handle:GetChildren() do
			if v:IsA('BasePart') and v:GetAttribute('SkinHidden') == nil then
				v:SetAttribute('SkinHidden', v.Transparency)
				v.Transparency = 1
			end
		end

		if handle:IsA('MeshPart') and template.Handle:IsA('MeshPart') then
			handle:ApplyMesh(template.Handle)
		end
		handle.Size = template.Handle.Size
		if grip and templategrip then
			grip.CFrame = templategrip.CFrame
		end

		for _, v in template.Handle:GetChildren() do
			if v:IsA('BasePart') then
				local part = v:Clone()
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				part.Massless = true
				part.CFrame = handle.CFrame * (template.Handle.CFrame:Inverse() * v.CFrame)
				part.Parent = handle
				local weld = Instance.new('WeldConstraint')
				weld.Part0 = handle
				weld.Part1 = part
				weld.Parent = part
				table.insert(record.Parts, part)
			end
		end
	end

	local function applySounds()
		for i in skins do
			local skin = pickedSkin(i) or false
			if sounds[i] ~= skin then
				sounds[i] = skin
				applySkinSounds(i, skin or nil)
			end
		end
	end

	local function applySkins()
		applySounds()

		local inventory = store.inventory.inventory
		local changed = false
		for _, v in inventory.items do
			local skin = pickedSkin(v.itemType)
			if v.itemSkin ~= skin then
				v.itemSkin = skin
				changed = true
			end
		end
		if inventory.hand then
			local skin = pickedSkin(inventory.hand.itemType)
			if inventory.hand.itemSkin ~= skin then
				inventory.hand.itemSkin = skin
				changed = true
			end
		end

		local hand = inventory.hand and inventory.hand.itemType
		if not changed and hand == lasthand then return end
		lasthand = hand

		if viewmodelCtrl then
			pcall(function()
				viewmodelCtrl:handleStore(bedwars.Store:getState())
			end)
		end
		if not lplr.Character then return end

		for _, v in lplr.Character:GetChildren() do
			if v:IsA('Accessory') then
				clearModel(v)
				applyModel(v)
			end
		end
	end

	local function queueSkins()
		if queued then return end
		queued = true
		task.defer(function()
			queued = false
			applySkins()
		end)
	end

	local function watchCharacter(char)
		if watching then
			watching:Disconnect()
		end
		watching = char.ChildAdded:Connect(function(v)
			if v:IsA('Accessory') and v:WaitForChild('Handle', 3) and SkinChanger.Enabled then
				applyModel(v)
			end
		end)
	end

	SkinChanger = vape.Categories.Render:CreateModule({
		Name = 'SkinChanger',
		Function = function(callback)
			if callback then
				SkinChanger:Clean(vapeEvents.InventoryChanged.Event:Connect(queueSkins))
				SkinChanger:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(queueSkins))
				SkinChanger:Clean(lplr.CharacterAdded:Connect(function(char)
					lasthand = nil
					watchCharacter(char)
					task.spawn(function()
						for _ = 1, 10 do
							task.wait(0.4)
							if not SkinChanger.Enabled then return end
							applySkins()
						end
					end)
				end))
				if lplr.Character then
					watchCharacter(lplr.Character)
				end
			elseif watching then
				watching:Disconnect()
				watching = nil
			end
			lasthand = nil
			applySkins()
		end,
		Tooltip = 'pick a skin for every item u got, sounds too, only u can see it tho'
	})

	for _, category in categories do
		CategoryToggles[category] = SkinChanger:CreateToggle({
			Name = category,
			Default = false,
			Tooltip = 'shows the skins for ur ' .. category,
			Function = function(callback)
				for family, option in Options do
					if familyCategory[family] == category then
						option.Object.Visible = callback
					end
				end
			end
		})

		for _, family in order do
			if familyCategory[family] == category then
				local list, seen = {}, {}
				for _, itemType in groups[family] do
					for label in skins[itemType] do
						if not seen[label] then
							seen[label] = true
							table.insert(list, label)
						end
					end
				end
				table.sort(list)
				table.insert(list, 1, 'none')
				Options[family] = SkinChanger:CreateDropdown({
					Name = names[family],
					List = list,
					Darker = true,
					Visible = false,
					Function = function()
						if SkinChanger.Enabled then
							lasthand = nil
							applySkins()
						end
					end
				})
			end
		end
	end

	task.defer(function()
		for family, option in Options do
			local toggle = CategoryToggles[familyCategory[family]]
			option.Object.Visible = toggle and toggle.Enabled or false
		end
	end)
end)



run(function()
	local InventoryESP
	local TeamCheck
	local Kits
	local Whitelist
	local Tools
	local Weapon
	local Loot
	local PersonalChest
	local Filter
	local FilterMode
	local FilterRange
	local FilterPlayers
	local SizeToggle
	local SizeSlider
	local warnedNames = {}
	local gui
	local rows = {}
	local thumbCache = {}
	local ICON_SIZE = 18
	local MAX_PER_ROW = 8
	local function teamColor(plr)
		local t = tonumber(plr:GetAttribute('Team'))
		local entry = t and getgenv().aeroTeamColors[t]
		return entry and entry.color or Color3.fromRGB(255, 255, 255)
	end
	local PLACEHOLDER = 'rbxassetid://6031075931' 
	local lootNames = {iron = true, gold = true, diamond = true, emerald = true}

	local function classify(itemType)
		if lootNames[itemType] or itemType:find('iron') or itemType:find('diamond') or itemType:find('emerald') or itemType:find('gold') then
			return 'loot'
		end
		local meta = bedwars.ItemMeta[itemType]
		if meta then
			if meta.sword or meta.projectile or meta.projectileSource or itemType:find('bow') or itemType:find('sword') then
				return 'weapon'
			end
			if meta.breakBlock or itemType:find('pickaxe') or itemType:find('axe') or itemType:find('shear') then
				return 'tool'
			end
		end
		return 'etc'
	end

	local function passesWhitelist(itemType)
		if not Whitelist.Enabled then return true end
		local c = classify(itemType)
		if c == 'tool' then return Tools.Enabled end
		if c == 'weapon' then return Weapon.Enabled end
		if c == 'loot' then return Loot.Enabled end
		return false 
	end

	local function applySize()
		if not gui or not gui:FindFirstChild('Holder') then return end
		local s = (SizeToggle and SizeToggle.Enabled and SizeSlider) and SizeSlider.Value or 1
		local holder = gui.Holder
		local hs = holder:FindFirstChild('HolderScale') or Instance.new('UIScale')
		hs.Name = 'HolderScale'
		hs.Scale = s
		hs.Parent = holder
		holder.Size = UDim2.new(0, 190, 0.9 / s, 0)
	end

	local function makeGui()
		gui = Instance.new('ScreenGui')
		gui.Name = 'InventoryESP'
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.DisplayOrder = 50
		pcall(function() gui.Parent = gethui and gethui() or game:GetService('CoreGui') end)
		if not gui.Parent then gui.Parent = lplr:WaitForChild('PlayerGui') end

		local holder = Instance.new('Frame')
		holder.Name = 'Holder'
		holder.AnchorPoint = Vector2.new(1, 0.5)
		holder.Position = UDim2.new(1, -2, 0.5, 0)
		holder.Size = UDim2.new(0, 190, 0.9, 0)
		holder.BackgroundTransparency = 1
		holder.Parent = gui

		local list = Instance.new('UIListLayout')
		list.FillDirection = Enum.FillDirection.Vertical
		list.HorizontalAlignment = Enum.HorizontalAlignment.Left
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Padding = UDim.new(0, 4)
		list.SortOrder = Enum.SortOrder.Name
		list.Parent = holder
		applySize()
	end

	local function getThumb(userId)
		if not thumbCache[userId] then
			thumbCache[userId] = 'rbxthumb://type=AvatarHeadShot&id=' .. userId .. '&w=150&h=150'
		end
		return thumbCache[userId]
	end

	local function invFolder(plr, personal)
		local inv = replicatedStorage:FindFirstChild('Inventories')
		if not inv then return nil end
		return inv:FindFirstChild(personal and (plr.Name .. '_personal') or plr.Name)
	end

	local function makeSection(parent, titleText)
		local wrap = Instance.new('Frame')
		wrap.Name = titleText
		wrap.BackgroundTransparency = 1
		wrap.Size = UDim2.new(1, 0, 0, 0)
		wrap.AutomaticSize = Enum.AutomaticSize.Y
		wrap.Parent = parent

		local wl = Instance.new('UIListLayout')
		wl.Padding = UDim.new(0, 2)
		wl.SortOrder = Enum.SortOrder.LayoutOrder
		wl.Parent = wrap

		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.LayoutOrder = 0
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, 0, 0, 12)
		title.Text = titleText
		title.TextColor3 = Color3.fromRGB(160, 200, 255)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextSize = 11
		title.Font = Enum.Font.GothamBold
		title.Parent = wrap

		local grid = Instance.new('Frame')
		grid.Name = 'Grid'
		grid.LayoutOrder = 1
		grid.BackgroundTransparency = 1
		grid.Size = UDim2.new(1, 0, 0, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		grid.Parent = wrap

		local gl = Instance.new('UIGridLayout')
		gl.CellSize = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
		gl.CellPadding = UDim2.new(0, 3, 0, 3)
		gl.FillDirectionMaxCells = MAX_PER_ROW
		gl.SortOrder = Enum.SortOrder.LayoutOrder
		gl.Parent = grid

		return {wrap = wrap, grid = grid, title = title, icons = {}}
	end

	local function buildRow(plr)
		local frame = Instance.new('Frame')
		frame.Name = plr.Name
		frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
		frame.BackgroundTransparency = 0.25
		frame.BorderSizePixel = 0
		frame.Size = UDim2.new(1, 0, 0, 44)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.Parent = gui.Holder
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = frame
		local stroke = Instance.new('UIStroke')
		stroke.Thickness = 1
		stroke.Color = Color3.fromRGB(60, 60, 70)
		stroke.Transparency = 0.3
		stroke.Parent = frame
		local pad = Instance.new('UIPadding')
		pad.PaddingLeft = UDim.new(0, 4)
		pad.PaddingRight = UDim.new(0, 4)
		pad.PaddingTop = UDim.new(0, 3)
		pad.PaddingBottom = UDim.new(0, 3)
		pad.Parent = frame
		local left = Instance.new('Frame')
		left.Name = 'Left'
		left.BackgroundTransparency = 1
		left.Size = UDim2.new(0, 30, 1, 0)
		left.Parent = frame
		local name = Instance.new('TextLabel')
		name.Name = 'PName'
		name.BackgroundTransparency = 1
		name.Position = UDim2.new(0, 0, 0, 0)
		name.Size = UDim2.new(1, 0, 0, 12)
		name.Text = plr.DisplayName or plr.Name
		name.TextColor3 = teamColor(plr)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextSize = 11
		name.Font = Enum.Font.GothamBold
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.ZIndex = 3
		name.Parent = frame
		local face = Instance.new('ImageLabel')
		face.Name = 'Face'
		face.AnchorPoint = Vector2.new(0.5, 0)
		face.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
		face.Size = UDim2.new(0, 24, 0, 24)
		face.Position = UDim2.new(0.5, 0, 0, 16) 
		face.Image = getThumb(plr.UserId)
		face.Parent = left
		local fc = Instance.new('UICorner')
		fc.CornerRadius = UDim.new(1, 0)
		fc.Parent = face
		local fs = Instance.new('UIStroke')
		fs.Thickness = 1.5
		fs.Color = teamColor(plr)
		fs.Parent = face
		local right = Instance.new('Frame')
		right.Name = 'Right'
		right.BackgroundTransparency = 1
		right.Position = UDim2.new(0, 34, 0, 14)
		right.Size = UDim2.new(1, -34, 0, 0)
		right.AutomaticSize = Enum.AutomaticSize.Y
		right.Parent = frame
		local rl = Instance.new('UIListLayout')
		rl.Padding = UDim.new(0, 4)
		rl.SortOrder = Enum.SortOrder.LayoutOrder
		rl.Parent = right

		local kiticon = Instance.new('ImageLabel')
		kiticon.Name = 'KitIcon'
		kiticon.AnchorPoint = Vector2.new(1, 0)
		kiticon.Position = UDim2.new(1, -2, 0, 0)
		kiticon.Size = UDim2.new(0, 20, 0, 20)
		kiticon.BackgroundTransparency = 1
		kiticon.ScaleType = Enum.ScaleType.Fit
		kiticon.Visible = false
		kiticon.ZIndex = 4
		kiticon.Parent = frame

		rows[plr] = {
			frame = frame,
			pname = name,
			pstroke = fs,
			kiticon = kiticon,
			inv = makeSection(right, 'Inventory'),
			personal = makeSection(right, 'Personal')
		}
		rows[plr].inv.wrap.LayoutOrder = 0
		rows[plr].personal.wrap.LayoutOrder = 1
		return rows[plr]
	end

	local function updateSection(section, folder, personalMode)
		local seen = {}
		local order = 0
		if folder then
			for _, item in folder:GetChildren() do
				local itemType = item.Name
				if personalMode or passesWhitelist(itemType) then
					seen[itemType] = true
					order += 1
					local icon = section.icons[itemType]
					if not icon then
						icon = Instance.new('ImageLabel')
						icon.Name = itemType
						icon.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
						icon.BackgroundTransparency = 0.2
						icon.ClipsDescendants = false
						icon.Parent = section.grid
						local ic = Instance.new('UICorner')
						ic.CornerRadius = UDim.new(0, 4)
						ic.Parent = icon
						local amt = Instance.new('TextLabel')
						amt.Name = 'Amt'
						amt.BackgroundTransparency = 1
						amt.Size = UDim2.new(1, -1, 1, -1)
						amt.Position = UDim2.new(0, 0, 0, 0)
						amt.TextColor3 = Color3.fromRGB(255, 255, 255)
						amt.TextStrokeTransparency = 0
						amt.TextXAlignment = Enum.TextXAlignment.Right
						amt.TextYAlignment = Enum.TextYAlignment.Bottom
						amt.TextSize = 10
						amt.ZIndex = 2
						amt.TextScaled = false
						amt.Font = Enum.Font.GothamBold
						amt.Parent = icon
						local img = PLACEHOLDER
						pcall(function()
							local got = bedwars.getIcon({itemType = itemType}, true)
							if got and got ~= '' then img = got end
						end)
						icon.Image = img
						section.icons[itemType] = icon
					end
					icon.LayoutOrder = order
					local count = item:GetAttribute('Amount') or item:GetAttribute('amount') or item:GetAttribute('Count')
					icon.Amt.Text = (count and count > 1) and tostring(count) or ''
				end
			end
		end
		for iname, icon in section.icons do
			if not seen[iname] then
				icon:Destroy()
				section.icons[iname] = nil
			end
		end
		section.wrap.Visible = order > 0
	end

	local function passesFilter(plr)
		if not Filter or not Filter.Enabled then return true end
		if FilterMode.Value == 'Range' then
			local myRoot = entitylib.character and entitylib.character.RootPart
			local theirRoot = plr.Character and plr.Character:FindFirstChild('HumanoidRootPart')
			if not myRoot or not theirRoot then return false end
			return (theirRoot.Position - myRoot.Position).Magnitude <= FilterRange.Value
		end
		if FilterMode.Value == 'Players' then
			local list = FilterPlayers.ListEnabled
			if #list == 0 then return false end
			local lname = plr.Name:lower()
			local ldisp = plr.DisplayName:lower()
			for _, v in list do
				local lv = tostring(v):lower()
				if lv == lname or lv == ldisp then return true end
			end
			return false
		end
		return true
	end

	local function removeRow(plr)
		if rows[plr] then
			rows[plr].frame:Destroy()
			rows[plr] = nil
		end
	end

	InventoryESP = vape.Categories.Render:CreateModule({
		Name = 'InventoryESP',
		Function = function(callback)
			if callback then
				makeGui()
				repeat
					local myTeam = lplr:GetAttribute('Team')
					for _, plr in playersService:GetPlayers() do
						local skip = false
						if TeamCheck.Enabled and (plr == lplr or (plr:GetAttribute('Team') and plr:GetAttribute('Team') == myTeam)) then
							skip = true
						end
						if not skip and plr ~= lplr and not passesFilter(plr) then
							skip = true
						end
						if skip then
							removeRow(plr)
						else
							local liveInv = invFolder(plr, false)
							local personalInv = PersonalChest.Enabled and invFolder(plr, true) or nil
							local anything = (liveInv and #liveInv:GetChildren() > 0) or (personalInv and #personalInv:GetChildren() > 0)
							if anything then
								local row = rows[plr] or buildRow(plr)
								local col = teamColor(plr)
								row.pname.TextColor3 = col
								row.pstroke.Color = col
								if Kits.Enabled then
									local kit = plr:GetAttribute('PlayingAsKits')
									local kitImage = kit and kitImageIds[kit:lower()]
									row.kiticon.Image = kitImage or kitImageIds['none']
									row.kiticon.Visible = true
								else
									row.kiticon.Visible = false
								end
								updateSection(row.inv, liveInv, false)
								updateSection(row.personal, personalInv, true)
								row.personal.wrap.Visible = PersonalChest.Enabled and row.personal.wrap.Visible
							else
								removeRow(plr)
							end
						end
					end
					for plr in rows do
						if not plr.Parent then removeRow(plr) end
					end
					task.wait(0.5)
				until not InventoryESP.Enabled
			else
				for plr in rows do removeRow(plr) end
				rows = {}
				if gui then gui:Destroy() gui = nil end
			end
		end,
		Tooltip = 'shows what everyone has in their inventory (n chest) on the side gng'
	})

	Whitelist = InventoryESP:CreateToggle({
		Name = 'Whitelist',
		Tooltip = 'only show the categories u pick below',
		Function = function(callback)
			if Tools then Tools.Object.Visible = callback end
			if Weapon then Weapon.Object.Visible = callback end
			if Loot then Loot.Object.Visible = callback end
		end
	})
	Tools = InventoryESP:CreateToggle({
		Name = 'Tools',
		Default = true,
		Darker = true,
		Visible = false,
		Tooltip = 'pickaxes, axes, shears'
	})
	Weapon = InventoryESP:CreateToggle({
		Name = 'Weapon',
		Default = true,
		Darker = true,
		Visible = false,
		Tooltip = 'swords n projectiles'
	})
	Loot = InventoryESP:CreateToggle({
		Name = 'Loot',
		Default = true,
		Darker = true,
		Visible = false,
		Tooltip = 'iron, gold, diamond, emerald'
	})
	PersonalChest = InventoryESP:CreateToggle({
		Name = 'Personal Chest',
		Tooltip = 'also show their personal chest items'
	})
	TeamCheck = InventoryESP:CreateToggle({
		Name = 'Team check',
		Default = true,
		Tooltip = 'dont show ppl on ur team'
	})

	Kits = InventoryESP:CreateToggle({
		Name = 'Kits',
		Default = false,
		Tooltip = 'puts the kit icon next to each persons name'
	})

	SizeToggle = InventoryESP:CreateToggle({
		Name = 'Custom Size',
		Function = function(callback)
			if SizeSlider then SizeSlider.Object.Visible = callback end
			applySize()
		end,
		Tooltip = 'turn on to pick ur own size for the inventory esp'
	})

	SizeSlider = InventoryESP:CreateSlider({
		Name = 'Size',
		Min = 0.5,
		Max = 2.5,
		Default = 1.3,
		Decimal = 10,
		Darker = true,
		Visible = false,
		Function = function()
			applySize()
		end,
		Tooltip = 'makes the inventory esp bigger or smaller gng'
	})

	local function syncFilterVisibility()
		local on = Filter and Filter.Enabled
		if FilterMode then FilterMode.Object.Visible = on end
		if FilterRange then FilterRange.Object.Visible = on and FilterMode.Value == 'Range' end
		if FilterPlayers then FilterPlayers.Object.Visible = on and FilterMode.Value == 'Players' end
	end

	Filter = InventoryESP:CreateToggle({
		Name = 'Filter',
		Default = false,
		Tooltip = 'only show certain ppl instead of everyone',
		Function = function()
			syncFilterVisibility()
		end
	})

	FilterMode = InventoryESP:CreateDropdown({
		Name = 'Filter Mode',
		List = {'Range', 'Players'},
		Default = 'Range',
		Darker = true,
		Visible = false,
		Tooltip = 'range = ppl close to u, players = only the ppl u type in',
		Function = function()
			syncFilterVisibility()
		end
	})

	FilterRange = InventoryESP:CreateSlider({
		Name = 'Filter Range',
		Min = 1,
		Max = 30,
		Default = 20,
		Darker = true,
		Visible = false,
		Tooltip = 'only show ppl this close to u, they disappear when they leave',
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})

	FilterPlayers = InventoryESP:CreateTextList({
		Name = 'Filter Players',
		Darker = true,
		Visible = false,
		Placeholder = 'username...',
		Tooltip = 'only show the ppl u add here',
		Function = function(list)
			for _, v in list do
				local lv = tostring(v):lower()
				if not warnedNames[lv] then
					local found = false
					for _, p in playersService:GetPlayers() do
						if p.Name:lower() == lv or p.DisplayName:lower() == lv then
							found = true
							break
						end
					end
					if not found then
						warnedNames[lv] = true
						notif('InventoryESP', tostring(v)..' aint in this game gng', 4)
					end
				end
			end
		end
	})

	task.defer(syncFilterVisibility)
end)

run(function()
    local DamageTexts = {Enabled = false}
	local Color
    local connection
	local Fonts
	local customMSG
	local DamageMessages = {
		'fuck',
		'shit',
		'damn',
		'hell',
		'bitch',
		'ass',
		'piss',
		'cock',
		'motherfucker',
		'fucker',
		'shitter',
		'bastard',
		'asshole',
		'get fucked',
		'eat shit',
		'suck it',
		'die',
		'kill',
		'smash',
		'crush',
		'break',
		'wreck',
		'destroy',
		'annihilate',
		'obliterate',
		'decimate',
		'massacre',
		'slaughter',
		'fuck you',
		'shithead',
		'dick',
		'pussy',
		'twat',
		'wanker',
		'bugger',
		'bloody hell',
		'goddamn',
		'holy shit',
		'what the fuck',
		'oh fuck',
		'fucking hell',
		'shitty',
		'crappy',
		'lousy',
		'motherfucking',
		'goddamn shit',
		'fuckface',
		'dipshit',
		'dumbshit',
		'jackass',
		'prick',
		'cocksucker',
		'asshat',
		'buttfuck',
		'fucknut',
		'shitbag',
		'hellfire',
		'fuckshit',
		'damnass',
		'piss off',
		'screw you',
		'bastard shit',
		'fucktard',
		'shitfuck',
		'cunt',
	    'bitchass nigga',
		'nigga',
		'die pls',
		'desire is some ass',
	}
	
	local RGBColors = {
		Color3.fromRGB(255, 255, 255), 
		Color3.fromRGB(0, 0, 0),       
		Color3.fromRGB(128, 0, 128), 
		Color3.fromRGB(0, 0, 255),  
		Color3.fromRGB(75, 0, 130),    
		Color3.fromRGB(0, 100, 255), 
		Color3.fromRGB(200, 200, 255),
		Color3.fromRGB(30, 30, 30)  
	}
	
	local function randomizer(tbl)
	    if not typeof(tbl) == "table" then return end
	    local index = math.random(1,#tbl)
	    local value = tbl[index]
	    return value,index
	end
	local font  = 'Arial'
    DamageTexts = vape.Categories.Render:CreateModule({
        Name = "DamageTexts",
        Function = function(call)
			if call then
				DamageTexts:Clean(workspace.DescendantAdded:Connect(function(part)
				    if part.Name == "DamageIndicatorPart" and part:IsA("BasePart") then
				        for i, v in part:GetDescendants() do
				            if v:IsA("TextLabel") then
				                local txt = randomizer(DamageMessages)
				                local clr = randomizer(RGBColors)
								if customMSG.Enabled then
				                	v.Text = txt
								end
								if Color.Enabled then
				              	  	v.TextColor3 = clr
								end
				            end
				        end
				    end
				end))
			else

			end
        end,
        Tooltip = "Customizes Damage Affects"
    })
	customMSG = DamageTexts:CreateToggle({
		Name = "Custom Messages",
		Default = true
	})
	Color = DamageTexts:CreateToggle({
		Name = "Custom Colors",
		Default = true
	})
	Fonts = DamageTexts:CreateFont({
		Name = 'Font',
		Function = function(val)
			font = val
		end
	})
end)

run(function()
	local PotESP
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local tracked = {}
	local function getSandIcon()
		local ok, icon = pcall(function() return bedwars.getIcon({itemType = 'sand'}, true) end)
		return ok and icon or 'rbxassetid://0'
	end
	local function createESP(obj)
		if tracked[obj] then return end
		if obj.Name:lower() ~= 'desert_pot' then return end
		local bill = Instance.new('BillboardGui')
		bill.Size = UDim2.fromOffset(40, 40)
		bill.Adornee = obj
		bill.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		bill.AlwaysOnTop = true
		bill.Parent = Folder
		local frame = Instance.new('Frame')
		frame.Size = UDim2.new(1, 0, 1, 0)
		frame.BackgroundTransparency = 0.4
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BorderSizePixel = 0
		frame.Parent = bill
		local uic = Instance.new('UICorner')
		uic.CornerRadius = UDim.new(0, 4)
		uic.Parent = frame
		local image = Instance.new('ImageLabel')
		image.Size = UDim2.new(1, -6, 1, -6)
		image.Position = UDim2.new(0.5, 0, 0.5, 0)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundTransparency = 1
		image.Image = getSandIcon()
		image.Parent = frame
		tracked[obj] = bill
	end
	local function removeESP(obj)
		if tracked[obj] then
			tracked[obj]:Destroy()
			tracked[obj] = nil
		end
	end
	local function scanAll()
		scanDescendants(workspace, function(obj)
			createESP(obj)
		end)
	end
	local function cleanup()
		for _, bill in pairs(tracked) do
			bill:Destroy()
		end
		table.clear(tracked)
	end
	PotESP = vape.Categories.Render:CreateModule({
		Name = 'PotESP',
		Function = function(callback)
			if callback then
				scanAll()
				PotESP:Clean(workspace.DescendantAdded:Connect(function(obj)
					task.wait(0.1)
					if obj.Name:lower() == 'desert_pot' then
						createESP(obj)
					end
				end))
				PotESP:Clean(workspace.DescendantRemoving:Connect(function(obj)
					if obj.Name:lower() == 'desert_pot' then
						removeESP(obj)
					end
				end))
			else
				cleanup()
			end
		end,
		Tooltip = 'shows a sand block icon above each desert pot'
	})
end)

run(function()
	local OreESP
	local Background
	local Color
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local tracked = {}
	local function getIronIcon()
		local ok, icon = pcall(function() return bedwars.getIcon({itemType = 'iron'}, true) end)
		return ok and icon or 'rbxassetid://0'
	end
	local function createESP(obj)
		if tracked[obj] then return end
		if obj.Name:lower() ~= 'iron_ore_mesh_block' then return end
		local bill = Instance.new('BillboardGui')
		bill.Size = UDim2.fromOffset(40, 40)
		bill.Adornee = obj
		bill.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		bill.AlwaysOnTop = true
		bill.Parent = Folder
		local frame = Instance.new('Frame')
		frame.Size = UDim2.new(1, 0, 1, 0)
		frame.BackgroundTransparency = Background.Enabled and 0.4 or 1
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BorderSizePixel = 0
		frame.Parent = bill
		local uic = Instance.new('UICorner')
		uic.CornerRadius = UDim.new(0, 4)
		uic.Parent = frame
		local image = Instance.new('ImageLabel')
		image.Size = UDim2.new(1, -6, 1, -6)
		image.Position = UDim2.new(0.5, 0, 0.5, 0)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundTransparency = 1
		image.Image = getIronIcon()
		image.Parent = frame
		tracked[obj] = {Billboard = bill, Frame = frame}
	end
	local function removeESP(obj)
		if tracked[obj] then
			tracked[obj].Billboard:Destroy()
			tracked[obj] = nil
		end
	end
	local function scanAll()
		scanDescendants(workspace, function(obj)
			createESP(obj)
		end)
	end
	local function cleanup()
		for _, v in pairs(tracked) do
			v.Billboard:Destroy()
		end
		table.clear(tracked)
	end
	OreESP = vape.Categories.Render:CreateModule({
		Name = 'OreESP',
		Function = function(callback)
			if callback then
				scanAll()
				OreESP:Clean(workspace.DescendantAdded:Connect(function(obj)
					task.wait(0.1)
					if obj.Name:lower() == 'iron_ore_mesh_block' then
						createESP(obj)
					end
				end))
				OreESP:Clean(workspace.DescendantRemoving:Connect(function(obj)
					if obj.Name:lower() == 'iron_ore_mesh_block' then
						removeESP(obj)
					end
				end))
			else
				cleanup()
			end
		end,
		Tooltip = 'puts an icon above iron ore blocks so u can find em? - idea from piston the goat'
	})
	Background = OreESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color and Color.Object then Color.Object.Visible = callback end
			for _, v in pairs(tracked) do
				v.Frame.BackgroundTransparency = callback and 0.4 or 1
			end
		end,
		Default = true
	})
	Color = OreESP:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.6,
		Function = function(hue, sat, val, opacity)
			for _, v in pairs(tracked) do
				v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.Frame.BackgroundTransparency = 1 - opacity
			end
		end,
		Darker = true
	})
	task.defer(function()
		if Color and Color.Object then
			Color.Object.Visible = Background.Enabled
		end
	end)
end)

--[[
	Utility Mobule
]]

run(function()
	local AutoEnchant
	local EnchantPick
	local UnlockTable
	local EnchantRange
	local netFolder
	local enchantInfo = {}
	local tableCost
	local diamondType
	local anyTeamTable = false

	local researchRemotes = {
		EnchantMeta = 'ResearchEnchant',
		ArmorEnchantMeta = 'ResearchArmorEnchant',
		ToolEnchantMeta = 'ResearchToolEnchant'
	}

	task.spawn(function()
		netFolder = replicatedStorage:WaitForChild('rbxts_include'):WaitForChild('node_modules'):WaitForChild('@rbxts'):WaitForChild('net'):WaitForChild('out'):WaitForChild('_NetManaged')
	end)

	task.spawn(function()
		pcall(function()
			local meta = require(replicatedStorage.TS.enchant['enchant-meta'])
			for group, remoteName in researchRemotes do
				for _, v in meta[group] or {} do
					if type(v) == 'table' and type(v.name) == 'string' and v.statusEffect then
						local lower = v.name:lower()
						for _, want in {'static', 'forest'} do
							if lower:find(want) and not enchantInfo[want] then
								enchantInfo[want] = {effect = v.statusEffect, remote = remoteName}
							end
						end
					end
				end
			end
		end)
		pcall(function()
			tableCost = require(replicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-util']).TeamUpgradeUtil.ENCHANT_TABLE_COST
		end)
		pcall(function()
			diamondType = require(replicatedStorage.TS.item['item-type']).ItemType.DIAMOND
		end)
		pcall(function()
			anyTeamTable = require(replicatedStorage.TS.enchant['enchant-util']).EnchantBalance.USE_ENCHANT_TABLE_ANY_TEAM == true
		end)
	end)

	local function hasEnchant(info)
		local char = lplr.Character
		local val = char and char:GetAttribute('StatusEffect_' .. tostring(info.effect))
		return type(val) == 'number' and val < 0
	end

	local function closestTable(tag, needTeam)
		local root = entitylib.character and entitylib.character.RootPart
		if not root then return nil end
		local myTeam = lplr:GetAttribute('Team')
		local best, bestDist = nil, EnchantRange.Value
		for _, v in collectionService:GetTagged(tag) do
			if v:IsA('BasePart') and (not needTeam or v:GetAttribute('Team') == myTeam) then
				local dist = (v.Position - root.Position).Magnitude
				if dist <= bestDist then
					best, bestDist = v, dist
				end
			end
		end
		return best
	end

	local function invoke(name, ...)
		local remote = netFolder and netFolder:FindFirstChild(name)
		if not remote then return end
		local args = table.pack(...)
		pcall(function()
			remote:InvokeServer(table.unpack(args, 1, args.n))
		end)
	end

	AutoEnchant = vape.Categories.Utility:CreateModule({
		Name = 'AutoEnchant',
		Function = function(callback)
			if callback then
				repeat
					local waitTime = 0.5
					if entitylib.isAlive and netFolder then
						local broken = UnlockTable.Enabled and closestTable('broken-enchant-table', true)
						local diamonds = diamondType and getItem(diamondType)
						if broken and (not tableCost or (diamonds and diamonds.amount >= tableCost)) then
							invoke('RepairEnchantTable', broken)
							waitTime = 2
						else
							local info = enchantInfo[EnchantPick.Value]
							if info and not hasEnchant(info) then
								local enchantTable = closestTable('enchant-table', not anyTeamTable)
								if enchantTable then
									invoke(info.remote, {enchantTable = enchantTable})
									waitTime = 1.5
								end
							end
						end
					end
					task.wait(waitTime)
				until not AutoEnchant.Enabled
			end
		end,
		Tooltip = 'auto rolls the enchant table till u get the enchant u picked'
	})

	EnchantPick = AutoEnchant:CreateDropdown({
		Name = 'enchant',
		List = {'static', 'forest'},
		Tooltip = 'which enchant u tryna get gng'
	})

	UnlockTable = AutoEnchant:CreateToggle({
		Name = 'Unlock Enchant Table',
		Default = true,
		Tooltip = 'fixes ur team enchant table for u when u got the diamonds'
	})

	EnchantRange = AutoEnchant:CreateSlider({
		Name = 'range',
		Min = 1,
		Max = 20,
		Default = 6,
		Suffix = function(val) return val == 1 and 'stud' or 'studs' end,
		Tooltip = 'how close u gotta be to the table for it to work'
	})
end)

run(function()
	local CheatDetector
	local SelfTest
	local toggles = {}

	local SAMPLE_STEP = 0.05
	local HISTORY_TIME = 2
	local FLAG_SCORE = 70
	local SCORE_DECAY = 1.2
	local REASON_LIFE = 25
	local REASON_COOLDOWN = 6

	local tips = {
		Speed = 'catches ppl movin way too fast',
		Reach = 'catches ppl hittin u from too far away',
		Killaura = 'catches ppl hittin mad fast or behind them',
		Fly = 'catches ppl floatin in the air'
	}

	local history = {}
	local meta = {}
	local score = {}
	local flagged = {}
	local reachStreak = {}
	local airTime = {}
	local speedTime = {}
	local kaData = {}

	local function resetPlayer(plr)
		history[plr] = nil
		meta[plr] = nil
		score[plr] = nil
		reachStreak[plr] = nil
		airTime[plr] = nil
		speedTime[plr] = nil
		kaData[plr] = nil
	end

	local function resetAll()
		table.clear(history)
		table.clear(meta)
		table.clear(score)
		table.clear(flagged)
		table.clear(reachStreak)
		table.clear(airTime)
		table.clear(speedTime)
		table.clear(kaData)
	end

	local function isOn(name)
		local t = toggles[name]
		return t and t.Enabled
	end

	local function notSelf(plr)
		return plr ~= lplr or (SelfTest and SelfTest.Enabled)
	end

	local function getEntities()
		if SelfTest and SelfTest.Enabled and entitylib.character then
			local list = table.clone(entitylib.List)
			table.insert(list, entitylib.character)
			return list
		end
		return entitylib.List
	end

	local function flagPlayer(plr, reasons)
		local key = tostring(plr)
		local now = os.clock()
		if flagged[key] and now < flagged[key] then return end
		flagged[key] = now + 20
		notif('CheatDetector', 'yo '..(plr.DisplayName or plr.Name)..' is prob cheatin -> '..reasons, 12, 'alert')
	end

	local function addScore(plr, amount, reason, label)
		if not plr then return end
		local now = os.clock()
		local s = score[plr]
		if not s then
			s = {value = 0, seen = {}, labels = {}, last = now}
			score[plr] = s
		end
		if s.seen[reason] and now - s.seen[reason] < REASON_COOLDOWN then return end
		s.seen[reason] = now
		s.labels[reason] = label
		s.value = s.value + amount
		if s.value >= FLAG_SCORE then
			local list = {}
			for r in s.labels do
				list[#list + 1] = s.labels[r]
			end
			table.sort(list)
			flagPlayer(plr, table.concat(list, ' + '))
			s.value = 0
			table.clear(s.seen)
			table.clear(s.labels)
		end
	end

	local function pushSample(plr, ent)
		local root = ent.RootPart
		if not root then return end
		local h = history[plr]
		if not h then
			h = {}
			history[plr] = h
		end
		local now = os.clock()
		local cf = root.CFrame
		h[#h + 1] = {t = now, pos = cf.Position, look = cf.LookVector, vel = root.AssemblyLinearVelocity}
		while h[1] and now - h[1].t > HISTORY_TIME do
			table.remove(h, 1)
		end
	end

	local function trackMeta(plr, ent)
		local now = os.clock()
		local m = meta[plr]
		if not m then
			m = {spawn = now, lastMove = now, lastDamaged = 0, char = ent.Character}
			meta[plr] = m
		end
		if m.char ~= ent.Character then
			m.char = ent.Character
			m.spawn = now
			m.lastMove = now
			m.lastPos = nil
			history[plr] = nil
			reachStreak[plr] = nil
			airTime[plr] = nil
			speedTime[plr] = nil
		end
		local root = ent.RootPart
		if root then
			if not m.lastPos or (root.Position - m.lastPos).Magnitude > 0.05 then
				m.lastMove = now
			end
			m.lastPos = root.Position
		end
		return m
	end

	local function getHumanoid(ent)
		if ent.Humanoid then return ent.Humanoid end
		return ent.Character and ent.Character:FindFirstChildOfClass('Humanoid')
	end

	local function trusted(plr, ent)
		if not plr or not ent then return false end
		local char = ent.Character
		local root = ent.RootPart
		if not char or not root or not char.Parent or not root.Parent then return false end
		local m = meta[plr]
		if not m then return false end
		local now = os.clock()
		if now - m.spawn < 3 then return false end
		if now - m.lastMove > 0.35 then return false end
		local hum = getHumanoid(ent)
		if not hum or hum.Health <= 0 then return false end
		if (char:GetAttribute('InflatedBalloons') or 0) > 0 then return false end
		local serverNow = workspace:GetServerTimeNow()
		if serverNow - (plr:GetAttribute('LastTeleported') or 0) < 1.5 then return false end
		local stun = char:GetAttribute('StunnedUntilTime')
		if stun and stun > serverNow - 1 then return false end
		local dashNext = char:GetAttribute('CanDashNext')
		if dashNext and dashNext > serverNow then return false end
		if lplr:GetNetworkPing() > 0.15 then return false end
		local h = history[plr]
		if not h or #h < 8 then return false end
		return true
	end

	local function minDistanceTo(plr, point, window)
		local h = history[plr]
		if not h or #h == 0 then return nil end
		local now = os.clock()
		local best
		for i = #h, 1, -1 do
			local s = h[i]
			if now - s.t > window then break end
			local d = (s.pos - point).Magnitude
			if not best or d < best then best = d end
		end
		return best
	end

	local function minPairDistance(a, b, window)
		local ha, hb = history[a], history[b]
		if not ha or not hb then return nil end
		local now = os.clock()
		local best
		for i = #ha, 1, -1 do
			if now - ha[i].t > window then break end
			for j = #hb, 1, -1 do
				if now - hb[j].t > window then break end
				if math.abs(ha[i].t - hb[j].t) <= 0.12 then
					local d = (ha[i].pos - hb[j].pos).Magnitude
					if not best or d < best then best = d end
				end
			end
		end
		return best
	end

	local function recentSample(plr)
		local h = history[plr]
		if not h or #h == 0 then return nil end
		local ping = math.clamp(lplr:GetNetworkPing() * 0.5, 0, 0.3)
		local target = os.clock() - ping
		local best, bestDiff
		for i = #h, 1, -1 do
			local diff = math.abs(h[i].t - target)
			if not bestDiff or diff < bestDiff then
				best = h[i]
				bestDiff = diff
			end
		end
		return best
	end

	local function getAttackRange(plr)
		local inv = store.inventories[plr]
		local hand = inv and inv.hand
		local name = hand and hand.tool and hand.tool.Name
		if not name then return nil end
		local itemMeta = bedwars.ItemMeta[name]
		local swordMeta = itemMeta and itemMeta.sword
		if not swordMeta then return nil end
		return swordMeta.attackRange
	end

	local function blockedByMap(fromPos, toPos)
		local dir = toPos - fromPos
		local dist = dir.Magnitude
		if dist < 3 then return false end
		local params = cloneRaycast()
		local hit = workspace:Raycast(fromPos, dir.Unit * (dist - 1.5), params)
		if not hit then return false end
		return (hit.Position - fromPos).Magnitude < dist - 2
	end

	local function kaState(plr)
		local d = kaData[plr]
		if not d then
			d = {targets = {}, intervals = {}, lastHit = 0, angleHits = {}, wallHits = {}}
			kaData[plr] = d
		end
		return d
	end

	local function pruneStamps(list, life)
		local now = os.clock()
		for i = #list, 1, -1 do
			if now - list[i] > life then table.remove(list, i) end
		end
		return #list
	end

	local function checkReach(attacker, victimPlr, victimPos, fromPosition)
		if not isOn('Reach') then return end
		local range = getAttackRange(attacker)
		if not range then return end

		local best
		if fromPosition then
			if victimPlr then
				best = minDistanceTo(victimPlr, fromPosition, 0.8)
			elseif victimPos then
				best = (victimPos - fromPosition).Magnitude
			end
		end
		if victimPlr then
			local paired = minPairDistance(attacker, victimPlr, 0.8)
			if paired and (not best or paired < best) then best = paired end
		end
		if not best then return end

		local allowance = range + 2.5 + math.min(lplr:GetNetworkPing(), 0.2) * 30
		if best > allowance then
			reachStreak[attacker] = (reachStreak[attacker] or 0) + 1
			if reachStreak[attacker] >= 3 then
				reachStreak[attacker] = 0
				addScore(attacker, 45, 'reach', 'reach ('..string.format('%.1f', best)..' studs, max is '..string.format('%.1f', allowance)..')')
			end
		else
			reachStreak[attacker] = 0
		end
	end

	local function checkKillaura(attacker, victimInstance, victimPlr, victimPos, fromPosition)
		if not isOn('Killaura') then return end
		local d = kaState(attacker)
		local now = os.clock()

		d.targets[victimInstance] = now
		local distinct = 0
		for inst, t in d.targets do
			if now - t <= 0.35 then
				distinct = distinct + 1
			else
				d.targets[inst] = nil
			end
		end
		if distinct >= 2 then
			addScore(attacker, 40, 'multi', 'killaura (hit '..distinct..' ppl at once)')
		end

		if d.lastHit > 0 then
			local gap = now - d.lastHit
			if gap > 0.04 and gap < 1.2 then
				d.intervals[#d.intervals + 1] = gap
				while #d.intervals > 16 do
					table.remove(d.intervals, 1)
				end
				if #d.intervals >= 12 then
					local sum = 0
					for _, g in d.intervals do sum = sum + g end
					local mean = sum / #d.intervals
					local varSum = 0
					for _, g in d.intervals do varSum = varSum + (g - mean) ^ 2 end
					local sd = math.sqrt(varSum / #d.intervals)
					if mean > 0.05 and sd / mean < 0.07 then
						addScore(attacker, 45, 'timing', 'killaura (hits perfectly on beat, no human jitter)')
						table.clear(d.intervals)
					end
				end
			end
		end
		d.lastHit = now

		local attackerSample = recentSample(attacker)
		local origin = attackerSample and attackerSample.pos or fromPosition
		local look = attackerSample and attackerSample.look
		local targetPos = victimPos
		if victimPlr then
			local vs = recentSample(victimPlr)
			if vs then targetPos = vs.pos end
		end

		if origin and look and targetPos then
			local flatLook = look * Vector3.new(1, 0, 1)
			local flatDir = (targetPos - origin) * Vector3.new(1, 0, 1)
			if flatLook.Magnitude > 0.001 and flatDir.Magnitude > 0.001 then
				local angle = math.deg(math.acos(math.clamp(flatLook.Unit:Dot(flatDir.Unit), -1, 1)))
				if angle > 75 then
					d.angleHits[#d.angleHits + 1] = now
					if pruneStamps(d.angleHits, 15) >= 4 then
						table.clear(d.angleHits)
						addScore(attacker, 35, 'angle', 'killaura (swingin at ppl behind them)')
					end
				end
			end

			if blockedByMap(origin, targetPos) then
				d.wallHits[#d.wallHits + 1] = now
				if pruneStamps(d.wallHits, 15) >= 3 then
					table.clear(d.wallHits)
					addScore(attacker, 40, 'wall', 'killaura (hittin straight thru blocks)')
				end
			end
		end
	end

	local function onMeleeDamage(dmg)
		if not CheatDetector.Enabled then return end
		if dmg.damageType ~= 0 then return end
		if not dmg.fromEntity or not dmg.entityInstance then return end

		local attacker = playersService:GetPlayerFromCharacter(dmg.fromEntity)
		if not attacker or not notSelf(attacker) then return end

		local victimPlr = playersService:GetPlayerFromCharacter(dmg.entityInstance)
		if victimPlr then
			local vm = meta[victimPlr]
			if vm then vm.lastDamaged = os.clock() end
		end

		local victimRoot = dmg.entityInstance.PrimaryPart or dmg.entityInstance:FindFirstChild('HumanoidRootPart')
		local victimPos = victimRoot and victimRoot.Position

		local am = meta[attacker]
		if not am or os.clock() - am.spawn < 3 then return end
		if lplr:GetNetworkPing() > 0.15 then return end

		checkReach(attacker, victimPlr, victimPos, dmg.fromPosition)
		checkKillaura(attacker, dmg.entityInstance, victimPlr, victimPos, dmg.fromPosition)
	end

	local function checkFly(plr, ent, dt, rayParams)
		if not isOn('Fly') then
			airTime[plr] = 0
			return
		end
		local root = ent.RootPart
		rayParams.FilterDescendantsInstances = {ent.Character, lplr.Character, gameCamera}
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -250, 0), rayParams)
		local groundDist = hit and (root.Position.Y - hit.Position.Y) or 250
		local vel = root.AssemblyLinearVelocity
		local horizontal = (vel * Vector3.new(1, 0, 1)).Magnitude

		if groundDist > 8 and math.abs(vel.Y) < 3 and horizontal > 2 then
			airTime[plr] = (airTime[plr] or 0) + dt
			if airTime[plr] >= 1.75 then
				airTime[plr] = 0
				addScore(plr, 50, 'fly', 'fly (hoverin '..math.floor(groundDist)..' studs off the ground)')
			end
		else
			airTime[plr] = 0
		end
	end

	local function checkSpeed(plr, ent, dt)
		if not isOn('Speed') then
			speedTime[plr] = 0
			return
		end
		local m = meta[plr]
		if m and os.clock() - (m.lastDamaged or 0) < 1.5 then
			speedTime[plr] = 0
			return
		end
		local h = history[plr]
		if not h or #h < 8 then
			speedTime[plr] = 0
			return
		end

		local now = os.clock()
		local newest, oldest, prev
		local maxStep = 0
		for i = #h, 1, -1 do
			local s = h[i]
			if now - s.t > 0.5 then break end
			if not newest then newest = s end
			if prev then
				local step = ((prev.pos - s.pos) * Vector3.new(1, 0, 1)).Magnitude
				if step > maxStep then maxStep = step end
			end
			prev = s
			oldest = s
		end

		if not newest or not oldest then
			speedTime[plr] = 0
			return
		end
		local span = newest.t - oldest.t
		if span < 0.3 or maxStep > 8 then
			speedTime[plr] = 0
			return
		end

		local travelled = ((newest.pos - oldest.pos) * Vector3.new(1, 0, 1)).Magnitude
		local speed = travelled / span
		if speed > 34 then
			speedTime[plr] = (speedTime[plr] or 0) + dt
			if speedTime[plr] >= 1.2 then
				speedTime[plr] = 0
				addScore(plr, 45, 'speed', 'speed ('..math.floor(speed)..' studs a sec)')
			end
		else
			speedTime[plr] = 0
		end
	end

	local function decayScores(dt)
		local now = os.clock()
		for plr, s in score do
			s.last = now
			s.value = math.max(0, s.value - SCORE_DECAY * dt)
			for reason, t in s.seen do
				if now - t > REASON_LIFE then
					s.seen[reason] = nil
					s.labels[reason] = nil
				end
			end
			if s.value <= 0 and not next(s.seen) then
				score[plr] = nil
			end
		end
	end

	CheatDetector = vape.Categories.Utility:CreateModule({
		Name = 'CheatDetector',
		Function = function(callback)
			if callback then
				resetAll()

				CheatDetector:Clean(playersService.PlayerRemoving:Connect(function(plr)
					resetPlayer(plr)
					flagged[tostring(plr)] = nil
				end))

				CheatDetector:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(dmg)
					pcall(onMeleeDamage, dmg)
				end))

				task.spawn(function()
					local rayParams = RaycastParams.new()
					rayParams.FilterType = Enum.RaycastFilterType.Exclude
					local last = os.clock()
					local decayAccum = 0
					repeat
						local now = os.clock()
						local dt = now - last
						last = now
						decayAccum = decayAccum + dt

						for _, ent in getEntities() do
							local plr = ent.Player
							if plr and notSelf(plr) and ent.RootPart and ent.Character then
								trackMeta(plr, ent)
								pushSample(plr, ent)
								if trusted(plr, ent) then
									checkFly(plr, ent, dt, rayParams)
									checkSpeed(plr, ent, dt)
								else
									airTime[plr] = 0
									speedTime[plr] = 0
								end
							end
						end

						if decayAccum >= 1 then
							decayScores(decayAccum)
							decayAccum = 0
						end

						task.wait(SAMPLE_STEP)
					until not CheatDetector.Enabled
					resetAll()
				end)
			else
				resetAll()
			end
		end,
		Tooltip = 'tells u if sum1 in ur game is prob cheatin'
	})

	SelfTest = CheatDetector:CreateToggle({
		Name = 'Self',
		Default = false,
		Tooltip = 'lets it flag u too so u can test it on urself'
	})

	for _, name in {'Speed', 'Reach', 'Killaura', 'Fly'} do
		toggles[name] = CheatDetector:CreateToggle({
			Name = name,
			Default = true,
			Tooltip = tips[name]
		})
	end
end)

run(function()
    local moduleData = {
        Connection = nil,
        CurrentDuration = 1,
        CachedPrompts = {}
    }
    
    local function updatePrompt(prompt, duration)
        if prompt and prompt:IsA("ProximityPrompt") then
            prompt.HoldDuration = duration
        end
    end
    
    local function updateAllPrompts(duration)
        for prompt in pairs(moduleData.CachedPrompts) do
            if prompt and prompt.Parent then
                prompt.HoldDuration = duration
            else
                moduleData.CachedPrompts[prompt] = nil
            end
        end
    end
    
    local function cacheExistingPrompts()
        moduleData.CachedPrompts = {}
        
        scanDescendants(workspace, function(descendant)
            if descendant:IsA("ProximityPrompt") then
                moduleData.CachedPrompts[descendant] = true
                descendant.HoldDuration = moduleData.CurrentDuration
            end
        end)
    end
    
	ProximityPromptDuration = vape.Categories.Utility:CreateModule({
		Name = 'ProximityPromptDuration',
		Function = function(callback)
			if callback then
				cacheExistingPrompts()
				ProximityPromptDuration:Clean(workspace.DescendantAdded:Connect(function(descendant)
					if descendant:IsA("ProximityPrompt") then
						moduleData.CachedPrompts[descendant] = true
						descendant.HoldDuration = moduleData.CurrentDuration
					end
				end))
			else
				moduleData.CachedPrompts = {}
			end
		end,
		Tooltip = 'customize proximity prompts'
	})
    
    local ProximityDurationSlider = ProximityPromptDuration:CreateSlider({
        Name = 'Duration',
        Min = 0,
        Max = 10,
        Default = 1,
        Decimal = 100,
        Suffix = 's',
        Function = function(value)
            moduleData.CurrentDuration = value
            if ProximityPromptDuration.Enabled then
                updateAllPrompts(value)
            end
        end
    })
end)

run(function()
	local BedAlarm
	local Types
	local Distance
	local UpdateTick
	local HighlightEnemies
	local SoundVolume
	local ShowAlarm

	local function getBed()
		if not (entitylib.isAlive and lplr.Character) then return nil end
		local id = lplr.Character:GetAttribute('Team') or lplr.Character:GetAttribute('TeamId')
		for _, v in collectionService:GetTagged('bed') do
			if tonumber(id) == tonumber(v:GetAttribute('TeamID') or v:GetAttribute('Team') or v:GetAttribute('TeamId')) then
				return v
			end
		end
		return nil
	end

	local function createAlarm(bedpos)
		if not ShowAlarm.Enabled then return end
		if not bedpos then return end
		if store.BedAlarm[lplr] then return end

		if bedwars.BedAlarmController then
			local suc, res = pcall(function()
				local oldthread = 0
				if vape.ThreadFix then 
					oldthread = getthreadidentity()
					setthreadidentity(8) 
				end

				local myTeam = lplr.Character:GetAttribute('Team') or lplr.Character:GetAttribute('TeamId') or -1
				bedwars.BedAlarmController:getOrCreateBedAlarmModel(myTeam, bedpos)

				if vape.ThreadFix then 
					setthreadidentity(oldthread) 
				end
			end)

			if suc then
				store.BedAlarm[lplr] = true
			else
				vape:CreateNotification("BedAlarm", `Creating Alarm issue: {res}`, 16, 'alert')
			end
		end
	end

	local function AlarmAffects(bedpos)
		if not ShowAlarm.Enabled or not bedpos then return end
		if not store.BedAlarm[lplr] then return end

		local myTeam = lplr.Character:GetAttribute('Team') or lplr.Character:GetAttribute('TeamId') or -1
		pcall(function()
			bedwars.BedAlarmController:triggerBedAlarmModel({bedPosition = bedpos, teamId = myTeam})
		end)
	end

	local function removeAlarm()
		if not store.BedAlarm[lplr] then return end
		
		local myTeam = lplr.Character:GetAttribute('Team') or lplr.Character:GetAttribute('TeamId') or -1
		local alarm = bedwars.BedAlarmController.bedAlarmModelMap[myTeam]
		if alarm then
			alarm:Destroy()
			bedwars.BedAlarmController.bedAlarmModelMap[myTeam] = nil
		end
		store.BedAlarm[lplr] = nil
	end

	local function createHighlight(ent)
		if store.BedAlarmHighlightedEnimes[ent] then return end
		
		local character = ent.character or ent.Character
		if not character then return end

		local highlight = Instance.new("Highlight")
		highlight.Name = "BedAlarmHighlight"
		highlight.Adornee = character
		highlight.FillColor = Color3.fromRGB(255, 80, 80)
		highlight.OutlineColor = Color3.fromRGB(255, 100, 100)
		highlight.FillTransparency = 0.6
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = character
		
		store.BedAlarmHighlightedEnimes[ent] = highlight
	end

	local function clearAllHighlights()
		for _, highlight in pairs(store.BedAlarmHighlightedEnimes) do
			if highlight and highlight.Parent then highlight:Destroy() end
		end
		table.clear(store.BedAlarmHighlightedEnimes)
	end

	local function removeHighlight(ent)
		local hl = store.BedAlarmHighlightedEnimes[ent]
		if hl then
			hl:Destroy()
			store.BedAlarmHighlightedEnimes[ent] = nil
		end
	end

	BedAlarm = vape.Categories.Utility:CreateModule({
		Name = "BedAlarm",
		Function = function(callback)
			if callback then
				store.BedAlarmNotifyTick = 0
				store.BedAlarmSoundTick = 0
				store.BedAlarmIsTrigged = false

				local bed = getBed()
				local bedpos = bed and bed:GetPivot().Position or Vector3.zero

				if ShowAlarm.Enabled then
					createAlarm(bedpos)
				end

				local _bedAlarmSearch = {Origin = bedpos, Range = Distance.Value, Part = 'RootPart', Players = true, IgnoreLocal = true}
				repeat
					if bedpos then
						_bedAlarmSearch.Origin = bedpos
						_bedAlarmSearch.Range = Distance.Value
						local entity = entitylib.EntityPosition(_bedAlarmSearch)

						if entity then
							store.BedAlarmIsTrigged = true

							if ShowAlarm.Enabled then
								createAlarm(bedpos)
							end

							if os.time() >= store.BedAlarmNotifyTick then
								store.BedAlarmNotifyTick = os.time() + UpdateTick.Value

								AlarmAffects(bedpos)

								local msg = '[Bed Alarm]: An intruder is near your bed!'
								if Types.Value == 'Vape' then
									vape:CreateNotification("BedAlarm", msg, UpdateTick.Value + 1)
								else
									pcall(function()
										bedwars.NotificationController:sendInfoNotification({ message = msg })
									end)
								end
							end

							if os.time() >= store.BedAlarmSoundTick then
								store.BedAlarmSoundTick = os.time() + 1.2

								local distance = (bedpos - entity.RootPart.Position).Magnitude
								local soundId = distance >= 30 and bedwars.SoundList.BED_ALARM_TRIGGERED_FAR or bedwars.SoundList.BED_ALARM

								pcall(function()
									bedwars.SoundManager:playSound(soundId, {
										volumeMultiplier = SoundVolume.Value
									})
								end)
							end

							if HighlightEnemies.Enabled then
								createHighlight(entity)
							end
						else
							store.BedAlarmIsTrigged = false
						end
					end

					for ent, _ in pairs(store.BedAlarmHighlightedEnimes) do
						if not entity or ent ~= entity then
							removeHighlight(ent)
						end
					end

					task.wait(1/60)
				until not BedAlarm.Enabled

			else
				store.BedAlarmIsTrigged = false
				clearAllHighlights()
				removeAlarm()
			end
		end
	})

	Distance = BedAlarm:CreateSlider({Name = 'Distance', Min = 10, Max = 100, Default = 64, Suffix = " studs"})
	
	Types = BedAlarm:CreateDropdown({
		Name = 'Notification Type',
		List = {'Vape','Bedwars'},
		Default = 'Bedwars'
	})
	
	UpdateTick = BedAlarm:CreateSlider({
		Name = "Update Tick",
		Min = 0.5,
		Max = 8,
		Decimal = 5,
		Default = 3,
		Suffix = 's'
	})
	
	SoundVolume = BedAlarm:CreateSlider({
		Name = "Volume Multiplier",
		Min = 0.1,
		Max = 3,
		Default = 1.5,
		Decimal = 5,
	})
	
	HighlightEnemies = BedAlarm:CreateToggle({
		Name = 'Highlight Enemies',
		Default = true,
		Function = function(v)
			if not v then clearAllHighlights() end
		end
	})
	
	ShowAlarm = BedAlarm:CreateToggle({
		Name = "Show Alarm Model",
		Default = false,
		Function = function(v)
			local bed = getBed()
			local pos = bed and bed:GetPivot().Position or Vector3.zero
			if v then
				createAlarm(pos)
			else
				removeAlarm()
			end
		end
	})
end)

run(function()
	local AutoPlay
	local Random
	
	local function isEveryoneDead()
		return #bedwars.Store:getState().Party.members <= 0
	end
	
	local function joinQueue()
		if not bedwars.Store:getState().Game.customMatch and bedwars.Store:getState().Party.leader.userId == lplr.UserId and bedwars.Store:getState().Party.queueState == 0 then
			if Random.Enabled then
				local listofmodes = {}
				for i, v in bedwars.QueueMeta do
					if not v.disabled and not v.voiceChatOnly and not v.rankCategory then 
						table.insert(listofmodes, i) 
					end
				end
				bedwars.QueueController:joinQueue(listofmodes[math.random(1, #listofmodes)])
			else
				bedwars.QueueController:joinQueue(store.queueType)
			end
		end
	end
	
	AutoPlay = vape.Categories.Utility:CreateModule({
		Name = 'AutoPlay',
		Function = function(callback)
			if callback then
				AutoPlay:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill and deathTable.entityInstance == lplr.Character and isEveryoneDead() and store.matchState ~= 2 then
						joinQueue()
					end
				end))
				AutoPlay:Clean(vapeEvents.MatchEndEvent.Event:Connect(function()
					task.wait(1)
					joinQueue()
				end))
			end
		end,
		Tooltip = 'auto queues after the match ends.'
	})
	Random = AutoPlay:CreateToggle({
		Name = 'Random',
	})
end)

run(function()
	local RegionLock
	local AllowedRegions
	local lockLabel = 'next match'
	local knownRegion
	local fetchBusy = false
	local nextFetch = 0
	local warnedUnknown = false
	local shorthand = {
		AU = 'SEA', AUS = 'SEA', AUSTRALIA = 'SEA', NZ = 'SEA', OCE = 'SEA', OCEANIA = 'SEA',
		AS = 'SEA', ASIA = 'SEA', SG = 'SEA', SGP = 'SEA',
		US = 'NA', USA = 'NA', AMERICA = 'NA',
		EUROPE = 'EU', GB = 'EU', UK = 'EU'
	}

	local function normalize(text)
		text = tostring(text):gsub('%s+', ''):upper()
		return shorthand[text] or text
	end

	local function currentRegion()
		local okState, gameState = pcall(function()
			return bedwars.Store:getState().Game
		end)
		local fromStore = okState and type(gameState) == 'table' and gameState.serverRegion or nil
		if type(fromStore) == 'string' and fromStore ~= '' then
			knownRegion = fromStore
			return fromStore
		end
		if not knownRegion and not fetchBusy and os.clock() >= nextFetch then
			fetchBusy = true
			task.spawn(function()
				local okFetch, reply = pcall(function()
					return bedwars.Client:Get('FetchServerRegion'):CallServer()
				end)
				nextFetch = os.clock() + 5
				fetchBusy = false
				if okFetch and type(reply) == 'string' and reply ~= '' then
					knownRegion = reply
				end
			end)
		end
		return knownRegion
	end

	local function regionOk()
		if #AllowedRegions.ListEnabled == 0 then
			return true
		end
		local region = currentRegion()
		if not region then
			return false
		end
		region = normalize(region)
		for _, want in AllowedRegions.ListEnabled do
			want = normalize(want)
			if want ~= '' and region:sub(1, #want) == want then
				return true
			end
		end
		return false
	end

	RegionLock = vape.Categories.Utility:CreateModule({
		Name = 'RegionLock',
		Function = function(callback)
			if callback then
				readyGate.Claimed = true
				warnedUnknown = false
				repeat
					if not readyGate.Held then
						lockLabel = lplr:GetAttribute('PlayerConnected') and 'loaded' or 'next match'
					else
						local heldSince = readyGate.Started or os.clock()
						if regionOk() then
							lockLabel = knownRegion or 'any region'
							readyGate.Release()
						elseif knownRegion then
							lockLabel = 'wrong region ('..knownRegion..')'
						elseif os.clock() - heldSince >= 20 then
							if not warnedUnknown then
								warnedUnknown = true
								notif('RegionLock', 'couldnt read this server region so ur loadin in anyway', 8, 'warning')
							end
							lockLabel = 'unknown region'
							readyGate.Release()
						else
							lockLabel = 'finding region'
						end
					end
					task.wait(0.5)
				until not RegionLock.Enabled
			else
				readyGate.Release()
				lockLabel = 'loaded'
				readyGate.Claimed = false
			end
		end,
		ExtraText = function()
			return lockLabel
		end,
		Tooltip = 'keeps u outta matches that aint in the regions u picked bedwars only has NA,EU adn SEA n picks urs from ur account country so this only skips the odd server in another region'
	})

	AllowedRegions = RegionLock:CreateTextList({
		Name = 'Regions',
		Placeholder = 'NA / EU / SEA',
		Default = {'NA', 'EU', 'SEA'},
		Function = function()
			if not AllowedRegions then
				return
			end
			for i, v in AllowedRegions.List do
				AllowedRegions.List[i] = v:gsub('%s+', ''):upper()
			end
			for i, v in AllowedRegions.ListEnabled do
				AllowedRegions.ListEnabled[i] = v:gsub('%s+', ''):upper()
			end
		end,
		Tooltip = 'turn off the regions u dont want. AUS OCE AU n NZ count as SEA n US counts as NA. leavin them all on lets anything in'
	})

	task.spawn(function()
		repeat
			task.wait()
		until vape.Loaded ~= false
		if vape.Loaded and not readyGate.Claimed then
			readyGate.Release()
		end
	end)
end)

run(function()
	local AutoVoidDrop
	local OwlCheck
	local PearlCheck
	local AutoReset
	local pearlLastInHandTickVoid = 0
	local DropToggles = {
		iron = nil,
		diamond = nil,
		emerald = nil,
		gold = nil
	}
	local cachedLowestPoint
	
	AutoVoidDrop = vape.Categories.Utility:CreateModule({
		Name = 'AutoVoidDrop',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.matchState ~= 0 or (not AutoVoidDrop.Enabled)
				if not AutoVoidDrop.Enabled then return end

				cachedLowestPoint = math.huge
				for _, v in pairs(store.blocks) do
					local point = (v.Position.Y - (v.Size.Y / 2)) - 75
					if point < cachedLowestPoint then
						cachedLowestPoint = point
					end
				end

				repeat
					if entitylib.isAlive then
						local root = entitylib.character.RootPart

						local handItem = store.inventory and store.inventory.inventory and store.inventory.inventory.hand
						if handItem and handItem.itemType == 'telepearl' then
							pearlLastInHandTickVoid = tick()
						end

						if root.Position.Y < cachedLowestPoint and (lplr.Character:GetAttribute('InflatedBalloons') or 0) <= 0 and not getItem('balloon') then
							local pearlBlock = PearlCheck.Enabled and (tick() - pearlLastInHandTickVoid) < 4
							if (not OwlCheck.Enabled or not root:FindFirstChild('OwlLiftForce')) and not pearlBlock then
								for _, item in pairs(store.inventory.inventory.items) do
									if item and item.tool then
										local dropped = bedwars.Client:Get(remotes.DropItem):CallServer({
											item = item.tool,
											amount = item.amount
										})
										if dropped then
											dropped:SetAttribute('ClientDropTime', tick() + 100)
										end
									end
								end
								if AutoReset.Enabled then
									local hum = root.Parent:FindFirstChildOfClass('Humanoid')
									if hum then
										hum.Health = 0
									end
								end
								break
							end
						end
					end

					task.wait(0.1)
				until not AutoVoidDrop.Enabled
			end
		end,
		Tooltip = 'drops resources when you fall into the void'
	})
	
	OwlCheck = AutoVoidDrop:CreateToggle({
		Name = 'Owl check',
		Default = true,
		Tooltip = 'doesnt drop items if being picked up by an owl'
	})
	PearlCheck = AutoVoidDrop:CreateToggle({
		Name = 'Pearl check',
		Default = false,
		Tooltip = 'does not drop if holding a pearl or recently threw one (4 sec cooldown)'
	})
	AutoReset = AutoVoidDrop:CreateToggle({
		Name = 'Auto Reset',
		Default = false,
		Tooltip = 'resets ur character right after dropping all the loot gng'
	})
	DropToggles.iron = AutoVoidDrop:CreateToggle({
		Name = 'Drop Iron',
		Default = true
	})
	DropToggles.diamond = AutoVoidDrop:CreateToggle({
		Name = 'Drop Diamond',
		Default = true
	})
	DropToggles.emerald = AutoVoidDrop:CreateToggle({
		Name = 'Drop Emerald',
		Default = true
	})
	DropToggles.gold = AutoVoidDrop:CreateToggle({
		Name = 'Drop Gold',
		Default = true
	})
end)
	
run(function()
	local PickupRange
	local Range
	local Lower
	local Network
	local PickupDelay
	local lastPickupTime = 0
	
	PickupRange = vape.Categories.Utility:CreateModule({
		Name = 'PickupRange',
		Function = function(callback)
			if callback then
				local items = collection('ItemDrop', PickupRange)
				local rangeSquared = Range.Value * Range.Value
				
				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						local humanoidHealth = entitylib.character.Humanoid.Health
						local currentTime = tick()
						local pickupDelaySeconds = PickupDelay.Value / 1000
						rangeSquared = Range.Value * Range.Value

						for _, v in pairs(items) do
							if (currentTime - (v:GetAttribute('ClientDropTime') or 0)) < 2 then continue end
							if (currentTime - lastPickupTime) < pickupDelaySeconds then continue end

							local offset = v.Position - localPosition
							local distanceSquared = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z

							if distanceSquared <= rangeSquared then
								if Lower.Enabled and (localPosition.Y - v.Position.Y) < (entitylib.character.HipHeight - 1) then continue end

								bedwars.Client:Get(remotes.PickupItem):CallServerAsync({
									itemDrop = v
								}):andThen(function(suc)
									if suc then
										lastPickupTime = tick()
										if bedwars.SoundList then
											bedwars.SoundManager:playSound(bedwars.SoundList.PICKUP_ITEM_DROP)
											local itemMeta = bedwars.ItemMeta[v.Name]
											if itemMeta then
												local sound = itemMeta.pickUpOverlaySound
												if sound then
													bedwars.SoundManager:playSound(sound, {
														position = v.Position,
														volumeMultiplier = 0.9
													})
												end
											end
										end
									end
								end)
							end
						end
					end
					task.wait(0.1)
				until not PickupRange.Enabled
			else
				lastPickupTime = 0
			end
		end,
		Tooltip = 'Picks up items from a farther distance'
	})

	Range = PickupRange:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 10,
		Default = 10,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	PickupDelay = PickupRange:CreateSlider({
		Name = 'Pickup Delay',
		Min = 0,
		Max = 500,
		Default = 0,
		Suffix = 'ms'
	})
	Lower = PickupRange:CreateToggle({
		Name = 'Feet Check'
	})
end)

run(function()
	local Scaffold
	local Expand
	local Tower
	local Downwards
	local Diagonal
	local LimitItem
	local Mouse
	local PlaceDelay
	local adjacent, lastpos = {}, Vector3.zero
	local lastPlaceTime = 0
	
	for x = -3, 3, 3 do
		for y = -3, 3, 3 do
			for z = -3, 3, 3 do
				local vec = Vector3.new(x, y, z)
				if vec ~= Vector3.zero then
					table.insert(adjacent, vec)
				end
			end
		end
	end
	
	local function checkAdjacent(pos)
		for _, v in adjacent do
			if getPlacedBlock(pos + v) then
				return true
			end
		end
		return false
	end
	
	local function getScaffoldBlock()
		if store.hand.toolType == 'block' then
			return store.hand.tool.Name, store.hand.amount
		elseif not LimitItem.Enabled then
			local wool, amount = getWool()
			if wool then
				return wool, amount
			end
			for _, item in store.inventory.inventory.items do
				local meta = bedwars.ItemMeta[item.itemType]
				if meta and meta.block then
					return item.itemType, item.amount
				end
			end
		end
		return nil, 0
	end
	
	Scaffold = vape.Categories.Utility:CreateModule({
		Name = 'Scaffold',
		Function = function(callback)
			if callback then
				lastPlaceTime = 0
				repeat
					if entitylib.isAlive then
						local wool, amount = getScaffoldBlock()

						if Mouse.Enabled then
							if not inputService:IsMouseButtonPressed(0) then
								wool = nil
							end
						end

						if wool then
							local root = entitylib.character.RootPart
							if Tower.Enabled and inputService:IsKeyDown(Enum.KeyCode.Space) and (not inputService:GetFocusedTextBox()) then
								root.Velocity = Vector3.new(root.Velocity.X, 38, root.Velocity.Z)
							end

							for i = Expand.Value, 1, -1 do
								local currentpos = roundPos(root.Position - Vector3.new(0, entitylib.character.HipHeight + (Downwards.Enabled and inputService:IsKeyDown(Enum.KeyCode.LeftShift) and 4.5 or 1.5), 0) + entitylib.character.Humanoid.MoveDirection * (i * 3))
								if Diagonal.Enabled then
									if math.abs(math.round(math.deg(math.atan2(-entitylib.character.Humanoid.MoveDirection.X, -entitylib.character.Humanoid.MoveDirection.Z)) / 45) * 45) % 90 == 45 then
										local dt = (lastpos - currentpos)
										if ((dt.X == 0 and dt.Z ~= 0) or (dt.X ~= 0 and dt.Z == 0)) and ((lastpos - root.Position) * Vector3.new(1, 0, 1)).Magnitude < 2.5 then
											currentpos = lastpos
										end
									end
								end

								local block, blockpos = getPlacedBlock(currentpos)
								if not block then
									if tick() - lastPlaceTime >= (PlaceDelay.Value / 1000) then
										blockpos = checkAdjacent(blockpos * 3) and blockpos * 3 or blockProximity(currentpos)
										if blockpos then
											task.spawn(bedwars.placeBlock, blockpos, wool, false)
											lastPlaceTime = tick()
										end
									end
								end
								lastpos = currentpos
							end
						end
					end

					task.wait(0.03)
				until not Scaffold.Enabled
			else
				lastPlaceTime = 0
			end
		end,
		Tooltip = 'Helps you make bridges/scaffold walk.'
	})
	Expand = Scaffold:CreateSlider({
		Name = 'Expand',
		Min = 1,
		Max = 6
	})
	Tower = Scaffold:CreateToggle({
		Name = 'Tower',
		Default = true
	})
	Downwards = Scaffold:CreateToggle({
		Name = 'Downwards',
		Default = true
	})
	Diagonal = Scaffold:CreateToggle({
		Name = 'Diagonal',
		Default = true
	})
	LimitItem = Scaffold:CreateToggle({Name = 'Limit to items'})
	Mouse = Scaffold:CreateToggle({Name = 'Require mouse down'})
	PlaceDelay = Scaffold:CreateSlider({
		Name = 'Place Delay',
		Min = 0,
		Max = 200,
		Default = 0,
		Suffix = "ms"
	})
end)

run(function()
	local AutoBuy
	local ItemShop
	local TeamUpgrade
	local WrenShop
	local GUICheck
	local BuyArmorToggle
	local BuyAxeToggle
	local BuyPickaxeToggle
	local BuyProjectileToggle
	local BuySerpentToggle
	local BuyJumpToggle
	local BuyShieldToggle
	local BreakSpeedToggle
	local ArmorUpgradeToggle
	local DamageToggle
	local DiamondGenToggle
	local TeamGenToggle
	local BedBarrierToggle

	local purchaseRemote
	local function getPurchaseRemote()
		if not purchaseRemote then
			purchaseRemote = game:GetService("ReplicatedStorage").rbxts_include.node_modules["@rbxts"].net.out._NetManaged.BedwarsPurchaseItem
		end
		return purchaseRemote
	end

	local function getResourceCount(currency)
		local item = getItem(currency)
		return item and item.amount or 0
	end

	local function playerOwns(itemType)
		for _, item in store.inventory.inventory.items do
			if item.itemType == itemType then return true end
		end
		if store.inventory.inventory.armor then
			for _, v in pairs(store.inventory.inventory.armor) do
				if type(v) == 'table' and v.itemType == itemType then return true end
			end
		end
		return false
	end

	local function isNearShop(checkType)
		if not GUICheck.Enabled then return true end
		local _, items, upgrades = getShopNPC()
		if checkType == 'item' then return items end
		if checkType == 'upgrade' then return upgrades end
		return false
	end

	local function buyItem(shopItem, shopId)
		pcall(function()
			getPurchaseRemote():InvokeServer({shopItem = shopItem, shopId = shopId})
		end)
	end

	local function getShopData(itemType)
		if not bedwars.Shop then return nil end
		local ok, res = pcall(function()
			return bedwars.Shop.getShopItem(itemType, lplr)
		end)
		return ok and res or nil
	end

	local armorTiers = {
		'emerald_chestplate','emerald_leggings','emerald_boots',
		'diamond_chestplate','diamond_leggings','diamond_boots',
		'iron_chestplate','iron_leggings','iron_boots',
		'leather_chestplate',
	}
	local axeTiers = {'emerald_axe','diamond_axe','iron_axe','stone_axe','wood_axe'}
	local pickaxeTiers = {'emerald_pickaxe','diamond_pickaxe','iron_pickaxe','stone_pickaxe','wood_pickaxe'}

	local function buyBestTier(tierList, shopId)
		for _, itemType in ipairs(tierList) do
			if playerOwns(itemType) then break end
			local data = getShopData(itemType)
			if data then
				if getResourceCount(data.currency or 'iron') >= (data.price or math.huge) then
					buyItem(data, shopId)
					break
				end
			end
		end
	end

	local function buyProjectile(shopId)
		local em = getResourceCount('emerald')
		local ir = getResourceCount('iron')
		local ownsAny = playerOwns('headhunter') or playerOwns('wood_crossbow') or playerOwns('wood_bow')
		if ownsAny then return end

		if em >= 24 then
			buyItem({
				lockAfterPurchase = true, itemType = "headhunter", price = 24,
				currency = "emerald", amount = 1,
				disabledInQueue = {"tnt_wars","bedwars_og_to4"}, category = "Combat",
				spawnWithItems = {"headhunter"},
				ignoredByKit = {"archer","flower_bee","falconer","nazar"}
			}, shopId)
		elseif em >= 7 then
			buyItem({
				disabledInQueue = {"tnt_wars","bedwars_og_to4"},
				itemType = "wood_crossbow", price = 7,
				superiorItems = {"headhunter"}, currency = "emerald",
				category = "Combat", lockAfterPurchase = true,
				ignoredByKit = {"archer","flower_bee","falconer","nazar"},
				spawnWithItems = {"wood_crossbow"}, amount = 1
			}, shopId)
		elseif ir >= 24 then
			buyItem({
				ignoredByKit = {"flower_bee","falconer","nazar"},
				itemType = "wood_bow", price = 24,
				superiorItems = {"wood_crossbow","tactical_crossbow"},
				currency = "iron", category = "Combat", lockAfterPurchase = true,
				spawnWithItems = {"wood_bow"}, amount = 1
			}, shopId)
		end
	end

	local function getNearestShopId()
		if not entitylib.isAlive then return nil end
		local localPosition = entitylib.character.RootPart.Position
		local id
		for _, v in store.shop do
			if v.Shop and v.RootPart and (v.RootPart.Position - localPosition).Magnitude <= 20 then
				id = v.Id
			end
		end
		return id
	end

	local function buyPotion(itemType)
		local shopId = getNearestShopId()
		if not shopId then return end
		local ok, item = pcall(function()
			return bedwars.Shop.getShopItem(itemType, lplr, {shopId = shopId})
		end)
		if not ok or not item then return end
		if getResourceCount(item.currency or 'iron') < (item.price or math.huge) then return end
		buyItem(item, shopId)
	end

	local upgradeIds = {
		BreakSpeed = 'BREAK_SPEED',
		Armor      = 'ARMOR',
		Damage     = 'DAMAGE',
		DiamondGen = 'DIAMOND_GENERATOR',
		TeamGen    = 'TEAM_GENERATOR',
	}

	local upgradeRemote = replicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("RequestPurchaseTeamUpgrade")

	local function buyTeamUpgrade(upgradeType)
		if not upgradeType then return end
		pcall(function()
			upgradeRemote:InvokeServer(upgradeType)
		end)
	end

	local lastBedBarrierBuy = 0
	local BED_BARRIER_DURATION = 180

	local bedUpgradeRemote = replicatedStorage:WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):WaitForChild("RequestPurchaseBedTeamUpgrade")

	local function buyBedBarrier()
		local now = tick()
		if now - lastBedBarrierBuy < BED_BARRIER_DURATION then return end
		local ok = pcall(function()
			bedUpgradeRemote:InvokeServer("bed_shield")
			bedUpgradeRemote:InvokeServer("bed_alarm")
		end)
		if ok then
			lastBedBarrierBuy = now
		end
	end

	AutoBuy = vape.Categories.Utility:CreateModule({
		Name = 'AutoBuy',
		Function = function(callback)
			if callback then
				task.spawn(function()
					repeat task.wait() until store.shopLoaded or not AutoBuy.Enabled
					if not AutoBuy.Enabled then return end
					repeat
						task.wait(0.5)
						if not entitylib.isAlive then continue end
						if WrenShop.Enabled then
							if BuySerpentToggle.Enabled then buyPotion('serpents_touch_potion') end
							if BuyJumpToggle.Enabled then buyPotion('jump_potion') end
							if BuyShieldToggle.Enabled then buyPotion('mini_shield') end
						end
						if ItemShop.Enabled and isNearShop('item') then
							local sid = "1_item_shop"
							if BuyArmorToggle.Enabled then buyBestTier(armorTiers, sid) end
							if BuyAxeToggle.Enabled then buyBestTier(axeTiers, sid) end
							if BuyPickaxeToggle.Enabled then buyBestTier(pickaxeTiers, sid) end
							if BuyProjectileToggle.Enabled then buyProjectile(sid) end
						end
						if TeamUpgrade.Enabled and isNearShop('upgrade') then
							if BreakSpeedToggle.Enabled   then buyTeamUpgrade(upgradeIds.BreakSpeed) end
							if ArmorUpgradeToggle.Enabled then buyTeamUpgrade(upgradeIds.Armor) end
							if DamageToggle.Enabled        then buyTeamUpgrade(upgradeIds.Damage) end
							if DiamondGenToggle.Enabled    then buyTeamUpgrade(upgradeIds.DiamondGen) end
							if TeamGenToggle.Enabled       then buyTeamUpgrade(upgradeIds.TeamGen) end
							if BedBarrierToggle.Enabled then buyBedBarrier() end
						end
					until not AutoBuy.Enabled
				end)
			end
		end,
		Tooltip = 'auto buys from the shops u turn on when ur near them'
	})

	ItemShop = AutoBuy:CreateToggle({
		Name = 'Item Shop',
		Default = true,
		Tooltip = 'buys gear from the item shop when ur near it',
		Function = function(v)
			if BuyArmorToggle     then BuyArmorToggle.Object.Visible     = v end
			if BuyAxeToggle       then BuyAxeToggle.Object.Visible       = v end
			if BuyPickaxeToggle   then BuyPickaxeToggle.Object.Visible   = v end
			if BuyProjectileToggle then BuyProjectileToggle.Object.Visible = v end
		end
	})

	TeamUpgrade = AutoBuy:CreateToggle({
		Name = 'Team Upgrade',
		Default = false,
		Tooltip = 'buys team upgrades when ur near the upgrade shop',
		Function = function(v)
			if BreakSpeedToggle   then BreakSpeedToggle.Object.Visible   = v end
			if ArmorUpgradeToggle then ArmorUpgradeToggle.Object.Visible = v end
			if DamageToggle       then DamageToggle.Object.Visible       = v end
			if DiamondGenToggle   then DiamondGenToggle.Object.Visible   = v end
			if TeamGenToggle      then TeamGenToggle.Object.Visible      = v end
			if BedBarrierToggle   then BedBarrierToggle.Object.Visible   = v end
		end
	})

	WrenShop = AutoBuy:CreateToggle({
		Name = 'Wren Shop',
		Default = false,
		Tooltip = 'buys potions from the wren shop gng',
		Function = function(v)
			if BuySerpentToggle then BuySerpentToggle.Object.Visible = v end
			if BuyJumpToggle    then BuyJumpToggle.Object.Visible    = v end
			if BuyShieldToggle  then BuyShieldToggle.Object.Visible  = v end
		end
	})

	GUICheck = AutoBuy:CreateToggle({
		Name = 'GUI Check',
		Default = true,
		Tooltip = 'only buys when ur near the shop'
	})

	BuyArmorToggle     = AutoBuy:CreateToggle({Name = 'Buy Armor',      Default = true, Darker = true})
	BuyAxeToggle       = AutoBuy:CreateToggle({Name = 'Buy Axe',        Default = false, Darker = true})
	BuyPickaxeToggle   = AutoBuy:CreateToggle({Name = 'Buy Pickaxe',    Default = false, Darker = true})
	BuyProjectileToggle = AutoBuy:CreateToggle({Name = 'Buy Projectile', Default = false, Darker = true})
	BuySerpentToggle   = AutoBuy:CreateToggle({Name = 'Buy Serpent Potion',     Default = false, Darker = true})
	BuyJumpToggle      = AutoBuy:CreateToggle({Name = 'Buy Jump Potion',        Default = false, Darker = true})
	BuyShieldToggle    = AutoBuy:CreateToggle({Name = 'Buy Shield Potion',      Default = false, Darker = true})
	BreakSpeedToggle   = AutoBuy:CreateToggle({Name = 'Break Speed',  Default = false, Darker = true})
	ArmorUpgradeToggle = AutoBuy:CreateToggle({Name = 'Armor',        Default = false, Darker = true})
	DamageToggle       = AutoBuy:CreateToggle({Name = 'Damage',       Default = false, Darker = true})
	DiamondGenToggle   = AutoBuy:CreateToggle({Name = 'Diamond Gen',  Default = false, Darker = true})
	TeamGenToggle      = AutoBuy:CreateToggle({Name = 'Team Gen',     Default = false, Darker = true})
	BedBarrierToggle   = AutoBuy:CreateToggle({Name = 'Bed Barrier',  Default = false, Darker = true})

	task.defer(function()
		if BuySerpentToggle   and BuySerpentToggle.Object   then BuySerpentToggle.Object.Visible   = WrenShop.Enabled end
		if BuyJumpToggle      and BuyJumpToggle.Object      then BuyJumpToggle.Object.Visible      = WrenShop.Enabled end
		if BuyShieldToggle    and BuyShieldToggle.Object    then BuyShieldToggle.Object.Visible    = WrenShop.Enabled end
		if BreakSpeedToggle   and BreakSpeedToggle.Object   then BreakSpeedToggle.Object.Visible   = TeamUpgrade.Enabled end
		if ArmorUpgradeToggle and ArmorUpgradeToggle.Object then ArmorUpgradeToggle.Object.Visible = TeamUpgrade.Enabled end
		if DamageToggle       and DamageToggle.Object       then DamageToggle.Object.Visible       = TeamUpgrade.Enabled end
		if DiamondGenToggle   and DiamondGenToggle.Object   then DiamondGenToggle.Object.Visible   = TeamUpgrade.Enabled end
		if TeamGenToggle      and TeamGenToggle.Object      then TeamGenToggle.Object.Visible      = TeamUpgrade.Enabled end
		if BedBarrierToggle   and BedBarrierToggle.Object   then BedBarrierToggle.Object.Visible   = TeamUpgrade.Enabled end
	end)
end)

run(function()
	local ViewMatchHistory

	ViewMatchHistory = vape.Categories.Utility:CreateModule({
		Name = "ViewMatchHistory",
		Function = function(callback)
			if callback then
				ViewMatchHistory:Toggle(false)
				local d = nil
				bedwars.MatchHistoryController:requestMatchHistory(lplr.Name):andThen(function(Data)
					if Data then
						bedwars.AppController:openApp({app = bedwars.MatchHistoryApp,appId = "MatchHistoryApp",},Data)
					end
				end)
			else
				return
			end
		end,
	})																								
end)

run(function()
	local KitRender
	local LastKitToggle
	local LastKitCount
	local LevelToggle
	local Players = playersService
	local player = Players.LocalPlayer
	local PlayerGui = player:WaitForChild("PlayerGui")
	local scanThread = nil
	local retryThread = nil
	local currentDraft = nil
	local lastKitCache = {}
	local lastKitPending = {}
	local lastKitRetry = {}

	local function resolveKitImage(kit)
		kit = kit or "none"
		local meta = bedwars.BedwarsKitMeta and (bedwars.BedwarsKitMeta[kit] or bedwars.BedwarsKitMeta.none)
		return (meta and meta.renderImage) or kitImageIds[kit] or kitImageIds["none"] or ""
	end

	local function clearLastKitCache()
		table.clear(lastKitCache)
		table.clear(lastKitPending)
		table.clear(lastKitRetry)
	end

	local function destroyNamed(root, name)
		if not root then return end
		for _, obj in root:GetDescendants() do
			if obj.Name == name then
				obj:Destroy()
			end
		end
	end

	local function cleanupVisuals()
		destroyNamed(PlayerGui, "aerov4KitRender")
		destroyNamed(PlayerGui, "aerov4KitIcon")
		destroyNamed(PlayerGui, "aerov4KitLevel")
		destroyNamed(PlayerGui, "aerov4LastKit")
	end

	local function cleanupLastMatch()
		destroyNamed(PlayerGui, "aerov4LastKit")
	end

	local function extractHistory(payload)
		if type(payload) ~= "table" then return nil end

		if type(payload.matchHistory) == "table" then
			return payload.matchHistory
		end

		if type(payload.data) == "table" then
			if type(payload.data.matchHistory) == "table" then
				return payload.data.matchHistory
			end
			if type(payload.data.history) == "table" then
				return payload.data.history
			end
			if next(payload.data) ~= nil then
				return payload.data
			end
		end

		if type(payload.history) == "table" then
			return payload.history
		end

		return payload
	end

	local function getMatchEntry(match, uid)
		if type(match) ~= "table" or type(match.players) ~= "table" then return nil end
		for _, entry in match.players do
			local info = entry and entry.playerInfo
			if info and tostring(info.userId) == tostring(uid) then
				return entry
			end
		end
		return nil
	end

	local function readLastCompletedKit(history, uid)
		if type(history) ~= "table" then return nil end

		local matches = {}
		local order = 0

		if history[1] ~= nil then
			for index, match in ipairs(history) do
				if type(match) == "table" then
					order += 1
					table.insert(matches, {
						match = match,
						time = tonumber(match.matchStartTime) or tonumber(match.startTime) or 0,
						order = order,
						index = index
					})
				end
			end
		else
			for index, match in pairs(history) do
				if type(match) == "table" then
					order += 1
					table.insert(matches, {
						match = match,
						time = tonumber(match.matchStartTime) or tonumber(match.startTime) or 0,
						order = order,
						index = tonumber(index) or order
					})
				end
			end
		end

		table.sort(matches, function(a, b)
			if a.time ~= b.time then
				return a.time > b.time
			end
			if a.index ~= b.index then
				return a.index < b.index
			end
			return a.order < b.order
		end)

		local kits = {}
		local loose = {}

		for _, record in matches do
			local entry = getMatchEntry(record.match, uid)
			if entry then
				local kit = entry.bedwars and entry.bedwars.kit
				if type(kit) == "string" and kit ~= "" then
					local outcome = entry.generic and string.lower(tostring(entry.generic.matchOutcome or "")) or ""
					if outcome == "win"
						or outcome == "loss"
						or outcome == "lose"
						or outcome == "lost"
						or outcome == "defeat"
						or outcome == "victory" then
						table.insert(kits, kit)
						if #kits >= 3 then break end
					elseif #loose < 3 then
						table.insert(loose, kit)
					end
				end
			end
		end

		if #kits == 0 then
			kits = loose
		end

		return #kits > 0 and kits or nil
	end

	local function finishLastKit(uid, payload)
		local history = extractHistory(payload)
		local kit = readLastCompletedKit(history, uid)
		lastKitCache[uid] = kit or false
		lastKitPending[uid] = nil
		lastKitRetry[uid] = nil
	end

	local function failLastKit(uid)
		lastKitPending[uid] = nil
		lastKitRetry[uid] = tick() + 1.5
	end

	local function consumeHistoryRequest(uid, request)
		if type(request) == "table" and type(request.andThen) == "function" then
			local chained = pcall(function()
				request:andThen(function(data)
					finishLastKit(uid, data)
				end):catch(function()
					failLastKit(uid)
				end)
			end)
			if not chained then
				failLastKit(uid)
			end
			return
		end

		if type(request) == "table" then
			finishLastKit(uid, request)
		else
			failLastKit(uid)
		end
	end

	local function fetchLastKit(plr)
		if not plr then return end
		local uid = plr.UserId
		if lastKitCache[uid] ~= nil or lastKitPending[uid] then return end
		if lastKitRetry[uid] and tick() < lastKitRetry[uid] then return end

		lastKitPending[uid] = true

		task.spawn(function()
			local controllers = (bedwars.KnitClient and bedwars.KnitClient.Controllers)
				or (bedwars.Knit and bedwars.Knit.Controllers)
			local controller = bedwars.MatchHistoryController
				or (controllers and controllers.MatchHistoryController)
				or bedwars.MatchHistoryController

			local request = nil

			if controller and type(controller.requestMatchHistory) == "function" then
				local ok, result = pcall(function()
					return controller:requestMatchHistory(plr.Name)
				end)
				if ok then
					request = result
				end
			end

			if not request then
				pcall(function()
					request = bedwars.Client:Get("RequestMatchHistory"):CallServerAsync(plr.Name)
				end)
			end

			if not request then
				local _remotes = getgenv().remotes or remotes
				pcall(function()
					local remoteName = _remotes and (_remotes.RequestMatchHistory or "RequestMatchHistory") or "RequestMatchHistory"
					request = bedwars.Client:Get(remoteName):CallServerAsync(plr.Name)
				end)
			end

			if not request then
				pcall(function()
					local client = require(replicatedStorage.TS.remotes).default.Client
					request = client:Get("RequestMatchHistory"):CallServerAsync(plr.Name)
				end)
			end

			if not request then
				failLastKit(uid)
				return
			end

			consumeHistoryRequest(uid, request)
		end)
	end

	local function unclip(inst)
		local node = inst
		for _ = 1, 7 do
			if not node then break end
			pcall(function()
				node.ClipsDescendants = false
			end)
			node = node.Parent
		end
	end

	local function findPlayerFromRender(render)
		if not render then return nil end

		local image = tostring(render.Image or "")
		local userId = image:match("id=(%d+)")
			or image:match("userId=(%d+)")
			or image:match("(%d+)")

		if userId then
			local plr = Players:GetPlayerByUserId(tonumber(userId))
			if plr then return plr end
		end

		local node = render.Parent
		for _ = 1, 6 do
			if not node then break end
			local label = node:FindFirstChild("PlayerName", true)
			if label and label:IsA("TextLabel") then
				local text = label.Text
				for _, plr in Players:GetPlayers() do
					if plr.Name == text or plr.DisplayName == text or plr:GetAttribute("DisguiseDisplayName") == text then
						return plr
					end
					local smName = nil
					pcall(function()
						smName = bedwars.KnitClient.Controllers.StreamerModeController:getDisplayName(plr)
					end)
					if smName and smName == text then
						return plr
					end
				end
			end
			node = node.Parent
		end

		return nil
	end

	local function findHost(render)
		local node = render
		local fallback = nil

		for _ = 1, 8 do
			node = node and node.Parent
			if not node then break end

			if node.Name == "MatchDraftPlayerCard" then
				return node
			end

			if not fallback and node:FindFirstChild("PlayerName", true) and node:FindFirstChild("PlayerRender", true) then
				fallback = node
			end
		end

		return fallback or render.Parent
	end

	local function isEnemy(plr)
		if not plr or plr == player then return false end
		local myTeam = player:GetAttribute("Team")
		local theirTeam = plr:GetAttribute("Team")
		if myTeam and theirTeam then
			return myTeam ~= theirTeam
		end
		return true
	end

	local function ensureCurrentKit(host, plr)
		if not host or not host.Parent then return end
		unclip(host)

		local icon = host:FindFirstChild("aerov4KitRender")
		if not icon then
			icon = Instance.new("ImageLabel")
			icon.Name = "aerov4KitRender"
			icon.AnchorPoint = Vector2.new(1, 0.5)
			icon.Position = UDim2.new(1.05, 0, 0.5, 0)
			icon.Size = UDim2.new(1.5, 0, 1.5, 0)
			icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
			icon.BackgroundTransparency = 1
			icon.BorderSizePixel = 0
			icon.ImageTransparency = 0.4
			icon.ScaleType = Enum.ScaleType.Crop
			icon.ZIndex = 5

			local ratio = Instance.new("UIAspectRatioConstraint")
			ratio.AspectRatio = 1
			ratio.AspectType = Enum.AspectType.FitWithinMaxSize
			ratio.DominantAxis = Enum.DominantAxis.Width
			ratio.Parent = icon

			icon.Parent = host
		end

		local kit = plr:GetAttribute("PlayingAsKits") or "none"
		local image = resolveKitImage(kit)
		if icon.Image ~= image then
			icon.Image = image
		end
	end

	local function ensureLevel(host, plr)
		if not host or not host.Parent then return end
		local nameLabel = host:FindFirstChild("PlayerName", true)
		if not nameLabel then return end
		unclip(nameLabel)

		local levelLabel = nameLabel:FindFirstChild("aerov4KitLevel")
		if not levelLabel then
			levelLabel = Instance.new("TextLabel")
			levelLabel.Name = "aerov4KitLevel"
			levelLabel.AnchorPoint = Vector2.new(0, 0.5)
			levelLabel.Position = UDim2.new(1, 5, 0.5, 0)
			levelLabel.Size = UDim2.fromOffset(44, 15)
			levelLabel.BackgroundTransparency = 1
			levelLabel.TextColor3 = Color3.fromRGB(255, 214, 51)
			levelLabel.TextSize = 12
			levelLabel.Font = Enum.Font.GothamBold
			levelLabel.TextStrokeTransparency = 0.25
			levelLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
			levelLabel.TextXAlignment = Enum.TextXAlignment.Left
			levelLabel.TextYAlignment = Enum.TextYAlignment.Center
			levelLabel.ZIndex = 10001
			levelLabel.Parent = nameLabel
		end

		local level = plr:GetAttribute("PlayerLevel") or 0
		local text = "[" .. tostring(level) .. "]"
		if levelLabel.Text ~= text then
			levelLabel.Text = text
		end
	end

	local function createLastMatchBadge(host, plr, slot)
		slot = slot or 1
		local badge = Instance.new("Frame")
		badge.Name = "aerov4LastKit"
		badge:SetAttribute("UserId", plr.UserId)
		badge:SetAttribute("Slot", slot)
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.new(0.41, (slot - 1) * 58, 0.5, 0)
		badge.Size = UDim2.fromOffset(54, 56)
		badge.BackgroundTransparency = 1
		badge.BorderSizePixel = 0
		badge.ClipsDescendants = false
		badge.ZIndex = 10000
		badge.Visible = false

		local tag = Instance.new("TextLabel")
		tag.Name = "Tag"
		tag.AnchorPoint = Vector2.new(0.5, 0)
		tag.Position = UDim2.new(0.5, 0, 0, -1)
		tag.Size = UDim2.new(1.1, 0, 0, 14)
		tag.BackgroundTransparency = 1
		tag.Text = slot == 1 and "last game" or (slot .. " games ago")
		tag.TextColor3 = Color3.fromRGB(255, 64, 64)
		tag.TextSize = 10
		tag.Font = Enum.Font.FredokaOne
		tag.TextStrokeTransparency = 0.35
		tag.TextStrokeColor3 = Color3.new(0, 0, 0)
		tag.TextXAlignment = Enum.TextXAlignment.Center
		tag.ZIndex = 10002
		tag.Parent = badge

		local img = Instance.new("ImageLabel")
		img.Name = "Render"
		img.AnchorPoint = Vector2.new(0.5, 1)
		img.Position = UDim2.new(0.5, 0, 1, 1)
		img.Size = UDim2.fromOffset(44, 41)
		img.BackgroundTransparency = 1
		img.BorderSizePixel = 0
		img.ImageTransparency = 0.05
		img.ScaleType = Enum.ScaleType.Fit
		img.ZIndex = 10001
		img.Parent = badge

		badge.Parent = host
		return badge
	end

	local function ensureLastMatch(host, plr)
		if not host or not host.Parent then return end

		if not (LastKitToggle and LastKitToggle.Enabled) then
			for _, old in host:GetChildren() do
				if old.Name == "aerov4LastKit" then
					old:Destroy()
				end
			end
			return
		end

		unclip(host)

		local count = LastKitCount and LastKitCount.Value or 1
		local badges = {}
		for _, obj in host:GetChildren() do
			if obj.Name == "aerov4LastKit" then
				local slot = obj:GetAttribute("Slot") or 1
				if slot > count or badges[slot] then
					obj:Destroy()
				else
					badges[slot] = obj
				end
			end
		end

		local cached = lastKitCache[plr.UserId]
		if cached == nil then
			fetchLastKit(plr)
		end

		for slot = 1, count do
			local badge = badges[slot] or createLastMatchBadge(host, plr, slot)
			local kit = type(cached) == "table" and cached[slot]
			if kit then
				local img = badge:FindFirstChild("Render")
				local image = resolveKitImage(kit)
				if img and img.Image ~= image then
					img.Image = image
				end
				badge.Visible = true
			else
				badge.Visible = false
			end
		end
	end

	local function processRender(render)
		if not KitRender.Enabled or not render or not render.Parent then return end
		if render.Name ~= "PlayerRender" or not render:IsA("ImageLabel") then return end

		local plr = findPlayerFromRender(render)
		if not plr or not isEnemy(plr) then return end

		local host = findHost(render)
		if not host or not host.Parent then return end

		ensureCurrentKit(host, plr)
		if LevelToggle and LevelToggle.Enabled then
			ensureLevel(host, plr)
		else
			destroyNamed(host, "aerov4KitLevel")
		end
		ensureLastMatch(host, plr)
	end

	local function scanDraft(app)
		if not app or not app.Parent then return end
		for _, obj in app:GetDescendants() do
			if obj.Name == "PlayerRender" and obj:IsA("ImageLabel") then
				pcall(processRender, obj)
			end
		end
	end

	local function startScanner()
		if scanThread then return end

		scanThread = task.spawn(function()
			while KitRender and KitRender.Enabled do
				local app = PlayerGui:FindFirstChild("MatchDraftApp")

				if app ~= currentDraft then
					cleanupVisuals()
					clearLastKitCache()
					currentDraft = app
				end

				if app then
					pcall(scanDraft, app)
				end

				task.wait(0.25)
			end

			scanThread = nil
		end)
	end

	local function stopScanner()
		if scanThread then
			pcall(task.cancel, scanThread)
			scanThread = nil
		end

		if retryThread then
			pcall(task.cancel, retryThread)
			retryThread = nil
		end

		currentDraft = nil
		clearLastKitCache()
		cleanupVisuals()
	end

	KitRender = vape.Categories.Utility:CreateModule({
		Name = "KitRender",
		Tooltip = "renders enemy kits during draft and shows their last match kit",
		Function = function(callback)
			if callback then
				cleanupVisuals()
				clearLastKitCache()
				startScanner()

				if not PlayerGui:FindFirstChild("MatchDraftApp") then
					retryThread = task.spawn(function()
						while KitRender.Enabled and not PlayerGui:FindFirstChild("MatchDraftApp") do
							task.wait(0.25)
						end
						if KitRender.Enabled then
							startScanner()
						end
						retryThread = nil
					end)
				end
			else
				stopScanner()
			end
		end
	})

	LastKitToggle = KitRender:CreateToggle({
		Name = "Show Last Match",
		Default = true,
		Tooltip = "shows the kit they used in their last completed match",
		Function = function(callback)
			if LastKitCount then
				LastKitCount.Object.Visible = callback
			end

			if not callback then
				cleanupLastMatch()
				return
			end

			clearLastKitCache()
			if KitRender and KitRender.Enabled then
				local app = PlayerGui:FindFirstChild("MatchDraftApp")
				if app then
					pcall(scanDraft, app)
				end
			end
		end
	})

	LastKitCount = KitRender:CreateSlider({
		Name = "last match count",
		Min = 1,
		Max = 3,
		Default = 1,
		Tooltip = "how many of they old kits u tryna see gng, 1 is they last game and 3 is 3 games ago",
		Function = function()
			if KitRender and KitRender.Enabled then
				local app = PlayerGui:FindFirstChild("MatchDraftApp")
				if app then
					pcall(scanDraft, app)
				end
			end
		end
	})
	LastKitCount.Object.Visible = LastKitToggle.Enabled

	LevelToggle = KitRender:CreateToggle({
		Name = "show level",
		Default = true,
		Tooltip = "shows they level next to they name so u know if they a sweat or not",
		Function = function()
			if KitRender and KitRender.Enabled then
				local app = PlayerGui:FindFirstChild("MatchDraftApp")
				if app then
					pcall(scanDraft, app)
				end
			end
		end
	})
end)

run(function()
	local StaffDetector
	local Mode
	local Clans
	local Party
	local Profile
	local Users
	local AlertDuration
	local blacklistedclans = {'gg', 'gg2', 'DV', 'DV2', 'nwr'}
	local blacklisteduserids = {1502104539, 3826146717, 4531785383, 1049767300, 4926350670, 653085195, 184655415, 2752307430, 5087196317, 5744061325, 1536265275}
	local apiModNames = {}
	local teamNameMap = { [1] = 'Blue', [2] = 'Orange', [3] = 'Pink', [4] = 'Yellow' }
	local joined = {}
	local detectedPlayers = {}
	local processing = {}
	for _, name in ipairs({'chasemaser','IllIlllIIIllllIIIll','7SlyR','DoordashRP','OrionYeets','lIllllllllllIllIIlll','AUW345678','the2ndtestaccount','IllIIIIlllIlllIIIIIl','IllIIIIlllIlllIlIIII','ProSurferGamer1','22willow_place','celisnix','G_TP56','celisnix_3','nwrkr','lIIlIlIllllllIIlI','IllIIIIIIlllllIIlIlI','GorillaWithASuit','liilliilliiiliill','IllIllIllllIIIIIIlIl','Typhoon_Kang','VictoryForLife2468','IlIIIlllllIIIIlIIIIl','Erin_Ireland22','IIIIllIIIIIIlllIlIII','IIIIIlllIlllllIlII','Ghostwxstaken','wvwvwvwwvwvvwvw','lllIIllIllIIllIllII','TheAwkwardSponge','TotallyKoaIa','YT_GoraPlays','LegendaryToragon','appleapplelllllll','Yo_johnny67','llIIllIIllllIlIl','PoopFarm_1','llIIIllIIIIIllllIII','Lemon01204','HugeMudOtter','AGameMasterHD','krustykrab204','kevinchuey','IllIIIIlIllIlIIIlI','YoZevStar','pzlican','Deevicus','Blackprincess1','yhpro1230','eple_147','whoisdv2_erin','whoisdv4_erin','whoisdv3_erin','VicForLife14','SleeplessSoulmate','Jsquire07','DVwastaken','pxIican','devzebu','FunFamilyKids177','Artan3333','3MEWMTS5LJCB','Zengoulen','GloriousConfigB2','heywasupsir','c6chisa'}) do
		apiModNames[name:lower()] = true
	end
	local listsLoaded = true

	getgenv()._onnation_staffCounts = {spec=0, mod=0, impossible=0}
	local function refreshStaffCounts()
		local c = {spec=0, mod=0, impossible=0}
		for _, data in pairs(detectedPlayers) do
			local ct = data.checktype
			if ct == 'spectator' then c.spec += 1
			elseif ct == 'impossible_join' then c.impossible += 1
			elseif ct == 'unverified' then c.impossible += 1
			else c.mod += 1 end
		end
		getgenv()._aerov4_staffCounts = c
		vapeEvents.StaffCountUpdate:Fire()
	end

	local function staffFunction(plr, checktype)
		if detectedPlayers[plr.UserId] then return end
		if not vape.Loaded then repeat task.wait() until vape.Loaded end
		local duration = AlertDuration.Value
		local playerName = plr.Name
		local playerId = plr.UserId
		detectedPlayers[playerId] = {name=playerName, checktype=checktype, detectedTime=tick()}
		notif('StaffDetector', 'Staff Detected (' .. checktype .. '): ' .. playerName .. ' (' .. playerId .. ')', duration, 'alert')
		whitelist.customtags[playerName] = {{text='GAME STAFF', color=Color3.new(1,0,0)}}
		local isClanCheck = checktype:find('clan')
		if Party.Enabled and not isClanCheck then pcall(bedwars.PartyController.leaveParty) end
		local modeValue = Mode.Value
		if modeValue == 'Uninject' then
			task.spawn(function() vape:Uninject() end)
			game:GetService('StarterGui'):SetCore('SendNotification', {Title='StaffDetector',Text='Staff Detected ('..checktype..')\n'..playerName..' ('..playerId..')',Duration=duration})
		elseif modeValue == 'Requeue' then
			pcall(bedwars.QueueController.leaveQueue)
			bedwars.QueueController:joinQueue(store.queueType)
		elseif modeValue == 'Profile' then
			if checktype == 'known_mod' or checktype == 'blacklisted_user' then
				vape.Save = function() end
				if vape.Profile ~= Profile.Value then vape:Load(true, Profile.Value) end
			end
		elseif modeValue == 'AutoConfig' then
			local safe = {AutoClicker=true,Reach=true,Sprint=true,HitFix=true,StaffDetector=true}
			vape.Save = function() end
			for i, v in vape.Modules do
				if not (safe[i] or v.Category == 'Render') then
					if v.Enabled then v:Toggle() end
					v:SetBind('')
				end
			end
		end
		refreshStaffCounts()
	end

	local function playerAdded(plr)
		joined[plr.UserId] = plr.Name
		if plr == lplr then return end
		if processing[plr.UserId] then return end
		processing[plr.UserId] = true

		if not listsLoaded then
			local t = tick()
			repeat task.wait(0.1) until listsLoaded or (tick()-t > 3)
		end

		if table.find(blacklisteduserids, plr.UserId) or (Users and table.find(Users.ListEnabled, tostring(plr.UserId))) then
			staffFunction(plr, 'blacklisted_user')
			processing[plr.UserId] = nil
			return
		end

		if apiModNames[plr.Name:lower()] then
			staffFunction(plr, 'known_mod')
			processing[plr.UserId] = nil
			return
		end

		local function spectatorFunction(plr)
			if detectedPlayers[plr.UserId] then return end
			if not vape.Loaded then repeat task.wait() until vape.Loaded end
			detectedPlayers[plr.UserId] = {name=plr.Name, checktype='spectator', detectedTime=tick()}
			notif('StaffDetector', 'Spectator: '..plr.Name..' ('..tostring(plr.UserId)..') [has friend(s) in server]', AlertDuration.Value, 'warning')
			refreshStaffCounts()
		end

		local function unverifiedFunction(plr, failed, checked)
			if detectedPlayers[plr.UserId] then return end
			if not vape.Loaded then repeat task.wait() until vape.Loaded end
			detectedPlayers[plr.UserId] = {name=plr.Name, checktype='unverified', detectedTime=tick()}
			notif('StaffDetector', 'cant check '..plr.Name..' ('..tostring(plr.UserId)..') friends list gng, could be staff. couldnt check '..tostring(failed)..'/'..tostring(checked)..' ppl', AlertDuration.Value, 'warning')
			refreshStaffCounts()
		end

		local function checkJoin()
			if not plr:GetAttribute('Team') and plr:GetAttribute('Spectator') then
				local hasFriend = false
				local failed = 0
				local checked = 0
				for _, sp in ipairs(playersService:GetPlayers()) do
					if sp ~= plr then
						checked = checked + 1
						local ok, res = pcall(function() return plr:IsFriendsWith(sp.UserId) end)
						if not ok then failed = failed + 1 end
						if ok and res then hasFriend = true break end
					end
				end
				if hasFriend then
					spectatorFunction(plr)
				elseif failed > 0 or checked == 0 then
					unverifiedFunction(plr, failed, checked)
				else
					staffFunction(plr, 'impossible_join')
				end
				return true
			end
			return false
		end

		local spectatorConnection
		spectatorConnection = plr:GetAttributeChangedSignal('Spectator'):Connect(function()
			if checkJoin() then spectatorConnection:Disconnect() processing[plr.UserId] = nil end
		end)
		StaffDetector:Clean(spectatorConnection)

		if checkJoin() then processing[plr.UserId] = nil return end

		if Clans.Enabled then
			local function checkClanTag()
				local clanTag = plr:GetAttribute('ClanTag')
				if clanTag and table.find(blacklistedclans, clanTag) then
					staffFunction(plr, 'blacklisted_clan_' .. clanTag:lower())
				end
			end
			if plr:GetAttribute('ClanTag') then
				checkClanTag()
			else
				local clanConnection
				clanConnection = plr:GetAttributeChangedSignal('ClanTag'):Connect(function()
					clanConnection:Disconnect()
					checkClanTag()
				end)
				StaffDetector:Clean(clanConnection)
				task.delay(5, function() if clanConnection then clanConnection:Disconnect() end end)
			end
		end

		processing[plr.UserId] = nil
	end

	local function playerRemoving(plr)
		local userId = plr.UserId
		joined[userId] = nil
		processing[userId] = nil
		if detectedPlayers[userId] then
			local data = detectedPlayers[userId]
			notif('StaffDetector', data.name .. ' (' .. data.checktype .. ') has left the server', AlertDuration.Value, 'warning')
			if whitelist.customtags[data.name] then whitelist.customtags[data.name] = nil end
			detectedPlayers[userId] = nil
			refreshStaffCounts()
		end
	end

	StaffDetector = vape.Categories.Utility:CreateModule({
		Name = 'StaffDetector',
		Function = function(callback)
			if callback then
				StaffDetector:Clean(playersService.PlayerAdded:Connect(playerAdded))
				StaffDetector:Clean(playersService.PlayerRemoving:Connect(playerRemoving))
				for _, v in playersService:GetPlayers() do task.spawn(playerAdded, v) end
			else
				table.clear(joined) table.clear(processing) table.clear(detectedPlayers)
				refreshStaffCounts()
			end
		end,
		Tooltip = 'detects people with staff role and etc'
	})

	Mode = StaffDetector:CreateDropdown({Name='Mode',List={'Uninject','Profile','Requeue','AutoConfig','Notify'},Function=function(val) if Profile.Object then Profile.Object.Visible = val=='Profile' end end})
	AlertDuration = StaffDetector:CreateSlider({Name='Alert Duration',Min=5,Max=120,Default=60,Suffix='s',})
	Clans = StaffDetector:CreateToggle({Name='Blacklist clans',Default=true})
	ClosetDetect = StaffDetector:CreateToggle({Name='Closet Cheaters',Default=true,Tooltip='tells u if a known closet cheater is in ur game so u know who to watch out for gng'})
	Party = StaffDetector:CreateToggle({Name='Leave party'})
	Profile = StaffDetector:CreateTextBox({Name='Profile',Default='default',Darker=true,Visible=false})
	Users = StaffDetector:CreateTextList({Name='Users',Placeholder='player (userid)',Function=function() end})
	task.defer(function() if Profile and Profile.Object then Profile.Object.Visible = (Mode.Value=='Profile') end end)
end)

run(function()
	TrapDisabler = vape.Categories.Utility:CreateModule({
		Name = 'TrapDisabler',
		Tooltip = 'disables Snap Traps'
	})
end)

run(function()
    local BedAssist = {Enabled = false}
    local bedassistrange = {Value = 30}
    local bedassistsmoothness = {Value = 6}
    local bedassistangle = {Value = 70}
    local bedassistfirstperson = {Enabled = false}
    local bedassistshopcheck = {Enabled = false}
	local bedassisthandcheck = {Enabled = false}
	local bedassistlowestblock = {Enabled = false}
	
	local function getBedAimSpeed(speedVal, dt)
		local baseSpeed = 0.01
		local multiplier = 1.35
		local speed = baseSpeed * (multiplier ^ speedVal)
		return math.min(speed, 0.95) * (dt * 60)
	end

	local function checkHand()
		return isHoldingPickaxe() or isHoldingItem({'axe'})
	end

    local camera = gameCamera
    local beds = {}
    local Connections = {}

    local function isFirstPerson()
        if not (lplr.Character and lplr.Character:FindFirstChild("Head")) then return false end
        return (lplr.Character.Head.Position - camera.CFrame.Position).Magnitude < 2
    end

    local function getClosestEnemyBed(playerPos)
        local closestBed = nil
        local closestDistance = bedassistrange.Value
        local lowestY = math.huge

        for _, bed in pairs(beds) do
            if not bed.Parent then continue end

            if tostring(bed:GetAttribute("TeamId")) == tostring(lplr:GetAttribute("Team")) then
                continue
            end

            if bed:GetAttribute("BedShieldEndTime") and bed:GetAttribute("BedShieldEndTime") > workspace:GetServerTimeNow() then
                continue
            end

            local distance = (playerPos - bed.Position).Magnitude
            if distance > bedassistrange.Value then continue end

            local delta = (bed.Position - playerPos)
            local char = lplr.Character
            local localfacing = Vector3.new(1, 0, 0)
            if char and char:FindFirstChild("HumanoidRootPart") then
                localfacing = char.HumanoidRootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
                if localfacing.Magnitude < 0.001 then
                    localfacing = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
                end
                localfacing = localfacing.Unit
            else
                localfacing = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
                if localfacing.Magnitude > 0.001 then
                    localfacing = localfacing.Unit
                else
                    localfacing = Vector3.new(1, 0, 0)
                end
            end

            local flatDelta = delta * Vector3.new(1, 0, 1)
            local angle = math.huge
            if flatDelta.Magnitude > 0.1 then
                angle = math.acos(math.clamp(localfacing:Dot(flatDelta.Unit), -1, 1))
            else
                angle = 0
            end

            if angle <= math.rad(bedassistangle.Value) then
                if bedassistlowestblock.Enabled then
                    if bed.Position.Y < lowestY then
                        lowestY = bed.Position.Y
                        closestBed = bed
                    end
                else
                    if distance < closestDistance then
                        closestDistance = distance
                        closestBed = bed
                    end
                end
            end
        end

        return closestBed
    end

    BedAssist = vape.Categories.Utility:CreateModule({
        Name = "BedAssist",
        Function = function(callback)
            if callback then
                table.clear(beds)
                for _, bed in ipairs(collectionService:GetTagged("bed")) do
                    table.insert(beds, bed)
                end

                table.insert(Connections, collectionService:GetInstanceAddedSignal("bed"):Connect(function(bed)
                    table.insert(beds, bed)
                end))

                table.insert(Connections, collectionService:GetInstanceRemovedSignal("bed"):Connect(function(bed)
                    local i = table.find(beds, bed)
                    if i then
                        table.remove(beds, i)
                    end
                end))

                local heartbeatConn
                heartbeatConn = runService.Heartbeat:Connect(function(dt)
                    if not BedAssist.Enabled then
                        heartbeatConn:Disconnect()
                        camera.CameraType = Enum.CameraType.Custom
                        return
                    end
                    if not lplr.Character or not lplr.Character:FindFirstChild("HumanoidRootPart") then
                        return
                    end
					if bedassisthandcheck.Enabled and not checkHand() then 
						return
					end
                    if bedassistfirstperson.Enabled and not isFirstPerson() then
                        return
                    end
                    if bedassistshopcheck.Enabled then
                        local isShop = lplr:FindFirstChild("PlayerGui") and lplr.PlayerGui:FindFirstChild("ItemShop")
                        if isShop then return end
                    end

                    if #beds == 0 then return end

                    local playerPos = lplr.Character.HumanoidRootPart.Position
                    local closestBed = getClosestEnemyBed(playerPos)

                    if closestBed then
                        local bedPos = closestBed.Position
                        local currentCFrame = camera.CFrame
                        local targetCFrame = CFrame.lookAt(currentCFrame.Position, bedPos)
                        local lerpAmount = bedassistsmoothness.Value / 15
                        camera.CFrame = currentCFrame:Lerp(targetCFrame, math.min(getBedAimSpeed(bedassistsmoothness.Value, dt), 0.95))
                    end
                end)
                table.insert(Connections, heartbeatConn)
            else
                for _, v in pairs(Connections) do
                    pcall(function()
                        v:Disconnect()
                    end)
                end
                Connections = {}
                table.clear(beds)
                camera.CameraType = Enum.CameraType.Custom
            end
        end,
        Tooltip = "aa for beds lol"
    })

    bedassistrange = BedAssist:CreateSlider({
        Name = "Assist Range",
        Min = 10,
        Max = 100,
        Function = function(val) end,
        Default = 30,
        Suffix = function(val) 
            return val == 1 and "stud" or "studs" 
        end
    })

    bedassistsmoothness = BedAssist:CreateSlider({
        Name = "Aim Speed",
        Min = 1,
        Max = 20,
        Function = function(val) end,
        Default = 6
    })

    bedassistangle = BedAssist:CreateSlider({
        Name = "Max Angle",
        Min = 10,
        Max = 360,
        Function = function(val) end,
        Default = 70
    })

    bedassistfirstperson = BedAssist:CreateToggle({
        Name = "First Person Only",
        Function = function() end,
        Default = false,
    })

    bedassistshopcheck = BedAssist:CreateToggle({
        Name = "Shop Check",
        Function = function() end,
        Default = false,
    })

	bedassisthandcheck = BedAssist:CreateToggle({
		Name = "Hand Check",
		Function = function() end,
		Default = true,
	})

	bedassistlowestblock = BedAssist:CreateToggle({
		Name = "Target Lowest Block",
		Function = function() end,
		Default = false,
	})
end)

run(function()
	local UIS = game:GetService('UserInputService')
	local CustomCursor = {Enabled = false}
	local mouseDropdown = {Value = 'Arrow'}
	local mouseIcons = {
		['CS:GO'] = 'rbxassetid://14789879068',
		['Old Roblox Mouse'] = 'rbxassetid://13546344315',
		['dx9ware'] = 'rbxassetid://12233942144',
		['Aimbot'] = 'rbxassetid://8680062686',
		['Triangle'] = 'rbxassetid://14790304072',
		['Arrow'] = 'rbxassetid://14790316561'
	}
	local customMouseIcon = {Enabled = false}
	local customIcon = {Value = ''}
	CustomCursor = vape.Categories.Utility:CreateModule({
		Name = 'CustomCursor',
		Tooltip = 'changes your cursor\'s image.',
		Function = function(callback)
			if callback then
				local function applyIcon()
					if customMouseIcon.Enabled then
						UIS.MouseIcon = 'rbxassetid://' .. customIcon.Value
					else
						UIS.MouseIcon = mouseIcons[mouseDropdown.Value]
					end
				end
				applyIcon()
				CustomCursor:Clean(UIS:GetPropertyChangedSignal('MouseIcon'):Connect(function()
					if CustomCursor.Enabled then
						applyIcon()
					end
				end))
				local playerGui = lplr:FindFirstChildOfClass('PlayerGui')
				if playerGui then
					for _, obj in ipairs(playerGui:GetDescendants()) do
						pcall(function()
							if obj:IsA('GuiButton') and obj.MouseIcon ~= '' then
								obj.MouseIcon = ''
							end
						end)
					end
					CustomCursor:Clean(playerGui.DescendantAdded:Connect(function(obj)
						pcall(function()
							if obj:IsA('GuiButton') then
								obj.MouseIcon = ''
							end
						end)
					end))
				end
				CustomCursor:Clean(runService.Heartbeat:Connect(applyIcon))
			else
				UIS.MouseIcon = ''
				task.wait()
				UIS.MouseIcon = ''
			end
		end
	})
	mouseDropdown = CustomCursor:CreateDropdown({
		Name = 'Mouse Icon',
		List = {
			'CS:GO',
			'Old Roblox Mouse',
			'dx9ware',
			'Aimbot',
			'Triangle',
			'Arrow'
		},
		Function = function() end
	})
	customMouseIcon = CustomCursor:CreateToggle({
		Name = 'Custom Icon',
		Function = function(callback) end
	})
	customIcon = CustomCursor:CreateTextBox({
		Name = 'Custom Mouse Icon',
		TempText = 'Image ID (not decal)',
		FocusLost = function(enter) 
			if CustomCursor.Enabled then 
				CustomCursor:Toggle(false)
				CustomCursor:Toggle(false)
			end
		end
	})
end)

run(function()
	local StaffHUD
	local ShowSpec
	local ShowMod
	local ShowImpossible
	local STAFF_GROUP_ID = 5774246
	local STAFF_MIN_RANK = 100

	local rowDefs = {
		{key='spec', label='Spec', color=Color3.fromRGB(100,180,255), order=1},
		{key='mod', label='Mod', color=Color3.fromRGB(255,60,60), order=3},
		{key='impossible', label='Impossible', color=Color3.fromRGB(200,50,255), order=4},
	}

	local tracked  = {}
	local counts   = {spec=0, closet=0, mod=0, impossible=0}
	local watchers = {}

	local apiClosetNames = {}
	local apiModNames = {}
	local listsLoaded = false

	local function loadLists()
		for _, name in ipairs({'chasemaser','IllIlllIIIllllIIIll','7SlyR','DoordashRP','OrionYeets','lIllllllllllIllIIlll','AUW345678','the2ndtestaccount','IllIIIIlllIlllIIIIIl','IllIIIIlllIlllIlIIII','ProSurferGamer1','22willow_place','celisnix','G_TP56','celisnix_3','nwrkr','lIIlIlIllllllIIlI','IllIIIIIIlllllIIlIlI','GorillaWithASuit','liilliilliiiliill','IllIllIllllIIIIIIlIl','Typhoon_Kang','VictoryForLife2468','IlIIIlllllIIIIlIIIIl','Erin_Ireland22','IIIIllIIIIIIlllIlIII','IIIIIlllIlllllIlII','Ghostwxstaken','wvwvwvwwvwvvwvw','lllIIllIllIIllIllII','TheAwkwardSponge','TotallyKoaIa','YT_GoraPlays','LegendaryToragon','appleapplelllllll','Yo_johnny67','llIIllIIllllIlIl','PoopFarm_1','llIIIllIIIIIllllIII','Lemon01204','HugeMudOtter','AGameMasterHD','krustykrab204','kevinchuey','IllIIIIlIllIlIIIlI','YoZevStar','pzlican','Deevicus','Blackprincess1','yhpro1230','eple_147','whoisdv2_erin','whoisdv4_erin','whoisdv3_erin','VicForLife14','SleeplessSoulmate','Jsquire07','DVwastaken','pxIican','devzebu','FunFamilyKids177','Artan3333','3MEWMTS5LJCB','Zengoulen','GloriousConfigB2','heywasupsir','c6chisa'}) do
			apiModNames[name:lower()] = true
		end
		listsLoaded = true
	end

	local gui = Instance.new('ScreenGui')
	gui.Name = 'StaffHUD'
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = vape.gui
	gui.Enabled = false

	local frame = Instance.new('Frame')
	frame.Name = 'Container'
	frame.Parent = gui
	frame.BackgroundColor3 = Color3.fromRGB(15,15,15)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.AnchorPoint = Vector2.new(1,1)
	frame.Position = UDim2.new(1,-8,1,-8)
	frame.Size = UDim2.new(0,110,0,14)
	frame.AutomaticSize = Enum.AutomaticSize.Y

	local uicorner = Instance.new('UICorner')
	uicorner.CornerRadius = UDim.new(0,6)
	uicorner.Parent = frame

	local pad = Instance.new('UIPadding')
	pad.PaddingLeft=UDim.new(0,6) pad.PaddingRight=UDim.new(0,6)
	pad.PaddingTop=UDim.new(0,4)  pad.PaddingBottom=UDim.new(0,4)
	pad.Parent = frame

	local layout = Instance.new('UIListLayout')
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0,2)
	layout.Parent = frame

	local rowObjects = {}
	for _, r in rowDefs do
		local lbl = Instance.new('TextLabel')
		lbl.Name = r.key
		lbl.Parent = frame
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1,0,0,13)
		lbl.TextColor3 = r.color
		lbl.TextSize = 11
		lbl.Font = Enum.Font.GothamBold
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextStrokeTransparency = 0.4
		lbl.TextStrokeColor3 = Color3.new(0,0,0)
		lbl.LayoutOrder = r.order
		lbl.Visible = false
		rowObjects[r.key] = lbl
	end

	local function updateDisplay()
		if not StaffHUD or not StaffHUD.Enabled then gui.Enabled = false return end
		local toggleMap = {spec=ShowSpec,mod=ShowMod,impossible=ShowImpossible}
		local anyVisible = false
		for _, r in rowDefs do
			local show = toggleMap[r.key] and toggleMap[r.key].Enabled
			rowObjects[r.key].Text = r.label .. ': ' .. (counts[r.key] or 0)
			rowObjects[r.key].Visible = show
			if show then anyVisible = true end
		end
		gui.Enabled = anyVisible
	end

	local function setTracked(userId, newCat)
		local old = tracked[userId]
		if old == newCat then return end
		if old then counts[old] = math.max(0,(counts[old] or 1)-1) end
		if newCat then
			tracked[userId] = newCat
			counts[newCat] = (counts[newCat] or 0) + 1
		else
			tracked[userId] = nil
		end
		updateDisplay()
	end

	local function removePlayer(userId)
		setTracked(userId, nil)
		if watchers[userId] then
			for _, c in ipairs(watchers[userId]) do pcall(function() c:Disconnect() end) end
			watchers[userId] = nil
		end
	end

	local function hasFriendInServer(plr)
		for _, other in ipairs(playersService:GetPlayers()) do
			if other ~= plr then
				local ok, res = pcall(function() return plr:IsFriendsWith(other.UserId) end)
				if ok and res then return true end
			end
		end
		return false
	end

	local function recheckSpec(plr)
		if not StaffHUD or not StaffHUD.Enabled then return end
		local cat = tracked[plr.UserId]
		if cat == 'closet' or cat == 'mod' then return end
		if plr:GetAttribute('Spectator') == true then
			task.spawn(function()
				local hasFriend = hasFriendInServer(plr)
				setTracked(plr.UserId, hasFriend and 'spec' or 'impossible')
			end)
		else
			if cat == 'spec' or cat == 'impossible' then
				setTracked(plr.UserId, nil)
			end
		end
	end

	local function watchPlayer(plr)
		if plr == lplr or watchers[plr.UserId] then return end
		local conns = {}
		table.insert(conns, plr:GetAttributeChangedSignal('Spectator'):Connect(function() recheckSpec(plr) end))
		table.insert(conns, plr:GetAttributeChangedSignal('Team'):Connect(function() recheckSpec(plr) end))
		watchers[plr.UserId] = conns
	end

	local function classifyPlayer(plr)
		if plr == lplr then return end
		local lowerName = plr.Name:lower()
		if apiModNames[lowerName] then
			setTracked(plr.UserId, 'mod')
			watchPlayer(plr)
			return
		end

		watchPlayer(plr)
		recheckSpec(plr)
	end

	local function cleanAll()
		for _, conns in pairs(watchers) do
			for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
		end
		table.clear(watchers)
		table.clear(tracked)
		counts = {spec=0, closet=0, mod=0, impossible=0}
	end

	StaffHUD = vape.Categories.Utility:CreateModule({
		Name = 'StaffHUD',
		Function = function(callback)
			if callback then
				cleanAll()
				loadLists()
				task.spawn(function()
					local t = tick()
					repeat task.wait(0.1) until listsLoaded or (tick() - t > 5)
					for _, plr in ipairs(playersService:GetPlayers()) do
						classifyPlayer(plr)
					end
				end)
				StaffHUD:Clean(playersService.PlayerAdded:Connect(function(plr)
					classifyPlayer(plr)
				end))
				StaffHUD:Clean(playersService.PlayerRemoving:Connect(function(plr)
					removePlayer(plr.UserId)
				end))
				StaffHUD:Clean(runService.Heartbeat:Connect(function()
					local compactUI = vape.gui:FindFirstChild('GeneratorCompactUI')
					frame.Position = (compactUI and compactUI.Enabled) and UDim2.new(1, -136, 1, -8) or UDim2.new(1, -8, 1, -8)
				end))
				updateDisplay()
			else
				cleanAll()
				table.clear(apiClosetNames)
				table.clear(apiModNames)
				listsLoaded = false
				gui.Enabled = false
			end
		end,
		Tooltip = 'little counter ui for staff'
	})

	ShowSpec = StaffHUD:CreateToggle({Name='Spectators', Default=true, Function=function() updateDisplay() end})
	ShowMod = StaffHUD:CreateToggle({Name='Mods', Default=true, Function=function() updateDisplay() end})
	ShowImpossible = StaffHUD:CreateToggle({Name='Impossible Joins',Default=true, Function=function() updateDisplay() end})

	vape:Clean(function()
		cleanAll()
		pcall(function() gui:Destroy() end)
	end)
end)



run(function()
	local NetworkTP
	NetworkTP = vape.Categories.Utility:CreateModule({
		Name = 'NetworkTP',
		Function = function(callback)
			if callback then
				local items = collection('ItemDrop', NetworkTP)
				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						local humanoidHealth = entitylib.character.Humanoid.Health
						local currentTime = tick()

						for _, v in pairs(items) do
							local dropTime = v:GetAttribute('ClientDropTime')
							if not dropTime then continue end
							if (currentTime - dropTime) < 2 then continue end
							if isnetworkowner(v) and humanoidHealth > 0 then
								v.CFrame = CFrame.new(localPosition - Vector3.new(0, 3, 0))
							end
						end
					end
					task.wait(0.1)
				until not NetworkTP.Enabled
			end
		end,
		Tooltip = 'network ownership teleports item drops to you'
	})
end)

run(function()
    local AntiSuffo
    
    AntiSuffo = vape.Categories.Utility:CreateModule({
    	Name = 'AntiSuffo',
    	Function = function(call)
    		if call then
    			repeat
    				if entitylib.isAlive then
    					if
    						getPlacedBlock(entitylib.character.RootPart.Position)
    						and (
    							getPlacedBlock(entitylib.character.RootPart.Position + Vector3.new(0, 2, 0))
    							and getPlacedBlock(entitylib.character.RootPart.Position - Vector3.new(0, 2, 0))
    						)
    					then
    						entitylib.character.RootPart.CFrame += Vector3.new(0, 0.5, 0)
    						if entitylib.character.RootPart.AssemblyLinearVelocity.Y < -1 then
    							entitylib.character.RootPart.AssemblyLinearVelocity = Vector3.zero
    						end
    					end
    				end
    				task.wait()
    			until not AntiSuffo.Enabled
    		end
    	end,
    	Tooltip = 'no more suffocating in blocks',
    })
end)

run(function()
	local ShopTierBypass
	local tiered, nexttier = {}, {}
	local originalGetShop
	local originalClientGet
	local originalControllerShop
	local hookedController
	local shopItemsTracked = {}
	local tierChains = {}
	local knownTiers = {
		{'wood_pickaxe', 'stone_pickaxe', 'iron_pickaxe', 'diamond_pickaxe'},
		{'wood_axe', 'stone_axe', 'iron_axe', 'diamond_axe'},
		{'leather_chestplate', 'iron_chestplate', 'diamond_chestplate', 'emerald_chestplate'},
	}
	
	local function applyBypassToItem(item)
		if item and type(item) == "table" then
			if not tiered[item] then 
				tiered[item] = item.tiered 
			end
			if not nexttier[item] then 
				nexttier[item] = item.nextTier 
			end
			item.nextTier = nil
			item.tiered = nil
			shopItemsTracked[item] = true
		end
	end
	
	local function applyBypassToTable(tbl)
		if tbl and type(tbl) == "table" then
			for _, item in pairs(tbl) do
				if type(item) == "table" then
					applyBypassToItem(item)
				end
			end
		end
	end
	
	local function hasItemOwned(itemType)
		if getItem(itemType) then return true end
		local armor = store.inventory.inventory.armor
		if armor then
			for _, a in armor do
				if type(a) == 'table' and a.itemType == itemType then
					return true
				end
			end
		end
		return false
	end

	local function isDowngrade(itemType)
		local chain = tierChains[itemType]
		if not chain then return false end
		local myIndex = chain.index[itemType]
		for i = myIndex + 1, #chain.items do
			if hasItemOwned(chain.items[i]) then return true end
		end
		return false
	end

	local function shouldBlock(itemType)
		if not tierChains[itemType] then return false end
		if hasItemOwned(itemType) then return true end
		if isDowngrade(itemType) then return true end
		return false
	end

	local function getShopController()
		local success, result = pcall(function()
			local RuntimeLib = require(game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("RuntimeLib"))
			if RuntimeLib then
				return RuntimeLib.import(script, game:GetService("ReplicatedStorage"), "TS", "games", "bedwars", "shop", "bedwars-shop")
			end
		end)
		
		if success then
			return result
		end
		
		local shopModule = game:GetService("ReplicatedStorage"):FindFirstChild("TS"):FindFirstChild("games"):FindFirstChild("bedwars"):FindFirstChild("shop"):FindFirstChild("bedwars-shop")
		if shopModule and shopModule:IsA("ModuleScript") then
			return require(shopModule)
		end
		
		return nil
	end
	
	ShopTierBypass = vape.Categories.Utility:CreateModule({
		Name = 'ShopTierBypass',
		Function = function(callback)
			if callback then
				local function collectAndBypass()
					local itemsSeen = {}
					if bedwars.Shop and bedwars.Shop.ShopItems then
						for _, v in pairs(bedwars.Shop.ShopItems) do
							itemsSeen[v] = true
						end
					end
					if bedwars.ShopItems then
						for _, v in pairs(bedwars.ShopItems) do
							itemsSeen[v] = true
						end
					end
					
					local shopController = getShopController()
					if shopController and shopController.BedwarsShop and shopController.BedwarsShop.getShop then
						local shopTable = shopController.BedwarsShop.getShop()
						if type(shopTable) == "table" then
							for _, v in pairs(shopTable) do
								itemsSeen[v] = true
							end
						end
					end
					for item, _ in pairs(itemsSeen) do
						applyBypassToItem(item)
					end

					local itemsByType = {}
					for item, _ in pairs(itemsSeen) do
						if item.itemType then
							itemsByType[item.itemType] = item
						end
					end
					for _, group in knownTiers do
						local chain = {items = {}, index = {}}
						for _, it in group do
							if itemsByType[it] then
								table.insert(chain.items, it)
								chain.index[it] = #chain.items
							end
						end
						if #chain.items > 1 then
							for _, it in chain.items do
								tierChains[it] = chain
							end
						end
					end
				end
				collectAndBypass()
				if bedwars.Shop and bedwars.Shop.getShop and not originalGetShop then
					originalGetShop = bedwars.Shop.getShop
					bedwars.Shop.getShop = function(...)
						local result = originalGetShop(...)
						if type(result) == "table" then
							applyBypassToTable(result)
						end
						return result
					end
				end
				
				if not originalClientGet then
					originalClientGet = bedwars.Client.Get
					local wrapperCache = setmetatable({}, {__mode = 'kv'})
					bedwars.Client.Get = function(self, name, ...)
						local remote = originalClientGet(self, name, ...)
						if name == 'BedwarsPurchaseItem' then
							local cached = wrapperCache[remote]
							if cached then return cached end
							local wrapper = {}
							wrapperCache[remote] = wrapper
							setmetatable(wrapper, {
								__index = function(_, key)
									if key == 'CallServerAsync' then
										return function(_, data, ...)
											if data and data.shopItem and data.shopItem.itemType then
												local itemType = data.shopItem.itemType
												if shouldBlock(itemType) then
													local displayName = bedwars.ItemMeta[itemType] and bedwars.ItemMeta[itemType].displayName or itemType
													if isDowngrade(itemType) then
														notif('ShopTierBypass', 'prevented yo ass from downgrading to '..displayName, 3, 'alert')
													else
														notif('ShopTierBypass', 'u alr got this item lmao: ', 3, 'alert')
													end
													return {andThen = function() end}
												end
											end
											return remote:CallServerAsync(data, ...)
										end
									end
									local value = remote[key]
									if type(value) == 'function' then
										return function(_, ...)
											return value(remote, ...)
										end
									end
									return value
								end
							})
							return wrapper
						end
						return remote
					end
				end

				local shopController = getShopController()
				if shopController and shopController.BedwarsShop and shopController.BedwarsShop.getShop then
					if not originalControllerShop then
						hookedController = shopController.BedwarsShop
						originalControllerShop = hookedController.getShop
						local base = originalControllerShop
						hookedController.getShop = function(...)
							local result = base(...)
							if type(result) == "table" then
								applyBypassToTable(result)
							end
							return result
						end
					end
				end
			else
				for item, _ in pairs(shopItemsTracked) do
					if item and type(item) == "table" then
						if tiered[item] ~= nil then
							item.tiered = tiered[item]
						end
						if nexttier[item] ~= nil then
							item.nextTier = nexttier[item]
						end
					end
				end
				
				if hookedController and originalControllerShop then
					hookedController.getShop = originalControllerShop
					originalControllerShop = nil
					hookedController = nil
				end
				
				if originalGetShop then
					bedwars.Shop.getShop = originalGetShop
					originalGetShop = nil
				end

				if originalClientGet then
					bedwars.Client.Get = originalClientGet
					originalClientGet = nil
				end
				
				table.clear(tiered)
				table.clear(nexttier)
				table.clear(shopItemsTracked)
				table.clear(tierChains)
			end
		end,
		Tooltip = 'lets u buy shit without buying the other tiers'
	})

	vape:Clean(function()
		if originalGetShop then
			pcall(function() bedwars.Shop.getShop = originalGetShop end)
			originalGetShop = nil
		end
		if originalClientGet then
			pcall(function() bedwars.Client.Get = originalClientGet end)
			originalClientGet = nil
		end
	end)
end)

run(function()
    local AutoPearl
    local Limit
    
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    rayCheck.FilterType = Enum.RaycastFilterType.Include
    local groundCheck = RaycastParams.new()
    groundCheck.RespectCanCollide = true
    groundCheck.FilterType = Enum.RaycastFilterType.Include
    local projectileRemote = {InvokeServer = function(self, ...) end}
    task.spawn(function()
    	projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
    end)
    
    local function firePearl(pos, spot, item)
    	for _, v in store.selfProjectiles or {} do
    		if v.Name == 'telepearl' then
    			return
    		end
    	end

    	local originalSlot = store.inventory.hotbarSlot
    	local pearlSlot = getHotbar(item.tool)
    	if not pearlSlot then
    		switchItem(item.tool)
    	else
    		if hotbarSwitch(pearlSlot) then
    			task.wait(0.05)
    		end
    	end
    
    	local meta = bedwars.ProjectileMeta.telepearl
    	local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)
    
    	if calc then
    		local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
    		local projectile = bedwars.ProjectileController:createLocalProjectile(meta, 'telepearl', 'telepearl', pos, nil, dir, {drawDurationSeconds = 1})
    		local res = projectileRemote:InvokeServer(
    			item.tool,
    			'telepearl',
    			'telepearl',
    			pos,
    			pos,
    			dir,
    			httpService:GenerateGUID(true),
    			{ 
                    drawDurationSeconds = 1, 
                    shotId = httpService:GenerateGUID(false) 
                },
    			workspace:GetServerTimeNow() - 0.045
    		)
    		if res then
    			pcall(function()
    				res.Parent = replicatedStorage
    			end)
    		end
    	end
    
    	if pearlSlot then
    		task.wait(0.05)
    		local swordSlot
    		for i, hv in store.inventory.hotbar do
    			if hv and hv.item and hv.item.itemType then
    				local hm = bedwars.ItemMeta[hv.item.itemType]
    				if hm and hm.sword then
    					swordSlot = i - 1
    					break
    				end
    			end
    		end
    		hotbarSwitch(swordSlot or originalSlot)
    	end
    end
    
    local function findNearGround(origin)
    	for _, v in {Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1)} do
    		for i = 1, 24 do
    			local ray = workspace:Raycast((origin.Position + (Vector3.yAxis * 3)) + (v * i), Vector3.new(0, -60, 0), groundCheck)
    			if ray then
    				return ray.Position + Vector3.new(0, 2, 0)
    			end
    		end
    	end
    	return nil
    end
    
    AutoPearl = vape.Categories.Utility:CreateModule({
    	Name = 'AutoPearl',
    	Function = function(callback)
    		if callback then
    			local check, lasty
    			repeat
    				if entitylib.isAlive and (not Limit.Enabled or store.hand.tool and store.hand.tool.Name == 'telepearl') then
    					local root = entitylib.character.RootPart
    					local pearl = getItem('telepearl')
    					local mapFolder = workspace:FindFirstChild('Map') or workspace
    					rayCheck.FilterDescendantsInstances = {mapFolder}
    					rayCheck.CollisionGroup = root.CollisionGroup
    					groundCheck.FilterDescendantsInstances = {mapFolder}
    					groundCheck.CollisionGroup = 'Default'
    
    					if entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
    						lasty = root.CFrame
    					end
    
    					if pearl and root.Velocity.Y < -100 and not workspace:Raycast(root.Position, Vector3.new(0, -200, 0), rayCheck) then
    						if not check then
    							check = true
    							local ground = findNearGround(root.CFrame + Vector3.new(0, 40, 0)) or findNearGround(lasty and lasty + Vector3.new(0, 5, 0) or root.CFrame)
    							if ground then
    								firePearl(root.Position, ground, pearl)
    							end
    						end
    					else
    						check = false
    					end
    				end
    				task.wait(0.1)
    			until not AutoPearl.Enabled
    		end
    	end,
    	Tooltip = 'auto throws yo pearl when falling in the void'
    })
    
    Limit = AutoPearl:CreateToggle({
    	Name = 'Limit to pearl',
    	Tooltip = 'only throws when ur already holding a pearl'
    })
end)

--[[
	World Modules
]]

run(function()
	local Protect
	local Target
	local LimitItem
	local protectOffsets = {
		Vector3.new(3, 0, 0),
		Vector3.new(-3, 0, 0),
		Vector3.new(0, 0, 3),
		Vector3.new(0, 0, -3),
		Vector3.new(0, 3, 0),
		Vector3.new(0, -3, 0),
	}

	local function getMyBeehive()
		for _, v in collectionService:GetTagged('beehive') do
			if v:GetAttribute('PlacedByUserId') == lplr.UserId then
				return v
			end
		end
	end

	local function getTargetItem()
		if Target.Value == 'Beehive' then
			return getMyBeehive()
		end
	end

	local function getProtectBlock()
		if LimitItem.Enabled then
			if store.hand.toolType == 'block' then
				return store.hand.tool.Name
			end
			return nil
		end
		if StrongestBlock.Enabled then
			local best, bestHealth
			for _, item in store.inventory.inventory.items do
				local meta = bedwars.ItemMeta[item.itemType]
				if meta and meta.block and (item.amount or 0) > 0 then
					local health = meta.block.health or 0
					if not bestHealth or health > bestHealth then
						best = item.itemType
						bestHealth = health
					end
				end
			end
			return best
		end
		return getScaffoldBlockForModule(LimitItem)
	end

	Protect = vape.Categories.World:CreateModule({
		Name = 'Protect',
		Function = function(callback)
			if callback then
				repeat
					local item = getTargetItem()
					if item then
						local basePos = bedwars.BlockController:getBlockPosition(item.Position) * 3
						for _, offset in protectOffsets do
							if not Protect.Enabled then break end
							local pos = basePos + offset
							if not getPlacedBlock(pos) then
								local block = getProtectBlock()
								if block then
									task.spawn(bedwars.placeBlock, pos, block, false)
									task.wait(0.05)
								end
							end
						end
					end
					task.wait(0.5)
				until not Protect.Enabled
			end
		end,
		Tooltip = 'boxes ur hive in so nobody can break it gng - more coming soon ig'
	})

	Target = Protect:CreateDropdown({
		Name = 'Target',
		List = {'Beehive'},
		Default = 'Beehive'
	})
	LimitItem = Protect:CreateToggle({Name = 'Limit to items'})
	StrongestBlock = Protect:CreateToggle({Name = 'Use Strongest Block'})
end)

run(function()
	local BedProtector
	local LimitItem
	local AutoSwitch
	local RangeSlider
	local LayerSlider
	local currentLayer = 0
	local buildingComplete = false
	local heldBlockType = nil
	local previousSlot = nil
	local lastPlaceTime = 0

	local ALLOWED_BLOCKS = {
		obsidian = true,
		wood_plank_oak = true,
		wood_oak_plank = true,
		ceramic = true,
		stone_brick = true
	}

	local function isAllowedBlock(itemType)
		if ALLOWED_BLOCKS[itemType] then return true end
		return itemType:find('wool') ~= nil
	end

	local function getPyramid(size, grid)
		local positions = {}
		for h = size, 0, -1 do
			for w = h, 0, -1 do
				table.insert(positions, Vector3.new(w, (size - h), ((h + 1) - w)) * grid)
				table.insert(positions, Vector3.new(w * -1, (size - h), ((h + 1) - w)) * grid)
				table.insert(positions, Vector3.new(w, (size - h), (h - w) * -1) * grid)
				table.insert(positions, Vector3.new(w * -1, (size - h), (h - w) * -1) * grid)
			end
		end
		return positions
	end

	local function getMyBed()
		local myTeam = lplr:GetAttribute('Team')
		if not myTeam then return nil end
		local root = entitylib.character and entitylib.character.RootPart
		if not root then return nil end
		for _, bed in collectionService:GetTagged('bed') do
			if bed and bed.Parent and bed:GetAttribute('Team'..myTeam..'NoBreak') then
				local bedPos = bed:IsA('BasePart') and bed.Position or (bed.PrimaryPart and bed.PrimaryPart.Position or bed:GetPivot().Position)
				if (root.Position - bedPos).Magnitude < 40 then
					return bed
				end
			end
		end
		return nil
	end

	local function getBlocks()
		local blocks = {}
		for _, item in store.inventory.inventory.items do
			local meta = bedwars.ItemMeta[item.itemType]
			if meta and meta.block and not meta.block.seeThrough and (item.amount or 0) > 0 and isAllowedBlock(item.itemType) then
				table.insert(blocks, {itemType = item.itemType, tool = item.tool, health = meta.block.health or 0})
			end
		end
		table.sort(blocks, function(a, b) return a.health > b.health end)
		return blocks
	end

	local function getBlockTypeForLayer(_, blocks)
		if #blocks == 0 then return nil end
		return blocks[1]
	end

	local function getSlotFor(itemType)
		for i, v in store.inventory.hotbar do
			if v.item and v.item.itemType == itemType then
				return i - 1
			end
		end
		return nil
	end

	local function restorePreviousSlot()
		if heldBlockType then
			if previousSlot then hotbarSwitch(previousSlot) end
			heldBlockType = nil
			previousSlot = nil
		end
	end

	local function switchToBlock(itemType)
		if LimitItem.Enabled then return end
		if not AutoSwitch.Enabled then return end
		if heldBlockType == itemType then return end
		local slot = getSlotFor(itemType)
		if slot then
			previousSlot = previousSlot or store.inventory.hotbarSlot
			hotbarSwitch(slot)
			heldBlockType = itemType
		end
	end

	local function isPositionInRange(worldPos)
		local root = entitylib.character and entitylib.character.RootPart
		if not root then return false end
		return (root.Position - worldPos).Magnitude <= RangeSlider.Value
	end

	local function repairAll(bedCFrame, blocks, upto)
		if upto <= 0 then return end

		local block = getBlockTypeForLayer(0, blocks) or blocks[1]
		if LimitItem.Enabled then
			if store.hand.toolType ~= 'block' then return end
			if not isAllowedBlock(store.hand.tool.Name) then return end
			block = {itemType = store.hand.tool.Name}
		end
		if not block then return end

		local switched = false
		for layer = 0, upto - 1 do
			local positions = getPyramid(layer + 1, 3)
			for _, pos in positions do
				if not BedProtector.Enabled then return end
				local worldPos = (bedCFrame * CFrame.new(pos)).Position
				if isPositionInRange(worldPos) and not getPlacedBlock(worldPos) then
					if not switched then
						switchToBlock(block.itemType)
						switched = true
					end
					task.spawn(bedwars.placeBlock, worldPos, block.itemType, false)
				end
			end
		end
	end

	local function buildLayer(bedCFrame, blocks)
		if buildingComplete then return false end

		local block = getBlockTypeForLayer(currentLayer, blocks) or blocks[1]
		if not block then return false end

		if LimitItem.Enabled then
			if store.hand.toolType ~= 'block' then return false end
			if not isAllowedBlock(store.hand.tool.Name) then return false end
			block = {itemType = store.hand.tool.Name}
		end

		local positions = getPyramid(currentLayer + 1, 3)
		local allPlaced = true
		local hasMissingInRange = false

		for _, pos in positions do
			local worldPos = (bedCFrame * CFrame.new(pos)).Position
			if not getPlacedBlock(worldPos) then
				allPlaced = false
				if isPositionInRange(worldPos) then
					hasMissingInRange = true
				end
			end
		end

		if allPlaced then
			currentLayer += 1
			if currentLayer >= LayerSlider.Value then
				buildingComplete = true
				restorePreviousSlot()
				notif('BedProtector', 'bed is fully walled gng ur good', 4)
			end
			return false
		end

		if not hasMissingInRange then return false end

		for _, pos in positions do
			if not BedProtector.Enabled then break end
			local worldPos = (bedCFrame * CFrame.new(pos)).Position
			if isPositionInRange(worldPos) and not getPlacedBlock(worldPos) then
				if tick() - lastPlaceTime >= 0.05 then
					switchToBlock(block.itemType)
					task.spawn(bedwars.placeBlock, worldPos, block.itemType, false)
					lastPlaceTime = tick()
					task.wait(0.05)
				end
			end
		end
		return true
	end

	BedProtector = vape.Categories.World:CreateModule({
		Name = 'BedProtector',
		Function = function(callback)
			if callback then
				currentLayer = 0
				buildingComplete = false
				heldBlockType = nil
				previousSlot = nil
				repeat
					pcall(function()
						if not entitylib.isAlive then return end
						local bed = getMyBed()
						if not bed then
							restorePreviousSlot()
							return
						end
						local bedCFrame = bed:IsA('BasePart') and bed.CFrame or (bed.PrimaryPart and bed.PrimaryPart.CFrame or bed:GetPivot())
						local blocks = getBlocks()
						if #blocks == 0 and not LimitItem.Enabled then return end
						repairAll(bedCFrame, blocks, currentLayer)
						if not buildingComplete then
							buildLayer(bedCFrame, blocks)
						end
					end)
					task.wait(0.05)
				until not BedProtector.Enabled
				restorePreviousSlot()
			end
		end,
		Tooltip = 'stacks a pyramid over ur bed w ur strongest block'
	})

	LimitItem = BedProtector:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'only builds while ur already holdin a block'
	})
	AutoSwitch = BedProtector:CreateToggle({
		Name = 'Auto Switch',
		Default = true,
		Tooltip = 'swaps ur hotbar to the block by itself then swaps back after. ignored if limit to items is on'
	})
	RangeSlider = BedProtector:CreateSlider({
		Name = 'Place Range',
		Min = 1,
		Max = 30,
		Default = 15,
		Suffix = ' studs'
	})
	LayerSlider = BedProtector:CreateSlider({
		Name = 'Layers',
		Min = 1,
		Max = 10,
		Default = 3,
		Suffix = ' layers'
	})
end)

run(function()
	local a = {Enabled = false}
	a = vape.Categories.World:CreateModule({
		Name = "LeaveParty",
		Function = function(call)
			if call then
				a:Toggle(false)
				game:GetService("ReplicatedStorage"):WaitForChild("events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events"):WaitForChild("leaveParty"):FireServer()
			end
		end
	})
end)

run(function()
    local anim
    local asset
    local trackingConnection
    local lastPosition
    local NightmareEmote
    local cachedRootPart
    local cachedHumanoid
    local lastValidationCheck = 0
    
    NightmareEmote = vape.Categories.World:CreateModule({
        Name = "NightmareEmote",
        Function = function(call)
            if call then
                local l__GameQueryUtil__8
                if (not shared.CheatEngineMode) then 
                    l__GameQueryUtil__8 = require(game:GetService("ReplicatedStorage")['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil 
                else
                    local backup = {}; function backup:setQueryIgnored() end; l__GameQueryUtil__8 = backup;
                end
                local l__TweenService__9 = tweenService
                local player = playersService.LocalPlayer
                local character = player.Character
                
                if not character then 
                    NightmareEmote:Toggle() 
                    return 
                end
                
                local humanoid = character:WaitForChild("Humanoid")
                local rootPart = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
                
                if not rootPart then 
                    NightmareEmote:Toggle() 
                    return 
                end
                
                cachedRootPart = rootPart
                cachedHumanoid = humanoid
                lastPosition = rootPart.Position
                lastValidationCheck = 0
                
                local v10 = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Effects"):WaitForChild("NightmareEmote"):Clone()
                asset = v10
                v10.Parent = game.Workspace
                
                local descendants = v10:GetDescendants()
                for _, part in ipairs(descendants) do
                    if part:IsA("BasePart") then
                        l__GameQueryUtil__8:setQueryIgnored(part, true)
                        part.CanCollide = false
                        part.Anchored = true
                    end
                end
                
                local l__Outer__15 = v10:FindFirstChild("Outer")
                if l__Outer__15 then
                    l__TweenService__9:Create(l__Outer__15, TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {
                        Orientation = l__Outer__15.Orientation + Vector3.new(0, 360, 0)
                    }):Play()
                end
                
                local l__Middle__16 = v10:FindFirstChild("Middle")
                if l__Middle__16 then
                    l__TweenService__9:Create(l__Middle__16, TweenInfo.new(12.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {
                        Orientation = l__Middle__16.Orientation + Vector3.new(0, -360, 0)
                    }):Play()
                end
                
                anim = Instance.new("Animation")
                anim.AnimationId = "rbxassetid://9191822700"
                anim = humanoid:LoadAnimation(anim)
                anim:Play()
                
                local movementThresholdSq = 0.1 * 0.1
                
                trackingConnection = runService.RenderStepped:Connect(function()
                    if not asset or not asset.Parent then 
                        if trackingConnection then
                            trackingConnection:Disconnect()
                        end
                        return 
                    end
                    
                    local currentTime = tick()
                    
                    if (currentTime - lastValidationCheck) > 0.5 then
                        if not character or not character.Parent then
                            asset:Destroy()
                            asset = nil
                            if trackingConnection then
                                trackingConnection:Disconnect()
                            end
                            NightmareEmote:Toggle()
                            return
                        end
                        
                        if not cachedRootPart or not cachedRootPart.Parent then
                            cachedRootPart = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
                        end
                        
                        if not cachedHumanoid or not cachedHumanoid.Parent then
                            cachedHumanoid = character:FindFirstChildOfClass("Humanoid")
                        end
                        
                        if not cachedRootPart or not cachedHumanoid or cachedHumanoid.Health <= 0 then
                            asset:Destroy()
                            asset = nil
                            if trackingConnection then
                                trackingConnection:Disconnect()
                            end
                            NightmareEmote:Toggle()
                            return
                        end
                        
                        lastValidationCheck = currentTime
                    end
                    
                    if lastPosition and cachedRootPart then
                        local currentPosition = cachedRootPart.Position
                        local dx = currentPosition.X - lastPosition.X
                        local dy = currentPosition.Y - lastPosition.Y
                        local dz = currentPosition.Z - lastPosition.Z
                        local distanceMovedSq = dx * dx + dy * dy + dz * dz
                        
                        if distanceMovedSq > movementThresholdSq then
                            asset:Destroy()
                            asset = nil
                            if trackingConnection then
                                trackingConnection:Disconnect()
                            end
                            NightmareEmote:Toggle()
                            return
                        end
                        
                        lastPosition = currentPosition
                    end
                    
                    if cachedRootPart then
                        v10:SetPrimaryPartCFrame(cachedRootPart.CFrame * CFrame.new(0, -3, 0))
                    end
                end)
                
                NightmareEmote:Clean(trackingConnection)
                
            else 
                if trackingConnection then
                    trackingConnection:Disconnect()
                    trackingConnection = nil
                end
                
                if anim then 
                    anim:Stop()
                    anim = nil
                end
                
                if asset then
                    asset:Destroy() 
                    asset = nil
                end
                
                lastPosition = nil
                cachedRootPart = nil
                cachedHumanoid = nil
                lastValidationCheck = 0
            end
        end
    })
end)

run(function()
    local AutoCounter
    local tntCount
    local LimitItem
    local AutoPlaceToggle
    local HighlightToggle

    local alltntBlocks = {}
    local counteredtnt = {}
    local tntHighlights = {}
    local autoCounterPlacing = false

    local function addHighlight(tntBlock)
        if tntHighlights[tntBlock] or not tntBlock.Parent then return end
        local h = Instance.new('SelectionBox')
        h.Adornee = tntBlock
        h.Color3 = Color3.fromRGB(255, 50, 50)
        h.LineThickness = 0.05
        h.SurfaceTransparency = 0.6
        h.SurfaceColor3 = Color3.fromRGB(255, 50, 50)
        h.Parent = coreGui
        tntHighlights[tntBlock] = h
    end

    local function removeHighlight(tntBlock)
        if tntHighlights[tntBlock] then
            tntHighlights[tntBlock]:Destroy()
            tntHighlights[tntBlock] = nil
        end
    end

    local function clearAllHighlights()
        for _, h in pairs(tntHighlights) do
            h:Destroy()
        end
        table.clear(tntHighlights)
    end

    local function isEnemytnt(tntBlock)
        if not tntBlock or not tntBlock.Parent then return false end
        if tntBlock:GetAttribute("AutoCountertnt") then return false end

        local placerId = tntBlock:GetAttribute("PlacedByUserId")
        if not placerId then
            return true
        end

        if placerId == lplr.UserId then
            return false
        end
        local myTeam = lplr:GetAttribute('Team')
        if myTeam then
            for _, player in playersService:GetPlayers() do
                if player.UserId == placerId and player:GetAttribute('Team') == myTeam then
                    return false
                end
            end
        end

        return true
    end

    local function isHoldingtnt()
        return isHoldingItem({'tnt'})
    end

    AutoCounter = vape.Categories.World:CreateModule({
        Name = 'AutoCounter',
        Function = function(callback)
            if callback then
                table.clear(counteredtnt)

                local tntAddedConnection = workspace.DescendantAdded:Connect(function(obj)
                    if obj.Name == "tnt" and obj:IsA("Part") then
                        if autoCounterPlacing then
                            obj:SetAttribute("AutoCountertnt", true)
                        end
                        alltntBlocks[obj] = true

                        task.defer(function()
                            if HighlightToggle and HighlightToggle.Enabled and isEnemytnt(obj) then
                                addHighlight(obj)
                            end
                        end)

                        local ancestryConnection
                        ancestryConnection = obj.AncestryChanged:Connect(function()
                            if not obj.Parent then
                                alltntBlocks[obj] = nil
                                counteredtnt[obj] = nil
                                removeHighlight(obj)
                                local fixedPos = fixPosition(obj.Position)
                                local posKey = string.format("%.0f,%.0f,%.0f", fixedPos.X, fixedPos.Y, fixedPos.Z)
                                autoCounterPositions[posKey] = nil
                                if ancestryConnection then
                                    ancestryConnection:Disconnect()
                                end
                            end
                        end)
                    end
                end)
                AutoCounter:Clean(tntAddedConnection)

                scanDescendants(workspace, function(obj)
                    if obj.Name == "tnt" and obj:IsA("Part") and not alltntBlocks[obj] then
                        alltntBlocks[obj] = true
                    end
                end, AutoCounter)

                local horizontalSides = {}
                for _, side in ipairs(Enum.NormalId:GetEnumItems()) do
                    local sideVec = Vector3.fromNormalId(side)
                    if sideVec.Y == 0 then
                        table.insert(horizontalSides, sideVec)
                    end
                end

                repeat
                    if not entitylib.isAlive then
                        task.wait(0.1)
                        continue
                    end

                    if HighlightToggle and HighlightToggle.Enabled then
                        for tntBlock in pairs(alltntBlocks) do
                            if tntBlock.Parent and isEnemytnt(tntBlock) then
                                addHighlight(tntBlock)
                            end
                        end
                    else
                        clearAllHighlights()
                    end

                    if AutoPlaceToggle and AutoPlaceToggle.Enabled then
                        if LimitItem.Enabled and not isHoldingtnt() then
                            task.wait(0.1)
                            continue
                        end

                        if not getItem("tnt") then
                            task.wait(0.1)
                            continue
                        end

                        local myPosition = entitylib.character.RootPart.Position
                        local maxDistanceSq = 30 * 30

                        for tntBlock in pairs(alltntBlocks) do
                            if tntBlock.Parent and not counteredtnt[tntBlock] and isEnemytnt(tntBlock) then
                                local offset = tntBlock.Position - myPosition
                                local distanceSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z

                                if distanceSq <= maxDistanceSq then
                                    local placedCount = 0
                                    local maxCount = tntCount.Value

                                    for _, sideVec in ipairs(horizontalSides) do
                                        if LimitItem.Enabled and not isHoldingtnt() then break end
                                        if placedCount >= maxCount then break end

                                        local placePos = fixPosition(tntBlock.Position + sideVec * 3.5)
                                        if not getPlacedBlock(placePos) and getItem("tnt") then
                                            if LimitItem.Enabled and not isHoldingtnt() then break end
                                            autoCounterPlacing = true
                                            bedwars.placeBlock(placePos, "tnt")
                                            autoCounterPlacing = false
                                            placedCount = placedCount + 1
                                            task.wait(0.05)
                                        end
                                    end

                                    counteredtnt[tntBlock] = true
                                    task.defer(function()
                                        if tntBlock.Parent then
                                            tntBlock.AncestryChanged:Wait()
                                        end
                                        counteredtnt[tntBlock] = nil
                                    end)
                                end
                            end
                        end
                    end

                    task.wait(0.1)
                until not AutoCounter.Enabled
            else
                table.clear(counteredtnt)
                clearAllHighlights()
            end
        end,
        Tooltip = 'Highlights and counters enemys tnt'
    })

    tntCount = AutoCounter:CreateSlider({
        Name = 'tnt Count',
        Min = 1,
        Max = 5,
        Default = 3
    })

    LimitItem = AutoCounter:CreateToggle({
        Name = 'Limit to tnt',
        Default = true,
    })

    AutoPlaceToggle = AutoCounter:CreateToggle({
        Name = 'AutoPlace',
        Default = true,
    })

    HighlightToggle = AutoCounter:CreateToggle({
        Name = 'Highlight',
        Default = true,
    })
end)

run(function()
    local AutoTool
    local old, event
    
    local function switchHotbarItem(block)
        if block and not block:GetAttribute('NoBreak') and not block:GetAttribute('Team'..(lplr:GetAttribute('Team') or 0)..'NoBreak') then
            local meta = bedwars.ItemMeta and bedwars.ItemMeta[block.Name]
			if not meta or not meta.block then return end
			local tool, slot = store.tools and store.tools[meta.block.breakType], nil
            if tool then
                for i, v in store.inventory.hotbar do
                    if v.item and v.item.itemType == tool.itemType then slot = i - 1 break end
                end
    
                if hotbarSwitch(slot) then
                    if inputService:IsMouseButtonPressed(0) then 
                        event:Fire() 
                    end
                    return true
                end
            end
        end
    end
    
    AutoTool = vape.Categories.World:CreateModule({
        Name = 'AutoTool',
        Function = function(callback)
            if callback then
                event = Instance.new('BindableEvent')
                AutoTool:Clean(event)
                AutoTool:Clean(event.Event:Connect(function()
                    contextActionService:CallFunction('block-break', Enum.UserInputState.Begin, newproxy(true))
                end))
                registerHitBlockPatch('AutoTool', function(self, maid, raycastparams, ...)
                    local ok, block = pcall(function()
                        return self.clientManager:getBlockSelector():getMouseInfo(1, {ray = raycastparams})
                    end)
                    if not ok then return nil end
                    local inst = block and block.target and block.target.blockInstance or nil
                    local switched = false
                    pcall(function() switched = switchHotbarItem(inst) == true end)
                    if switched then return false end
                    return nil
                end)
            else
                unregisterHitBlockPatch('AutoTool')
                old = nil
            end
        end,
        Tooltip = 'auto selects the correct tool'
    })
end)
	
run(function()
	local ChestSteal
	local Range
	local Open
	local Skywars
	local DelayToggle
	local DelaySlider
	local TeamFilter
	local Delays = {}
	
	local function isTeamChest(chest)
		if not TeamFilter.Enabled then return false end
		local myTeam = tostring(lplr:GetAttribute('Team') or '')
		local myBed = nil
		for _, bed in collectionService:GetTagged('bed') do
			if not bed:IsA('BasePart') then continue end
			local bedTeam = tostring(bed:GetAttribute('Team') or bed:GetAttribute('TeamId') or '')
			if bedTeam == myTeam then myBed = bed break end
		end
		if not myBed then return false end
		local dist = (chest.Position - myBed.Position).Magnitude
		return dist <= 60
	end
	
	local function lootChest(chest)
		chest = chest and chest.Value or nil
		if not chest then return end
		
		local chestitems = chest and chest:GetChildren() or {}
		if #chestitems > 1 and (Delays[chest] or 0) < tick() then
			Delays[chest] = tick() + (DelayToggle.Enabled and DelaySlider.Value or 0.2)
			bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(chest)
	
			for _, v in chestitems do
				if v:IsA('Accessory') then
					if DelayToggle.Enabled then
						task.wait(DelaySlider.Value / #chestitems) 
					end
					
					task.spawn(function()
						pcall(function()
							bedwars.Client:GetNamespace('Inventory'):Get('ChestGetItem'):CallServer(chest, v)
						end)
					end)
				end
			end
	
			bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(nil)
		end
	end
	
	ChestSteal = vape.Categories.World:CreateModule({
		Name = 'ChestSteal',
		Function = function(callback)
			if callback then
				local chests = collection('chest', ChestSteal)
				repeat task.wait() until store.queueType ~= 'bedwars_test'
				if (not Skywars.Enabled) or store.queueType:find('skywars') then
					repeat
						if entitylib.isAlive and store.matchState ~= 2 then
							if Open.Enabled then
								if bedwars.AppController:isAppOpen('ChestApp') then
									lootChest(lplr.Character:FindFirstChild('ObservedChestFolder'))
								end
							else
								local localPosition = entitylib.character.RootPart.Position
								for _, v in chests do
									if (localPosition - v.Position).Magnitude <= Range.Value then
										if isTeamChest(v) then continue end
										lootChest(v:FindFirstChild('ChestFolderValue'))
									end
								end
							end
						end
						task.wait(0.1)
					until not ChestSteal.Enabled
				end
			end
		end,
		Tooltip = 'takes items from near chests'
	})
	Range = ChestSteal:CreateSlider({
		Name = 'Range',
		Min = 0,
		Max = 18,
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Open = ChestSteal:CreateToggle({Name = 'GUI Check'})
	Skywars = ChestSteal:CreateToggle({
		Name = 'Only Skywars',
		Function = function()
			if ChestSteal.Enabled then
				ChestSteal:Toggle()
				ChestSteal:Toggle()
			end
		end,
		Default = true
	})
	TeamFilter = ChestSteal:CreateToggle({
		Name = 'Team Check',
		Default = false
	})
	DelayToggle = ChestSteal:CreateToggle({
		Name = 'Delay',
		Function = function(callback)
			DelaySlider.Object.Visible = callback
			if ChestSteal.Enabled then
				ChestSteal:Toggle()
				ChestSteal:Toggle()
			end
		end
	})
    DelaySlider = ChestSteal:CreateSlider({
        Name = 'Delay Time',
        Min = 0.1,
        Max = 5,
        Default = 1,
        Decimal = 10,
        Suffix = 's',
        Visible = false
    })

    task.defer(function()
        if DelaySlider and DelaySlider.Object then
            DelaySlider.Object.Visible = false  
        end
    end)
end)

run(function()
	local FPSBoost
	local Kill
	local Visualizer
	local effects, util = {}, {}
	local originalAddGameNametag
	local nametagHooked = false
	
	FPSBoost = vape.Categories.World:CreateModule({
		Name = 'FPSBoost',
		Function = function(callback)
			if callback then
				if Kill.Enabled then
					for i, v in bedwars.KillEffectController.killEffects do
						if not i:find('Custom') then
							effects[i] = v
							bedwars.KillEffectController.killEffects[i] = {
								new = function() 
									return {
										onKill = function() end, 
										isPlayDefaultKillEffect = function() 
											return true 
										end
									} 
								end
							}
						end
					end
				end

			if Visualizer.Enabled then
				local keepKeys = {'beam', 'Beam', 'projectile', 'Projectile', 'draw', 'Draw', 'line', 'Line', 'ray', 'Ray', 'arc', 'Arc'}
				for i, v in bedwars.VisualizerUtils do
					local keep = false
					for _, k in keepKeys do
						if tostring(i):lower():find(k:lower()) then
							keep = true
							break
						end
					end
					if not keep then
						util[i] = v
						bedwars.VisualizerUtils[i] = function() end
					end
				end
			end

			else
				for i, v in effects do 
					bedwars.KillEffectController.killEffects[i] = v 
				end
				
				for i, v in util do 
					bedwars.VisualizerUtils[i] = v 
				end
				
				if nametagHooked and originalAddGameNametag then
					bedwars.NametagController.addGameNametag = originalAddGameNametag
					nametagHooked = false
				end
				
				table.clear(effects)
				table.clear(util)
			end
		end,
		Tooltip = 'improves fps - well tries'
	})
	
	Kill = FPSBoost:CreateToggle({
		Name = 'Kill Effects',
		Function = function()
			if FPSBoost.Enabled then
				FPSBoost:Toggle()
				FPSBoost:Toggle()
			end
		end,
		Default = true
	})
	
	Visualizer = FPSBoost:CreateToggle({
		Name = 'Visualizer',
		Function = function()
			if FPSBoost.Enabled then
				FPSBoost:Toggle()
				FPSBoost:Toggle()
			end
		end,
		Default = true
	})
end)

run(function()
	local ShadowRemover
	local connections = {}
	local originalShadows = {}
	local processedShadows = {}
	
	local function removeShadow(obj)
		if obj:IsA("BasePart") and not processedShadows[obj] then
			if not originalShadows[obj] then
				originalShadows[obj] = obj.CastShadow
			end
			obj.CastShadow = false
			processedShadows[obj] = true
		end
	end
	
	ShadowRemover = vape.Categories.World:CreateModule({
		Name = 'ShadowRemover',
		Function = function(callback)
			if callback then
				scanDescendants(workspace, removeShadow, ShadowRemover)
				
				local conn = workspace.DescendantAdded:Connect(function(obj)
					if ShadowRemover.Enabled then
						removeShadow(obj)
					end
				end)
				table.insert(connections, conn)
			else
				for obj, shadow in pairs(originalShadows) do
					if obj and obj.Parent then
						pcall(function()
							obj.CastShadow = shadow
						end)
					end
				end
				
				for _, conn in connections do
					conn:Disconnect()
				end
				table.clear(connections)
				table.clear(originalShadows)
				table.clear(processedShadows)
			end
		end,
	})
end)

run(function()
	local RemoveNeon = {Enabled = false}
	local neonConnection
	local safetyLoop
	local originalMaterials = {}
	local processedParts = {}
	local lastCleanup = 0
	
	local function cleanupDeadReferences()
		local count = 0
		for obj, _ in pairs(originalMaterials) do
			if not obj or not obj.Parent then
				originalMaterials[obj] = nil
				processedParts[obj] = nil
			end
			count = count + 1
			if count % 100 == 0 then
				task.wait()
			end
		end
	end
	
	local function removeNeonFromPart(obj)
		if obj:IsA("BasePart") then
			if obj.Material == Enum.Material.Neon then
				if not originalMaterials[obj] then
					originalMaterials[obj] = {
						Material = obj.Material,
						Reflectance = obj.Reflectance
					}
				end
				pcall(function()
					obj.Material = Enum.Material.Plastic
					obj.Reflectance = 0
				end)
			end
		end
	end
	
	local function restoreNeon()
		for obj, data in pairs(originalMaterials) do
			if obj and obj.Parent then
				pcall(function()
					obj.Material = data.Material
					obj.Reflectance = data.Reflectance
				end)
			end
		end
		table.clear(originalMaterials)
		table.clear(processedParts)
	end
	
	local function batchProcessParts(parts, batchSize)
		local count = 0
		for i, part in ipairs(parts) do
			if part and part.Parent then
				removeNeonFromPart(part)
				count = count + 1
			end
			if i % batchSize == 0 then
				task.wait()
			end
		end
		return count
	end
	
	RemoveNeon = vape.Categories.World:CreateModule({
		Name = 'RemoveNeon',
		Function = function(callback)
			if callback then
				task.spawn(function()
					local allParts = {}
					scanDescendants(workspace, function(v)
						if v:IsA("BasePart") then
							removeNeonFromPart(v)
						end
					end, RemoveNeon)
				end)
				
				neonConnection = workspace.DescendantAdded:Connect(function(obj)
					if RemoveNeon.Enabled then
						removeNeonFromPart(obj)
					end
				end)
				
				safetyLoop = task.spawn(function()
					while RemoveNeon.Enabled do
						task.wait(30)
						if RemoveNeon.Enabled then
							cleanupDeadReferences()
						end
					end
				end)
			else
				if neonConnection then
					neonConnection:Disconnect()
					neonConnection = nil
				end
				if safetyLoop then
					task.cancel(safetyLoop)
					safetyLoop = nil
				end
				restoreNeon()
			end
		end,
	})
end)

run(function()
	local PotatoMode
	local Mode
	local originalProperties = {}
	local blockMonitorConnections = {}
	local processedBlocks = {}

	local blockColors = {
		["wool_white"] = Color3.fromRGB(255, 255, 255),
		["wool_red"] = Color3.fromRGB(255, 50, 50),
		["wool_green"] = Color3.fromRGB(50, 255, 50),
		["wool_blue"] = Color3.fromRGB(50, 100, 255),
		["wool_yellow"] = Color3.fromRGB(255, 255, 50),
		["wool_orange"] = Color3.fromRGB(255, 150, 50),
		["wool_purple"] = Color3.fromRGB(180, 50, 255),
		["wool_pink"] = Color3.fromRGB(255, 100, 200),
		["wool_black"] = Color3.fromRGB(50, 50, 50),
		["wool_cyan"] = Color3.fromRGB(50, 255, 255),
		["wool_magenta"] = Color3.fromRGB(255, 50, 150),
		["wool_lime"] = Color3.fromRGB(150, 255, 50),
		["wool_brown"] = Color3.fromRGB(150, 75, 0),
		["wool_light_blue"] = Color3.fromRGB(100, 200, 255),
		["wool_gray"] = Color3.fromRGB(150, 150, 150),
		["wool_builder"] = Color3.fromRGB(200, 200, 200),
		["wool_shear"] = Color3.fromRGB(200, 200, 200),
		["wool"] = Color3.fromRGB(200, 200, 200),
		["clay_white"] = Color3.fromRGB(255, 255, 255),
		["clay_black"] = Color3.fromRGB(50, 50, 50),
		["clay_blue"] = Color3.fromRGB(50, 100, 255),
		["clay_dark_brown"] = Color3.fromRGB(100, 60, 30),
		["clay_dark_green"] = Color3.fromRGB(30, 100, 30),
		["clay_gray"] = Color3.fromRGB(150, 150, 150),
		["clay_green"] = Color3.fromRGB(50, 255, 50),
		["clay_light_brown"] = Color3.fromRGB(200, 170, 120),
		["clay_light_green"] = Color3.fromRGB(150, 255, 150),
		["clay_orange"] = Color3.fromRGB(255, 150, 50),
		["clay_pink"] = Color3.fromRGB(255, 100, 200),
		["clay_purple"] = Color3.fromRGB(180, 50, 255),
		["clay_red"] = Color3.fromRGB(255, 50, 50),
		["clay_tan"] = Color3.fromRGB(210, 180, 140),
		["clay_yellow"] = Color3.fromRGB(255, 255, 50),
		["clay"] = Color3.fromRGB(220, 180, 140),
		["wood_plank_spruce"] = Color3.fromRGB(222, 184, 135),
		["wood_plank_birch"] = Color3.fromRGB(230, 220, 190),
		["wood_plank_maple"] = Color3.fromRGB(200, 140, 90),
		["wood_plank_oak"] = Color3.fromRGB(180, 140, 100),
		["wood_plank_oak_builder"] = Color3.fromRGB(180, 140, 100),
		["oak_log"] = Color3.fromRGB(120, 90, 60),
		["birch_log"] = Color3.fromRGB(220, 210, 180),
		["spruce_log"] = Color3.fromRGB(100, 75, 50),
		["hickory_log"] = Color3.fromRGB(140, 100, 60),
		["wood"] = Color3.fromRGB(180, 140, 100),
		["stone"] = Color3.fromRGB(150, 150, 150),
		["stone_brick"] = Color3.fromRGB(140, 140, 140),
		["stone_brick_builder"] = Color3.fromRGB(140, 140, 140),
		["stone_slab"] = Color3.fromRGB(160, 160, 160),
		["stone_pillar"] = Color3.fromRGB(160, 160, 160),
		["stone_tiles"] = Color3.fromRGB(160, 160, 160),
		["stone_player_block"] = Color3.fromRGB(150, 150, 150),
		["andesite"] = Color3.fromRGB(150, 150, 150),
		["andesite_polished"] = Color3.fromRGB(160, 160, 160),
		["diorite"] = Color3.fromRGB(220, 220, 220),
		["diorite_polished"] = Color3.fromRGB(230, 230, 230),
		["granite"] = Color3.fromRGB(180, 100, 80),
		["granite_polished"] = Color3.fromRGB(190, 110, 90),
		["cobblestone"] = Color3.fromRGB(150, 150, 150),
		["limestone"] = Color3.fromRGB(210, 200, 180),
		["marble"] = Color3.fromRGB(235, 235, 235),
		["marble_pillar"] = Color3.fromRGB(235, 235, 235),
		["slate_brick"] = Color3.fromRGB(90, 95, 100),
		["slate_tiles"] = Color3.fromRGB(90, 95, 100),
		["volatile_stone"] = Color3.fromRGB(150, 150, 150),
		["obsidian"] = Color3.fromRGB(50, 30, 80),
		["bedrock"] = Color3.fromRGB(80, 80, 80),
		["tnt"] = Color3.fromRGB(255, 50, 50),
		["sandstone"] = Color3.fromRGB(220, 200, 150),
		["sandstone_polished"] = Color3.fromRGB(225, 205, 155),
		["sandstone_smooth"] = Color3.fromRGB(225, 205, 155),
		["red_sandstone"] = Color3.fromRGB(190, 110, 60),
		["red_sandstone_polished"] = Color3.fromRGB(195, 115, 65),
		["red_sandstone_smooth"] = Color3.fromRGB(195, 115, 65),
		["sand"] = Color3.fromRGB(220, 200, 150),
		["red_sand"] = Color3.fromRGB(190, 110, 60),
		["glass"] = Color3.fromRGB(200, 230, 230),
		["magic_glass"] = Color3.fromRGB(150, 200, 255),
		["diamond"] = Color3.fromRGB(100, 220, 220),
		["diamond_block"] = Color3.fromRGB(100, 220, 220),
		["diamond_ore"] = Color3.fromRGB(100, 220, 220),
		["emerald"] = Color3.fromRGB(50, 255, 50),
		["emerald_block"] = Color3.fromRGB(50, 255, 50),
		["emerald_ore"] = Color3.fromRGB(50, 255, 50),
		["iron"] = Color3.fromRGB(220, 220, 220),
		["iron_block"] = Color3.fromRGB(220, 220, 220),
		["iron_ore"] = Color3.fromRGB(200, 200, 200),
		["iron_ore_mesh_block"] = Color3.fromRGB(200, 200, 200),
		["gold"] = Color3.fromRGB(255, 215, 0),
		["gold_block"] = Color3.fromRGB(255, 215, 0),
		["copper_block"] = Color3.fromRGB(184, 115, 51),
		["steel_block"] = Color3.fromRGB(170, 170, 180),
		["galactite"] = Color3.fromRGB(100, 80, 160),
		["galactite_brick"] = Color3.fromRGB(100, 80, 160),
		["crystal_ore"] = Color3.fromRGB(180, 150, 255),
		["guilded_iron"] = Color3.fromRGB(230, 200, 100),
		["ceramic"] = Color3.fromRGB(230, 140, 60),
		["aquamarine_lantern"] = Color3.fromRGB(80, 220, 200),
		["barrel"] = Color3.fromRGB(140, 95, 55),
		["bookshelf"] = Color3.fromRGB(150, 100, 60),
		["brick"] = Color3.fromRGB(160, 80, 60),
		["grass"] = Color3.fromRGB(50, 255, 50),
		["moss_block"] = Color3.fromRGB(50, 150, 50),
		["dirt"] = Color3.fromRGB(120, 80, 50),
		["void_dirt"] = Color3.fromRGB(60, 40, 25),
		["void_grass"] = Color3.fromRGB(25, 80, 25),
		["ice"] = Color3.fromRGB(180, 220, 255),
		["snow"] = Color3.fromRGB(255, 255, 255),
		["snow_pile"] = Color3.fromRGB(255, 255, 255),
		["glowstone"] = Color3.fromRGB(255, 240, 150),
		["magma_block"] = Color3.fromRGB(200, 80, 30),
		["slime_block"] = Color3.fromRGB(120, 230, 120),
		["gum_block"] = Color3.fromRGB(255, 150, 200),
		["invisible_block"] = Color3.fromRGB(255, 255, 255),
		["void_block"] = Color3.fromRGB(20, 20, 20),
		["smoke_block"] = Color3.fromRGB(130, 130, 130),
		["cotton_candy_block"] = Color3.fromRGB(255, 200, 230),
		["cotton_candy_block_blue"] = Color3.fromRGB(150, 200, 255),
		["cotton_candy_block_orange"] = Color3.fromRGB(255, 180, 120),
		["cotton_candy_block_pink"] = Color3.fromRGB(255, 150, 200),
		["cotton_candy_block_yellow"] = Color3.fromRGB(255, 240, 150),
		["blue_tile"] = Color3.fromRGB(50, 100, 255),
		["concrete_green"] = Color3.fromRGB(50, 180, 50),
		["concrete"] = Color3.fromRGB(180, 180, 180),
		["bed"] = Color3.fromRGB(200, 50, 50),
		["og_bed"] = Color3.fromRGB(200, 50, 50),
		["royale_bed"] = Color3.fromRGB(200, 50, 50),
		["fake_bed"] = Color3.fromRGB(200, 50, 50),
		["barrier"] = Color3.fromRGB(255, 0, 0),
		["ladder"] = Color3.fromRGB(150, 100, 50),
		["vine_ladder"] = Color3.fromRGB(60, 120, 60),
		["scaffold"] = Color3.fromRGB(180, 140, 100),
		["christmas_scaffold"] = Color3.fromRGB(180, 140, 100),
		["drawbridge"] = Color3.fromRGB(150, 110, 70),
		["christmas_drawbridge"] = Color3.fromRGB(150, 110, 70),
		["haybale"] = Color3.fromRGB(230, 200, 100),
		["purple_hay_bale"] = Color3.fromRGB(180, 50, 255),
	}

	local cachedColors = {}

	local function getBlockColor(blockName)
		if cachedColors[blockName] then
			return cachedColors[blockName]
		end

		if blockColors[blockName] then
			cachedColors[blockName] = blockColors[blockName]
			return blockColors[blockName]
		end

		local lowerName = blockName:lower()

		if blockColors[lowerName] then
			cachedColors[blockName] = blockColors[lowerName]
			return blockColors[lowerName]
		end

		if lowerName:find("wool", 1, true) then
			for key, color in pairs(blockColors) do
				if key:find("wool", 1, true) and lowerName:find(key, 1, true) then
					cachedColors[blockName] = color
					return color
				end
			end
			cachedColors[blockName] = blockColors["wool"]
			return blockColors["wool"]
		end

		if lowerName:find("clay", 1, true) then
			for key, color in pairs(blockColors) do
				if key:find("clay", 1, true) and lowerName:find(key, 1, true) then
					cachedColors[blockName] = color
					return color
				end
			end
			cachedColors[blockName] = blockColors["clay"]
			return blockColors["clay"]
		end

		for name, color in pairs(blockColors) do
			if lowerName:find(name, 1, true) then
				cachedColors[blockName] = color
				return color
			end
		end

		local defaultColor = Color3.fromRGB(150, 150, 150)
		cachedColors[blockName] = defaultColor
		return defaultColor
	end

	local function cleanupDeadReferences()
		for block, _ in pairs(originalProperties) do
			if not block or not block.Parent then
				originalProperties[block] = nil
				processedBlocks[block] = nil
			end
		end
	end

	local function simplifyBlock(block)
		if not block or not block.Parent or processedBlocks[block] then return end

		if not originalProperties[block] then
			originalProperties[block] = {
				Material = block.Material,
				Color = block.Color,
				TextureID = block:IsA("MeshPart") and block.TextureID or nil,
				Textures = {}
			}

			for _, child in block:GetChildren() do
				if child:IsA("Texture") or child:IsA("Decal") then
					table.insert(originalProperties[block].Textures, {
						Class = child.ClassName,
						Texture = child.Texture,
						StudsPerTileU = child:IsA("Texture") and child.StudsPerTileU or nil,
						StudsPerTileV = child:IsA("Texture") and child.StudsPerTileV or nil,
						Face = child.Face,
						Transparency = child.Transparency,
						Color3 = child:IsA("Decal") and child.Color3 or nil
					})
				end
			end
		end

		block.Material = Enum.Material.SmoothPlastic
		block.Color = getBlockColor(block.Name)

		for _, child in block:GetChildren() do
			if child:IsA("Texture") or child:IsA("Decal") then
				child:Destroy()
			end
		end

		if block:IsA("MeshPart") and block.TextureID ~= "" then
			block.TextureID = ""
		end

		processedBlocks[block] = true
	end

	local function restoreBlock(block)
		if not block or not block.Parent then
			originalProperties[block] = nil
			processedBlocks[block] = nil
			return
		end

		local props = originalProperties[block]
		if not props then return end

		block.Material = props.Material or Enum.Material.Plastic
		block.Color = props.Color or Color3.fromRGB(255, 255, 255)

		if props.TextureID and block:IsA("MeshPart") then
			block.TextureID = props.TextureID
		end

		for _, textureProps in props.Textures do
			local newTexture
			if textureProps.Class == "Texture" then
				newTexture = Instance.new("Texture")
				newTexture.StudsPerTileU = textureProps.StudsPerTileU or 1
				newTexture.StudsPerTileV = textureProps.StudsPerTileV or 1
			else
				newTexture = Instance.new("Decal")
				newTexture.Color3 = textureProps.Color3 or Color3.fromRGB(255, 255, 255)
			end

			newTexture.Texture = textureProps.Texture or ""
			newTexture.Face = textureProps.Face or Enum.NormalId.Front
			newTexture.Transparency = textureProps.Transparency or 0
			newTexture.Parent = block
		end

		originalProperties[block] = nil
		processedBlocks[block] = nil
	end

	local function isTargetBlock(obj)
		if not obj:IsA("BasePart") then return false end

		local name = obj.Name

		if blockColors[name] then return true end

		local lowerName = name:lower()
		return lowerName:find("wool", 1, true) or
		       lowerName:find("clay", 1, true) or
		       lowerName:find("wood", 1, true) or
		       lowerName:find("log", 1, true) or
		       lowerName:find("stone", 1, true) or
		       lowerName:find("brick", 1, true) or
		       lowerName:find("glass", 1, true) or
		       lowerName:find("plank", 1, true) or
		       lowerName:find("bed", 1, true) or
		       lowerName:find("obsidian", 1, true) or
		       lowerName:find("sand", 1, true) or
		       lowerName:find("tnt", 1, true) or
		       lowerName:find("barrier", 1, true) or
		       lowerName:find("magic", 1, true) or
		       lowerName:find("concrete", 1, true) or
		       lowerName:find("diamond", 1, true) or
		       lowerName:find("emerald", 1, true) or
		       lowerName:find("iron", 1, true) or
		       lowerName:find("gold", 1, true) or
		       lowerName:find("copper", 1, true) or
		       lowerName:find("steel", 1, true) or
		       lowerName:find("ore", 1, true) or
		       lowerName:find("marble", 1, true) or
		       lowerName:find("slate", 1, true) or
		       lowerName:find("granite", 1, true) or
		       lowerName:find("andesite", 1, true) or
		       lowerName:find("diorite", 1, true) or
		       lowerName:find("grass", 1, true) or
		       lowerName:find("dirt", 1, true) or
		       lowerName:find("ice", 1, true) or
		       lowerName:find("snow", 1, true) or
		       lowerName:find("moss", 1, true) or
		       lowerName:find("slime", 1, true) or
		       lowerName:find("scaffold", 1, true) or
		       lowerName:find("ladder", 1, true) or
		       lowerName:find("tile", 1, true) or
		       lowerName:find("cotton_candy", 1, true) or
		       lowerName:find("_block", 1, true) or
		       obj:IsA("Seat")
	end

	local function processExistingBlocks(simplify)
		scanDescendants(workspace, function(obj)
			if isTargetBlock(obj) then
				if simplify then
					simplifyBlock(obj)
				else
					restoreBlock(obj)
				end
			end
		end)

		if not simplify then
			task.delay(2, cleanupDeadReferences)
		end
	end

	local function setupBlockMonitor(simplify)
		for _, conn in blockMonitorConnections do
			conn:Disconnect()
		end
		table.clear(blockMonitorConnections)

		if not simplify then return end

		local mainConn = workspace.DescendantAdded:Connect(function(descendant)
			if isTargetBlock(descendant) then
				task.defer(function()
					if descendant and descendant.Parent then
						simplifyBlock(descendant)
					end
				end)
			end
		end)

		table.insert(blockMonitorConnections, mainConn)

		local lastCleanup = 0
		local cleanupConn = runService.Heartbeat:Connect(function()
			local now = tick()
			if now - lastCleanup >= 5 then
				lastCleanup = now
				cleanupDeadReferences()
			end
		end)

		table.insert(blockMonitorConnections, cleanupConn)
	end

	local ntReference = {}
	local function ntRemember(obj, property)
		local props = ntReference[obj]
		if not props then
			props = {}
			ntReference[obj] = props
		end
		if props[property] == nil then
			props[property] = obj[property]
		end
	end
	local function ntStrip(obj)
		if obj:IsA('Decal') then
			ntRemember(obj, 'Transparency')
			obj.Transparency = 1
			return
		end
		if obj:IsA('SurfaceAppearance') then
			ntRemember(obj, 'Parent')
			obj.Parent = nil
			return
		end
		if obj:IsA('SpecialMesh') then
			ntRemember(obj, 'TextureId')
			obj.TextureId = ''
			return
		end
		if obj:IsA('BasePart') then
			if obj:IsA('MeshPart') then
				ntRemember(obj, 'TextureID')
				obj.TextureID = ''
			end
			ntRemember(obj, 'Material')
			obj.Material = Enum.Material.SmoothPlastic
		end
	end
	local function ntRestore()
		for i, v in ntReference do
			pcall(function()
				for property, value in v do
					i[property] = value
				end
			end)
		end
		table.clear(ntReference)
	end
	local function ntScan()
		local descendants = store.map:GetDescendants()
		for i, v in descendants do
			if not PotatoMode.Enabled or Mode.Value ~= 'No Texture' then return end
			ntStrip(v)
			if i % 500 == 0 then
				task.wait()
			end
		end
	end

	PotatoMode = vape.Categories.World:CreateModule({
		Name = 'PotatoMode',
		Function = function(callback)
			if callback then
				if Mode.Value == 'No Texture' then
					repeat task.wait() until store.map or not PotatoMode.Enabled
					if not PotatoMode.Enabled then return end
					PotatoMode:Clean(store.map.DescendantAdded:Connect(function(obj)
						task.defer(ntStrip, obj)
					end))
					ntScan()
				else
					processExistingBlocks(true)
					setupBlockMonitor(true)
				end
			else
				processExistingBlocks(false)
				for _, conn in blockMonitorConnections do
					conn:Disconnect()
				end
				table.clear(blockMonitorConnections)
				table.clear(cachedColors)
				cleanupDeadReferences()
				ntRestore()
			end
		end,
	})
	Mode = PotatoMode:CreateDropdown({
		Name = 'Mode',
		List = {'Original', 'No Texture'},
		Default = 'Original',
		Tooltip = 'Original = flat colored blocks, No Texture = strips everything off the map',
		Function = function(val)
			if PotatoMode.Enabled then
				PotatoMode:Toggle()
				PotatoMode:Toggle()
			end
		end
	})
end)

run(function()
	local Clutch
	local LimitItem

	local function getScaffoldBlock()
		return getScaffoldBlockForModule(LimitItem)
	end

	local lastPlace = 0

	Clutch = vape.Categories.World:CreateModule({
		Name = 'Clutch',
		Tooltip = 'clutchs for u via blocks',
		Function = function(callback)
			if callback then
				Clutch:Clean(runService.Heartbeat:Connect(function()
					if not Clutch.Enabled or not entitylib.isAlive then return end
					local root = entitylib.character.RootPart
					if not root then return end
					if root.Velocity.Y >= -50 then return end
					local wool = getScaffoldBlock()
					if not wool then return end
					local now = os.clock()
					if now - lastPlace < 0.05 then return end
					local target = roundPos(root.Position - Vector3.new(0, entitylib.character.HipHeight + 4.5, 0))
					if not getPlacedBlock(target) then
						local prox = blockProximity(target)
						bedwars.placeBlock(prox or target, wool, false)
						lastPlace = now
					end
				end))
			else
				lastPlace = 0
			end
		end,
	})

	LimitItem = Clutch:CreateToggle({
		Name = 'Limit to items',
		Default = false,
	})
end)

run(function()
	local PhaseMine
	local connections = {}
	local trackedParts = {}
	local lastWeaponState = nil
	local weaponCheckCounter = 0
	
	local function removeCollision(character)
		if not character then return end
		
		local charParts = trackedParts[character]
		if not charParts then
			charParts = {}
			trackedParts[character] = charParts
			
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") then
					table.insert(charParts, {part = part, origCollide = part.CanCollide, origQuery = part.CanQuery})
					part.CanCollide = false
					part.CanQuery = false
				end
			end
		else
			for _, entry in charParts do
				if entry.part and entry.part.Parent then
					entry.part.CanCollide = false
					entry.part.CanQuery = false
				end
			end
		end
	end
	
	local function restoreCollision(character)
		if not character then return end
		
		local charParts = trackedParts[character]
		if charParts then
			for _, entry in charParts do
				if entry.part and entry.part.Parent then
					entry.part.CanCollide = entry.origCollide
					entry.part.CanQuery = entry.origQuery
				end
			end
		end
	end

	local function updateAllCollisions(forceUpdate)
		weaponCheckCounter = weaponCheckCounter + 1
		local shouldCheck = forceUpdate or (weaponCheckCounter % 3 == 0)
		
		if not shouldCheck then return end
		
		local isWeaponEquipped = hasValidWeapon()
		
		if not forceUpdate and lastWeaponState == isWeaponEquipped then
			return
		end
		
		lastWeaponState = isWeaponEquipped
		
		for _, entity in entitylib.List do
			if entity.Character and entity.Character.Parent then
				if isWeaponEquipped then
					restoreCollision(entity.Character)
				else
					removeCollision(entity.Character)
				end
			end
		end
	end
	
	local motorParts = {}
	local function updateMotorParts()
		for _, entity in entitylib.List do
			if entity.Character then
				local charMotors = motorParts[entity.Character]
				
				if not charMotors then
					charMotors = {}
					motorParts[entity.Character] = charMotors
					
					for _, part in entity.Character:GetChildren() do
						if part:IsA("BasePart") and part.Name == "Part" and part:FindFirstChildOfClass("Motor6D") then
							table.insert(charMotors, part)
						end
					end
				end
				
				for _, part in charMotors do
					if part and part.Parent then
						part.CanCollide = false
					end
				end
			end
		end
	end
	
	local tracked = {}
	local descConnections = {}

	PhaseMine = vape.Categories.World:CreateModule({
		Name = 'PhaseMine',
		Function = function(callback)
			if callback then

				local function shouldRemoveCollision()
					local hand = store.hand
					if not hand or not hand.tool then return false end
					local meta = bedwars.ItemMeta[hand.tool.Name]
					if meta and (meta.block == true or meta.toolType == 'block') then return true end
					if hand.toolType == 'block' then return true end
					local name = hand.tool.Name:lower()
					if name:find("pickaxe") or name:find("axe") or name:find("shovel") or name:find("tool") then return true end
					if meta and (meta.miningPower or meta.isTool) then return true end
					return false
				end

				local function storeOriginal(char)
					if tracked[char] then return end
					local list = {}
					for _, part in ipairs(char:GetDescendants()) do
						if part:IsA("BasePart") then
							table.insert(list, {
								part = part,
								origCollide = part.CanCollide,
								origQuery = part.CanQuery
							})
						end
					end
					tracked[char] = list
				end

				local function applyToChar(char, remove)
					if not char then return end
					if char == lplr.Character then return end
					storeOriginal(char)
					local list = tracked[char]
					for _, entry in ipairs(list) do
						if entry.part and entry.part.Parent then
							entry.part.CanCollide = false
							entry.part.CanQuery = not remove
						end
					end
				end

				local function onPartAdded(char, part)
					if not PhaseMine.Enabled then return end
					if char == lplr.Character then return end
					if part:IsA("BasePart") then
						storeOriginal(char)
						local list = tracked[char]
						local found = false
						for _, entry in ipairs(list) do
							if entry.part == part then
								found = true
								break
							end
						end
						if not found then
							table.insert(list, {
								part = part,
								origCollide = part.CanCollide,
								origQuery = part.CanQuery
							})
						end
						local remove = shouldRemoveCollision()
						part.CanCollide = false
						part.CanQuery = not remove
					end
				end

				local function setupCharacter(char)
					if not char then return end
					if char == lplr.Character then return end
					if descConnections[char] then
						descConnections[char]:Disconnect()
						descConnections[char] = nil
					end
					applyToChar(char, shouldRemoveCollision())
					local conn = char.DescendantAdded:Connect(function(part)
						onPartAdded(char, part)
					end)
					descConnections[char] = conn
				end

				local function cleanupCharacter(char)
					if descConnections[char] then
						descConnections[char]:Disconnect()
						descConnections[char] = nil
					end
					tracked[char] = nil
				end

				local function applyToAll(remove)
					for _, entity in ipairs(entitylib.List) do
						if entity.Character then
							applyToChar(entity.Character, remove)
						end
					end
					for _, obj in ipairs(workspace:GetChildren()) do
						if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
							if obj ~= lplr.Character then
								applyToChar(obj, remove)
							end
						end
					end
				end

				local function updateCollision()
					if not PhaseMine.Enabled then return end
					local remove = shouldRemoveCollision()
					applyToAll(remove)
				end

				local function setupAllCharacters()
					for _, entity in ipairs(entitylib.List) do
						if entity.Character then
							setupCharacter(entity.Character)
						end
					end
					for _, obj in ipairs(workspace:GetChildren()) do
						if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
							if obj ~= lplr.Character then
								setupCharacter(obj)
							end
						end
					end
				end

				task.wait(0.2)
				setupAllCharacters()
				updateCollision()

				local lastState = shouldRemoveCollision()
				local heartbeat = runService.Heartbeat:Connect(function()
					if not PhaseMine.Enabled then return end
					local current = shouldRemoveCollision()
					if current ~= lastState then
						lastState = current
						updateCollision()
					end
				end)
				table.insert(connections, heartbeat)

				local entityAdded = entitylib.Events.EntityAdded:Connect(function(entity)
					if entity.Character then
						task.wait(0.1)
						setupCharacter(entity.Character)
					end
				end)
				table.insert(connections, entityAdded)

				local workspaceChildAdded = workspace.ChildAdded:Connect(function(obj)
					if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
						if obj ~= lplr.Character then
							task.wait(0.1)
							setupCharacter(obj)
						end
					end
				end)
				table.insert(connections, workspaceChildAdded)

				local entityRemoved = entitylib.Events.EntityRemoved:Connect(function(entity)
					if entity.Character then
						cleanupCharacter(entity.Character)
					end
				end)
				table.insert(connections, entityRemoved)

				local workspaceChildRemoved = workspace.ChildRemoved:Connect(function(obj)
					if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
						if obj ~= lplr.Character then
							cleanupCharacter(obj)
						end
					end
				end)
				table.insert(connections, workspaceChildRemoved)

				local localAdded = lplr.CharacterAdded:Connect(function(char)
					if PhaseMine.Enabled then
						if lplr.Character and lplr.Character ~= char then
							cleanupCharacter(lplr.Character)
						end
						task.wait(0.2)
						updateCollision()
						setupAllCharacters()
					end
				end)
				table.insert(connections, localAdded)

				if vapeEvents and vapeEvents.InventoryChanged then
					local invConn = vapeEvents.InventoryChanged.Event:Connect(function()
						if PhaseMine.Enabled then
							updateCollision()
						end
					end)
					table.insert(connections, invConn)
				end

			else
				for _, conn in ipairs(connections) do
					conn:Disconnect()
				end
				table.clear(connections)

				for char, conn in pairs(descConnections) do
					conn:Disconnect()
				end
				table.clear(descConnections)

				for char, list in pairs(tracked) do
					if char and char.Parent then
						for _, entry in ipairs(list) do
							if entry.part and entry.part.Parent then
								entry.part.CanCollide = entry.origCollide
								entry.part.CanQuery = entry.origQuery
							end
						end
					end
				end
				table.clear(tracked)
			end
		end,
		Tooltip = 'mine OR build through players and npcs'
	})
end)

run(function()
	local AntiEffects
	local AntiDizzy
	local AntiSleep
	local AntiTrap
	local AntiFear
	local old = nil
	local oldAdd = nil
	local sleepModifier = nil

	local function applyEffects()
		if AntiDizzy and AntiDizzy.Enabled then
			if not old then
				old = bedwars.ForestEnvironmentCollectibleEntityController.canPickupEntity
			end
			bedwars.ForestEnvironmentCollectibleEntityController.canPickupEntity = function(a, b, c)
				local selfRef, plr, mushroom = a, b, c
				if c == nil then
					selfRef, plr, mushroom = nil, a, b
				end
				if typeof(mushroom) == 'Instance' then
					local mush = mushroom:GetAttribute('MushroomType')
					if mush == 'Dizzy' then return false end
					if mush then return true end
				end
				if selfRef == nil then
					return old(plr, mushroom)
				end
				return old(selfRef, plr, mushroom)
			end
			runService:BindToRenderStep('antieffects_dizzy', Enum.RenderPriority.Character.Value + 2, function()
				runService:UnbindFromRenderStep('dizzy-status')
			end)
		else
			if old then
				bedwars.ForestEnvironmentCollectibleEntityController.canPickupEntity = old
				old = nil
			end
			runService:UnbindFromRenderStep('antieffects_dizzy')
		end

		if AntiTrap and AntiTrap.Enabled then
			runService:BindToRenderStep('antieffects_trap', Enum.RenderPriority.Character.Value + 2, function()
				local char = lplr.Character
				if not char then return end
				local hum = char:FindFirstChildOfClass('Humanoid')
				if char:GetAttribute('SnapTrapMarked') then
					char:SetAttribute('SnapTrapMarked', nil)
				end
				if hum then
					if hum.JumpPower == 0 then hum.JumpPower = 50 end
					if hum.JumpHeight == 0 then hum.JumpHeight = 7.2 end
					if hum.WalkSpeed < 10 then hum.WalkSpeed = 16 end
				end
			end)
		else
			runService:UnbindFromRenderStep('antieffects_trap')
		end

		if AntiFear and AntiFear.Enabled then
			runService:UnbindFromRenderStep('werewolf-fear-status')
			runService:BindToRenderStep('antieffects_fear', Enum.RenderPriority.Character.Value + 2, function()
				runService:UnbindFromRenderStep('werewolf-fear-status')
			end)
		else
			runService:UnbindFromRenderStep('antieffects_fear')
		end

		if AntiSleep and AntiSleep.Enabled then
			local char = lplr.Character
			if char then
				sleepModifier = bedwars.SprintController:getMovementStatusModifier()
				oldAdd = sleepModifier.addModifier
				sleepModifier.addModifier = function(self, tab)
					if tab and tab.moveSpeedMultiplier and tab.moveSpeedMultiplier <= 0 then
						return oldAdd(self, { moveSpeedMultiplier = 1 })
					end
					return oldAdd(self, tab)
				end
				runService:BindToRenderStep('antieffects_sleep', Enum.RenderPriority.Character.Value + 2, function()
					local stunTime = char:GetAttribute('StunnedUntilTime')
					local now = workspace:GetServerTimeNow()
					if stunTime and stunTime > now then
						char:SetAttribute('StunnedUntilTime', -1)
					end
					for mod, _ in sleepModifier.modifiers do
						if type(mod) == 'table' and (mod.moveSpeedMultiplier or 1) <= 0 then
							sleepModifier:removeModifier(mod)
						end
					end
					local hum = char:FindFirstChildOfClass('Humanoid')
					if hum then
						if hum.JumpPower == 0 then hum.JumpPower = 50 end
						if hum.JumpHeight == 0 then hum.JumpHeight = 7.2 end
					end
				end)
			end
		else
			runService:UnbindFromRenderStep('antieffects_sleep')
			if sleepModifier and oldAdd then
				sleepModifier.addModifier = oldAdd
				oldAdd = nil
				sleepModifier = nil
			end
		end
	end

	AntiEffects = vape.Categories.World:CreateModule({
		Name = 'AntiEffects',
		Tooltip = 'blocks negative effects',
		Function = function(callback)
			if callback then
				applyEffects()
			else
				if old then
					bedwars.ForestEnvironmentCollectibleEntityController.canPickupEntity = old
					old = nil
				end
				runService:UnbindFromRenderStep('antieffects_dizzy')
				runService:UnbindFromRenderStep('antieffects_sleep')
				runService:UnbindFromRenderStep('antieffects_fear')
				runService:UnbindFromRenderStep('antieffects_trap')
				if sleepModifier and oldAdd then
					sleepModifier.addModifier = oldAdd
					oldAdd = nil
					sleepModifier = nil
				end
			end
		end
	})
	AntiDizzy = AntiEffects:CreateToggle({
		Name = 'Dizzy',
		Tooltip = 'blocks dizzy effects from mushrooms and toads',
		Default = true,
		Function = function()
			if AntiEffects.Enabled then applyEffects() end
		end
	})
	AntiSleep = AntiEffects:CreateToggle({
		Name = 'Sleep',
		Tooltip = 'blocks sleep splash potion effect',
		Default = true,
		Function = function()
			if AntiEffects.Enabled then applyEffects() end
		end
	})
	AntiTrap = AntiEffects:CreateToggle({
		Name = 'Trap',
		Tooltip = 'allows you to move when snapped by a trap',
		Default = true,
		Function = function()
			if AntiEffects.Enabled then applyEffects() end
		end
	})
	AntiFear = AntiEffects:CreateToggle({
		Name = 'Fear',
		Tooltip = 'stops werewolf fear from walkin u away from them',
		Default = true,
		Function = function()
			if AntiEffects.Enabled then applyEffects() end
		end
	})
end)

run(function()
	local AntiMagma

	AntiMagma = vape.Categories.World:CreateModule({
		Name = "AntiMagma",
		Tooltip = 'allows you not to be instantly killed by magma',
		Function = function(callback)
			if callback then
				local function disableMagmaPart(v)
					if not v:IsA("BasePart") then return end
					if not string.find(string.lower(v.Name), 'magma') then return end
					for _, stuff in v:GetDescendants() do
						if stuff:IsA("TouchTransmitter") then
							pcall(function() stuff:Destroy() end)
						end
					end
				end

				scanDescendants(workspace, disableMagmaPart, AntiMagma)

				AntiMagma:Clean(workspace.DescendantAdded:Connect(function(v)
					disableMagmaPart(v)
				end))
				local worldFolder = getWorldFolder()
				if not worldFolder then return end
				local blocks = worldFolder:WaitForChild("Blocks", 1)
				if not blocks then return end
				AntiMagma:Clean(blocks.ChildAdded:Connect(function(v)
					disableMagmaPart(v)
				end))
			end
		end
	})
end)

run(function()
    local BlockIn
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude
    local PlaceSpeed
    local LimitItem
    local Blacklist

    local function isBlacklisted(itemType)
        return Blacklist and table.find(Blacklist.ListEnabled, itemType)
    end

    local function getBlocks()
        local blocks = {}

        if LimitItem and LimitItem.Enabled then
            local itemType = store.hand.toolType == 'block' and store.hand.tool and store.hand.tool.Name
            local meta = itemType and bedwars.ItemMeta[itemType]
            local block = meta and meta.block
            if block and not isBlacklisted(itemType) and (store.hand.amount or 0) > 0 then
                table.insert(blocks, { itemType, block.health or 0, store.hand.tool, store.hand.amount })
            end
            return blocks
        end

        for _, item in store.inventory.inventory.items do
            local itemType = item.itemType
            local meta = itemType and bedwars.ItemMeta[itemType]
            local block = meta and meta.block
            if block and not isBlacklisted(itemType) and (item.amount or 0) > 0 then
                table.insert(blocks, { itemType, block.health or 0, item.tool, item.amount })
            end
        end
        table.sort(blocks, function(a, b)
            return a[2] > b[2]
        end)
        return blocks
    end

    local function getPyramid()
        return {
            Vector3.new(0, 0, 3),
            Vector3.new(0, 3, 3),
            Vector3.new(-3, 0, 0),
            Vector3.new(-3, 3, 0),
            Vector3.new(0, 0, -3),
            Vector3.new(0, 3, -3),
            Vector3.new(3, 0, 0),
            Vector3.new(3, 3, 0),
            Vector3.new(3, 6, 0),
            Vector3.new(0, 6, 0),
        }
    end

    local function isMoving()
        if not entitylib.isAlive then return false end
        local vel = entitylib.character.RootPart.AssemblyLinearVelocity
        return Vector3.new(vel.X, 0, vel.Z).Magnitude > 2
    end

    local function doBuild()
        local basePos = bedwars.BlockController:getBlockPosition(entitylib.character.RootPart.Position) * 3
        rayCheck.FilterDescendantsInstances = { lplr.Character, gameCamera }
        local oldPlaceCPS = bedwars.SharedConstants.BLOCK_PLACE_CPS
        bedwars.SharedConstants.BLOCK_PLACE_CPS = 20
        local blocks = getBlocks()
        if #blocks < 1 then
            notif('BlockIn', 'Missing blocks', 4, 'warning')
        end
        local pattern = getPyramid()
        local aborted = false
        for attempt = 1, 4 do
            if not BlockIn.Enabled or not entitylib.isAlive then break end
            for _, block in blocks do
                if not BlockIn.Enabled or not entitylib.isAlive then break end
                if (block[4] or 0) <= 0 then continue end
                local switched = false
                for _, pos in pattern do
                    if not BlockIn.Enabled or not entitylib.isAlive then break end
                    if isMoving() then
                        aborted = true
                        break
                    end
                    local target = basePos + pos
                    if getPlacedBlock(target) then continue end
                    if not switched then
                        for index, v in store.inventory.hotbar do
                            if v.item and v.item.tool == block[3] and index ~= (store.inventory.hotbarSlot + 1) then
                                hotbarSwitch(index - 1)
                                break
                            end
                        end
                        switched = true
                    end
                    bedwars.placeBlock(target, block[1])
                    local delay = PlaceSpeed.Value
                    if delay > 0 then task.wait(delay) end
                end
                if aborted then break end
            end
            if aborted then break end
            local complete = true
            for _, pos in pattern do
                if not getPlacedBlock(basePos + pos) then
                    complete = false
                    break
                end
            end
            if complete then break end
            task.wait(0.08)
        end
        bedwars.SharedConstants.BLOCK_PLACE_CPS = oldPlaceCPS or 12
        return aborted
    end

    BlockIn = vape.Categories.World:CreateModule({
        Name = 'BlockIn',
        Function = function(callback)
            if callback then
                if not entitylib.isAlive then
                elseif LimitItem and LimitItem.Enabled and store.hand.toolType ~= 'block' then
                    notif('BlockIn', 'Hold a block first', 2, 'warning')
                else
                    doBuild()
                end
                if BlockIn.Enabled then
                    BlockIn:Toggle()
                end
            end
        end,
        Tooltip = 'auto places blocks around yo self'
    })

    PlaceSpeed = BlockIn:CreateSlider({
        Name = 'Placement Speed',
        Min = 0,
        Max = 0.5,
        Default = 0.07,
        Decimal = 100,
        Suffix = 'seconds',
    })
    LimitItem = BlockIn:CreateToggle({
        Name = 'Limit to items',
    })
    Blacklist = BlockIn:CreateTextList({
        Name = 'Blacklists',
        Placeholder = 'block',
        Default = {
            'cannon',
            'tnt',
            'siege_tnt',
        }
    })
end)

run(function()
    local AutoSuffo
    local Range
    local LimitItem
    local Targets

    local function fixPosition(pos)
        return bedwars.BlockController:getBlockPosition(pos) * 3
    end

    local ring = {
        Vector3.new(3, 0, 0), Vector3.new(-3, 0, 0),
        Vector3.new(0, 0, 3), Vector3.new(0, 0, -3),
    }

    local function getBlockItem()
        if store.hand.toolType == 'block' then
            return store.hand.tool.Name
        elseif not LimitItem.Enabled then
            return (getWool())
        end
        return nil
    end

    local function predict(part)
        local vel = part.AssemblyLinearVelocity or Vector3.zero
        return part.Position + vel * lplr:GetNetworkPing()
    end

    local function buildCells(ent)
        local root = predict(ent.RootPart)
        local head = predict(ent.Head)
        local cells = {}
        table.insert(cells, fixPosition(head))
        table.insert(cells, fixPosition(head + Vector3.new(0, 3, 0)))
        for _, o in ring do
            table.insert(cells, fixPosition(head + o))
            table.insert(cells, fixPosition(root + o))
        end
        return cells
    end

    AutoSuffo = vape.Categories.World:CreateModule({
        Name = 'AutoSuffo',
        Function = function(callback)
            if callback then
                repeat
                    local item = entitylib.isAlive and getBlockItem()

                    if item then
                        for _, ent in entitylib.AllPosition({
                            Part = 'RootPart',
                            Range = Range.Value,
                            Players = Targets.Players.Enabled,
                            NPCs = Targets.NPCs.Enabled,
                        }) do
                            if ent.Targetable and ent.Head then
                                for _, pos in buildCells(ent) do
                                    if not getPlacedBlock(pos) and checkFaceAdjacent(pos) then
                                        task.spawn(bedwars.placeBlock, pos, item)
                                    end
                                end
                            end
                        end
                    end

                    task.wait(0.05)
                until not AutoSuffo.Enabled
            end
        end,
    })
    Range = AutoSuffo:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 20,
        Default = 14,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    Targets = AutoSuffo:CreateTargets({Players = true})
    LimitItem = AutoSuffo:CreateToggle({
        Name = 'Limit to Items',
    })
end)

--[[
	Inventory Modules
]]

run(function()
	local AutoBank
	local UIToggle
	local GUICheck
	local UI
	local Chests
	local Items = {}
	local BankToggles = {
		iron = nil,
		diamond = nil,
		emerald = nil
	}
	local cachedChest
	local lastChestCheck = 0
	local lastHotbarUpdate = 0

	local function addItem(itemType, shop)
		local item = Instance.new('ImageLabel')
		item.Image = bedwars.getIcon({itemType = itemType}, true)
		item.Size = UDim2.fromOffset(32, 32)
		item.Name = itemType
		item.BackgroundTransparency = 1
		item.LayoutOrder = #UI:GetChildren()
		item.Parent = UI
		local itemtext = Instance.new('TextLabel')
		itemtext.Name = 'Amount'
		itemtext.Size = UDim2.fromScale(1, 1)
		itemtext.BackgroundTransparency = 1
		itemtext.Text = ''
		itemtext.TextColor3 = Color3.new(1, 1, 1)
		itemtext.TextSize = 16
		itemtext.TextStrokeTransparency = 0.3
		itemtext.Font = Enum.Font.Arial
		itemtext.Parent = item
		Items[itemType] = {Object = itemtext, Type = shop}
	end

	local function refreshBank(echest)
		for i, v in pairs(Items) do
			local item = echest:FindFirstChild(i)
			v.Object.Text = item and item:GetAttribute('Amount') or ''
		end
	end

	local function nearChest()
		if not entitylib.isAlive then return false end

		local pos = entitylib.character.RootPart.Position
		local maxDistanceSq = 22 * 22

		for _, chest in pairs(Chests) do
			if chest.Parent then
				local offset = chest.Position - pos
				local distanceSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z
				if distanceSq < maxDistanceSq then
					return true
				end
			end
		end

		return false
	end

	local function isNearOwnBase()
		if not entitylib.isAlive then return false end
		local myTeam = tostring(lplr:GetAttribute('Team') or '')
		if myTeam == '' then return false end
		local myBed = nil
		for _, bed in collectionService:GetTagged('bed') do
			if not bed:IsA('BasePart') then continue end
			local bedTeam = tostring(bed:GetAttribute('Team') or bed:GetAttribute('TeamId') or '')
			if bedTeam == myTeam then myBed = bed break end
		end
		if not myBed then return false end
		local bedPos = myBed.Position
		local closestChest, closestDist = nil, math.huge
		for _, chest in pairs(Chests) do
			if chest.Parent then
				local dist = (chest.Position - bedPos).Magnitude
				if dist < closestDist then closestChest = chest closestDist = dist end
			end
		end
		if not closestChest then return false end
		local myPos = entitylib.character.RootPart.Position
		return (myPos - closestChest.Position).Magnitude <= 60
	end

	local function handleState()
		local currentTime = tick()

		if not cachedChest or not cachedChest.Parent or (currentTime - lastChestCheck) > 1 then
			cachedChest = replicatedStorage.Inventories:FindFirstChild(lplr.Name..'_personal')
			lastChestCheck = currentTime
		end

		if not cachedChest then return end

		if not nearChest() and not GUICheck.Enabled then
			return
		end

		local itemsToDeposit = {}
		for _, v in ipairs(store.inventory.inventory.items) do
			local itemInfo = Items[v.itemType]
			if itemInfo and BankToggles[v.itemType] and BankToggles[v.itemType].Enabled then
				table.insert(itemsToDeposit, v)
			end
		end

		if #itemsToDeposit > 0 then
			for _, v in ipairs(itemsToDeposit) do
				bedwars.Client:GetNamespace('Inventory'):Get('ChestGiveItem'):CallServer(cachedChest, v.tool)
			end
			task.defer(function()
				if cachedChest and cachedChest.Parent then
					refreshBank(cachedChest)
				end
			end)
		end
	end


	AutoBank = vape.Categories.Inventory:CreateModule({
		Name = 'AutoBank',
		Function = function(callback)
			if callback then
				Chests = collection('chest', AutoBank)
				cachedChest = nil
				lastChestCheck = 0
				lastHotbarUpdate = 0
				UI = Instance.new('Frame')
				UI.Size = UDim2.new(1, 0, 0, 44)
				UI.Position = UDim2.fromOffset(0, -256)
				UI.BackgroundTransparency = 1
				UI.Visible = UIToggle.Enabled
				UI.Parent = vape.gui
				AutoBank:Clean(UI)

				local Sort = Instance.new('UIListLayout')
				Sort.FillDirection = Enum.FillDirection.Horizontal
				Sort.HorizontalAlignment = Enum.HorizontalAlignment.Center
				Sort.SortOrder = Enum.SortOrder.LayoutOrder
				Sort.Parent = UI

				addItem('iron', true)
				addItem('diamond', false)
				addItem('emerald', true)
				addItem('serpents_touch_potion', false)
				addItem('jump_potion', false)
				addItem('mini_shield', false)

				local cachedHotbar
				local guiInset = guiService:GetGuiInset().Y

				repeat
					local currentTime = tick()

					if (currentTime - lastHotbarUpdate) > 0.5 then
						local playerGui = lplr.PlayerGui
						if playerGui then
							local hotbar = playerGui:FindFirstChild('hotbar')
							if hotbar then
								local container = hotbar['1']:FindFirstChild('HotbarHealthbarContainer')
								if container then
									cachedHotbar = container
									UI.Position = UDim2.fromOffset(0, (container.AbsolutePosition.Y + guiInset) - 40)
									lastHotbarUpdate = currentTime
								end
							end
						end
					end

					if not cachedChest or not cachedChest.Parent or (currentTime - lastChestCheck) > 1 then
						cachedChest = replicatedStorage.Inventories:FindFirstChild(lplr.Name .. '_personal')
						lastChestCheck = currentTime
					end
					if UIToggle.Enabled and UI and cachedChest then
						refreshBank(cachedChest)
					end

					local shouldBank = false

					if GUICheck.Enabled then
						shouldBank = bedwars.AppController:isAppOpen('ChestApp') or
						             bedwars.AppController:isAppOpen('BedwarsAppIds.CHEST_INVENTORY')
					else
						shouldBank = nearChest()
					end

					if shouldBank and not (TeamCheck and TeamCheck.Enabled and isNearOwnBase()) then
						handleState()
					end

					task.wait(0.1)
				until (not AutoBank.Enabled)
			else
				table.clear(Items)
				cachedChest = nil
			end
		end,
		Tooltip = 'automatically puts resources in pchest'
	})

	UIToggle = AutoBank:CreateToggle({
		Name = 'UI',
		Function = function(callback)
			if AutoBank.Enabled and UI then
				UI.Visible = callback
			end
		end,
		Default = true
	})

	GUICheck = AutoBank:CreateToggle({
		Name = 'GUI Check',
	})

	BankToggles.iron = AutoBank:CreateToggle({
		Name = 'Bank Iron',
		Default = true
	})

	BankToggles.diamond = AutoBank:CreateToggle({
		Name = 'Bank Diamond',
		Default = true
	})

	BankToggles.emerald = AutoBank:CreateToggle({
		Name = 'Bank Emerald',
		Default = true
	})

	BankToggles.serpents_touch_potion = AutoBank:CreateToggle({
		Name = 'Bank Serpent Potion',
		Default = false
	})

	BankToggles.jump_potion = AutoBank:CreateToggle({
		Name = 'Bank Jump Potion',
		Default = false
	})

	BankToggles.mini_shield = AutoBank:CreateToggle({
		Name = 'Bank Shield Potion',
		Default = false
	})

	TeamCheck = AutoBank:CreateToggle({
		Name = 'Team Check',
		Default = false
	})
end)
	
run(function()
	local AutoConsume
	local Health
	local SpeedPotion
	local Apple
	local ShieldPotion
	local SerpentsTouch
	local JumpPotion
	local LimitToItem
	local Delay
	local NoSlow
	local consuming = false
	local heldTrack
	local GoldenApple
	local GoldenAppleHealth
	local SpeedPie
	
	local function consumeCheck(attribute)
		if entitylib.isAlive then
			if SpeedPotion.Enabled and (not attribute or attribute == 'StatusEffect_speed') then
				local speedpotion = getItem('speed_potion')
				if speedpotion and (not lplr.Character:GetAttribute('StatusEffect_speed')) then
					task.spawn(function()
						for _ = 1, 4 do
							local result = false
							bedwars.Client:Get(remotes.ConsumeItem):CallServerAsync({item = speedpotion.tool}):andThen(function(r)
								result = r
							end):await()
							if result then break end
						end
					end)
				end
			end
	
			if Apple.Enabled and (not attribute or attribute:find('Health')) then
				if (lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) <= (Health.Value / 100) then
					local inv = replicatedStorage:FindFirstChild('Inventories') and replicatedStorage.Inventories:FindFirstChild(lplr.Name)
					local appleItem = inv and (inv:FindFirstChild('orange') or inv:FindFirstChild('apple'))
					if appleItem then
						replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged.ConsumeItem:InvokeServer({item = appleItem})
					end
				end
			end

			if GoldenApple and GoldenApple.Enabled and (not attribute or attribute:find('Health')) then
				local gaHealth = GoldenAppleHealth and GoldenAppleHealth.Value or 50
				local currentHPPct = (lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth') * 100)
				local inv = replicatedStorage:FindFirstChild('Inventories') and replicatedStorage.Inventories:FindFirstChild(lplr.Name)
				local gaItem = inv and inv:FindFirstChild('golden_apple')
				if currentHPPct <= gaHealth and gaItem then
					replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged.ConsumeItem:InvokeServer({item = gaItem})
				end
			end

			if SpeedPie and SpeedPie.Enabled then
				local speedPieActive = false
				local statusHud = lplr.PlayerGui:FindFirstChild('StatusEffectHudScreen')
				if statusHud then
					local hud = statusHud:FindFirstChild('StatusEffectHud')
					if hud then
						local speedPieFrame = hud:FindFirstChild('Speed Pie')
						if speedPieFrame then
							local timer = speedPieFrame:FindFirstChild('4')
							if timer and timer:IsA('TextLabel') then
								local val = tonumber(timer.Text)
								speedPieActive = val and val > 0
							end
						end
					end
				end
				if not speedPieActive then
					local inv = replicatedStorage:FindFirstChild('Inventories') and replicatedStorage.Inventories:FindFirstChild(lplr.Name)
					local pieItem = inv and inv:FindFirstChild('pie')
					if pieItem then
						replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged.ConsumeItem:InvokeServer({item = pieItem})
					end
				end
			end

			if ShieldPotion.Enabled and (not attribute or attribute:find('Shield')) then
				if (lplr.Character:GetAttribute('Shield_POTION') or 0) == 0 then
					local shield = getItem('big_shield') or getItem('mini_shield')
	
					if shield then
						replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged.ConsumeItem:InvokeServer({item = shield.tool})
					end
				end
			end
		end
	end
	
	local function heldConsume()
		if consuming then return end
		local tool = store.hand.tool
		if not tool then return end
		local item = getItem(tool.Name)
		if not item then return end
		local meta = bedwars.ItemMeta[item.itemType]
		if not meta or not meta.consumable then return end

		consuming = true
		local humanoid = lplr.Character and lplr.Character:FindFirstChildOfClass('Humanoid')
		local anim = Instance.new('Animation')
		anim.AnimationId = 'rbxassetid://4968114448'
		if humanoid then
			heldTrack = humanoid:LoadAnimation(anim)
			heldTrack:Play()
		end

		if NoSlow.Enabled and humanoid then
			local normalSpeed = humanoid.WalkSpeed
			task.spawn(function()
				while consuming and NoSlow.Enabled do
					humanoid.WalkSpeed = normalSpeed
					task.wait()
				end
			end)
		end

		task.wait(Delay.Value)

		if heldTrack then
			heldTrack:Stop()
			heldTrack = nil
		end

		if consuming and store.hand.tool and store.hand.tool.Name == tool.Name then
			local currentItem = getItem(tool.Name)
			if currentItem then
				replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged.ConsumeItem:InvokeServer({item = currentItem.tool})
			end
		end
		consuming = false
	end

	AutoConsume = vape.Categories.Inventory:CreateModule({
		Name = 'AutoConsume',
		Function = function(callback)
			if callback then
				local throttle = 0
				local throttledCheck = function()
					local now = tick()
					if now - throttle < 0.2 then return end
					throttle = now
					consumeCheck()
				end
				AutoConsume:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(throttledCheck))
				AutoConsume:Clean(vapeEvents.AttributeChanged.Event:Connect(function(attribute)
					if attribute:find('Shield') or attribute:find('Health') then
						throttledCheck()
					end
				end))
				consumeCheck()
				task.spawn(function()
					local lastTool
					while AutoConsume.Enabled do
						if LimitToItem.Enabled then
							local tool = store.hand.tool
							if tool and tool.Name ~= lastTool then
								lastTool = tool.Name
								heldConsume()
							elseif not tool then
								lastTool = nil
							end
						end
						task.wait(0.2)
					end
				end)
				task.spawn(function()
					while AutoConsume.Enabled do
						task.wait(0.3)
						if SerpentsTouch.Enabled then
							local serpent = getItem('serpents_touch_potion')
							if serpent then
								replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged.ConsumeItem:InvokeServer({item = serpent.tool})
							end
						end
						if JumpPotion.Enabled then
							local jumppotion = getItem('jump_potion')
							if jumppotion then
								replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged.ConsumeItem:InvokeServer({item = jumppotion.tool})
							end
						end
						if ShieldPotion.Enabled and (lplr.Character:GetAttribute('Shield_POTION') or 0) == 0 then
							local shield = getItem('big_shield') or getItem('mini_shield')
							if shield then
								replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged.ConsumeItem:InvokeServer({item = shield.tool})
							end
						end
					end
				end)
				task.spawn(function()
					while AutoConsume.Enabled do
						task.wait(0.5)
						if not SpeedPie or not SpeedPie.Enabled then continue end
						local speedPieActive = false
						local statusHud = lplr.PlayerGui:FindFirstChild('StatusEffectHudScreen')
						if statusHud then
							local hud = statusHud:FindFirstChild('StatusEffectHud')
							if hud then
								local speedPieFrame = hud:FindFirstChild('Speed Pie')
								if speedPieFrame then
									local timer = speedPieFrame:FindFirstChild('4')
									if timer and timer:IsA('TextLabel') then
										local val = tonumber(timer.Text)
										speedPieActive = val and val > 0
									end
								end
							end
						end
						if not speedPieActive then
							local inv = replicatedStorage:FindFirstChild('Inventories') and replicatedStorage.Inventories:FindFirstChild(lplr.Name)
							local pieItem = inv and inv:FindFirstChild('pie')
							if pieItem then
								replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged.ConsumeItem:InvokeServer({item = pieItem})
							end
						end
					end
				end)
			end
		end,
		Tooltip = 'Automatically heals for you when health or shield is under threshold.'
	})
	SpeedPotion = AutoConsume:CreateToggle({
		Name = 'Speed Potions',
		Default = true
	})
	Apple = AutoConsume:CreateToggle({
		Name = 'Apple',
		Default = true,
		Function = function(callback)
			if Health then
				Health.Object.Visible = callback
			end
		end
	})
	Health = AutoConsume:CreateSlider({
		Name = 'Health Percent',
		Min = 1,
		Max = 99,
		Default = 70,
		Suffix = '%',
		Visible = false
	})
	ShieldPotion = AutoConsume:CreateToggle({
		Name = 'Shield Potions',
		Default = true
	})
	GoldenApple = AutoConsume:CreateToggle({
		Name = 'Golden Apple',
		Default = false,
		Function = function(callback)
			if GoldenAppleHealth then
				GoldenAppleHealth.Object.Visible = callback
			end
		end
	})
	GoldenAppleHealth = AutoConsume:CreateSlider({
		Name = 'Eat At HP%',
		Min = 1,
		Max = 99,
		Default = 50,
		Suffix = '%',
		Visible = false
	})
	SpeedPie = AutoConsume:CreateToggle({
		Name = 'Speed Pie',
		Default = false
	})
	SerpentsTouch = AutoConsume:CreateToggle({
		Name = 'Serpents Potion',
		Default = true,
		Tooltip = 'auto drinks ur serpents touch potion when u got one'
	})
	JumpPotion = AutoConsume:CreateToggle({
		Name = 'Jump Potion',
		Default = true,
		Tooltip = 'auto chugs jump potions for u'
	})
	LimitToItem = AutoConsume:CreateToggle({
		Name = 'Limit To Item',
		Default = false,
		Function = function(callback)
			if Delay then
				Delay.Object.Visible = callback
			end
		end,
		Tooltip = 'only consumes stuff when ur actually holding it, waits the delay first'
	})
	Delay = AutoConsume:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 3,
		Default = 1,
		Suffix = 's',
		Visible = false,
		Tooltip = 'how long to wait before it actually eats it'
	})
	NoSlow = AutoConsume:CreateToggle({
		Name = 'No Slow',
		Default = false,
		Tooltip = 'stops u from getting slowed down while eating/drinking stuff'
	})
end)

run(function()
	local Value
	local oldclickhold, oldshowprogress
	
	local FastConsume = vape.Categories.Inventory:CreateModule({
		Name = 'FastConsume',
		Function = function(callback)
			if callback then
				oldclickhold = bedwars.ClickHold.startClick
				oldshowprogress = bedwars.ClickHold.showProgress
				bedwars.ClickHold.startClick = function(self)
					self.startedClickTime = tick()
					local handle = self:showProgress()
					local clicktime = self.startedClickTime
					bedwars.RuntimeLib.Promise.defer(function()
						task.wait(self.durationSeconds * (Value.Value / 40))
						if handle == self.handle and clicktime == self.startedClickTime and self.closeOnComplete then
							self:hideProgress()
							if self.onComplete then self.onComplete() end
							if self.onPartialComplete then self.onPartialComplete(1) end
							self.startedClickTime = -1
						end
					end)
				end
	
				bedwars.ClickHold.showProgress = function(self)
					local roact = debug.getupvalue(oldshowprogress, 1)
					local countdown = roact.mount(roact.createElement('ScreenGui', {}, { roact.createElement('Frame', {
						[roact.Ref] = self.wrapperRef,
						Size = UDim2.new(),
						Position = UDim2.fromScale(0.5, 0.55),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = 0.8
					}, { roact.createElement('Frame', {
						[roact.Ref] = self.progressRef,
						Size = UDim2.fromScale(0, 1),
						BackgroundColor3 = Color3.new(1, 1, 1),
						BackgroundTransparency = 0.5
					}) }) }), lplr:FindFirstChild('PlayerGui'))
	
					self.handle = countdown
					local sizetween = tweenService:Create(self.wrapperRef:getValue(), TweenInfo.new(0.1), {
						Size = UDim2.fromScale(0.11, 0.005)
					})
					local countdowntween = tweenService:Create(self.progressRef:getValue(), TweenInfo.new(self.durationSeconds * (Value.Value / 40), Enum.EasingStyle.Linear), {
						Size = UDim2.fromScale(1, 1)
					})
	
					sizetween:Play()
					countdowntween:Play()
					table.insert(self.tweens, countdowntween)
					table.insert(self.tweens, sizetween)
					
					return countdown
				end
			else
				bedwars.ClickHold.startClick = oldclickhold
				bedwars.ClickHold.showProgress = oldshowprogress
				oldclickhold = nil
				oldshowprogress = nil
			end
		end,
		Tooltip = 'Use/Consume items quicker.'
	})
	Value = FastConsume:CreateSlider({
		Name = 'Multiplier',
		Min = 0,
		Max = 100
	})
end)
	
run(function()
	local FastDrop
	local DropDelay
	local ItemList
	local UseBind
	local BBind
	local CurrentBind = Enum.KeyCode.H

	local function getInputEnum(inputName)
		if string.find(inputName, "MouseButton") then
			return Enum.UserInputType[inputName]
		else
			return Enum.KeyCode[inputName]
		end
	end

	local function isInputDown(input)
		if typeof(input) == "EnumItem" then
			if input.EnumType == Enum.KeyCode then
				return inputService:IsKeyDown(input)
			elseif input.EnumType == Enum.UserInputType then
				return inputService:IsMouseButtonPressed(input)
			end
		end
		return false
	end

	FastDrop = vape.Categories.Inventory:CreateModule({
		Name = 'FastDrop',
		Function = function(callback)
			if callback then

				repeat
					if entitylib.isAlive and (not store.inventory.opened) and (isInputDown(CurrentBind)) and inputService:GetFocusedTextBox() == nil then
						if tick() - store.lastDropTime >= (DropDelay.Value / 1000) then
							local handItem = store.hand and store.hand.tool
							if handItem then
								local itemType = handItem.Name
								local listEnabled = ItemList.ListEnabled
								
								local shouldDrop = true
								if #listEnabled > 0 then
									shouldDrop = table.find(listEnabled, itemType) ~= nil
								end
								
								if shouldDrop then
									task.spawn(bedwars.ItemDropController.dropItemInHand)
									store.lastDropTime = tick()
								end
							end
							task.wait()
						else
							task.wait(0.01)
						end
					else
						task.wait(0.1)
					end
				until not FastDrop.Enabled
			else
				store.lastDropTime = tick() + DropDelay.Value
			end
		end,
		Tooltip = 'Drops items fast'
	})

	DropDelay = FastDrop:CreateSlider({
		Name = 'Drop Delay',
		Min = 0,
		Max = 500,
		Default = 0,
		Suffix = 'ms'
	})
	
	ItemList = FastDrop:CreateTextList({
		Name = 'Item Whitelist',
		Placeholder = 'Item name (e.g., wool_blue)',
	})
end)

run(function()
	local AutoHotbar
	local Mode
	local Clear
	local List
	local Active
	
	local function CreateWindow(self)
		local selectedslot = 1
		local window = Instance.new('Frame')
		window.Name = 'HotbarGUI'
		window.Size = UDim2.fromOffset(660, 465)
		window.Position = UDim2.fromScale(0.5, 0.5)
		window.BackgroundColor3 = uipallet.Main
		window.AnchorPoint = Vector2.new(0.5, 0.5)
		window.Visible = false
		window.Parent = vape.gui.ScaledGui
		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.Size = UDim2.new(1, -10, 0, 20)
		title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 12)
		title.BackgroundTransparency = 1
		title.Text = 'AutoHotbar'
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = uipallet.Text
		title.TextSize = 13
		title.FontFace = uipallet.Font
		title.Parent = window
		local divider = Instance.new('Frame')
		divider.Name = 'Divider'
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.Position = UDim2.fromOffset(0, 40)
		divider.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
		divider.BorderSizePixel = 0
		divider.Parent = window
		addBlur(window)
		local modal = Instance.new('TextButton')
		modal.Text = ''
		modal.BackgroundTransparency = 1
		modal.Modal = true
		modal.Parent = window
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = window
		local close = Instance.new('ImageButton')
		close.Name = 'Close'
		close.Size = UDim2.fromOffset(24, 24)
		close.Position = UDim2.new(1, -35, 0, 9)
		close.BackgroundColor3 = Color3.new(1, 1, 1)
		close.BackgroundTransparency = 1
		close.Image = getcustomasset('aerov4/assets/new/close.png')
		close.ImageColor3 = color.Light(uipallet.Text, 0.2)
		close.ImageTransparency = 0.5
		close.AutoButtonColor = false
		close.Parent = window
		close.MouseEnter:Connect(function()
			close.ImageTransparency = 0.3
			tween:Tween(close, TweenInfo.new(0.2), {
				BackgroundTransparency = 0.6
			})
		end)
		close.MouseLeave:Connect(function()
			close.ImageTransparency = 0.5
			tween:Tween(close, TweenInfo.new(0.2), {
				BackgroundTransparency = 1
			})
		end)
		close.MouseButton1Click:Connect(function()
			window.Visible = false
			vape.gui.ScaledGui.ClickGui.Visible = true
		end)
		local closecorner = Instance.new('UICorner')
		closecorner.CornerRadius = UDim.new(1, 0)
		closecorner.Parent = close
		local bigslot = Instance.new('Frame')
		bigslot.Size = UDim2.fromOffset(110, 111)
		bigslot.Position = UDim2.fromOffset(11, 71)
		bigslot.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
		bigslot.Parent = window
		local bigslotcorner = Instance.new('UICorner')
		bigslotcorner.CornerRadius = UDim.new(0, 4)
		bigslotcorner.Parent = bigslot
		local bigslotstroke = Instance.new('UIStroke')
		bigslotstroke.Color = color.Light(uipallet.Main, 0.034)
		bigslotstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bigslotstroke.Parent = bigslot
		local slotnum = Instance.new('TextLabel')
		slotnum.Size = UDim2.fromOffset(80, 20)
		slotnum.Position = UDim2.fromOffset(25, 200)
		slotnum.BackgroundTransparency = 1
		slotnum.Name = 'SlotNum'
		slotnum.Text = 'SLOT 1'
		slotnum.TextColor3 = color.Dark(uipallet.Text, 0.1)
		slotnum.TextSize = 12
		slotnum.FontFace = uipallet.Font
		slotnum.Parent = window
		for i = 1, 9 do
			local slotbkg = Instance.new('TextButton')
			slotbkg.Name = 'Slot'..i
			slotbkg.Size = UDim2.fromOffset(51, 52)
			slotbkg.Position = UDim2.fromOffset(89 + (i * 55), 382)
			slotbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			slotbkg.Text = ''
			slotbkg.AutoButtonColor = false
			slotbkg.Parent = window
			local slotimage = Instance.new('ImageLabel')
			slotimage.Size = UDim2.fromOffset(32, 32)
			slotimage.Position = UDim2.new(0.5, -16, 0.5, -16)
			slotimage.BackgroundTransparency = 1
			slotimage.Image = ''
			slotimage.Parent = slotbkg
			local slotcorner = Instance.new('UICorner')
			slotcorner.CornerRadius = UDim.new(0, 4)
			slotcorner.Parent = slotbkg
			local slotstroke = Instance.new('UIStroke')
			slotstroke.Color = color.Light(uipallet.Main, 0.04)
			slotstroke.Thickness = 2
			slotstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			slotstroke.Enabled = i == selectedslot
			slotstroke.Parent = slotbkg
			slotbkg.MouseEnter:Connect(function()
				slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
			end)
			slotbkg.MouseLeave:Connect(function()
				slotbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			end)
			slotbkg.MouseButton1Click:Connect(function()
				window['Slot'..selectedslot].UIStroke.Enabled = false
				selectedslot = i
				slotstroke.Enabled = true
				slotnum.Text = 'SLOT '..selectedslot
			end)
			slotbkg.MouseButton2Click:Connect(function()
				local obj = self.Hotbars[self.Selected]
				if obj then
					window['Slot'..i].ImageLabel.Image = ''
					obj.Hotbar[tostring(i)] = nil
					obj.Object['Slot'..i].Image = '	'
				end
			end)
		end
		local searchbkg = Instance.new('Frame')
		searchbkg.Size = UDim2.fromOffset(496, 31)
		searchbkg.Position = UDim2.fromOffset(142, 80)
		searchbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		searchbkg.Parent = window
		local search = Instance.new('TextBox')
		search.Size = UDim2.new(1, -10, 0, 31)
		search.Position = UDim2.fromOffset(10, 0)
		search.BackgroundTransparency = 1
		search.Text = ''
		search.PlaceholderText = ''
		search.TextXAlignment = Enum.TextXAlignment.Left
		search.TextColor3 = uipallet.Text
		search.TextSize = 12
		search.FontFace = uipallet.Font
		search.ClearTextOnFocus = false
		search.Parent = searchbkg
		local searchcorner = Instance.new('UICorner')
		searchcorner.CornerRadius = UDim.new(0, 4)
		searchcorner.Parent = searchbkg
		local searchicon = Instance.new('ImageLabel')
		searchicon.Size = UDim2.fromOffset(14, 14)
		searchicon.Position = UDim2.new(1, -26, 0, 8)
		searchicon.BackgroundTransparency = 1
		searchicon.Image = getcustomasset('aerov4/assets/new/search.png')
		searchicon.ImageColor3 = color.Light(uipallet.Main, 0.37)
		searchicon.Parent = searchbkg
		local children = Instance.new('ScrollingFrame')
		children.Name = 'Children'
		children.Size = UDim2.fromOffset(500, 240)
		children.Position = UDim2.fromOffset(144, 122)
		children.BackgroundTransparency = 1
		children.BorderSizePixel = 0
		children.ScrollBarThickness = 2
		children.ScrollBarImageTransparency = 0.75
		children.CanvasSize = UDim2.new()
		children.Parent = window
		local windowlist = Instance.new('UIGridLayout')
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.FillDirectionMaxCells = 9
		windowlist.CellSize = UDim2.fromOffset(51, 52)
		windowlist.CellPadding = UDim2.fromOffset(4, 3)
		windowlist.Parent = children
		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / vape.guiscale.Scale)
		end)
		table.insert(vape.Windows, window)
	
		local function createitem(id, image)
			local slotbkg = Instance.new('TextButton')
			slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
			slotbkg.Text = ''
			slotbkg.AutoButtonColor = false
			slotbkg.Parent = children
			local slotimage = Instance.new('ImageLabel')
			slotimage.Size = UDim2.fromOffset(32, 32)
			slotimage.Position = UDim2.new(0.5, -16, 0.5, -16)
			slotimage.BackgroundTransparency = 1
			slotimage.Image = image
			slotimage.Parent = slotbkg
			local slotcorner = Instance.new('UICorner')
			slotcorner.CornerRadius = UDim.new(0, 4)
			slotcorner.Parent = slotbkg
			slotbkg.MouseEnter:Connect(function()
				slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
			end)
			slotbkg.MouseLeave:Connect(function()
				slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
			end)
			slotbkg.MouseButton1Click:Connect(function()
				local obj = self.Hotbars[self.Selected]
				if obj then
					window['Slot'..selectedslot].ImageLabel.Image = image
					obj.Hotbar[tostring(selectedslot)] = id
					obj.Object['Slot'..selectedslot].Image = image
				end
			end)
		end
	
		local function indexSearch(text)
			for _, v in children:GetChildren() do
				if v:IsA('TextButton') then
					v:ClearAllChildren()
					v:Destroy()
				end
			end
	
			if text == '' then
				for _, v in {'diamond_sword', 'diamond_pickaxe', 'diamond_axe', 'shears', 'wood_bow', 'wool_white', 'fireball', 'apple', 'iron', 'gold', 'diamond', 'emerald'} do
					createitem(v, bedwars.ItemMeta[v].image)
				end
				return
			end
	
			for i, v in bedwars.ItemMeta do
				if text:lower() == i:lower():sub(1, text:len()) then
					if not v.image then continue end
					createitem(i, v.image)
				end
			end
		end
	
		search:GetPropertyChangedSignal('Text'):Connect(function()
			indexSearch(search.Text)
		end)
		indexSearch('')
	
		return window
	end
	
	vape.Components.HotbarList = function(optionsettings, children, api)
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		local optionapi = {
			Type = 'HotbarList',
			Hotbars = {},
			Selected = 1
		}
		local hotbarlist = Instance.new('TextButton')
		hotbarlist.Name = 'HotbarList'
		hotbarlist.Size = UDim2.fromOffset(220, 40)
		hotbarlist.BackgroundColor3 = optionsettings.Darker and (children.BackgroundColor3 == color.Dark(uipallet.Main, 0.02) and color.Dark(uipallet.Main, 0.04) or color.Dark(uipallet.Main, 0.02)) or children.BackgroundColor3
		hotbarlist.Text = ''
		hotbarlist.BorderSizePixel = 0
		hotbarlist.AutoButtonColor = false
		hotbarlist.Parent = children
		local textbkg = Instance.new('Frame')
		textbkg.Name = 'BKG'
		textbkg.Size = UDim2.new(1, -20, 0, 31)
		textbkg.Position = UDim2.fromOffset(10, 4)
		textbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		textbkg.Parent = hotbarlist
		local textbkgcorner = Instance.new('UICorner')
		textbkgcorner.CornerRadius = UDim.new(0, 4)
		textbkgcorner.Parent = textbkg
		local textbutton = Instance.new('TextButton')
		textbutton.Name = 'HotbarList'
		textbutton.Size = UDim2.new(1, -2, 1, -2)
		textbutton.Position = UDim2.fromOffset(1, 1)
		textbutton.BackgroundColor3 = uipallet.Main
		textbutton.Text = ''
		textbutton.AutoButtonColor = false
		textbutton.Parent = textbkg
		textbutton.MouseEnter:Connect(function()
			tween:Tween(textbkg, TweenInfo.new(0.2), {
				BackgroundColor3 = color.Light(uipallet.Main, 0.14)
			})
		end)
		textbutton.MouseLeave:Connect(function()
			tween:Tween(textbkg, TweenInfo.new(0.2), {
				BackgroundColor3 = color.Light(uipallet.Main, 0.034)
			})
		end)
		local textbuttoncorner = Instance.new('UICorner')
		textbuttoncorner.CornerRadius = UDim.new(0, 4)
		textbuttoncorner.Parent = textbutton
		local textbuttonicon = Instance.new('ImageLabel')
		textbuttonicon.Size = UDim2.fromOffset(12, 12)
		textbuttonicon.Position = UDim2.fromScale(0.5, 0.5)
		textbuttonicon.AnchorPoint = Vector2.new(0.5, 0.5)
		textbuttonicon.BackgroundTransparency = 1
		textbuttonicon.Image = getcustomasset('aerov4/assets/new/add.png')
		textbuttonicon.ImageColor3 = Color3.fromHSV(0.46, 0.96, 0.52)
		textbuttonicon.Parent = textbutton
		local childrenlist = Instance.new('Frame')
		childrenlist.Size = UDim2.new(1, 0, 1, -40)
		childrenlist.Position = UDim2.fromOffset(0, 40)
		childrenlist.BackgroundTransparency = 1
		childrenlist.Parent = hotbarlist
		local windowlist = Instance.new('UIListLayout')
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
		windowlist.Padding = UDim.new(0, 3)
		windowlist.Parent = childrenlist
		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			hotbarlist.Size = UDim2.fromOffset(220, math.min(43 + windowlist.AbsoluteContentSize.Y / vape.guiscale.Scale, 603))
		end)
		optionapi.Window = CreateWindow(optionapi)
	
		function optionapi:Save(savetab)
			local hotbars = {}
			for _, v in self.Hotbars do
				table.insert(hotbars, v.Hotbar)
			end
			savetab.HotbarList = {
				Selected = self.Selected,
				Hotbars = hotbars
			}
		end
	
		function optionapi:Load(savetab)
			for _, v in self.Hotbars do
				v.Object:ClearAllChildren()
				v.Object:Destroy()
				table.clear(v.Hotbar)
			end
			table.clear(self.Hotbars)
			for _, v in savetab.Hotbars do
				self:AddHotbar(v)
			end
			self.Selected = savetab.Selected or 1
		end
	
		textbutton.MouseButton1Click:Connect(function()
		optionapi:AddHotbar()
	end)
	function optionapi:AddHotbar(data)
		local hotbardata = {Hotbar = data or {}}
			table.insert(self.Hotbars, hotbardata)
			local hotbar = Instance.new('TextButton')
			hotbar.Size = UDim2.fromOffset(200, 27)
			hotbar.BackgroundColor3 = table.find(self.Hotbars, hotbardata) == self.Selected and color.Light(uipallet.Main, 0.034) or uipallet.Main
			hotbar.Text = ''
			hotbar.AutoButtonColor = false
			hotbar.Parent = childrenlist
			hotbardata.Object = hotbar
			local hotbarcorner = Instance.new('UICorner')
			hotbarcorner.CornerRadius = UDim.new(0, 4)
			hotbarcorner.Parent = hotbar
			for i = 1, 9 do
				local slot = Instance.new('ImageLabel')
				slot.Name = 'Slot'..i
				slot.Size = UDim2.fromOffset(17, 18)
				slot.Position = UDim2.fromOffset(-7 + (i * 18), 5)
				slot.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
				slot.Image = hotbardata.Hotbar[tostring(i)] and bedwars.getIcon({itemType = hotbardata.Hotbar[tostring(i)]}, true) or ''
				slot.BorderSizePixel = 0
				slot.Parent = hotbar
			end
			hotbar.MouseButton1Click:Connect(function()
				local ind = table.find(optionapi.Hotbars, hotbardata)
				if ind == optionapi.Selected then
					vape.gui.ScaledGui.ClickGui.Visible = false
					optionapi.Window.Visible = true
					for i = 1, 9 do
						optionapi.Window['Slot'..i].ImageLabel.Image = hotbardata.Hotbar[tostring(i)] and bedwars.getIcon({itemType = hotbardata.Hotbar[tostring(i)]}, true) or ''
					end
				else
					if optionapi.Hotbars[optionapi.Selected] then
						optionapi.Hotbars[optionapi.Selected].Object.BackgroundColor3 = uipallet.Main
					end
					hotbar.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
					optionapi.Selected = ind
				end
			end)
			local close = Instance.new('ImageButton')
			close.Name = 'Close'
			close.Size = UDim2.fromOffset(16, 16)
			close.Position = UDim2.new(1, -23, 0, 6)
			close.BackgroundColor3 = Color3.new(1, 1, 1)
			close.BackgroundTransparency = 1
			close.Image = getcustomasset('aerov4/assets/new/closemini.png')
			close.ImageColor3 = color.Light(uipallet.Text, 0.2)
			close.ImageTransparency = 0.5
			close.AutoButtonColor = false
			close.Parent = hotbar
			local closecorner = Instance.new('UICorner')
			closecorner.CornerRadius = UDim.new(1, 0)
			closecorner.Parent = close
			close.MouseEnter:Connect(function()
				close.ImageTransparency = 0.3
				tween:Tween(close, TweenInfo.new(0.2), {
					BackgroundTransparency = 0.6
				})
			end)
			close.MouseLeave:Connect(function()
				close.ImageTransparency = 0.5
				tween:Tween(close, TweenInfo.new(0.2), {
					BackgroundTransparency = 1
				})
			end)
			close.MouseButton1Click:Connect(function()
				local ind = table.find(self.Hotbars, hotbardata)
				local obj = self.Hotbars[self.Selected]
				local obj2 = self.Hotbars[ind]
				if obj and obj2 then
					obj2.Object:ClearAllChildren()
					obj2.Object:Destroy()
					table.remove(self.Hotbars, ind)
					ind = table.find(self.Hotbars, obj)
					self.Selected = table.find(self.Hotbars, obj) or 1
				end
			end)
		end
	
		api.Options.HotbarList = optionapi
	
		return optionapi
	end
	
	local function getBlock()
		local clone = table.clone(store.inventory.inventory.items)
		table.sort(clone, function(a, b)
			return a.amount < b.amount
		end)
	
		for _, item in clone do
			local block = bedwars.ItemMeta[item.itemType].block
			if block and not block.seeThrough then
				return item
			end
		end
	end
	
	local function getCustomItem(v)
		if v == 'diamond_sword' then
			local sword = store.tools.sword
			v = sword and sword.itemType or 'wood_sword'
		elseif v == 'diamond_pickaxe' then
			local pickaxe = store.tools.stone
			v = pickaxe and pickaxe.itemType or 'wood_pickaxe'
		elseif v == 'diamond_axe' then
			local axe = store.tools.wood
			v = axe and axe.itemType or 'wood_axe'
		elseif v == 'wood_bow' then
			local bow = getBow()
			v = bow and bow.itemType or 'wood_bow'
		elseif v == 'wool_white' then
			local block = getBlock()
			v = block and block.itemType or 'wool_white'
		end
	
		return v
	end
	
	local function findItemInTable(tab, item)
		for slot, v in tab do
			if item.itemType == getCustomItem(v) then
				return tonumber(slot)
			end
		end
	end
	
	local function findInHotbar(item)
		for i, v in store.inventory.hotbar do
			if v.item and v.item.itemType == item.itemType then
				return i - 1, v.item
			end
		end
	end
	
	local function findInInventory(item)
		for _, v in store.inventory.inventory.items do
			if v.itemType == item.itemType then
				return v
			end
		end
	end
	
	local function dispatch(...)
		bedwars.Store:dispatch(...)
		vapeEvents.InventoryChanged.Event:Wait()
	end
	
	local function sortCallback()
		if Active then return end
		Active = true
		local items = (List.Hotbars[List.Selected] and List.Hotbars[List.Selected].Hotbar or {})
	
		for _, v in store.inventory.inventory.items do
			local slot = findItemInTable(items, v)
			if slot then
				local olditem = store.inventory.hotbar[slot]
				if olditem.item and olditem.item.itemType == v.itemType then continue end
				if olditem.item then
					dispatch({
						type = 'InventoryRemoveFromHotbar',
						slot = slot - 1
					})
				end
	
				local newslot = findInHotbar(v)
				if newslot then
					dispatch({
						type = 'InventoryRemoveFromHotbar',
						slot = newslot
					})
					if olditem.item then
						dispatch({
							type = 'InventoryAddToHotbar',
							item = findInInventory(olditem.item),
							slot = newslot
						})
					end
				end
	
				dispatch({
					type = 'InventoryAddToHotbar',
					item = findInInventory(v),
					slot = slot - 1
				})
			elseif Clear.Enabled then
				local newslot = findInHotbar(v)
				if newslot then
				   	dispatch({
						type = 'InventoryRemoveFromHotbar',
						slot = newslot
					})
				end
			end
		end
	
		Active = false
	end
	
	AutoHotbar = vape.Categories.Inventory:CreateModule({
		Name = 'AutoHotbar',
		Function = function(callback)
			if callback then
				task.spawn(sortCallback)
				if Mode.Value == 'On Key' then
					AutoHotbar:Toggle()
					return
				end
	
				AutoHotbar:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(sortCallback))
			end
		end,
		Tooltip = 'arranges your hotbar based off what u want'
	})
	Mode = AutoHotbar:CreateDropdown({
		Name = 'Activation',
		List = {'Toggle', 'On Key'},
		Function = function()
			if AutoHotbar.Enabled then
				AutoHotbar:Toggle()
				AutoHotbar:Toggle()
			end
		end
	})
	Clear = AutoHotbar:CreateToggle({Name = 'Clear Hotbar'})
	List = AutoHotbar:CreateHotbarList({})
end)

--[[
	Minigames Modules
]]

run(function()
    local BedPlates
    local Background
    local TeamColor
    local Color = {}
    local Reference = {}
    local BlockCache = {}
	local LayerCounter
	local LayerColor
	local UIStyle
	local PositionDropdown
	local IgnoreTeam
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local compactUI = Instance.new('ScreenGui')
    compactUI.Name = 'BedPlatesCompactUI'
    compactUI.Parent = vape.gui
    compactUI.Enabled = false
    compactUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    compactUI.DisplayOrder = 10
    compactUI.ResetOnSpawn = false
    local compactMainFrame = Instance.new('Frame')
    compactMainFrame.Name = 'MainFrame'
    compactMainFrame.Parent = compactUI
    compactMainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    compactMainFrame.BackgroundTransparency = 0.3
    compactMainFrame.BorderSizePixel = 0
    compactMainFrame.Position = UDim2.new(1, -8, 1, -8)
    compactMainFrame.Size = UDim2.new(0, 150, 0, 0)
    compactMainFrame.AutomaticSize = Enum.AutomaticSize.Y
    compactMainFrame.AnchorPoint = Vector2.new(1, 1)
    local compactCorner = Instance.new('UICorner')
    compactCorner.CornerRadius = UDim.new(0, 8)
    compactCorner.Parent = compactMainFrame
    local compactListLayout = Instance.new('UIListLayout')
    compactListLayout.Padding = UDim.new(0, 4)
    compactListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    compactListLayout.Parent = compactMainFrame
    local compactPadding = Instance.new('UIPadding')
    compactPadding.PaddingTop = UDim.new(0, 6)
    compactPadding.PaddingBottom = UDim.new(0, 6)
    compactPadding.PaddingLeft = UDim.new(0, 6)
    compactPadding.PaddingRight = UDim.new(0, 6)
    compactPadding.Parent = compactMainFrame
    
	local teamColors = getgenv().aeroTeamColors
    
    local function getBedTeamColor(bed)
        local teamId = bed:GetAttribute('TeamID') or bed:GetAttribute('Team') or bed:GetAttribute('TeamId')
        teamId = tonumber(teamId)
        if teamId and teamColors[teamId] then
            return teamColors[teamId]
        end
        return {name = 'Enemy', color = Color3.new(1, 1, 1)}
    end
    
    local function isMyBed(bed)
        local myTeam = lplr.Character and (lplr.Character:GetAttribute('Team') or lplr.Character:GetAttribute('TeamId'))
        local bedTeam = bed:GetAttribute('TeamID') or bed:GetAttribute('Team') or bed:GetAttribute('TeamId')
        if not myTeam or not bedTeam then return false end
        return tonumber(myTeam) == tonumber(bedTeam)
    end
    
	local function updateLayerTextColor()
		for _, ref in pairs(Reference) do
			for _, img in ref.billboard.Frame:GetChildren() do
				if img:IsA('ImageLabel') then
					local txt = img:FindFirstChild('Amount')
					if txt then
						txt.TextColor3 = LayerColor and Color3.fromHSV(LayerColor.Hue, LayerColor.Sat, LayerColor.Value) or Color3.fromRGB(250,250,250)
					end
				end
			end
		end
	end

    local function scanSide(self, start, tab, dirsHit)
		local checkDirs = {
			Vector3.new(3,0,0), Vector3.new(-3,0,0),
			Vector3.new(0,0,3), Vector3.new(0,0,-3),
			Vector3.new(3,0,3), Vector3.new(3,0,-3),
			Vector3.new(-3,0,3), Vector3.new(-3,0,-3),
			Vector3.new(0,3,0),
		}
		for _, side in ipairs(checkDirs) do
			for i = 1, 15 do
				local block = getPlacedBlock(start + (side * i))
				if not block or block == self or block.Name == 'bed' then break end
				if not block:GetAttribute('NoBreak') then
					tab[block.Name] = math.max(tab[block.Name] or 0, i)
					dirsHit[block.Name] = dirsHit[block.Name] or {}
					dirsHit[block.Name][tostring(side)] = true
				end
			end
		end
    end

	local function getBlockHealth(blck)
		local meta = bedwars.ItemMeta[blck]
		if not meta then  return 0 end
		local blockmeta = meta.block
		if not blockmeta then  return 0 end
		return blockmeta.health or 0
	end
    
    local BedTotals = {}

    local function getBedLayers(bed)
		local start = bedwars.BlockController:getBlockPosition(bed.Position) * 3
		local layers = {}
		local dirsHit = {}
		local founded = {}
		scanSide(bed, start, layers, dirsHit)
		scanSide(bed, start + Vector3.new(0,0,3), layers, dirsHit)
		for blocks, amount in layers do 
			local coverage = 0
			for _ in pairs(dirsHit[blocks] or {}) do
				coverage = coverage + 1
			end
			if coverage >= 5 then
				table.insert(founded, {blocks, amount})
			end
		end
		table.sort(founded, function(a,b)
			local healthA, healthB = getBlockHealth(a[1]), getBlockHealth(b[1])			
			return healthA == healthB and a[1] < b[1] or healthA > healthB
		end)
		return founded
    end

    local function renderLayers(frame, founded)
		for _, obj in frame:GetChildren() do
			if obj and (obj:IsA("ImageLabel") and obj.Name ~= 'Blur') then
				obj:Destroy()
			end
		end
		for _, data in founded do
			local block, amt = data[1], data[2]
			local image = Instance.new('ImageLabel')
			image.Size = UDim2.fromOffset(32,32)
			image.BackgroundTransparency = 1
			image.Image = bedwars.getIcon({itemType=block}, true)
			image.Parent = frame
			if amt >= 1 and (not LayerCounter or LayerCounter.Enabled) then
				local txt = Instance.new('TextLabel')
				txt.Name = 'Amount'
				txt.Size = UDim2.fromScale(1,1)
				txt.BackgroundTransparency = 1
				local newamt = amt
				txt.Text = tostring(newamt)
				txt.TextColor3 = LayerColor and Color3.fromHSV(LayerColor.Hue, LayerColor.Sat, LayerColor.Value) or Color3.fromRGB(250,250,250)
				txt.TextSize = 24
				txt.TextStrokeTransparency = 0.3
				txt.Font = Enum.Font.Arial
				txt.Parent = image
			end
		end
    end

    local function refreshAdornee(v)
		local bed = v.Adornee
		local founded = getBedLayers(bed)
		local total = 0
		for _, data in founded do total = math.max(total, data[2]) end
		BedTotals[bed] = total
		local mine = isMyBed(bed)
		v.Enabled = #founded > 0 and UIStyle.Value == 'Original' and not mine
		renderLayers(v.Frame, founded)
		if Reference[bed] and Reference[bed].compactRow then
			renderLayers(Reference[bed].compactRow.iconsFrame, founded)
			Reference[bed].compactRow.countLabel.Text = tostring(total)
			Reference[bed].compactRow.frame.Visible = #founded > 0 and not (mine and IgnoreTeam and IgnoreTeam.Enabled)
		end
    end
    
    local function Added(v)
        if Reference[v] then return end
        local _bpUserId = v:GetAttribute('PlacedByUserId')
        if _bpUserId then
            local _bpOk, _bpOwner = pcall(function() return playersService:GetPlayerByUserId(_bpUserId) end)
        end
        
        local billboard = Instance.new('BillboardGui')
        billboard.Parent = Folder
        billboard.Name = 'bed'
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
        billboard.Size = UDim2.fromOffset(36, TeamColor.Enabled and 50 or 36)
        billboard.AlwaysOnTop = true
        billboard.ClipsDescendants = false
        billboard.Adornee = v
        billboard.Enabled = UIStyle.Value == 'Original'
        
        local blur = addBlur(billboard)
        blur.Visible = Background.Enabled
        
        local frame = Instance.new('Frame')
        frame.Size = TeamColor.Enabled and UDim2.new(1, 0, 1, -16) or UDim2.fromScale(1, 1)
        frame.Position = TeamColor.Enabled and UDim2.new(0, 0, 0, 16) or UDim2.new(0, 0, 0, 0)
        frame.BackgroundColor3 = TeamColor.Enabled and getBedTeamColor(v).color or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
        frame.BackgroundTransparency = 1 - (Background.Enabled and (TeamColor.Enabled and 0.5 or Color.Opacity) or 0)
        frame.Parent = billboard

        local teamLabel = Instance.new('TextLabel')
        teamLabel.Name = 'TeamLabel'
        teamLabel.Size = UDim2.new(1, 0, 0, 14)
        teamLabel.Position = UDim2.new(0, 0, 0, 0)
        teamLabel.BackgroundTransparency = 1
        teamLabel.Text = getBedTeamColor(v).name
        teamLabel.TextColor3 = getBedTeamColor(v).color
        teamLabel.TextSize = 13
        teamLabel.Font = Enum.Font.GothamBold
        teamLabel.TextStrokeTransparency = 0.4
        teamLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        teamLabel.Visible = TeamColor.Enabled
        teamLabel.Parent = billboard
        
        local layout = Instance.new('UIListLayout')
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.Padding = UDim.new(0, 4)
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), TeamColor.Enabled and 50 or 36)
        end)
        layout.Parent = frame
        
        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = frame

        local rowFrame = Instance.new('Frame')
        rowFrame.BackgroundTransparency = 1
        rowFrame.Size = UDim2.new(1, 0, 0, 50)
        rowFrame.LayoutOrder = #compactMainFrame:GetChildren()
        rowFrame.Visible = false
        rowFrame.Parent = compactMainFrame

        local rowTeamLabel = Instance.new('TextLabel')
        rowTeamLabel.Size = UDim2.new(1, 0, 0, 14)
        rowTeamLabel.BackgroundTransparency = 1
        rowTeamLabel.Text = getBedTeamColor(v).name
        rowTeamLabel.TextColor3 = getBedTeamColor(v).color
        rowTeamLabel.TextSize = 13
        rowTeamLabel.Font = Enum.Font.GothamBold
        rowTeamLabel.TextStrokeTransparency = 0.4
        rowTeamLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        rowTeamLabel.Parent = rowFrame

        local rowBG = Instance.new('Frame')
        rowBG.Position = UDim2.new(0, 0, 0, 16)
        rowBG.Size = UDim2.new(1, 0, 0, 34)
        rowBG.BackgroundColor3 = Color3.new(0, 0, 0)
        rowBG.BackgroundTransparency = 0.3
        rowBG.Parent = rowFrame

        local rowCorner = Instance.new('UICorner')
        rowCorner.CornerRadius = UDim.new(0, 4)
        rowCorner.Parent = rowBG

        local rowIcons = Instance.new('Frame')
        rowIcons.BackgroundTransparency = 1
        rowIcons.Size = UDim2.new(1, -30, 1, 0)
        rowIcons.Parent = rowBG

        local rowIconLayout = Instance.new('UIListLayout')
        rowIconLayout.FillDirection = Enum.FillDirection.Horizontal
        rowIconLayout.Padding = UDim.new(0, 2)
        rowIconLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        rowIconLayout.Parent = rowIcons

        local rowCount = Instance.new('TextLabel')
        rowCount.Size = UDim2.new(0, 28, 1, 0)
        rowCount.Position = UDim2.new(1, -28, 0, 0)
        rowCount.BackgroundTransparency = 1
        rowCount.Text = "0"
        rowCount.TextColor3 = Color3.fromRGB(255, 255, 255)
        rowCount.TextSize = 14
        rowCount.Font = Enum.Font.GothamBold
        rowCount.Parent = rowBG

        Reference[v] = {
            billboard = billboard,
            compactRow = {
                frame = rowFrame,
                iconsFrame = rowIcons,
                countLabel = rowCount
            }
        }
        BlockCache[v] = ""
        refreshAdornee(billboard)
    end
    
    local _refreshNearPending = false
    local function refreshNear(data)
        if _refreshNearPending then return end
        _refreshNearPending = true
        task.defer(function()
            _refreshNearPending = false
            local blockPos = data.blockRef.blockPosition * 3
            local maxDistanceSq = 30 * 30
            for bed, ref in pairs(Reference) do
                if bed.Parent then
                    local offset = blockPos - bed.Position
                    local distanceSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z
                    if distanceSq <= maxDistanceSq then
                        refreshAdornee(ref.billboard)
                    end
                end
            end
        end)
    end

    local currentCorner = 'Bottom Right'

    local function updateCompactPosition()
        local genUI = vape.gui:FindFirstChild('GeneratorCompactUI')
        local offset = 8
        if genUI and genUI.Enabled and currentCorner == 'Bottom Right' then
            offset = offset + 128
        end
        local invHost = (gethui and gethui()) or game:GetService('CoreGui')
        if invHost:FindFirstChild('InventoryESP') and (currentCorner == 'Bottom Right' or currentCorner == 'Top Right') then
            offset = offset + 200
        end
        if currentCorner == 'Top Right' then
            compactMainFrame.AnchorPoint = Vector2.new(1, 0)
            compactMainFrame.Position = UDim2.new(1, -offset, 0, 8)
        elseif currentCorner == 'Top Left' then
            compactMainFrame.AnchorPoint = Vector2.new(0, 0)
            compactMainFrame.Position = UDim2.new(0, 8, 0, 8)
        elseif currentCorner == 'Bottom Left' then
            compactMainFrame.AnchorPoint = Vector2.new(0, 1)
            compactMainFrame.Position = UDim2.new(0, 8, 1, -8)
        else
            compactMainFrame.AnchorPoint = Vector2.new(1, 1)
            compactMainFrame.Position = UDim2.new(1, -offset, 1, -8)
        end
    end
    
    BedPlates = vape.Categories.Minigames:CreateModule({
        Name = 'BedPlates',
        Function = function(callback)
            if callback then
                table.clear(BlockCache)
                compactUI.Enabled = UIStyle.Value == 'Compact'
                
                local tagged = collectionService:GetTagged('bed')
                for _, v in ipairs(tagged) do 
                    Added(v)
                end
                
                BedPlates:Clean(vapeEvents.PlaceBlockEvent.Event:Connect(refreshNear))
                BedPlates:Clean(vapeEvents.BreakBlockEvent.Event:Connect(refreshNear))
                BedPlates:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(Added))

                local worldFolder = getWorldFolder()
                local blocksFolder = worldFolder and worldFolder:FindFirstChild('Blocks')
                if blocksFolder then
                    local function onBlockChange(obj)
                        if not (obj:IsA('BasePart')) then return end
                        refreshNear({blockRef = {blockPosition = obj.Position / 3}})
                    end
                    BedPlates:Clean(blocksFolder.ChildAdded:Connect(onBlockChange))
                    BedPlates:Clean(blocksFolder.ChildRemoved:Connect(onBlockChange))
                end
                BedPlates:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(v)
                    if Reference[v] then
                        Reference[v].billboard:Destroy()
                        Reference[v].compactRow.frame:Destroy()
                        Reference[v] = nil
                        BlockCache[v] = nil
                    end
                end))
                BedPlates:Clean(runService.Heartbeat:Connect(updateCompactPosition))
                BedPlates:Clean(runService.Heartbeat:Connect(function()
                    if not TeamColor.Enabled and Background.Enabled then
                        local col = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                        for bed, ref in pairs(Reference) do
                            ref.billboard.Frame.BackgroundColor3 = col
                        end
                    end
                    if LayerCounter.Enabled then
                        updateLayerTextColor()
                    end
                end))
            else
                for _, v in pairs(Reference) do
                    v.billboard:Destroy()
                    v.compactRow.frame:Destroy()
                end
                table.clear(Reference)
                table.clear(BlockCache)
                compactUI.Enabled = false
            end
        end,
        Tooltip = 'shows enemys bed defence'
    })

    UIStyle = BedPlates:CreateDropdown({
        Name = 'UI Style',
        List = {'Original', 'Compact'},
        Default = 'Original',
        Function = function(val)
            local isOriginal = val == 'Original'
            compactUI.Enabled = BedPlates.Enabled and not isOriginal
            for bed, ref in pairs(Reference) do
                ref.billboard.Enabled = isOriginal
                refreshAdornee(ref.billboard)
            end
            if PositionDropdown.Object then
                PositionDropdown.Object.Visible = not isOriginal
            end
            if IgnoreTeam and IgnoreTeam.Object then
                IgnoreTeam.Object.Visible = not isOriginal
            end
        end,
        Tooltip = 'pick between the floating world esp or a corner panel'
    })

    PositionDropdown = BedPlates:CreateDropdown({
        Name = 'Position',
        List = {'Top Right', 'Top Left', 'Bottom Left', 'Bottom Right'},
        Default = 'Bottom Right',
        Function = function(val)
            currentCorner = val
            updateCompactPosition()
        end,
        Tooltip = 'pick w corner u want the panel chillin in'
    })

    task.defer(function()
        if PositionDropdown and PositionDropdown.Object then
            PositionDropdown.Object.Visible = (UIStyle.Value == 'Compact')
        end
        if IgnoreTeam and IgnoreTeam.Object then
            IgnoreTeam.Object.Visible = (UIStyle.Value == 'Compact')
        end
    end)
    
    IgnoreTeam = BedPlates:CreateToggle({
        Name = 'Ignore Team',
        Default = false,
        Function = function(callback)
            for bed, ref in pairs(Reference) do
                refreshAdornee(ref.billboard)
            end
        end,
        Tooltip = 'wont show ur own team bed on the compact panel'
    })
    
    Background = BedPlates:CreateToggle({
        Name = 'Background',
        Function = function(callback)
            if Color.Object then 
                Color.Object.Visible = callback and not TeamColor.Enabled
            end
            for _, v in pairs(Reference) do
                v.Frame.BackgroundTransparency = 1 - (callback and (TeamColor.Enabled and 0.5 or Color.Opacity) or 0)
                local blur = v:FindFirstChild('Blur')
                if blur then
                    blur.Visible = callback
                end
            end
        end,
        Default = true
    })

    Color = BedPlates:CreateColorSlider({
        Name = 'Background Color',
        DefaultValue = 0,
        DefaultOpacity = 0.5,
        Function = function(hue, sat, val, opacity)
            for bed, v in pairs(Reference) do
                if not TeamColor.Enabled then
                    v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                end
                if Background.Enabled and not TeamColor.Enabled then
                    v.Frame.BackgroundTransparency = 1 - opacity
                end
            end
        end,
        Visible = false,
        Darker = true
    })
    
    TeamColor = BedPlates:CreateToggle({
        Name = 'Team Color',
        Default = true,
        Function = function(callback)
            if Color.Object then
                Color.Object.Visible = Background.Enabled and not callback
            end
            for bed, billboard in pairs(Reference) do
                billboard.Frame.BackgroundColor3 = callback and getBedTeamColor(bed).color or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                billboard.Frame.BackgroundTransparency = 1 - (Background.Enabled and (callback and 0.5 or Color.Opacity) or 0)
            end
        end
    })

	LayerCounter = BedPlates:CreateToggle({
		Name = 'Layer Counter',
		Function = function(callback)
			if LayerColor and LayerColor.Object then
				LayerColor.Object.Visible = callback
			end
			for _, billboard in pairs(Reference) do
				refreshAdornee(billboard)
			end
		end,
		Default = true
	})
	LayerColor = BedPlates:CreateColorSlider({
		Name = 'Counter Text Color',
		DefaultSat = 1,
		DefaultValue = 1,
		Function = function()
			updateLayerTextColor()
		end,
		Visible = LayerCounter.Enabled
	})	
end)

run(function()
	local AutoHonor
	local Delay
	local honoredusers = {}
	local maxhonors = 2
	
	local function getTeammates()
		local teammates = {}
		local nonteammates = {}
		local myTeam = lplr.Team
		
		for i, plr in playersService:GetPlayers() do
			if plr ~= lplr then
				if plr.Team == myTeam then
					table.insert(teammates, plr)
				else
					table.insert(nonteammates, plr)
				end
			end
		end
		return teammates, nonteammates
	end
	
	local function honorPlayers()
		if #honoredusers >= maxhonors then return end
		
		local teammates, nonteammates = getTeammates()
		
		if #teammates > 0 and #honoredusers < maxhonors then
			local randomTeammate = teammates[math.random(1, #teammates)]
			if not honoredusers[randomTeammate.UserId] then
				task.wait(Delay.Value)
				bedwars.HonorController:honorPlayer(randomTeammate.UserId)
				honoredusers[randomTeammate.UserId] = true
			end
		end
		
		if #nonteammates > 0 and #honoredusers < maxhonors then
			local randomEnemy = nonteammates[math.random(1, #nonteammates)]
			if not honoredusers[randomEnemy.UserId] then
				task.wait(Delay.Value)
				bedwars.HonorController:honorPlayer(randomEnemy.UserId)
				honoredusers[randomEnemy.UserId] = true
			end
		end
	end
	
	AutoHonor = vape.Categories.Minigames:CreateModule({
		Name = "AutoHonor",
		Function = function(callback)
			if callback then
				AutoHonor:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill and deathTable.entityInstance == lplr.Character and isEveryoneDead() and store.matchState ~= 2 then
						honorPlayers()
					end
				end))
				AutoHonor:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(...)
					honorPlayers()
				end))
			else
				table.clear(honoredusers)
			end
		end
	})
	Delay = AutoHonor:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Default = 0.05
	})
end)

run(function()
	local Breaker
	local TargetMode
	local Mode
	local Range
	local BreakSpeed
	local UpdateRate
	local Bed
	local BedCheck
	local LuckyBlock
	local IronOre
	local Tesla
	local Hive
	local Pinata
	local Crops
	local Effect
	local CustomHealth = {}
	local Animation
	local SelfBreak
	local LimitItem
	local AutoTool
	local MouseDown
	local Snow
	local YetiBreaker
	local RagnarBreaker
	local ShowPath
	local BlockHighlight
	local BreakerHighlightColor
	local BreakerAngle
	local blockHighlightInstance
	local parts = {}
	local lastYetiUse = 0
	local cachedTeammates = {}
	local cachedTeammatesTime = 0
	local breakabilityCache = {}
	local BREAK_CACHE_TTL = 0.5
	local legitRoute = {}
	local legitTarget = nil
	local legitAnchor = nil
	local legitPlanTime = 0
	local legitLastHit = 0
	local _hbMounted = nil
	local _hbPart = nil
	local _hbProgressRef = nil
	local _hbBlock = nil
	local _hbPos = nil
	local _hbMax = 1
	local _hbLast = 0
	local _hbPercent = -1

	local function screenPoint()
		if inputService.TouchEnabled then
			return gameCamera.ViewportSize / 2
		end
		return inputService:GetMouseLocation()
	end

	local function frontPoint()
		local root = entitylib.character and entitylib.character.RootPart
		if not root then return nil end
		local look = gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude < 0.01 then return root.Position end
		return root.Position + look.Unit * 6
	end

	local function cleanupHealthbar()
		if _hbMounted then
			pcall(bedwars.Roact.unmount, _hbMounted)
			_hbMounted = nil
		end
		if _hbPart then
			pcall(function() _hbPart:Destroy() end)
			_hbPart = nil
		end
		_hbProgressRef = nil
		_hbBlock = nil
		_hbPos = nil
		_hbPercent = -1
		local stray = workspace:FindFirstChild('AeroBreakerHB')
		while stray do
			pcall(function() stray:Destroy() end)
			stray = workspace:FindFirstChild('AeroBreakerHB')
		end
	end

	local function setHealthbarPercent(percent)
		percent = math.clamp(percent, 0, 1)
		if percent <= 0 then
			cleanupHealthbar()
			return
		end
		if math.abs(percent - _hbPercent) < 0.001 then return end
		_hbPercent = percent
		local bar = _hbProgressRef and _hbProgressRef:getValue()
		if bar then
			tweenService:Create(bar, TweenInfo.new(0.15), {
				Size = UDim2.fromScale(percent, 1),
				BackgroundColor3 = Color3.fromHSV(math.clamp(percent / 2.5, 0, 1), 0.89, 0.75)
			}):Play()
		end
	end

	local function customHealthbar(self, blockRef, health, maxHealth, changeHealth, block)
		if not Breaker or not Breaker.Enabled then return end
		if not block or not block.Parent then
			cleanupHealthbar()
			return
		end
		if block:GetAttribute('NoHealthbar') then return end
		health = block:GetAttribute('Health') or health
		maxHealth = block:GetAttribute('MaxHealth') or maxHealth
		if health <= 0 then
			cleanupHealthbar()
			return
		end

		if _hbBlock ~= block then
			cleanupHealthbar()
			_hbBlock = block
			local create = bedwars.Roact.createElement
			local percent = math.clamp(health / maxHealth, 0, 1)
			_hbProgressRef = bedwars.Roact.createRef()
			local part = Instance.new('Part')
			part.Name = 'AeroBreakerHB'
			part.Size = Vector3.one
			part.CFrame = CFrame.new(bedwars.BlockController:getWorldPosition(blockRef.blockPosition))
			part.Transparency = 1
			part.Anchored = true
			part.CanCollide = false
			part.Parent = workspace
			_hbPart = part
			bedwars.QueryUtil:setQueryIgnored(part, true)

			_hbMounted = bedwars.Roact.mount(create('BillboardGui', {
				Size = UDim2.fromOffset(249, 102),
				StudsOffset = Vector3.new(0, 2.5, 0),
				Adornee = part,
				MaxDistance = 40,
				AlwaysOnTop = true
			}, {
				create('Frame', {
					Size = UDim2.fromOffset(160, 50),
					Position = UDim2.fromOffset(44, 32),
					BackgroundColor3 = Color3.new(),
					BackgroundTransparency = 0.5
				}, {
					create('UICorner', {CornerRadius = UDim.new(0, 5)}),
					create('ImageLabel', {
						Size = UDim2.new(1, 89, 1, 52),
						Position = UDim2.fromOffset(-48, -31),
						BackgroundTransparency = 1,
						Image = getcustomasset('aerov4/assets/new/blur.png'),
						ScaleType = Enum.ScaleType.Slice,
						SliceCenter = Rect.new(52, 31, 261, 502)
					}),
					create('TextLabel', {
						Size = UDim2.fromOffset(145, 14),
						Position = UDim2.fromOffset(13, 12),
						BackgroundTransparency = 1,
						Text = (bedwars.ItemMeta[block.Name] and bedwars.ItemMeta[block.Name].displayName) or block.Name,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextColor3 = Color3.new(),
						TextScaled = true,
						Font = Enum.Font.Arial
					}),
					create('TextLabel', {
						Size = UDim2.fromOffset(145, 14),
						Position = UDim2.fromOffset(12, 11),
						BackgroundTransparency = 1,
						Text = (bedwars.ItemMeta[block.Name] and bedwars.ItemMeta[block.Name].displayName) or block.Name,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextColor3 = color.Dark(uipallet.Text, 0.16),
						TextScaled = true,
						Font = Enum.Font.Arial
					}),
					create('Frame', {
						Size = UDim2.fromOffset(138, 4),
						Position = UDim2.fromOffset(12, 32),
						BackgroundColor3 = uipallet.Main
					}, {
						create('UICorner', {CornerRadius = UDim.new(1, 0)}),
						create('Frame', {
							[bedwars.Roact.Ref] = _hbProgressRef,
							Size = UDim2.fromScale(percent, 1),
							BackgroundColor3 = Color3.fromHSV(math.clamp(percent / 2.5, 0, 1), 0.89, 0.75)
						}, {create('UICorner', {CornerRadius = UDim.new(1, 0)})})
					})
				})
			}), part)
		end

		_hbPos = blockRef.blockPosition
		_hbMax = math.max(tonumber(maxHealth) or health, 1)
		_hbLast = tick()
		setHealthbarPercent(health / _hbMax)
	end

	local function refreshHealthbar()
		if not _hbBlock then return end
		if not _hbBlock.Parent or (tick() - _hbLast) > 1.5 then
			cleanupHealthbar()
			return
		end
		local live = _hbBlock:GetAttribute('Health')
		if live then
			setHealthbarPercent(live / _hbMax)
		end
	end

	local function cachedIsBreakable(v)
		local now = tick()
		local cached = breakabilityCache[v]
		if cached and (now - cached.t) < BREAK_CACHE_TTL then
			return cached.v
		end
		local ok, result = pcall(function()
			local blockPos = bedwars.BlockController:getBlockPosition(v.Position)
			return bedwars.BlockController:isBlockBreakable({blockPosition = blockPos}, lplr)
		end)
		local val = ok and result or false
		breakabilityCache[v] = {v = val, t = now}
		return val
	end

	local function rebuildTeammateCache()
		local now = tick()
		if now - cachedTeammatesTime < 2 then return end
		cachedTeammatesTime = now
		table.clear(cachedTeammates)
		local localTeam = lplr:GetAttribute('Team') or lplr.Team
		if not localTeam then return end
		for _, player in playersService:GetPlayers() do
			local pt = player:GetAttribute('Team') or player.Team
			if pt == localTeam then
				cachedTeammates[player.UserId] = true
			end
		end
	end

	local function isSameTeam(userId)
		if not userId or userId == 0 then return false end
		rebuildTeammateCache()
		return cachedTeammates[userId] == true
	end

	local function myTeamId()
		return lplr:GetAttribute('Team')
			or (lplr.Character and (lplr.Character:GetAttribute('Team') or lplr.Character:GetAttribute('TeamId')))
	end

	local function passesChecks(v)
		if v:GetAttribute('NoBreak') then return false end

		if (v:GetAttribute('BedShieldEndTime') or 0) > workspace:GetServerTimeNow() then
			return false
		end

		local blockTeam = v:GetAttribute('Team') or v:GetAttribute('TeamId')
		local mineNow = myTeamId()
		if mineNow and v:GetAttribute('Team' .. tostring(mineNow) .. 'NoBreak') then
			return false
		end

		if not SelfBreak.Enabled then
			local mine = myTeamId()
			if blockTeam and mine and tonumber(blockTeam) == tonumber(mine) then
				return false
			end
			if v:GetAttribute('PlacedByUserId') == lplr.UserId then
				return false
			end
			if isSameTeam(v:GetAttribute('PlacedByUserId')) then
				return false
			end
		end

		if LimitItem.Enabled then
			local hand = store.hand and store.hand.tool
			local hmeta = hand and bedwars.ItemMeta[hand.Name]
			if not (hmeta and hmeta.breakBlock) then return false end
		end

		return true
	end

	local function ensureParts(count)
		if not (Breaker and Breaker.Enabled) then return end
		while #parts < count do
			local part = Instance.new('Part')
			part.Anchored = true
			part.CanQuery = false
			part.CanCollide = false
			part.Transparency = 1
			part.Position = Vector3.zero
			part.Parent = gameCamera
			local adorn = Instance.new('BoxHandleAdornment')
			adorn.Size = Vector3.one
			adorn.AlwaysOnTop = true
			adorn.ZIndex = 1
			adorn.Transparency = 0.5
			adorn.Adornee = part
			adorn.Parent = part
			table.insert(parts, part)
		end
	end

	local function hideParts()
		for _, p in parts do
			p.Position = Vector3.zero
		end
	end

	local function destroyParts()
		for _, p in parts do
			pcall(function()
				p:ClearAllChildren()
				p:Destroy()
			end)
		end
		table.clear(parts)
	end

	local function highlightColor(fallback)
		if BreakerHighlightColor then
			return Color3.fromHSV(BreakerHighlightColor.Hue, BreakerHighlightColor.Sat, BreakerHighlightColor.Value)
		end
		return fallback
	end

	local function setHighlight(block)
		if not (BlockHighlight and BlockHighlight.Enabled) then
			if blockHighlightInstance then blockHighlightInstance.Adornee = nil end
			return
		end
		if not blockHighlightInstance then
			if not (Breaker and Breaker.Enabled) then return end
			blockHighlightInstance = Instance.new('BoxHandleAdornment')
			blockHighlightInstance.AlwaysOnTop = true
			blockHighlightInstance.ZIndex = 10
			blockHighlightInstance.Transparency = 0.3
			blockHighlightInstance.Parent = gameCamera
		end
		blockHighlightInstance.Color3 = highlightColor(Color3.fromRGB(255, 255, 0))
		if block and block.Parent then
			blockHighlightInstance.Size = block.Size + Vector3.new(0.05, 0.05, 0.05)
			blockHighlightInstance.Adornee = block
		else
			blockHighlightInstance.Adornee = nil
		end
	end

	local function clearVisuals()
		hideParts()
		setHighlight(nil)
	end

	local function clearLegit()
		table.clear(legitRoute)
		legitTarget = nil
		legitAnchor = nil
	end

	local function cleanupAll()
		table.clear(breakabilityCache)
		clearLegit()
		if blockHighlightInstance then
			pcall(function() blockHighlightInstance:Destroy() end)
			blockHighlightInstance = nil
		end
		destroyParts()
		cleanupHealthbar()
	end

	local function useKitAbilities()
		if RagnarBreaker and RagnarBreaker.Enabled and store.equippedKit == 'berserker' then
			pcall(function()
				if bedwars.AbilityController and bedwars.AbilityController:canUseAbility('berserker_rage') then
					replicatedStorage:WaitForChild('events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'):WaitForChild('useAbility'):FireServer('berserker_rage')
				end
			end)
		end
		if YetiBreaker and YetiBreaker.Enabled and store.equippedKit == 'yeti' and (tick() - lastYetiUse) > 1 then
			lastYetiUse = tick()
			task.spawn(function()
				pcall(function()
					if bedwars.AbilityController and bedwars.AbilityController:canUseAbility('yeti_glacial_roar') then
						replicatedStorage:WaitForChild('events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'):WaitForChild('useAbility'):FireServer('yeti_glacial_roar')
					end
				end)
			end)
		end
	end

	local function holdingCorrectTool(v)
		if AutoTool.Enabled then return true end
		local blockMeta = bedwars.ItemMeta[v.Name]
		local breaktype = v.Name == 'gumdrop_bounce_pad' and 'stone' or (blockMeta and blockMeta.block and blockMeta.block.breakType)
		if not breaktype then return true end
		local correctTool = store.tools[breaktype]
		if not correctTool then return true end
		local hand = store.hand and store.hand.tool
		return hand ~= nil and hand.Name == correctTool.tool.Name
	end

	local function drawPath(target, path, endpos)
		if not (ShowPath and ShowPath.Enabled) or not path or not target then
			hideParts()
			return
		end
		local currentnode = target
		for _, part in parts do
			part.Position = currentnode or Vector3.zero
			if currentnode then
				part.BoxHandleAdornment.Color3 = currentnode == endpos and Color3.new(1, 0.2, 0.2)
					or currentnode == target and Color3.new(0.2, 0.2, 1)
					or Color3.new(0.2, 1, 0.2)
			end
			currentnode = path[currentnode]
		end
	end

	local function drawRoute(activePos)
		if not (ShowPath and ShowPath.Enabled) then
			hideParts()
			return
		end
		for i, part in parts do
			local node = legitRoute[i]
			part.Position = node or Vector3.zero
			if node then
				part.BoxHandleAdornment.Color3 = node == activePos and Color3.new(1, 0.2, 0.2) or Color3.new(0.2, 1, 0.2)
			end
		end
	end

	local damageRemote
	task.spawn(function()
		pcall(function()
			damageRemote = replicatedStorage
				:WaitForChild('rbxts_include'):WaitForChild('node_modules')
				:WaitForChild('@easy-games'):WaitForChild('block-engine')
				:WaitForChild('node_modules'):WaitForChild('@rbxts')
				:WaitForChild('net'):WaitForChild('out')
				:WaitForChild('_NetManaged'):WaitForChild('DamageBlock')
		end)
	end)

	local function rawBreak(block)
		if not damageRemote or not block or not block.Parent then return false end
		local bp = bedwars.BlockController:getBlockPosition(block.Position)
		task.spawn(function()
			local ok, res = pcall(function()
				return damageRemote:InvokeServer({
					blockRef = {blockPosition = bp},
					hitPosition = block.Position + Vector3.new(0, block.Size.Y / 2, 0),
					hitNormal = Vector3.yAxis
				})
			end)
		end)
		return true
	end

	local ignoreList = {}
	local cursorParams = RaycastParams.new()
	cursorParams.FilterType = Enum.RaycastFilterType.Exclude

	local function cursorBlock()
		local sp = screenPoint()
		local unit = gameCamera:ViewportPointToRay(sp.X, sp.Y, 0)
		table.clear(ignoreList)
		if lplr.Character then
			table.insert(ignoreList, lplr.Character)
		end
		for _, plr in playersService:GetPlayers() do
			if plr.Character then
				table.insert(ignoreList, plr.Character)
			end
		end
		for _, ent in entitylib.List do
			if ent.Character then
				table.insert(ignoreList, ent.Character)
			end
		end
		cursorParams.FilterDescendantsInstances = ignoreList
		local result = workspace:Raycast(unit.Origin, unit.Direction * 999, cursorParams)
		if not result then return nil, nil end
		local inst = result.Instance
		return (inst and inst:IsA('BasePart')) and inst or nil, result.Position
	end

	local function containedWorldPositions(block)
		local out = {}
		local ok, handler = pcall(function()
			return bedwars.BlockController:getHandlerRegistry():getHandler(block.Name)
		end)
		if ok and handler then
			local ok2, cp = pcall(function() return handler:getContainedPositions(block) end)
			if ok2 and cp then
				for _, v in cp do
					table.insert(out, v * 3)
				end
			end
		end
		if #out == 0 then
			table.insert(out, bedwars.BlockController:getBlockPosition(block.Position) * 3)
		end
		return out
	end

	local function buildLegitRoute(target)
		local anchor = frontPoint()
		if not anchor then return false end

		local bestPos, bestPath, bestStart, bestScore = nil, nil, nil, math.huge
		for _, startPos in containedWorldPositions(target) do
			local ok, pos, cost, path = pcall(bedwars.calculatePath, target, startPos, BreakerAngle.Value, anchor)
			if ok and pos and cost then
				local score = cost + (pos - anchor).Magnitude * 0.1
				if score < bestScore then
					bestPos, bestPath, bestStart, bestScore = pos, path, startPos, score
				end
			end
		end
		if not bestPos then return false end

		table.clear(legitRoute)
		local cur = bestPos
		local guard = 0
		while cur and guard < 128 do
			guard = guard + 1
			table.insert(legitRoute, cur)
			if cur == bestStart then break end
			cur = bestPath and bestPath[cur]
		end

		legitAnchor = anchor
		legitTarget = target
		legitPlanTime = tick()
		return #legitRoute > 0
	end

	Breaker = vape.Categories.Minigames:CreateModule({
		Name = 'Breaker',
		Function = function(callback)
			if callback then
				local beds = {}
				local function bedAdd(obj)
					if obj.Name ~= 'bed' or not obj:IsA('BasePart') then return end
					if table.find(beds, obj) then return end
					table.insert(beds, obj)
				end
				local function bedRemove(obj)
					local i = table.find(beds, obj)
					if i then table.remove(beds, i) end
				end
				for _, obj in workspace:GetChildren() do
					bedAdd(obj)
				end
				Breaker:Clean(workspace.ChildAdded:Connect(bedAdd))
				Breaker:Clean(workspace.ChildRemoved:Connect(bedRemove))
				task.spawn(function()
					while Breaker.Enabled do
						task.wait(1)
						for i = #beds, 1, -1 do
							if not beds[i] or not beds[i].Parent then
								table.remove(beds, i)
							end
						end
						for _, obj in workspace:GetChildren() do
							bedAdd(obj)
						end
					end
				end)
				local luckyblock = collection('LuckyBlock', Breaker)
				local ironores = collection('iron_ore_mesh_block', Breaker)

				local trackedSpecial = {tesla_trap = {}, beehive = {}, pinata = {}, carrot = {}, melon = {}, pumpkin = {}, snow_pile = {}}
				local _trackedNames = {tesla_trap = true, beehive = true, pinata = true, carrot = true, melon = true, pumpkin = true, snow_pile = true}

				local function trackAdd(obj)
					if not _trackedNames[obj.Name] then return end
					local t = trackedSpecial[obj.Name]
					if not t then return end
					if obj:IsA('BasePart') then
						table.insert(t, obj)
					elseif obj:IsA('Model') then
						local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA('BasePart')
						if part then table.insert(t, part) end
					end
				end

				local function trackRemove(obj)
					if not _trackedNames[obj.Name] then return end
					local t = trackedSpecial[obj.Name]
					if t then
						local part = obj
						if obj:IsA('Model') then
							part = obj.PrimaryPart or obj:FindFirstChildWhichIsA('BasePart')
						end
						if part then
							local i = table.find(t, part)
							if i then table.remove(t, i) end
						end
					end
					breakabilityCache[obj] = nil
				end

				ensureParts(8)
				scanDescendants(workspace, trackAdd, Breaker)
				Breaker:Clean(workspace.DescendantAdded:Connect(trackAdd))
				Breaker:Clean(workspace.DescendantRemoving:Connect(trackRemove))

				local function getBlockHealth(block)
					return block:GetAttribute('Health')
						or (bedwars.ItemMeta[block.Name] and bedwars.ItemMeta[block.Name].block and bedwars.ItemMeta[block.Name].block.health)
						or 0
				end

				local function candidateLists()
					local lists = {}
					if Bed.Enabled then
						table.insert(lists, beds)
					end
					if Tesla and Tesla.Enabled then table.insert(lists, trackedSpecial.tesla_trap) end
					if Hive and Hive.Enabled then table.insert(lists, trackedSpecial.beehive) end
					if LuckyBlock.Enabled then table.insert(lists, luckyblock) end
					if IronOre.Enabled then table.insert(lists, ironores) end
					if Snow and Snow.Enabled then table.insert(lists, trackedSpecial.snow_pile) end
					if Pinata and Pinata.Enabled then table.insert(lists, trackedSpecial.pinata) end
					if Crops and Crops.Enabled then
						table.insert(lists, trackedSpecial.carrot)
						table.insert(lists, trackedSpecial.melon)
						table.insert(lists, trackedSpecial.pumpkin)
					end
					return lists
				end

				local function valid(v, localPosition)
					if not v or not v.Parent then return false end
					local d = (v.Position - localPosition).Magnitude
					if d >= Range.Value then
						return false
					end
					if not passesChecks(v) then
						return false
					end
					if not cachedIsBreakable(v) then
						return false
					end
					return true
				end

				local function pickBest(tab, localPosition)
					if not tab then return nil end
					local best, bestValue = nil, math.huge
					for i = 1, #tab do
						local v = tab[i]
						if v and valid(v, localPosition) then
							local value = (TargetMode.Value == 'Health') and getBlockHealth(v) or (v.Position - localPosition).Magnitude
							if value < bestValue then
								best, bestValue = v, value
							end
						end
					end
					return best
				end

				local function pickClosestAny(localPosition)
					local best, bestDist = nil, math.huge
					for _, tab in candidateLists() do
						for i = 1, #tab do
							local v = tab[i]
							if v and valid(v, localPosition) then
								local dist = (v.Position - localPosition).Magnitude
								if dist < bestDist then
									best, bestDist = v, dist
								end
							end
						end
					end
					return best
				end

				local function runNormal(localPosition)
					local found = false
					for _, tab in candidateLists() do
						local best = pickBest(tab, localPosition)
						if best then
							found = true
							if holdingCorrectTool(best) then
								useKitAbilities()
								setHighlight(best)
								local breakWait = BreakSpeed.Value
								local target, path, endpos = bedwars.breakBlock(
									best,
									Effect.Enabled,
									Animation.Enabled,
									CustomHealth.Enabled and customHealthbar or nil,
									AutoTool.Enabled,
									BreakerAngle.Value
								)
								if target and endpos and target == endpos then
									rawBreak(best)
								end
								if BedCheck and BedCheck.Enabled and best.Name == 'bed' and target and (target - best.Position).Magnitude < 3 then
									breakWait = math.max(breakWait, 0.3)
								end
								drawPath(target, path, endpos)
								task.wait(breakWait)
								return true
							end
						end
					end
					return found
				end

				local function runLegit(localPosition)
					local target = pickClosestAny(localPosition)
					if not target then
						clearLegit()
						return false
					end

					local anchor = frontPoint()
					local stale = legitTarget ~= target
						or legitTarget and not legitTarget.Parent
						or not legitAnchor
						or not anchor
						or #legitRoute == 0
						or (anchor - legitAnchor).Magnitude > 6
						or (tick() - legitPlanTime) > 2

					local frontPos, frontBlock = nil, nil
					local function findFront()
						frontPos, frontBlock = nil, nil
						for _, pos in legitRoute do
							local blk = getPlacedBlock(pos)
							if blk then
								frontPos, frontBlock = pos, blk
								break
							end
						end
					end

					if not stale then
						findFront()
						if not frontBlock then stale = true end
					end
					if stale then
						if not buildLegitRoute(target) then
							clearVisuals()
							return false
						end
						findFront()
					end
					if not frontBlock then
						clearVisuals()
						return false
					end

					local raw, hitPos = cursorBlock()
					local aimed = nil
					if raw and raw.Parent then
						if raw == frontBlock or raw:IsDescendantOf(frontBlock) then
							aimed = frontBlock
						elseif frontBlock:IsA('BasePart') and raw:IsDescendantOf(frontBlock.Parent) and raw.Name == frontBlock.Name then
							aimed = frontBlock
						end
					end
					if not aimed and hitPos and (hitPos - frontBlock.Position).Magnitude <= 4.5 then
						aimed = frontBlock
					end

					drawRoute(aimed and frontPos or nil)

					if not aimed or (aimed.Position - localPosition).Magnitude > Range.Value then
						setHighlight(nil)
						return true
					end

					setHighlight(aimed)
					if (tick() - legitLastHit) >= BreakSpeed.Value then
						legitLastHit = tick()
						if holdingCorrectTool(aimed) then
							useKitAbilities()
							bedwars.breakBlock(
								aimed,
								Effect.Enabled,
								Animation.Enabled,
								CustomHealth.Enabled and customHealthbar or nil,
								AutoTool.Enabled,
								BreakerAngle.Value,
								frontPos
							)
						end
					end
					return true
				end

				repeat
					task.wait(1 / UpdateRate.Value)
					if not Breaker.Enabled then break end

					refreshHealthbar()
					if blockHighlightInstance and blockHighlightInstance.Adornee then
						local a = blockHighlightInstance.Adornee
						if not a.Parent or (a:GetAttribute('Health') or 1) <= 0 then
							blockHighlightInstance.Adornee = nil
							hideParts()
						end
					end
					if legitTarget and not legitTarget.Parent then
						clearLegit()
						hideParts()
					end

					if entitylib.isAlive then
						if MouseDown.Enabled and not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
							clearVisuals()
							continue
						end
						local localPosition = entitylib.character.RootPart.Position
						local ok, acted
						if Mode and Mode.Value == 'Legit' then
							ok, acted = pcall(runLegit, localPosition)
						else
							ok, acted = pcall(runNormal, localPosition)
						end
						if not ok then
							table.clear(breakabilityCache)
							acted = false
						end
						if not acted then
							clearVisuals()
						end
					else
						clearVisuals()
					end
				until not Breaker.Enabled
			else
				cleanupAll()
			end
		end,
		Tooltip = 'oh my god nuke the BEDD NOOOO'
	})

	vape:Clean(cleanupAll)

	TargetMode = Breaker:CreateDropdown({
		Name = 'Target Mode',
		List = {'Distance', 'Health'},
		Default = 'Distance',
		Tooltip = 'distance picks the closest block, health picks the weakest one'
	})
	Mode = Breaker:CreateDropdown({
		Name = 'Mode',
		List = {'Normal', 'Legit'},
		Default = 'Normal',
		Tooltip = 'normal digs to the block on its own, legit only breaks what ur cursor is on',
		Function = function(val)
			if TargetMode and TargetMode.Object then
				TargetMode.Object.Visible = val ~= 'Legit'
			end
			clearLegit()
		end
	})
	Range = Breaker:CreateSlider({
		Name = 'Break range',
		Min = 1,
		Max = 30,
		Default = 30,
		Tooltip = 'how far away a block can be for u to hit it'
	})
	BreakerAngle = Breaker:CreateSlider({
		Name = 'Break Angle',
		Min = 0,
		Max = 360,
		Default = 360,
		Tooltip = 'only digs thru blocks inside this cone in front of ur cam'
	})
	BreakSpeed = Breaker:CreateSlider({
		Name = 'Break speed',
		Min = 0,
		Max = 0.3,
		Default = 0.25,
		Decimal = 100,
		Tooltip = 'wait between each hit, lower is faster'
	})
	UpdateRate = Breaker:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Tooltip = 'how often it re checks for blocks, leave it high'
	})
	Bed = Breaker:CreateToggle({
		Name = 'Break Bed',
		Default = true,
		Function = function(callback)
			if BedCheck and BedCheck.Object then
				BedCheck.Object.Visible = callback
			end
		end
	})
	BedCheck = Breaker:CreateToggle({
		Name = 'Bed Check',
		Default = false,
		Darker = true,
		Tooltip = 'slows down to normal speed once ur actually on the bed'
	})
	LuckyBlock = Breaker:CreateToggle({
		Name = 'Break Lucky Block',
		Default = true
	})
	IronOre = Breaker:CreateToggle({
		Name = 'Break Iron Ore',
		Default = true
	})
	Snow = Breaker:CreateToggle({
		Name = 'Break Snow',
		Default = false
	})
	Tesla = Breaker:CreateToggle({
		Name = 'Break Tesla',
		Default = true
	})
	Hive = Breaker:CreateToggle({
		Name = 'Break Hive',
		Default = true
	})
	Pinata = Breaker:CreateToggle({
		Name = 'Break Pinata',
		Default = false
	})
	Crops = Breaker:CreateToggle({
		Name = 'Break Crops',
		Default = false,
		Tooltip = 'breaks farmer cletus crops (carrot and etc)'
	})
	Effect = Breaker:CreateToggle({
		Name = 'Show Healthbar & Effects',
		Default = true,
		Function = function(callback)
			if CustomHealth and CustomHealth.Object then
				CustomHealth.Object.Visible = callback
			end
		end
	})
	CustomHealth = Breaker:CreateToggle({
		Name = 'Custom Healthbar',
		Default = true,
		Darker = true
	})
	Animation = Breaker:CreateToggle({
		Name = 'Animation',
		Tooltip = 'plays the swing animation while u dig'
	})
	SelfBreak = Breaker:CreateToggle({
		Name = 'Self Break',
		Tooltip = 'lets it break ur own bed and blocks u or ur team placed'
	})
	AutoTool = Breaker:CreateToggle({
		Name = 'Auto Tool',
		Default = true,
		Tooltip = 'swaps to the right tool on its own, off means it waits till ur holdin it'
	})
	LimitItem = Breaker:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'only works while ur holdin sum that can break blocks'
	})
	MouseDown = Breaker:CreateToggle({
		Name = 'Require Mouse Down',
		Tooltip = 'only digs while u hold left click'
	})
	YetiBreaker = Breaker:CreateToggle({
		Name = 'Yeti Breaker',
		Tooltip = 'pops the yeti roar whenever ur nuking'
	})
	RagnarBreaker = Breaker:CreateToggle({
		Name = 'Ragnar',
		Tooltip = 'pops the ragnar rage whenever ur nuking'
	})
	ShowPath = Breaker:CreateToggle({
		Name = 'Show Path',
		Default = true,
		Tooltip = 'shows u the blocks its diggin thru'
	})
	BlockHighlight = Breaker:CreateToggle({
		Name = 'Block Highlight',
		Default = false,
		Function = function(callback)
			if BreakerHighlightColor and BreakerHighlightColor.Object then
				BreakerHighlightColor.Object.Visible = callback
			end
			if not callback and blockHighlightInstance then
				blockHighlightInstance.Adornee = nil
			end
		end,
		Tooltip = 'boxes the block its hittin rn'
	})
	BreakerHighlightColor = Breaker:CreateColorSlider({
		Name = 'Highlight Color',
		Darker = true,
		Visible = false
	})

	task.defer(function()
		if CustomHealth and CustomHealth.Object and Effect then
			CustomHealth.Object.Visible = Effect.Enabled
		end
		if BedCheck and BedCheck.Object and Bed then
			BedCheck.Object.Visible = Bed.Enabled
		end
		if BreakerHighlightColor and BreakerHighlightColor.Object and BlockHighlight then
			BreakerHighlightColor.Object.Visible = BlockHighlight.Enabled
		end
		if TargetMode and TargetMode.Object and Mode then
			TargetMode.Object.Visible = Mode.Value ~= 'Legit'
		end
	end)
end)

--[[
	Legit Modules
]]

run(function()
	local HitColor
	local Color
	local done = {}
	
	HitColor = vape.Categories.Legit:CreateModule({
		Name = 'HitColor',
		Function = function(callback)
			if callback then
				local function hookHighlight(v)
					local highlight = v.Character and v.Character:FindFirstChild('_DamageHighlight_')
					if highlight and not done[highlight] then
						highlight.FillColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
						highlight.FillTransparency = Color.Opacity
						done[highlight] = true
					end
				end
				for _, v in entitylib.List do hookHighlight(v) end
				HitColor:Clean(entitylib.Events.EntityAdded:Connect(hookHighlight))
			else
				for highlight in pairs(done) do
					if highlight and highlight.Parent then
						pcall(function()
							highlight.FillColor = Color3.new(1, 0, 0)
							highlight.FillTransparency = 0.4
						end)
					end
				end
				table.clear(done)
			end
		end,
		Tooltip = 'customize hit color'
	})
	Color = HitColor:CreateColorSlider({
		Name = 'Color',
		DefaultOpacity = 0.4
	})
end)



run(function()
	local Interface
	local HotbarOpenInventory = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-open-inventory']).HotbarOpenInventory
	local HotbarHealthbar = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui.healthbar['hotbar-healthbar']).HotbarHealthbar
	local HotbarApp = getRoactRender(require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-app']).HotbarApp.render)
	local old, new = {}, {}
	
	vape:Clean(function()
		for _, v in new do
			table.clear(v)
		end
		for _, v in old do
			table.clear(v)
		end
		table.clear(new)
		table.clear(old)
	end)
	
	local function modifyconstant(func, ind, val)
		if not func then return end
		if not old[func] then old[func] = {} end
		if not new[func] then new[func] = {} end
		if not old[func][ind] then
			old[func][ind] = debug.getconstant(func, ind)
		end
		if typeof(old[func][ind]) ~= typeof(val) then return end
		new[func][ind] = val
	
		if Interface.Enabled then
			if val then
				debug.setconstant(func, ind, val)
			else
				debug.setconstant(func, ind, old[func][ind])
				old[func][ind] = nil
			end
		end
	end
	
	Interface = vape.Categories.Legit:CreateModule({
		Name = 'Interface',
		Function = function(callback)
			for i, v in (callback and new or old) do
				for i2, v2 in v do
					debug.setconstant(i, i2, v2)
				end
			end
		end,
		Tooltip = 'Customize bedwars UI'
	})
	local fontitems = {'LuckiestGuy'}
	for _, v in Enum.Font:GetEnumItems() do
		if v.Name ~= 'LuckiestGuy' then
			table.insert(fontitems, v.Name)
		end
	end
	Interface:CreateDropdown({
		Name = 'Health Font',
		List = fontitems,
		Function = function(val)
			modifyconstant(HotbarHealthbar.render, 77, val)
		end
	})
	Interface:CreateColorSlider({
		Name = 'Health Color',
		Function = function(hue, sat, val)
			modifyconstant(HotbarHealthbar.render, 16, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
			if Interface.Enabled then
				local hotbar = lplr.PlayerGui:FindFirstChild('hotbar')
				hotbar = hotbar and hotbar:FindFirstChild('HealthbarProgressWrapper', true)
				if hotbar then
					hotbar['1'].BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				end
			end
		end
	})
	Interface:CreateColorSlider({
		Name = 'Hotbar Color',
		DefaultOpacity = 0.8,
		Function = function(hue, sat, val, opacity)
			local func = oldinvrender or HotbarOpenInventory.render
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 51, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 58, tonumber(Color3.fromHSV(hue, sat, math.clamp(val > 0.5 and val - 0.2 or val + 0.2, 0, 1)):ToHex(), 16))
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 54, 1 - opacity)
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 55, math.clamp(1.2 - opacity, 0, 1))
			modifyconstant(func, 31, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
			modifyconstant(func, 32, math.clamp(1.2 - opacity, 0, 1))
			modifyconstant(func, 34, tonumber(Color3.fromHSV(hue, sat, math.clamp(val > 0.5 and val - 0.2 or val + 0.2, 0, 1)):ToHex(), 16))
		end
	})
end)
	
run(function()
	local KillEffect
	local Mode
	local List
	local NameToId = {}
	
	local killeffects = {
		Gravity = function(_, _, char, _)
			char:BreakJoints()
			local highlight = char:FindFirstChildWhichIsA('Highlight')
			local nametag = char:FindFirstChild('Nametag', true)
			if highlight then
				highlight:Destroy()
			end
			if nametag then
				nametag:Destroy()
			end
	
			task.spawn(function()
				local partvelo = {}
				for _, v in char:GetDescendants() do
					if v:IsA('BasePart') then
						partvelo[v.Name] = v.Velocity
					end
				end
				char.Archivable = true
				local clone = char:Clone()
				clone.Humanoid.Health = 100
				clone.Parent = workspace
				game:GetService('Debris'):AddItem(clone, 30)
				char:Destroy()
				task.wait(0.01)
				clone.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
				clone:BreakJoints()
				task.wait(0.01)
				for _, v in clone:GetDescendants() do
					if v:IsA('BasePart') then
						local bodyforce = Instance.new('BodyForce')
						bodyforce.Force = Vector3.new(0, (workspace.Gravity - 10) * v:GetMass(), 0)
						bodyforce.Parent = v
						v.CanCollide = true
						v.Velocity = partvelo[v.Name] or Vector3.zero
					end
				end
			end)
		end,
		Lightning = function(_, _, char, _)
			char:BreakJoints()
			local highlight = char:FindFirstChildWhichIsA('Highlight')
			if highlight then
				highlight:Destroy()
			end
			local startpos = 1125
			local startcf = char.PrimaryPart.CFrame.p - Vector3.new(0, 8, 0)
			local newpos = Vector3.new((math.random(1, 10) - 5) * 2, startpos, (math.random(1, 10) - 5) * 2)
	
			for i = startpos - 75, 0, -75 do
				local newpos2 = Vector3.new((math.random(1, 10) - 5) * 2, i, (math.random(1, 10) - 5) * 2)
				if i == 0 then
					newpos2 = Vector3.zero
				end
				local part = Instance.new('Part')
				part.Size = Vector3.new(1.5, 1.5, 77)
				part.Material = Enum.Material.SmoothPlastic
				part.Anchored = true
				part.Material = Enum.Material.Neon
				part.CanCollide = false
				part.CFrame = CFrame.new(startcf + newpos + ((newpos2 - newpos) * 0.5), startcf + newpos2)
				part.Parent = workspace
				local part2 = part:Clone()
				part2.Size = Vector3.new(3, 3, 78)
				part2.Color = Color3.new(0.7, 0.7, 0.7)
				part2.Transparency = 0.7
				part2.Material = Enum.Material.SmoothPlastic
				part2.Parent = workspace
				game:GetService('Debris'):AddItem(part, 0.5)
				game:GetService('Debris'):AddItem(part2, 0.5)
				bedwars.QueryUtil:setQueryIgnored(part, true)
				bedwars.QueryUtil:setQueryIgnored(part2, true)
				if i == 0 then
					local soundpart = Instance.new('Part')
					soundpart.Transparency = 1
					soundpart.Anchored = true
					soundpart.Size = Vector3.zero
					soundpart.Position = startcf
					soundpart.Parent = workspace
					bedwars.QueryUtil:setQueryIgnored(soundpart, true)
					local sound = Instance.new('Sound')
					sound.SoundId = 'rbxassetid://6993372814'
					sound.Volume = 2
					sound.Pitch = 0.5 + (math.random(1, 3) / 10)
					sound.Parent = soundpart
					sound:Play()
					sound.Ended:Connect(function()
						soundpart:Destroy()
					end)
				end
				newpos = newpos2
			end
		end,
		Delete = function(_, _, char, _)
			char:Destroy()
		end
	}
	
	KillEffect = vape.Categories.Legit:CreateModule({
		Name = 'KillEffect',
		Function = function(callback)
			if callback then
				for i, v in killeffects do
					bedwars.KillEffectController.killEffects['Custom'..i] = {
						new = function()
							return {
								onKill = v,
								isPlayDefaultKillEffect = function()
									return false
								end
							}
						end
					}
				end
				KillEffect:Clean(lplr:GetAttributeChangedSignal('KillEffectType'):Connect(function()
					lplr:SetAttribute('KillEffectType', Mode.Value == 'Bedwars' and NameToId[List.Value] or 'Custom'..Mode.Value)
				end))
				lplr:SetAttribute('KillEffectType', Mode.Value == 'Bedwars' and NameToId[List.Value] or 'Custom'..Mode.Value)
			else
				for i in killeffects do
					bedwars.KillEffectController.killEffects['Custom'..i] = nil
				end
				lplr:SetAttribute('KillEffectType', 'default')
			end
		end,
		Tooltip = 'Custom final kill effects'
	})
	local modes = {'Bedwars'}
	for i in killeffects do
		table.insert(modes, i)
	end
	Mode = KillEffect:CreateDropdown({
		Name = 'Mode',
		List = modes,
		Function = function(val)
			List.Object.Visible = val == 'Bedwars'
			if KillEffect.Enabled then
				lplr:SetAttribute('KillEffectType', val == 'Bedwars' and NameToId[List.Value] or 'Custom'..val)
			end
		end
	})
	local KillEffectName = {}
	for i, v in bedwars.KillEffectMeta do
		table.insert(KillEffectName, v.name)
		NameToId[v.name] = i
	end
	table.sort(KillEffectName)
    List = KillEffect:CreateDropdown({
        Name = 'Bedwars',
        List = KillEffectName,
        Function = function(val)
            if KillEffect.Enabled then
                lplr:SetAttribute('KillEffectType', NameToId[val])
            end
        end,
        Darker = true
    })

    task.defer(function()
        if List and List.Object then
            List.Object.Visible = (Mode.Value == 'Bedwars')
        end
    end)
end)
	
run(function()
    local WinEffect
    local List
    local NameToId = {}
    
    WinEffect = vape.Categories.Legit:CreateModule({
        Name = "WinEffect",
        Function = function(callback)
            if callback then
                WinEffect:Clean(vapeEvents.MatchEndEvent.Event:Connect(function()
                    local remote = bedwars.Client:Get(remotes.WinEffectTriggered).instance
                    local payload = {
                        winEffectType = NameToId[List.Value],
                        winningPlayer = lplr
                    }
                    local ok = pcall(function()
                        remote.OnClientEvent:Fire(payload)
                    end)
                    if not ok then
                        for _, v in getconnections(remote.OnClientEvent) do
                            local fn = v.Function or v.Callback or v[1]
                            if fn then pcall(fn, payload) end
                        end
                    end
                end))
            end
        end,
        Tooltip = "select any clientside win effect"
    })
    
    local WinEffectName = {}
    for i, v in bedwars.WinEffectMeta do
        table.insert(WinEffectName, v.name)
        NameToId[v.name] = i
    end
    table.sort(WinEffectName)
    
    List = WinEffect:CreateDropdown({
        Name = "Effects",
        List = WinEffectName
    })
end)
run(function()
	local SilasIFrame
	SilasIFrame = vape.Categories.Kits:CreateModule({
		Name = "Silas I-Frame",
		Tooltip = 'allows you to swing ur sword when using ability on silas',
		Function = function(callback)
			if callback then
				if vape.Modules.Killaura.Enabled then
					vape:CreateNotification("Vape","Note, This disables swing state and allows sword swings while the attackable check is enabled.",12)
				end
				repeat
					if bedwars.SwordController then
						bedwars.SwordController.disableSwingState = false
					end
					task.wait(0.03)
				until not SilasIFrame.Enabled
			end
		end
	})
end)
run(function()
    local PlayerLevel
	local level 
	local old

	PlayerLevel = vape.Categories.Utility:CreateModule({
        Name = 'SetPlayerLevel',
		Tooltip = "Sets your player level to 1000 (client sided)",
        Function = function(callback)
			if callback then
				old = lplr:GetAttribute("PlayerLevel")
				lplr:SetAttribute("PlayerLevel", level.Value)
			else
				lplr:SetAttribute("PlayerLevel", old)
				old = nil
			end
		end
	})

	level = PlayerLevel:CreateSlider({
		Name = 'Player Level',
		Min = 1,
		Max = 1000,
		Default = 100,
		Function = function(val)
			if PlayerLevel.Enabled then
				lplr:SetAttribute("PlayerLevel", val)
			end
		end
	})
end)
run(function()
    local InfiniteJump
    local TP
    local ProgressBar
    local jumpHeld = false
    local progressFrame
    local progressFill
    local progressText

    local JumpVelocity = 50 -- fixed jump strength
    local TPDownDelay = 0.7
    local tpTick = 0
    local oldy
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    local lastGroundTime = tick()
    local tpToggle = true

    local function updateProgressBar(now, grounded)
        if not progressFrame then
            return
        end
        local visible = ProgressBar and ProgressBar.Enabled and TP and TP.Enabled and entitylib.isAlive and jumpHeld and not grounded and tpToggle
        progressFrame.Visible = visible
        if not visible then
            return
        end

        local elapsed = math.clamp(now - lastGroundTime, 0, TPDownDelay)
        progressFill.Size = UDim2.new(elapsed / TPDownDelay, 0, 1, 0)
        progressText.Text = string.format('TP Down in %.1fs', math.max(TPDownDelay - elapsed, 0))
    end

    local function createProgressBar()
        if progressFrame then
            return
        end

        progressFrame = Instance.new('Frame')
        progressFrame.Name = 'InfiniteJumpTPProgress'
        progressFrame.AnchorPoint = Vector2.new(0.5, 0)
        progressFrame.Position = inputService.TouchEnabled and UDim2.new(0.5, 0, 0, 90) or UDim2.new(0.5, 0, 1, -200)
        progressFrame.Size = inputService.TouchEnabled and UDim2.new(0.6, 0, 0, 22) or UDim2.new(0.2, 0, 0, 22)
        progressFrame.BackgroundColor3 = Color3.new(0, 0, 0)
        progressFrame.BackgroundTransparency = 0.5
        progressFrame.BorderSizePixel = 0
        progressFrame.Visible = false
        progressFrame.ZIndex = 100
        progressFrame.Parent = vape.gui

        progressFill = Instance.new('Frame')
        progressFill.Name = 'Fill'
        progressFill.Size = UDim2.new(0, 0, 1, 0)
        progressFill.BackgroundColor3 = Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
        progressFill.BorderSizePixel = 0
        progressFill.ZIndex = 101
        progressFill.Parent = progressFrame

        progressText = Instance.new('TextLabel')
        progressText.Name = 'Text'
        progressText.BackgroundTransparency = 1
        progressText.Size = UDim2.new(1, 0, 1, 0)
        progressText.Font = Enum.Font.Gotham
        progressText.Text = 'TP Down in 0.7s'
        progressText.TextColor3 = Color3.new(0.9, 0.9, 0.9)
        progressText.TextSize = 16
        progressText.TextStrokeTransparency = 0
        progressText.ZIndex = 102
        progressText.Parent = progressFrame
    end

    local function destroyProgressBar()
        if progressFrame then
            progressFrame:Destroy()
        end
        progressFrame = nil
        progressFill = nil
        progressText = nil
    end

    InfiniteJump = vape.Categories.Blatant:CreateModule({
        Name = "InfiniteJump",
        Tooltip = "Infinite jump + TP Down",
        Function = function(callback)
            if callback then
                lastGroundTime = tick()
                tpToggle = true
                oldy = nil
                jumpHeld = false
                createProgressBar()

                InfiniteJump:Clean(inputService.InputBegan:Connect(function(input)
                    if inputService:GetFocusedTextBox() then return end
                    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space then
                        jumpHeld = true
                    end
                end))

                InfiniteJump:Clean(inputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space then
                        jumpHeld = false
                    end
                end))

                if inputService.TouchEnabled then
                    local touchGui = lplr.PlayerGui:FindFirstChild('TouchGui')
                    local controlFrame = touchGui and touchGui:FindFirstChild('TouchControlFrame')
                    local jumpButton = controlFrame and controlFrame:FindFirstChild('JumpButton')
                    if jumpButton then
                        InfiniteJump:Clean(jumpButton.MouseButton1Down:Connect(function()
                            jumpHeld = true
                        end))
                        InfiniteJump:Clean(jumpButton.MouseButton1Up:Connect(function()
                            jumpHeld = false
                        end))
                    end
                end

                InfiniteJump:Clean(runService.PreSimulation:Connect(function()
                    if not entitylib.isAlive or not lplr.Character then
                        oldy = nil
                        tpToggle = true
                        jumpHeld = false
                        lastGroundTime = tick()
                        updateProgressBar(tick(), true)
                        return
                    end

                    local root = entitylib.character and entitylib.character.RootPart
                    local humanoid = entitylib.character and entitylib.character.Humanoid
                    if not root or not humanoid then
                        return
                    end

                    local now = tick()
                    local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
                    if grounded then
                        lastGroundTime = now
                        tpToggle = true
                    end

                    if oldy then
                        if tpTick < now then
                            root.CFrame = CFrame.lookAlong(
                                Vector3.new(root.Position.X, oldy, root.Position.Z),
                                root.CFrame.LookVector
                            )
                            oldy = nil
                            tpToggle = true
                            lastGroundTime = now
                        end
                        updateProgressBar(now, grounded)
                        return
                    end

                    if jumpHeld then
                        local velocity = root.AssemblyLinearVelocity
                        root.AssemblyLinearVelocity = Vector3.new(velocity.X, JumpVelocity, velocity.Z)
                    end

                    updateProgressBar(now, grounded)
                    if jumpHeld and not grounded and TP.Enabled and tpToggle and now - lastGroundTime >= TPDownDelay then
                        rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
                        rayCheck.CollisionGroup = root.CollisionGroup
                        local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
                        if ray then
                            oldy = root.Position.Y
                            tpToggle = false
                            tpTick = now + 0.11
                            updateProgressBar(now, false)
                            root.CFrame = CFrame.lookAlong(
                                Vector3.new(root.Position.X, ray.Position.Y + humanoid.HipHeight, root.Position.Z),
                                root.CFrame.LookVector
                            )
                        end
                    end
                end))
            else
                jumpHeld = false
                if oldy and entitylib.isAlive and entitylib.character and entitylib.character.RootPart then
                    local root = entitylib.character.RootPart
                    root.CFrame = CFrame.lookAlong(
                        Vector3.new(root.Position.X, oldy, root.Position.Z),
                        root.CFrame.LookVector
                    )
                end
                oldy = nil
                tpToggle = true
                destroyProgressBar()
            end
        end
    })

    TP = InfiniteJump:CreateToggle({
        Name = "TP Down",
        Default = true
    })
    ProgressBar = InfiniteJump:CreateToggle({
        Name = 'TP Down Progress Bar',
        Default = true,
        Function = function(callback)
            if progressFrame then
                progressFrame.Visible = callback and InfiniteJump.Enabled and TP.Enabled
            end
        end
    })
end)
run(function()
	local AutoToxic
	local GG
	local Toggles, Lists, said, dead = {}, {}, {}
	
	local function sendMessage(name, obj, default)
		local tab = Lists[name].ListEnabled
		local custommsg = #tab > 0 and tab[math.random(1, #tab)] or default
		if not custommsg then return end
		if #tab > 1 and custommsg == said[name] then
			repeat 
				task.wait() 
				custommsg = tab[math.random(1, #tab)] 
			until custommsg ~= said[name]
		end
		said[name] = custommsg
	
		custommsg = custommsg and custommsg:gsub('<obj>', obj or '') or ''
		if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(custommsg)
		else
			replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(custommsg, 'All')
		end
	end
	
	AutoToxic = vape.Categories.Utility:CreateModule({
		Name = 'AutoToxic',
		Function = function(callback)
			if callback then
				AutoToxic:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
					if Toggles.BedDestroyed.Enabled and bedTable.brokenBedTeam.id == lplr:GetAttribute('Team') then
						sendMessage('BedDestroyed', (bedTable.player.DisplayName or bedTable.player.Name), 'how dare you >:( | <obj>')
					elseif Toggles.Bed.Enabled and bedTable.player.UserId == lplr.UserId then
						local team = bedwars.QueueMeta[store.queueType].teams[tonumber(bedTable.brokenBedTeam.id)]
						sendMessage('Bed', team and team.displayName:lower() or 'white', 'nice bed lul | <obj>')
					end
				end))
				AutoToxic:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill then
						local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
						local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
						if not killed or not killer then return end
						if killed == lplr then
							if (not dead) and killer ~= lplr and Toggles.Death.Enabled then
								dead = true
								sendMessage('Death', (killer.DisplayName or killer.Name), 'my gaming chair subscription expired :( | <obj>')
							end
						elseif killer == lplr and Toggles.Kill.Enabled then
							sendMessage('Kill', (killed.DisplayName or killed.Name), 'vxp on top | <obj>')
						end
					end
				end))
				AutoToxic:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winstuff)
					if GG.Enabled then
						if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
							textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync('gg')
						else
							replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('gg', 'All')
						end
					end
					
					local myTeam = bedwars.Store:getState().Game.myTeam
					if myTeam and myTeam.id == winstuff.winningTeamId or lplr.Neutral then
						if Toggles.Win.Enabled then 
							sendMessage('Win', nil, 'yall garbage') 
						end
					end
				end))
			end
		end,
		Tooltip = 'Says a message after a certain action'
	})
	GG = AutoToxic:CreateToggle({
		Name = 'AutoGG',
		Default = true
	})
	for _, v in {'Kill', 'Death', 'Bed', 'BedDestroyed', 'Win'} do
		Toggles[v] = AutoToxic:CreateToggle({
			Name = v..' ',
			Function = function(callback)
				if Lists[v] then
					Lists[v].Object.Visible = callback
				end
			end
		})
		Lists[v] = AutoToxic:CreateTextList({
			Name = v,
			Darker = true,
			Visible = false
		})
	end
end)

for _, name in {'PlayerAttach', 'silentaim ', 'BlockCPSRemover', 'DamageTexts', 'StaffHUD', 'NetworkTP', 'ShadowRemover', 'PhaseMine', 'Scary Skybox', 'FastProxPrompt', 'SafeWalk', 'Wallhop', 'Freecam', 'Parkour', 'PotatoMode', 'Protect', 'RemoveNeon', 'Xray'} do
	local module = vape.Modules[name]
	if module and module.Enabled then
		module:Toggle()
	end
	vape:Remove(name)
end
run(function()
	local Shaders = {Enabled = false}

    local Shaders = vape.Categories.Render:CreateModule({
        Name = "Shaders",
        Function = function(callback)
            if callback then
                local VaporwaveSky = Lighting:FindFirstChild("VaporwaveSky") or Instance.new("Sky")
                VaporwaveSky.Name = "VaporwaveSky"
                VaporwaveSky.SkyboxBk = "rbxassetid://159454299"
                VaporwaveSky.SkyboxDn = "rbxassetid://159454296"
                VaporwaveSky.SkyboxFt = "rbxassetid://159454293"
                VaporwaveSky.SkyboxLf = "rbxassetid://159454286"
                VaporwaveSky.SkyboxRt = "rbxassetid://159454300"
                VaporwaveSky.SkyboxUp = "rbxassetid://159454288"
                VaporwaveSky.StarCount = 200
                VaporwaveSky.SunAngularSize = 10
                VaporwaveSky.MoonAngularSize = 9
                VaporwaveSky.CelestialBodiesShown = true
                VaporwaveSky.Parent = Lighting

                local Bloom = Lighting:FindFirstChild("VaporwaveBloom") or Instance.new("BloomEffect")
                Bloom.Name = "VaporwaveBloom"
                Bloom.Enabled = true
                Bloom.Intensity = 0.35
                Bloom.Threshold = 0.2
                Bloom.Size = 56
                Bloom.Parent = Lighting

                local Color = Lighting:FindFirstChild("VaporwaveColor") or Instance.new("ColorCorrectionEffect")
                Color.Name = "VaporwaveColor"
                Color.Enabled = true
                Color.Brightness = 0.05
                Color.Contrast = 0.25
                Color.Saturation = 0.5
                Color.TintColor = Color3.fromRGB(220, 160, 255)
                Color.Parent = Lighting

                local Atmosphere = Lighting:FindFirstChild("VaporwaveAtmosphere") or Instance.new("Atmosphere")
                Atmosphere.Name = "VaporwaveAtmosphere"
                Atmosphere.Density = 0.25
                Atmosphere.Offset = 0.15
                Atmosphere.Glare = 1.2
                Atmosphere.Haze = 1
                Atmosphere.Color = Color3.fromRGB(180, 140, 255)
                Atmosphere.Decay = Color3.fromRGB(220, 120, 200)
                Atmosphere.Parent = Lighting
            else
                local sky = Lighting:FindFirstChild("VaporwaveSky")
                if sky then sky:Destroy() end
                local bloom = Lighting:FindFirstChild("VaporwaveBloom")
                if bloom then bloom.Enabled = false end
                local color = Lighting:FindFirstChild("VaporwaveColor")
                if color then color.Enabled = false end
                local atmosphere = Lighting:FindFirstChild("VaporwaveAtmosphere")
                if atmosphere then atmosphere:Destroy() end
            end
        end,
        Tooltip = "Shaders"
    })
end)
run(function()
    local AnimeImages
    local AnimeSelection
    local anime_imageids = {
        ['Waifu1'] = 'rbxassetid://14417732284',
        ['Waifu2'] = 'rbxassetid://14665237598'
    }
	
    local animefunctions = {
        Waifu1 = function() 
            task.spawn(function()
				local scale
				local scaledUI = Instance.new('UIScale')
				local Anime = Instance.new('ScreenGui')
				local ImageLabel = Instance.new('ImageLabel')
				local scalebla = Instance.new('Frame')
				Anime.Name = 'Anime'
				Anime.Parent = coreGui
				Anime.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
				scalebla.Name = 'ScaledGui'
				scalebla.Size = UDim2.fromScale(1, 1)
				scalebla.BackgroundTransparency = 1
				scalebla.Parent = gui
				ImageLabel.Parent = Anime
				ImageLabel.BackgroundColor3 = Color3.new(1, 1, 1)
				ImageLabel.BackgroundTransparency = 1
				ImageLabel.BorderColor3 = Color3.new(0, 0, 0)
				ImageLabel.BorderSizePixel = 0
				ImageLabel.AnchorPoint = Vector2.new(1, 0)
				ImageLabel.Position = UDim2.new(1, -1, 0, -3)
				ImageLabel.Size = UDim2.new(0, 244, 0, 410)
				ImageLabel.Image = tostring(anime_imageids[tostring(AnimeSelection.Value)])
				ImageLabel.ScaleType = Enum.ScaleType.Fit
				scaledUI.Scale = math.max(ImageLabel.AbsoluteSize.X / 1920, 0.6)
				scale = math.max(ImageLabel.AbsoluteSize.X / 1920, 0.6)
				scaledUI.Parent = ImageLabel
				scalebla.Size = UDim2.fromScale(1 / scale, 1 / scale)

				AnimeImages:Clean(ImageLabel:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
					scaledUI.Scale = math.max(ImageLabel.AbsoluteSize.X / 1920, 0.6)
				end))
            end)
        end,
        
        Waifu2 = function() 
            task.spawn(function()
				local scale
				local scaledUI = Instance.new('UIScale')
				local Anime = Instance.new('ScreenGui')
				local ImageLabel = Instance.new('ImageLabel')
				local scalebla = Instance.new('Frame')
				Anime.Name = 'Anime'
				Anime.Parent = coreGui
				Anime.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
				scalebla.Name = 'ScaledGui'
				scalebla.Size = UDim2.fromScale(1, 1)
				scalebla.BackgroundTransparency = 1
				scalebla.Parent = Anime
				ImageLabel.Parent = Anime
				ImageLabel.BackgroundColor3 = Color3.new(1, 1, 1)
				ImageLabel.BackgroundTransparency = 1
				ImageLabel.BorderColor3 = Color3.new(0, 0, 0)
				ImageLabel.BorderSizePixel = 0
				ImageLabel.AnchorPoint = Vector2.new(1, 0)
				ImageLabel.Position = UDim2.new(1, -1, 0, -25)
				ImageLabel.Size = UDim2.new(0, 244, 0, 410)
				ImageLabel.Image = tostring(anime_imageids[tostring(AnimeSelection.Value)])
				ImageLabel.ScaleType = Enum.ScaleType.Fit
				scaledUI.Scale = math.max(ImageLabel.AbsoluteSize.X / 1920, 0.6)
				scale = math.max(ImageLabel.AbsoluteSize.X / 1920, 0.6)
				scaledUI.Parent = ImageLabel
				scalebla.Size = UDim2.fromScale(1 / scale, 1 / scale)

				AnimeImages:Clean(ImageLabel:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
					scaledUI.Scale = math.max(ImageLabel.AbsoluteSize.X / 1920, 0.6)
				end))
            end)
        end
    }

    AnimeImages = vape.Categories.Render:CreateModule({
        Name = 'AnimeImages',
        Function = function(callback) 
            if callback then
				for i,v in coreGui:GetChildren() do
                    if v.Name == 'Anime' then
                        v:Destroy()
                    end
                end

                animefunctions[AnimeSelection.Value]()
            else
                for i,v in coreGui:GetChildren() do
                    if v.Name == 'Anime' then
                        v:Destroy()
                    end
                end
            end
        end,
        Tooltip = 'Displays your desired image of Anime girls.',
        ExtraText = function()
            return AnimeSelection.Value
        end
    })
	AnimeSelection = AnimeImages:CreateDropdown({
		Name = 'Selection',
		Function = function(val)
			for i,v in coreGui:GetChildren() do
                if v.Name == 'Anime' then
                    v:Destroy()
                end
            end

            animefunctions[val]()
		end,
		List = {'Waifu1', 'Waifu2'}
	})
end)
run(function()
	local HotbarVisuals: table = {}
	local HotbarRounding: table  = {}
	local HotbarHighlight: table  = {}
	local HotbarColorToggle: table  = {}
	local HotbarHideSlotIcons: table  = {}
	local HotbarSlotNumberColorToggle: table  = {}
	local HotbarSpacing: table  = {Value = 0}
	local HotbarInvisibility: table  = {Value = 4}
	local HotbarRoundRadius: table  = {Value = 8}
	local HotbarColor: table  = {}
	local HotbarHighlightColor: table  = {}
	local HotbarSlotNumberColor: table  = {}
	local HotbarHealthbarColorToggle: table = {}
	local HotbarHealthbarColor: table = {}
	local HotbarHealthbarGradientToggle: table = {}
	local HotbarHealthbarGradientColor: table = {}
	local HotbarHealthbarGradientColor2: table = {}
	local HotbarHealthbarOutlineToggle: table = {}
	local HotbarHealthbarOutlineColor: table = {}
	local hotbarcoloricons: table  = {}
	local hotbarsloticons: table  = {}
	local hotbarobjects: table  = {}
	local hotbarslotgradients: table  = {}
	local inventoryiconobj: any = nil
	local healthbarFill: GuiObject? = nil
	local healthbarOriginalColor: Color3? = nil
	local healthbarGradient: UIGradient? = nil
	local healthbarOutline: UIStroke? = nil

	local function clearHealthbarEffects()
		if healthbarFill and healthbarFill.Parent and healthbarOriginalColor then
			healthbarFill.BackgroundColor3 = healthbarOriginalColor
		end
		if healthbarGradient then healthbarGradient:Destroy(); healthbarGradient = nil; end
		if healthbarOutline then healthbarOutline:Destroy(); healthbarOutline = nil; end
		healthbarFill = nil
		healthbarOriginalColor = nil
	end

	local function updateHealthbarEffects()
		local hotbar = lplr.PlayerGui:FindFirstChild('hotbar')
		local wrapper = hotbar and hotbar:FindFirstChild('HealthbarProgressWrapper', true)
		local fill = wrapper and wrapper:FindFirstChild('1')
		if not (fill and fill:IsA('GuiObject')) then
			clearHealthbarEffects()
			return
		end

		if healthbarFill ~= fill then
			clearHealthbarEffects()
			healthbarFill = fill
			healthbarOriginalColor = fill.BackgroundColor3
		end
		local originalColor = healthbarOriginalColor or fill.BackgroundColor3

		if HotbarHealthbarGradientToggle.Enabled then
			fill.BackgroundColor3 = Color3.new(1, 1, 1)
			if not healthbarGradient then
				healthbarGradient = Instance.new('UIGradient')
				healthbarGradient.Parent = fill
			end
			healthbarGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(HotbarHealthbarGradientColor.Hue, HotbarHealthbarGradientColor.Sat, HotbarHealthbarGradientColor.Value)),
				ColorSequenceKeypoint.new(1, Color3.fromHSV(HotbarHealthbarGradientColor2.Hue, HotbarHealthbarGradientColor2.Sat, HotbarHealthbarGradientColor2.Value))
			})
		else
			if healthbarGradient then healthbarGradient:Destroy(); healthbarGradient = nil; end
			fill.BackgroundColor3 = HotbarHealthbarColorToggle.Enabled
				and Color3.fromHSV(HotbarHealthbarColor.Hue, HotbarHealthbarColor.Sat, HotbarHealthbarColor.Value)
				or originalColor
		end

		if HotbarHealthbarOutlineToggle.Enabled then
			if not healthbarOutline then
				healthbarOutline = Instance.new('UIStroke')
				healthbarOutline.Thickness = 1.3
				healthbarOutline.Parent = fill
			end
			healthbarOutline.Color = Color3.fromHSV(HotbarHealthbarOutlineColor.Hue, HotbarHealthbarOutlineColor.Sat, HotbarHealthbarOutlineColor.Value)
		elseif healthbarOutline then
			healthbarOutline:Destroy()
			healthbarOutline = nil
		end
	end

	local function hotbarFunction(): (any, any)
		local icons: any = ({pcall(function() return lplr.PlayerGui.hotbar["1"].ItemsHotbar end)})[2];
		if not (icons and typeof(icons) == "Instance") then return end;

		inventoryiconobj = icons;
		pcall(function()
			local layout: UIListLayout? = icons:FindFirstChildOfClass("UIListLayout");
			if layout then layout.Padding = UDim.new(0, HotbarSpacing.Value); end
		end);

		for _, v: Instance in pairs(icons:GetChildren()) do
			local sloticon: TextLabel? = ({pcall(function() return v:FindFirstChildWhichIsA("ImageButton"):FindFirstChildWhichIsA("TextLabel") end)})[2];
			if typeof(sloticon) ~= "Instance" then continue end;

			local parent: GuiObject = sloticon.Parent;
			table.insert(hotbarcoloricons, parent);
			sloticon.Parent.Transparency = 0.1 * HotbarInvisibility.Value;

			if HotbarColorToggle.Enabled and not HotbarVisualsGradient.Enabled then
				parent.BackgroundColor3 = Color3.fromHSV(HotbarColor.Hue, HotbarColor.Sat, HotbarColor.Value);
			elseif HotbarVisualsGradient.Enabled and not parent:FindFirstChildWhichIsA("UIGradient") then
				parent.BackgroundColor3 = Color3.fromRGB(255, 255, 255);
				local g: UIGradient = Instance.new("UIGradient");
				g.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(HotbarVisualsGradientColor.Hue, HotbarVisualsGradientColor.Sat, HotbarVisualsGradientColor.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(HotbarVisualsGradientColor2.Hue, HotbarVisualsGradientColor2.Sat, HotbarVisualsGradientColor2.Value))
				});
				g.Parent = parent;
				table.insert(hotbarslotgradients, g);
			end;

			if HotbarRounding.Enabled then
				local r: UICorner = Instance.new("UICorner"); r.CornerRadius = UDim.new(0, HotbarRoundRadius.Value);
				r.Parent = parent; table.insert(hotbarobjects, r);
			end;

			if HotbarHighlight.Enabled then
				local hl: UIStroke = Instance.new("UIStroke");
				hl.Color = Color3.fromHSV(HotbarHighlightColor.Hue, HotbarHighlightColor.Sat, HotbarHighlightColor.Value);
				hl.Thickness = 1.3; hl.Parent = parent;
				table.insert(hotbarobjects, hl);
			end;

			if HotbarHideSlotIcons.Enabled then sloticon.Visible = false; end;
			table.insert(hotbarsloticons, sloticon);
		end;
	end;

	HotbarVisuals = vape.Categories.Utility:CreateModule({
		["Name"] = 'HotbarVisuals',
		["Tooltip"] = 'Add customization to your hotbar.',
		["Function"] = function(callback: boolean): void
			if callback then 
				task.spawn(function()
					table.insert(HotbarVisuals.Connections, lplr.PlayerGui.DescendantAdded:Connect(function(v)
						if v.Name == "hotbar" then hotbarFunction(); end
					end));
					hotbarFunction();
				end);
				table.insert(HotbarVisuals.Connections, runService.RenderStepped:Connect(function()
					for _, v in hotbarcoloricons do pcall(function() v.Transparency = 0.1 * HotbarInvisibility["Value"]; end); end
					updateHealthbarEffects()
				end));
			else
				clearHealthbarEffects()
				for _: any, v: any in hotbarsloticons do pcall(function() v.Visible = true; end); end
				for _: any, v: any in hotbarcoloricons do pcall(function() v.BackgroundColor3 = Color3.fromRGB(29, 36, 46); end); end
				for _: any, v: any in hotbarobjects do pcall(function() v:Destroy(); end); end
				for _: any, v: any in hotbarslotgradients do pcall(function() v:Destroy(); end); end
				table.clear(hotbarobjects); table.clear(hotbarsloticons); table.clear(hotbarcoloricons);
			end;
		end;
	})
	local function forceRefresh()
		if HotbarVisuals["Enabled"] then HotbarVisuals:Toggle(); HotbarVisuals:Toggle(); end;
	end;
	HotbarColorToggle = HotbarVisuals:CreateToggle({
		["Name"] = "Slot Color",
		["Function"] = function(callback: boolean): void pcall(function() HotbarColor.Object.Visible = callback; end); forceRefresh(); end
	});
	HotbarVisualsGradient = HotbarVisuals:CreateToggle({
		["Name"] = "Gradient Slot Color",
		["Function"] = function(callback: boolean): void
			pcall(function()
				HotbarVisualsGradientColor.Object.Visible = callback;
				HotbarVisualsGradientColor2.Object.Visible = callback;
			end);
			forceRefresh();
		end;
	});
	HotbarVisualsGradientColor = HotbarVisuals:CreateColorSlider({
		["Name"] = 'Gradient Color',
		["Function"] = function(h, s, v)
			for i: any, v: any in hotbarslotgradients do 
				pcall(function() v.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromHSV(HotbarVisualsGradientColor.Hue, HotbarVisualsGradientColor.Sat, HotbarVisualsGradientColor.Value)), ColorSequenceKeypoint.new(1, Color3.fromHSV(HotbarVisualsGradientColor2.Hue, HotbarVisualsGradientColor2.Sat, HotbarVisualsGradientColor2.Value))}) end)
			end;
		end;
	})
	HotbarVisualsGradientColor2 = HotbarVisuals:CreateColorSlider({
		["Name"] = 'Gradient Color 2',
		["Function"] = function(h, s, v)
			for i: any,v: any in hotbarslotgradients do 
				pcall(function() v.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromHSV(HotbarVisualsGradientColor.Hue, HotbarVisualsGradientColor.Sat, HotbarVisualsGradientColor.Value)), ColorSequenceKeypoint.new(1, Color3.fromHSV(HotbarVisualsGradientColor2.Hue, HotbarVisualsGradientColor2.Sat, HotbarVisualsGradientColor2.Value))}) end)
			end;
		end;
	})
	HotbarColor = HotbarVisuals:CreateColorSlider({
		["Name"] = 'Slot Color',
		["Function"] = function(h, s, v)
			for i: any,v: any in hotbarcoloricons do
				if HotbarColorToggle["Enabled"] then
					pcall(function() v.BackgroundColor3 = Color3.fromHSV(HotbarColor.Hue, HotbarColor.Sat, HotbarColor.Value) end) 
				end;
			end;
		end;
	})
	HotbarRounding = HotbarVisuals:CreateToggle({
		["Name"] = 'Rounding',
		["Function"] = function(callback: boolean): void pcall(function() HotbarRoundRadius.Object.Visible = callback; end); forceRefresh(); end
	})
	HotbarRoundRadius = HotbarVisuals:CreateSlider({
		["Name"] = 'Corner Radius',
		["Min"] = 1,
		["Max"] = 20,
		["Function"] = function(callback: boolean): void
			for i,v in hotbarobjects do 
				pcall(function() v.CornerRadius = UDim.new(0, callback) end);
			end;
		end;
	})
	HotbarHighlight = HotbarVisuals:CreateToggle({
		["Name"] = 'Outline Highlight',
		["Function"] = function(callback: boolean): void pcall(function() HotbarHighlightColor.Object.Visible = callback; end); forceRefresh(); end
	})
	HotbarHighlightColor = HotbarVisuals:CreateColorSlider({
		["Name"] = 'Highlight Color',
		["Function"] = function(h, s, v)
			for i,v in hotbarobjects do 
				if v:IsA('UIStroke') and HotbarHighlight.Enabled then 
					pcall(function() v.Color = Color3.fromHSV(HotbarHighlightColor.Hue, HotbarHighlightColor.Sat, HotbarHighlightColor.Value) end)
				end;
			end;
		end;
	})
	HotbarHideSlotIcons = HotbarVisuals:CreateToggle({
		["Name"] = "No Slot Numbers", ["Function"] = forceRefresh
	});
	HotbarInvisibility = HotbarVisuals:CreateSlider({
		["Name"] = 'Invisibility',
		["Min"] = 0,
		["Max"] = 10,
		["Default"] = 4,
		["Function"] = function(value)
			for i,v in hotbarcoloricons do 
				pcall(function() v.Transparency = (0.1 * value) end); 
			end;
		end;
	})
	HotbarSpacing = HotbarVisuals:CreateSlider({
		["Name"] = 'Spacing',
		["Min"] = 0,
		["Max"] = 5,
		["Function"] = function(value)
			if HotbarVisuals["Enabled"] then 
				pcall(function() inventoryiconobj:FindFirstChildOfClass('UIListLayout').Padding = UDim.new(0, value) end);
			end;
		end;
	})
	HotbarHealthbarColorToggle = HotbarVisuals:CreateToggle({
		["Name"] = 'Custom Healthbar Color',
		["Function"] = function(callback: boolean): void
			if HotbarHealthbarColor.Object then HotbarHealthbarColor.Object.Visible = callback; end
			updateHealthbarEffects()
		end
	})
	HotbarHealthbarColor = HotbarVisuals:CreateColorSlider({
		["Name"] = 'Healthbar Color',
		["Function"] = updateHealthbarEffects
	})
	HotbarHealthbarGradientToggle = HotbarVisuals:CreateToggle({
		["Name"] = 'Healthbar Gradient',
		["Function"] = function(callback: boolean): void
			if HotbarHealthbarGradientColor.Object then HotbarHealthbarGradientColor.Object.Visible = callback; end
			if HotbarHealthbarGradientColor2.Object then HotbarHealthbarGradientColor2.Object.Visible = callback; end
			updateHealthbarEffects()
		end
	})
	HotbarHealthbarGradientColor = HotbarVisuals:CreateColorSlider({
		["Name"] = 'Healthbar Gradient Color',
		["Function"] = updateHealthbarEffects
	})
	HotbarHealthbarGradientColor2 = HotbarVisuals:CreateColorSlider({
		["Name"] = 'Healthbar Gradient Color 2',
		["Function"] = updateHealthbarEffects
	})
	HotbarHealthbarOutlineToggle = HotbarVisuals:CreateToggle({
		["Name"] = 'Healthbar Outline',
		["Function"] = function(callback: boolean): void
			if HotbarHealthbarOutlineColor.Object then HotbarHealthbarOutlineColor.Object.Visible = callback; end
			updateHealthbarEffects()
		end
	})
	HotbarHealthbarOutlineColor = HotbarVisuals:CreateColorSlider({
		["Name"] = 'Healthbar Outline Color',
		["Function"] = updateHealthbarEffects
	})
	HotbarHealthbarColor.Object.Visible = false
	HotbarHealthbarGradientColor.Object.Visible = false
	HotbarHealthbarGradientColor2.Object.Visible = false
	HotbarHealthbarOutlineColor.Object.Visible = false
	HotbarColor.Object.Visible = false;
	HotbarRoundRadius.Object.Visible = false;
	HotbarHighlightColor.Object.Visible = false;
end);

run(function()
	local FakeLag = {Enabled = false}
	local FakeLagUsage = {Value = "Blatant"}
	local FakeLagSpeed = {Enabled = false}
	local FakeLagDelay1 = {Value = 2}
	local FakeLagDelay2 = {Value = 7}
	local FakeLagDelayLegit = {Value = 3}
	local FakeLagSpeed1 = {Value = 22}
	local FakeLagSpeed2 = {Value = 18}
	local FakeLagSpeed3 = {Value = 20}
	local FakeLagSpeed4 = {Value = 2.7}
	local FakeLagSpeed5 = {Value = 1.5}
	local function ChangeSpeeds() -- this won't work with speed but ok
		entitylib.character.Humanoid.WalkSpeed = FakeLagSpeed1.Value
		task.wait(FakeLagSpeed4.Value / 10)
		entitylib.character.Humanoid.WalkSpeed = FakeLagSpeed2.Value
		task.wait(FakeLagSpeed5.Value / 10)
		entitylib.character.Humanoid.WalkSpeed = FakeLagSpeed3.Value
	end
	FakeLag = vape.Categories.Utility:CreateModule({
		Name = "FakeLag",
        Tooltip = "Makes people think you're laggy",
		Function = function(callback)
			if callback then
				task.spawn(function()
					repeat task.wait()
						if FakeLagUsage.Value == "Blatant" then
							entitylib.character.HumanoidRootPart.Anchored = true
							task.wait(FakeLagDelay1.Value / 10)
							entitylib.character.HumanoidRootPart.Anchored = false
							ChangeSpeeds()
							task.wait(FakeLagDelay2.Value/10)
						elseif FakeLagUsage.Value == "Legit" then
							entitylib.character.HumanoidRootPart.Anchored = true
							task.wait(FakeLagDelay1.Value / 10 + FakeLagDelayLegit.Value)
							entitylib.character.HumanoidRootPart.Anchored = false
							ChangeSpeeds()
							task.wait(FakeLagDelay2.Value / 10 + FakeLagDelayLegit.Value)
						end
					until not FakeLag.Enabled
				end)
			else
				if entitylib.character.HumanoidRootPart.Anchored then
					entitylib.character.HumanoidRootPart.Anchored = false
				end
			end
		end,
		ExtraText = function()
			return FakeLagUsage.Value
		end
	})
FakeLagUsage = FakeLag:CreateDropdown({
    Name = "Mode",
    List = {
        "Blatant",
        "Legit"
    },
    Tooltip = "FakeLag Mode",
    Function = function() end
})

FakeLagSpeed = FakeLag:CreateToggle({
    Name = "Speed",
    Default = false,
    Tooltip = "Changes speed",
    Function = function() end
})

FakeLagDelay1 = FakeLag:CreateSlider({
    Name = "Anchored Delay",
    Min = 0,
    Max = 20,
    Tooltip = "Anchored Delay Value",
    Function = function() end,
    Default = 2
})

FakeLagDelay2 = FakeLag:CreateSlider({
    Name = "Unanchored Delay",
    Min = 0,
    Max = 20,
    Tooltip = "Not Anchored Delay Value",
    Function = function() end,
    Default = 7
})

FakeLagDelayLegit = FakeLag:CreateSlider({
    Name = "Legit",
    Min = 1,
    Max = 10,
    Tooltip = "Legit Time",
    Function = function() end,
    Default = 3
})

FakeLagSpeed1 = FakeLag:CreateSlider({
    Name = "Speed 1",
    Min = 1,
    Max = 22,
    Tooltip = "Speed 1 Value",
    Function = function() end,
    Default = 22
})

FakeLagSpeed2 = FakeLag:CreateSlider({
    Name = "Speed 2",
    Min = 1,
    Max = 20,
    Tooltip = "Speed 2 Value",
    Function = function() end,
    Default = 18
})

FakeLagSpeed3 = FakeLag:CreateSlider({
    Name = "Speed 3",
    Min = 1,
    Max = 20,
    Tooltip = "Speed 3 Value",
    Function = function() end,
    Default = 20
})

FakeLagSpeed4 = FakeLag:CreateSlider({
    Name = "Speed Delay 1",
    Min = 1,
    Max = 3,
    Tooltip = "Speed Delay 1 Value",
    Function = function() end,
    Default = 2.7
})

FakeLagSpeed5 = FakeLag:CreateSlider({
    Name = "Speed Delay 2",
    Min = 1,
    Max = 3,
    Tooltip = "Speed Delay 2 Value",
    Function = function() end,
    Default = 1.5
})
end)
run(function()
    local AutoCorrect
    local blacklistedwords = {
        'hack',
        'hax',
        'cheat'
    }

    local function getWord(msg)
		msg = string.lower(tostring(msg))
        for i,v in blacklistedwords do
            if string.find(tostring(msg), v) then
                return true
            end
        end

        return false
    end

    local function sendmsg(msg)
        if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(msg)
        else
            replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(msg, 'All')
        end
    end

    AutoCorrect = vape.Categories.Utility:CreateModule({
        Name = 'AutoCorrect',
        Function = function(callback)
            if callback then
                for i,v in playersService:GetPlayers() do
                    if v ~= lplr then
                        AutoCorrect:Clean(v.Chatted:Connect(function(msg)
                            if getWord(msg) then
                                sendmsg('Actually, '..v.Name..' it\'s called "Exploiters/Exploits".')
                            end
                        end))
                    end
                end

				AutoCorrect:Clean(playersService.PlayerAdded:Connect(function(plr)
                    AutoCorrect:Clean(plr.Chatted:Connect(function(msg)
						if getWord(msg) then
							sendmsg('Actually, '..plr.Name..' it\'s called "Exploiters/Exploits".')
						end
					end))
                end))
            end
        end,
        Tooltip = 'Automatically corrects someone for using the incorrect terminology.'
    })
end)

run(function()
    local Lighting = game:GetService("Lighting")

    -- Store effects to remove later
    local shaderEffects = {}

    -- Helper to create & apply an effect
    local function addEffect(className, props)
        local effect = Instance.new(className)
        for prop, val in pairs(props) do
            effect[prop] = val
        end
        effect.Name = "CloudWare_" .. className
        effect.Parent = Lighting
        table.insert(shaderEffects, effect)
    end

    vape.Categories.Render:CreateModule({
        Name = "Realistic Shader",
        Tooltip = "Simulates RTX-style visuals using lighting and post effects.",
        Function = function(enabled)
            if enabled then
                -- Darker, richer world lighting
                Lighting.Brightness = 1.2
                Lighting.OutdoorAmbient = Color3.fromRGB(45, 45, 55)
                Lighting.Ambient = Color3.fromRGB(22, 22, 30)
                Lighting.EnvironmentDiffuseScale = 0.4
                Lighting.EnvironmentSpecularScale = 0.6
                Lighting.GlobalShadows = true
                Lighting.ClockTime = 17  -- dusk

                -- Simulated RTX-style post-processing
                addEffect("BloomEffect", {
                    Intensity = 0.6,
                    Threshold = 0.8,
                    Size = 56
                })

                addEffect("ColorCorrectionEffect", {
                    Brightness = 0.3,
                    Contrast = 0.35,
                    Saturation = 0.15,
                    TintColor = Color3.fromRGB(200, 200, 230)
                })

                addEffect("SunRaysEffect", {
                    Intensity = 0.12,
                    Spread = 0.25
                })

                addEffect("DepthOfFieldEffect", {
                    FarIntensity = 0.3,
                    FocusDistance = 25,
                    InFocusRadius = 15,
                    NearIntensity = 0.2
                })

                addEffect("BlurEffect", {
                    Size = 1
                })
            else
                -- Restore lighting defaults (optional, tweak as needed)
                Lighting.Brightness = 2
                Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
                Lighting.Ambient = Color3.fromRGB(127, 127, 127)
                Lighting.EnvironmentDiffuseScale = 1
                Lighting.EnvironmentSpecularScale = 1
                Lighting.ClockTime = 14

                -- Remove shader effects
                for _, effect in pairs(shaderEffects) do
                    if effect and effect.Parent then
                        effect:Destroy()
                    end
                end
                shaderEffects = {}
            end
        end
    })
end)	
run(function()
	local Ambience2 = vape.Categories.Render:CreateModule({
		Name = "Ambience 2",
		Function = function(callback)
			local lighting = game:GetService("Lighting")
			if callback then
				local sky = Instance.new("Sky")
				sky.Name = "Ambience2_Sky"
				local id = "rbxassetid://121826915456627"
				sky.SkyboxBk = id
				sky.SkyboxDn = id
				sky.SkyboxFt = id
				sky.SkyboxLf = id
				sky.SkyboxRt = id
				sky.SkyboxUp = id
				sky.Parent = lighting
			else
				local sky = lighting:FindFirstChild("Ambience2_Sky")
				if sky then sky:Destroy() end
			end
		end,
		Tooltip = "Ambience 2"
	})
end)
run(function()
	local Ambience1 = vape.Categories.Render:CreateModule({
		Name = "Ambience 1",
		Function = function(callback)
			local lighting = game:GetService("Lighting")
			if callback then
				local sky = Instance.new("Sky")
				sky.Name = "Ambience1_Sky"
				local id = "rbxassetid://122785120445164"
				sky.SkyboxBk = id
				sky.SkyboxDn = id
				sky.SkyboxFt = id
				sky.SkyboxLf = id
				sky.SkyboxRt = id
				sky.SkyboxUp = id
				sky.Parent = lighting
			else
				local sky = lighting:FindFirstChild("Ambience1_Sky")
				if sky then sky:Destroy() end
			end
		end,
		Tooltip = "Ambience 1"
	})
end)
run(function()
    local Skyboxes
    local SkyboxList
    local lighting = game:GetService("Lighting")

    local oldSky = lighting:FindFirstChildOfClass("Sky")
    local storedSkyProps = {}

    if oldSky then
        for _, prop in ipairs({
            "SkyboxBk",
            "SkyboxDn",
            "SkyboxFt",
            "SkyboxLf",
            "SkyboxRt",
            "SkyboxUp"
        }) do
            storedSkyProps[prop] = oldSky[prop]
        end
    end

    local skies = {
        ["orange"] = {
            AssetId = "rbxassetid://18359130164"
        },

        ["E-Girl Sky"] = {
            SkyboxLf = "rbxassetid://113265956567183",
            SkyboxRt = "rbxassetid://131435765577828",
            SkyboxDn = "rbxassetid://11802584423",
            SkyboxFt = "rbxassetid://18428890211",
            SkyboxUp = "rbxassetid://16114656175",
            SkyboxBk = "rbxassetid://13327486722"
        },

        ["Xylex Sky"] = {
            SkyboxBk = "rbxassetid://13953598788",
            SkyboxDn = "rbxassetid://13953598788",
            SkyboxFt = "rbxassetid://13953598788",
            SkyboxLf = "rbxassetid://13953598788",
            SkyboxRt = "rbxassetid://13953598788",
            SkyboxUp = "rbxassetid://13953598788"
        }
    }

    local function applySky(name)
        local skyData = skies[name]
        if not skyData then
            vape:CreateNotification("Skyboxes", "Unknown skybox: "..tostring(name), 5, "warning")
            return
        end

        if skyData.AssetId then
            local success, objects = pcall(game.GetObjects, game, skyData.AssetId)
            if not success or type(objects) ~= "table" then
                vape:CreateNotification("Skyboxes", "Failed to load the Orange skybox asset.", 5, "warning")
                return
            end

            local sourceSky
            for _, object in objects do
                if object:IsA("Sky") then
                    sourceSky = object
                    break
                end
                sourceSky = object:FindFirstChildWhichIsA("Sky", true)
                if sourceSky then break end
            end

            if not sourceSky then
                for _, object in objects do
                    object:Destroy()
                end
                vape:CreateNotification("Skyboxes", "Orange asset does not contain a Sky object.", 5, "warning")
                return
            end

            local faceProperties = {"SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp"}
            for _, prop in faceProperties do
                skyData[prop] = sourceSky[prop]
            end
            for _, object in objects do
                object:Destroy()
            end
        end

        local sky = lighting:FindFirstChildOfClass("Sky")
        if not sky then
            sky = Instance.new("Sky")
            sky.Parent = lighting
        end

        for prop, value in pairs(skyData) do
            if prop ~= "AssetId" then
                sky[prop] = value
            end
        end
    end

    local function restoreSky()
        local sky = lighting:FindFirstChildOfClass("Sky")
        if sky and next(storedSkyProps) then
            for prop, val in pairs(storedSkyProps) do
                sky[prop] = val
            end
        end
    end

    Skyboxes = vape.Categories.Render:CreateModule({
        Name = "Skyboxes",
        Tooltip = "Custom skyboxes",
        Function = function(enabled)
            if enabled then
                applySky(SkyboxList.Value)
            else
                restoreSky()
            end
        end
    })

    SkyboxList = Skyboxes:CreateDropdown({
        Name = "Skybox",
        List = {"orange", "E-Girl Sky", "Xylex Sky"},
        Default = "orange",
        Function = function(val)
            if Skyboxes.Enabled then
                applySky(val)
            end
        end
    })
end)
run(function()
    local texture_pack: table = {["Enabled"] = false};
    local texture_pack_color: table = {["Hue"] = 0, ["Sat"] = 0, ["Value"] = 0};
    local texture_pack_m: table = {};
    texture_pack = vape.Categories.Render:CreateModule({
        ["Name"] ='TexturePack',
        ["HoverText"] = 'Customizes the texture pack.',
        ["Function"] = function(callback: boolean): void
            if callback then
                if texture_pack_m["Value"] == 'Velocity' then
					task.spawn(function()
						local Players: Players = game:GetService("Players")
						local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
						local Workspace: Workspace = game:GetService("Workspace")
						local objs: any = game:GetObjects("rbxassetid://13988978091")
						local import: any = objs[1]
						import.Parent = game:GetService("ReplicatedStorage")
						local index: table? = {
							{
								name = "wood_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
								model = import:WaitForChild("Wood_Sword"),
							},
							{
								name = "stone_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
								model = import:WaitForChild("Stone_Sword"),
							},
							{
								name = "iron_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
								model = import:WaitForChild("Iron_Sword"),
							},
							{
								name = "diamond_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
								model = import:WaitForChild("Diamond_Sword"),
							},
							{
								name = "emerald_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
								model = import:WaitForChild("Emerald_Sword"),
							},
							{
								name = "wood_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-190), math.rad(-95)),
								model = import:WaitForChild("Wood_Pickaxe"),
							},
							{
								name = "stone_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-190), math.rad(-95)),
								model = import:WaitForChild("Stone_Pickaxe"),
							},
							{
								name = "iron_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-190), math.rad(-95)),
								model = import:WaitForChild("Iron_Pickaxe"),
							},
							{
								name = "diamond_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(80), math.rad(-95)),
								model = import:WaitForChild("Diamond_Pickaxe"),
							},
							{
								name = "wood_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
								model = import:WaitForChild("Wood_Axe"),
							},
							{
								name = "stone_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
								model = import:WaitForChild("Stone_Axe"),
							},
							{
								name = "iron_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
								model = import:WaitForChild("Iron_Axe"),
							},
							{
								name = "diamond_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(-95)),
								model = import:WaitForChild("Diamond_Axe"),
							},
						}
						local func = Workspace.Camera.Viewmodel.ChildAdded:Connect(function(tool)
							if not tool:IsA("Accessory") then
								return
							end
							for _, v in next, index do
								if v.name == tool.Name then
									for _, part in next, tool:GetDescendants() do
										if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then
											part.Transparency = 1
										end
									end
									local model = v.model:Clone()
									model.CFrame = tool.Handle.CFrame * v.offset
									model.CFrame = model.CFrame * CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
									model.Parent = tool
									local weld = Instance.new("WeldConstraint")
									weld.Part0 = model
									weld.Part1 = tool.Handle
									weld.Parent = model
									local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)
									for _, part in ipairs(tool2:GetDescendants()) do
										if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then
											part.Transparency = 1
											if part.Name == "Handle" then
												part.Transparency = 0
											end
										end
									end
								end
							end
						end)
					end)
                elseif texture_pack_m["Value"] == 'Aquarium' then
					task.spawn(function()
						local Players = game:GetService("Players")
						local ReplicatedStorage = game:GetService("ReplicatedStorage")
						local Workspace = game:GetService("Workspace")
						local objs = game:GetObjects("rbxassetid://14217388022")
						local import = objs[1]
						import.Parent = game:GetService("ReplicatedStorage")
						local index = {
						
							{
								name = "wood_sword",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
								model = import:WaitForChild("Wood_Sword"),
							},
							
							{
								name = "stone_sword",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
								model = import:WaitForChild("Stone_Sword"),
							},
							
							{
								name = "iron_sword",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
								model = import:WaitForChild("Iron_Sword"),
							},
							
							{
								name = "diamond_sword",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
								model = import:WaitForChild("Diamond_Sword"),
							},
							
							{
								name = "emerald_sword",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
								model = import:WaitForChild("Diamond_Sword"),
							},
							
							{
								name = "Rageblade",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
								model = import:WaitForChild("Diamond_Sword"),
							},
						}
						local func = Workspace:WaitForChild("Camera").Viewmodel.ChildAdded:Connect(function(tool)
							if(not tool:IsA("Accessory")) then return end
							for i,v in pairs(index) do
								if(v.name == tool.Name) then
									for i,v in pairs(tool:GetDescendants()) do
										if(v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation")) then
											v.Transparency = 1
										end
									end
									local model = v.model:Clone()
									model.CFrame = tool:WaitForChild("Handle").CFrame * v.offset
									model.CFrame *= CFrame.Angles(math.rad(0),math.rad(-50),math.rad(0))
									model.Parent = tool
									local weld = Instance.new("WeldConstraint",model)
									weld.Part0 = model
									weld.Part1 = tool:WaitForChild("Handle")
									local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)
									for i,v in pairs(tool2:GetDescendants()) do
										if(v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation")) then
											v.Transparency = 1
										end
									end
									local model2 = v.model:Clone()
									model2.Anchored = false
									model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
									model2.CFrame *= CFrame.Angles(math.rad(0),math.rad(-50),math.rad(0))
									model2.CFrame *= CFrame.new(0.4,0,-.9)
									model2.Parent = tool2
									local weld2 = Instance.new("WeldConstraint",model)
									weld2.Part0 = model2
									weld2.Part1 = tool2:WaitForChild("Handle")
								end
							end
						end)
					end)
                elseif texture_pack_m["Value"] == 'Ocean' then
					task.spawn(function()
						local Players = game:GetService("Players")
						local ReplicatedStorage = game:GetService("ReplicatedStorage")
						local Workspace = game:GetService("Workspace")
						local objs = game:GetObjects("rbxassetid://14356045010")
						local import = objs[1]
						import.Parent = game:GetService("ReplicatedStorage")
						index = {
							{
								name = "wood_sword",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
								model = import:WaitForChild("Wood_Sword"),
							},
							{
								name = "stone_sword",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
								model = import:WaitForChild("Stone_Sword"),
							},
							{
								name = "iron_sword",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
								model = import:WaitForChild("Iron_Sword"),
							},
							{
								name = "diamond_sword",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
								model = import:WaitForChild("Diamond_Sword"),
							},
							{
								name = "emerald_sword",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(-90)),
								model = import:WaitForChild("Emerald_Sword"),
							}, 
							{
								name = "rageblade",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(90)),
								model = import:WaitForChild("Rageblade"),
							}, 
							{
								name = "fireball",
										offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
								model = import:WaitForChild("Fireball"),
							}, 
							{
								name = "telepearl",
										offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
								model = import:WaitForChild("Telepearl"),
							}, 
							{
								name = "wood_bow",
								offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
								model = import:WaitForChild("Bow"),
							},
							{
								name = "wood_crossbow",
								offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
								model = import:WaitForChild("Crossbow"),
							},
							{
								name = "tactical_crossbow",
								offset = CFrame.Angles(math.rad(0), math.rad(180), math.rad(-90)),
								model = import:WaitForChild("Crossbow"),
							},
								{
								name = "wood_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
								model = import:WaitForChild("Wood_Pickaxe"),
							},
							{
								name = "stone_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
								model = import:WaitForChild("Stone_Pickaxe"),
							},
							{
								name = "iron_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
								model = import:WaitForChild("Iron_Pickaxe"),
							},
							{
								name = "diamond_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(80), math.rad(-95)),
								model = import:WaitForChild("Diamond_Pickaxe"),
							},
						{
									
								name = "wood_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
								model = import:WaitForChild("Wood_Axe"),
							},
							{
								name = "stone_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
								model = import:WaitForChild("Stone_Axe"),
							},
							{
								name = "iron_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
								model = import:WaitForChild("Iron_Axe"),
							},
							{
								name = "diamond_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-95)),
								model = import:WaitForChild("Diamond_Axe"),
							},
						
						
						
						}
						local func = Workspace:WaitForChild("Camera").Viewmodel.ChildAdded:Connect(function(tool)
							if(not tool:IsA("Accessory")) then return end
							for i,v in pairs(index) do
								if(v.name == tool.Name) then
									for i,v in pairs(tool:GetDescendants()) do
										if(v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation")) then
											v.Transparency = 1
										end
									end
									local model = v.model:Clone()
									model.CFrame = tool:WaitForChild("Handle").CFrame * v.offset
									model.CFrame *= CFrame.Angles(math.rad(0),math.rad(-50),math.rad(0))
									model.Parent = tool
									local weld = Instance.new("WeldConstraint",model)
									weld.Part0 = model
									weld.Part1 = tool:WaitForChild("Handle")
									local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)
									for i,v in pairs(tool2:GetDescendants()) do
										if(v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation")) then
											v.Transparency = 1
										end
									end
									local model2 = v.model:Clone()
									model2.Anchored = false
									model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
									model2.CFrame *= CFrame.Angles(math.rad(0),math.rad(-50),math.rad(0))
									model2.CFrame *= CFrame.new(.7,0,-.8)
									model2.Parent = tool2
									local weld2 = Instance.new("WeldConstraint",model)
									weld2.Part0 = model2
									weld2.Part1 = tool2:WaitForChild("Handle")
								end
							end
						end)
					end)
                elseif texture_pack_m["Value"] == 'Animated' then
                    task.spawn(function()
                        workspace:WaitForChild("Camera").Viewmodel.ChildAdded:Connect(function(tool)
                            if not tool:IsA("Accessory") then 
                                return 
                            end
                            local handle: any = tool:FindFirstChild("Handle")
                            if handle then
                                if string.find(tool.Name:lower(), 'sword') then
                                    handle.Material = Enum.Material.ForceField
                                    handle.MeshId = "rbxassetid://13471207377"
                                    handle.BrickColor = BrickColor.new("Hot pink")
                                    local outline: Highlight = Instance.new('Highlight')
                                    outline.Adornee = handle 
                                    outline.FillTransparency = 0.5
                                    outline.FillColor = Color3.fromRGB(221, 193, 255) 
                                    outline.OutlineTransparency = 0.2
                                    outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                                    outline.Parent = handle
                                    local highlight: Highlight = Instance.new('Highlight')
                                    highlight.Adornee = handle 
                                    highlight.FillTransparency = 0.5
                                    highlight.FillColor = Color3.fromHSV(texture_pack_color["Hue"], texture_pack_color["Sat"], texture_pack_color["Value"])
                                    highlight.OutlineTransparency = 0.2
                                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                                    highlight.Parent = handle
                                end
                            end
                        end)
                    end)
				elseif texture_pack_m["Value"] == 'DemonSlayer' then
					task.spawn(function()
						local Players = game:GetService("Players")
						local ReplicatedStorage = game:GetService("ReplicatedStorage")
						local Workspace = game:GetService("Workspace")
						local objs = game:GetObjects("rbxassetid://14241215869")
						local import = objs[1]
						import.Parent = ReplicatedStorage
						local index = {
							{
								name = "wood_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
								model = import:WaitForChild("Wood_Sword"),
							},	
							{
								name = "stone_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
								model = import:WaitForChild("Stone_Sword"),
							},
							{
								name = "iron_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
								model = import:WaitForChild("Iron_Sword"),
							},
							{
								name = "diamond_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
								model = import:WaitForChild("Diamond_Sword"),
							},
							{
								name = "emerald_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
								model = import:WaitForChild("Emerald_Sword"),
							},
							{
								name = "wood_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
								model = import:WaitForChild("Wood_Pickaxe"),
							},
							{
								name = "stone_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
								model = import:WaitForChild("Stone_Pickaxe"),
							},
							{
								name = "iron_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
								model = import:WaitForChild("Iron_Pickaxe"),
							},
							{
								name = "diamond_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(90), math.rad(-95)),
								model = import:WaitForChild("Diamond_Pickaxe"),
							},	
							{
								name = "fireball",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
								model = import:WaitForChild("Fireball"),
							},	
							{
								name = "telepearl",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
								model = import:WaitForChild("Telepearl"),
							},
							{
								name = "diamond",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(-90)),
								model = import:WaitForChild("Diamond"),
							},
							{
								name = "iron",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
								model = import:WaitForChild("Iron"),
							},
							{
								name = "gold",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
								model = import:WaitForChild("Gold"),
							},
							{
								name = "emerald",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(-90)),
								model = import:WaitForChild("Emerald"),
							},
							{
								name = "wood_bow",
								offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
								model = import:WaitForChild("Bow"),
							},
							{
								name = "wood_crossbow",
								offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
								model = import:WaitForChild("Bow"),
							},
							{
								name = "tactical_crossbow",
								offset = CFrame.Angles(math.rad(0), math.rad(180), math.rad(-90)),
								model = import:WaitForChild("Bow"),
							},
							{
								name = "wood_dao",
								offset = CFrame.Angles(math.rad(0), math.rad(89), math.rad(-90)),
								model = import:WaitForChild("Wood_Sword"),
							},
							{
								name = "stone_dao",
								offset = CFrame.Angles(math.rad(0), math.rad(89), math.rad(-90)),
								model = import:WaitForChild("Stone_Sword"),
							},
							{
								name = "iron_dao",
								offset = CFrame.Angles(math.rad(0), math.rad(89), math.rad(-90)),
								model = import:WaitForChild("Iron_Sword"),
							},
							{
								name = "diamond_dao",
								offset = CFrame.Angles(math.rad(0), math.rad(89), math.rad(-90)),
								model = import:WaitForChild("Diamond_Sword"),
							},
						}
						local func = Workspace.Camera.Viewmodel.ChildAdded:Connect(function(tool)	
							if not tool:IsA("Accessory") then return end	
							for _, v in ipairs(index) do	
								if v.name == tool.Name then		
									for _, part in ipairs(tool:GetDescendants()) do
										if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then				
											part.Transparency = 1
										end			
									end		
									local model = v.model:Clone()
									model.CFrame = tool:WaitForChild("Handle").CFrame * v.offset
									model.CFrame *= CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
									model.Parent = tool			
									local weld = Instance.new("WeldConstraint", model)
									weld.Part0 = model
									weld.Part1 = tool:WaitForChild("Handle")			
									local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)			
									for _, part in ipairs(tool2:GetDescendants()) do
										if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then				
											part.Transparency = 1				
										end			
									end			
									local model2 = v.model:Clone()
									model2.Anchored = false
									model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
									model2.CFrame *= CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
									if v.name:match("rageblade") then
										model2.CFrame *= CFrame.new(0.7, 0, -.7)                           
									elseif v.name:match("sword") or v.name:match("blade") then
										model2.CFrame *= CFrame.new(.2, 0, -.8)
									elseif v.name:match("dao") then
										model2.CFrame *= CFrame.new(.7, 0, -1.3)
									elseif v.name:match("axe") and not v.name:match("pickaxe") and v.name:match("diamond") then
										model2.CFrame *= CFrame.new(.08, 0, -1.1) - Vector3.new(0, 0, -1.1)
									elseif v.name:match("axe") and not v.name:match("pickaxe") and not v.name:match("diamond") then
										model2.CFrame *= CFrame.new(-.2, 0, -2.4) + Vector3.new(0, 0, 2.12)
									elseif v.name:match("diamond_pickaxe") then
										model2.CFrame *= CFrame.new(.2, 0, -.26)
									elseif v.name:match("iron") and not v.name:match("iron_pickaxe") then
										model2.CFrame *= CFrame.new(0, -.24, 0)
									elseif v.name:match("gold") then
										model2.CFrame *= CFrame.new(0, .03, 0)
									elseif v.name:match("diamond") or v.name:match("emerald") then
										model2.CFrame *= CFrame.new(0, -.03, 0)
									elseif v.name:match("telepearl") then
										model2.CFrame *= CFrame.new(.1, 0, .1)
									elseif v.name:match("fireball") then
										model2.CFrame *= CFrame.new(.28, .1, 0)
									elseif v.name:match("bow") and not v.name:match("crossbow") then
										model2.CFrame *= CFrame.new(-.2, .1, -.05)
									elseif v.name:match("wood_crossbow") and not v.name:match("tactical_crossbow") then
										model2.CFrame *= CFrame.new(-.5, 0, .05)
									elseif v.name:match("tactical_crossbow") and not v.name:match("wood_crossbow") then
										model2.CFrame *= CFrame.new(-.35, 0, -1.2)
									else
										model2.CFrame *= CFrame.new(.0, 0, -.06)
									end
									model2.Parent = tool2
									local weld2 = Instance.new("WeldConstraint", model)
									weld2.Part0 = model2
									weld2.Part1 = tool2:WaitForChild("Handle")
								end
							end
						end)
					end)
				elseif texture_pack_m["Value"] == 'Glizzy' then
					task.spawn(function()
						local Players = game:GetService("Players")
						local ReplicatedStorage = game:GetService("ReplicatedStorage")
						local Workspace = game:GetService("Workspace")
						local objs = game:GetObjects("rbxassetid://13804645310")
						local import = objs[1]
						import.Parent = game:GetService("ReplicatedStorage")
						
						local index = {
							{
								name = "wood_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
								model = import:WaitForChild("Wood_Sword"),
							},
							{
								name = "stone_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
								model = import:WaitForChild("Stone_Sword"),
							},
							{
								name = "iron_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
								model = import:WaitForChild("Iron_Sword"),
							},
							{
								name = "diamond_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
								model = import:WaitForChild("Diamond_Sword"),
							},
							{
								name = "emerald_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90)),
								model = import:WaitForChild("Emerald_Sword"),
							},
							{
								name = "rageblade",
								offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-270)),
								model = import:WaitForChild("Rageblade"),
							},
						}
						
						local func = Workspace:WaitForChild("Camera").Viewmodel.ChildAdded:Connect(function(tool)
							if not tool:IsA("Accessory") then return end
							for _,v in pairs(index) do
								if v.name == tool.Name then
									for _,v in pairs(tool:GetDescendants()) do
										if v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation") then
											v.Transparency = 1
										end
									end
									local model = v.model:Clone()
									model.CFrame = tool:WaitForChild("Handle").CFrame * v.offset
									model.CFrame = model.CFrame * CFrame.Angles(math.rad(0), math.rad(100), math.rad(0))
									model.Parent = tool
									local weld = Instance.new("WeldConstraint", model)
									weld.Part0 = model
									weld.Part1 = tool:WaitForChild("Handle")
									
									local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)
									for _,v in pairs(tool2:GetDescendants()) do
										if v:IsA("Part") or v:IsA("MeshPart") or v:IsA("UnionOperation") then
											v.Transparency = 1
										end
									end
									local model2 = v.model:Clone()
									model2.Anchored = false
									model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
									model2.CFrame = model2.CFrame * CFrame.Angles(math.rad(0), math.rad(-105), math.rad(0))
									model2.CFrame = model2.CFrame * CFrame.new(-0.4, 0, -0.10)
									model2.Parent = tool2
									local weld2 = Instance.new("WeldConstraint", model2)
									weld2.Part0 = model2
									weld2.Part1 = tool2:WaitForChild("Handle")
								end
							end
						end)					
					end)
				elseif texture_pack_m["Value"] == 'FirstPack' then
					task.spawn(function()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/TexturePacks/main/Pack%231"))()  
					end)
				elseif texture_pack_m["Value"] == 'SecondPack' then
					task.spawn(function()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/TexturePacks/main/Pack%232"))()  
					end)
				elseif texture_pack_m["Value"] == 'ThirdPack' then
					task.spawn(function()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/Modules/main/TexturePack"))()  
					end)
				elseif texture_pack_m["Value"] == 'FourthPack' then
					task.spawn(function()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/TexturePacks/main/Pack%234"))()  
					end)
				elseif texture_pack_m["Value"] == 'FifthPack' then
					task.spawn(function()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/TexturePacks/main/Pack%235"))()  
					end)
				elseif texture_pack_m["Value"] == 'SixthPack' then
					task.spawn(function()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/TexturePacks/main/Pack%236"))()  
					end)
				elseif texture_pack_m["Value"] == 'SeventhPack' then
					task.spawn(function()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/TexturePacks/main/Pack%237"))()  
					end)
				elseif texture_pack_m["Value"] == 'EighthPack' then
					task.spawn(function()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/TexturePacks/main/1024xPack"))()  
					end)
				elseif texture_pack_m["Value"] == 'EgirlPack' then
					task.spawn(function() 	
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/TexturePacks/main/E-Girl"))()  		             
					end)
				elseif texture_pack_m["Value"] == 'CottonCandy' then
					task.spawn(function() 
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/TexturePacks/main/CottonCandy256x"))()           
					end)
				elseif texture_pack_m["Value"] == 'PrivatePack' then
					task.spawn(function()
						local Players = game:GetService("Players")
						local ReplicatedStorage = game:GetService("ReplicatedStorage")
						local Workspace = game:GetService("Workspace")
						local objs = game:GetObjects("rbxassetid://14161283331")
						local import = objs[1]
						import.Parent = ReplicatedStorage
						local index = {
							{
								name = "wood_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
								model = import:WaitForChild("Wood_Sword"),
							},	
							{
								name = "stone_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
								model = import:WaitForChild("Stone_Sword"),
							},
							{
								name = "iron_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
								model = import:WaitForChild("Iron_Sword"),
							},
							{
								name = "diamond_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
								model = import:WaitForChild("Diamond_Sword"),
							},
							{
								name = "emerald_sword",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-90)),
								model = import:WaitForChild("Emerald_Sword"),
							},
							{
								name = "rageblade",
								offset = CFrame.Angles(math.rad(0),math.rad(-100),math.rad(90)),
								model = import:WaitForChild("Rageblade"),
							}, 
							{
								name = "wood_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
								model = import:WaitForChild("Wood_Pickaxe"),
							},
							{
								name = "stone_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-180), math.rad(-95)),
								model = import:WaitForChild("Stone_Pickaxe"),
							},
							{
								name = "iron_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(-18033), math.rad(-95)),
								model = import:WaitForChild("Iron_Pickaxe"),
							},
							{
								name = "diamond_pickaxe",
								offset = CFrame.Angles(math.rad(0), math.rad(80), math.rad(-95)),
								model = import:WaitForChild("Diamond_Pickaxe"),
							},	
							{
								name = "wood_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
								model = import:WaitForChild("Wood_Axe"),
							},	
							{
								name = "stone_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
								model = import:WaitForChild("Stone_Axe"),
							},	
							{
								name = "iron_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95)),
								model = import:WaitForChild("Iron_Axe"),
							},	
							{
								name = "diamond_axe",
								offset = CFrame.Angles(math.rad(0), math.rad(-89), math.rad(-95)),
								model = import:WaitForChild("Diamond_Axe"),
							},	
							{
								name = "fireball",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
								model = import:WaitForChild("Fireball"),
							},	
							{
								name = "telepearl",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
								model = import:WaitForChild("Telepearl"),
							},
							{
								name = "diamond",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
								model = import:WaitForChild("Diamond"),
							},
							{
								name = "iron",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
								model = import:WaitForChild("Iron"),
							},
							{
								name = "gold",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
								model = import:WaitForChild("Gold"),
							},
							{
								name = "emerald",
								offset = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
								model = import:WaitForChild("Emerald"),
							},
							{
								name = "wood_bow",
								offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
								model = import:WaitForChild("Bow"),
							},
							{
								name = "wood_crossbow",
								offset = CFrame.Angles(math.rad(0), math.rad(0), math.rad(90)),
								model = import:WaitForChild("Bow"),
							},
							{
								name = "tactical_crossbow",
								offset = CFrame.Angles(math.rad(0), math.rad(180), math.rad(-90)),
								model = import:WaitForChild("Bow"),
							},
						}
						local func = Workspace.Camera.Viewmodel.ChildAdded:Connect(function(tool)	
							if not tool:IsA("Accessory") then return end	
							for _, v in ipairs(index) do	
								if v.name == tool.Name then		
									for _, part in ipairs(tool:GetDescendants()) do
										if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then				
											part.Transparency = 1
										end			
									end		
									local model = v.model:Clone()
									model.CFrame = tool:WaitForChild("Handle").CFrame * v.offset
									model.CFrame *= CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
									model.Parent = tool			
									local weld = Instance.new("WeldConstraint", model)
									weld.Part0 = model
									weld.Part1 = tool:WaitForChild("Handle")			
									local tool2 = Players.LocalPlayer.Character:WaitForChild(tool.Name)			
									for _, part in ipairs(tool2:GetDescendants()) do
										if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then				
											part.Transparency = 1				
										end			
									end			
									local model2 = v.model:Clone()
									model2.Anchored = false
									model2.CFrame = tool2:WaitForChild("Handle").CFrame * v.offset
									model2.CFrame *= CFrame.Angles(math.rad(0), math.rad(-50), math.rad(0))
									if v.name:match("rageblade") then
										model2.CFrame *= CFrame.new(0.7, 0, -1)                           
									elseif v.name:match("sword") or v.name:match("blade") then
										model2.CFrame *= CFrame.new(.6, 0, -1.1) - Vector3.new(0, 0, -.3)
									elseif v.name:match("axe") and not v.name:match("pickaxe") and v.name:match("diamond") then
										model2.CFrame *= CFrame.new(.08, 0, -1.1) - Vector3.new(0, 0, -1.1)
									elseif v.name:match("axe") and not v.name:match("pickaxe") and not v.name:match("diamond") then
										model2.CFrame *= CFrame.new(-.2, 0, -2.4) + Vector3.new(0, 0, 2.12)
									elseif v.name:match("iron") then
										model2.CFrame *= CFrame.new(0, -.24, 0)
									elseif v.name:match("gold") then
										model2.CFrame *= CFrame.new(0, .03, 0)
									elseif v.name:match("diamond") then
										model2.CFrame *= CFrame.new(0, .027, 0)
									elseif v.name:match("emerald") then
										model2.CFrame *= CFrame.new(0, .001, 0)
									elseif v.name:match("telepearl") then
										model2.CFrame *= CFrame.new(.1, 0, .1)
									elseif v.name:match("fireball") then
										model2.CFrame *= CFrame.new(.28, .1, 0)
									elseif v.name:match("bow") and not v.name:match("crossbow") then
										model2.CFrame *= CFrame.new(-.29, .1, -.2)
									elseif v.name:match("wood_crossbow") and not v.name:match("tactical_crossbow") then
										model2.CFrame *= CFrame.new(-.6, 0, 0)
									elseif v.name:match("tactical_crossbow") and not v.name:match("wood_crossbow") then
										model2.CFrame *= CFrame.new(-.5, 0, -1.2)
									else
										model2.CFrame *= CFrame.new(.2, 0, -.2)
									end
									model2.Parent = tool2
									local weld2 = Instance.new("WeldConstraint", model)
									weld2.Part0 = model2
									weld2.Part1 = tool2:WaitForChild("Handle")
								end
							end
						end)            
					end)
				elseif texture_pack_m["Value"] == 'FirstHighResPack' then	
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/TexturePacks/main/512xPack"))()   
					end)
				elseif texture_pack_m["Value"] == 'SecondHighResPack' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/SnoopyOwner/TexturePacks/main/1024xPack"))()   
					end)
				elseif texture_pack_m["Value"] == 'FatCat' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/"..Pack.Value..".lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Simply' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Simply.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'VioletsDreams' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/VioletsDreams.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Enlightened' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Enlightened.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Onyx' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Onyx.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Fury' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Fury.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Wichtiger' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Wichtiger.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Makima' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Makima.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Marin-Kitsawaba' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Marin-Kitsawaba.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Prime' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Prime.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Vile' then	
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Vile.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Devourer' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Devourer.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Acidic' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Acidic.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Moon4Real' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Moon4Real.lua"))()
					end)
				elseif texture_pack_m["Value"] == 'Nebula' then
					task.spawn(function()
						task.wait()
						loadstring(game:HttpGet("https://raw.githubusercontent.com/qwertyui-is-back/TexturePacks/refs/heads/main/Nebula.lua"))()
					end)
				else
					local connect: any;
					local pack: any = game:GetObjects("rbxassetid://14027120450");
					local txtpack: any = unpack(pack)
					txtpack.Parent = game:GetService("ReplicatedStorage")
					connect = workspace.Camera.Viewmodel.DescendantAdded:Connect(function(d)
						for i,v in next, txtpack:GetChildren() do
							if v.Name == d.Name then
								for i1,v1 in next, d:GetDescendants() do
									if v1:IsA("Part") or v1:IsA("MeshPart") then
										v1.Transparency = 1
									end
								end
								for i1,v1 in next, lplr.Character:GetChildren() do
									if v1.Name == v.Name then
										for i2,v2 in next, v1:GetDescendants() do
											if v2.Name ~= d.Name then
												if v2:IsA("Part") or v2:IsA("MeshPart") then
													v2.Transparency = 1;
												end;
											end;
										end;
									end;
								end;
								local handle: Handle? = d:FindFirstChild("Handle");
								if handle and handle:IsA("BasePart") then
									local vmmodel: any = v:Clone();
									vmmodel.CFrame = handle.CFrame * CFrame.Angles(math.rad(90), math.rad(-130), 0);
									if d.Name == "rageblade" then
										vmmodel.CFrame = CFrame.Angles(math.rad(-80), math.rad(230), math.rad(10));
									end;
									vmmodel.Parent = d;
									local vmmodelweld: WeldConstraint = Instance.new("WeldConstraint", vmmodel);
									vmmodelweld.Part0 = vmmodel;
									vmmodelweld.Part1 = handle;
									local charPart: any = lplr.Character:FindFirstChild(d.Name);
									local charHandle: any = charPart and charPart:FindFirstChild("Handle");
									if charHandle and charHandle:IsA("BasePart") then
										local charmodel: any = v:Clone();
										charmodel.CFrame = charHandle.CFrame * CFrame.Angles(math.rad(90), math.rad(-130), 0);
										if d.Name == "rageblade" then
											charmodel.CFrame = CFrame.Angles(math.rad(-80), math.rad(230), math.rad(10));
										end;
										charmodel.Anchored = false;
										charmodel.CanCollide = false;
										charmodel.Parent = charPart;
										local charmodelweld: WeldConstraint = Instance.new("WeldConstraint", charmodel);
										charmodelweld.Part0 = charmodel;
										charmodelweld.Part1 = charHandle;
									end;
								end;
							end;
						end;
					end);
				end;
			end;
		end;
    })
    texture_pack_m = texture_pack:CreateDropdown({
        ["Name"] ='Mode',
        ["List"] = {
            'Velocity',
			"FirstPack", 
			"SecondPack", 
			"ThirdPack", 
			"FourthPack", 
			"FifthPack", 
			"SixthPack", 
			"SeventhPack",
			"EighthPack", 
			"EgirlPack", 
			"CottonCandy", 
			"Pack512x", 
			"Pack1056x",
	        "PrivatePack",
            'Aquarium',
            'Ocean',
            'Animated',
			'DemonSlayer',
			'Glizzy',
			'FatCat',
			'Simply',
			'VioletsDreams',
			'Enlightened',
			"Onyx", 
			"Fury", 
			"Wichtiger", 
			"Makima", 
			"Marin-Kitsawaba", 
			"Prime", 
			"Vile", 
			"Devourer", 
			"Acidic", 
			"Moon4Real", 
			"Nebula",
			'Lunar'
        },
        ["Default"] ='Velocity',
        ["HoverText"] = 'Mode to render the texture pack, credits to Snoopy and CatVape.',
        ["Function"] = function() end
    })
    texture_pack_color = texture_pack:CreateColorSlider({
        ["Name"] ="Animated Color",
        ["HoverText"] = "Color of the ANIMATED texturepack.",
        ["Function"] = function() end
    })
end)
run(function()
	local AutoBerserker
	local Mode
	local EnemyRange
	local lastUse = 0
	local abilityRemote

	task.spawn(function()
		repeat task.wait() until replicatedStorage and replicatedStorage:FindFirstChild("events-@easy-games/game-core:shared/game-core-networking@getEvents.Events")
		local eventsFolder = replicatedStorage["events-@easy-games/game-core:shared/game-core-networking@getEvents.Events"]
		abilityRemote = eventsFolder and eventsFolder:FindFirstChild("useAbility")
	end)

	AutoBerserker = vape.Categories.Kits:CreateModule({
		Name = 'AutoBerserker',
		Function = function(callback)
			if callback then
				AutoBerserker:Clean(runService.Heartbeat:Connect(function()
					if not entitylib.isAlive then return end
					if not abilityRemote then return end

					local now = tick()
					if now - lastUse < 1 then return end

					local shouldActivate = false

					if Mode.Value == 'Always' then
						shouldActivate = true
					elseif Mode.Value == 'Combat Only' then
						local enemies = entitylib.AllPosition({
							Range = EnemyRange.Value,
							Part = 'RootPart',
							Players = true,
						})
						shouldActivate = #enemies > 0
					end

					if shouldActivate then
						abilityRemote:FireServer("berserker_rage")
						lastUse = now
					end
				end))
			end
		end,
		Tooltip = 'Automatically activates Berserker rage ability.'
	})
	Mode = AutoBerserker:CreateDropdown({
		Name = 'Mode',
		List = {'Combat Only', 'Always'},
		Function = function(val)
			EnemyRange.Object.Visible = (val == 'Combat Only')
		end
	})
	EnemyRange = AutoBerserker:CreateSlider({
		Name = 'Enemy Range',
		Min = 1,
		Max = 30,
		Default = 15,
		Suffix = 'studs',
		Darker = true,
		Visible = false
	})
end)
run(function()
    local Players = game:GetService("Players")
    local Terrain = workspace.Terrain
    local Lighting = game:GetService("Lighting")
    local RunService = game:GetService("RunService")
    local lplr = Players.LocalPlayer

    -- Global States
    local waterSize = Vector3.new(4000, 20, 4000)
    local currentWaterCFrame = nil
    local starEmitter = nil
    
    -- Slider Values (The Master Config)
    local settings = {
        Height = -40,
        WaveSpeed = 8,
        Glare = 0.8,
        Transparency = 0.8,
        StarSize = 0.5,
        StarAmount = 50,
        RainbowSpeed = 10,
        ClockTime = 14, -- 14 is afternoon
        MoonSize = 20,
        Brightness = 2 -- Default lighting brightness
    }

    -- Original Settings for Cleanup
    local oldSky = Lighting:FindFirstChildOfClass("Sky") and Lighting:FindFirstChildOfClass("Sky"):Clone() or nil
    local oldClock = Lighting.ClockTime
    local oldBrightness = Lighting.Brightness

    local VoidOcean = vape.Categories.Render:CreateModule({
        Name = "VoidOcean",
        Function = function(callback)
            if callback then
                Terrain.WaterColor = Color3.fromRGB(12, 60, 110)
                Terrain.WaterReflectance = settings.Glare
                Terrain.WaterWaveSpeed = settings.WaveSpeed
                Terrain.WaterTransparency = settings.Transparency
                
                local root = lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart")
                currentWaterCFrame = CFrame.new(root and root.Position.X or 0, settings.Height, root and root.Position.Z or 0)
                Terrain:FillBlock(currentWaterCFrame, waterSize, Enum.Material.Water)
            else
                -- Full Reset
                if currentWaterCFrame then Terrain:FillBlock(currentWaterCFrame, waterSize, Enum.Material.Air) end
                if starEmitter then starEmitter:Destroy() starEmitter = nil end
                Lighting.ClockTime = oldClock
                Lighting.Brightness = oldBrightness
                for _, v in pairs(Lighting:GetChildren()) do if v:IsA("Sky") then v:Destroy() end end
                if oldSky then oldSky:Clone().Parent = Lighting end
            end
        end
    })

    -- TOGGLES (The Basics)
    VoidOcean:CreateToggle({
        Name = "Rainbow Mode",
        Function = function(callback)
            task.spawn(function()
                while callback and VoidOcean.Enabled do
                    local hue = (tick() % settings.RainbowSpeed) / settings.RainbowSpeed
                    local color = Color3.fromHSV(hue, 0.7, 1)
                    Terrain.WaterColor = color
                    if starEmitter then starEmitter.Color = ColorSequence.new(color) end
                    RunService.Heartbeat:Wait()
                end
                if not callback and VoidOcean.Enabled then 
                    Terrain.WaterColor = Color3.fromRGB(12, 60, 110) 
                end
            end)
        end
    })

    VoidOcean:CreateToggle({
        Name = "Realistic Sky",
        Function = function(callback)
            if callback and VoidOcean.Enabled then
                for _, v in pairs(Lighting:GetChildren()) do if v:IsA("Sky") then v:Destroy() end end
                local sky = Instance.new("Sky")
                sky.SkyboxBk = "rbxassetid://10128014521"; sky.SkyboxDn = "rbxassetid://10128014839"; sky.SkyboxFt = "rbxassetid://10128015112"
                sky.SkyboxLf = "rbxassetid://10128015385"; sky.SkyboxRt = "rbxassetid://10128015582"; sky.SkyboxUp = "rbxassetid://10128015814"
                sky.MoonAngularSize = settings.MoonSize
                sky.Parent = Lighting
            elseif not callback then
                for _, v in pairs(Lighting:GetChildren()) do if v:IsA("Sky") then v:Destroy() end end
                if oldSky then oldSky:Clone().Parent = Lighting end
            end
        end
    })

    -- THE SLIDER SUITE (Control Everything)
    
    -- Ocean Controls
    VoidOcean:CreateSlider({ Name = "Ocean Height", Min = -150, Max = 50, Default = -40, Function = function(val)
        settings.Height = val
        if VoidOcean.Enabled and currentWaterCFrame then
            Terrain:FillBlock(currentWaterCFrame, waterSize, Enum.Material.Air)
            local root = lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart")
            currentWaterCFrame = CFrame.new(root and root.Position.X or 0, val, root and root.Position.Z or 0)
            Terrain:FillBlock(currentWaterCFrame, waterSize, Enum.Material.Water)
        end
    end})

    VoidOcean:CreateSlider({ Name = "Water Transparency", Min = 0, Max = 1, Default = 0.8, Function = function(val)
        settings.Transparency = val
        if VoidOcean.Enabled then Terrain.WaterTransparency = val end
    end})

    VoidOcean:CreateSlider({ Name = "Wave Speed", Min = 0, Max = 100, Default = 8, Function = function(val) 
        settings.WaveSpeed = val 
        if VoidOcean.Enabled then Terrain.WaterWaveSpeed = val end 
    end})

    -- Lighting Controls (Darkness/Brightness)
    VoidOcean:CreateSlider({ Name = "Time (Darkness)", Min = 0, Max = 24, Default = 14, Function = function(val)
        settings.ClockTime = val
        if VoidOcean.Enabled then 
            Lighting.ClockTime = val 
            -- Auto-handle Stars if it gets dark
            local root = lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart")
            if (val < 6 or val > 18) and not starEmitter and root then
                starEmitter = Instance.new("ParticleEmitter", root)
                starEmitter.Texture = "rbxassetid://5030434751"
                starEmitter.Size = NumberSequence.new(settings.StarSize, 0)
                starEmitter.Rate = settings.StarAmount
            elseif (val >= 6 and val <= 18) and starEmitter then
                starEmitter:Destroy() starEmitter = nil
            end
        end
    end})

    VoidOcean:CreateSlider({ Name = "World Brightness", Min = 0, Max = 10, Default = 2, Function = function(val)
        settings.Brightness = val
        if VoidOcean.Enabled then Lighting.Brightness = val end
    end})

    -- Sky & Moon Controls
    VoidOcean:CreateSlider({ Name = "Moon Size", Min = 0, Max = 100, Default = 20, Function = function(val)
        settings.MoonSize = val
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if sky then sky.MoonAngularSize = val end
    end})

    -- Star Controls
    VoidOcean:CreateSlider({ Name = "Star Size", Min = 0.1, Max = 10, Default = 0.5, Function = function(val)
        settings.StarSize = val
        if starEmitter then starEmitter.Size = NumberSequence.new(val, 0) end
    end})

    VoidOcean:CreateSlider({ Name = "Star Amount", Min = 0, Max = 500, Default = 50, Function = function(val)
        settings.StarAmount = val
        if starEmitter then starEmitter.Rate = val end
    end})

end)
run(function()
    local Disabler

    local DEFAULT_SPEED = 23
    local WIND_SPEED = 40
    local BOOST_SPEED = 40
    local SKATE_SPEED = 20

    local currentMode = "default"
    local lastCheck = 0

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ServerMomentumUpdate =
        ReplicatedStorage.rbxts_include.node_modules["@rbxts"].net.out._NetManaged.ServerMomentumUpdate

    local function setSpeed(val)
        if _G.SpeedValue then
            _G.SpeedValue.Value = val
        end
        if _G.FlyValue then
            _G.FlyValue.Value = val
        end
    end

    local function cleanupDisabler()
        if Disabler and Disabler.CheckLoop then
            Disabler.CheckLoop:Disconnect()
            Disabler.CheckLoop = nil
        end

        if Disabler and Disabler.MomentumLoop and task.cancel then
            task.cancel(Disabler.MomentumLoop)
            Disabler.MomentumLoop = nil
        end

        if Disabler and Disabler.DeathConn then
            Disabler.DeathConn:Disconnect()
            Disabler.DeathConn = nil
        end

        currentMode = "default"
        setSpeed(DEFAULT_SPEED)
    end

    Disabler = vape.Categories.Blatant:CreateModule({
        Name = "Semi disabler",
        Function = function(callback)
            if callback then
                cleanupDisabler()

                -- 🔁 Status checker (every 0.5s)
                Disabler.CheckLoop = runService.Heartbeat:Connect(function()
                    if tick() - lastCheck < 0.5 then return end
                    lastCheck = tick()

                    local playerGui = lplr:FindFirstChildOfClass("PlayerGui")
                    local wind = playerGui and playerGui:FindFirstChild("WindWalkerEffect", true)
                    local boost = playerGui and playerGui:FindFirstChild("Speed Boost", true)
                    local skate = playerGui and playerGui:FindFirstChild("High Speed Skating", true)

                    -- 🛼 High Speed Skating (highest priority)
                    if skate and skate.Visible ~= false then
                        if currentMode ~= "skate" then
                            currentMode = "skate"
                            setSpeed(SKATE_SPEED)
                        end
                        return
                    end

                    -- ⚡ Speed Boost
                    if boost and boost.Visible ~= false then
                        if currentMode ~= "boost" then
                            currentMode = "boost"
                            setSpeed(BOOST_SPEED)
                        end
                        return
                    end

                    -- 🌪 WindWalker stacks
                    local stack = wind and wind:FindFirstChild("EffectStack", true)
                    if stack and (stack:IsA("TextLabel") or stack:IsA("TextButton")) then
                        local num = tonumber(stack.Text)
                        if num and num >= 1 then
                            if currentMode ~= "wind" then
                                currentMode = "wind"
                                setSpeed(WIND_SPEED)
                            end
                            return
                        end
                    end

                    -- 🔄 Reset
                    if currentMode ~= "default" then
                        currentMode = "default"
                        setSpeed(23)
                    end
                end)

                -- 💎 Krystal momentum spam
                Disabler.MomentumLoop = task.spawn(function()
                    while Disabler and Disabler.Enabled do
                        if ServerMomentumUpdate and ServerMomentumUpdate.OnClientEvent then
                            firesignal(ServerMomentumUpdate.OnClientEvent, {
                                momentumIncrement = 9e9
                            })
                        end
                        task.wait(0.01)
                    end
                end)

                -- ☠ Reset on respawn
                Disabler.DeathConn = lplr.CharacterAdded:Connect(function()
                    task.wait(0.1)
                    currentMode = "default"
                    setSpeed(DEFAULT_SPEED)
                end)

            else
                cleanupDisabler()
            end
        end,
        ExtraText = function() return "Bedwars Developers" end,
        Tooltip = "Semi disables the ac with 3 different ways"
    })
end)
run(function()
	local LagbackNotifier
	
	LagbackNotifier = vape.Categories.Utility:CreateModule({
        Name = 'LagbackNotifier',
        Function = function(enabled)
            if enabled then
                local lastnetowner = true
                LagbackNotifier:Clean(lplr:GetAttributeChangedSignal('LastTeleported'):Connect(function()
                    vape:CreateNotification('LagbackNotifier', 'Teleport detected', 3)
                end))
                LagbackNotifier:Clean(runService.Heartbeat:Connect(function()
                    local char = lplr.Character
                    local hrp = char and char:FindFirstChild('HumanoidRootPart')

                    if hrp then
                        if lastnetowner ~= isnetworkowner(hrp) then
                            lastnetowner = isnetworkowner(hrp)
                            if not lastnetowner then
                                vape:CreateNotification('LagbackNotifier', 'Lagback detected', 3)
                            end
                        end
                    end
                end))
            end
        end
    })
end)
run(function()
	local SetFPS
	local FPS
	
	SetFPS = vape.Categories.Utility:CreateModule({
		Name = "SetFPS",
		Function = function(callback)
			if callback then
				setfpscap(FPS.Value)
			else
				setfpscap(240)
			end
		end,
		Tooltip = "Removes or customizes the Frame-Per-Second limit",
	})
	
	FPS = SetFPS:CreateSlider({
		Name = "Frames Per Second",
		Min = 0,
		Max = 420,
		Default = 240,
		Function = function(value)
			setfpscap(value)
		end
	})
end)
local role = "owner"
run(function()
    local HitFix
	local PingBased
	local Options
    HitFix = vape.Categories.Blatant:CreateModule({
        Name = 'HitFix',
        Function = function(callback)
            if role ~= "owner" and role ~= "coowner" and role ~= "admin" and role ~= "friend" and role ~= "premium" then
                vape:CreateNotification("Onyx", "You don’t have access to this.", 10, "alert")
                return
            end  

            local function getPing()
                local stats = game:GetService("Stats")
                local ping = stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
                return tonumber(ping:match("%d+")) or 50
            end

            local function getDelay()
                local ping = getPing()

                if PingBased.Enabled then
                    if Options.Value == "Blatant" then
                        return math.clamp(0.08 + (ping / 1000), 0.08, 0.14)
                    else
                        return math.clamp(0.11 + (ping / 1200), 0.11, 0.15)
                    end
                end

                return Options.Value == "Blatant" and 0.1 or 0.13
            end

            if callback then
                pcall(function()
                    if bedwars.SwordController and bedwars.SwordController.swingSwordAtMouse then
                        local func = bedwars.SwordController.swingSwordAtMouse

                        if Options.Value == "Blatant" then
                            debug.setconstant(func, 23, "raycast")
                            debug.setupvalue(func, 4, bedwars.QueryUtil)
                        end

                        for i, v in ipairs(debug.getconstants(func)) do
                            if typeof(v) == "number" and (v == 28) then
                                debug.setconstant(func, i, getDelay())
                            end
                        end
                    end
                end)
            else
                pcall(function()
                    if bedwars.SwordController and bedwars.SwordController.swingSwordAtMouse then
                        local func = bedwars.SwordController.swingSwordAtMouse

                        debug.setconstant(func, 23, "Raycast")
                        debug.setupvalue(func, 4, workspace)

                        for i, v in ipairs(debug.getconstants(func)) do
                            if typeof(v) == "number" then
                                if v < 0.15 then
                                    debug.setconstant(func, i, 0.15)
                                end
                            end
                        end
                    end
                end)
            end
        end,
        Tooltip = 'Improves hit registration and decreases the chances of a ghost hit'
    })

    Options = HitFix:CreateDropdown({
        Name = "Mode",
        List = {"Blatant", "Legit"},
    })

    PingBased = HitFix:CreateToggle({
        Name = "Ping Based",
        Default = false,
    })
end)

	
run(function()
	local ChinaHat
	local Material
	local Color
	local hat
	
	ChinaHat = vape.Categories.Render:CreateModule({
		Name = 'ChinaHat',
		Function = function(callback)
			if callback then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				hat = Instance.new('MeshPart')
				hat.Size = Vector3.new(3, 0.7, 3)
				hat.Name = 'ChinaHat'
				hat.Material = Enum.Material[Material.Value]
				hat.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				hat.CanCollide = false
				hat.CanQuery = false
				hat.Massless = true
				hat.MeshId = 'http://www.roblox.com/asset/?id=1778999'
				hat.Transparency = 1 - Color.Opacity
				hat.Parent = gameCamera
				hat.CFrame = entitylib.isAlive and entitylib.character.Head.CFrame + Vector3.new(0, 1, 0) or CFrame.identity
				local weld = Instance.new('WeldConstraint')
				weld.Part0 = hat
				weld.Part1 = entitylib.isAlive and entitylib.character.Head or nil
				weld.Parent = hat
				ChinaHat:Clean(hat)
				ChinaHat:Clean(entitylib.Events.LocalAdded:Connect(function(char)
					if weld then 
						weld:Destroy() 
					end
					hat.Parent = gameCamera
					hat.CFrame = char.Head.CFrame + Vector3.new(0, 1, 0)
					hat.Velocity = Vector3.zero
					weld = Instance.new('WeldConstraint')
					weld.Part0 = hat
					weld.Part1 = char.Head
					weld.Parent = hat
				end))
	
				repeat
					hat.LocalTransparencyModifier = ((gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude <= 0.6 and 1 or 0)
					task.wait()
				until not ChinaHat.Enabled
			else
				hat = nil
			end
		end,
		Tooltip = 'Puts a china hat on your character (ty mastadawn)'
	})
	local materials = {'ForceField'}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'ForceField' then
			table.insert(materials, v.Name)
		end
	end
	Material = ChinaHat:CreateDropdown({
		Name = 'Material',
		List = materials,
		Function = function(val)
			if hat then
				hat.Material = Enum.Material[val]
			end
		end
	})
	Color = ChinaHat:CreateColorSlider({
		Name = 'Hat Color',
		DefaultOpacity = 0.7,
		Function = function(hue, sat, val, opacity)
			if hat then
				hat.Color = Color3.fromHSV(hue, sat, val)
				hat.Transparency = 1 - opacity
			end
		end
	})
end)
run(function()
	local Cape
	local Texture
	local part, motor
	
	local function createMotor(char)
		if motor then 
			motor:Destroy() 
		end
		part.Parent = gameCamera
		motor = Instance.new('Motor6D')
		motor.MaxVelocity = 0.08
		motor.Part0 = part
		motor.Part1 = char.Character:FindFirstChild('UpperTorso') or char.RootPart
		motor.C0 = CFrame.new(0, 2, 0) * CFrame.Angles(0, math.rad(-90), 0)
		motor.C1 = CFrame.new(0, motor.Part1.Size.Y / 2, 0.45) * CFrame.Angles(0, math.rad(90), 0)
		motor.Parent = part
	end
	
	Cape = vape.Categories.Render:CreateModule({
		Name = 'Cape',
		Function = function(callback)
			if callback then
				part = Instance.new('Part')
				part.Size = Vector3.new(2, 4, 0.1)
				part.CanCollide = false
				part.CanQuery = false
				part.Massless = true
				part.Transparency = 0
				part.Material = Enum.Material.SmoothPlastic
				part.Color = Color3.new()
				part.CastShadow = false
				part.Parent = gameCamera
				local capesurface = Instance.new('SurfaceGui')
				capesurface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				capesurface.Adornee = part
				capesurface.Parent = part
	
				if Texture.Value:find('.webm') then
					local decal = Instance.new('VideoFrame')
					decal.Video = getcustomasset(Texture.Value)
					decal.Size = UDim2.fromScale(1, 1)
					decal.BackgroundTransparency = 1
					decal.Looped = true
					decal.Parent = capesurface
					decal:Play()
				else
					local decal = Instance.new('ImageLabel')
					decal.Image = Texture.Value ~= '' and (Texture.Value:find('rbxasset') and Texture.Value or assetfunction(Texture.Value)) or 'rbxassetid://14637958134'
					decal.Size = UDim2.fromScale(1, 1)
					decal.BackgroundTransparency = 1
					decal.Parent = capesurface
				end
				Cape:Clean(part)
				Cape:Clean(entitylib.Events.LocalAdded:Connect(createMotor))
				if entitylib.isAlive then
					createMotor(entitylib.character)
				end
	
				repeat
					if motor and entitylib.isAlive then
						local velo = math.min(entitylib.character.RootPart.Velocity.Magnitude, 90)
						motor.DesiredAngle = math.rad(6) + math.rad(velo) + (velo > 1 and math.abs(math.cos(tick() * 5)) / 3 or 0)
					end
					capesurface.Enabled = (gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude > 0.6
					part.Transparency = (gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude > 0.6 and 0 or 1
					task.wait()
				until not Cape.Enabled
			else
				part = nil
				motor = nil
			end
		end,
		Tooltip = 'Add\'s a cape to your character'
	})
	Texture = Cape:CreateTextBox({
		Name = 'Texture'
	})
end)
run(function()
	local InstantRegent
	local old = nil
	
	InstantRegent = vape.Categories.Kits:CreateModule({
		Name = "InstantRegent",
		Tooltip = "no cooldown on the void axe spam",
		Function = function(callback)
			if callback then
				if old then return end
				old = bedwars.CooldownController.isOnCooldown
				bedwars.CooldownController.isOnCooldown = function(self, id)
					if id ~= nil and string.find(tostring(id):lower(), 'void_axe', 1, true) then
						return false
					end
					if type(old) ~= 'function' then return false end
					return old(self, id)
				end
			else
				if old then
					bedwars.CooldownController.isOnCooldown = old
					old = nil
				end
			end
		end
	})
end)

run(function()
	local YuziDasher
	local ImpulseSlider
	local JumpHeightSlider
	local CurrentKeybind = Enum.KeyCode.Q

	local canDash = true

	local function PerformDash()
		if not canDash then return end
		if not entitylib.isAlive then return end

		local heldItem = store.hand.tool
		if not heldItem or not (heldItem.Name:find("dao") or heldItem.Name:find("yuzi") or heldItem.Name == "jade_hammer" or heldItem.Name == "void_axe") then return end

		local abilityId = (heldItem.Name == "jade_hammer" and "JADE_HAMMER_JUMP") or (heldItem.Name == "void_axe" and "VOID_AXE_JUMP") or nil

		local character = lplr.Character
		if not (character and character.PrimaryPart) then return end

		canDash = false

		task.spawn(function()
			local originalJumpHeight = character.Humanoid.JumpHeight

			pcall(function() character:SetAttribute('CanDash', 0) end)

			local lookVector = gameCamera.CFrame.LookVector
			local origin = character.PrimaryPart.Position

			pcall(function()
				local n = game:GetService("ReplicatedStorage"):FindFirstChild("rbxts_include")
				if n then n = n:FindFirstChild("node_modules") end
				if n then n = n:FindFirstChild("@rbxts") end
				if n then n = n:FindFirstChild("net") end
				if n then n = n:FindFirstChild("out") end
				if n then n = n:FindFirstChild("_NetManaged") end
				if n then n = n:FindFirstChild("SwordSwingMiss") end
				if n then n:FireServer({ weapon = heldItem, chargeRatio = 0 }) end
			end)

			task.wait(0.05)

			local useDash = abilityId == nil
			local canUse = useDash and bedwars.AbilityController:canUseAbility('dash') or (abilityId and bedwars.AbilityController:canUseAbility(abilityId))

			if canUse then
				if useDash then
					bedwars.AbilityController:useAbility('dash', nil, {
						direction = lookVector,
						origin = origin,
						weapon = heldItem.Name
					})
				else
					bedwars.AbilityController:useAbility(abilityId)
				end

				pcall(function()
					bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.DAO_DASH)
				end)

				pcall(function()
					local hrp = character.HumanoidRootPart
					local mass = hrp.AssemblyMass or 5
					hrp:ApplyImpulse(lookVector.Unit * Vector3.new(1, 0, 1) * mass * ImpulseSlider.Value)
					character.Humanoid.JumpHeight = JumpHeightSlider.Value
					character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				end)

				task.delay(0.5, function()
					if character and character.Humanoid then
						pcall(function()
							character.Humanoid.JumpHeight = originalJumpHeight
							if bedwars.JumpHeightController then
								bedwars.JumpHeightController:setJumpHeight(game:GetService("StarterPlayer").CharacterJumpHeight)
							end
						end)
					end
				end)
			end

			task.wait(0.3)
			canDash = true
		end)
	end

	YuziDasher = vape.Categories.Kits:CreateModule({
		Name = 'YuziDasher',
		Function = function(callback)
			if callback then
				YuziDasher:Clean(YuziDasher.Bind.Triggered:Connect(function(isDown)
					if isDown then
						PerformDash()
					end
				end))
				YuziDasher:Clean(inputService.InputBegan:Connect(function(input, gameProcessed)
					if gameProcessed then return end
					if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == CurrentKeybind then
						PerformDash()
					end
				end))
			else
				canDash = true
			end
		end,
	})

	local keybindOptions = {
		"Q", "E", "R", "F", "G", "X", "Z", "V", "B",
		"LeftAlt", "LeftControl", "LeftShift", "RightAlt", "RightControl", "RightShift",
		"Space", "CapsLock", "Tab"
	}

	YuziDasher:CreateDropdown({
		Name = 'Keybind',
		List = keybindOptions,
		Default = "Q",
		Function = function(value)
			CurrentKeybind = Enum.KeyCode[value]
		end
	})

	ImpulseSlider = YuziDasher:CreateSlider({
		Name = 'Impulse Multiplier',
		Min = 10,
		Max = 500,
		Default = 100,
		Tooltip = 'Controls dash speed'
	})

	JumpHeightSlider = YuziDasher:CreateSlider({
		Name = 'Jump Height',
		Min = 0,
		Max = 50,
		Default = 10,
	})
end)
run(function()
	local AntiLasso
	local Chance
	local watching = setmetatable({}, {__mode = 'k'})
	
	local function Added(ent)
		if watching[ent] then return end
	
		watching[ent] = ent.ChildAdded:Connect(function(v)
			if not AntiLasso.Enabled then return end
			if v:IsA('Accessory') and v:FindFirstChild('Rope') and Random.new(os.clock()):NextNumber(1, 100) < Chance.Value then
				ent.PrimaryPart.Anchored = true
				v.Destroying:Once(function()
					task.wait(0.5)
					ent.PrimaryPart.Anchored = false
				end)
			end
		end)
	end
	
	AntiLasso = vape.Categories.Kits:CreateModule({
		Name = 'AntiLasso',
		Function = function(callback)
			if callback then
				AntiLasso:Clean(entitylib.Events.LocalAdded:Connect(function(ent)
					task.delay(1, function()
						Added(ent.Character)
					end)
				end))
				if entitylib.isAlive then
					Added(lplr.Character)
				end
			else
				local char = lplr.Character
				local root = char and char.PrimaryPart
				if root then
					pcall(function() root.Anchored = false end)
				end
			end
		end,
		Tooltip = 'stops u gettin yanked by the lasso'
	})
	
	Chance = AntiLasso:CreateSlider({
		Name = 'Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
end)

run(function()
	local GrimReaperFix
	GrimReaperFix = vape.Categories.Kits:CreateModule({
		Name = 'GrimReaperFix',
		Function = function(callback)
			if callback then
				GrimReaperFix:Clean(runService.Heartbeat:Connect(function()
					if not entitylib.isAlive then return end
					local humanoid = entitylib.character.Humanoid
					if humanoid.HipHeight > 2.1 then
						humanoid.HipHeight = 2.05
					end
				end))
			end
		end,
		Tooltip = 'fixes grim height (prevents being too tall)'
	})
end)
run(function()
	local Breaker
	local Range
	local BreakSpeed
	local UpdateRate
	local Custom
	local Bed
	local LuckyBlock
	local IronOre
	local Effect
	local CustomHealth = {}
	local Animation
	local SelfBreak
	local InstantBreak
	local LimitItem
	local customlist, parts = {}, {}
	
	local function customHealthbar(self, blockRef, health, maxHealth, changeHealth, block)
		if block:GetAttribute('NoHealthbar') then return end
		if not self.healthbarPart or not self.healthbarBlockRef or self.healthbarBlockRef.blockPosition ~= blockRef.blockPosition then
			self.healthbarMaid:DoCleaning()
			self.healthbarBlockRef = blockRef
			local create = bedwars.Roact.createElement
			local percent = math.clamp(health / maxHealth, 0, 1)
			local cleanCheck = true
			local part = Instance.new('Part')
			part.Size = Vector3.one
			part.CFrame = CFrame.new(bedwars.BlockController:getWorldPosition(blockRef.blockPosition))
			part.Transparency = 1
			part.Anchored = true
			part.CanCollide = false
			part.Parent = workspace
			self.healthbarPart = part
			bedwars.QueryUtil:setQueryIgnored(self.healthbarPart, true)
	
			local mounted = bedwars.Roact.mount(create('BillboardGui', {
				Size = UDim2.fromOffset(249, 102),
				StudsOffset = Vector3.new(0, 2.5, 0),
				Adornee = part,
				MaxDistance = 40,
				AlwaysOnTop = true
			}, {
				create('Frame', {
					Size = UDim2.fromOffset(160, 50),
					Position = UDim2.fromOffset(44, 32),
					BackgroundColor3 = Color3.new(),
					BackgroundTransparency = 0.5
				}, {
					create('UICorner', {CornerRadius = UDim.new(0, 5)}),
					create('ImageLabel', {
						Size = UDim2.new(1, 89, 1, 52),
						Position = UDim2.fromOffset(-48, -31),
						BackgroundTransparency = 1,
						Image = getcustomasset('newvape/assets/new/blur.png'),
						ScaleType = Enum.ScaleType.Slice,
						SliceCenter = Rect.new(52, 31, 261, 502)
					}),
					create('TextLabel', {
						Size = UDim2.fromOffset(145, 14),
						Position = UDim2.fromOffset(13, 12),
						BackgroundTransparency = 1,
						Text = bedwars.ItemMeta[block.Name].displayName or block.Name,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextColor3 = Color3.new(),
						TextScaled = true,
						Font = Enum.Font.Arial
					}),
					create('TextLabel', {
						Size = UDim2.fromOffset(145, 14),
						Position = UDim2.fromOffset(12, 11),
						BackgroundTransparency = 1,
						Text = bedwars.ItemMeta[block.Name].displayName or block.Name,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextColor3 = color.Dark(uipallet.Text, 0.16),
						TextScaled = true,
						Font = Enum.Font.Arial
					}),
					create('Frame', {
						Size = UDim2.fromOffset(138, 4),
						Position = UDim2.fromOffset(12, 32),
						BackgroundColor3 = uipallet.Main
					}, {
						create('UICorner', {CornerRadius = UDim.new(1, 0)}),
						create('Frame', {
							[bedwars.Roact.Ref] = self.healthbarProgressRef,
							Size = UDim2.fromScale(percent, 1),
							BackgroundColor3 = Color3.fromHSV(math.clamp(percent / 2.5, 0, 1), 0.89, 0.75)
						}, {create('UICorner', {CornerRadius = UDim.new(1, 0)})})
					})
				})
			}), part)
	
			self.healthbarMaid:GiveTask(function()
				cleanCheck = false
				self.healthbarBlockRef = nil
				bedwars.Roact.unmount(mounted)
				if self.healthbarPart then
					self.healthbarPart:Destroy()
				end
				self.healthbarPart = nil
			end)
	
			bedwars.RuntimeLib.Promise.delay(5):andThen(function()
				if cleanCheck then
					self.healthbarMaid:DoCleaning()
				end
			end)
		end
	
		local newpercent = math.clamp((health - changeHealth) / maxHealth, 0, 1)
		tweenService:Create(self.healthbarProgressRef:getValue(), TweenInfo.new(0.3), {
			Size = UDim2.fromScale(newpercent, 1), BackgroundColor3 = Color3.fromHSV(math.clamp(newpercent / 2.5, 0, 1), 0.89, 0.75)
		}):Play()
	end
	
	local hit = 0
	
	local function attemptBreak(tab, localPosition)
		if not tab then return end
		for _, v in tab do
			if (v.Position - localPosition).Magnitude < Range.Value and bedwars.BlockController:isBlockBreakable({blockPosition = v.Position / 3}, lplr) then
				if not SelfBreak.Enabled and v:GetAttribute('PlacedByUserId') == lplr.UserId then continue end
				if (v:GetAttribute('BedShieldEndTime') or 0) > workspace:GetServerTimeNow() then continue end
				if LimitItem.Enabled and not (store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name].breakBlock) then continue end
	
				hit += 1
				local target, path, endpos = bedwars.breakBlock(v, Effect.Enabled, Animation.Enabled, CustomHealth.Enabled and customHealthbar or nil, InstantBreak.Enabled)
				if path then
					local currentnode = target
					for _, part in parts do
						part.Position = currentnode or Vector3.zero
						if currentnode then
							part.BoxHandleAdornment.Color3 = currentnode == endpos and Color3.new(1, 0.2, 0.2) or currentnode == target and Color3.new(0.2, 0.2, 1) or Color3.new(0.2, 1, 0.2)
						end
						currentnode = path[currentnode]
					end
				end
	
				task.wait(InstantBreak.Enabled and (store.damageBlockFail > tick() and 4.5 or 0) or BreakSpeed.Value)
	
				return true
			end
		end
	
		return false
	end
	
	Breaker = vape.Categories.Utility:CreateModule({
		Name = 'Breaker',
		Function = function(callback)
			if callback then
				for _ = 1, 30 do
					local part = Instance.new('Part')
					part.Anchored = true
					part.CanQuery = false
					part.CanCollide = false
					part.Transparency = 1
					part.Parent = gameCamera
					local highlight = Instance.new('BoxHandleAdornment')
					highlight.Size = Vector3.one
					highlight.AlwaysOnTop = true
					highlight.ZIndex = 1
					highlight.Transparency = 0.5
					highlight.Adornee = part
					highlight.Parent = part
					table.insert(parts, part)
				end
	
				local beds = collection('bed', Breaker)
				local luckyblock = collection('LuckyBlock', Breaker)
				local ironores = collection('iron-ore', Breaker)
				customlist = collection('block', Breaker, function(tab, obj)
					if table.find(Custom.ListEnabled, obj.Name) then
						table.insert(tab, obj)
					end
				end)
	
				repeat
					task.wait(1 / UpdateRate.Value)
					if not Breaker.Enabled then break end
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
	
						if attemptBreak(Bed.Enabled and beds, localPosition) then continue end
						if attemptBreak(customlist, localPosition) then continue end
						if attemptBreak(LuckyBlock.Enabled and luckyblock, localPosition) then continue end
						if attemptBreak(IronOre.Enabled and ironores, localPosition) then continue end
	
						for _, v in parts do
							v.Position = Vector3.zero
						end
					end
				until not Breaker.Enabled
			else
				for _, v in parts do
					v:ClearAllChildren()
					v:Destroy()
				end
				table.clear(parts)
			end
		end,
		Tooltip = 'Break blocks around you automatically'
	})
	Range = Breaker:CreateSlider({
		Name = 'Break range',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	BreakSpeed = Breaker:CreateSlider({
		Name = 'Break speed',
		Min = 0,
		Max = 0.3,
		Default = 0.25,
		Decimal = 100,
		Suffix = 'seconds'
	})
	UpdateRate = Breaker:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})
	Custom = Breaker:CreateTextList({
		Name = 'Custom',
		Function = function()
			if not customlist then return end
			table.clear(customlist)
			for _, obj in store.blocks do
				if table.find(Custom.ListEnabled, obj.Name) then
					table.insert(customlist, obj)
				end
			end
		end
	})
	Bed = Breaker:CreateToggle({
		Name = 'Break Bed',
		Default = true
	})
	LuckyBlock = Breaker:CreateToggle({
		Name = 'Break Lucky Block',
		Default = true
	})
	IronOre = Breaker:CreateToggle({
		Name = 'Break Iron Ore',
		Default = true
	})
	Effect = Breaker:CreateToggle({
		Name = 'Show Healthbar & Effects',
		Function = function(callback)
			if CustomHealth.Object then
				CustomHealth.Object.Visible = callback
			end
		end,
		Default = true
	})
	CustomHealth = Breaker:CreateToggle({
		Name = 'Custom Healthbar',
		Default = true,
		Darker = true
	})
	Animation = Breaker:CreateToggle({Name = 'Animation'})
	SelfBreak = Breaker:CreateToggle({Name = 'Self Break'})
	InstantBreak = Breaker:CreateToggle({Name = 'Instant Break'})
	LimitItem = Breaker:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only breaks when tools are held'
	})
end)
run(function()
	local PotatoMode
	local Mode
	local originalProperties = {}
	local blockMonitorConnections = {}
	local processedBlocks = {}

	local blockColors = {
		["wool_white"] = Color3.fromRGB(255, 255, 255),
		["wool_red"] = Color3.fromRGB(255, 50, 50),
		["wool_green"] = Color3.fromRGB(50, 255, 50),
		["wool_blue"] = Color3.fromRGB(50, 100, 255),
		["wool_yellow"] = Color3.fromRGB(255, 255, 50),
		["wool_orange"] = Color3.fromRGB(255, 150, 50),
		["wool_purple"] = Color3.fromRGB(180, 50, 255),
		["wool_pink"] = Color3.fromRGB(255, 100, 200),
		["wool_black"] = Color3.fromRGB(50, 50, 50),
		["wool_cyan"] = Color3.fromRGB(50, 255, 255),
		["wool_magenta"] = Color3.fromRGB(255, 50, 150),
		["wool_lime"] = Color3.fromRGB(150, 255, 50),
		["wool_brown"] = Color3.fromRGB(150, 75, 0),
		["wool_light_blue"] = Color3.fromRGB(100, 200, 255),
		["wool_gray"] = Color3.fromRGB(150, 150, 150),
		["wool_builder"] = Color3.fromRGB(200, 200, 200),
		["wool_shear"] = Color3.fromRGB(200, 200, 200),
		["wool"] = Color3.fromRGB(200, 200, 200),
		["clay_white"] = Color3.fromRGB(255, 255, 255),
		["clay_black"] = Color3.fromRGB(50, 50, 50),
		["clay_blue"] = Color3.fromRGB(50, 100, 255),
		["clay_dark_brown"] = Color3.fromRGB(100, 60, 30),
		["clay_dark_green"] = Color3.fromRGB(30, 100, 30),
		["clay_gray"] = Color3.fromRGB(150, 150, 150),
		["clay_green"] = Color3.fromRGB(50, 255, 50),
		["clay_light_brown"] = Color3.fromRGB(200, 170, 120),
		["clay_light_green"] = Color3.fromRGB(150, 255, 150),
		["clay_orange"] = Color3.fromRGB(255, 150, 50),
		["clay_pink"] = Color3.fromRGB(255, 100, 200),
		["clay_purple"] = Color3.fromRGB(180, 50, 255),
		["clay_red"] = Color3.fromRGB(255, 50, 50),
		["clay_tan"] = Color3.fromRGB(210, 180, 140),
		["clay_yellow"] = Color3.fromRGB(255, 255, 50),
		["clay"] = Color3.fromRGB(220, 180, 140),
		["wood_plank_spruce"] = Color3.fromRGB(222, 184, 135),
		["wood_plank_birch"] = Color3.fromRGB(230, 220, 190),
		["wood_plank_maple"] = Color3.fromRGB(200, 140, 90),
		["wood_plank_oak"] = Color3.fromRGB(180, 140, 100),
		["wood_plank_oak_builder"] = Color3.fromRGB(180, 140, 100),
		["oak_log"] = Color3.fromRGB(120, 90, 60),
		["birch_log"] = Color3.fromRGB(220, 210, 180),
		["spruce_log"] = Color3.fromRGB(100, 75, 50),
		["hickory_log"] = Color3.fromRGB(140, 100, 60),
		["wood"] = Color3.fromRGB(180, 140, 100),
		["stone"] = Color3.fromRGB(150, 150, 150),
		["stone_brick"] = Color3.fromRGB(140, 140, 140),
		["stone_brick_builder"] = Color3.fromRGB(140, 140, 140),
		["stone_slab"] = Color3.fromRGB(160, 160, 160),
		["stone_pillar"] = Color3.fromRGB(160, 160, 160),
		["stone_tiles"] = Color3.fromRGB(160, 160, 160),
		["stone_player_block"] = Color3.fromRGB(150, 150, 150),
		["andesite"] = Color3.fromRGB(150, 150, 150),
		["andesite_polished"] = Color3.fromRGB(160, 160, 160),
		["diorite"] = Color3.fromRGB(220, 220, 220),
		["diorite_polished"] = Color3.fromRGB(230, 230, 230),
		["granite"] = Color3.fromRGB(180, 100, 80),
		["granite_polished"] = Color3.fromRGB(190, 110, 90),
		["cobblestone"] = Color3.fromRGB(150, 150, 150),
		["limestone"] = Color3.fromRGB(210, 200, 180),
		["marble"] = Color3.fromRGB(235, 235, 235),
		["marble_pillar"] = Color3.fromRGB(235, 235, 235),
		["slate_brick"] = Color3.fromRGB(90, 95, 100),
		["slate_tiles"] = Color3.fromRGB(90, 95, 100),
		["volatile_stone"] = Color3.fromRGB(150, 150, 150),
		["obsidian"] = Color3.fromRGB(50, 30, 80),
		["bedrock"] = Color3.fromRGB(80, 80, 80),
		["tnt"] = Color3.fromRGB(255, 50, 50),
		["sandstone"] = Color3.fromRGB(220, 200, 150),
		["sandstone_polished"] = Color3.fromRGB(225, 205, 155),
		["sandstone_smooth"] = Color3.fromRGB(225, 205, 155),
		["red_sandstone"] = Color3.fromRGB(190, 110, 60),
		["red_sandstone_polished"] = Color3.fromRGB(195, 115, 65),
		["red_sandstone_smooth"] = Color3.fromRGB(195, 115, 65),
		["sand"] = Color3.fromRGB(220, 200, 150),
		["red_sand"] = Color3.fromRGB(190, 110, 60),
		["glass"] = Color3.fromRGB(200, 230, 230),
		["magic_glass"] = Color3.fromRGB(150, 200, 255),
		["diamond"] = Color3.fromRGB(100, 220, 220),
		["diamond_block"] = Color3.fromRGB(100, 220, 220),
		["diamond_ore"] = Color3.fromRGB(100, 220, 220),
		["emerald"] = Color3.fromRGB(50, 255, 50),
		["emerald_block"] = Color3.fromRGB(50, 255, 50),
		["emerald_ore"] = Color3.fromRGB(50, 255, 50),
		["iron"] = Color3.fromRGB(220, 220, 220),
		["iron_block"] = Color3.fromRGB(220, 220, 220),
		["iron_ore"] = Color3.fromRGB(200, 200, 200),
		["iron_ore_mesh_block"] = Color3.fromRGB(200, 200, 200),
		["gold"] = Color3.fromRGB(255, 215, 0),
		["gold_block"] = Color3.fromRGB(255, 215, 0),
		["copper_block"] = Color3.fromRGB(184, 115, 51),
		["steel_block"] = Color3.fromRGB(170, 170, 180),
		["galactite"] = Color3.fromRGB(100, 80, 160),
		["galactite_brick"] = Color3.fromRGB(100, 80, 160),
		["crystal_ore"] = Color3.fromRGB(180, 150, 255),
		["guilded_iron"] = Color3.fromRGB(230, 200, 100),
		["ceramic"] = Color3.fromRGB(230, 140, 60),
		["aquamarine_lantern"] = Color3.fromRGB(80, 220, 200),
		["barrel"] = Color3.fromRGB(140, 95, 55),
		["bookshelf"] = Color3.fromRGB(150, 100, 60),
		["brick"] = Color3.fromRGB(160, 80, 60),
		["grass"] = Color3.fromRGB(50, 255, 50),
		["moss_block"] = Color3.fromRGB(50, 150, 50),
		["dirt"] = Color3.fromRGB(120, 80, 50),
		["void_dirt"] = Color3.fromRGB(60, 40, 25),
		["void_grass"] = Color3.fromRGB(25, 80, 25),
		["ice"] = Color3.fromRGB(180, 220, 255),
		["snow"] = Color3.fromRGB(255, 255, 255),
		["snow_pile"] = Color3.fromRGB(255, 255, 255),
		["glowstone"] = Color3.fromRGB(255, 240, 150),
		["magma_block"] = Color3.fromRGB(200, 80, 30),
		["slime_block"] = Color3.fromRGB(120, 230, 120),
		["gum_block"] = Color3.fromRGB(255, 150, 200),
		["invisible_block"] = Color3.fromRGB(255, 255, 255),
		["void_block"] = Color3.fromRGB(20, 20, 20),
		["smoke_block"] = Color3.fromRGB(130, 130, 130),
		["cotton_candy_block"] = Color3.fromRGB(255, 200, 230),
		["cotton_candy_block_blue"] = Color3.fromRGB(150, 200, 255),
		["cotton_candy_block_orange"] = Color3.fromRGB(255, 180, 120),
		["cotton_candy_block_pink"] = Color3.fromRGB(255, 150, 200),
		["cotton_candy_block_yellow"] = Color3.fromRGB(255, 240, 150),
		["blue_tile"] = Color3.fromRGB(50, 100, 255),
		["concrete_green"] = Color3.fromRGB(50, 180, 50),
		["concrete"] = Color3.fromRGB(180, 180, 180),
		["bed"] = Color3.fromRGB(200, 50, 50),
		["og_bed"] = Color3.fromRGB(200, 50, 50),
		["royale_bed"] = Color3.fromRGB(200, 50, 50),
		["fake_bed"] = Color3.fromRGB(200, 50, 50),
		["barrier"] = Color3.fromRGB(255, 0, 0),
		["ladder"] = Color3.fromRGB(150, 100, 50),
		["vine_ladder"] = Color3.fromRGB(60, 120, 60),
		["scaffold"] = Color3.fromRGB(180, 140, 100),
		["christmas_scaffold"] = Color3.fromRGB(180, 140, 100),
		["drawbridge"] = Color3.fromRGB(150, 110, 70),
		["christmas_drawbridge"] = Color3.fromRGB(150, 110, 70),
		["haybale"] = Color3.fromRGB(230, 200, 100),
		["purple_hay_bale"] = Color3.fromRGB(180, 50, 255),
	}

	local cachedColors = {}

	local function getBlockColor(blockName)
		if cachedColors[blockName] then
			return cachedColors[blockName]
		end

		if blockColors[blockName] then
			cachedColors[blockName] = blockColors[blockName]
			return blockColors[blockName]
		end

		local lowerName = blockName:lower()

		if blockColors[lowerName] then
			cachedColors[blockName] = blockColors[lowerName]
			return blockColors[lowerName]
		end

		if lowerName:find("wool", 1, true) then
			for key, color in pairs(blockColors) do
				if key:find("wool", 1, true) and lowerName:find(key, 1, true) then
					cachedColors[blockName] = color
					return color
				end
			end
			cachedColors[blockName] = blockColors["wool"]
			return blockColors["wool"]
		end

		if lowerName:find("clay", 1, true) then
			for key, color in pairs(blockColors) do
				if key:find("clay", 1, true) and lowerName:find(key, 1, true) then
					cachedColors[blockName] = color
					return color
				end
			end
			cachedColors[blockName] = blockColors["clay"]
			return blockColors["clay"]
		end

		for name, color in pairs(blockColors) do
			if lowerName:find(name, 1, true) then
				cachedColors[blockName] = color
				return color
			end
		end

		local defaultColor = Color3.fromRGB(150, 150, 150)
		cachedColors[blockName] = defaultColor
		return defaultColor
	end

	local function cleanupDeadReferences()
		for block, _ in pairs(originalProperties) do
			if not block or not block.Parent then
				originalProperties[block] = nil
				processedBlocks[block] = nil
			end
		end
	end

	local function simplifyBlock(block)
		if not block or not block.Parent or processedBlocks[block] then return end

		if not originalProperties[block] then
			originalProperties[block] = {
				Material = block.Material,
				Color = block.Color,
				TextureID = block:IsA("MeshPart") and block.TextureID or nil,
				Textures = {}
			}

			for _, child in block:GetChildren() do
				if child:IsA("Texture") or child:IsA("Decal") then
					table.insert(originalProperties[block].Textures, {
						Class = child.ClassName,
						Texture = child.Texture,
						StudsPerTileU = child:IsA("Texture") and child.StudsPerTileU or nil,
						StudsPerTileV = child:IsA("Texture") and child.StudsPerTileV or nil,
						Face = child.Face,
						Transparency = child.Transparency,
						Color3 = child:IsA("Decal") and child.Color3 or nil
					})
				end
			end
		end

		block.Material = Enum.Material.SmoothPlastic
		block.Color = getBlockColor(block.Name)

		for _, child in block:GetChildren() do
			if child:IsA("Texture") or child:IsA("Decal") then
				child:Destroy()
			end
		end

		if block:IsA("MeshPart") and block.TextureID ~= "" then
			block.TextureID = ""
		end

		processedBlocks[block] = true
	end

	local function restoreBlock(block)
		if not block or not block.Parent then
			originalProperties[block] = nil
			processedBlocks[block] = nil
			return
		end

		local props = originalProperties[block]
		if not props then return end

		block.Material = props.Material or Enum.Material.Plastic
		block.Color = props.Color or Color3.fromRGB(255, 255, 255)

		if props.TextureID and block:IsA("MeshPart") then
			block.TextureID = props.TextureID
		end

		for _, textureProps in props.Textures do
			local newTexture
			if textureProps.Class == "Texture" then
				newTexture = Instance.new("Texture")
				newTexture.StudsPerTileU = textureProps.StudsPerTileU or 1
				newTexture.StudsPerTileV = textureProps.StudsPerTileV or 1
			else
				newTexture = Instance.new("Decal")
				newTexture.Color3 = textureProps.Color3 or Color3.fromRGB(255, 255, 255)
			end

			newTexture.Texture = textureProps.Texture or ""
			newTexture.Face = textureProps.Face or Enum.NormalId.Front
			newTexture.Transparency = textureProps.Transparency or 0
			newTexture.Parent = block
		end

		originalProperties[block] = nil
		processedBlocks[block] = nil
	end

	local function isTargetBlock(obj)
		if not obj:IsA("BasePart") then return false end

		local name = obj.Name

		if blockColors[name] then return true end

		local lowerName = name:lower()
		return lowerName:find("wool", 1, true) or
		       lowerName:find("clay", 1, true) or
		       lowerName:find("wood", 1, true) or
		       lowerName:find("log", 1, true) or
		       lowerName:find("stone", 1, true) or
		       lowerName:find("brick", 1, true) or
		       lowerName:find("glass", 1, true) or
		       lowerName:find("plank", 1, true) or
		       lowerName:find("bed", 1, true) or
		       lowerName:find("obsidian", 1, true) or
		       lowerName:find("sand", 1, true) or
		       lowerName:find("tnt", 1, true) or
		       lowerName:find("barrier", 1, true) or
		       lowerName:find("magic", 1, true) or
		       lowerName:find("concrete", 1, true) or
		       lowerName:find("diamond", 1, true) or
		       lowerName:find("emerald", 1, true) or
		       lowerName:find("iron", 1, true) or
		       lowerName:find("gold", 1, true) or
		       lowerName:find("copper", 1, true) or
		       lowerName:find("steel", 1, true) or
		       lowerName:find("ore", 1, true) or
		       lowerName:find("marble", 1, true) or
		       lowerName:find("slate", 1, true) or
		       lowerName:find("granite", 1, true) or
		       lowerName:find("andesite", 1, true) or
		       lowerName:find("diorite", 1, true) or
		       lowerName:find("grass", 1, true) or
		       lowerName:find("dirt", 1, true) or
		       lowerName:find("ice", 1, true) or
		       lowerName:find("snow", 1, true) or
		       lowerName:find("moss", 1, true) or
		       lowerName:find("slime", 1, true) or
		       lowerName:find("scaffold", 1, true) or
		       lowerName:find("ladder", 1, true) or
		       lowerName:find("tile", 1, true) or
		       lowerName:find("cotton_candy", 1, true) or
		       lowerName:find("_block", 1, true) or
		       obj:IsA("Seat")
	end

	local function processExistingBlocks(simplify)
		scanDescendants(workspace, function(obj)
			if isTargetBlock(obj) then
				if simplify then
					simplifyBlock(obj)
				else
					restoreBlock(obj)
				end
			end
		end)

		if not simplify then
			task.delay(2, cleanupDeadReferences)
		end
	end

	local function setupBlockMonitor(simplify)
		for _, conn in blockMonitorConnections do
			conn:Disconnect()
		end
		table.clear(blockMonitorConnections)

		if not simplify then return end

		local mainConn = workspace.DescendantAdded:Connect(function(descendant)
			if isTargetBlock(descendant) then
				task.defer(function()
					if descendant and descendant.Parent then
						simplifyBlock(descendant)
					end
				end)
			end
		end)

		table.insert(blockMonitorConnections, mainConn)

		local lastCleanup = 0
		local cleanupConn = runService.Heartbeat:Connect(function()
			local now = tick()
			if now - lastCleanup >= 5 then
				lastCleanup = now
				cleanupDeadReferences()
			end
		end)

		table.insert(blockMonitorConnections, cleanupConn)
	end

	local ntReference = {}
	local function ntRemember(obj, property)
		local props = ntReference[obj]
		if not props then
			props = {}
			ntReference[obj] = props
		end
		if props[property] == nil then
			props[property] = obj[property]
		end
	end
	local function ntStrip(obj)
		if obj:IsA('Decal') then
			ntRemember(obj, 'Transparency')
			obj.Transparency = 1
			return
		end
		if obj:IsA('SurfaceAppearance') then
			ntRemember(obj, 'Parent')
			obj.Parent = nil
			return
		end
		if obj:IsA('SpecialMesh') then
			ntRemember(obj, 'TextureId')
			obj.TextureId = ''
			return
		end
		if obj:IsA('BasePart') then
			if obj:IsA('MeshPart') then
				ntRemember(obj, 'TextureID')
				obj.TextureID = ''
			end
			ntRemember(obj, 'Material')
			obj.Material = Enum.Material.SmoothPlastic
		end
	end
	local function ntRestore()
		for i, v in ntReference do
			pcall(function()
				for property, value in v do
					i[property] = value
				end
			end)
		end
		table.clear(ntReference)
	end
	local function ntScan()
		local descendants = store.map:GetDescendants()
		for i, v in descendants do
			if not PotatoMode.Enabled or Mode.Value ~= 'No Texture' then return end
			ntStrip(v)
			if i % 500 == 0 then
				task.wait()
			end
		end
	end

	PotatoMode = vape.Categories.World:CreateModule({
		Name = 'PotatoMode',
		Function = function(callback)
			if callback then
				if Mode.Value == 'No Texture' then
					repeat task.wait() until store.map or not PotatoMode.Enabled
					if not PotatoMode.Enabled then return end
					PotatoMode:Clean(store.map.DescendantAdded:Connect(function(obj)
						task.defer(ntStrip, obj)
					end))
					ntScan()
				else
					processExistingBlocks(true)
					setupBlockMonitor(true)
				end
			else
				processExistingBlocks(false)
				for _, conn in blockMonitorConnections do
					conn:Disconnect()
				end
				table.clear(blockMonitorConnections)
				table.clear(cachedColors)
				cleanupDeadReferences()
				ntRestore()
			end
		end,
	})
	Mode = PotatoMode:CreateDropdown({
		Name = 'Mode',
		List = {'Original', 'No Texture'},
		Default = 'Original',
		Tooltip = 'Original = flat colored blocks, No Texture = strips everything off the map',
		Function = function(val)
			if PotatoMode.Enabled then
				PotatoMode:Toggle()
				PotatoMode:Toggle()
			end
		end
	})
end)
run(function()
	local AutoGrimReaper
	local Range
	local Delay
	local collectionActive = false

	local function startLoop()
		if collectionActive then return end
		collectionActive = true
		task.spawn(function()
			repeat task.wait() until Range and Delay
			while AutoGrimReaper.Enabled and collectionActive do
				if not entitylib.isAlive then
					task.wait(0.5)
					continue
				end
				local controller = bedwars.GrimReaperController
				if not controller or not controller.soulsByPosition then
					task.wait(0.2)
					continue
				end
				local localPosition = entitylib.character.RootPart.Position
				local range = Range.Value
				local char = lplr.Character
				local health = char and char:GetAttribute('Health')
				local maxHealth = char and char:GetAttribute('MaxHealth')
				local lowHealth = health and maxHealth and health <= (maxHealth / 4) and not char:GetAttribute('GrimReaperChannel')
				if lowHealth then
					for _, v in controller.soulsByPosition do
						if not AutoGrimReaper.Enabled or not collectionActive then break end
						if typeof(v) == 'Instance' then
							local part = not v:IsA('Model') and v or v.PrimaryPart
							if part and (localPosition - part.Position).Magnitude <= range then
								local secret = v:GetAttribute('GrimReaperSoulSecret')
								if secret then
									pcall(function()
										bedwars.Client:Get(remotes.ConsumeSoul):CallServer({ secret = secret })
									end)
									if Delay.Value > 0 then
										task.wait(Delay.Value)
									end
								end
							end
						end
					end
				end
				task.wait(0.1)
			end
			collectionActive = false
		end)
	end

	AutoGrimReaper = vape.Categories.Kits:CreateModule({
		Name = 'AutoGrimReaper',
		Function = function(callback)
			if callback then
				startLoop()
			else
				collectionActive = false
			end
		end,
		Tooltip = 'auto eats souls when ur hp is low'
	})
	Range = AutoGrimReaper:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 150,
		Default = 120
	})
	Delay = AutoGrimReaper:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.1,
		Decimal = 100,
		Suffix = 's'
	})
end)
run(function()
	local FPSBooster
	local Cosmetics
	local Animations
	local Clouds
	local Quality
	local Shadows
	local Post
	local Water
	local Kill
	local Visualizer
	local Particles
	local Nametags
	local Compatibility
	local hidden = {}
	local watching = setmetatable({}, {__mode = 'k'})
	local effects = {}
	local killeffects, visualizers, particlesold = {}, {}, {}
	local waterold
	local qualityold
	local shadowsold
	local technologyold
	local nametagold
	local posthook
	local particlehook
	local particleclasses = {'ParticleEmitter', 'Trail', 'Beam', 'Smoke', 'Fire', 'Sparkles'}
	
	local function silenceParticle(obj)
		if not table.find(particleclasses, obj.ClassName) or particlesold[obj] ~= nil or obj.Parent and obj.Parent.Name == 'ProjectileTargeting' then return end
		particlesold[obj] = obj.Enabled
		obj.Enabled = false
	end
	
	local function stripEffect(effect)
		if effects[effect] ~= nil then return end
		for _, v in vape.BlurEffects or {} do
			if v == effect then return end
		end
	
		if effect:IsA('PostEffect') then
			effects[effect] = effect.Enabled
			effect.Enabled = false
		elseif effect:IsA('Atmosphere') then
			effects[effect] = effect.Density
			effect.Density = 0
		end
	end
	
	local function setSpeed(speed)
		for _, v in entitylib.List do
			if v.Player ~= lplr then
				local humanoid = v.Character:FindFirstChildWhichIsA('Humanoid')
				local animator = humanoid and humanoid:FindFirstChildWhichIsA('Animator')
				for _, v2 in animator and animator:GetPlayingAnimationTracks() or {} do
					v2:AdjustSpeed(speed)
				end
			end
		end
	end
	
	local function Added(ent)
		if not Cosmetics.Enabled or ent.Player == lplr then return end
	
		for _, v in ent.Character:GetChildren() do
			if v.Name == 'Clothing' or v.Name == '3DClothing' then
				hidden[v] = v.Parent
				v.Parent = nil
			end
		end
	
		if not watching[ent.Character] then
			watching[ent.Character] = ent.Character.ChildAdded:Connect(function(obj)
				if FPSBooster.Enabled and Cosmetics.Enabled and (obj.Name == 'Clothing' or obj.Name == '3DClothing') then
					task.defer(function()
						if FPSBooster.Enabled and Cosmetics.Enabled and obj.Parent == ent.Character then
							hidden[obj] = ent.Character
							obj.Parent = nil
						end
					end)
				end
			end)
		end
	end
	
	local function Removed(ent)
		if watching[ent.Character] then
			watching[ent.Character]:Disconnect()
			watching[ent.Character] = nil
		end
	
		for i, v in hidden do
			if v == ent.Character then
				hidden[i] = nil
			end
		end
	end
	
	FPSBooster = vape.Categories.Render:CreateModule({
		Name = 'FPSBooster 2',
		Function = function(callback)
			if callback then
				if Quality.Enabled then
					pcall(function()
						qualityold = settings().Rendering.QualityLevel
						settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
					end)
				end
	
				if Shadows.Enabled then
					shadowsold = lightingService.GlobalShadows
					lightingService.GlobalShadows = false
				end
	
				if Post.Enabled then
					for _, v in lightingService:GetChildren() do
						stripEffect(v)
					end
	
					posthook = lightingService.ChildAdded:Connect(function(v)
						if FPSBooster.Enabled and Post.Enabled then
							task.defer(stripEffect, v)
						end
					end)
				end
	
				if Water.Enabled then
					waterold = {
						Size = workspace.Terrain.WaterWaveSize,
						Speed = workspace.Terrain.WaterWaveSpeed,
						Reflectance = workspace.Terrain.WaterReflectance,
						Transparency = workspace.Terrain.WaterTransparency
					}
					workspace.Terrain.WaterWaveSize = 0
					workspace.Terrain.WaterWaveSpeed = 0
					workspace.Terrain.WaterReflectance = 0
					workspace.Terrain.WaterTransparency = 1
				end
	
				if Compatibility.Enabled then
					technologyold = lightingService.Technology
					lightingService.Technology = Enum.Technology.Compatibility
				end
	
				if Kill.Enabled then
					for i, v in bedwars.KillEffectController.killEffects do
						if not i:find('Custom') then
							killeffects[i] = v
							bedwars.KillEffectController.killEffects[i] = {
								new = function()
									return {
										onKill = function() end,
										isPlayDefaultKillEffect = function()
											return true
										end
									}
								end
							}
						end
					end
				end
	
				if Visualizer.Enabled then
					for i, v in bedwars.VisualizerUtils do
						visualizers[i] = v
						bedwars.VisualizerUtils[i] = function() end
					end
				end
	
				if Particles.Enabled then
					particlehook = workspace.DescendantAdded:Connect(silenceParticle)
					task.spawn(function()
						local clock = os.clock()
						for _, v in workspace:GetDescendants() do
							silenceParticle(v)
	
							if os.clock() - clock > 0.002 then
								task.wait()
								if not FPSBooster.Enabled or not Particles.Enabled then return end
								clock = os.clock()
							end
						end
					end)
				end
	
				if Nametags.Enabled then
					task.spawn(function()
						repeat task.wait() until store.matchState ~= 0 or not FPSBooster.Enabled
						if not FPSBooster.Enabled or not Nametags.Enabled or not bedwars.AppController then return end
	
						nametagold = bedwars.NametagController.addGameNametag
						bedwars.NametagController.addGameNametag = function() end
						for _, v in bedwars.AppController:getOpenApps() do
							if tostring(v):find('Nametag') then
								bedwars.AppController:closeApp(tostring(v))
							end
						end
					end)
				end
	
				if Clouds.Enabled then
					local clouds = workspace:FindFirstChild('Clouds')
					if clouds then
						hidden[clouds] = clouds.Parent
						clouds.Parent = nil
					end
				end
	
				if Cosmetics.Enabled then
					FPSBooster:Clean(entitylib.Events.EntityAdded:Connect(Added))
					FPSBooster:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
					for _, v in entitylib.List do
						Added(v)
					end
				end
	
				if Animations.Enabled then
					task.spawn(function()
						repeat
							setSpeed(0)
							task.wait(0.5)
						until not FPSBooster.Enabled or not Animations.Enabled
					end)
				end
			else
				if posthook then
					posthook:Disconnect()
					posthook = nil
				end
	
				if particlehook then
					particlehook:Disconnect()
					particlehook = nil
				end
	
				for i, v in effects do
					if i.Parent then
						if i:IsA('Atmosphere') then
							i.Density = v
						else
							i.Enabled = v
						end
					end
				end
				table.clear(effects)
	
				for i, v in killeffects do
					bedwars.KillEffectController.killEffects[i] = v
				end
				table.clear(killeffects)
	
				for i, v in visualizers do
					bedwars.VisualizerUtils[i] = v
				end
				table.clear(visualizers)
	
				for i, v in particlesold do
					if i.Parent then
						i.Enabled = v
					end
				end
				table.clear(particlesold)
	
				if nametagold then
					bedwars.NametagController.addGameNametag = nametagold
					nametagold = nil
				end
	
				if technologyold then
					lightingService.Technology = technologyold
					technologyold = nil
				end
	
				if waterold then
					workspace.Terrain.WaterWaveSize = waterold.Size
					workspace.Terrain.WaterWaveSpeed = waterold.Speed
					workspace.Terrain.WaterReflectance = waterold.Reflectance
					workspace.Terrain.WaterTransparency = waterold.Transparency
					waterold = nil
				end
	
				for _, v in watching do
					v:Disconnect()
				end
				table.clear(watching)
	
				for i, v in hidden do
					if v.Parent then
						i.Parent = v
					end
				end
	
				table.clear(hidden)
				setSpeed(1)
	
				if qualityold then
					pcall(function()
						settings().Rendering.QualityLevel = qualityold
					end)
					qualityold = nil
				end
	
				if shadowsold ~= nil then
					lightingService.GlobalShadows = shadowsold
					shadowsold = nil
				end
			end
		end,
		Tooltip = 'Strips the parts of the scene that actually cost frames'
	})
	
	Cosmetics = FPSBooster:CreateToggle({
		Name = 'Cosmetics',
		Function = function()
			if FPSBooster.Enabled then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides everyone else\'s skins, the biggest win of the four.\nBodies and held items stay visible'
	})
	Animations = FPSBooster:CreateToggle({
		Name = 'Freeze animations',
		Function = function(callback)
			if FPSBooster.Enabled and not callback then
				setSpeed(1)
			end
	
			if FPSBooster.Enabled and callback then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Tooltip = 'Stops everyone else animating, they slide around instead.\nUnverified on your machine, A/B it yourself'
	})
	Clouds = FPSBooster:CreateToggle({
		Name = 'Clouds',
		Function = function()
			if FPSBooster.Enabled then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Removes the cloud decoration, around 700 parts on most maps'
	})
	Quality = FPSBooster:CreateToggle({
		Name = 'Render quality',
		Function = function()
			if FPSBooster.Enabled then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Drops the engine render quality to its lowest level'
	})
	Shadows = FPSBooster:CreateToggle({
		Name = 'Shadows',
		Function = function()
			if FPSBooster.Enabled then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Turns off global shadows'
	})
	Post = FPSBooster:CreateToggle({
		Name = 'Post effects',
		Function = function()
			if FPSBooster.Enabled then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Turns off sun rays, depth of field and colour correction, whole render passes the card does every frame.\nThe GUI blur is left alone'
	})
	Water = FPSBooster:CreateToggle({
		Name = 'Water',
		Function = function()
			if FPSBooster.Enabled then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Flattens terrain water, no waves and no reflection.\nOnly does anything on maps that have water'
	})
	Compatibility = FPSBooster:CreateToggle({
		Name = 'Compatibility lighting',
		Function = function()
			if FPSBooster.Enabled then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Drops the map to compatibility lighting, the cheapest renderer Roblox has'
	})
	Kill = FPSBooster:CreateToggle({
		Name = 'Kill effects',
		Function = function()
			if FPSBooster.Enabled then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Stops other peoples kill effects from playing'
	})
	Visualizer = FPSBooster:CreateToggle({
		Name = 'Visualizer',
		Function = function()
			if FPSBooster.Enabled then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Turns off the games own visual effect helpers'
	})
	Particles = FPSBooster:CreateToggle({
		Name = 'Particles',
		Function = function()
			if FPSBooster.Enabled then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Stops every particle, trail and beam in the map from rendering'
	})
	Nametags = FPSBooster:CreateToggle({
		Name = 'Nametags',
		Function = function()
			if FPSBooster.Enabled then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides the game nametags once the match starts'
	})
end)



run(function()
	local ShadowRemover
	local connections = {}
	local originalShadows = {}
	local processedShadows = {}
	
	local function removeShadow(obj)
		if obj:IsA("BasePart") and not processedShadows[obj] then
			if not originalShadows[obj] then
				originalShadows[obj] = obj.CastShadow
			end
			obj.CastShadow = false
			processedShadows[obj] = true
		end
	end
	
	ShadowRemover = vape.Categories.World:CreateModule({
		Name = 'ShadowRemover',
		Function = function(callback)
			if callback then
				scanDescendants(workspace, removeShadow, ShadowRemover)
				
				local conn = workspace.DescendantAdded:Connect(function(obj)
					if ShadowRemover.Enabled then
						removeShadow(obj)
					end
				end)
				table.insert(connections, conn)
			else
				for obj, shadow in pairs(originalShadows) do
					if obj and obj.Parent then
						pcall(function()
							obj.CastShadow = shadow
						end)
					end
				end
				
				for _, conn in connections do
					conn:Disconnect()
				end
				table.clear(connections)
				table.clear(originalShadows)
				table.clear(processedShadows)
			end
		end,
	})
end)

run(function()
	local RemoveNeon = {Enabled = false}
	local neonConnection
	local safetyLoop
	local originalMaterials = {}
	local processedParts = {}
	local lastCleanup = 0
	
	local function cleanupDeadReferences()
		local count = 0
		for obj, _ in pairs(originalMaterials) do
			if not obj or not obj.Parent then
				originalMaterials[obj] = nil
				processedParts[obj] = nil
			end
			count = count + 1
			if count % 100 == 0 then
				task.wait()
			end
		end
	end
	
	local function removeNeonFromPart(obj)
		if obj:IsA("BasePart") then
			if obj.Material == Enum.Material.Neon then
				if not originalMaterials[obj] then
					originalMaterials[obj] = {
						Material = obj.Material,
						Reflectance = obj.Reflectance
					}
				end
				pcall(function()
					obj.Material = Enum.Material.Plastic
					obj.Reflectance = 0
				end)
			end
		end
	end
	
	local function restoreNeon()
		for obj, data in pairs(originalMaterials) do
			if obj and obj.Parent then
				pcall(function()
					obj.Material = data.Material
					obj.Reflectance = data.Reflectance
				end)
			end
		end
		table.clear(originalMaterials)
		table.clear(processedParts)
	end
	
	local function batchProcessParts(parts, batchSize)
		local count = 0
		for i, part in ipairs(parts) do
			if part and part.Parent then
				removeNeonFromPart(part)
				count = count + 1
			end
			if i % batchSize == 0 then
				task.wait()
			end
		end
		return count
	end
	
	RemoveNeon = vape.Categories.Kits:CreateModule({
		Name = 'RemoveNeon',
		Function = function(callback)
			if callback then
				task.spawn(function()
					local allParts = {}
					scanDescendants(workspace, function(v)
						if v:IsA("BasePart") then
							removeNeonFromPart(v)
						end
					end, RemoveNeon)
				end)
				
				neonConnection = workspace.DescendantAdded:Connect(function(obj)
					if RemoveNeon.Enabled then
						removeNeonFromPart(obj)
					end
				end)
				
				safetyLoop = task.spawn(function()
					while RemoveNeon.Enabled do
						task.wait(30)
						if RemoveNeon.Enabled then
							cleanupDeadReferences()
						end
					end
				end)
			else
				if neonConnection then
					neonConnection:Disconnect()
					neonConnection = nil
				end
				if safetyLoop then
					task.cancel(safetyLoop)
					safetyLoop = nil
				end
				restoreNeon()
			end
		end,
	})
end)
run(function()
    local HellBladeSpam
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Workspace = game:GetService("Workspace")

    local player = Players.LocalPlayer

    local remote = ReplicatedStorage
        :WaitForChild("rbxts_include")
        :WaitForChild("node_modules")
        :WaitForChild("@rbxts")
        :WaitForChild("net")
        :WaitForChild("out")
        :WaitForChild("_NetManaged")
        :WaitForChild("HellBladeRelease")

    local function getWeapon()
        return ReplicatedStorage
            :WaitForChild("Inventories")
            :WaitForChild(player.Name)
            :FindFirstChild("infernal_saber")
    end

    local chargeTime = 67
    local loopDelay = 0.1
    local hideVFX = false

    local mainThread = nil
    local connection = nil

    HellBladeSpam = vape.Categories.Blatant:CreateModule({
        Name = "Instakill",
        Tooltip = "Super sause",
        Function = function(enabled)
            if enabled then
                -- 🔁 MAIN LOOP
                mainThread = task.spawn(function()
                    while HellBladeSpam.Enabled do
                        local weapon = getWeapon()

                        if weapon then
                            remote:FireServer({
                                chargeTime = chargeTime,
                                player = player,
                                weapon = weapon
                            })
                        end

                        task.wait(loopDelay)
                    end
                end)


                connection = Workspace.DescendantAdded:Connect(function(obj)
                    if hideVFX and obj.Name == "InfernalSwordSpin" then
                        obj:Destroy()
                    end
                end)

            else
                if connection then
                    connection:Disconnect()
                    connection = nil
                end
                mainThread = nil
            end
        end
    })

    HellBladeSpam:CreateSlider({
        Name = "Charge Time",
        Min = 0,
        Max = 100,
        Default = 67,
        Function = function(val)
            chargeTime = val
        end
    })

    HellBladeSpam:CreateSlider({
        Name = "Loop Delay",
        Min = 0.001,
        Max = 1,
        Default = 0.1,
        Decimal = 2,
        Function = function(val)
            loopDelay = val
        end
    })

    HellBladeSpam:CreateToggle({
        Name = "Hide VFX",
        Default = false,
        Function = function(val)
            hideVFX = val
        end
    })
end)
