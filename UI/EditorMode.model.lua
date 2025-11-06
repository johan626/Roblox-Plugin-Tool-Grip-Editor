--!nonstrict
return {
	ClassName = "Frame",
	Properties = {
		Name = "EditorModeFrame",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(60, 60, 60),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		ZIndex = 2,
	},
	Children = {
		{
			ClassName = "UIListLayout",
			Properties = {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 5),
			},
		},
		{
			ClassName = "TextButton",
			Properties = {
				Name = "CharacterModeButton",
				Text = "Character Mode",
				LayoutOrder = 1,
				Size = UDim2.new(0, 120, 1, 0),
				Style = Enum.ButtonStyle.RobloxRoundDefaultButton, -- Default active
			},
		},
		{
			ClassName = "TextButton",
			Properties = {
				Name = "ViewmodelModeButton",
				Text = "Viewmodel Mode",
				LayoutOrder = 2,
				Size = UDim2.new(0, 120, 1, 0),
				Style = Enum.ButtonStyle.RobloxRoundButton, -- Default inactive
			},
		},
	}
}