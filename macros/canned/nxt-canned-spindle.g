; nxt-canned-spindle.g — INTERNAL: require configured spindle running (M3/M4)
; Called via M98 from canned cycle macros only.

if { global.nxtSpindleID == null || global.nxtSpindleID < 0 || global.nxtSpindleID >= #spindles || spindles[global.nxtSpindleID] == null || spindles[global.nxtSpindleID].state == "unconfigured" }
    abort { "nxt-canned: set global.nxtSpindleID in nxt-user-vars.g for canned cycles" }

if { abs(spindles[global.nxtSpindleID].current) < 0.001 }
    abort { "nxt-canned: spindle must be running (M3/M4) before drilling cycle" }
