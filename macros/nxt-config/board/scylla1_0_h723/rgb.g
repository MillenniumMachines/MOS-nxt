; rgb.g — Scylla NeoPixel / RGB header (PD_6 = neopixel / rgbpwm)
;
; Firmware pin names (Team Gloomy Scylla): PD_6 → rgbpwm, neopixel.
; Bind pin/strip only — type/order/count are Configuration → nxt-user-vars.g.
; nxt.g owns the post-colour M950 (single boot owner).
; Daemon nxt-run-rgb.g may lazy-create the strip if pin is set and not yet ready.

if { exists(global.nxtRGBPin) }
    set global.nxtRGBPin = "neopixel"
if { exists(global.nxtRGBStrip) }
    set global.nxtRGBStrip = 0
