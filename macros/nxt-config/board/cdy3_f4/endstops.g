; endstops.g — CDYv3 endstop pin wiring (Y direction set by machine/.../endstop-y.g)

; Endstop X=MIN: NC
M574 X1 S1 P"PC_7"

; Endstop Y (pin); direction overridden per machine profile
M574 Y1 S1 P"PD_11"

; Endstop Z=MAX: NC
M574 Z2 S1 P"PB_10"
