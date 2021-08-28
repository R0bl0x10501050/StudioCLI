RBX_VERSION = "1.0.0"

local REGISTRY = {
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
}

-----------------------------------------------------------------------------------------------------------------

local SERVICES = {
	['StudioService'] = game:GetService("StudioService"),
	['InsertService'] = game:GetService("InsertService"),
	['HttpService'] = game:GetService("HttpService")
}

local allowedGameChildren = {game.Workspace, game.Players, game.Lighting, game.ReplicatedFirst, game.ReplicatedStorage, game.ServerScriptService, game.ServerStorage, game.StarterGui, game.StarterPack, game.StarterPlayer, game.Teams, game.SoundService, game.Chat, game.LocalizationService, game.TestService}

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
	
	for _, v in ipairs(split) do
		if v == ".." then
			parent = parent.Parent
			continue
		end
		parent = getChild(parent, v)
	end
	
	return parent
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
	
	-- LIBRARY (a CLI library-ish thing, example: npm)
	
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
	
	['rbx'] = { -- Package manager, basically npm for Roblox, the commands are literally identical lol
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
				local module = game:GetObjects("rbxassetid://"..tostring(packageName))[1]
				if table.find(flags, "g") or args['global'] then
					if module then
						if not game.ReplicatedStorage:FindFirstChild("rbx_modules") then
							local rbx_modules = Instance.new("Folder", game.ReplicatedStorage)
							rbx_modules.Name = "rbx_modules"
						end
						module.Parent = game.ReplicatedStorage:FindFirstChild("rbx_modules")
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
					local module = game:GetObjects("rbxassetid://"..tostring(REGISTRY[tostring(packageName):upper()]))[1]
					module:SetAttribute("rbx_package_ID", packageName)
					if module then module.Parent = self.PATH end
				end
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
							else
								--local latestVersion = SERVICES.InsertService:GetLatestAssetVersionAsync(REGISTRY[tostring(v):upper()])
								--local module = SERVICES.InsertService:LoadAssetVersion(latestVersion):GetChildren()[1]
								local module = game:GetObjects("rbxassetid://"..tostring(tonumber(REGISTRY[tostring(v):upper()])))[1]
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
								else
									--local latestVersion = SERVICES.InsertService:GetLatestAssetVersionAsync(REGISTRY[tostring(v):upper()])
									--local module = SERVICES.InsertService:LoadAssetVersion(latestVersion):GetChildren()[1]
									local module = game:GetObjects("rbxassetid://"..tostring(tonumber(REGISTRY[tostring(v):upper()])))[1]
									module:SetAttribute("rbx_package_ID", v)
									if module then module.Parent = game.ReplicatedStorage:FindFirstChild("rbx_modules") end
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
							else
								--local latestVersion = SERVICES.InsertService:GetLatestAssetVersionAsync(REGISTRY[tostring(v):upper()])
								--local module = SERVICES.InsertService:LoadAssetVersion(latestVersion):GetChildren()[1]
								local module = game:GetObjects("rbxassetid://"..tostring(tonumber(REGISTRY[tostring(v):upper()])))[1]
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
								else
									--local latestVersion = SERVICES.InsertService:GetLatestAssetVersionAsync(REGISTRY[tostring(v):upper()])
									--local module = SERVICES.InsertService:LoadAssetVersion(latestVersion):GetChildren()[1]
									local module = game:GetObjects("rbxassetid://"..tostring(tonumber(REGISTRY[tostring(v):upper()])))[1]
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
		
		if path == ".." then
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
	['mkdir'] = function(self)
		Instance.new("Folder", self.PATH)
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
	['touch'] = function(self)
		Instance.new("Script", self.PATH)
	end,
}
