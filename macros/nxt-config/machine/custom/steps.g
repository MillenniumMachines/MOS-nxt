; steps.g — stock stub; user overlays survive plugin ZIP reinstall
; Generated file: 0:/sys/nxt-user-custom/steps.g (Configuration Save)

if { fileexists("0:/sys/nxt-user-custom/steps.g") }
    M98 P"0:/sys/nxt-user-custom/steps.g"
else
    ; Fallback when Custom Save has not written user overlays yet
    M92 X800 Y800 Z800
