; drives.g - Configures motor driver settings

; Physical drive 0 (X) goes forwards using default driver timings
M569 P0 S0

; Physical drive 1 (Y) goes forwards using default driver timings
M569 P1 S0

; Physical drive 2 (Z) reversed vs v1.5 (v1.6 / v2.0 mechanical)
M569 P2 S1

; Set drive mappings to relevant axes
M584 X0 Y1 Z2

; Configure microstepping, no interpolation.
; This is about as high as we can go without losing
; significant amounts of torque.
; This puts our positional accuracy around the 0.02-0.04mm range.
M350 X32 Y32 Z32

; Steps/mm: machine/<profile>/steps.g

; Set motor currents (mA)
M906 X1800 Y1800 Z1200

; Set standstill current reduction to 10%
M917 X10 Y10 Z10

; Enable motor idle current reduction after 30 seconds
M84 S30