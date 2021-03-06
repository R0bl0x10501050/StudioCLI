-- Commands.lua

RBX_VERSION = "2.0.0"
GIT_VERSION = "1.0.0"

local REGISTRY = {
	-- Test
	['TEST']			= 7406422890,					-- Testing module, by R0bl0x10501050
	
	-- Beta Stage Modules
	['COLORPLUS']		= 7200837815, 					-- Created by @R0bl0x10501050 | https://devforum.roblox.com/t/colorplus-a-color3-library/1391617
	['ROQUERY']			= 7128769023, 					-- Created by @R0bl0x10501050 | https://devforum.roblox.com/t/roquery-do-more-with-your-code/1364337
	['FPSSETTER']		= 7020204992, 					-- Created by @R0bl0x10501050 | https://devforum.roblox.com/t/fpssetter-set-players-fps/1319561
	['RCONSOLE']		= 6794533185, 					-- Created by @R0bl0x10501050 | https://devforum.roblox.com/t/rconsole-js-console-in-roblox/1215944
	['CONVERT']			= 6183613353, 					-- Created by @R0bl0x10501050 | https://devforum.roblox.com/t/convert-easy-ways-to-convert-different-values/960291
	
	['REPLICASERVICE'] 	= 6015318619,					-- Created by @loleris | https://devforum.roblox.com/t/replicate-your-states-with-replicaservice-networking-system/894736
	['PROFILESERVICE'] 	= 5331689994,					-- Created by @loleris | https://devforum.roblox.com/t/save-your-player-data-with-profileservice-datastore-module/667805
	
	['MATHEVALUATOR'] 	= 7323648466, 					-- Created by @AstrealDev | https://devforum.roblox.com/t/mathevaluator-evaluate-mathematical-expressions-at-runtime/1435728
	
	['FASTSIGNAL'] 		= 6532460357, 					-- Created by @LucasMZ_RBX | https://devforum.roblox.com/t/fastsignal-create-custom-events/1360042
	['BADGESERVICE3']	= 6525256722,					-- Created by @LucasMZ_RBX | https://devforum.roblox.com/t/badgeservice3-set-up-badges-for-free-in-your-project/1112765
	
	-- Version 1.0.0 Modules
	['CUTSCENE']		= 5539329435,					-- Created by @Vaschex | https://devforum.roblox.com/t/cutsceneservice-smooth-cutscenes-using-bezier-curves/718571
	
	-- Version 1.1.0 Modules
	-- :(
	
	-- Version 1.2.0 Modules
	-- :(
	
	-- Version 1.3.0 Modules
}

local PLUGIN_OPTIONS = {
	"colors"
}

-----------------------------------------------------------------------------------------------------------------

local SERVICES = {
	['MarketplaceService'] = game:GetService("MarketplaceService"),
	['StudioService'] = game:GetService("StudioService"),
	['InsertService'] = game:GetService("InsertService"),
	['HttpService'] = game:GetService("HttpService")
}

local Request = require(script.Request)
local HashLib = require(script.HashLib)
local Octokit = require(script.OctokitLua)

local allowedGameChildren
local isRojoMainLoopAlive = false

allowedGameChildren = {game.Workspace, game.Players, game.Lighting, game.ReplicatedFirst, game.ReplicatedStorage, game.ServerScriptService, game.ServerStorage, game.StarterGui, game.StarterPack, game.StarterPlayer, game.SoundService, game.Chat}

local VARIABLES = {}
local PLUGINDATA = {
	HasCodeWidget = false
}

local function refreshVars(self)
	VARIABLES = {
		HOME = "game",
		PATH = self.PATH == game and "game" or "game/"..self.PATH:GetFullName():gsub("%.", "/"),
		OLDPATH = (self.PREVIOUS_PATH or game) == game and "game" or "game/"..(self.PREVIOUS_PATH or game):GetFullName():gsub("%.", "/"),
		EXEPATH = self.EXEPATH or "ServerStorage/bin"
	}
	
	for k, v in pairs(self) do
		if table.find(self.blacklistedVariables, k:lower()) then continue end
		VARIABLES[k:upper()] = v
	end
end

local function parseFileMetadata(file, isRojoProject)
	local isDotFile = false
	
	local RojoIndex = {
		'%.server%.lua$',
		'%.client%.lua$',
		'%.lua$'
	}
	
	local RojoNames = {
		['%.server%.lua$'] = 'Script',
		['%.client%.lua$'] = 'LocalScript',
		['%.lua$'] = 'ModuleScript'
	}
	
	if file.path:match("^.") == "." and file.mode == "100644" and file['type'] == "blob" then
		return "ModuleScript", file.path
	elseif file.path:find(".") and file['type'] == "blob" then
		if file.mode == "100644" then
			if isRojoProject then
				for _, extension in ipairs(RojoIndex) do
					if file.path:match(extension) then
						return RojoNames[extension], file.path:split(".")[1] or RojoNames[extension]
					end
				end
				
				return nil, nil
			else
				return "Script", file.path:split(".")[1] or "Script"
			end
		end
	--elseif file.mode == "040000" and file['type'] == "tree" then	
		-- this shouldn't happen
	else
		return nil, nil
	end
end

local function make_local_repo(parent)
	Instance.new("Folder", parent).Name = "hooks"
	Instance.new("Folder", parent).Name = "objects"
	Instance.new("Folder", parent).Name = "refs"
	Instance.new("Folder", parent.refs).Name = "heads"
	Instance.new("Folder", parent.refs).Name = "tags"
	Instance.new("Folder", parent.refs.heads).Name = "main"
end

local function repo_check()
	local localRepository = game.ServerStorage:FindFirstChild('.git')
	if not localRepository then
		localRepository = Instance.new("Folder", game.ReplicatedStorage)
		localRepository.Name = '.git'
		make_local_repo(localRepository)
	end
	return localRepository
end

local function getChild(parent, name)
	local ITERABLE_TABLE
	
	if parent ~= game then
		ITERABLE_TABLE = parent:GetChildren()
	else
		ITERABLE_TABLE = allowedGameChildren
	end
	
	for _, vv in ipairs(ITERABLE_TABLE) do
		if string.lower(vv.Name) == string.lower(name) then
			return vv
		end
	end
end

local function getInstanceFromPath(parent, path)
	if parent == nil then return nil end
	
	local split = string.split(path, "/")
	
	for k, v in ipairs(split) do
		if v == ".." then
			parent = parent.Parent
			continue
		elseif v == "." then
			continue
		elseif v == "~" then
			parent = workspace
		elseif v == "" and k == 1 then
			parent = game
		end
		parent = getChild(parent, v)
	end
	
	return parent
end

local function getInstanceFromName(name)
	local split, instance = string.split(name, "."), game
	
	for _, v in ipairs(split) do
		instance = getChild(instance, v)
	end
	
	return instance
end

return {
	
	-- I'll keep these here if you are experiencing problems and want to investigate.
	['test'] = function(self, regular, args, flags)
		print(regular)
		print(args)
		print(flags)
	end,
	
	['test2'] = {
		"Hello testing!",
		function(self, regular, args, flags)
			print(regular)
			print(args)
			print(flags)
		end
	},
	
	-- CUSTOM COMMANDS
	
	['toggle'] = function(self, regular, args, flags)
		if (not regular[1]) or (type(regular[1]) ~= "string") then return end
		if table.find(PLUGIN_OPTIONS, regular[1]:lower()) then
			self.OPTIONS[regular[1]:lower()] = not self.OPTIONS[regular[1]:lower()]
		end
	end,
	
	['preview'] = function(self, regular, args, flags)
		if regular[1] then
			local rbxid = "rbxassetid://"..regular[1]
			local info = SERVICES.MarketplaceService:GetProductInfo(regular[1])
			local asset_type = info['AssetTypeId']
			
			local function make_gui()
				local widgetInfo = DockWidgetPluginGuiInfo.new(
					Enum.InitialDockState.Float,  -- This is the initial dockstate of the widget
					true,  -- Initial state, enabled or not
					false,  -- Can override previous state?
					960,    -- Default width
					540,    -- Default height
					240,    -- Minimum width
					135     -- Minimum height
				)
				
				local widget = self.plugin:CreateDockWidgetPluginGui(math.random(0,999999999)..regular[1], widgetInfo)
				
				widget:BindToClose(function()
					widget:Destroy()
				end)
				
				return widget
			end
			
			if asset_type == 1 then
				local widget = make_gui()
				local frame = Instance.new("Frame", widget)
				frame.BackgroundColor3 = Color3.fromRGB(53, 53, 53)
				frame.Size = UDim2.fromScale(1,1)
				local image = Instance.new("ImageLabel", frame)
				image.BorderSizePixel = 0
				image.BackgroundTransparency = 1
				image.Position = UDim2.fromScale(0,0)
				image.Size = UDim2.fromScale(1,1)
				image.Image = rbxid
				image.ScaleType = Enum.ScaleType.Fit
			elseif asset_type == 2 then
				local widget = make_gui()
				local frame = Instance.new("Frame", widget)
				frame.BackgroundColor3 = Color3.fromRGB(53, 53, 53)
				frame.Size = UDim2.fromScale(1,1)
				local video = Instance.new("VideoFrame", frame)
				video.BorderSizePixel = 0
				video.BackgroundTransparency = 1
				video.Position = UDim2.fromScale(0,0)
				video.Size = UDim2.new(1,0,1,0)
				video.Video = rbxid
			end
		end
	end,
	
	['rojo'] = {
		['connect'] = function(self, regular, args, flags)
			if true then return nil end
			local host, port = args['host'] or "localhost", args['port'] or "34872"
			local baseURL = string.format("http://%s:%s", host, port)
			
			-- Check
			local s, e = pcall(function()
				return game.HttpService:RequestAsync({Url = baseURL.."/api/rojo", Method = "GET"})
			end)
			
			if not s then
				self:NewMsg("You have not started Rojo yet!")
				self:NewMsg("You can start Rojo with 'rojo serve' in your editor's terminal")
			end
			
			-- Main
			local function safeGet(url_path)
				local s, e = pcall(function()
					return SERVICES.HttpService:GetAsync(baseURL..url_path)
				end)
				
				return s and e
			end
			
			local apiData = SERVICES.HttpService:JSONDecode(e.Body)
			local rojoVersion = apiData['serverVersion']
			local rootID = apiData['rootInstanceId']
			local read_1 = safeGet("/api/read/"..rootID)
			if not read_1 then self:NewMsg("Rojo crashed!") end
			local initialRead = SERVICES.HttpService:JSONDecode(read_1)
			
			local instances = initialRead['instances']
			local messageCursor = 0
			
			isRojoMainLoopAlive = true
			
			local function getInstanceFromRojoId(RojoId: string, onlyPath: boolean?)
				local instances = initialRead['instances']
				local path = ""
				
				local function recurse(id)
					for id, object in pairs(instances) do
						if id == RojoId then
							if object['parent'] then
								path = object['Name'] .. "/" .. path
								recurse(object['parent'])
							end
							return
						end
					end
				end
				
				return (onlyPath or false) and path or getInstanceFromPath(game, path)
			end
			
			local function mainLoop()
				local instances_1 = safeGet("/api/read/"..rootID)
				if not instances_1 then self:NewMsg("Rojo crashed!") end
				instances = SERVICES.HttpService:JSONDecode(instances_1)['instances']
				
				local data_1 = safeGet("/api/subscribe/"..messageCursor)
				if not data_1 then self:NewMsg("Rojo crashed!") end
				local data = SERVICES.HttpService:JSONDecode(data_1)
				
				local messages = data['messages']
				messageCursor = data['messageCursor']
				
				for _, chunk in ipairs(messages) do
					--// Added
					for new_id, new_object in pairs(chunk.added) do
						--local new_path = getInstanceFromRojoId(new_id, true)
						--local split = new_path:split("/")
						--table.remove(split, #split)
						--new_path = table.concat(split, "/")
						
						local instance = Instance.new(new_object['ClassName'])
						
						for property_name, property_value in pairs(new_object['Properties']) do
							if rojoVersion:match("^.") == "7" then
								instance[property_name] = property_value
							else
								instance[property_name] = property_value['Value']
							end
						end
						
						instance.Parent = getInstanceFromRojoId(new_object['Parent'])
					end
					
					--// Removed
					for _, removed_id in ipairs(chunk.removed) do
						local to_be_removed = getInstanceFromRojoId(removed_id)
						if to_be_removed then to_be_removed:Destroy() end
					end
					
					--// Updated
					for _, updated_object in ipairs(chunk.updated) do
						local instance = getInstanceFromRojoId(updated_object['id'])
						
						-- Name
						
						-- ClassName
						
						-- Properties
						for property_name, property_value in pairs(updated_object['changedProperties']) do
							if rojoVersion:match("^.") == "7" then
								instance[property_name] = property_value
							else
								instance[property_name] = property_value['Value']
							end
						end
						
						-- Metadata
					end
					
				end
				
				if isRojoMainLoopAlive then
					task.wait(1)
					mainLoop()
				else
					coroutine.yield()
				end
			end
			
			coroutine.wrap(function()
				mainLoop()
			end)()
		end,
		['disconnect'] = function(self)
			if true then return nil end
			isRojoMainLoopAlive = false
			self:NewMsg("Exited Rojo sync successfully")
		end,
	},
	
	['code'] = function(self, regular, args, flags)
		if regular[1] then
			local widgetInfo = DockWidgetPluginGuiInfo.new(
				Enum.InitialDockState.Float,  -- Widget will be initialized in floating panel
				false,   -- Widget will be initially enabled
				false,  -- Don't override the previous enabled state
				450,    -- Default width of the floating window
				600,    -- Default height of the floating window
				450,    -- Minimum width of the floating window
				600     -- Minimum height of the floating window
			)
			
			local CodeWidget, existed
			
			if not PLUGINDATA.HasCodeWidget then
				CodeWidget = self.plugin:CreateDockWidgetPluginGui("CodeWidget", widgetInfo)
				CodeWidget.Title = "Roblox VSCode"
				CodeWidget.Enabled = true
				PLUGINDATA.HasCodeWidget = CodeWidget
			else
				CodeWidget = PLUGINDATA.HasCodeWidget
				CodeWidget.Enabled = true
				if CodeWidget.VSCode then CodeWidget.VSCode:Destroy() end
			end
			
			script.Parent:WaitForChild("Misc").VSCode:Clone().Parent = CodeWidget
			
			local directory = getInstanceFromPath(self.PATH, regular[1])
			local frame = CodeWidget.VSCode
			
			if not directory then
				CodeWidget.Enabled = false
				self:NewMsg("Provide a valid directory!")
				return
			end
			
			for _, v in ipairs(frame.Screens.Files.FileList:GetChildren()) do
				v:Destroy()
			end
			
			for _, v in ipairs(frame.Screens.Files.ArrowList:GetChildren()) do
				v:Destroy()
			end
			
			for _, v in ipairs(frame.Sidebar:GetChildren()) do
				if v:IsA("UIGridLayout") then continue end
				
				v.TextButton.MouseEnter:Connect(function()
					v.ImageLabel.ImageColor3 = Color3.fromRGB(170, 179, 194)
				end)
				
				v.TextButton.MouseLeave:Connect(function()
					if frame.Screens:FindFirstChild(v.Name) and frame.Screens:FindFirstChild(v.Name).Visible  == true then return end
					v.ImageLabel.ImageColor3 = Color3.fromRGB(111, 117, 127)
				end)
				
				v.TextButton.MouseButton1Click:Connect(function()
					if frame.Screens:FindFirstChild(v.Name) and frame.Screens:FindFirstChild(v.Name).Visible ~= true then
						for _, vv in ipairs(frame.Screens:GetChildren()) do
							vv.Visible = false
						end
						frame.Screens:FindFirstChild(v.Name).Visible = true
						for _, vvv in ipairs(frame.Sidebar:GetChildren()) do
							if vvv:IsA("UIGridLayout") then continue end
							vvv.ImageLabel.ImageColor3 = Color3.fromRGB(111, 117, 127)
						end
						v.ImageLabel.ImageColor3 = Color3.fromRGB(223, 236, 255)
					end
				end)
			end
			
			--// Files
			local files = frame.Screens.Files
			local depth = 0
			
			local function newEntry(instance, name: string?)
				local isFolder = instance:IsA("Folder")
				local offsetX, disabled = nil, false
				
				if not isFolder then
					if instance:IsA("LocalScript") then
						disabled = instance.Disabled
						offsetX = 288
					elseif instance:IsA("Script") then
						disabled = instance.Disabled
						offsetX = 96
					elseif instance:IsA("ModuleScript") then
						offsetX = 1216
					else
						print(instance.ClassName)
					end
				else
					offsetX = 1232
				end
				
				local parent = Instance.new("Frame", files.FileList)
				parent.BackgroundColor3 = Color3.fromRGB(255,255,255)
				parent.BackgroundTransparency = 1
				parent.BorderSizePixel = 0
				parent.Name = isFolder and instance.Name or instance.Name..".lua"
				parent.Position = isFolder and UDim2.new(0, depth*20, 0, (#files.FileList:GetChildren() - 1)*22) or UDim2.new(0, depth*20, 0, (#files.FileList:GetChildren() - 1)*22)
				parent.Size = UDim2.new(1, 0, 0, 22)
				parent.ZIndex = 2
				
				local icon = Instance.new("ImageLabel", parent)
				icon.BackgroundColor3 = Color3.fromRGB(255,255,255)
				icon.BackgroundTransparency = 1
				icon.BorderSizePixel = 0
				icon.Name = "Icon"
				icon.Position = UDim2.new(0, 4, 0, 3)
				icon.Size = UDim2.new(0, 18, 0, 18)
				icon.Image = "rbxasset://textures/ClassImages.png"
				icon.ImageRectOffset = Vector2.new(offsetX, 0)
				icon.ImageRectSize = Vector2.new(16, 16)
				icon.ScaleType = Enum.ScaleType.Fit
				icon.ZIndex = 2
				
				local name = Instance.new("TextLabel", parent)
				name.BackgroundColor3 = Color3.fromRGB(255,255,255)
				name.BackgroundTransparency = 1
				name.BorderSizePixel = 0
				name.Font = Enum.Font.SourceSansLight
				name.Name = "Name"
				name.Text = instance.Name
				name.TextColor3 = Color3.fromRGB(208, 208, 208)
				name.TextScaled = true
				name.TextXAlignment = Enum.TextXAlignment.Left
				name.Position = UDim2.new(0.1, 0, 0.05, 0)
				name.Size = UDim2.new(0.85, 0, 0.9, 0)
				name.ZIndex = 2
				
				if not isFolder then
					local button = Instance.new("TextButton", parent)
					button.BackgroundTransparency = 1
					button.BackgroundColor3 = Color3.new(0.756863, 0.85098, 1)
					button.BorderSizePixel = 0
					button.Text = ""
					button.Size = UDim2.new(1, 0, 1, 0)
					button.ZIndex = 1
					
					button.MouseEnter:Connect(function()
						button.BackgroundTransparency = 0.75
					end)
					
					button.MouseLeave:Connect(function()
						button.BackgroundTransparency = 1
					end)
					
					button.MouseButton1Click:Connect(function()
						self.plugin:OpenScript(instance)
					end)
				end
				
				if disabled then
					icon.ImageColor3 = Color3.new(0.67451, 0.67451, 0.67451)
					name.TextColor3 = Color3.new(0.745098, 0.745098, 0.745098)
				end
			end
			
			files.FolderName.Text = (directory and directory.Name) and directory.Name:upper() or "FOLDER"
			
			local createUI
			createUI = function(dir)
				for _, child in ipairs(dir:GetChildren()) do
					if (not child:IsA("LuaSourceContainer")) and (not child:IsA("Folder")) then continue end
					newEntry(child)
					if child:IsA("Folder") or child.Parent == game then
						depth += 1
						createUI(child)
						depth -= 1
					end
				end
			end
			
			local function makeSmallButton(button, callback)
				button.MouseEnter:Connect(function()
					button.BackgroundTransparency = 0.75
				end)
				
				button.MouseLeave:Connect(function()
					button.BackgroundTransparency = 1
				end)
				
				button.MouseButton1Click:Connect(callback)
			end
			
			-- Connection
			makeSmallButton(files.FolderName.ImageButton, function()
				for _, v in ipairs(frame.Screens.Files.FileList:GetChildren()) do
					v:Destroy()
				end
				
				for _, v in ipairs(frame.Screens.Files.ArrowList:GetChildren()) do
					v:Destroy()
				end
				
				createUI(directory)
			end)
			
			createUI(directory)
			
			--// Run/Debug
			local rundebug = frame.Screens.RunDebug
			
			rundebug.Run.TextButton.MouseEnter:Connect(function()
				rundebug.Run.BackgroundTransparency = 0.15
			end)
			
			rundebug.Run.TextButton.MouseLeave:Connect(function()
				rundebug.Run.BackgroundTransparency = 0.3
			end)
			
			rundebug.Run.TextButton.MouseButton1Click:Connect(function()
				local active_source = SERVICES.StudioService.ActiveScript and SERVICES.StudioService.ActiveScript.Source or ""
				local source = string.format("return function() %s end", active_source)
				local new_script = Instance.new("ModuleScript", script)
				new_script.Name = "TEMPORARY"..math.random(111111,999999)
				new_script.Source = source
				local s, e = pcall(function()
					return require(new_script)
				end)
				new_script:Destroy()
				local result = type(e) == 'function' and e() or e
				if not s then print(result) end
			end)
		else
			self:NewMsg("You must specify a directory!")
		end
	end,
	
	['decalimg'] = function(self, regular, args, flags)
		-- Convert decal ID to image ID
		if tonumber(regular[1]) then
			local id
			local s, e = pcall(function()
				id = tonumber(string.match(game:GetObjects("rbxassetid://"..regular[1])[1].Texture, "%d+"))
			end)
			if s and tonumber(id) then
				self:NewMsg(id)
			else
				self:NewMsg("Failure to convert id")
			end
		else
			self:NewMsg("Incorrect ID format!")
		end
	end,
	
	-- LANGUAGE
	
	['lua'] = function(self, regular, args, flags)
		self:NewMsg(loadstring(table.concat(regular, " ")))
	end,
	
	-- LIBRARY (a CLI library-ish thing, like npm)
	
	['audio'] = { -- built-in audio player! enjoy :)
		['play'] = function(self, regular, args, flags)
			local audioId = regular[1]
			self.UI.AUDIO.SoundId = "rbxassetid://" .. (tonumber(audioId) and audioId or "0")
			
			if table.find(flags, "l") or args['looped'] then
				self.UI.AUDIO.Looped = true
			end
			
			if args['volume'] and tonumber(args['volume']) then
				self.UI.AUDIO.Volume = tonumber(args['volume']) or 0.5
			end
			
			self.UI.AUDIO:Play()
		end,
		['pause'] = function(self, regular, args, flags)
			if self.UI.AUDIO.IsPlaying then
				self.UI.AUDIO:Pause()
			end
		end,
		['resume'] = function(self, regular, args, flags)
			if self.UI.AUDIO.IsPaused == true then
				self.UI.AUDIO:Resume()
			end
		end,
		['stop'] = function(self, regular, args, flags)
			if self.UI.AUDIO.IsPlaying then
				self.UI.AUDIO:Stop()
			end
		end,
		['reset'] = function(self, regular, args, flags)
			if self.UI.AUDIO.IsPlaying then
				self.UI.AUDIO:Stop()
			end
			self.UI.AUDIO.SoundId = ""
		end,
	},
	
	['http'] = { -- Simple HTTP library for the command line, output is a bit buggy though
		['get'] = function(self, regular, args, flags)
			local link = regular[1]
			local split = link:split("/")[3]:split("%.")
			if split[#split-1] == "roblox" and split[#split] == "com" then
				self:NewMsg("Cannot send request to roblox.com!")
			elseif link:find("http") then
				local output = SERVICES.HttpService:GetAsync(link)
				if output then
					self:NewMsg(output)
				end
			else
				self:NewMsg("Link must be valid!")
			end
		end,
		['post'] = function(self, regular, args, flags)
			local function makeEnum(input)
				if input:lower() == "applicationjson" then
					return Enum.HttpContentType.ApplicationJson
				elseif input:lower() == "applicationxml" then
					return Enum.HttpContentType.ApplicationXml
				elseif input:lower() == "applicationurlencoded" then
					return Enum.HttpContentType.ApplicationUrlEncoded
				elseif input:lower() == "textplain" then
					return Enum.HttpContentType.TextPlain
				elseif input:lower() == "textxml" then
					return Enum.HttpContentType.TextXml
				else
					return Enum.HttpContentType.ApplicationJson
				end
			end
			
			local link = regular[1]
			table.remove(regular, 1)
			local data = table.concat(regular, " ")
			local contentType = args['contentType'] and makeEnum(args['contentType']) or Enum.HttpContentType.ApplicationJson
			local compress = args['compress'] and true or false
			
			local output = SERVICES.HttpService:PostAsync(link, data or "", contentType or Enum.HttpContentType.ApplicationJson, compress or false)
			if output then
				self:NewMsg(output)
			end
		end,
	},
	
	--['generate'] = function(self, regular, args, flags) -- project generator // COMMAND SUSPENDED, it's impossible
	--	local generator = regular[1]
	--	local force = table.find(flags, 'f') or args['force']
	--end,
	
	['git'] = { -- git integration for Roblox!!!!!!!
		['add'] = function(self, regular, args, flags)
			local filename = regular[1]
			local res = getInstanceFromPath(self.PATH, filename)
			
			if res and res ~= game and res:IsA("LuaSourceContainer") then
				local staged = self.plugin:GetSetting("git_staged_"..game.GameId) or {}
				--staged[res:GetFullName()] = staged.Source
				table.insert(staged, {Name = res.Name, FullName = res:GetFullName(), Source = res.Source})
				self.plugin:SetSetting("git_staged_"..game.GameId, staged)
			else
				self:NewMsg("Failed to stage "..filename..".lua")
			end
		end,
		['branch'] = function(self, regular, args, flags)
			if regular[1] then
				local new_branch = Instance.new("Folder", game.ServerStorage['.git'].refs.heads)
				new_branch.Name = regular[1]
				
				-- Remote --
				
				local name, token, repo = nil, nil, self.plugin:GetSetting("git_remote_repo"..game.GameId)
				
				do
					name = self.plugin:GetSetting("git_config_displayname_"..game.GameId)
					if not name then
						name = self.plugin:GetSetting("git_config_displayname_global")
						if not name then
							self:NewMsg("You must set your GitHub username as user.displayname first!")
							return
						end
					end
					
					local test_local = self.plugin:GetSetting("git_config_token_"..game.GameId)
					if test_local and type(test_local) == "string" then
						token = test_local
					else
						local test_global = self.plugin:GetSetting("git_config_token_global")
						if test_global and type(test_global) == "string" then
							token = test_global
						else
							self:NewMsg("No GitHub token available!")
							self:NewMsg("Run \"git config token <token here> -g\"")
						end
					end
				end
				
				local octokit = Octokit.new(token)
				
				--local latest_commit = octokit.request("GET /repos/{name}/{repo}/git/ref/heads/{branch}", {
				--	name = name,
				--	repo = repo,
				--	branch = 'main'
				--})
				
				local new_tree = octokit.request("POST /repos/{name}/{repo}/git/trees", {
					name = name,
					repo = repo
				}, {
					tree = {
						{
							['path'] = "README.md",
							['type'] = "blob",
							['mode'] = "100644",
							['content'] = tostring(repo)
						}
					}
				})
				
				local new_tree_sha = new_tree.sha
				
				--
				
				local new_commit = octokit.request("POST /repos/{name}/{repo}/git/commits", {
					name = name,
					repo = repo
				}, {
					message = "Initial commit",
					tree = new_tree_sha
				})
				
				local new_commit_sha = new_commit.sha
				
				--
				
				local new_ref = octokit.request("POST /repos/{name}/{repo}/git/refs", {
					name = name,
					repo = repo
				}, {
					ref = "refs/heads/"..regular[1],
					sha = new_commit_sha
				})
				
				-- End Remote --
				
				self.plugin:SetSetting("git_branch_current"..game.GameId, regular[1])
			else
				local branches = game.ServerStorage['.git'].refs.heads:GetChildren()
				local current_branch = self.plugin:GetSetting("git_branch_current"..game.GameId) or "main"
				for _, v in ipairs(branches) do
					self:NewMsg(v.Name:lower() == current_branch:lower() and "*"..v.Name or v.Name)
				end
			end
		end,
		['checkout'] = function(self, regular, args, flags)
			if regular[1] then
				if args['remote'] then
					self.plugin:SetSetting("git_remote_repo"..game.GameId, regular[1])
				else
					self.plugin:SetSetting("git_branch_current"..game.GameId, regular[1])
				end
			end
		end,
		['clone'] = function(self, regular, args, flags)
			local raw_repo = regular[1]
			local owner, repo = raw_repo:split("/")[1], raw_repo:split("/")[2]
			local token = nil
			
			do
				local test_local = self.plugin:GetSetting("git_config_token_"..game.GameId)
				if test_local and type(test_local) == "string" then
					token = test_local
				else
					local test_global = self.plugin:GetSetting("git_config_token_global")
					if test_global and type(test_global) == "string" then
						token = test_global
					else
						self:NewMsg("No GitHub token available!")
						self:NewMsg("Run \"git config token <token here> -g\"")
					end
				end
			end
			
			if owner and repo and token then
				local octokit = Octokit.new(token)
				local branches = octokit.request("GET /repos/{owner}/{repo}/branches", {
					owner = owner,
					repo = repo
				})
				local branch = nil
				
				for _, v in ipairs(branches) do
					if v.name == "master" or v.name == "main" then
						branch = v.commit.sha
					end
				end
				
				if branch then
					local commit = octokit.request('GET /repos/{owner}/{repo}/git/commits/{commit_sha}', {
						owner = owner,
						repo = repo,
						commit_sha = branch
					})
					
					if commit then
						local ProjectRootFolder = Instance.new("Folder", self.PATH == game and workspace or self.PATH)
						ProjectRootFolder.Name = repo
						local isRojoProject = false
						local stacks = 0
						
						local function getTreeAndConstructData(sha, parentFolder)
							stacks += 1
							if stacks > 50 then return end
							
							local tree = octokit.request('GET /repos/{owner}/{repo}/git/trees/{tree_sha}', {
								owner = owner,
								repo = repo,
								tree_sha = sha
							})
							
							if tree then
								local file_tree = tree.tree
								
								for _, file in ipairs(file_tree) do
									if file.path:match("%.project%.json$") then
										isRojoProject = true
									end
								end
								
								for _, file in ipairs(file_tree) do
									if file['type'] ~= "tree" then
										local ClassName, Name = parseFileMetadata(file, isRojoProject)
										if ClassName and Name then
											local blob = octokit.request('GET /repos/{owner}/{repo}/git/blobs/{file_sha}', {
												owner = owner,
												repo = repo,
												file_sha = file.sha
											})
											
											if blob then
												local new_file = Instance.new(ClassName, parentFolder)
												new_file.Name = Name
												
												local decoded = nil
												
												if blob.encoding == "base64" then
													decoded = HashLib.base64_to_bin(blob.content)
												--elseif blob.encoding == "utf-8" or blob.encoding == "utf8" then
												end
												
												new_file.Source = decoded
												
												--if file.path:match("^PACKAGE%.lua$") and new_file.Parent == ProjectRootFolder then
												--	local info = require(new_file)
												--	-- Options/configuration settings
												--end
											else
												self:NewMsg("Error when fetching blob")
											end
										end
									else
										local parent = Instance.new("Folder", parentFolder)
										parent.Name = file.path
										getTreeAndConstructData(file.sha, parent)
									end
								end
							else
								if not (table.find(flags, 'f') or args['force']) then
									ProjectRootFolder:Destroy()
								end
								self:NewMsg("Error while fetching tree")
							end
							
							stacks -= 1
						end
						
						local tree_sha = commit.tree.sha
						getTreeAndConstructData(tree_sha, ProjectRootFolder)
					else
						self:NewMsg("Error while fetching latest commit")
					end
				else
					self:NewMsg("\"main\" or \"master\" branch missing, cannot clone")
				end
			else
				self:NewMsg("Failed to reach repository")
			end
		end,
		['commit'] = function(self, regular, args, flags)
			local commit_msg = ""
			if table.find(flags, 'm') and regular[1] and type(regular[1]) == 'string' then
				commit_msg = table.concat(regular, " ")
				commit_msg = commit_msg:gsub("\"", "")
			end
			
			local staged = self.plugin:GetSetting("git_staged_"..game.GameId) or {}
			if table.getn(staged) == 0 then
				self:NewMsg("Nothing to commit!")
			else
				local hexadecimal_commit_id = HashLib.sha256(string.format("%X", Random.new():NextInteger(0, 9999999999999999999999999999)))
				local objects = {}
				local changes = ''
				local parent_folder = Instance.new("Folder", game.ServerStorage['.git'].objects)
				
				for _, v in ipairs(staged) do
					local source = getInstanceFromName(v.FullName).Source or v.Source or ""
					
					changes ..= source
					
					local object = {
						FullName = v.FullName,
						Source = HashLib.base64_encode(source),
						Type = 1
						--[[
						1 - File
						2 - Directory (Folder)
						]]
					}
					
					local text = "return {Source=\""..object.Source.."\",FullName=\""..object.FullName.."\",Type="..object.Type.."}"
					local instance_object = Instance.new("ModuleScript", parent_folder)
					instance_object.Name = HashLib.base64_encode(tostring(#parent_folder:GetChildren()+1))
					instance_object.Source = text
				end
				
				changes = HashLib.sha256(changes)
				
				local algorithm = (self.plugin:GetSetting("git_branch_current"..game.GameId) or "main")..(changes)..(commit_msg)..(hexadecimal_commit_id)
				local hashed_algorithm = HashLib.sha256(algorithm)
				local trimmed_hash = hashed_algorithm:gmatch(".......")() or ""
				
				parent_folder.Name = trimmed_hash
				parent_folder:SetAttribute("Identifier", hashed_algorithm)
				
				local branchRef = game.ServerStorage['.git'].refs.heads[self.plugin:GetSetting("git_branch_current"..game.GameId) or "main"]
				local base_commit
				if not branchRef then
					branchRef = Instance.new("Folder", game.ServerStorage['.git'].refs.heads)
					branchRef.Name = self.plugin:GetSetting("git_branch_current"..game.GameId) or "main"
				end
				
				local commit_object = Instance.new("Model", branchRef)
				commit_object.Name = trimmed_hash
				commit_object:SetAttribute("CommitSHA", hashed_algorithm)
				commit_object:SetAttribute("Order", #branchRef:GetChildren())
				commit_object:SetAttribute("Message", commit_msg)
				
				self.plugin:SetSetting("git_staged_"..game.GameId, {})
				self:NewMsg("Commit <font color=\"rgb(34,195,130)\">"..trimmed_hash.."</font>", true)
				self:NewMsg("<font color=\"rgb(233,233,64)\">"..#staged.."</font> file change(s)", true)
			end
		end,
		['compare'] = function(self, regular, args, flags)
			local commit_1, commit_2 = regular[1], regular[2]
			local parent_folder = game.ServerStorage['.git'].objects
			local commit_1_obj, commit_2_obj
			for _, commit in ipairs(parent_folder:GetChildren()) do
				if commit:GetAttribute("Identifier") == commit_1 then
					commit_1_obj = commit
				elseif commit:GetAttribute("Identifier") == commit_2 then
					commit_2_obj = commit
				end
			end
			if commit_1_obj and commit_2_obj then
				-- local widget = self.plugin:CreateDockWidgetPluginGui("GitCompare")
				local commit_1_objects = commit_1_obj:GetChildren()
				local commit_1_objects_files = {}
				
				for _, v in ipairs(commit_1_objects) do
					local source = require(v)
					commit_1_objects_files[source.FullName] = {}
				end
			elseif commit_1_obj then
				self:NewMsg("Second commit SHA is invalid!")
			elseif commit_2_obj then
				self:NewMsg("First commit SHA is invalid!")
			else
				self:NewMsg("Both commit SHAs are invalid!")
			end
		end,
		['config'] = {
			['displayname'] = function(self, regular, args, flags)
				local plugin_setting = ""
				
				if args['global'] or table.find(flags, 'g') then
					plugin_setting = "git_config_displayname_global"
				else
					plugin_setting = "git_config_displayname_"..game.GameId
				end
				
				if regular[1] then
					self.plugin:SetSetting(plugin_setting, regular[1])
				else
					local displayname = self.plugin:GetSetting(plugin_setting) or "No DisplayName found - "..game.Players:GetNameFromUserIdAsync(game.StudioService:GetUserId())
					if args['print'] then
						print(displayname)
					else
						self:NewMsg(displayname)
					end
				end
			end,
			['token'] = function(self, regular, args, flags)
				local plugin_setting = ""
				
				if args['global'] or table.find(flags, 'g') then
					plugin_setting = "git_config_token_global"
				else
					plugin_setting = "git_config_token_"..game.GameId
				end
				
				if regular[1] then
					self.plugin:SetSetting(plugin_setting, regular[1])
				else
					local token = self.plugin:GetSetting(plugin_setting) or "No token found"
					if args['print'] then
						print(token)
					else
						self:NewMsg(token)
					end
				end
			end,
		},
		['init'] = function(self, regular, args, flags)
			local has_local, has_remote = true, false
			
			if args['remote'] then
				has_local = false
				has_remote = true
			end
			
			if args['both'] then
				has_local = true
				has_remote = true
			end
			
			local function do_local()
				local localRepository = game.ServerStorage:FindFirstChild('.git')
				if localRepository then
					self:NewMsg("A local git repository is already initiated!")
				else
					localRepository = Instance.new("Folder", game.ServerStorage)
					localRepository.Name = '.git'
					make_local_repo(localRepository)
					self.plugin:SetSetting("git_branch_current"..game.GameId, 'main')
				end
			end
		
			local function do_remote()
				local repo_name = regular[1] or game:GetFullName()
				local token = nil
				
				do
					local test_local = self.plugin:GetSetting("git_config_token_"..game.GameId)
					if test_local and type(test_local) == "string" then
						token = test_local
					else
						local test_global = self.plugin:GetSetting("git_config_token_global")
						if test_global and type(test_global) == "string" then
							token = test_global
						else
							self:NewMsg("No GitHub token available!")
							self:NewMsg("Run \"git config token <token here> -g\"")
						end
					end
				end
				
				local octokit = Octokit.new(token)
				
				local repos = octokit.request('GET /user/repos')
				local found = false
				
				for _, repo_found in ipairs(repos) do
					if repo_found.name:lower() == repo_name:lower() then
						found = true
					end
				end
				
				if found == false then
					local data, success = octokit.request("POST /user/repos", {}, {
						name = repo_name,
						['auto_init'] = true
					})
					
					if success then
						self.plugin:SetSetting("git_remote_repo"..game.GameId, repo_name)
					end
				elseif found == true then
					self:NewMsg("A remote repository with this name is already initiated!")
				end
			end
			
			if has_local then
				do_local()
			end
			
			if has_remote then
				do_remote()
			end
		end,
		['push'] = function(self, regular, args, flags)
			local repo = self.plugin:GetSetting("git_remote_repo"..game.GameId)
			
			if repo then
				local token = nil
				
				do
					local test_local = self.plugin:GetSetting("git_config_token_"..game.GameId)
					if test_local and type(test_local) == "string" then
						token = test_local
					else
						local test_global = self.plugin:GetSetting("git_config_token_global")
						if test_global and type(test_global) == "string" then
							token = test_global
						else
							self:NewMsg("No GitHub token available!")
							self:NewMsg("Run \"git config token <token here> -g\"")
						end
					end
				end
				
				local octokit = Octokit.new(token)
				
				-----------------------------------
				
				local name = self.plugin:GetSetting("git_config_displayname_"..game.GameId)
				if not name then
					name = self.plugin:GetSetting("git_config_displayname_global")
					if not name then
						self:NewMsg("You must set your GitHub username as user.displayname first!")
						return
					end
				end
				
				local branch = octokit.request("GET /repos/{name}/{repo}/git/ref/heads/{branch}", {
					name = name,
					repo = repo,
					branch = regular[1]
				})
				
				if not branch then
					self:NewMsg("Error fetching remote branch")
					return
				end
				
				local latest_num, latest_commit, branch_instance = 0, nil, game.ServerStorage['.git'].refs.heads:FindFirstChild(regular[1] or 'main')
				
				if not branch_instance then
					self:NewMsg("Error fetching local branch")
					return
				end
				
				for _, v in ipairs(branch_instance:GetChildren()) do
					local order = v:GetAttribute("Order")
					if order > latest_num then
						latest_num = order
						latest_commit = v
					end
				end
				
				if not latest_commit then
					self:NewMsg("Error fetching latest local commit")
					return
				end
				
				local local_commit_sha, latest_object = latest_commit:GetAttribute("CommitSHA"), nil
				
				for _, v in ipairs(game.ServerStorage['.git'].objects:GetChildren()) do
					if v:GetAttribute("Identifier") == local_commit_sha then
						latest_object = v
					end
				end
				
				if not latest_object then
					self:NewMsg("Error fetching latest local object")
					return
				end
				
				local send_data = {}
				
				for _, v in ipairs(latest_object:GetChildren()) do
					local data = require(v)
					
					-- Path
					local split = data.FullName:split(".")
					local file_name
					
					if split[#split] == "cli" then
						file_name = split[#split-1].."."..split[#split]
						table.remove(split, #split)
						table.remove(split, #split)
					else
						file_name = split[#split]
						table.remove(split, #split)
					end
					
					table.insert(split, file_name..".lua")
					local path = table.concat(split, "/")
					
					-- Type
					local blob_type = data.Type
					
					local type_conversions = {
						['1'] = 'blob',
						['2'] = 'tree'
					}
					
					local mode_conversions = {
						['1'] = '100644',
						['2'] = '040000'
					}
					
					local new_type = type_conversions[tostring(blob_type)] or "blob"
					local new_mode = mode_conversions[tostring(blob_type)] or "100644"
					
					--// End Of Variables
					
					table.insert(send_data, {
						['path'] = path,
						['type'] = new_type,
						['mode'] = new_mode,
						['content'] = HashLib.base64_to_bin(data.Source)
					})
				end
				
				local latest_remote_commit = octokit.request("GET /repos/{name}/{repo}/git/ref/heads/{branch}", {
					name = name,
					repo = repo,
					branch = regular[1]
				})
				
				local old_commit_sha = latest_remote_commit.object.sha
				
				if not (latest_remote_commit and old_commit_sha) then
					self:NewMsg("Error fetching latest remote commit")
					return
				end
				
				local new_tree = octokit.request("POST /repos/{name}/{repo}/git/trees", {
					name = name,
					repo = repo
				}, {
					tree = send_data,
					base_tree = old_commit_sha
				})
				
				local new_tree_sha = new_tree.sha
				
				if not (new_tree and new_tree_sha) then
					self:NewMsg("Error creating new remote tree")
					return
				end
				
				local new_commit = octokit.request("POST /repos/{name}/{repo}/git/commits", {
					name = name,
					repo = repo
				}, {
					message = latest_commit:GetAttribute("Message"),
					tree = new_tree_sha,
					parents = {
						old_commit_sha
					}
				})
				
				local new_commit_sha = new_commit.sha
				
				if not (new_commit and new_commit_sha) then
					self:NewMsg("Error creating new remote commit")
					return
				end
				
				local new_ref = octokit.request("POST /repos/{name}/{repo}/git/refs/heads/{branch}", {
					name = name,
					repo = repo,
					branch = regular[1]
				}, {
					sha = new_commit_sha
				})
				
				if not new_ref then
					self:NewMsg("Error updating remote branch")
					return
				else
					self:NewMsg("Pushed changes to remote repository")
				end
			else
				self:NewMsg("You need to initialize a remote repository first!")
			end
		end,
		['reset'] = function(self, regular, args, flags)
			local filename = regular[1]
			
			if filename then
				local res = getInstanceFromPath(self.PATH, filename)
				
				if res and res ~= game and res:IsA("LuaSourceContainer") then
					local staged = self.plugin:GetSetting("git_staged_"..game.GameId) or {}
					if table.find(staged, res) then
						table.remove(staged, table.find(res))
						self.plugin:SetSetting("git_staged_"..game.GameId, staged)
					end
				else
					self:NewMsg("Failed to unstage "..filename..".lua")
				end
			elseif table.find(flags, 'f') then
				self.plugin:SetSetting("git_staged_"..game.GameId, {})
			else
				self:NewMsg("You must add a 'f' flag to clear staged files")
			end
		end,
		['staged'] = function(self, regular, args, flags)
			local staged = self.plugin:GetSetting("git_staged_"..game.GameId) or {}
			for _, v in ipairs(staged) do
				self:NewMsg('game.'..v.FullName)
			end
		end,
		['version'] = function(self, regular, args, flags)
			self:NewMsg(GIT_VERSION)
		end,
	},
	
	['rbx'] = { -- Package manager, basically npm for Roblox, the commands are literally identical lol
		['cloud'] = function(self, regular, args, flags)
			local url = "https://rbx-cloud.vercel.app/api/users/create?user="..tostring(SERVICES.StudioService:GetUserId())
			local result = SERVICES.HttpService:JSONDecode(SERVICES.HttpService:GetAsync(url))
			local key = result.key
			if (key and tostring(key)) then
				self.plugin:SetSetting("rbx_cloud_key", tostring(key))
			end
		end,
		['ls'] = function(self, regular, args, flags)
			if self.PATH == game then
				self:NewMsg("Cannot list the packages in a DataModel!")
				self:NewMsg("Please 'cd' somewhere to list packages.")
				return
			end
			
			if table.find(flags, 'g') then
				if not game.ReplicatedStorage:FindFirstChild("rbx_modules") then return end
				self:NewMsg("GLOBAL")
				for _, v in ipairs(game.ReplicatedStorage:FindFirstChild("rbx_modules"):GetChildren()) do
					self:NewMsg("| "..v:GetAttribute("rbx_package_ID"))
				end
			else
				self:NewMsg("LOCAL")
				for _, v in ipairs(self.PATH:GetChildren()) do
					if v:GetAttribute("rbx_package_ID") then
						self:NewMsg("| "..v:GetAttribute("rbx_package_ID"))
					end
				end
			end
		end,
		['import'] = function(self, regular, args, flags)
			local directory = self.PATH
			if table.find(flags, "g") or args['global'] then
				directory = game.ReplicatedStorage:FindFirstChild("rbx_modules")
				if not directory then
					directory = Instance.new("Folder", game.ReplicatedStorage)
					directory.Name = "rbx_modules"
				end
			end
			
			for _, file in (SERVICES.StudioService:PromptImportFiles({--[["rbxmx", ]]"lua"})) do
				if file.Name:find(".lua") then
					local importedScript = Instance.new("Script", directory)
					importedScript.Source = file:GetBinaryContents()
				elseif file.Name:find(".rbxmx") then
					-- Finish the XML Decoder
					-- Make this read the raw XML data
					-- and create Instances based on it
				end
			end
		end,
		['info'] = function(self, regular, args, flags)
			local packageName = regular[1]
			local objects
			local packageFile
			local pkgData = {id = "", name = "", pkgVersion = "0.0.1"}
			
			if tonumber(packageName) then
				objects = game:GetObjects("rbxassetid://"..tostring(packageName))
				pkgData.id = tostring(packageName)
				pkgData.name = "NIL"
			elseif REGISTRY[tostring(packageName):upper()] then
				objects = game:GetObjects("rbxassetid://"..tostring(REGISTRY[tostring(packageName):upper()]))
				pkgData.id = tostring(packageName:gsub("%s", "-"))
				pkgData.name = packageName
			end
			
			if objects and objects[1] then
				packageFile = objects[1]:FindFirstChild("PACKAGE")
				
				if packageFile then
					packageFile = require(packageFile)
					if packageFile.id then pkgData.id = packageFile.id end
					if packageFile.name then pkgData.name = packageFile.name end
					if packageFile.pkgVersion then pkgData.pkgVersion = packageFile.pkgVersion end
				end
				
				self:NewMsg(pkgData.name.." ("..pkgData.id..") @"..pkgData.pkgVersion)
			else
				self:NewMsg("Package does not exist!")
			end
			
			objects = nil
			packageFile = nil
			table.clear(pkgData)
		end,
		['init'] = function(self, regular, args, flags)
			if game.ReplicatedStorage:FindFirstChild("PACKAGE") then
				if table.find(flags, "f") then
					game.ReplicatedStorage:FindFirstChild("PACKAGE"):Destroy()
					local packageFile = Instance.new("ModuleScript", game.ReplicatedStorage)
					packageFile.Name = "PACKAGE"
					packageFile.Source = "return {\n\t['name'] = 'my-roblox-game',\n\t['version'] = '0.0.1',\n\t['description'] = 'my roblox game',\n\t['keywords'] = '',\n\t['license'] = 'UNLICENSE',\n\t['author'] = '',\n\t['scripts'] = {},\n\t['bugs'] = {},\n\t['funding'] = {},\n\t['private'] = true,\n}"
				else
					self:NewMsg("A PackageFile already exists! Add the \"-f\" flag to overwrite!")
				end
			else
				local packageFile = Instance.new("ModuleScript", game.ReplicatedStorage)
				packageFile.Name = "PACKAGE"
				packageFile.Source = "return {\n\t['name'] = 'my-roblox-game',\n\t['version'] = '0.0.1',\n\t['description'] = 'my roblox game',\n\t['keywords'] = '',\n\t['license'] = 'UNLICENSE',\n\t['author'] = '',\n\t['scripts'] = {},\n\t['bugs'] = {},\n\t['funding'] = {},\n\t['private'] = true,\n}"
			end
		end,
		['install'] = function(self, regular, args, flags)
			if self.PATH == game then
				self:NewMsg("Cannot install a package into a DataModel!")
				self:NewMsg("Please 'cd' somewhere to install your package.")
				return
			end
			
			local packageName = regular[1]
			
			if tonumber(packageName) then
				--local latestVersion = SERVICES.InsertService:GetLatestAssetVersionAsync(tonumber(packageName))
				--local module = SERVICES.InsertService:LoadAssetVersion(latestVersion):GetChildren()[1]
				local objects = game:GetObjects("rbxassetid://"..tostring(packageName))
				local module = objects[1]
				if table.find(flags, "g") or args['global'] then
					if module then
						if not game.ReplicatedStorage:FindFirstChild("rbx_modules") then
							local rbx_modules = Instance.new("Folder", game.ReplicatedStorage)
							rbx_modules.Name = "rbx_modules"
						end
						module.Parent = game.ReplicatedStorage:FindFirstChild("rbx_modules")
						module:SetAttribute("rbx_package_ID", packageName)
					end
				elseif table.find(flags, "d") or args['dev'] then
					if module then
						module.Parent = self.UI.DEV_MODULES
						module:SetAttribute("rbx_package_ID", packageName)
					end
				else
					if module then
						module.Parent = self.PATH
						module:SetAttribute("rbx_package_ID", packageName)
					end
				end
			else
				if REGISTRY[tostring(packageName):upper()] then
					--local latestVersion = SERVICES.InsertService:GetLatestAssetVersionAsync(REGISTRY[tostring(packageName):upper()])
					--local module = SERVICES.InsertService:LoadAssetVersion(latestVersion):GetChildren()[1]
					local objects = game:GetObjects("rbxassetid://"..tostring(REGISTRY[tostring(packageName):upper()]))
					local module = objects[1]
					if table.find(flags, "g") or args['global'] then
						if module then
							if not game.ReplicatedStorage:FindFirstChild("rbx_modules") then
								local rbx_modules = Instance.new("Folder", game.ReplicatedStorage)
								rbx_modules.Name = "rbx_modules"
							end
							module.Parent = game.ReplicatedStorage:FindFirstChild("rbx_modules")
							module:SetAttribute("rbx_package_ID", packageName)
						end
					elseif table.find(flags, "d") or args['dev'] then
						if module then
							module.Parent = self.UI.DEV_MODULES
							module:SetAttribute("rbx_package_ID", packageName)
						end
					else
						if module then
							module.Parent = self.PATH
							module:SetAttribute("rbx_package_ID", packageName)
						end
					end
				else
					local url = "https://rbx-cloud.vercel.app/api/packages/"..tostring(packageName)
					local result = SERVICES.HttpService:JSONDecode(SERVICES.HttpService:GetAsync(url))
					local pkgId
					if result.pkgId and tonumber(result.pkgId) then
						pkgId = tonumber(result.pkgId)
					else
						self:NewMsg("Package '"..packageName.."' not found")
						return
					end
					local objects = game:GetObjects("rbxassetid://"..tostring(pkgId))
					local module = objects[1]
					if table.find(flags, "g") or args['global'] then
						if module then
							if not game.ReplicatedStorage:FindFirstChild("rbx_modules") then
								local rbx_modules = Instance.new("Folder", game.ReplicatedStorage)
								rbx_modules.Name = "rbx_modules"
							end
							module.Parent = game.ReplicatedStorage:FindFirstChild("rbx_modules")
							module:SetAttribute("rbx_package_ID", packageName)
						end
					elseif table.find(flags, "d") or args['dev'] then
						if module then
							module.Parent = self.UI.DEV_MODULES
							module:SetAttribute("rbx_package_ID", packageName)
						end
					else
						if module then
							module.Parent = self.PATH
							module:SetAttribute("rbx_package_ID", packageName)
						end
					end
				end
			end
		end,
		['key'] = function(self, regular, args, flags)
			local key = regular[1]
			if key then
				self.plugin:SetSetting("rbx_cloud_key", tostring(key))
			end
		end,
		['publish'] = function(self, regular, args, flags)
			local name = regular[1]
			local id = regular[2]
			local key = regular[3] or self.plugin:GetSetting("rbx_cloud_key")
			if tostring(name) and tonumber(id) and tostring(key) then
				local url = "https://rbx-cloud.vercel.app/api/packages/create?pkgName="..tostring(name).."&id="..id.."&user="..SERVICES.StudioService:GetUserId().."&key="..tostring(key)
				SERVICES.HttpService:JSONDecode(SERVICES.HttpService:GetAsync(url))
			else
				self:NewMsg("Provide a valid Roblox AssetID")
			end
		end,
		['run'] = function(self, regular, args, flags)
			local packageFile = game.ReplicatedStorage:FindFirstChild("PACKAGE")
			if not packageFile then
				self:NewMsg("Failed to fetch PACKAGE")
			else
				local scripts = require(packageFile).scripts
				if #regular ~= 0 then
					local runScript = scripts[regular[1]]
					if type(runScript) == "function" then
						runScript()
					--elseif type(runScript) == "string" then
					--	-- ability to run Lua files?
					else
						self:NewMsg("Script '"..regular[1].."' does not exist!")
					end
				else
					self:NewMsg("SCRIPTS")
					for k in pairs(scripts) do
						self:NewMsg("| "..k)
					end
				end
				
			end
		end,
		['star'] = function(self, regular, args, flags)
			local stars
			if not self.plugin:GetSetting("RBX_Stars") then
				self.plugin:SetSetting("RBX_Stars", {})
				stars = {}
			else
				stars = self.plugin:GetSetting("RBX_Stars")
			end
			
			for _, v in ipairs(regular) do
				if tonumber(v) then
					table.insert(stars, v)
				else
					table.insert(stars, REGISTRY[tostring(v):upper()])
				end
			end
			
			self.plugin:SetSetting("RBX_Stars", stars)
		end,
		['stars'] = function(self, regular, args, flags)
			local stars
			if not self.plugin:GetSetting("RBX_Stars") then
				self.plugin:SetSetting("RBX_Stars", {})
				stars = {}
			else
				stars = self.plugin:GetSetting("RBX_Stars")
			end
			
			for _, v in ipairs(stars) do
				self:NewMsg("| "..v)
			end
		end,
		['whoami'] = function(self, regular, args, flags)
			local userId = SERVICES.StudioService:GetUserId() or 0
			self:NewMsg(game.Players:GetNameFromUserIdAsync(userId).." "..tostring(userId))
		end,
		['uninstall'] = function(self, regular, args, flags)
			if self.PATH == game then
				self:NewMsg("Cannot uninstall a package from a DataModel!")
				self:NewMsg("Please 'cd' somewhere to uninstall a package.")
				return
			end
			
			local packageName = regular[1]
			
			if table.find(flags, "g") or args['global'] then
				if not game.ReplicatedStorage:FindFirstChild("rbx_modules") then return end
				for _, v in ipairs(game.ReplicatedStorage:FindFirstChild("rbx_modules"):GetChildren()) do
					if v:GetAttribute("rbx_package_ID") == packageName then
						v:Destroy()
						break
					end
				end
			elseif table.find(flags, "d") or args['dev'] then
				for _, v in ipairs(self.UI.DEV_MODULES:GetChildren()) do
					if v:GetAttribute("rbx_package_ID") == packageName then
						v:Destroy()
						break
					end
				end
			else
				for _, v in ipairs(self.PATH:GetChildren()) do
					if v:GetAttribute("rbx_package_ID") == packageName then
						v:Destroy()
						break
					end
				end
			end
		end,
		['unstar'] = function(self, regular, args, flags)
			local stars
			if not self.plugin:GetSetting("RBX_Stars") then
				self.plugin:SetSetting("RBX_Stars", {})
				stars = {}
			else
				stars = self.plugin:GetSetting("RBX_Stars")
			end
			
			if table.find(flags, 'a') then
				stars = {}
			else
				for _, v in ipairs(regular) do
					if tonumber(v) then
						table.remove(stars, table.find(stars, v))
					else
						table.remove(stars, table.find(stars, REGISTRY[tostring(v):upper()]))
					end
				end
			end

			self.plugin:SetSetting("RBX_Stars", stars)
		end,
		['update'] = function(self, regular, args, flags)
			if table.find(flags, 'g') or args['global'] then
				-- Global
				if not game.ReplicatedStorage:FindFirstChild("rbx_modules") then return end
				
				if table.find(flags, 'a') or args['all'] then
					-- All global
					for _, package in ipairs(game.ReplicatedStorage:FindFirstChild("rbx_modules"):GetChildren()) do
						if package:GetAttribute("rbx_package_ID") then
							local v = package:GetAttribute("rbx_package_ID")
							package:Destroy()
							if tonumber(v) then
								--local latestVersion = SERVICES.InsertService:GetLatestAssetVersionAsync(tonumber(v))
								--local module = SERVICES.InsertService:LoadAssetVersion(latestVersion):GetChildren()[1]
								local module = game:GetObjects("rbxassetid://"..tostring(tonumber(v)))[1]
								module:SetAttribute("rbx_package_ID", v)
								if module then module.Parent = game.ReplicatedStorage:FindFirstChild("rbx_modules") end
							elseif tonumber(REGISTRY[tostring(v):upper()]) then
								--local latestVersion = SERVICES.InsertService:GetLatestAssetVersionAsync(REGISTRY[tostring(v):upper()])
								--local module = SERVICES.InsertService:LoadAssetVersion(latestVersion):GetChildren()[1]
								local module = game:GetObjects("rbxassetid://"..tostring(tonumber(REGISTRY[tostring(v):upper()])))[1]
								module:SetAttribute("rbx_package_ID", v)
								if module then module.Parent = game.ReplicatedStorage:FindFirstChild("rbx_modules") end
							else
								local url = "https://rbx-cloud.vercel.app/api/packages/"..tostring(tostring(v))
								local result = SERVICES.HttpService:JSONDecode(SERVICES.HttpService:GetAsync(url))
								local pkgId
								if result.pkgId and tonumber(result.pkgId) then
									pkgId = tonumber(result.pkgId)
								else
									self:NewMsg("Package '"..tostring(v).."' not found")
									return
								end
								local module = game:GetObjects("rbxassetid://"..tostring(tonumber(pkgId)))[1]
								module:SetAttribute("rbx_package_ID", v)
								if module then module.Parent = game.ReplicatedStorage:FindFirstChild("rbx_modules") end
							end
						end
					end
				else
					-- Specified global
					for _, v in ipairs(regular) do
						for _, package in ipairs(game.ReplicatedStorage:FindFirstChild("rbx_modules"):GetChildren()) do
							if package:GetAttribute("rbx_package_ID") == v or package:GetAttribute("rbx_package_ID") == REGISTRY[tostring(v):upper()] then
								package:Destroy()
								if tonumber(v) then
									--local latestVersion = SERVICES.InsertService:GetLatestAssetVersionAsync(tonumber(v))
									--local module = SERVICES.InsertService:LoadAssetVersion(latestVersion):GetChildren()[1]
									local module = game:GetObjects("rbxassetid://"..tostring(tonumber(v)))[1]
									module:SetAttribute("rbx_package_ID", v)
									if module then module.Parent = game.ReplicatedStorage:FindFirstChild("rbx_modules") end
								elseif tonumber(REGISTRY[tostring(v):upper()]) then
									--local latestVersion = SERVICES.InsertService:GetLatestAssetVersionAsync(REGISTRY[tostring(v):upper()])
									--local module = SERVICES.InsertService:LoadAssetVersion(latestVersion):GetChildren()[1]
									local module = game:GetObjects("rbxassetid://"..tostring(tonumber(REGISTRY[tostring(v):upper()])))[1]
									module:SetAttribute("rbx_package_ID", v)
									if module then module.Parent = game.ReplicatedStorage:FindFirstChild("rbx_modules") end
								else
									local url = "https://rbx-cloud.vercel.app/api/packages/"..tostring(tostring(v))
									local result = SERVICES.HttpService:JSONDecode(SERVICES.HttpService:GetAsync(url))
									local pkgId
									if result.pkgId and tonumber(result.pkgId) then
										pkgId = tonumber(result.pkgId)
									else
										self:NewMsg("Package '"..tostring(v).."' not found")
										return
									end
									local module = game:GetObjects("rbxassetid://"..tostring(tonumber(pkgId)))[1]
									module:SetAttribute("rbx_package_ID", v)
									if module then module.Parent = game.ReplicatedStorage:FindFirstChild("rbx_modules") end
								end
								
								break
							end
						end
					end
				end
			elseif table.find(flags, "d") or args['dev'] then
				-- Dev
				if table.find(flags, 'a') or args['all'] then
					for _, package in ipairs(self.UI.DEV_MODULES:GetChildren()) do
						if package:GetAttribute("rbx_package_ID") then
							local v = package:GetAttribute("rbx_package_ID")
							package:Destroy()
							if tonumber(v) then
								--local latestVersion = SERVICES.InsertService:GetLatestAssetVersionAsync(tonumber(v))
								--local module = SERVICES.InsertService:LoadAssetVersion(latestVersion):GetChildren()[1]
								local module = game:GetObjects("rbxassetid://"..tostring(tonumber(v)))[1]
								module:SetAttribute("rbx_package_ID", v)
								if module then module.Parent = self.UI.DEV_MODULES end
							elseif tonumber(REGISTRY[tostring(v):upper()]) then
								--local latestVersion = SERVICES.InsertService:GetLatestAssetVersionAsync(REGISTRY[tostring(v):upper()])
								--local module = SERVICES.InsertService:LoadAssetVersion(latestVersion):GetChildren()[1]
								local module = game:GetObjects("rbxassetid://"..tostring(tonumber(REGISTRY[tostring(v):upper()])))[1]
								module:SetAttribute("rbx_package_ID", v)
								if module then module.Parent = self.UI.DEV_MODULES end
							else
								local url = "https://rbx-cloud.vercel.app/api/packages/"..tostring(tostring(v))
								local result = SERVICES.HttpService:JSONDecode(SERVICES.HttpService:GetAsync(url))
								local pkgId
								if result.pkgId and tonumber(result.pkgId) then
									pkgId = tonumber(result.pkgId)
								else
									self:NewMsg("Package '"..tostring(v).."' not found")
									return
								end
								local module = game:GetObjects("rbxassetid://"..tostring(tonumber(pkgId)))[1]
								module:SetAttribute("rbx_package_ID", v)
								if module then module.Parent = self.UI.DEV_MODULES end
							end
						end
					end
				else
					for _, v in ipairs(regular) do
						for _, package in ipairs(self.UI.DEV_MODULES:GetChildren()) do
							if package:GetAttribute("rbx_package_ID") == v or package:GetAttribute("rbx_package_ID") == REGISTRY[tostring(v):upper()] then
								package:Destroy()
								if tonumber(v) then
									--local latestVersion = SERVICES.InsertService:GetLatestAssetVersionAsync(tonumber(v))
									--local module = SERVICES.InsertService:LoadAssetVersion(latestVersion):GetChildren()[1]
									local module = game:GetObjects("rbxassetid://"..tostring(tonumber(v)))[1]
									module:SetAttribute("rbx_package_ID", v)
									if module then module.Parent = self.UI.DEV_MODULES end
								elseif tonumber(REGISTRY[tostring(v):upper()]) then
									--local latestVersion = SERVICES.InsertService:GetLatestAssetVersionAsync(REGISTRY[tostring(v):upper()])
									--local module = SERVICES.InsertService:LoadAssetVersion(latestVersion):GetChildren()[1]
									local module = game:GetObjects("rbxassetid://"..tostring(tonumber(REGISTRY[tostring(v):upper()])))[1]
									module:SetAttribute("rbx_package_ID", v)
									if module then module.Parent = self.UI.DEV_MODULES end
								else
									local url = "https://rbx-cloud.vercel.app/api/packages/"..tostring(tostring(v))
									local result = SERVICES.HttpService:JSONDecode(SERVICES.HttpService:GetAsync(url))
									local pkgId
									if result.pkgId and tonumber(result.pkgId) then
										pkgId = tonumber(result.pkgId)
									else
										self:NewMsg("Package '"..tostring(v).."' not found")
										return
									end
									local module = game:GetObjects("rbxassetid://"..tostring(tonumber(pkgId)))[1]
									module:SetAttribute("rbx_package_ID", v)
									if module then module.Parent = self.UI.DEV_MODULES end
								end
								
								break
							end
						end
					end
				end
			else
				-- Local
				if self.PATH == game then
					self:NewMsg("Cannot update a package in a DataModel!")
					self:NewMsg("Please 'cd' somewhere to update a package.")
					return
				end
				
				if table.find(flags, 'a') or args['all'] then
					-- All local
					for _, package in ipairs(self.PATH:GetChildren()) do
						if package:GetAttribute("rbx_package_ID") then
							local v = package:GetAttribute("rbx_package_ID")
							package:Destroy()
							if tonumber(v) then
								--local latestVersion = SERVICES.InsertService:GetLatestAssetVersionAsync(tonumber(v))
								--local module = SERVICES.InsertService:LoadAssetVersion(latestVersion):GetChildren()[1]
								local module = game:GetObjects("rbxassetid://"..tostring(tonumber(v)))[1]
								module:SetAttribute("rbx_package_ID", v)
								if module then module.Parent = self.PATH end
							elseif tonumber(REGISTRY[tostring(v):upper()]) then
								--local latestVersion = SERVICES.InsertService:GetLatestAssetVersionAsync(REGISTRY[tostring(v):upper()])
								--local module = SERVICES.InsertService:LoadAssetVersion(latestVersion):GetChildren()[1]
								local module = game:GetObjects("rbxassetid://"..tostring(tonumber(REGISTRY[tostring(v):upper()])))[1]
								module:SetAttribute("rbx_package_ID", v)
								if module then module.Parent = self.PATH end
							else
								local url = "https://rbx-cloud.vercel.app/api/packages/"..tostring(tostring(v))
								local result = SERVICES.HttpService:JSONDecode(SERVICES.HttpService:GetAsync(url))
								local pkgId
								if result.pkgId and tonumber(result.pkgId) then
									pkgId = tonumber(result.pkgId)
								else
									self:NewMsg("Package '"..tostring(v).."' not found")
									return
								end
								local module = game:GetObjects("rbxassetid://"..tostring(tonumber(pkgId)))[1]
								module:SetAttribute("rbx_package_ID", v)
								if module then module.Parent = self.PATH end
							end
						end
					end
				else
					-- Specified local
					for _, v in ipairs(regular) do
						for _, package in ipairs(self.PATH:GetChildren()) do
							if package:GetAttribute("rbx_package_ID") == v or package:GetAttribute("rbx_package_ID") == REGISTRY[tostring(v):upper()] then
								package:Destroy()
								if tonumber(v) then
									--local latestVersion = SERVICES.InsertService:GetLatestAssetVersionAsync(tonumber(v))
									--local module = SERVICES.InsertService:LoadAssetVersion(latestVersion):GetChildren()[1]
									local module = game:GetObjects("rbxassetid://"..tostring(tonumber(v)))[1]
									module:SetAttribute("rbx_package_ID", v)
									if module then module.Parent = self.PATH end
								elseif tonumber(REGISTRY[tostring(v):upper()]) then
									--local latestVersion = SERVICES.InsertService:GetLatestAssetVersionAsync(REGISTRY[tostring(v):upper()])
									--local module = SERVICES.InsertService:LoadAssetVersion(latestVersion):GetChildren()[1]
									local module = game:GetObjects("rbxassetid://"..tostring(tonumber(REGISTRY[tostring(v):upper()])))[1]
									module:SetAttribute("rbx_package_ID", v)
									if module then module.Parent = self.PATH end
								else
									local url = "https://rbx-cloud.vercel.app/api/packages/"..tostring(tostring(v))
									local result = SERVICES.HttpService:JSONDecode(SERVICES.HttpService:GetAsync(url))
									local pkgId
									if result.pkgId and tonumber(result.pkgId) then
										pkgId = tonumber(result.pkgId)
									else
										self:NewMsg("Package '"..tostring(v).."' not found")
										return
									end
									local module = game:GetObjects("rbxassetid://"..tostring(tonumber(pkgId)))[1]
									module:SetAttribute("rbx_package_ID", v)
									if module then module.Parent = self.PATH end
								end
								
								break
							end
						end
					end
				end
			end
		end,
		['version'] = function(self, regular, args, flags)
			self:NewMsg(RBX_VERSION)
		end,
	},
	
	-- BASH COMMANDS (the default BASH commands in a BASH terminal + more!)
	['cd'] = function(self, args)
		local path = args[1]
		local ancestor = self.PATH
		
		if path == "$PATH" then
			self:NewMsg("Not supported yet")
		elseif path == "~" then
			self.PREVIOUS_PATH = self.PATH
			self.PATH = workspace
			return
		elseif path == ".." then
			if ancestor.Parent == game then
				self.PREVIOUS_PATH = self.PATH
				self.PATH = game
			elseif ancestor.Parent then
				self.PREVIOUS_PATH = self.PATH
				self.PATH = ancestor.Parent
			else
				self:NewMsg("Failed to set directory")
			end
			return
		elseif path == "-" then
			if self.PREVIOUS_PATH then
				self.PATH = self.PREVIOUS_PATH
				self.PREVIOUS_PATH = nil
			else
				self:NewMsg("No previous path found")
			end
			return
		end
		
		local res = getInstanceFromPath(ancestor, path)
		
		if res and res ~= game then
			self.PREVIOUS_PATH = self.PATH
			self.PATH = res
		else
			self:NewMsg("Failed to set directory")
		end
	end,
	['echo'] = function(self, args)
		refreshVars(self)
		
		for i, v in ipairs(args) do
			if v:match("^%$.*") then
				args[i] = VARIABLES[v:gsub("%$", ""):upper()]
			elseif v:match("\"") then
				args[i] = v:gsub("\"", "")
			elseif v:match("\'") then
				args[i] = v:gsub("\'", "")
			end
		end
		
		self:NewMsg(table.concat(args, " "))
	end,
	['edit'] = function(self, args)
		local params = args
		if type(params[1]) == "number" then
			local scriptToOpen = self.PATH
			local lineNum = tonumber(params[1])
			if type(lineNum) == "number" then
				self.plugin:OpenScript(scriptToOpen, lineNum)
			else
				self.plugin:OpenScript(scriptToOpen)
			end
		elseif self.PATH:IsA("LuaSourceContainer") then
			self.plugin:OpenScript(self.PATH)
		else
			self:NewMsg("Current directory is not a LuaSourceContainer")
		end
	end,
	['exit'] = function(self, args)
		self.plugin:Deactivate()
		self.UI.Parent.Enabled = false
		self:Clear()
	end,
	['export'] = function(self, args)
		local export_string = nil
		
		if #args > 1 then
			export_string = table.concat(args)
		else
			export_string = args[1]
		end
		
		if export_string then
			local split = export_string:split("=")
			local variable_name, new_value = split[1], split[2]
			if table.find(self.blacklistedVariables, variable_name:lower()) then
				self:NewMsg("You cannot overwrite a blacklisted variable!")
			else
				for self_variable_key, self_variable_value in pairs(self) do
					if table.find(self.blacklistedFilteredVariable, self_variable_key:lower()) then continue end
					new_value = table.pack(new_value:gsub("$"..self_variable_key, tostring(self_variable_value)))[1]
				end
				self[variable_name] = new_value
			end
		end
	end,
	['head'] = function(self, args)
		local params = args
		local txt = string.split(string.gsub(self.PATH[params[1]].Source, "\t", ""), "\n")
		self:NewMsg("BEGIN "..self.PATH[params[1]].Name..".lua")
		for k, v in ipairs(txt) do
			self:NewMsg(v)
			if k == 10 then break end
		end
		self:NewMsg("END "..self.PATH[params[1]].Name..".lua")
	end,
	['less'] = function(self, args)
		local params = args
		local txt = string.split(string.gsub(self.PATH[params[1]].Source, "\t", ""), "\n")
		self:NewMsg("BEGIN "..self.PATH[params[1]].Name..".lua")
		for _, v in ipairs(txt) do
			self:NewMsg(v)
		end
		self:NewMsg("END "..self.PATH[params[1]].Name..".lua")
	end,
	['ls'] = function(self)
		local tbl
		
		if self.PATH == game then
			tbl = allowedGameChildren
		else
			tbl = self.PATH:GetChildren()
		end
		
		for _, v in ipairs(tbl) do
			self:NewMsg(v.Name.."("..v.ClassName..")")
		end
	end,
	['mkdir'] = function(self, args)
		local folder = Instance.new("Folder", self.PATH)
		folder.Name = args[1] or "Folder"
	end,
	['pwd'] = function(self)
		if self.PATH == game then
			self:NewMsg("game")
		else
			self:NewMsg("game/"..string.gsub(self.PATH:GetFullName(), "%.", "/"))
		end
	end,
	['rm'] = function(self)
		if self.PATH.Parent == game or self.PATH == game then
			self:NewMsg("Cannot remove a DataModel or a direct child of one")
		elseif self.PATH.Parent then
			local parent = self.PATH.Parent
			self.PATH:Destroy()
			self.PATH = parent
		end
	end,
	['rmdir'] = function(self)
		if self.PATH:IsA("Folder") then
			if self.PATH.Parent == game or self.PATH == game then
				self:NewMsg("Cannot remove a DataModel or a direct child of one")
			elseif #self.PATH:GetChildren() ~= 0 then
				self:NewMsg("Cannot use rmdir on a directory with Instances")
			elseif self.PATH.Parent then
				local parent = self.PATH.Parent
				self.PATH:Destroy()
				self.PATH = parent
			end
		else
			self:NewMsg("Cannot use rmdir on a non-directory")
		end
	end,
	['run'] = function(self)
		if self.PATH:IsA("ModuleScript") and self.PATH.Name:split(".")[2] == 'cli' then
			local file = self.PATH
			local file_name = file.Name
			local file_source = file.Source
			local file_parent = file.Parent
			file:Destroy()
			file = Instance.new("ModuleScript", game.ReplicatedStorage)
			file.Name = file_name
			file.Source = file_source
			file.Parent = file_parent
			
			self.PATH = file
			
			local commands = require(file)
			
			for _, command in ipairs(commands) do
				self:__evaluate(command, false)
			end
		elseif self.PATH.Name:split(".")[2] ~= 'cli' then
			self:NewMsg("File must end in '.cli'")
		else
			self:NewMsg("Cannot run a non-ModuleScript")
		end
	end,
	['tail'] = function(self, args)
		local params = args
		local txt = string.split(string.gsub(self.PATH[params[1]].Source, "\t", ""), "\n")
		self:NewMsg("BEGIN "..self.PATH[params[1]].Name..".lua")
		for k, v in ipairs(txt) do
			if k + 10 >= #txt then
				self:NewMsg(v)
			end
		end
		self:NewMsg("END "..self.PATH[params[1]].Name..".lua")
	end,
	['touch'] = function(self, args)
		local file = Instance.new("Script", self.PATH)
		file.Name = args[1] or "Script"
	end,
}
