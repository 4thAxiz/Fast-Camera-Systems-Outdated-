-- 4thAxis
-- 6/20/22

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

local DownVector = Vector3.new(0,-1,0)
Module.Epsilon = 1e-5
Module.CameraAngleX = 0
Module.CameraAngleY = 0

local InvRoot2 = 1/math.sqrt(2)
local Right = Vector3.new(1, 0, 0)
local Top   = Vector3.new(0, 1, 0)
local Back  = Vector3.new(0, 0, 1)

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

local function GetRotationXY(X, Y)
	X = X or Module.CameraAngleX
	Y = Y or Module.CameraAngleY
	
	local Cosy, Siny = math.cos(X),  math.sin(X)
	local Cosx, Sinx = math.cos(Y), math.sin(Y)
	return CFrame.new(
		0, 0, 0, 
		Cosy, Siny*Sinx, Siny*Cosx, 
		0, Cosx, -Sinx,
		-Siny, Cosy*Sinx, Cosy*Cosx
	)
end


local function GetPositionToWorldByOffset(OriginCF, XOffset, YOffset, ZOffset)
	-- Perserve rotational matrix, only transform position to world instead rather than naively transforming origin cframe to world space
	XOffset = XOffset or Configs.CamLockOffset.X
	YOffset = YOffset or Configs.CamLockOffset.Y
	ZOffset = ZOffset or Configs.CamLockOffset.Z

	local X, Y, Z, M11, M12, M13, M21, M22, M23, M31, M32, M33 = OriginCF:GetComponents()
	return Vector3.new (
		M11*XOffset+M12*YOffset+M13*ZOffset+X,
		M21*XOffset+M22*YOffset+M23*ZOffset+Y,
		M31*XOffset+M32*YOffset+M33*ZOffset+Z
	)
end


local function ZBasisToObjectSpace(ZBasis, Offset)
	local x, y, z, a11, a12, a13, 
				   a21, a22, a23, 
				   a31, a32, a33 = Offset:GetComponents()
	-- Z-basis of rotational matrix, we actually have a singular matrix meaning it is non-invertable e.g ZBasis:Invert()=ZBasis so this is nice short-cut
	local _, _, _, _, _, R13, 	
				   _, _, R23, 
				   _, _, R33 = ZBasis:GetComponents()

	return x, y, z,
		   0, 0, a11*R13+a12*R23+a13*R33,
		   0, 0, a21*R13+a22*R23+a23*R33,
		   0, 0, a31*R13+a32*R23+a33*R33
end


local function MatrixFromAxisAngles(PivotAxis, Theta, Delta, Alpha)
	Theta = Theta*Alpha
	PivotAxis = PivotAxis.Unit
	
	local SinTheta, CosTheta = math.sin(Theta), math.cos(Theta)	
	local RightDotPivot = PivotAxis.X -- Right:Dot(Pivot)
	local PivotCrossRight = Vector3.new(0, PivotAxis.Z, -PivotAxis.Y) -- Pivot:Cross(Right)
	local TopDotPivot = PivotAxis.Y -- Top:Dot(Pivot)
	local PivotCrossTop = Vector3.new(-PivotAxis.Z, 0, PivotAxis.X) -- PivotCrossTop
	local BackDotPivot = PivotAxis.Z -- Back:Dot(Pivot)
	local PivotCrossBack = Vector3.new(PivotAxis.Y, -PivotAxis.X, 0)
	
	-- Can considerably optimize this but got lazy-- would look like this: https://gyazo.com/dceaf793453bc48b1731526c3a70c6d8 in case anyone dares to do so...
	
	local Right = Right*Theta+RightDotPivot*PivotAxis*(1-Theta)+PivotCrossRight*Theta 
	local Top = Top*Theta+TopDotPivot*PivotAxis*(1-Theta)+PivotCrossRight*Theta 
	local Back = Back*Theta+BackDotPivot*PivotAxis*(1-Theta)+PivotCrossRight*Theta 
	
	return CFrame.new(
		0, 0, 0,
		Right.X, Top.X, Back.X,
		Right.Y, Top.Y, Back.Y,
		Right.Z, Top.Z, Back.Z
	) + Delta*Alpha
end


local function SlerpInvertedRotation(Motor, PivotAxis, Theta, Delta, Alpha, M11, M12, M13, M21, M22, M23, M31, M32, M33)
	if M11 > M22 and M11 > M33 then
		if M11 < 1e-4 then
			PivotAxis = Vector3.new(0, InvRoot2, InvRoot2)
		else
			local x = math.sqrt(M11)
			local invx = 1/x
			M21 = (M21 + M12)/4
			M31 = (M31 + M13)/4
			PivotAxis = Vector3.new(x, M21*invx, M31*invx)
		end
		return Motor * MatrixFromAxisAngles(PivotAxis, Theta, Delta, Alpha)

	elseif M22 > M33 then
		if M22 < 1e-4 then
			PivotAxis = Vector3.new(InvRoot2, 0, InvRoot2)
		else
			local y = math.sqrt(M22)
			local invy = 1/y
			M21 = (M21 + M12)/4
			M32 = (M32 + M23)/4
			PivotAxis = Vector3.new(M21*invy, y, M32*invy)
		end
		return Motor * MatrixFromAxisAngles(PivotAxis, Theta, Delta, Alpha)

	else
		if M33 < 1e-4 then
			PivotAxis = Vector3.new(InvRoot2, InvRoot2, 0)
		else
			local z = math.sqrt(M33)
			local invz = 1/z
			M31 = (M31 + M13)/4
			M32 = (M33 + M23)/4
			PivotAxis = Vector3.new(M31*invz, M32*invz, z)
		end

		return Motor * MatrixFromAxisAngles(PivotAxis, Theta, Delta, Alpha)
	end
end


local function LerpFromZBasisRotationMatrix(Motor, ZBasis, Alpha)
	-- SLERP while avoiding quarternions, specifically written. Not sure if a generalized custom lerp would come close to gapping CFrame:Lerp()
	Alpha = Alpha or 0.5

	local _, _, _, M11, M12, M13, 
				   M21, M22, M23, 
				   M31, M32, M33 = ZBasisToObjectSpace(ZBasis, Motor)

	local CoTheta = (M11 + M22 + M33 - 1)*0.5
	local Delta = (ZBasis.Position-Motor.Position)
	if CoTheta == 0 then return Motor + Delta*Alpha end -- Rotations are aligned, interpolate positions

	local PivotAxis = Vector3.new(M32-M23, M13-M31, M21-M12) -- Rotation Axis
	if CoTheta >= 0.999 then -- Close but not perfectly aligned rotations, best to just LERP...
		local a = 1 - Alpha
		local _, _, _, a11, a12, a13, 
					   a21, a22, a23, 
					   a31, a32, a33 = Motor:GetComponents()
		local _, _, _, _, _, R13, 	
					   _, _, R23, 
					   _, _, R33 = ZBasis:GetComponents()
		
		return CFrame.new(
			0, 0, 0, 
			a11*a, a12*a, a13*a+R13*Alpha,
			a21*a, a22*a, a23*a+R23*Alpha,
			a31*a, a32*a, a33*a+R33*Alpha
		) + (Motor.Position + Delta*Alpha)
		
	elseif CoTheta <= -0.9999 then -- exactly opposite rotations, probably not common but exists for numerical scalability practice
		M11, M22, M33 = (M11+1)/2, (M22+1)/2, (M33+1)/2  -- 0.5*Mn+0.5 sounds nice but it really isn't
		return SlerpInvertedRotation(Motor, PivotAxis, math.pi, Delta, Alpha,
			M11, M12, M13, 
			M21, M22, M23, 
			M31, M32, M33
		)
	else -- Normal case
		return Motor * MatrixFromAxisAngles(PivotAxis, math.acos(CoTheta), Delta, Alpha)
	end
end



local function FastCFLerpCase(MotorC0, YOffset, Alpha, R11, R12, R13, R21, R22, R23, R31, R32, R33, OrthogonalMatrix) 
	local _, _, _, a11, a12, a13, a21, a22, a23, a31, a32, a33 = MotorC0:GetComponents()
	local Determinant = a11*a22*a33+a12*a23*a31+a13*a21*a32-a11*a23*a32-a12*a21*a33-a13*a22*a31 
	if Determinant~=0 then return false end		-- if det is 0, we don't have to calculute for matrix inverse; shortcut lerp. Otherwise, Roblox here probably benefits from SIMD hardware optimizations which typically use elimination methods. Technically orthogonal matrices shouldn't have det=0 but who said this can't be just used with orthongal matrices ;)
	local ax, ay, az; ax, ay, az, a11, a12, a13, a21, a22, a23, a31, a32, a33 = MotorC0:GetComponents() -- too lazy to work with det order
	-- convert goal to start's object space with inversion omitted
	local x, y, z = ax,ay, az 
	R11, R12, R13 = 0, 0, a11*R13+a12*R23+a13*R33 
	R21, R22, R23 = 0, 0, a21*R13+a22*R23+a23*R33
	R31, R32, R33 = 0, 0, a31*R13+a32*R23+a33*R33

	if (R33 > 0) then -- (R11+R22+R33)>0  (our trace) 
		local Pos = MotorC0.Position + (Vector3.new(x, y+YOffset, z) - MotorC0.Position) * Alpha*0.5
		local Theta =  math.acos(R23*(0.5/(math.sqrt(1+R33)))) -- possible to cancel out square root
		if Theta == 0 then -- theta~=0 is too expensive to handle because we need c0* matrix from axis angles for rotation and additional stuff if we go with this approach...
			return CFrame.new (
				Pos.X, Pos.Y, Pos.Z, 
				R11, R12, R13, 
				R21, R22, R23, 
				R31, R32, R33
			)
		end
	end

	return false
end


local function SlerpXY(Origin, GoalPos, GoalLook, Alpha)
	Alpha = math.clamp(Alpha or 0.5, 0, 1)
	local Theta = math.acos(Origin.lookVector:Dot(GoalLook)) -- LookVector of goal cframe
	if Theta < 0.01 then 
		return Origin
	else
		local Position = Origin.Position:Lerp(GoalPos, Alpha)
		local InvSin = 1/math.sin(Theta)
		local Rotation = math.sin((1-Alpha)*Theta)*InvSin*Origin.LookVector + math.sin(Alpha*Theta)*InvSin*GoalLook
		return CFrame.lookAt(
			Position, 
			Position + Rotation
		)
	end
end


local function TransformMotor(Motor, MotorOriginC0, x, y, YOffset, Alpha)
	YOffset = YOffset or 0
	Alpha = Alpha or 0.5
	local MotorC0 = Motor.C0
	-- rotation matrix --
	local cosx, sinx = math.cos(x), math.sin(x)
	local cosy, siny = math.cos(y),  math.sin(y)
	local R11, R12, R13 = 0, 0, siny
	local R21, R22, R23 = 0, 0, -cosy*sinx
	local R31, R32, R33 = 0, 0, cosx*cosy
	-- transformation matrix (OriginC0*rotation) --
	local ax, ay, az, a11, a12, a13, a21, a22, a23, a31, a32, a33 = MotorOriginC0:GetComponents()
	local x, y, z = ax, ay, az
	R11, R12, R13 = 0, 0, a11*R13+a12*R23+a13*R33
	R21, R22, R23 = 0, 0, a21*R13+a22*R23+a23*R33
	R31, R32, R33 = 0, 0, a31*R13+a32*R23+a33*R33	
	
	local FromFastLerp = FastCFLerpCase(MotorC0, YOffset, Alpha, R11, R12, R13, R21, R22, R23, R31, R32, R33, true) -- calculute for orthongonal matrix -> only rotational matrix
	return FromFastLerp or SlerpXY (
		Motor.C0,  
		Vector3.new(x, y, z),
		Vector3.new(-R13, -R23, -R33), 
		Alpha
	)
end


local function GetViewMatrix(Eye, Focus)
	-- Faster alternative to cframe.lookat for our case since we are more commonly prone to special cases such as: when focus is facing up/down or if focus and eye are colinear vectors
	local XAxis = Focus-Eye -- Lookvector
	if (XAxis:Dot(XAxis) <= Module.Epsilon) then 
		return CFrame.new(Eye.X, Eye.Y, Eye.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1) 
	end
	XAxis = XAxis.Unit
	local Xx, Xy, Xz = XAxis.X, XAxis.Y, XAxis.Z
	local RNorm = (((Xz*Xz)+(Xx*Xx))) -- R:Dot(R), our right vector
	if RNorm <= Module.Epsilon and math.abs(XAxis.Y) > 0 then
 		return CFrame.fromMatrix(Eye, -math.sign(XAxis.Y)*Vector3.zAxis, Vector3.xAxis)
	end
	RNorm = 1/(RNorm^0.5) -- take the root of our squared norm and inverse division
	local Rx, Rz = -(Xz*RNorm), (Xx*RNorm) -- cross y-axis with right and normalize
	local Ux, Uy, Uz = -Rz*(Rz*Xx-Rx*Xz), -(Rz*Rz)*Xy-(Rx*Rx)*Xy, Rx*(Rz*Xx-Rx*Xz) -- cross right and up and normalize.
	local UNorm = 1/((Ux*Ux)+(Uy*Uy)+(Uz*Uz))^0.5 -- inverse division and multiply this ratio rather than dividing each component
	return CFrame.new(
		Eye.X,Eye.Y,Eye.Z,
		Rx, -Xy*Rz, Ux*UNorm, 
		0, (Rz*Xx)-Rx*Xz, Uy*UNorm,
		Rz, Xy*Rx, Uz*UNorm
	)
end

--------------------------------------------------------------------
-------------------------  Functions  ------------------------------
--------------------------------------------------------------------

Module.OverTheShoulder = function(_, CameraAngleX, CameraAngleY, Lerp)
	Module.CameraAngleX = CameraAngleX or Module.CameraAngleX
	Module.CameraAngleY = CameraAngleY or Module.CameraAngleY	
	if Camera.CameraType ~= Enum.CameraType.Scriptable then Camera.CameraType = Enum.CameraType.Scriptable end

	local Origin = CFrame.new((HumanoidRootPart.CFrame.Position)) * GetRotationXY(math.rad(Module.CameraAngleX), math.rad(Module.CameraAngleY))
	local Eye = GetPositionToWorldByOffset(Origin)
	local Focus = GetPositionToWorldByOffset(Origin, Configs.CamLockOffset.X, Configs.CamLockOffset.Y, -10000)

	Camera.CFrame = GetViewMatrix(Eye, Focus)
end


Module.IsometricCamera = function(_, CameraDepth, HeightOffset, FOV)
	CameraDepth = CameraDepth or Configs.IsometricCameraDepth
	HeightOffset = HeightOffset or Configs.IsometricHeightOffset
	Camera.FieldOfView = FOV or Configs.IsometricFieldOfView

	local Root = HumanoidRootPart.Position + Vector3.new(0, HeightOffset, 0)
	local Eye = Root + Vector3.new(CameraDepth, CameraDepth, CameraDepth)	
	Camera.CFrame = GetViewMatrix(Eye, Root)
end


Module.SideScrollingCamera = function(_, CameraDepth, HeightOffset, FOV)
	CameraDepth = CameraDepth or Configs.SideCameraDepth
	HeightOffset = HeightOffset or Configs.SideHeightOffset
	Camera.FieldOfView = FOV or Configs.SideFieldOfView

	local Focus = HumanoidRootPart.Position + Vector3.new(0, HeightOffset, 0)
	local Eye = Vector3.new(Focus.X, Focus.Y, CameraDepth)
	Camera.CFrame =  GetViewMatrix(Eye, Focus)
end


Module.TopDownCamera = function(_, FaceMouse, MouseSensitivity, Offset, Direction, Distance)
	FaceMouse = FaceMouse or Configs.TopDownFaceMouse
	MouseSensitivity = MouseSensitivity or Configs.TopDownMouseSensitivity
	Distance = Distance or Configs.TopDownDistance
	Direction = Direction or DownVector
	Offset = Offset or Configs.TopDownOffset

	local Axis = Vector3.new(-((Mouse.Y-ScreenSizeY*0.5)*PixelCoordinateRatioY),0,((Mouse.X-ScreenSizeX*0.5)*PixelCoordinateRatioX))
	local Eye = (Distance + (Root.Position+Offset)) + Axis * MouseSensitivity 
	
	local Focus = Eye + Direction
	Camera.CFrame = GetViewMatrix(Eye, Focus)
	
	if FaceMouse then
		local Forward = (Root.Position - Mouse.Hit.Position).Unit
		local Right = Vector3.new(-Forward.Z, 0, Forward.X) -- Forward:Cross(YAxis)
		Root.CFrame = CFrame.fromMatrix(Root.Position, -Right, Vector3.yAxis)
	end
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
	GoalCF = GoalCF or GetViewMatrix(Root.Position, Vector3.new(Mouse.Hit.Position.X, Root.Position.Y, Mouse.Hit.Position.Z))
	Root.CFrame = Root.CFrame:Lerp(GoalCF, Alpha or Configs.FaceCharacterAlpha)
end
 

Module.FollowMouse = function(Dt)
	local Easing = Configs.MouseCameraEasingStyle and TweenService:GetValue(Configs.MouseCameraSmoothness, Configs.MouseCameraEasingStyle, Configs.MouseCameraEasingDirection or Enum.EasingDirection.Out)
	local Goal = Head.CFrame * CFrame.new(0, Configs.AspectRatio.Y, Configs.AspectRatio.X) * GetRotationXY(270, math.rad(2))
	if Easing then
		Camera.CFrame = Camera.CFrame:Lerp(Goal, Easing)
	else
		local a = Configs.MouseCameraSmoothness-1
		Camera.CFrame = Camera.CFrame:Lerp(Goal, (a*a*a*a*a)+1)
	end
	
	local P = Mouse.Hit.Position
	local Distance = (Head.CFrame.Position - P).Magnitude
	local Difference = Head.CFrame.Y-P.Y
	local X, Y = -math.atan(Difference/Distance)*0.5, (((Head.CFrame.Position-P).Unit):Cross(Torso.CFrame.LookVector)).Y

	Neck.C0 = TransformMotor(Neck, NeckOriginC0, X, Y, 1, 0.5)
	Waist.C0 = TransformMotor(Waist, WaistOriginC0, X, Y*0.5, 0, 0.5)
end



return Module
