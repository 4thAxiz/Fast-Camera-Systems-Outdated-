# Fast-Camera-Systems

Probably the most optimized and fastest Camera you'll find written for the Roblox engine...

# Usage

```lua
local Module = require(script:WaitForChild("CameraSystem")) -- CameraModes should be placed under this.
Module.EnableTopDownCamera() -- Functions are pretty self-documenting
```

# Camera Modes
## Over The Shoulder

## Top Down Camera
![image](https://user-images.githubusercontent.com/73378249/175833398-4114805f-549b-462c-922a-90277a2c42b6.png)

## Isometric Camera
![image](https://user-images.githubusercontent.com/73378249/175834608-4d90a4ce-fae4-4bba-a0df-e483e99d5c65.png)

## Side-Scrolling Camera

![image](https://user-images.githubusercontent.com/73378249/175834668-7f013fdd-ad43-406c-85fa-8853b98ccffc.png)

## Follow-Mouse
![image](https://user-images.githubusercontent.com/73378249/175834787-5ec8ec55-b6e1-47f0-b332-d0245a6944d9.png)


# Design 
Purely math based camera designed from scratch. Intended to be lightweight and flexible for future-proofing. All the math I wrote is carefully optimized in considering to modern architectures and in consideration to lower-end architectures like ARM. For those who crave all the slightest optimizations possible, I made a seperate CameraModes module (FastCameraModes) but I leave my cautions as readability is sacraficed considerably.

The challenge posed for deriving and writing a fast camera:
- GC footprint: Luau's GC (garbage collector) is notorious when it comes to cleaning up userdata creation or even table creations that may result in GC Assist instructions which will halt Luau scripts for this extra work needing to be done by the GC.
- Consideration of Luau->C/C++ bridge innovcations: Biggest bottleneck Roblox games face. It is extremely expensive to bridge data between C++ and Luau often making calculations in Luau much faster than what they could be in C++.
- Optimizing Expensive Calculations: Considering cases where components could cancel out other components and resulting in shortcut calculations. 
- Numerical Stability: Unfortunately, calculations in C++ have more precision than Luau but this is neglible however it is important to take in consideration of errors that may stem from this thus designing math to be more numerically robust is something that should always be noted.
- Consideration of current compiler optimizations: It is important to make sure for example that upvalues should stay constant or otherwise the compiler will not be able to cache function closures which is a reasonable performance loss. If we can't cache closures and avoid this, then it is best to cache function constants as upvalues otherwise.
- Further target hardware considerations such as cache locality and branch prediction: Although from the perspective of Luau, the impact is minimal however we can still considerably influence this. When possible, division is avoided and multiplication is favored by multiplying ratios (1/x) instead as this is still faster on ARM but doesn't hurt other architectures however bypass delays are also taken in considering of as inverse division leads to interleaving integer and floating operations.
