-- 4thAxis
-- 6/20/22


local Module = {}
Module.Connections = {}

--------------------------------------------------------------------
---------------------------  Imports   -----------------------------
--------------------------------------------------------------------

local CameraModes = require(script:WaitForChild("CameraModes"))

--------------------------------------------------------------------
--------------------------  Services  ------------------------------
--------------------------------------------------------------------

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local Players = game:GetService("Players")

--------------------------------------------------------------------
--------------------------  Privates  ------------------------------
--------------------------------------------------------------------

local function LockCenter(Input)
	if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end
end


local function MouseMovementTrack(_, Input, Object)
	if Input == Enum.UserInputState.Change then
		CameraModes.OverTheShoulder(nil, CameraModes.CameraAngleX-Object.Delta.X, math.clamp(CameraModes.CameraAngleY-Object.Delta.Y*0.4, -75, 75))
	end
end


--------------------------------------------------------------------
-------------------------  Functions  ------------------------------
--------------------------------------------------------------------

---------------------------
----    Shift Lock     ----
---------------------------

function Module.EnableShiftLockCamera()
	Module.Connections.LockCenter = UserInputService.InputBegan:Connect(LockCenter)
	Module.Connections.MouseMovementTrack = CAS:BindAction("PlayerInput2", MouseMovementTrack, false, Enum.UserInputType.MouseMovement, Enum.UserInputType.Touch)
	--UserInputService.InputChanged:Connect(MouseMovementTrack)	
	RunService:BindToRenderStep("ShiftLock", Enum.RenderPriority.Camera.Value, CameraModes.OverTheShoulder)
end

function Module.DisableShiftLockCamera()
	if not Module.Connections.LockCenter and not Module.Connections.MouseMovementTrack then return end

	Module.Connections.LockCenter:Disconnect()
	Module.Connections.MouseMovementTrack:Disconnect()
	RunService:UnBindToRenderStep("ShiftLock")
end

---------------------------
---- Isometric Camera  ----
---------------------------

function Module.EnableIsometricCamera()
	RunService:BindToRenderStep("IsometricCamera", Enum.RenderPriority.Camera.Value, CameraModes.IsometricCamera)

end

function Module.DisableIsometricCamera()
	RunService:UnBindToRenderStep("IsometricCamera")
end

---------------------------
----  Top Down Camera  ----
---------------------------

function Module.EnableTopDownCamera()
	RunService:BindToRenderStep("TopDown", Enum.RenderPriority.Camera.Value, CameraModes.TopDownCamera)

end 

function Module.DisableTopDownCamera()
	RunService:UnBindToRenderStep("TopDown")

end

---------------------------
---- SideScrollCamera  ----
---------------------------

function Module.EnableSideScrollingCamera()
	RunService:BindToRenderStep("SideScroll", Enum.RenderPriority.Camera.Value, CameraModes.SideScrollingCamera)
end

function Module.DisableSideScrollingCamera()
	RunService:UnbindFromRenderStep("SideScroll")

end

---------------------------
----   Follow Mouse    ----
---------------------------

function Module.FollowMouse()
	Module.DisableShiftLockCamera()
	RunService:BindToRenderStep("FollowMouse", Enum.RenderPriority.Camera.Value, CameraModes.FollowMouse)
end

function Module.StopFollowingMouse()
	RunService:UnBindToRenderStep("FollowMouse")
end

---------------------------
----    Face Mouse     ----
---------------------------

function Module.FaceCharacterToMouse()
	RunService:BindToRenderStep("FaceCharacterToMouse", Enum.RenderPriority.Character.Value, CameraModes.FaceCharacterToMouse)
end

function Module.StopFacingMouse()
	RunService:UnbindFromRenderStep("FaceCharacterToMouse")
end

---------------------------
---- Head Follow Mouse ----
---   (Experimental)   ----
---------------------------

function Module.HeadFollowCamera()
	RunService:BindToRenderStep("HeadFollowCamera", Enum.RenderPriority.Character.Value, CameraModes.HeadFollowCamera)
end

function Module.StopHeadFollowCamera()
	RunService:UnbindFromRenderStep("HeadFollowCamera")
end



return Module
