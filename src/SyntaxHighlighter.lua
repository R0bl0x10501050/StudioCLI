-- Syntax highlighter for Terminals like:
-- * Windows Powershell
-- * StudioCLI

-- Boring legal statement...
-- You may NOT copy, redistribute, sell, or modify this module in ANY way
-- unless granted permission from the creator.

-------------------------------------------------------------------------

local RS = game:GetService("RunService")

local HIGHLIGHTING = {
	['cmd'] = Color3.fromRGB(255, 255, 0),
	['regular'] = Color3.fromRGB(238, 238, 238),
	['flags'] = Color3.fromRGB(70, 70, 70),
	['variables'] = Color3.fromRGB(0, 182, 12),
	['numbers'] = Color3.fromRGB(255, 198, 0)
}

local function detectDoubleHyphen(str: string)
	return table.pack(pcall(function() return str:match("^..") end))[2] == "--"
end

local function detectSingleHyphen(str: string)
	return table.pack(pcall(function() return str:match("^.") end))[2] == "-"
end

local function startsWith(str: string, match: string)
	local expression = "^"
	for i = 1, #match:split("") do
		expression ..= "."
	end
	return table.pack(pcall(function() return str:match(expression) end))[2] == match
end

local function clearTags(str: string)
	-- Credit to @JohnnyMorganz for the string pattern
	-- https://devforum.roblox.com/t/richtext-textscaled-support-added/634167/171
	if str == nil then return nil end
	if str == "" or str:match("%s") then return str end
	return table.pack(str:gsub("</?%s*[bius]%s*>", ""):gsub("</?font%s*[%w%s='\"\(\),]*>", ""))[1]
end

local SyntaxHighligher = {}
SyntaxHighligher.__index = SyntaxHighligher

function SyntaxHighligher.new(instance, live)
	local self = setmetatable({
		instance = instance,
		connected = true
	}, SyntaxHighligher)
	
	if live then
		self.thread = task.spawn(function()
			while self.connected == true do
				self:Highlight()
				wait(0.5)
			end
		end)
	end
	
	return self
end

function SyntaxHighligher:RequestOriginalText()
	
	-- Example:
	-- <hello>bye</hello>
	-- Should return: bye
	
	local text = self.instance.Text
	local originalText = ""
	local ignore = false
	local split = text:split("")
	
	local currentIndex = 1
	local currentToken = split[currentIndex]
	
	local function advance()
		currentIndex += 1
		currentToken = split[currentIndex]
	end
	
	while currentToken ~= nil do
		if ignore == true then
			if currentToken == ">" then
				ignore = false
			end
		else
			if currentToken == "<" then
				ignore = true
			else
				originalText ..= currentToken
			end
		end
		
		advance()
	end
	
	return (originalText or "")
end

function SyntaxHighligher:Highlight()
	local text = self.instance.Text
	if text:split("")[1]:match("%s") then
		text = text:gsub("^.", "")
	end
	
	local split = text:split(" ")
	
	local currentIndex = 1
	local currentToken = clearTags(split[currentIndex])
	
	local function advance()
		currentIndex += 1
		currentToken = clearTags(split[currentIndex]) or nil
	end
	
	while currentToken ~= nil do
		if currentToken:match("%s") then
			table.remove(split, currentIndex)
		else
			if not currentToken then continue end
			if currentIndex == 1 then
				split[currentIndex] = "<font color=\"rgb("..tostring(math.round(HIGHLIGHTING.cmd.R*255))..","..tostring(math.round(HIGHLIGHTING.cmd.G*255))..","..tostring(math.round(HIGHLIGHTING.cmd.B*255))..")\">"..split[currentIndex].."</font>"
			elseif startsWith(currentToken, "-") then
				split[currentIndex] = "<font color=\"rgb("..tostring(math.round(HIGHLIGHTING.flags.R*255))..","..tostring(math.round(HIGHLIGHTING.flags.G*255))..","..tostring(math.round(HIGHLIGHTING.flags.B*255))..")\">"..split[currentIndex].."</font>"
			elseif currentToken:match("^."):match("%$") then
				split[currentIndex] = "<font color=\"rgb("..tostring(math.round(HIGHLIGHTING.variables.R*255))..","..tostring(math.round(HIGHLIGHTING.variables.G*255))..","..tostring(math.round(HIGHLIGHTING.variables.B*255))..")\">"..split[currentIndex].."</font>"
			elseif currentToken:match("^."):match("%d") then
				split[currentIndex] = "<font color=\"rgb("..tostring(math.round(HIGHLIGHTING.numbers.R*255))..","..tostring(math.round(HIGHLIGHTING.numbers.G*255))..","..tostring(math.round(HIGHLIGHTING.numbers.B*255))..")\">"..split[currentIndex].."</font>"
			elseif currentToken:match("^."):match("%a") then
				split[currentIndex] = "<font color=\"rgb("..tostring(math.round(HIGHLIGHTING.regular.R*255))..","..tostring(math.round(HIGHLIGHTING.regular.G*255))..","..tostring(math.round(HIGHLIGHTING.regular.B*255))..")\">"..split[currentIndex].."</font>"
			end
			advance()
		end
	end
	
	--print(split)
	--split[1] = "<font color=\"rgb("..tostring(math.round(HIGHLIGHTING.cmd.R*255))..","..tostring(math.round(HIGHLIGHTING.cmd.G*255))..","..tostring(math.round(HIGHLIGHTING.cmd.B*255))..")\">"..clearTags(split[1]).."</font>"
	--print(split)
	
	self.instance.Text = table.concat(split, " ")
end

function SyntaxHighligher:Destroy()
	self.connected = false
	if self.thread then coroutine.yield(self.thread) end
	self = nil
end

return SyntaxHighligher
