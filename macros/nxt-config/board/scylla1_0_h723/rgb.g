; rgb.g — Scylla NeoPixel / RGB header (PD_6 = neopixel / rgbpwm)
;
; Firmware pin names (Team Gloomy Scylla): PD_6 → rgbpwm, neopixel.
; Always bind nxt RGB globals and create the M950 LED strip on board entry
; so the output exists even before nxtFeatureRgbLight / daemon rendering.
; LED count / colours may be updated later by nxt-rgb-colours.g (re-M950).

if { exists(global.nxtRGBPin) }
    set global.nxtRGBPin = "neopixel"
if { exists(global.nxtRGBStrip) }
    set global.nxtRGBStrip = 0
if { exists(global.nxtRGBType) }
    set global.nxtRGBType = 1

; Create / refresh the addressable strip on this board's RGB header.
if { exists(global.nxtRGBPin) && global.nxtRGBPin != null }
    M950 E{global.nxtRGBStrip} C{global.nxtRGBPin} T{global.nxtRGBType} U{global.nxtRGBCount}
    if { exists(global.nxtRGBReady) }
        set global.nxtRGBReady = true
