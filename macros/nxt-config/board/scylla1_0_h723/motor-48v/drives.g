; drives.g - Configures motor driver settings
; XYZ M569 directions: machine/<profile>/drives-dir.g (after board pack)

; Set non-standard sense resistors for the BTT 5160 drivers
M569.9 P0.0 R0.05
M569.9 P0.1 R0.05
M569.9 P0.2 R0.05
M569.9 P0.3 R0.05

; Set drive mappings to relevant axes (A / drive 3: see axis-a.g when
; global.nxtFeatureFourthAxis — keeps XYZ-only machines from getting a phantom A)
M584 X0 Y1 Z2

; Configure microstepping, no interpolation.
; This is about as high as we can go without losing
; significant amounts of torque.
; This puts our positional accuracy around the 0.02-0.04mm range.
M350 X32 Y32 Z32 I0

; Milo lead-screws are 8mm pitch, with 1.8 degree motors or 200 steps per revolution
; Z axis is geared 2-1 for v1.5

; Steps/mm: machine/<profile>/steps.g

; Set motor currents (mA). I100 = no idle-current drop (M84 S0 is invalid on
; RRF 3.5.1+; default I30 after timeout lets mill Z droop).
M906 X3000 Y3000 Z3000 I100

; Set standstill current (percent of M906). Z holds against gravity on a mill;
; XY can sit lower. A is set in axis-a.g (M917 A90) when fourth axis is on.
M917 X10 Y10 Z50
