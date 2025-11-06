local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local Players = game:GetService("Players")

local Modules = script.Parent
local UI = require(Modules.UI)
local Project = Modules.Parent

local ToolEditor = {}
ToolEditor.__index = ToolEditor

function ToolEditor:_createNewDummy(rigType)
	if self.Dummy then
		self.Dummy:Destroy()
	end

	local hDesc
	if rigType == "R15" and self.ActiveHumanoidDescription then
		hDesc = self.ActiveHumanoidDescription
	else -- For R6, or initial R15 creation, use a plain description
		hDesc = Instance.new("HumanoidDescription")
		local gray = BrickColor.new(-1).Color
		for _,limb in pairs(Enum.BodyPart:GetEnumItems()) do
			hDesc[limb.Name .. "Color"] = gray
		end
	end

	local dummy = Players:CreateHumanoidModelFromDescription(hDesc, rigType)
	local humanoid = dummy:WaitForChild("Humanoid")

	-- Avoid unintended script injection.
	if dummy:FindFirstChild("Animate") then
		dummy.Animate:Destroy()
	end

	local animator = Instance.new("Animator")
	animator.Parent = humanoid

	local worldModel = self.WorldModel
	if not worldModel then
		worldModel = Instance.new("WorldModel")
		self.WorldModel = worldModel
	end
	dummy.Parent = worldModel

	local rootPart = humanoid.RootPart
	rootPart.Anchored = true

	self.Dummy = dummy
	self.Humanoid = humanoid
	self.RootPart = rootPart
	self.Animator = animator

	self:StartAnimations(dummy)
end

function ToolEditor:_generateViewmodelFromDummy()
	if self.ViewmodelDummy then
		self.ViewmodelDummy:Destroy()
	end

	local viewmodelDummy = self.Dummy:Clone()
	viewmodelDummy.Name = "ViewmodelDummy"

	local humanoid = viewmodelDummy:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end

	local partsToKeep = {
		-- R15
		["RightUpperArm"] = true, ["RightLowerArm"] = true, ["RightHand"] = true,
		["LeftUpperArm"] = true, ["LeftLowerArm"] = true, ["LeftHand"] = true,
		-- R6
		["Right Arm"] = true, ["Left Arm"] = true,
	}

	for _, part in pairs(viewmodelDummy:GetChildren()) do
		if part:IsA("BasePart") and not partsToKeep[part.Name] then
			part:Destroy()
		end
	end

	-- Also remove any accessories
	for _, accoutrement in pairs(viewmodelDummy:GetChildren()) do
		if accoutrement:IsA("Accessory") then
			accoutrement:Destroy()
		end
	end

	local primaryPart = viewmodelDummy:FindFirstChild("RightHand") or viewmodelDummy:FindFirstChild("Right Arm")
	if primaryPart then
		viewmodelDummy.PrimaryPart = primaryPart
	end

	self.ViewmodelDummy = viewmodelDummy
	self:StartAnimations(viewmodelDummy)
	return viewmodelDummy
end

function ToolEditor.new()
	local editor = 
		{
			RigType = "R15",
			ActiveHumanoidDescription = nil,
			ZoomMultiplier = 1,

			IsLiveSyncActive = false,
			SyncedTool = nil,
			PlayerAddedConnection = nil,

			EditorMode = "Character", -- "Character" or "Viewmodel"

			ProxyAttachment = nil,
			CustomAnimationTracks = {},
		}

	setmetatable(editor, ToolEditor)
	editor:_createNewDummy("R15")
	return editor
end

function ToolEditor:SetEditorMode(newMode)
	if self.EditorMode == newMode then
		return
	end

	self.EditorMode = newMode
	warn("Editor mode switched to:", newMode)

	if newMode == "Viewmodel" then
		if not self.ViewmodelDummy then
			self:_generateViewmodelFromDummy()
		end
		self.Dummy.Parent = nil
		self.ViewmodelDummy.Parent = self.WorldModel
		self.RootPart = self.ViewmodelDummy.PrimaryPart or self.ViewmodelDummy:FindFirstChild("HumanoidRootPart")
	else -- Character mode
		self.Dummy.Parent = self.WorldModel
		if self.ViewmodelDummy then
			self.ViewmodelDummy.Parent = nil
		end
		self.RootPart = self.Dummy:FindFirstChild("HumanoidRootPart")
	end

	local currentTool = self.Tool
	self:ClearTool()

	if currentTool then
		if newMode == "Viewmodel" then
			self:BindViewmodelTool(currentTool)
		else
			self:BindTool(currentTool)
		end
	end
end

function ToolEditor:SetParent(parent)
	local worldModel = self.WorldModel
	worldModel.Parent = parent
end

function ToolEditor:FindObject(className, name)
	local dummy = self.Dummy
	local child = dummy:FindFirstChild(name, true)

	if child and child:IsA(className) then
		return child
	end
end

function ToolEditor:FindLimb(limbName)
	return self:FindObject("BasePart", limbName)
end

function ToolEditor:FindJoint(jointName)
	return self:FindObject("JointInstance", jointName)
end

function ToolEditor:FindAttachment(attName)
	return self:FindObject("Attachment", attName)
end

function ToolEditor:GetCameraZoom()
	local handle = self.Handle
	local baseZoom

	if handle then
		local size = handle.Size
		baseZoom = math.max(4, size.Magnitude * 1.5)
	else
		local cf, size = self.Dummy:GetBoundingBox()
		baseZoom = size.Magnitude
	end

	return baseZoom * self.ZoomMultiplier
end

function ToolEditor:AdjustZoom(scrollDelta)
	local currentMultiplier = self.ZoomMultiplier
	local newMultiplier = currentMultiplier - (scrollDelta * 0.1)
	self.ZoomMultiplier = math.clamp(newMultiplier, 0.5, 2)
end

function ToolEditor:StepAnimator(delta)
	local animator = self.Animator
	animator:StepAnimations(delta)
end

function ToolEditor:ApplyDescription(hDesc)
	self.ActiveHumanoidDescription = hDesc
	-- Only R15 rigs can have descriptions applied in this way.
	if self.RigType == "R15" then
		local humanoid = self.Humanoid
		humanoid:ApplyDescription(hDesc)
	end

	-- Regenerate the viewmodel dummy if it exists to keep it in sync
	if self.ViewmodelDummy then
		self:_generateViewmodelFromDummy()
	end
end

function ToolEditor:SwitchRigType()
	local currentTool = self.Tool
	self:ClearTool()

	local newRigType = (self.RigType == "R15") and "R6" or "R15"
	self.RigType = newRigType

	self:_createNewDummy(newRigType)

	if self.ViewmodelDummy then
		self:_generateViewmodelFromDummy()
	end

	if currentTool then
		-- Re-bind based on current mode
		if self.EditorMode == "Character" then
			self:BindTool(currentTool)
		else
			self:BindViewmodelTool(currentTool)
		end
	end

	return newRigType
end

function ToolEditor:StartAnimations(targetDummy)
	targetDummy = targetDummy or self.Dummy
	if not targetDummy then return end

	local humanoid = targetDummy:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	local anims = Project:WaitForChild("Animations")[self.RigType]

	for _,track in pairs(animator:GetPlayingAnimationTracks()) do
		track:Stop()
	end

	self.CustomAnimationTrack = nil

	for _,animDef in pairs(anims:GetChildren()) do
		local anim = UI.create(require(animDef))
		local track = animator:LoadAnimation(anim)
		track:Play()
	end
end

function ToolEditor:PlayAnimation(animationId)
	self:StopCustomAnimation()

	local animator
	if self.EditorMode == "Viewmodel" and self.ViewmodelDummy then
		animator = self.ViewmodelDummy:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")
	else
		animator = self.Animator
	end

	if not animator then
		return false, "Animator not found for current mode."
	end

	local success, animation = pcall(function()
		local anim = Instance.new("Animation")
		anim.AnimationId = animationId
		return anim
	end)

	if not success then
		return false, "Invalid AnimationId format"
	end

	local loaded, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	animation:Destroy()

	if not loaded then
		return false, "Failed to load animation. Check permissions and ID."
	end

	if not self.CustomAnimationTracks then self.CustomAnimationTracks = {} end
	self.CustomAnimationTracks[animator] = track

	track.Looped = true
	track:Play()

	return true
end

function ToolEditor:StopCustomAnimation()
	if not self.CustomAnimationTracks then return end

	for animator, track in pairs(self.CustomAnimationTracks) do
		if track then
			track:Stop()
			track:Destroy()
		end
	end
	self.CustomAnimationTracks = {}

	-- Restart the default animations on both dummies
	self:StartAnimations(self.Dummy)
	self:StartAnimations(self.ViewmodelDummy)
end

function ToolEditor:Connect(name, event)
	return event:Connect(function (...)
		self[name](self, ...)
	end)
end

function ToolEditor:BindProperty(object, property, funcName)
	local event = object:GetPropertyChangedSignal(property)
	return self:Connect(funcName, event)
end

function ToolEditor:RefreshGrip()
	local rightGrip = self.RightGrip
	local handle = self.Handle
	local tool = self.Tool

	if rightGrip and handle then
		local grip = tool.Grip
		rightGrip.C1 = grip
	end
end

function ToolEditor:ReflectGrip()
	local tool = self.Tool
	local gripEditor = self.GripEditor

	if tool and gripEditor then
		local newCFrame = gripEditor.CFrame
		tool.Grip = newCFrame

		-- Live Sync Communication
		if self.IsLiveSyncActive and self.SyncedTool == tool then
			pcall(function()
				local folderName = "ToolGripEditor_Sync_" .. tool:GetFullName()
				local syncFolder = game:GetService("CoreGui"):FindFirstChild(folderName)
				if syncFolder then
					syncFolder.GripCFrame.Value = newCFrame
				end
			end)
		end
	end
end

function ToolEditor:ReflectViewmodelGrip()
	if self.ProxyAttachment and self.ViewModelWeld then
		self.ViewModelWeld.C1 = self.ProxyAttachment.CFrame
	end
end

function ToolEditor:InjectClientScript(player, tool)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	local playerScripts = player:FindFirstChild("PlayerScripts")
	if not playerScripts then
		return
	end

	local SCRIPT_NAME = "ToolGripEditor_LiveSync"
	if playerScripts:FindFirstChild(SCRIPT_NAME) then
		return -- Already injected
	end

	local folderName = "ToolGripEditor_Sync_" .. tool:GetFullName()
	local syncFolder = Instance.new("Folder")
	syncFolder.Name = folderName
	syncFolder.Parent = game:GetService("CoreGui")

	local cframeValue = Instance.new("CFrameValue")
	cframeValue.Name = "GripCFrame"
	cframeValue.Value = tool.Grip
	cframeValue.Parent = syncFolder

	-- The client script will be added in the next step.
	-- For now, this is a placeholder.
	local clientScript = Instance.new("LocalScript")
	clientScript.Name = SCRIPT_NAME

	local clientScriptSource = [[
		local Players = game:GetService("Players")
		local CoreGui = game:GetService("CoreGui")

		local localPlayer = Players.LocalPlayer

		local SYNC_FOLDER_NAME = %q
		local TOOL_NAME = %q

		local syncFolder = CoreGui:WaitForChild(SYNC_FOLDER_NAME)
		if not syncFolder then return end

		local gripCFrameValue = syncFolder:WaitForChild("GripCFrame")
		if not gripCFrameValue then return end

		local function findToolInCharacter(character)
			if not character then return nil end
			return character:FindFirstChild(TOOL_NAME)
		end

		local function onGripChanged(newGrip)
			local character = localPlayer.Character
			if not character then return end

			local tool = findToolInCharacter(character)
			if tool and tool:IsA("Tool") then
				tool.Grip = newGrip
			end
		end

		local function onCharacterAdded(character)
			-- Wait for the tool to be equipped/added
			character.ChildAdded:Connect(function(child)
				if child:IsA("Tool") and child.Name == TOOL_NAME then
					-- Set the initial grip value immediately
					child.Grip = gripCFrameValue.Value
				end
			end)

			-- Check if tool is already there
			local tool = findToolInCharacter(character)
			if tool and tool:IsA("Tool") then
				 tool.Grip = gripCFrameValue.Value
			end
		end

		-- Initial setup
		if localPlayer.Character then
			onCharacterAdded(localPlayer.Character)
		end

		-- Connect events
		gripCFrameValue.Changed:Connect(onGripChanged)
		localPlayer.CharacterAdded:Connect(onCharacterAdded)
	]]

	clientScript.Source = string.format(clientScriptSource, folderName, tool.Name)
	clientScript.Parent = playerScripts
end

function ToolEditor:CleanupClientScript(player, tool)
	if player then
		local playerScripts = player:FindFirstChild("PlayerScripts")
		if playerScripts then
			local SCRIPT_NAME = "ToolGripEditor_LiveSync"
			local script = playerScripts:FindFirstChild(SCRIPT_NAME)
			if script then
				script:Destroy()
			end
		end
	end

	if tool then
		local folderName = "ToolGripEditor_Sync_" .. tool:GetFullName()
		local syncFolder = game:GetService("CoreGui"):FindFirstChild(folderName)
		if syncFolder then
			syncFolder:Destroy()
		end
	end
end

function ToolEditor:ToggleLiveSync()
	if not self.Tool then
		warn("Cannot toggle Live Sync without a tool selected.")
		return false
	end

	self.IsLiveSyncActive = not self.IsLiveSyncActive

	if self.IsLiveSyncActive then
		self.SyncedTool = self.Tool

		-- Inject for existing players
		for _, player in pairs(Players:GetPlayers()) do
			self:InjectClientScript(player, self.SyncedTool)
		end

		-- Listen for new players
		self.PlayerAddedConnection = Players.PlayerAdded:Connect(function(player)
			self:InjectClientScript(player, self.SyncedTool)
		end)

	else
		-- Cleanup for all players
		for _, player in pairs(Players:GetPlayers()) do
			self:CleanupClientScript(player, self.SyncedTool)
		end

		-- Stop listening for new players
		if self.PlayerAddedConnection then
			self.PlayerAddedConnection:Disconnect()
			self.PlayerAddedConnection = nil
		end

		self:CleanupClientScript(nil, self.SyncedTool) -- Cleanup CoreGui folder
		self.SyncedTool = nil
	end

	return self.IsLiveSyncActive
end


function ToolEditor:ClearTool()
	if self.IsLiveSyncActive then
		self:ToggleLiveSync() -- Turn it off
	end

	if self.GripRefresh then
		self.GripRefresh:Disconnect()
		self.GripRefresh = nil
	end

	if self.GripReflect then
		self.GripReflect:Disconnect()
		self.GripReflect = nil
	end

	if self.Handle then
		self.Handle:Destroy()
		self.Handle = nil
	end

	if self.GripEditor then
		self.GripEditor:Destroy()
		self.GripEditor = nil
	end

	self:StopCustomAnimation()

	if self.RightGrip then
		self.RightGrip.Part1 = nil
	end

	if self.ViewModelWeld then
		self.ViewModelWeld:Destroy()
		self.ViewModelWeld = nil
	end

	self.Tool = nil
	self.ZoomMultiplier = 1
end

function ToolEditor:CreateGhostArm()
	local dummy = self.Dummy:Clone()
	local humanoid = dummy.Humanoid

	for _,child in pairs(dummy:GetChildren()) do
		if child:IsA("BasePart") then
			local limb = humanoid:GetLimb(child)

			if limb.Name == "RightArm" then
				child:ClearAllChildren()
				child.Anchored = true
				child.Locked = true

				if child.Name == "RightHand" then
					dummy.PrimaryPart = child
				end
			else
				child:Destroy()
			end
		elseif child:IsA("Accoutrement") then
			child:Destroy()
		end
	end

	dummy.Archivable = false
	dummy.Name = "PreviewArm"

	return dummy
end

function ToolEditor:BindTool(tool)
	if tool == nil then
		self:ClearTool()
		return false
	end

	if self.Tool == tool then
		return true
	elseif self.Tool ~= nil then
		self:ClearTool()
	end

	local dummy = self.Dummy
	local handle = tool:FindFirstChild("Handle")

	if not (handle and handle:IsA("BasePart")) then
		return
	end

	local part0Name = (self.RigType == "R15") and "RightHand" or "Right Arm"
	local rightHand = self:FindLimb(part0Name)
	local rightGrip = self.RightGrip

	if not (rightGrip and rightGrip:IsDescendantOf(dummy)) then
		local gripAtt = self:FindAttachment("RightGripAttachment")

		rightGrip = Instance.new("Motor6D")
		rightGrip.C0 = gripAtt.CFrame
		rightGrip.Name = "RightGrip"
		rightGrip.Part0 = rightHand
		rightGrip.Parent = rightHand

		self.RightGrip = rightGrip
	end

	local newHandle = handle:Clone()
	newHandle.Parent = self.Dummy

	for _,joint in pairs(newHandle:GetJoints()) do
		joint:Destroy()
	end

	for _,child in pairs(newHandle:GetChildren()) do
		if child:IsA("Sound") then
			child.PlayOnRemove = false
		end
	end

	newHandle.Locked = true
	newHandle.Anchored = false
	rightGrip.Part1 = newHandle

	local gripEditor = Instance.new("Attachment")
	gripEditor.Archivable = false
	gripEditor.CFrame = tool.Grip
	gripEditor.Name = "Grip"

	for _,part in pairs(tool:GetDescendants()) do
		if not part:IsA("BasePart") then
			continue
		end

		if part == handle then
			continue
		end

		if not part:IsDescendantOf(tool) then
			continue
		end

		local copy = part:Clone()
		copy.Anchored = false
		copy.Locked = true
		copy.Parent = newHandle

		for _,joint in pairs(copy:GetJoints()) do
			joint:Destroy()
		end

		local weld = Instance.new("Weld")
		weld.C0 = handle.CFrame:ToObjectSpace(part.CFrame)
		weld.Part0 = newHandle
		weld.Part1 = copy
		weld.Parent = copy
	end

	self.GripRefresh = self:BindProperty(tool, "Grip", "RefreshGrip")
	self.GripReflect = self:BindProperty(gripEditor, "CFrame", "ReflectGrip")

	self.GripEditor = gripEditor
	self.DirectHandle = handle

	self.Handle = newHandle
	self.Tool = tool

	self:RefreshGrip()

	return (self.Handle ~= nil)
end

function ToolEditor:BindViewmodelTool(tool)
	if tool == nil then
		self:ClearTool()
		return false
	end

	if self.Tool == tool then
		return true
	elseif self.Tool ~= nil then
		self:ClearTool()
	end

	local handle = tool:FindFirstChild("Handle")
	if not (handle and handle:IsA("BasePart")) then
		return
	end

	local part0Name = (self.RigType == "R15") and "RightHand" or "Right Arm"
	local rightHand = self.ViewmodelDummy:FindFirstChild(part0Name, true)

	if not rightHand then
		warn("Could not find right hand for viewmodel!")
		return false
	end

	local newHandle = handle:Clone()
	newHandle.Parent = self.ViewmodelDummy

	for _,descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= handle then
			local partClone = descendant:Clone()
			partClone.Parent = newHandle

			local weld = Instance.new("Weld")
			weld.Part0 = newHandle
			weld.Part1 = partClone
			weld.C0 = handle.CFrame:ToObjectSpace(descendant.CFrame)
			weld.Parent = partClone
		end
	end

	local viewModelWeld = Instance.new("Motor6D")
	viewModelWeld.Name = "ViewModelWeld"
	viewModelWeld.Part0 = rightHand
	viewModelWeld.Part1 = newHandle

	local gripAtt = rightHand:FindFirstChild("RightGripAttachment")
	if gripAtt then
		viewModelWeld.C0 = gripAtt.CFrame
	end

	viewModelWeld.Parent = rightHand

	self.Handle = newHandle
	self.ViewModelWeld = viewModelWeld
	self.Tool = tool
	self.DirectHandle = handle

	return true
end

function ToolEditor:EditGrip(plugin)
	if self.EditorMode == "Viewmodel" then
		self:_editViewmodelGrip(plugin)
		return
	end

	local tool = self.Tool
	local handle = self.Handle

	local gripEditor = self.GripEditor
	local directHandle = self.DirectHandle

	if tool and handle and gripEditor then
		local editor = Instance.new("Model")
		editor.Name = "Tool Grip Editor"
		editor.Archivable = false
		editor.Parent = workspace

		local proxyHandle = handle:Clone()
		proxyHandle.Locked = true
		proxyHandle.Anchored = true
		proxyHandle.Parent = editor

		for _,desc in pairs(proxyHandle:GetDescendants()) do
			if desc:IsA("BasePart") then
				if tool:IsDescendantOf(workspace) then
					desc:Destroy()
				else 
					desc.Locked = true
					desc.Anchored = true
					desc.Parent = editor
				end
			end
		end

		gripEditor.Parent = proxyHandle
		editor.PrimaryPart = proxyHandle
		editor:SetPrimaryPartCFrame(directHandle.CFrame)

		local camera = workspace.CurrentCamera
		self.InUse = true

		if camera then
			local cf = camera.CFrame
			local focus = gripEditor.WorldPosition

			local lookVector = cf.LookVector
			local extents = handle.Size.Magnitude

			camera.CFrame = CFrame.new(focus - (lookVector * extents * 1.5), focus)
			camera.Focus = CFrame.new(focus)
		end

		if tool:IsDescendantOf(workspace) then
			proxyHandle.Transparency = 1

			for _,child in pairs(proxyHandle:GetChildren()) do
				if child ~= gripEditor then
					if child:IsA("Sound") then
						child.PlayOnRemove = false
					end

					child:Destroy()
				end
			end
		end

		local ghostArm = self:CreateGhostArm()
		ghostArm.Parent = editor

		self.GhostArm = ghostArm
		Selection:Set{gripEditor}

		if plugin:GetSelectedRibbonTool() ~= Enum.RibbonTool.Move then
			plugin:SelectRibbonTool("Move", UDim2.new())
		end

		ChangeHistoryService:SetWaypoint("Begin Grip Edit")
		Selection.SelectionChanged:Wait()

		gripEditor.Parent = nil
		ghostArm.Parent = nil

		self.GhostArm = nil
		self.InUse = false

		ChangeHistoryService:SetWaypoint("End Grip Edit")
		editor:Destroy()
	end
end

function ToolEditor:_editViewmodelGrip(plugin)
	local tool = self.Tool
	local handle = self.Handle
	local viewModelWeld = self.ViewModelWeld

	if not (tool and handle and viewModelWeld) then
		return
	end

	local editorModel = Instance.new("Model")
	editorModel.Name = "Viewmodel Grip Editor"
	editorModel.Archivable = false

	local ghostViewmodel = self.ViewmodelDummy:Clone()
	ghostViewmodel.Name = "GhostViewmodel"
	for _, part in ipairs(ghostViewmodel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	ghostViewmodel.Parent = editorModel

	editorModel.Parent = workspace

	local handleProxy = handle:Clone()
	handleProxy.Anchored = true
	handleProxy.Parent = editorModel

	local gripAttachmentProxy = Instance.new("Attachment")
	gripAttachmentProxy.Name = "GripAttachment"
	gripAttachmentProxy.CFrame = viewModelWeld.C1
	gripAttachmentProxy.Parent = handleProxy

	editorModel.PrimaryPart = handleProxy
	editorModel:SetPrimaryPartCFrame(self.DirectHandle.CFrame)

	if tool:IsDescendantOf(workspace) then
		handleProxy.Transparency = 0.75
	end

	Selection:Set{gripAttachmentProxy}
	self.InUse = true
	self.ProxyAttachment = gripAttachmentProxy

	local cframeChanged = self:Connect("ReflectViewmodelGrip", gripAttachmentProxy:GetPropertyChangedSignal("CFrame"))

	if plugin:GetSelectedRibbonTool() ~= Enum.RibbonTool.Move then
		plugin:SelectRibbonTool("Move", UDim2.new())
	end

	ChangeHistoryService:SetWaypoint("Begin Viewmodel Grip Edit")

	-- Wait for deselection
	Selection.SelectionChanged:Wait()

	gripAttachmentProxy.Parent = nil
	ghostViewmodel.Parent = nil
	cframeChanged:Disconnect()

	self.ProxyAttachment = nil
	self.InUse = false

	ChangeHistoryService:SetWaypoint("End Viewmodel Grip Edit")
	editorModel:Destroy()
end

-----------------------------------------------------------
-- TODO: If this module is ever constructed multiple times
--       then return the ToolEditor table itself. At the
--       present moment, it acts more like a singleton.
-----------------------------------------------------------

return ToolEditor.new()
