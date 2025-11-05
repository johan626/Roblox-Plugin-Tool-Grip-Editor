return {
	ClassName = "Frame",

	Properties = {
		Name = "AnimationPreview",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -70),
		Size = UDim2.new(1, -50, 0, 40),
		BackgroundTransparency = 1,

		Visible = false,
		ZIndex = 10,
	},

	Children = {
		{
			ClassName = "TextBox",
			Properties = {
				Name = "AnimIdInput",
				Text = "rbxassetid://",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.new(1, -90, 1, 0),

				Font = Enum.Font.SourceSans,
				TextSize = 18,
				TextColor3 = Color3.new(1, 1, 1),
			},
		},
		{
			ClassName = "TextButton",
			Properties = {
				Name = "PlayButton",
				Text = "Play",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.new(0, 80, 1, 0),

				Font = Enum.Font.SourceSansSemibold,
				Style = Enum.ButtonStyle.RobloxRoundDefaultButton,

				TextSize = 20,
				TextColor3 = Color3.new(1, 1, 1),
			},
		},
		{
			Name = "SizeCap",
			ClassName = "UISizeConstraint",

			Properties = {
				MaxSize = Vector2.new(300, 40)
			}
		},
	}
}
