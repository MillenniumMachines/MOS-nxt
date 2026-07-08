; M4005.g: CHECK nxt POST-PROCESSOR VERSION
;
; Compares param.V from the CAM post-processor to global.nxtVersion (release line, e.g. v0.7.0).
; Exact string match only — no tag or beta-number rules.

if { !inputs[state.thisInput].active }
    M99

if { !exists(param.V) }
    abort { "M4005: post-processor version (V...) is required" }

if { !exists(global.nxtVersion) }
    abort { "M4005: nxt not loaded (global.nxtVersion missing)" }

if { param.V != global.nxtVersion }
    abort { "Post-processor version mismatch: need " ^ global.nxtVersion ^ ", got " ^ param.V }
