; drives-overlay.g — stock stub; user overlays survive plugin ZIP reinstall
; Generated file: 0:/sys/nxt-user-custom/drives-overlay.g (Configuration Save)

if { fileexists("0:/sys/nxt-user-custom/drives-overlay.g") }
    M98 P"0:/sys/nxt-user-custom/drives-overlay.g"
