--[[ --------------------------------------------------------------------

-- 4thAxis
-- 6/20/22

	MIT License

	Copyright (c) 2022 4thAxis

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
]] --------------------------------------------------------------------


local Module = {}

--------------------------------------------------------------------
---------------------------  Imports   -----------------------------
--------------------------------------------------------------------

local Configs = require(script.Parent:WaitForChild("Configurations"))

--------------------------------------------------------------------
--------------------------  Services  ------------------------------
--------------------------------------------------------------------

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

--------------------------------------------------------------------
-------------------------  Constants  ------------------------------
--------------------------------------------------------------------

Module.Epsilon = 1e-5
Module.CameraAngleX = 0
Module.CameraAngleY = 0

local DownVector = Vector3.new(0,-1,0)
local Rad2 = math.rad(2)
local Cos270 = math.cos(270)
local Sin270 = math.sin(270)

--------------------------------------------------------------------

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()

local Camera = workspace.CurrentCamera
local ScreenSize = Camera.ViewportSize	
local ScreenSizeX, ScreenSizeY = ScreenSize.X, ScreenSize.Y
local PixelCoordinateRatioX, PixelCoordinateRatioY = 1/ScreenSizeX, 1/ScreenSizeY

local Character = Player.Character or Player.CharacterAdded:Wait()
local Head = Character:WaitForChild("Head")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Torso = Character:WaitForChild("UpperTorso")
local Root = Character:WaitForChild("HumanoidRootPart")
local Neck = Head:WaitForChild("Neck")
local Waist = Torso:WaitForChild("Waist")
local NeckOriginC0 = Neck.C0
local WaistOriginC0 = Waist.C0

Neck.MaxVelocity = 1/3

--------------------------------------------------------------------
--------------------------  Privates  ------------------------------
--------------------------------------------------------------------

local function DisableRobloxCamera()
	if Camera.CameraType ~= Enum.CameraType.Scriptable then 
		Camera.CameraType = Enum.CameraType.Scriptable
	end
end

--------------------------------------------------------------------
-------------------------  Functions  ------------------------------
--------------------------------------------------------------------

Module.OverTheShoulder = function(_, CameraAngleX, CameraAngleY, Lerp)
	Module.CameraAngleX = CameraAngleX or Module.CameraAngleX
	Module.CameraAngleY = CameraAngleY or Module.CameraAngleY
	DisableRobloxCamera()
	
	local RadX, RadY = math.rad(Module.CameraAngleX), math.rad(Module.CameraAngleY)
	local Cosy, Siny = math.cos(RadX),  math.sin(RadX)
	local Cosx, Sinx = math.cos(RadY), math.sin(RadY)
	local Origin = CFrame.new((HumanoidRootPart.CFrame.Position)) * CFrame.new(
		0, 0, 0, 
		Cosy, Siny*Sinx, Siny*Cosx, 
		0, Cosx, -Sinx,
		-Siny, Cosy*Sinx, Cosy*Cosx
	)
	
	local XOffset, YOffset,  ZOffset= Configs.CamLockOffset.X, Configs.CamLockOffset.Y, Configs.CamLockOffset.Z
	local X, Y, Z, M11, M12, M13, M21, M22, M23, M31, M32, M33 = Origin:GetComponents()	
	
	local Eye = Vector3.new (M11*XOffset+M12*YOffset+M13*ZOffset+X,M21*XOffset+M22*YOffset+M23*ZOffset+Y,M31*XOffset+M32*YOffset+M33*ZOffset+Z)
	local XAxis = Vector3.new (M11*XOffset+M12*YOffset+M13*-10000+X,M21*XOffset+M22*YOffset+M23*-10000+Y,M31*XOffset+M32*YOffset+M33*-10000+Z)-Eye

	if (XAxis:Dot(XAxis) <= Module.Epsilon) then 
		Camera.CFrame = CFrame.new(Eye.X, Eye.Y, Eye.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1) 
	end
	XAxis = XAxis.Unit
	local Xx, Xy, Xz = XAxis.X, XAxis.Y, XAxis.Z
	local RNorm = (((Xz*Xz)+(Xx*Xx))) -- R:Dot(R), our right vector
	if RNorm <= Module.Epsilon and math.abs(XAxis.Y) > 0 then
		Camera.CFrame = CFrame.fromMatrix(Eye, -math.sign(XAxis.Y)*Vector3.zAxis, Vector3.xAxis)
	end
	RNorm = 1/(RNorm^0.5) -- take the root of our squared norm and inverse division
	local Rx, Rz = -(Xz*RNorm), (Xx*RNorm) -- cross y-axis with right and normalize
	local Ux, Uy, Uz = -Rz*(Rz*Xx-Rx*Xz), -(Rz*Rz)*Xy-(Rx*Rx)*Xy, Rx*(Rz*Xx-Rx*Xz) -- cross right and up and normalize.
	local UNorm = 1/((Ux*Ux)+(Uy*Uy)+(Uz*Uz))^0.5 -- inverse division and multiply this ratio rather than dividing each component
	Camera.CFrame = CFrame.new(
		Eye.X,Eye.Y,Eye.Z,
		Rx, -Xy*Rz, Ux*UNorm, 
		0, (Rz*Xx)-Rx*Xz, Uy*UNorm,
		Rz, Xy*Rx, Uz*UNorm
	)
end


Module.IsometricCamera = function(_, CameraDepth, HeightOffset, FOV)
	CameraDepth = CameraDepth or Configs.IsometricCameraDepth
	HeightOffset = HeightOffset or Configs.IsometricHeightOffset
	Camera.FieldOfView = FOV or Configs.IsometricFieldOfView
	DisableRobloxCamera()

	local Root = HumanoidRootPart.Position + Vector3.new(0, HeightOffset, 0)
	local Eye = Root + Vector3.new(CameraDepth, CameraDepth, CameraDepth)	
	
	local XAxis = Root-Eye
	if (XAxis:Dot(XAxis) <= Module.Epsilon) then 
		Camera.CFrame = CFrame.new(Eye.X, Eye.Y, Eye.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1) 
	end
	XAxis = XAxis.Unit
	local Xx, Xy, Xz = XAxis.X, XAxis.Y, XAxis.Z
	local RNorm = (((Xz*Xz)+(Xx*Xx))) -- R:Dot(R), our right vector
	if RNorm <= Module.Epsilon and math.abs(XAxis.Y) > 0 then
		Camera.CFrame = CFrame.fromMatrix(Eye, -math.sign(XAxis.Y)*Vector3.zAxis, Vector3.xAxis)
	end
	RNorm = 1/(RNorm^0.5) -- take the root of our squared norm and inverse division
	local Rx, Rz = -(Xz*RNorm), (Xx*RNorm) -- cross y-axis with right and normalize
	local Ux, Uy, Uz = -Rz*(Rz*Xx-Rx*Xz), -(Rz*Rz)*Xy-(Rx*Rx)*Xy, Rx*(Rz*Xx-Rx*Xz) -- cross right and up and normalize.
	local UNorm = 1/((Ux*Ux)+(Uy*Uy)+(Uz*Uz))^0.5 -- inverse division and multiply this ratio rather than dividing each component
	Camera.CFrame = CFrame.new(
		Eye.X,Eye.Y,Eye.Z,
		Rx, -Xy*Rz, Ux*UNorm, 
		0, (Rz*Xx)-Rx*Xz, Uy*UNorm,
		Rz, Xy*Rx, Uz*UNorm
	)
end


Module.SideScrollingCamera = function(_, CameraDepth, HeightOffset, FOV)
	CameraDepth = CameraDepth or Configs.SideCameraDepth
	HeightOffset = HeightOffset or Configs.SideHeightOffset
	Camera.FieldOfView = FOV or Configs.SideFieldOfView
	DisableRobloxCamera()

	local Focus = HumanoidRootPart.Position + Vector3.new(0, HeightOffset, 0)
	local Eye = Vector3.new(Focus.X, Focus.Y, CameraDepth)
	local XAxis = Focus-Eye
	if (XAxis:Dot(XAxis) <= Module.Epsilon) then 
		Camera.CFrame = CFrame.new(Eye.X, Eye.Y, Eye.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1) 
	end
	XAxis = XAxis.Unit
	local Xx, Xy, Xz = XAxis.X, XAxis.Y, XAxis.Z
	local RNorm = (((Xz*Xz)+(Xx*Xx))) -- R:Dot(R), our right vector
	if RNorm <= Module.Epsilon and math.abs(XAxis.Y) > 0 then
		Camera.CFrame = CFrame.fromMatrix(Eye, -math.sign(XAxis.Y)*Vector3.zAxis, Vector3.xAxis)
	end
	RNorm = 1/(RNorm^0.5) -- take the root of our squared norm and inverse division
	local Rx, Rz = -(Xz*RNorm), (Xx*RNorm) -- cross y-axis with right and normalize
	local Ux, Uy, Uz = -Rz*(Rz*Xx-Rx*Xz), -(Rz*Rz)*Xy-(Rx*Rx)*Xy, Rx*(Rz*Xx-Rx*Xz) -- cross right and up and normalize.
	local UNorm = 1/((Ux*Ux)+(Uy*Uy)+(Uz*Uz))^0.5 -- inverse division and multiply this ratio rather than dividing each component
	Camera.CFrame = CFrame.new(
		Eye.X,Eye.Y,Eye.Z,
		Rx, -Xy*Rz, Ux*UNorm, 
		0, (Rz*Xx)-Rx*Xz, Uy*UNorm,
		Rz, Xy*Rx, Uz*UNorm
	)
end


Module.TopDownCamera = function(_, FaceMouse, MouseSensitivity, Offset, Direction, Distance)
	FaceMouse = FaceMouse or Configs.TopDownFaceMouse
	MouseSensitivity = MouseSensitivity or Configs.TopDownMouseSensitivity
	Distance = Distance or Configs.TopDownDistance
	Direction = Direction or DownVector
	Offset = Offset or Configs.TopDownOffset
	DisableRobloxCamera()

	if FaceMouse then
		local Forward = (Root.Position - Mouse.Hit.Position).Unit
		local Right = Vector3.new(-Forward.Z, 0, Forward.X) -- Forward:Cross(YAxis)
		Root.CFrame = CFrame.fromMatrix(Root.Position, -Right, Vector3.yAxis)
	end
	
	local Mx, My = UserInputService:GetMouseLocation()
	local Axis = Vector3.new(-((My-ScreenSizeY*0.5)*PixelCoordinateRatioY),0,((Mx-ScreenSizeX*0.5)*PixelCoordinateRatioX))
	local Eye = (Distance + (Root.Position+Offset)) + Axis * MouseSensitivity 
	
	local XAxis = (Eye + Direction)-Eye
	if (XAxis:Dot(XAxis) <= Module.Epsilon) then 
		Camera.CFrame = CFrame.new(Eye.X, Eye.Y, Eye.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1) 
	end
	XAxis = XAxis.Unit
	local Xx, Xy, Xz = XAxis.X, XAxis.Y, XAxis.Z
	local RNorm = (((Xz*Xz)+(Xx*Xx))) -- R:Dot(R), our right vector
	if RNorm <= Module.Epsilon and math.abs(XAxis.Y) > 0 then
		Camera.CFrame = CFrame.fromMatrix(Eye, -math.sign(XAxis.Y)*Vector3.zAxis, Vector3.xAxis)
	end
	RNorm = 1/(RNorm^0.5) -- take the root of our squared norm and inverse division
	local Rx, Rz = -(Xz*RNorm), (Xx*RNorm) -- cross y-axis with right and normalize
	local Ux, Uy, Uz = -Rz*(Rz*Xx-Rx*Xz), -(Rz*Rz)*Xy-(Rx*Rx)*Xy, Rx*(Rz*Xx-Rx*Xz) -- cross right and up and normalize.
	local UNorm = 1/((Ux*Ux)+(Uy*Uy)+(Uz*Uz))^0.5 -- inverse division and multiply this ratio rather than dividing each component
	Camera.CFrame = CFrame.new(
		Eye.X,Eye.Y,Eye.Z,
		Rx, -Xy*Rz, Ux*UNorm, 
		0, (Rz*Xx)-Rx*Xz, Uy*UNorm,
		Rz, Xy*Rx, Uz*UNorm
	)
end


Module.HeadFollowCamera = function(_, Alpha)
	if not (Camera.CameraSubject:IsDescendantOf(Character) or Camera.CameraSubject:IsDescendantOf(Player)) then return end
	Alpha = Alpha or Configs.HeadFollowAlpha
	local ZColumn = -(Camera.CFrame.LookVector)
	ZColumn = ZColumn - Vector3.new(0, ZColumn.Y, 0)
	local XColumn = Vector3.yAxis:Cross(ZColumn)

	if Torso.CFrame:PointToObjectSpace(Head.Position+ZColumn).Z > 0 then
		Neck.C0 = Neck.C0:Lerp(NeckOriginC0 * CFrame.fromMatrix(Vector3.zero, XColumn, Vector3.yAxis, ZColumn), Alpha)
		Waist.C0 = Waist.C0:Lerp(WaistOriginC0 * CFrame.fromMatrix(Vector3.zero, XColumn*0.5, Vector3.yAxis, ZColumn), Alpha)
	end
end


Module.FaceCharacterToMouse = function(_, Alpha, GoalCF)
	if GoalCF then 
		Root.CFrame = Root.CFrame:Lerp(GoalCF, Alpha or Configs.FaceCharacterAlpha)
	else
		local Eye = Root.Position
		local XAxis = Vector3.new(Mouse.Hit.Position.X, Root.Position.Y, Mouse.Hit.Position.Z)-Eye
		if (XAxis:Dot(XAxis) <= Module.Epsilon) then 
			Root.CFrame = Root.CFrame:Lerp(CFrame.new(
				Eye.X, Eye.Y, Eye.Z, 
				1, 0, 0, 
				0, 1, 0, 
				0, 0, 1
			), Alpha or Configs.FaceCharacterAlpha)
		end
		XAxis = XAxis.Unit
		local Xx, Xy, Xz = XAxis.X, XAxis.Y, XAxis.Z
		local RNorm = (((Xz*Xz)+(Xx*Xx))) -- R:Dot(R), our right vector
		if RNorm <= Module.Epsilon and math.abs(XAxis.Y) > 0 then
			Root.CFrame = Root.CFrame:Lerp(CFrame.fromMatrix(
				Eye, 
				-math.sign(XAxis.Y)*Vector3.zAxis, 
				Vector3.xAxis
			), Alpha or Configs.FaceCharacterAlpha)
		end
		RNorm = 1/(RNorm^0.5) -- take the root of our squared norm and inverse division
		local Rx, Rz = -(Xz*RNorm), (Xx*RNorm) -- cross y-axis with right and normalize
		local Ux, Uy, Uz = -Rz*(Rz*Xx-Rx*Xz), -(Rz*Rz)*Xy-(Rx*Rx)*Xy, Rx*(Rz*Xx-Rx*Xz) -- cross right and up and normalize.
		local UNorm = 1/((Ux*Ux)+(Uy*Uy)+(Uz*Uz))^0.5 -- inverse division and multiply this ratio rather than dividing each component
		
		Root.CFrame = Root.CFrame:Lerp(CFrame.new(
			Eye.X,Eye.Y,Eye.Z,
			Rx, -Xy*Rz, Ux*UNorm, 
			0, (Rz*Xx)-Rx*Xz, Uy*UNorm,
			Rz, Xy*Rx, Uz*UNorm
		), Alpha or Configs.FaceCharacterAlpha)
	end
end


Module.FollowMouse = function(Dt, Alpha, XOffset, YOffset)
	Alpha = Alpha or Configs.MouseAlpha
	XOffset = XOffset or Configs.MouseXOffset
	YOffset = YOffset or Configs.MouseYOffset
	DisableRobloxCamera()

	local Easing = Configs.MouseCameraEasingStyle and TweenService:GetValue(Configs.MouseCameraSmoothness, Configs.MouseCameraEasingStyle, Configs.MouseCameraEasingDirection or Enum.EasingDirection.Out)
	local Cosy, Siny = math.cos(XOffset), math.sin(XOffset)
	local Cosx, Sinx = math.cos(YOffset), math.sin(YOffset)
	local Goal = Head.CFrame * CFrame.new(0, Configs.AspectRatio.Y, Configs.AspectRatio.X) * CFrame.new( -- Given that we know the components of CFrame.new(0, Configs.AspectRatio.Y, Configs.AspectRatio.X), we can simplify the product
		0, 0, 0, 
		Cosy, Siny*Sinx, Siny*Cosx, 
		0, Cosx, -Sinx,
		-Siny, Cosy*Sinx, Cosy*Cosx
	)
	
	if Easing then
		Camera.CFrame = Camera.CFrame:Lerp(Goal, Easing)
	else
		local a = Configs.MouseCameraSmoothness-1
		Camera.CFrame = Camera.CFrame:Lerp(Goal, (a*a*a*a*a)+1)
	end
	
	local P = Mouse.Hit.Position
	local Dis = (Head.CFrame.Position - P).Magnitude
	local Dif = Head.CFrame.Y-P.Y
	local X, Y = -math.atan(Dif/Dis)*0.5, (((Head.CFrame.Position-P).Unit):Cross(Torso.CFrame.LookVector)).Y
	
	-- rotation matrix --
	local cosx, sinx = math.cos(X), math.sin(X)
	local cosy, siny = math.cos(Y),  math.sin(Y)
	local R11, R12, R13 = 0, 0, siny
	local R21, R22, R23 = 0, 0, -cosy*sinx
	local R31, R32, R33 = 0, 0, cosx*cosy
	 
	do -- Neck transformation matrix (OriginC0*rotation) --
		local MotorC0 = Neck.C0
		local ax, ay, az, a11, a12, a13, a21, a22, a23, a31, a32, a33 = NeckOriginC0:GetComponents()
		local x, y, z = ax, ay, az
		R11, R12, R13 = 0, 0, a11*R13+a12*R23+a13*R33
		R21, R22, R23 = 0, 0, a21*R13+a22*R23+a23*R33
		R31, R32, R33 = 0, 0, a31*R13+a32*R23+a33*R33
		
		local ax, ay, az, a11, a12, a13, a21, a22, a23, a31, a32, a33 = MotorC0:GetComponents()
		local Determinant = a11*a22*a33+a12*a23*a31+a13*a21*a32-a11*a23*a32-a12*a21*a33-a13*a22*a31 
		if Determinant ~= 0 then -- Fall to a slower case but still pretty nice little fast slerp trick
			local GoalPos = Vector3.new(x, y, z)
			local GoalLook = Vector3.new(-R13, -R23, -R33)
			local Theta = math.acos(MotorC0.lookVector:Dot(GoalLook)) 
			
			if Theta < 0.01 then 
				Neck.C0 = MotorC0 -- Because the rotation difference is practically the same
			else
				local Position = MotorC0.Position:Lerp(GoalPos, Alpha)
				local InvSin = 1/math.sin(Theta)
				local Rotation = math.sin((1-Alpha)*Theta)*InvSin*MotorC0.LookVector + math.sin(Alpha*Theta)*InvSin*GoalLook
				Neck.C0 = CFrame.lookAt(
					Position, 
					Position + Rotation
				)
			end
		else-- if det is 0, we don't have to calculute for matrix inverse; shortcut lerp. Otherwise, Roblox here probably benefits from SIMD hardware optimizations which typically use elimination methods
			local x, y, z = ax,ay, az 
			R11, R12, R13 = 0, 0, a11*R13+a12*R23+a13*R33 -- convert goal to start's object space with inversion omitted
			R21, R22, R23 = 0, 0, a21*R13+a22*R23+a23*R33
			R31, R32, R33 = 0, 0, a31*R13+a32*R23+a33*R33

			if (R33 > 0) and math.acos(R23*(0.5/(math.sqrt(1+R33)))) <= Module.Epsilon then -- (R11+R22+R33)>0  (our trace) 
				local Pos = MotorC0.Position + (Vector3.new(x, y+1, z) - MotorC0.Position) * Alpha*0.5
				Neck.C0 = CFrame.new (
					Pos.X, Pos.Y, Pos.Z, 
					R11, R12, R13, 
					R21, R22, R23, 
					R31, R32, R33
				) 
			else -- Best to just use :Lerp to save us here given the computations we already have made, our little fast slerp probably won't be able to save us at this point now...
				Neck.C0:Lerp(CFrame.new(
					0, 0, 0, 
					R11, R12, R13, 
					R21, R22, R23, 
					R31, R32, R33
				), Alpha)
			end
		end		
	end
	
	do -- Waist transformation matrix (OriginC0*rotation) --
		cosy, siny = math.cos(Y*0.5),  math.sin(Y*0.5) -- adjust rotation matrix for y/2
		R11, R12, R13 = 0, 0, siny
		R21, R22, R23 = 0, 0, -cosy*sinx
		R31, R32, R33 = 0, 0, cosx*cosy
		
		local MotorC0 = Waist.C0
		local ax, ay, az, a11, a12, a13, a21, a22, a23, a31, a32, a33 = WaistOriginC0:GetComponents()
		local x, y, z = ax, ay, az
		R11, R12, R13 = 0, 0, a11*R13+a12*R23+a13*R33
		R21, R22, R23 = 0, 0, a21*R13+a22*R23+a23*R33
		R31, R32, R33 = 0, 0, a31*R13+a32*R23+a33*R33

		local ax, ay, az, a11, a12, a13, a21, a22, a23, a31, a32, a33 = MotorC0:GetComponents()
		local Determinant = a11*a22*a33+a12*a23*a31+a13*a21*a32-a11*a23*a32-a12*a21*a33-a13*a22*a31 
		if Determinant ~= 0 then
			local GoalPos = Vector3.new(x, y, z)
			local GoalLook = Vector3.new(-R13, -R23, -R33)
			local Theta = math.acos(MotorC0.lookVector:Dot(GoalLook)) -- LookVector of goal cframe
			
			if Theta < 0.01 then 
				Waist.C0 = MotorC0 -- Because the rotation difference is practically the same
				return
			else
				local Position = MotorC0.Position:Lerp(GoalPos, Alpha)
				local InvSin = 1/math.sin(Theta)
				local Rotation = math.sin((1-Alpha)*Theta)*InvSin*MotorC0.LookVector + math.sin(Alpha*Theta)*InvSin*GoalLook
				Waist.C0 = CFrame.lookAt(
					Position, 
					Position + Rotation
				)
				return
			end
		else-- if det is 0, we don't have to calculute for matrix inverse; shortcut lerp. Otherwise, Roblox here probably benefits from SIMD hardware optimizations which typically use elimination methods
			local x, y, z = ax,ay, az 
			R11, R12, R13 = 0, 0, a11*R13+a12*R23+a13*R33 -- convert goal to start's object space with inversion omitted
			R21, R22, R23 = 0, 0, a21*R13+a22*R23+a23*R33
			R31, R32, R33 = 0, 0, a31*R13+a32*R23+a33*R33

			if (R33 > 0 and math.acos(R23*(0.5/(math.sqrt(1+R33)))) <= Module.Epsilon) then -- (R11+R22+R33)>0  (our trace) 
				local Pos = MotorC0.Position + (Vector3.new(x, y+1, z) - MotorC0.Position) * Alpha*0.5				
				Waist.C0 =  CFrame.new ( 
					Pos.X, Pos.Y, Pos.Z, 
					R11, R12, R13, 
					R21, R22, R23, 
					R31, R32, R33
				)
				return
			else
				Waist.C0:Lerp(CFrame.new( -- Best to just use :Lerp to save us here given the computations we already have made, our little fast slerp probably won't be able to save us at this point now...
					0, 0, 0, 
					R11, R12, R13, 
					R21, R22, R23, 
					R31, R32, R33
				), Alpha)
				return
			end
		end	
	end
end



return Module
