--// Written By: R0bl0x10501050

-- -- -- -- -- -- -- -- -- --

--// Services

local ChangeHistoryService = game:GetService("ChangeHistoryService")

--// Requires

local TerminalHandler = require(script.TerminalHandler)
TerminalHandler:Init(script.Parent:WaitForChild('Terminal'):WaitForChild('ScrollingFrame'), plugin)

--// Local Vars

local toolbar = plugin:CreateToolbar("StudioCLI")

local TerminalButton = toolbar:CreateButton("Open_StudioCLI", "Open The CLI", "rbxassetid://4458901886", "Open StudioCLI")

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Bottom,  -- This is the initial dockstate of the widget
	false,  -- Initial state, enabled or not
	false,  -- Can override previous state?
	800,    -- Default width
	200,    -- Default height
	400,    -- Minimum width
	100     -- Minimum height
)

local terminal = plugin:CreateDockWidgetPluginGui("terminal", widgetInfo)
terminal.Name = "StudioCLI"
terminal.Title = "CLI - Terminal"

local pluginAction = plugin:CreatePluginAction("EnterTerminal", "Enter Terminal", "Enter the StudioCLI Terminal", "rbxasset://textures/sparkle.png", true)

--local pluginMenu = plugin:CreatePluginMenu(math.random(), "RightClick")
--pluginMenu.Name = "RightClick"

--local RightClick_NewTerminal = pluginMenu:AddNewAction("RightClick_NewTerminal", "New Terminal", "http://www.roblox.com/asset/?id=6035047380")
--local RightClick_KillTerminal = pluginMenu:AddNewAction("RightClick_KillTerminal", "Kill Terminal", "http://www.roblox.com/asset/?id=6035067837")

--RightClick_NewTerminal.Triggered:Connect(function()
	
--end)

--RightClick_KillTerminal.Triggered:Connect(function()
	
--end)

-- -- -- -- -- -- -- -- -- --

--// Listeners

TerminalButton.Click:Connect(function()
	terminal.Enabled = not terminal.Enabled
end)

pluginAction.Triggered:Connect(function()
	plugin:GetSetting("Focus"):CaptureFocus()
end)

--// Logic

script.Parent:WaitForChild('Terminal'):WaitForChild('ScrollingFrame').Parent = terminal
