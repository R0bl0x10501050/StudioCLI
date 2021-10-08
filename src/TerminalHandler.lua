-- TerminalHandler.lua

local Cmds = require(script.Parent.Commands)
local SyntaxHighlighter = require(script.SyntaxHighligher)

local CLI_VERSION = "1.4.0"
--local PACKAGE_STORAGE_VERSION = "0.0.1"

local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")

local bashCommands = {'cd', 'echo', 'edit', 'exit', 'head', 'less', 'ls', 'mkdir', 'pwd', 'rm', 'rmdir', 'tail', 'touch'}
local allowedGameChildren = {game.Workspace, game.Players, game.Lighting, game.ReplicatedFirst, game.ReplicatedStorage, game.ServerScriptService, game.ServerStorage, game.StarterGui, game.StarterPack, game.StarterPlayer, game.SoundService, game.Chat}

local themes = {
	['DEFAULT'] = {
		['TextColor3'] = Color3.new(1, 1, 1),
		['TextTransparency'] = 0,
		['BackgroundColor3'] = Color3.new(0.0235294, 0.0235294, 0.0235294)
	},
	['LIGHT'] = {
		['TextColor3'] = Color3.new(0, 0, 0),
		['TextTransparency'] = 0.25,
		['BackgroundColor3'] = Color3.new(1, 1, 1)
	}
}

local function getDictionaryLength(dict)
	local length = 0
	for k, _ in pairs(dict) do
		length += 1
	end
	return length
end

local function clearTags(str: string)
	-- Credit to @JohnnyMorganz for the string pattern
	-- https://devforum.roblox.com/t/richtext-textscaled-support-added/634167/171
	if str == nil then return nil end
	if str == "" or str:match("^%s$") then return str end
	return str:gsub("</?%s*[bius]%s*>", ""):gsub("</?font%s*[%w%s='\"\(\),]*>", "")
end

local function clearWhitespace(instance)
	local text = instance.Text
	if text:split("")[1]:match("%s") then
		text = text:gsub("^.", "")
	end
	instance.Text = text
end

local function old_rerequire(scriptFile)
	if not scriptFile:IsA("ModuleScript") then return nil end
	local clone, new_parent = scriptFile:Clone(), scriptFile.Parent
	scriptFile:Destroy()
	clone.Parent = new_parent
	return require(clone) or {}
end

local function rerequire(scriptFile)
	if not scriptFile:IsA("ModuleScript") then return nil end
	local clone = scriptFile:Clone()
	local data = require(clone)
	clone:Destroy()
	return data or {}
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

local TerminalHandler = {}
TerminalHandler.PATH = game
TerminalHandler.PREVIOUS_PATH = nil

function TerminalHandler:Init(frame, pluginInstance)
	self.blacklistedVariables = {"plugin", "options", "ui", "theme", "restricted", "init", "clear", "newinput", "newline", "newmsg", "path", "oldpath", "__evaluate", "blacklistedvariables", "home"}
	self.blacklistedFilteredVariable = {"plugin", "options", "ui", "theme", "restricted", "init", "clear", "newinput", "newline", "newmsg", "path", "oldpath", "__evaluate", "blacklistedvariables"}
	self.plugin = pluginInstance
	self.OPTIONS = {
		colors = true
	}
	self.UI = frame
	self.Theme = themes["DEFAULT"]
	
	-- Config
	local config = game.ReplicatedStorage:FindFirstChild("config.cli")
	if config and config:IsA("ModuleScript") then
		local config_source = config.Source
		config:Destroy()
		config = Instance.new("ModuleScript", game.ReplicatedStorage)
		config.Name = "config.cli"
		config.Source = config_source
		
		local pluginSettings = require(config)
		for name, value in pairs(pluginSettings) do
			if (name and type(name) == "string" and name:upper() == "THEME") and (value and themes[value:upper()]) then
				self.Theme = themes[value:upper()]
			end
		end
	end
	
	-- Theme
	local theme = self.Theme
	self.UI.BackgroundColor3 = theme.BackgroundColor3
	self.UI.Display.TextColor3 = theme.TextColor3
	self.UI.Display.TextTransparency = theme.TextTransparency
	
	-- Misc
	self.Restricted = self.UI:FindFirstChildOfClass("TextLabel"):Clone()
	self.Restricted.Position = UDim2.fromOffset(0, self.UI:GetAttribute("Lines")*20)
	self.Restricted.Size = UDim2.new(1, 0, 0, 20)
	self.Restricted.Parent = self.UI
	self.UI:SetAttribute("Lines", self.UI:GetAttribute("Lines")+1)
	self.Restricted.Text = "StudioCLI v"..CLI_VERSION..". Type 'help' to display a list of commands. Type 'clear' to clear."
	
	-- Profiles
	local profile = game.ReplicatedStorage:FindFirstChild("profile.cli")
	if profile and profile:IsA("ModuleScript") then
		local profile_source = profile.Source
		profile:Destroy()
		profile = Instance.new("ModuleScript", game.ReplicatedStorage)
		profile.Name = "profile.cli"
		profile.Source = profile_source
		
		local commands = require(profile)
		for _, command in ipairs(commands) do
			self:__evaluate(command, false)
		end
	end
	
	self:NewInput()
end

function TerminalHandler:NewLine()
	local blank = self.UI:FindFirstChildOfClass("TextLabel"):Clone()
	blank.Name = "DeleteMe"
	blank.Position = UDim2.fromOffset(0, self.UI:GetAttribute("Lines")*20)
	blank.Size = UDim2.new(1, 0, 0, 20)
	blank.Parent = self.UI
	self.UI:SetAttribute("Lines", self.UI:GetAttribute("Lines")+1)
	--self.UI.CanvasPosition = Vector2.new(0, (self.UI.Parent.AbsoluteSize.Y * self.UI.CanvasSize.Y.Scale) + self.UI.CanvasSize.Y.Offset + 500)
	self.UI.CanvasPosition = Vector2.new(0, (self.UI:GetAttribute("Lines")*20) + 50)
end

function TerminalHandler:NewMsg(text, richtext: boolean?)
	local msg = self.UI:FindFirstChildOfClass("TextLabel"):Clone()
	msg.Name = "DeleteMe"
	msg.Position = UDim2.fromOffset(0, self.UI:GetAttribute("Lines")*20)
	msg.Size = UDim2.new(1, 0, 0, 20)
	msg.Parent = self.UI
	msg.Text = text
	if richtext then msg.RichText = true end
	self.UI:SetAttribute("Lines", self.UI:GetAttribute("Lines")+1)
	--self.UI.CanvasPosition = Vector2.new(0, (self.UI.Parent.AbsoluteSize.Y * self.UI.CanvasSize.Y.Scale) + self.UI.CanvasSize.Y.Offset + 500)
	self.UI.CanvasPosition = Vector2.new(0, (self.UI:GetAttribute("Lines")*20) + 50)
end

function TerminalHandler:NewInput(default)
	local connection = "FetchLastInput_"..math.random()
	local highlighter
	
	local text = self.UI:FindFirstChildOfClass("TextLabel"):Clone()
	text.Name = "DeleteMe"
	text.Position = UDim2.fromOffset(0, self.UI:GetAttribute("Lines")*20)
	
	-- How live highlighting will work
	
	-- TextBox (stores actual text, is on top, isn't visible aka has TextTransparency of 1)
	-- Passes over the text to the highlighter
	-- Puts highlighted text in the TextLabel
	
	-- TextLabel (stores highlighted text, is visible)
	-- Stores actual highlighted text that the end user sees
	
	--TextBox
	local msg = Instance.new("TextBox", self.UI)
	msg.Name = "DeleteMe"
	msg.Active = true
	msg.BackgroundTransparency = 1
	msg.ClearTextOnFocus = false
	msg.PlaceholderText = ""
	msg.Font = Enum.Font.Ubuntu
	msg.RichText = false
	msg.Text = ""
	msg.TextColor3 = self.UI:FindFirstChildOfClass("TextLabel").TextColor3
	msg.TextScaled = false
	msg.TextSize = 20
	msg.TextTransparency = 0.5 --1
	msg.TextXAlignment = Enum.TextXAlignment.Left
	msg.TextYAlignment = Enum.TextYAlignment.Center
	msg.ZIndex = 1 --2
	
	--TextLabel
	local label = Instance.new("TextLabel", self.UI)
	label.Name = "DeleteMe"
	label.Active = false
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Ubuntu
	label.RichText = true
	label.Text = ""
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = false
	label.TextSize = 20
	label.TextTransparency = 0
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = 2 --1
	
	--Cursor
	--local cursor = Instance.new("Frame", self.UI)
	--cursor.Name = "DeleteMe"
	
	msg.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			--CAS:UnbindAction(connection)
			task.wait()
			
			local lastInputList = self.plugin:GetSetting("LastInput") or {}
			local cmd
			
			if self.OPTIONS.colors then
				highlighter:Highlight(false)
				local command = highlighter:RequestOriginalText()
				self:__evaluate(command, true)
				cmd = command
			else
				clearWhitespace(msg)
				self:__evaluate(msg.Text, true)
				cmd = msg.Text
			end
			
			table.insert(lastInputList, #lastInputList+1, cmd:gsub("%<", ""):gsub("%>", "") or "")
			
			if #lastInputList > 50 then
				repeat
					table.remove(lastInputList, 1)
				until #lastInputList <= 50
			end
			
			self.plugin:SetSetting("LastInput", lastInputList)
			self.plugin:SetSetting("LastInputNumber", #lastInputList+1)
			
			msg.Focused:Connect(function()
				msg:ReleaseFocus(false)
			end)
		end
	end)
	
	local unsubmittedText = ""
	
	msg:GetPropertyChangedSignal("Text"):Connect(function()
		if msg.Text == "<" or msg.Text == "^" then
			local queue = self.plugin:GetSetting("LastInput") or {}
			local queueNum = self.plugin:GetSetting("LastInputNumber") or #queue + 1
			local text = queue[queueNum - 1] or ""
			if text ~= "" and text then
				self.plugin:SetSetting("LastInputNumber", queueNum - 1)
			end
			msg:ReleaseFocus()
			msg.Text = text
			msg:CaptureFocus()
		elseif msg.Text == ">" then
			local queue = self.plugin:GetSetting("LastInput") or {}
			local queueNum = self.plugin:GetSetting("LastInputNumber") or #queue + 1
			local text
			if queueNum >= #queue + 1 then
				text = unsubmittedText
				self.plugin:SetSetting("LastInputNumber", #queue + 1)
			elseif queueNum == #queue then
				text = unsubmittedText
				self.plugin:SetSetting("LastInputNumber", queueNum + 1)
			else
				text = queue[queueNum + 1] or ""
				self.plugin:SetSetting("LastInputNumber", queueNum + 1)
			end
			msg:ReleaseFocus()
			msg.Text = text
			msg:CaptureFocus()
		elseif (self.plugin:GetSetting("LastInputNumber") or 1) == #(self.plugin:GetSetting("LastInput") or {}) + 1 then
			unsubmittedText = msg.Text
		end
	end)
	
	-- Due to the nature of Roblox plugins, pressing the 'UP' key
	-- will not automaticaly fill in the last input received
	--msg.InputBegan:Connect(function(input)
	--	print(input.KeyCode, input.UserInputType, input.UserInputState)
	--	if input.KeyCode == Enum.KeyCode.Up then
			
	--	end
	--end)
	
	if self.OPTIONS.colors then
		highlighter = SyntaxHighlighter.new(msg, label, true)
	end
	
	if self.PATH == game then
		text.Size = UDim2.new(0, 63, 0, 20)
		text.Parent = self.UI
		text.Text = "game> "
		
		msg.Position = UDim2.fromOffset(63, self.UI:GetAttribute("Lines")*20)
		msg.Size = UDim2.new(1, -63, 0, 20)
		label.Position = UDim2.fromOffset(63, self.UI:GetAttribute("Lines")*20)
		label.Size = UDim2.new(1, -63, 0, 20)
	else
		local PATH = "game/"..string.gsub(self.PATH:GetFullName(), "%.", "/")
		local textSize = game:GetService("TextService"):GetTextSize(PATH.."> ", text.TextSize, Enum.Font.Ubuntu, self.Restricted.AbsoluteSize)
		text.Size = UDim2.new(0, textSize.X, 0, 20)
		text.Parent = self.UI
		text.Text = PATH.."> "
		
		msg.Position = UDim2.fromOffset(textSize.X, self.UI:GetAttribute("Lines")*20)
		msg.Size = UDim2.new(1, -textSize.X, 0, 20)
		label.Position = UDim2.fromOffset(textSize.X, self.UI:GetAttribute("Lines")*20)
		label.Size = UDim2.new(1, -textSize.X, 0, 20)
	end
	
	msg.Parent = self.UI
	msg:CaptureFocus()
	self.plugin:SetSetting("Focus", msg)
	
	self.UI:SetAttribute("Lines", self.UI:GetAttribute("Lines")+1)
	--self.UI.CanvasPosition = Vector2.new(0, (self.UI.Parent.AbsoluteSize.Y * self.UI.CanvasSize.Y.Scale) + self.UI.CanvasSize.Y.Offset + 500)
	self.UI.CanvasPosition = Vector2.new(0, (self.UI:GetAttribute("Lines")*20) + 50)
	
	if type(default) == "string" then
		msg.Text = default
	else
		msg.Text = ""
	end
end

function TerminalHandler:Clear()
	for _, v in ipairs(self.UI:GetChildren()) do
		if v ~= self.Restricted and v.Name == "DeleteMe" then
			v:Destroy()
		end
	end
	
	self.UI:SetAttribute("Lines", 1)
	--self.UI.CanvasPosition = Vector2.new(0, (self.UI.Parent.AbsoluteSize.Y * self.UI.CanvasSize.Y.Scale) + self.UI.CanvasSize.Y.Offset)
	self.UI.CanvasPosition = Vector2.new(0, (self.UI:GetAttribute("Lines")*20) + 50)
	
	self:NewInput()
end

function TerminalHandler:__evaluate(input, newLine)
	-- Remove strange whitespace at beginning
	if input == "" then
		self:NewMsg("Could not find command '"..input.."'")
		if newLine == true then self:NewInput() end
		return
	end
	
	if string.match(string.split(input, "")[1], "%s") then
		local split = string.split(input, "")
		table.remove(split, 1)
		input = ""
		for _, v in ipairs(split) do
			input = input..v
		end
	end
	
	-- Scan for arguments
	local args = {}
	local cmdExtension = {}
	local flags = {}
	
	if (type(input) == 'string' and (not table.find(bashCommands, string.split(input, " ")[1]))) or type(input) == 'table' then
		local stringToEval
		
		if type(input) == 'string' then
			stringToEval = input
		elseif type(input) == 'table' then
			stringToEval = input[1]
		end
		
		local split = string.split(stringToEval, " ")
		local currentToken = 2
		local currentArg = split[currentToken]
		
		local function advance()
			currentToken += 1
			currentArg = split[currentToken]
		end
		
		local function detectDoubleHyphen(str: string)
			return table.pack(pcall(function() return str:match("^..") end))[2] == "--"
		end
		
		local function detectSingleHyphen(str: string)
			return table.pack(pcall(function() return str:match("^.") end))[2] == "-"
		end
		
		while currentArg ~= nil do
			if detectDoubleHyphen(currentArg) then
				local currentKey = currentArg
				advance()
				if detectDoubleHyphen(currentArg) or detectSingleHyphen(currentArg) then
					args[table.pack(string.gsub(currentKey, "%-%-", ""))[1]] = ""
				else
					args[table.pack(string.gsub(currentKey, "%-%-", ""))[1]] = currentArg or ""
					advance()
				end
			elseif detectSingleHyphen(currentArg) then
				table.insert(flags, table.pack(currentArg:gsub("-", ""))[1])
				advance()
			else
				table.insert(cmdExtension, currentArg)
				advance()
			end
		end
		
		if type(input) == 'string' then
			input = string.split(input, " ")[1]
		elseif type(input) == 'table' then
			input[1] = string.split(input[1], " ")[1]
		end
	elseif table.find(bashCommands, string.split(input, " ")[1]) then
		local stringToEval
		
		if type(input) == 'string' then
			stringToEval = input
		elseif type(input) == 'table' then
			stringToEval = input[1]
		end
		
		local split = string.split(stringToEval, " ")
		local currentToken = 2
		local currentArg = split[currentToken]
		
		local function advance()
			currentToken += 1
			currentArg = split[currentToken]
		end
		
		local function detectDoubleHyphen(str: string)
			return table.pack(pcall(function() return str:match("^..") end))[2] == "--"
		end
		
		local function detectSingleHyphen(str: string)
			return table.pack(pcall(function() return str:match("^.") end))[2] == "-"
		end
		
		while currentArg ~= nil do
			if currentArg == "-" then
				table.insert(cmdExtension, currentArg)
				advance()
			elseif detectDoubleHyphen(currentArg) or detectSingleHyphen(currentArg) then
				advance()
			else
				table.insert(cmdExtension, currentArg)
				advance()
			end
		end
		
		if type(input) == 'string' then
			input = string.split(input, " ")[1]
		elseif type(input) == 'table' then
			input[1] = string.split(input[1], " ")[1]
		end
	end
		
	--if table.find(bashCommands, input) then
	--	args = cmdExtension
	--end
	
	-- Default commands
	if input == 'alias' then
		print(cmdExtension)
		local name = cmdExtension[1]
		if name == "clear" then self.plugin:SetSetting("Aliases", {}) if newLine == true then self:NewInput() end return end
		table.remove(cmdExtension, 1)
		if cmdExtension[1] ~= "=" then
			self:NewMsg("Failed to set alias \""..name.."\"")
			if newLine == true then self:NewInput() end
			return
		else
			table.remove(cmdExtension, 1)
			local argument3 = table.concat(cmdExtension, " ")
			local command = string.gsub(argument3, "\"", "")
			if Cmds[name] then self:NewMsg("Cannot overwrite existing command") if newLine == true then self:NewInput() end return end
			local dictionary = self.plugin:GetSetting("Aliases") or {}
			dictionary[name] = command
			self.plugin:SetSetting("Aliases", dictionary)
			if newLine == true then self:NewInput() end
			return
		end
	end
	if input == 'clear' or input == 'cls' then self:Clear() return end
	if input == 'function' then
		local name = cmdExtension[1]
		if name == "clear" then self.plugin:SetSetting("Functions", {}) if newLine == true then self:NewInput() end return end
		table.remove(cmdExtension, 1)
		if cmdExtension[1] ~= "{" or cmdExtension[#cmdExtension] ~= "}" then
			self:NewMsg("Failed to set function \""..name.."\" - Incorrect syntax!")
			if newLine == true then self:NewInput() end
			return
		else
			table.remove(cmdExtension, 1)
			table.remove(cmdExtension)
			local commands = {}
			local combined = table.concat(cmdExtension, " ")
			commands = combined:split(";")
			table.foreachi(commands, function(i,v)
				if commands[i] ~= v then return end
				if v == "" then
					table.remove(commands, i)
				end
			end)
			local dictionary = self.plugin:GetSetting("Functions") or {}
			dictionary[name] = commands
			self.plugin:SetSetting("Functions", dictionary)
			if newLine == true then self:NewInput() end
			return
		end
	end
	if input == 'hardreset' then self.PREVIOUS_PATH = nil self.PATH = game if newLine == true then self:NewInput() end return end
	if input == 'help' then
		self:NewLine()
		self:NewMsg("COMMANDS")
		self:NewLine()
		self:NewMsg("cd 	- Change the current directory")
		self:NewMsg("echo 	- Print some output")
		self:NewMsg("edit 	- Edit the script (current directory)")
		self:NewMsg("exit 	- Kill the terminal")
		self:NewMsg("head 	- Read the first 10 lines of the specified file")
		self:NewMsg("less 	- View the specified file")
		self:NewMsg("ls 	- View the children of the current directory")
		self:NewMsg("mkdir 	- Make a new directory in the current one")
		self:NewMsg("pwd 	- Output the current directory")
		self:NewMsg("rm 	- Destroy the current path")
		self:NewMsg("rmdir 	- Destroy the current directory")
		self:NewMsg("tail 	- Read the last 10 lines of the specified file")
		self:NewMsg("touch 	- Create a new file in the current directory")
		--self:NewLine()
		if newLine == true then self:NewInput() end
		return
	end
	if input == 'reset' then self.PATH = game if newLine == true then self:NewInput() end return end
	if input == 'version' then self:NewMsg(CLI_VERSION) if newLine == true then self:NewInput() end return end
	
	--print(cmdExtension)
	--print(args)
	--print(flags)
	
	-- Logic
	if table.find(bashCommands, input) then
		local startTime = DateTime.now().UnixTimestampMillis
		
		local success, e = pcall(function()
			local passed = {self, cmdExtension or {}}
			Cmds[input](unpack(passed))
		end)
		
		local endTime = DateTime.now().UnixTimestampMillis
		
		if not success then
			self:NewMsg("Error while executing command '"..string.split(input, " ")[1].."': "..tostring(e))
		else
			--self:NewMsg("Successfully executed command '"..string.split(input, " ")[1].."' in "..((endTime - startTime)/1000).." seconds")
		end
		
		if newLine == true then self:NewInput() end
	elseif type(Cmds[input]) == 'string' then
		self:NewMsg(Cmds[input])
		if newLine == true then self:NewInput() end
	elseif type(Cmds[input]) == 'function' then
		local startTime = DateTime.now().UnixTimestampMillis
		
		local success, e = pcall(function()
			--local passed = {self, args}
			--Cmds[input](unpack(passed))
			local passed = {self, cmdExtension or {}, args or {}, flags or {}}
			Cmds[input](unpack(passed))
		end)
		
		local endTime = DateTime.now().UnixTimestampMillis
		
		if not success then
			self:NewMsg("Error while executing command '"..string.split(input, " ")[1].."': "..tostring(e))
		else
			--self:NewMsg("Successfully executed command '"..string.split(input, " ")[1].."' in "..((endTime - startTime)/1000).." seconds")
		end
		
		if newLine == true then self:NewInput() end
	elseif type(Cmds[input]) == 'table' and getDictionaryLength(cmdExtension) ~= 0 and type(Cmds[input][1]) ~= "string" then
		local library = Cmds[input]
		local passedExtension = {}
		
		local currentToken = 1
		local currentObj = cmdExtension[currentToken]
		local functionName = nil
		
		local function advance()
			currentToken += 1
			currentObj = cmdExtension[currentToken]
		end
		
		while currentObj ~= nil do
			if type(library) == "function" then
				if not functionName then
					functionName = cmdExtension[currentToken-1]
				end
				table.insert(passedExtension, currentObj)
				advance()
				continue
			end
			if library[currentObj] then
				library = library[currentObj]
			else
				table.insert(passedExtension, currentObj)
			end
			advance()
		end
		
		if not functionName then
			functionName = input
		end
		
		local startTime = DateTime.now().UnixTimestampMillis
		
		local success, e = pcall(function()
			--table.insert(args, 1, self)
			--library(unpack(args))
			local passed = {self, passedExtension or {}, args or {}, flags or {}}
			library(unpack(passed))
		end)
		
		local endTime = DateTime.now().UnixTimestampMillis
		
		if not success then
			self:NewMsg("Error while executing command '"..functionName.."': "..tostring(e))
		else
			--self:NewMsg("Successfully executed command '"..functionName.."' in "..((endTime - startTime)/1000).." seconds")
		end
		
		if newLine == true then self:NewInput() end
	elseif type(Cmds[input]) == 'table' and type(Cmds[input][1]) == 'string' and type(Cmds[input][2]) == 'function' then
		local startTime = DateTime.now().UnixTimestampMillis
		
		local success, e = pcall(function()
			--local passed = {self, args}
			--Cmds[input][2](unpack(passed))
			local passed = {self, cmdExtension or {}, args or {}, flags or {}}
			Cmds[input][2](unpack(passed))
		end)
		
		self:NewMsg(Cmds[input][1])
		
		local endTime = DateTime.now().UnixTimestampMillis
		
		if not success then
			self:NewMsg("Error while executing command '"..string.split(input, " ")[1].."': "..tostring(e))
		else
			--self:NewMsg("Successfully executed command '"..string.split(input, " ")[1].."' in "..((endTime - startTime)/1000).." seconds")
		end
		
		if newLine == true then self:NewInput() end
	else
		-- Executable path
		local exepath = {}
		
		for _, exepath_split in ipairs(self.EXEPATH and self.EXEPATH:split(";") or string.split("ServerStorage/bin",  ";")) do
			if exepath_split == "" or exepath_split == nil then continue end
			table.insert(exepath, exepath_split)
		end
		
		local function get_bin(bin)
			bin = getInstanceFromPath(game, bin)
			if bin then
				local found_bin_file
				
				for _, bin_file in ipairs(bin:GetChildren()) do
					if bin_file.Name == input then
						found_bin_file = bin_file
						break
					end
				end
				
				if found_bin_file then
					local library = rerequire(found_bin_file)
					local passedExtension = {}
					
					local currentToken = 1
					local currentObj = cmdExtension[currentToken]
					local functionName = nil
					
					local function advance()
						currentToken += 1
						currentObj = cmdExtension[currentToken]
					end
					
					while currentObj ~= nil do
						if type(library) == "function" then
							if not functionName then
								functionName = cmdExtension[currentToken-1]
							end
							table.insert(passedExtension, currentObj)
							advance()
							continue
						end
						if library[currentObj] then
							library = library[currentObj]
						else
							table.insert(passedExtension, currentObj)
						end
						advance()
					end
					
					if not functionName then
						functionName = input
					end
					
					local startTime = DateTime.now().UnixTimestampMillis
					
					local success, e = pcall(function()
						local passed = {self, passedExtension or {}, args or {}, flags or {}}
						library(unpack(passed))
					end)
					
					local endTime = DateTime.now().UnixTimestampMillis
					
					if not success then
						self:NewMsg("Error while executing command '"..functionName.."': "..tostring(e))
					else
						--self:NewMsg("Successfully executed command '"..functionName.."' in "..((endTime - startTime)/1000).." seconds")
					end
					
					if newLine == true then self:NewInput() end
					
					return true
				end
			end
			return false
		end
		
		for _, executable in ipairs(exepath) do
			local success = get_bin(executable)
			if success then return end
		end
		
		-- Aliases & Functions
		local aliases = self.plugin:GetSetting("Aliases") or {}
		local aliasCMD = aliases[input]
		
		if aliasCMD then
			local split = string.split(aliasCMD, "&&")
			if table.getn(split) > 1 then
				table.foreachi(split, function(i,v)
					local split2 = string.split(v, "")
					if string.find(split2[1], "%s") then table.remove(split2, 1) end
					if string.find(split2[#split2], "%s") then table.remove(split2, #split2) end
					self:__evaluate(table.concat(split2, ""), true)
				end)
			else
				self:__evaluate(aliases[input], true)
			end
		else
			local functions = self.plugin:GetSetting("Functions") or {}
			local functionsCMD = functions[input]
			
			if functionsCMD then
				for _, v in ipairs(functionsCMD) do
					self:__evaluate(v, false)
				end
			else
				self:NewMsg("Could not find command '"..string.split(input, " ")[1].."'")
			end
		end
		
		if newLine == true then self:NewInput() end
	end
end

return TerminalHandler
