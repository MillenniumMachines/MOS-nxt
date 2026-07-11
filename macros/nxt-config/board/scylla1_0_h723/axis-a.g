; axis-a.g — Scylla v1.0 fourth axis (physical drive 3)
;
; Loaded from motor-*/entry.g when global.nxtFeatureFourthAxis is true.
; Pins: amin=PD_15 (D.15), amax=PD_13 (D.13). Driver 3 is the 4th TMC5160.
;
; Steps/mm, soft limits, and speeds: prefer MosFourthAxis
; 0:/sys/rotary-plugin-config.g (M98 from config.g after nxt) — or calibrate
; with M4806. Do not duplicate M584 A / M574 A there if this file already ran.

; Direction for physical drive 3
M569 P3 S1

; Map logical A → drive 3, rotary mode (degrees)
M584 A3 R1

; Microstepping (no interpolation) — match XYZ board pack
M350 A32 I0

; Current / standstill — spit-roast Nema23 @ 48 V defaults (tune as needed)
M906 A3500 I100
M917 A90

; Homing endstop: stock MosFourthAxis uses amax header as A1 (active low).
; Change to P"!amin" if your switch is on the min header instead.
M574 A1 S1 P"!amax"

echo "[nxt] board Scylla: A axis mapped (drive 3, endstop !amax)"
