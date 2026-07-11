; endstops.g — Custom M574 pin + side (after board pack endstops)
; Applies per-axis when both pin and HomeAt (1=min, 2=max) are set.

if { exists(global.nxtCustomXEndstopPin) && global.nxtCustomXEndstopPin != null }
    if { exists(global.nxtCustomXHomeAt) && global.nxtCustomXHomeAt != null }
        M574 X{global.nxtCustomXHomeAt} S1 P{global.nxtCustomXEndstopPin}

if { exists(global.nxtCustomYEndstopPin) && global.nxtCustomYEndstopPin != null }
    if { exists(global.nxtCustomYHomeAt) && global.nxtCustomYHomeAt != null }
        M574 Y{global.nxtCustomYHomeAt} S1 P{global.nxtCustomYEndstopPin}

if { exists(global.nxtCustomZEndstopPin) && global.nxtCustomZEndstopPin != null }
    if { exists(global.nxtCustomZHomeAt) && global.nxtCustomZHomeAt != null }
        M574 Z{global.nxtCustomZHomeAt} S1 P{global.nxtCustomZEndstopPin}
