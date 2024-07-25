--// Written by depso

local ImGui = {
	Animations = {
		Buttons = {
			MouseEnter = {
				BackgroundTransparency = 0.5,
			},
			MouseLeave = {
				BackgroundTransparency = 0.7,
			} 
		},
		Tabs = {
			MouseEnter = {
				BackgroundTransparency = 0.5,
			},
			MouseLeave = {
				BackgroundTransparency = 1,
			} 
		},
		Inputs = {
			MouseEnter = {
				BackgroundTransparency = 0,
			},
			MouseLeave = {
				BackgroundTransparency = 0.5,
			} 
		},
		WindowBorder = {
			Selected = {
				Transparency = 0,
				Thickness = 1
			},
			Deselected = {
				Transparency = 0.2,
				Thickness = 0.5
			}
		},
	},

	Windows = {},
	Animation = TweenInfo.new(0.1),
	UIAssetId = "rbxassetid://18364667141"
}

function ImGui:GetName(Name: string)
	local Format = "%s_"
	return Format:format(Name)
end

--// Universal functions
local CloneRef = cloneref or function(_)return _ end
local function GetService(...): ServiceProvider
	return CloneRef(game:GetService(...))
end

--// Services 
local TweenService: TweenService = GetService("TweenService")
local UserInputService: UserInputService = GetService("UserInputService")
local Players: Players = GetService("Players")
local CoreGui = GetService("CoreGui")
local RunService: RunService = GetService("RunService")

--// LocalPlayer
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui
local Mouse = LocalPlayer:GetMouse()

local NullFunction = function() end
local IsStudio = RunService:IsStudio()

local GuiParent = IsStudio and PlayerGui or CoreGui
local ImGuiScreenGui = Instance.new("ScreenGui", GuiParent)
ImGui.ScreenGui = ImGuiScreenGui

--// Prefabs
local UI = IsStudio and PlayerGui.DepsoImGui or game:GetObjects(ImGui.UIAssetId)[1]

local Prefabs = UI.Prefabs
ImGui.Prefabs = Prefabs
Prefabs.Visible = false

local AddionalStyles = {
	[{
		Name="Border"
	}] = function(GuiObject: GuiObject, Value, Class)
		local Outline = GuiObject:FindFirstChildOfClass("UIStroke")
		if not Outline then return end

		local BorderThickness = Class.BorderThickness
		if BorderThickness then
			Outline.Thickness = BorderThickness
		end

		Outline.Enabled = Value
	end,

	[{
		Name="Ratio"
	}] = function(GuiObject: GuiObject, Value, Class)
		local RatioAxis = Class.RatioAxis or "Height"
		local AspectRatio = Class.Ratio or 4/3
		local AspectType = Class.AspectType or Enum.AspectType.ScaleWithParentSize

		local Ratio = GuiObject:FindFirstChildOfClass("UIAspectRatioConstraint")
		if not Ratio then
			Ratio = Instance.new("UIAspectRatioConstraint", GuiObject)
		end

		Ratio.DominantAxis = Enum.DominantAxis[RatioAxis]
		Ratio.AspectType = AspectType
		Ratio.AspectRatio = AspectRatio
	end,

	[{
		Name="CornerRadius",
		Recursive=true
	}] = function(GuiObject: GuiObject, Value, Class)
		local UICorner = GuiObject:FindFirstChildOfClass("UICorner")
		if not UICorner then
			UICorner = Instance.new("UICorner", GuiObject)
		end

		UICorner.CornerRadius = Class.CornerRadius
	end,

	[{
		Name="Label"
	}] = function(GuiObject: GuiObject, Value, Class)
		local Label = GuiObject:FindFirstChild("Label")
		if not Label then return end

		Label.Text = Class.Label
		function Class:SetLabel(Text)
			Label.Text = Label
			return Class
		end
	end,

	[{
		Name="NoGradient",
		Aliases = {"NoGradientAll"},
		Recursive=true
	}] = function(GuiObject: GuiObject, Value, Class)
		local UIGradient = GuiObject:FindFirstChildOfClass("UIGradient")
		if not UIGradient then return end
		UIGradient.Enabled = not Value
	end,

	--// Addional functions for classes
	[{
		Name="Callback"
	}] = function(GuiObject: GuiObject, Value, Class)
		function Class:SetCallback(NewCallback)
			Class.Callback = NewCallback
			return Class
		end
		function Class:FireCallback(NewCallback)
			return Class.Callback(GuiObject)
		end
	end,

	[{
		Name="Value"
	}] = function(GuiObject: GuiObject, Value, Class)
		function Class:GetValue()
			return Class.Value
		end
	end,
}

function ImGui:ApplyColors(ColorOverwrites, GuiObject: GuiObject, ElementType: string)
	for Info, Value in next, ColorOverwrites do
		local Key = Info
		local Recursive = false

		if typeof(Info) == "table" then
			Key = Info.Name or ""
			Recursive = Info.Recursive or false
		end

		--// Child object
		if typeof(Value) == "table" then
			local Element = GuiObject:FindFirstChild(Key, Recursive)

			if not Element then 
				if ElementType == "Window" then
					Element = GuiObject.Content:FindFirstChild(Key, Recursive)
					if not Element then continue end
				else 
					warn(Key, "was not found in", GuiObject)
					warn("Table:", Value)

					continue
				end
			end

			ImGui:ApplyColors(Value, Element)
			continue
		end

		--// Set property
		GuiObject[Key] = Value
	end
end

function ImGui:CheckStyles(GuiObject: GuiObject, Class, Colors)
	--// Addional styles
	for Info, Callback in next, AddionalStyles do
		local Value = Class[Info.Name]
		local Aliases = Info.Aliases

		if Aliases and not Value then
			for _, Alias in Info.Aliases do
				Value = Class[Alias]
				if Value then break end
			end
		end
		if not Value then continue end

		Callback(GuiObject, Value, Class)
		if Info.Recursive then
			for _, Child in next, GuiObject:GetChildren() do
				Callback(Child, Value, Class)
			end
		end
	end

	--// Label functions/Styliser
	local ElementType = GuiObject.Name
	GuiObject.Name = self:GetName(ElementType)

	--// Apply Colors
	local Colors = Colors or {}
	local ColorOverwrites = Colors[ElementType]

	if ColorOverwrites then
		ImGui:ApplyColors(ColorOverwrites, GuiObject, ElementType)
	end

	--// Set properties
	for Key, Value in next, Class do
		pcall(function() --// If the property does not exist
			GuiObject[Key] = Value
		end)
	end
end

function ImGui:MergeMetatables(Class, Instance: GuiObject)
	local Metadata = {}
	Metadata.__index = function(self, Key)
		local suc, Value = pcall(function()
			local Value = Instance[Key]
			if typeof(Value) == "function" then
				return function(...)
					return Value(Instance, ...)
				end
			end
			return Value
		end)
		return suc and Value or Class[Key]
	end

	Metadata.__newindex = function(self, Key, Value)
		local Key2 = Class[Key]
		if Key2 ~= nil or typeof(Value) == "function" then
			Class[Key] = Value
		else
			Instance[Key] = Value
		end
	end

	return setmetatable({}, Metadata)
end

function ImGui:ContainerClass(Frame: Frame, Class, Window)
	local ContainerClass = Class or {}
	local WindowConfig = ImGui.Windows[Window]

	function ContainerClass:NewInstance(Instance: Frame, Class, Parent)
		--// Config
		Class = Class or {}

		--// Set Parent
		Instance.Parent = Parent or Frame
		Instance.Visible = true

		if WindowConfig.NoGradientAll then
			Class.NoGradient = true
		end

		local Colors = WindowConfig.Colors
		ImGui:CheckStyles(Instance, Class, Colors)

		--// External callback check
		if Class.NewInstanceCallback then
			Class.NewInstanceCallback(Instance)
		end

		--// Merge the class with the properties of the instance
		return ImGui:MergeMetatables(Class, Instance)
	end

	function ContainerClass:Button(Config)
		Config = Config or {}
		local Button = Prefabs.Button:Clone()

		local function Callback(...)
			local func = Config.Callback or NullFunction
			return func(Button, ...)
		end
		Button.Activated:Connect(Callback)

		--// Apply animations
		ImGui:ApplyAnimations(Button, "Buttons")
		return self:NewInstance(Button, Config)
	end

	function ContainerClass:Image(Config)
		Config = Config or {}
		local Image = Prefabs.Image:Clone()

		local function Callback(...)
			local func = Config.Callback or NullFunction
			return func(Image, ...)
		end
		Image.Activated:Connect(Callback)

		if tonumber(Config.Image) then
			Image.Image = "rbxassetid://"..Config.Image
			Config.Image = nil --// Prevent overwriting
		end

		--// Apply animations
		ImGui:ApplyAnimations(Image, "Buttons")
		return self:NewInstance(Image, Config)
	end

	function ContainerClass:ScrollingBox(Config)
		Config = Config or {}
		local Box = Prefabs.ScrollBox:Clone()
		local ContainClass = ImGui:ContainerClass(Box, Config, Window) 
		return self:NewInstance(Box, ContainClass)
	end

	function ContainerClass:Label(Config)
		Config = Config or {}
		local Label = Prefabs.Label:Clone()
		return self:NewInstance(Label, Config)
	end

	function ContainerClass:Checkbox(Config)
		Config = Config or {}
		local IsRadio = Config.IsRadio

		local CheckBox = Prefabs.CheckBox:Clone()
		local Tickbox: ImageButton = CheckBox.Tickbox
		local Tick: ImageLabel = Tickbox.Tick
		local Label = CheckBox.Label

		--// Stylise to correct type
		if IsRadio then
			Tick.ImageTransparency = 1
			Tick.BackgroundTransparency = 0
		else
			Tickbox:FindFirstChildOfClass("UIPadding"):Remove()
			Tickbox:FindFirstChildOfClass("UICorner"):Remove()
		end

		--// Apply animations
		ImGui:ApplyAnimations(CheckBox, "Buttons", Tickbox)

		local Value = Config.Value or false

		--// Callback
		local function Callback(...)
			local func = Config.Callback or NullFunction
			return func(CheckBox, ...)
		end

		function Config:SetTicked(NewValue: boolean)
			Value = NewValue
			Config.Value = Value

			--// Fire callback
			Callback(Value)

			--// Animations
			local Size = Value and UDim2.fromScale(1,1) or UDim2.fromScale(0,0)
			ImGui:Tween(Tick, {
				Size = Size
			})
			ImGui:Tween(Label, {
				TextTransparency = Value and 0 or 0.3
			})
			return Config
		end
		Config:SetTicked(Value)

		function Config:Toggle()
			Config:SetTicked(not Value)
			return Config
		end

		--// Connect functions
		local function Clicked()
			Value = not Value
			Config:SetTicked(Value)
		end
		CheckBox.Activated:Connect(Clicked)
		Tickbox.Activated:Connect(Clicked)

		return self:NewInstance(CheckBox, Config)
	end

	function ContainerClass:RadioButton(Config)
		Config = Config or {}
		Config.IsRadio = true
		return self:Checkbox(Config)
	end

	function ContainerClass:Viewport(Config)
		Config = Config or {}
		local Model = Config.Model

		local Holder = Prefabs.Viewport:Clone()
		local Viewport: ViewportFrame = Holder.Viewport
		local WorldModel: WorldModel = Viewport.WorldModel
		Config.WorldModel = WorldModel
		Config.Viewport = Viewport

		function Config:SetCamera(Camera)
			Viewport.CurrentCamera = Camera
			Config.Camera = Camera
			Camera.CFrame = CFrame.new(0,0,0)
			return Config
		end

		local Camera = Config.Camera or Instance.new("Camera", Viewport)
		Config:SetCamera(Camera)

		function Config:SetModel(Model: Model, PivotTo: CFrame)
			WorldModel:ClearAllChildren()

			--// Set new model
			if Config.Clone then
				Model = Model:Clone()
			end
			if PivotTo then
				Model:PivotTo(PivotTo)
			end

			Model.Parent = WorldModel
			Config.Model = Model
			return Config
		end

		--// Set model
		if Model then
			Config:SetModel(Model)
		end

		local ContainClass = ImGui:ContainerClass(Holder, Config, Window) 
		return self:NewInstance(Holder, ContainClass)
	end

	function ContainerClass:InputText(Config)
		Config = Config or {}
		local TextInput = Prefabs.TextInput:Clone()
		local TextBox: TextBox = TextInput.Input

		TextBox.Text = Config.Value or ""
		TextBox.PlaceholderText = Config.PlaceHolder
		TextBox.MultiLine = Config.MultiLine == true

		--// Apply animations
		ImGui:ApplyAnimations(TextInput, "Inputs")

		local function Callback(...)
			local func = Config.Callback or NullFunction
			return func(TextBox, ...)
		end
		TextBox:GetPropertyChangedSignal("Text"):Connect(function()
			local Value = TextBox.Text
			Config.Value = Value
			return Callback(Value)
		end)

		function Config:SetValue(Text)
			TextBox.Text = tostring(Text)
			Config.Value = Text
			return Config
		end

		function Config:Clear()
			TextBox.Text = ""
			return Config
		end

		return self:NewInstance(TextInput, Config)
	end

	function ContainerClass:InputTextMultiline(Config)
		Config = Config or {}
		Config.Label = ""
		Config.Size = UDim2.new(1, 0, 0, 38)
		Config.MultiLine = true
		return ContainerClass:InputText(Config)
	end

	function ContainerClass:GetRemainingHeight()
		local Padding = Frame:FindFirstChildOfClass("UIPadding")
		local UIListLayout = Frame:FindFirstChildOfClass("UIListLayout")

		local LayoutPaddding = UIListLayout.Padding
		local PaddingTop = Padding.PaddingTop
		local PaddingBottom = Padding.PaddingBottom

		local PaddingSizeY = PaddingTop+PaddingBottom+LayoutPaddding
		local OccupiedY = Frame.AbsoluteSize.Y+PaddingSizeY.Offset+3

		return UDim2.new(1, 0, 1, -OccupiedY) 
	end

	function ContainerClass:Console(Config)
		Config = Config or {}
		local MaxLines = Config.MaxLines or 100
		local Console: ScrollingFrame = Prefabs.Console:Clone()
		local Source: TextBox = Console.Source
		local Lines = Console.Lines

		if Config.Fill then
			Console.Size = ContainerClass:GetRemainingHeight()
		end

		--// Set values from config
		Source.TextEditable = Config.ReadOnly ~= true
		Source.Text = Config.Text or ""
		Source.TextWrapped = Config.TextWrapped == true
		Source.RichText = Config.RichText == true
		Lines.Visible = Config.LineNumbers == true

		function Config:UpdateLineNumbers()
			if not Config.LineNumbers then return end

			local LinesCount = #Source.Text:split("\n")
			local Format = Config.LinesFormat or "%s"

			--// Update lines text
			Lines.Text = ""
			for i = 1, LinesCount do
				Lines.Text ..= `{Format:format(i)}{i ~= LinesCount and '\n' or ''}`
			end

			Source.Size = UDim2.new(1, -Lines.AbsoluteSize.X, 0, 0)
			return Config
		end

		function Config:UpdateScroll()
			local CanvasSizeY = Console.AbsoluteCanvasSize.Y
			Console.CanvasPosition = Vector2.new(0, CanvasSizeY)
			return Config
		end

		function Config:SetText(Text)
			if not Config.Enabled then return end
			Source.Text = Text
			Config:UpdateLineNumbers()
			return Config
		end

		function Config:Clear(Text)
			Source.Text = ""
			Config:UpdateLineNumbers()
			return Config
		end

		function Config:AppendText(...)
			if not Config.Enabled then return end
			local NewString = "\n" .. table.concat({...}, " ")
			Source.Text ..= NewString
			Config:UpdateLineNumbers()

			if Config.AutoScroll then
				Config:UpdateScroll()
			end

			local Lines = Source.Text:split("\n")
			if #Lines > MaxLines then
				Source.Text = Source.Text:sub(#Lines[1]+2)
			end
			return Config
		end

		--// Connect events
		Source.Changed:Connect(Config.UpdateLineNumbers)

		return self:NewInstance(Console, Config)
	end

	function ContainerClass:Table(Config)
		Config = Config or {}
		local Table: Frame = Prefabs.Table:Clone()
		local TableChildCount = #Table:GetChildren() --// Performance

		--// Configure Table style
		if Config.Fill then
			Table.Size = ContainerClass:GetRemainingHeight()
		end
		local RowName = "Row"

		local RowsCount = 0
		function Config:CreateRow()
			local RowClass = {}

			local Row: Frame = Table.RowTemp:Clone()
			local UIListLayout = Row:FindFirstChildOfClass("UIListLayout")
			UIListLayout.VerticalAlignment = Enum.VerticalAlignment[Config.Align or "Center"]

			local RowChildCount = #Row:GetChildren() --// Performance
			Row.Name = RowName
			Row.Visible = true

			if Config.RowBackground then
				Row.BackgroundTransparency = RowsCount % 2 == 1 and 0.94 or 1
			end

			function RowClass:CreateColumn(CConfig)
				CConfig = CConfig or {}
				local Column: Frame = Row.ColumnTemp:Clone()
				Column.Visible = true
				Column.Name = "Column"

				local Stroke = Column:FindFirstChildOfClass("UIStroke")
				Stroke.Enabled = Config.Border ~= false

				local ContainClass = ImGui:ContainerClass(Column, CConfig, Window) 
				return ContainerClass:NewInstance(Column, ContainClass, Row)
			end

			function RowClass:UpdateColumns()
				if not Row or not Table then return end
				local Columns = Row:GetChildren()
				local RowsCount = #Columns - RowChildCount

				for _, Column: Frame in next, Columns do
					if not Column:IsA("Frame") then continue end
					Column.Size = UDim2.new(1/RowsCount, 0, 0, 0)
				end
				return RowClass
			end
			Row.ChildAdded:Connect(RowClass.UpdateColumns)
			Row.ChildRemoved:Connect(RowClass.UpdateColumns)

			RowsCount += 1
			return ContainerClass:NewInstance(Row, RowClass, Table)
		end

		function Config:UpdateRows()
			local Rows = Table:GetChildren()
			local PaddingY = Table.UIListLayout.Padding.Offset + 2
			local RowsCount = #Rows - TableChildCount

			for _, Row: Frame in next, Rows do
				if not Row:IsA("Frame") then continue end
				Row.Size = UDim2.new(1, 0, 1/RowsCount, -PaddingY)
			end
			return Config
		end

		if Config.RowsFill then
			Table.AutomaticSize = Enum.AutomaticSize.None
			Table.ChildAdded:Connect(Config.UpdateRows)
			Table.ChildRemoved:Connect(Config.UpdateRows)
		end

		function Config:ClearRows()
			RowsCount = 0
			local PostRowName = ImGui:GetName(RowName)
			for _, Row: Frame in next, Table:GetChildren() do
				if not Row:IsA("Frame") then continue end

				if Row.Name == PostRowName then
					Row:Remove()
				end
			end
			return Config
		end

		return self:NewInstance(Table, Config) 
	end

	function ContainerClass:Grid(Config)
		Config = Config or {}
		Config.Grid = true

		return self:Table(Config)
	end

	function ContainerClass:CollapsingHeader(Config)
		Config = Config or {}
		local Title = Config.Title or ""
		Config.Name = Title

		local Header = Prefabs.CollapsingHeader:Clone()
		local Titlebar: TextButton = Header.TitleBar
		local Container: Frame = Header.ChildContainer
		Titlebar.Title.Text = Title

		--// Apply animations
		if Config.IsTree then
			ImGui:ApplyAnimations(Titlebar, "Tabs")
		else
			ImGui:ApplyAnimations(Titlebar, "Buttons")
		end

		--// Open Animations
		Config.Open = false
		function Config:SetOpen(Open)
			local Animate = Config.NoAnimation ~= true
			ImGui:HeaderAnimate(Header, Animate, Config.Open, Titlebar)
			return self
		end

		--// Toggle
		local ToggleButton = Titlebar.Toggle.ToggleButton
		local function Toggle()
			Config.Open = not Config.Open
			Config:SetOpen(Config.Open)
		end
		Titlebar.Activated:Connect(Toggle)
		ToggleButton.Activated:Connect(Toggle)

		--// Custom toggle image
		if Config.Image then
			ToggleButton.Image = Config.Image 
		end

		local ContainClass = ImGui:ContainerClass(Container, Config, Window) 
		return self:NewInstance(Header, ContainClass)
	end

	function ContainerClass:TreeNode(Config)
		Config = Config or {}
		Config.IsTree = true
		return self:CollapsingHeader(Config)
	end

	function ContainerClass:Separator(Config)
		Config = Config or {}
		local Separator = Prefabs.SeparatorText:Clone()
		local HeaderLabel = Separator.TextLabel
		HeaderLabel.Text = Config.Text or ""

		if not Config.Text then
			HeaderLabel.Visible = false
		end

		return self:NewInstance(Separator, Config)
	end

	function ContainerClass:Row(Config)
		Config = Config or {}
		local Row: Frame = Prefabs.Row:Clone()
		local UIListLayout = Row:FindFirstChildOfClass("UIListLayout")
		local UIPadding = Row:FindFirstChildOfClass("UIPadding")

		--// Apply correct margins
		UIPadding.PaddingLeft = UIListLayout.Padding
		UIPadding.PaddingRight = UIListLayout.Padding

		if Config.Spacing then
			UIListLayout.Padding = UDim.new(0, Config.Spacing)
		end

		function Config:Fill()
			local Children = Row:GetChildren()
			local Rows = #Children - 2 --// -UIListLayout + UIPadding

			--// Change layout
			local Padding = UIListLayout.Padding.Offset * 2
			UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

			for _, Child: Instance in next, Children do
				local YScale = 0
				if Child:IsA("ImageButton") then
					YScale = 1
				end
				pcall(function()
					Child.Size = UDim2.new(1/Rows, -Padding, YScale, 0)
				end)
			end
			return Config
		end

		local ContainClass = ImGui:ContainerClass(Row, Config, Window) 
		return self:NewInstance(Row, ContainClass)
	end

	function ContainerClass:Slider(Config)
		Config = Config or {}
		local Value = Config.Value or 0
		local ValueFormat = Config.Format or "%.d"
		Config.Name = Config.Label or ""

		local Slider: TextButton = Prefabs.Slider:Clone()
		local UIPadding = Slider:FindFirstChildOfClass("UIPadding")
		local Grab: Frame = Slider.Grab
		local ValueText = Slider.ValueText

		local function Callback(...)
			local func = Config.Callback or NullFunction
			return func(Slider, ...)
		end

		--// Apply Progress styles
		if Config.Progress then
			local UIGradient = Grab:FindFirstChildOfClass("UIGradient")
			local Label = Slider.Label

			local PaddingSides = UDim.new(0,2)
			local Diff = UIPadding.PaddingLeft - PaddingSides

			Grab.AnchorPoint = Vector2.new(0, 0.5)
			UIGradient.Enabled = true

			UIPadding.PaddingLeft = PaddingSides
			UIPadding.PaddingRight = PaddingSides

			Label.Position = UDim2.new(1, 15-Diff.Offset, 0, 0)
		end

		function Config:SetValue(Value: number, Slider: false)
			local MinValue = Config.MinValue
			local MaxValue = Config.MaxValue
			local Differnce = MaxValue - MinValue
			local Percentage = Value/MaxValue

			if Slider then
				Percentage = Value
				Value = MinValue + (Differnce * Percentage)
			else
				Value = tonumber(Value)
			end

			--// Animate grab
			local Props = {
				Position = UDim2.fromScale(Percentage, 0.5)
			}

			if Config.Progress then
				Props = {
					Size = UDim2.fromScale(Percentage, 1)
				}
			end

			ImGui:Tween(Grab, Props)

			Config.Value = Value
			ValueText.Text = ValueFormat:format(Value, MaxValue) 

			Callback(Value)
			return Config
		end
		Config:SetValue(Value)

		local Dragging = false
		local MouseMoveConnection = nil
		local Hovering = false

		local function MouseMove()
			if Config.ReadOnly then return end
			if not Dragging then return end
			local MouseX = UserInputService:GetMouseLocation().X
			local LeftPos = Slider.AbsolutePosition.X

			local Percentage = (MouseX-LeftPos)/Slider.AbsoluteSize.X
			Percentage = math.clamp(Percentage, 0, 1)
			Config:SetValue(Percentage, true)
		end

		--// Connect mouse events
		Slider.MouseEnter:Connect(function()
			Hovering = true
		end)
		Slider.MouseLeave:Connect(function()
			Hovering = false
		end)
		Slider.Activated:Connect(MouseMove)

		UserInputService.InputBegan:Connect(function(inputObject)
			if not Hovering then return end
			if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
				Dragging = true

				--// Save heavy performance
				MouseMoveConnection = Mouse.Move:Connect(MouseMove)
			end
		end)
		UserInputService.InputEnded:Connect(function(inputObject)
			if not Dragging then return end
			if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
				Dragging = false
				MouseMoveConnection:Disconnect()
			end
		end)

		return self:NewInstance(Slider, Config)
	end

	function ContainerClass:ProgressSlider(Config)
		Config = Config or {}
		Config.Progress = true
		return self:Slider(Config)
	end

	function ContainerClass:ProgressBar(Config)
		Config = Config or {}
		Config.Progress = true
		Config.ReadOnly = true
		Config.MinValue = 0
		Config.MaxValue = 100
		Config.Format = "% i%%"
		Config = self:Slider(Config)

		function Config:SetPercentage(Value: number)
			Config:SetValue(Value)
		end

		return Config
	end

	function ContainerClass:Keybind(Config)
		local Keybind: TextButton = Prefabs.Keybind:Clone()
		local ValueText: TextButton = Keybind.ValueText
		local Key = Config.Value 

		local function Callback(...)
			local func = Config.Callback or NullFunction
			return func(Keybind, ...)
		end

		function Config:SetValue(NewKey: Enum.KeyCode)
			if not NewKey then return end
			ValueText.Text = NewKey.Name
			Config.Value = NewKey

			if NewKey == Enum.KeyCode.Backspace then
				ValueText.Text = "Not set"
				return
			end
		end
		Config:SetValue(Key)

		Keybind.Activated:Connect(function()
			ValueText.Text = "..."
			local NewKey = UserInputService.InputBegan:wait()
			if not UserInputService.WindowFocused then return end 

			if NewKey.KeyCode.Name == "Unknown" then
				return Config:SetValue(Key)
			end

			wait(.1) --// 👍
			Config:SetValue(NewKey.KeyCode)
		end)

		Config.Connection = UserInputService.InputBegan:Connect(function(Input, GameProcessed)
			if not Config.IgnoreGameProcessed and GameProcessed then return end

			if Input.KeyCode == Config.Value then
				return Callback(Input.KeyCode)
			end
		end)

		return self:NewInstance(Keybind, Config)
	end

	return ContainerClass
end

function ImGui:GetAnimation(Animation: boolean?)
	return Animation and self.Animation or TweenInfo.new(0)
end

function ImGui:Tween(Instance: GuiObject, Props: SharedTable, tweenInfo)
	local tweenInfo = tweenInfo or ImGui:GetAnimation(true)
	local Tween = TweenService:Create(Instance, 
		tweenInfo,
		Props
	)
	Tween:Play()
	return Tween
end

function ImGui:ApplyAnimations(Instance: GuiObject, Class: string, Target: GuiObject?)
	local Animatons = ImGui.Animations
	local ColorProps = Animatons[Class]

	if not ColorProps then 
		return warn("No colors for", Class)
	end

	--// Apply tweens for connections
	local Connections = {}
	for Connection, Props in next, ColorProps do
		if typeof(Props) ~= "table" then continue end
		local Target = Target or Instance
		local Callback = function()
			ImGui:Tween(Target, Props)
		end

		--// Connections
		Connections[Connection] = Callback
		Instance[Connection]:Connect(Callback)
	end

	--// Reset colors
	if Connections["MouseLeave"] then
		Connections["MouseLeave"]()
	end

	return Connections 
end

function ImGui:HeaderAnimate(Header: Instance, Animation, Open, TitleBar: Instance, Toggle)
	local ToggleButtion = Toggle or TitleBar.Toggle.ToggleButton

	--// Togle animation
	ImGui:Tween(ToggleButtion, {
		Rotation = Open and 90 or 0,
	}):Play()

	--// Container animation
	local Container: Frame = Header:FindFirstChild("ChildContainer")
	if not Container then return end

	local UIListLayout: UIListLayout = Container.UIListLayout
	local UIPadding: UIPadding = Container:FindFirstChildOfClass("UIPadding")
	local ContentSize = UIListLayout.AbsoluteContentSize

	if UIPadding then
		local Top = UIPadding.PaddingTop.Offset
		local Bottom = UIPadding.PaddingBottom.Offset
		ContentSize = Vector2.new(ContentSize.X, ContentSize.Y+Top+Bottom)
	end

	Container.AutomaticSize = Enum.AutomaticSize.None
	if not Open then
		Container.Size = UDim2.new(1, -10, 0, ContentSize.Y)
	end

	ImGui:Tween(Container, {
		Size = UDim2.new(1, -10, 0, Open and ContentSize.Y or 0)
	}).Completed:Connect(function()
		if not Open then return end
		Container.AutomaticSize = Enum.AutomaticSize.Y
		Container.Size = UDim2.new(1, -10, 0, 0)
	end)
end

function ImGui:ApplyDraggable(Frame: Frame, Header: Frame)
	local tweenInfo = ImGui:GetAnimation(true)
	local Header = Header or Frame

	local Dragging = false
	local Input = nil
	local KeyBeganPos = nil
	local BeganPos = Frame.Position

	--// Debounce 
	Header.InputBegan:Connect(function(Key)
		if Key.UserInputType == Enum.UserInputType.MouseButton1 then
			Dragging = true
			Input = Key
			KeyBeganPos = Key.Position
			BeganPos = Frame.Position
		end
	end)
	Header.InputEnded:Connect(function(Key)
		if Key.UserInputType == Enum.UserInputType.MouseButton1 then
			Dragging = false
		end
	end)

	--// Dragging
	UserInputService.InputChanged:Connect(function(Input)
		if not Dragging or Input.UserInputType ~= Enum.UserInputType.MouseMovement then 
			return
		end

		local Delta = Input.Position - KeyBeganPos
		local Position = UDim2.new(
			BeganPos.X.Scale, 
			BeganPos.X.Offset + Delta.X, 
			BeganPos.Y.Scale, 
			BeganPos.Y.Offset + Delta.Y
		)
		ImGui:Tween(Frame, {
			Position = Position
		}):Play()
	end)
end

function ImGui:ApplyResizable(MinSize, Frame: Frame, Dragger: TextButton, Config)
	MinSize = MinSize or Vector2.new(160, 90)

	local startDrag
	local startSize

	Dragger.MouseButton1Down:Connect(function()
		if startDrag then return end
		startSize = Frame.AbsoluteSize			
		startDrag = Vector2.new(Mouse.X, Mouse.Y)
	end)	

	UserInputService.InputChanged:Connect(function(Input)
		if not startDrag or Input.UserInputType ~= Enum.UserInputType.MouseMovement then 
			return
		end

		local MousePos = Vector2.new(Mouse.X, Mouse.Y)
		local mouseMoved = MousePos - startDrag

		local NewSize = startSize + mouseMoved
		NewSize = UDim2.fromOffset(
			math.max(MinSize.X, NewSize.X), 
			math.max(MinSize.Y, NewSize.Y)
		)

		Frame.Size = NewSize
		if Config then
			Config.Size = NewSize
		end
	end)

	UserInputService.InputEnded:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then
			startDrag = nil
		end
	end)	
end


function ImGui:ApplyWindowSelectEffect(Window: GuiObject, TitleBar)
	local UIStroke = Window:FindFirstChildOfClass("UIStroke")

	local MouseHovering = false
	local Colors = {
		Selected = {
			BackgroundColor3 = TitleBar.BackgroundColor3
		},
		Deselected = {
			BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		}
	}

	local function SetSelected(Selected)
		local Animations = ImGui.Animations
		local Type = Selected and "Selected" or "Deselected"
		local TweenInfo = ImGui:GetAnimation(true) 

		ImGui:Tween(TitleBar, Colors[Type])
		ImGui:Tween(UIStroke, Animations.WindowBorder[Type])
	end

	--// Connect Events
	Window.MouseEnter:Connect(function()
		MouseHovering = true
	end)
	Window.MouseLeave:Connect(function()
		MouseHovering = false
	end)
	UserInputService.InputBegan:Connect(function(Input)
		if Input.UserInputType.Name:find("Mouse") then
			SetSelected(MouseHovering)
		end
	end)
end

function ImGui:CreateWindow(WindowConfig)
	--// UI Elements
	local Window: Frame = Prefabs.Window:Clone()
	Window.Visible = true
	Window.Parent = ImGui.ScreenGui

	local Content = Window.Content
	local Body = Content.Body

	--// Resize
	local Resize = Window.ResizeGrip
	Resize.Visible = WindowConfig.NoResize ~= true
	ImGui:ApplyResizable(
		Vector2.new(160, 90), 
		Window, 
		Resize,
		WindowConfig
	)

	--// Title Bar
	local TitleBar: Frame = Content.TitleBar
	TitleBar.Visible = WindowConfig.NoTitleBar ~= true

	local Toggle = TitleBar.Left.Toggle
	Toggle.Visible = WindowConfig.NoCollapse ~= true
	ImGui:ApplyAnimations(Toggle.ToggleButton, "Tabs")

	local ToolBar = Content.ToolBar
	ToolBar.Visible = WindowConfig.TabsBar ~= false

	if not WindowConfig.NoDrag then
		ImGui:ApplyDraggable(Window)
	end

	--// Close Window
	local CloseButton: TextButton = TitleBar.Close
	CloseButton.Visible = WindowConfig.NoClose ~= true
	CloseButton.Activated:Connect(function()
		local Callback = WindowConfig.CloseCallback
		WindowConfig:SetVisible(false)
		if Callback then
			Callback(WindowConfig)
		end
	end)

	function WindowConfig:GetHeaderSizeY(): number
		local ToolbarY = ToolBar.Visible and ToolBar.AbsoluteSize.Y or 0
		local TitlebarY = TitleBar.Visible and TitleBar.AbsoluteSize.Y or 0
		return ToolbarY + TitlebarY
	end

	function WindowConfig:UpdateBody()
		local HeaderSizeY = self:GetHeaderSizeY()
		Body.Size = UDim2.new(1, 0, 1, -HeaderSizeY)
	end
	WindowConfig:UpdateBody()

	--// Open/Close
	WindowConfig.Open = true
	function WindowConfig:SetOpen(Open: true, Animation: boolean)
		WindowConfig.Open = Open

		ImGui:HeaderAnimate(TitleBar, true, Open, TitleBar, Toggle.ToggleButton)

		ImGui:Tween(Resize, {
			TextTransparency = Open and 0.6 or 1,
			Interactable = Open
		})

		local WindowAbSize = Window.AbsoluteSize 
		local TitleBarSize = TitleBar.AbsoluteSize 

		ImGui:Tween(Window, {
			Size = Open and self.Size or UDim2.fromOffset(WindowAbSize.X, TitleBarSize.Y)
		}):Play()
		return self
	end

	function WindowConfig:SetVisible(Visible: boolean)
		Window.Visible = Visible 
		return self
	end

	function WindowConfig:SetTitle(Text)
		TitleBar.Left.Title.Text = tostring(Text)
		return self
	end
	function WindowConfig:Remove()
		Window:Remove()
		return self
	end

	Toggle.ToggleButton.Activated:Connect(function()
		local Open = not WindowConfig.Open
		WindowConfig.Open = Open
		return WindowConfig:SetOpen(Open, true)
	end)	

	function WindowConfig:CreateTab(Config)
		local Name = Config.Name or ""
		local TabButton = ToolBar.TabButton:Clone()
		TabButton.Name = Name
		TabButton.Text = Name
		TabButton.Visible = true
		TabButton.Parent = ToolBar

		--// Apply animations
		ImGui:ApplyAnimations(TabButton, "Tabs")

		local AutoSizeAxis = WindowConfig.AutoSize or "Y"
		local Tab: Frame = Body.Template:Clone()
		Tab.AutomaticSize = Enum.AutomaticSize[AutoSizeAxis]
		Tab.Visible = Config.Visible or false
		Tab.Name = Name
		Tab.Parent = Body

		if AutoSizeAxis == "Y" then
			Tab.Size = UDim2.fromScale(1, 0)
		elseif AutoSizeAxis == "X" then
			Tab.Size = UDim2.fromScale(0, 1)
		end

		local Class = {
			Content = Tab,
			Button = TabButton
		}

		TabButton.Activated:Connect(function()
			WindowConfig:ShowTab(Class)
		end)

		function Class:GetContentSize()
			return Tab.AbsoluteSize
		end

		--// Automatic sizes
		self:UpdateBody()
		if WindowConfig.AutoSize then
			Tab:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				wait()
				self:SetSize(Class:GetContentSize())
			end)
		end

		return ImGui:ContainerClass(Tab, Class, Window)
	end

	function WindowConfig:SetPosition(Position)
		Window.Position = Position
		return self
	end
	function WindowConfig:SetSize(Size)
		local HeaderSizeY = self:GetHeaderSizeY()

		if typeof(Size) == "Vector2" then
			Size = UDim2.new(0, Size.X, 0, Size.Y)
		end

		--// Apply new size
		local NewSize = UDim2.new(
			Size.X.Scale,
			Size.X.Offset,
			Size.Y.Scale,
			Size.Y.Offset + HeaderSizeY
		)
		self.Size = NewSize
		Window.Size = NewSize
		return self
	end

	--// Tab change system 
	function WindowConfig:ShowTab(TabClass: SharedTable)
		local TargetPage: Frame = TabClass.Content

		--// Page animation
		if not TargetPage.Visible and not TabClass.NoAnimation then
			TargetPage.Position = UDim2.fromOffset(0, 5)
		end

		--// Hide other tabs
		for _, Page in next, Body:GetChildren() do
			Page.Visible = Page == TargetPage
		end

		--// Page animation
		ImGui:Tween(TargetPage, {
			Position = UDim2.fromOffset(0, 0)
		})
		return self
	end

	function WindowConfig:Center() --// Without an Anchor point
		local Size = Window.AbsoluteSize
		local Position = UDim2.new(0.5,-Size.X/2,0.5,-Size.Y/2)
		self:SetPosition(Position)
		return self
	end

	--// Load Style Configs
	WindowConfig:SetTitle(WindowConfig.Title or "Depso UI")
	WindowConfig:SetOpen(WindowConfig.Open or true)

	ImGui.Windows[Window] = WindowConfig
	ImGui:CheckStyles(Window, WindowConfig, WindowConfig.Colors)

	--// Window section events
	if not WindowConfig.NoSelectEffect then
		ImGui:ApplyWindowSelectEffect(Window, TitleBar)
	end

	return ImGui:MergeMetatables(WindowConfig, Window)
end

return ImGui
