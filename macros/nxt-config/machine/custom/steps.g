; steps.g — Custom steps/mm from nxtCustom*Steps, else defaults

var nxtHaveSteps = false
if { exists(global.nxtCustomXSteps) && global.nxtCustomXSteps != null }
    if { exists(global.nxtCustomYSteps) && global.nxtCustomYSteps != null }
        if { exists(global.nxtCustomZSteps) && global.nxtCustomZSteps != null }
            set var.nxtHaveSteps = true

if { var.nxtHaveSteps }
    if { exists(global.nxtCustomASteps) && global.nxtCustomASteps != null }
        M92 X{global.nxtCustomXSteps} Y{global.nxtCustomYSteps} Z{global.nxtCustomZSteps} A{global.nxtCustomASteps}
    else
        M92 X{global.nxtCustomXSteps} Y{global.nxtCustomYSteps} Z{global.nxtCustomZSteps}
    M99

; Default steps (edit for your leadscrews / gearing, or set via Configuration)
M92 X800 Y800 Z800
