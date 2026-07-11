; limits.g — Custom travel from nxtCustom* globals (Configuration UI)

var nxtHaveCustom = false
if { exists(global.nxtCustomXMin) && global.nxtCustomXMin != null }
    if { exists(global.nxtCustomXMax) && global.nxtCustomXMax != null }
        if { exists(global.nxtCustomYMin) && global.nxtCustomYMin != null }
            if { exists(global.nxtCustomYMax) && global.nxtCustomYMax != null }
                if { exists(global.nxtCustomZMin) && global.nxtCustomZMin != null }
                    if { exists(global.nxtCustomZMax) && global.nxtCustomZMax != null }
                        set var.nxtHaveCustom = true

if { !var.nxtHaveCustom }
    echo "[nxt] custom limits: set all nxtCustom* Min/Max in Configuration"
    M117 "nxt custom limits unset"
    M99

; Set axis limits - minima
M208 X{global.nxtCustomXMin} Y{global.nxtCustomYMin} Z{global.nxtCustomZMin} S1

; Set axis limits - maxima
M208 X{global.nxtCustomXMax} Y{global.nxtCustomYMax} Z{global.nxtCustomZMax} S0
