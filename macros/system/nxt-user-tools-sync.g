; nxt-user-tools-sync.g — Rewrite 0:/sys/nxt-user-tools.g from live tools[] + global.nxtTT.
; Invoked from M4000.g / M4001.g when auto-persistence is enabled (see global nxtAutoPersistTools).
;
; While nxtUserToolsLoadDepth > 0 (this file or a copy is being M98-loaded line-by-line),
; M4000/M4001 skip calling this macro so one tool at a time does not truncate the file.

if { !inputs[state.thisInput].active }
    M99

if { exists(global.nxtAutoPersistTools) && !global.nxtAutoPersistTools }
    M99

if { !exists(global.nxtTT) || !exists(global.nxtET) }
    M99

var TP = "0:/sys/nxt-user-tools.g"

var defS = 0
if { exists(global.nxtSpindleID) && global.nxtSpindleID != null }
    set var.defS = { global.nxtSpindleID }

echo >{var.TP} {"; nxt user tool library (persisted)"}
echo >>{var.TP} {"; Maintained by nxt-user-tools-sync.g after M4000/M4001 (and DWC Tool Library save)."}
echo >>{var.TP} {"; When M98-loading this file, nxtUserToolsLoadDepth prevents re-entrant sync."}
echo >>{var.TP} {""}
echo >>{var.TP} {"if { !exists(global.nxtUserToolsLoadDepth) }"}
echo >>{var.TP} {"    global nxtUserToolsLoadDepth = 0"}
echo >>{var.TP} {"set global.nxtUserToolsLoadDepth = { global.nxtUserToolsLoadDepth + 1 }"}
echo >>{var.TP} {""}

; Persist the Tool Library edit-lock (self-declares on load for partial-deploy safety).
; Ensure the runtime global exists before reading it — boards that have not yet
; re-run updated nxt-vars.g after an upgrade would otherwise abort every M4000 sync.
if { !exists(global.nxtTTLocked) }
    global nxtTTLocked = false
echo >>{var.TP} {"if { !exists(global.nxtTTLocked) }"}
echo >>{var.TP} {"    global nxtTTLocked = false"}
echo >>{var.TP} { "set global.nxtTTLocked = " ^ global.nxtTTLocked }
echo >>{var.TP} {""}

var ti = 0
while { var.ti < limits.tools }
    ; Skip probe/datum slot — regenerated from config at boot (nxt-probe-tool-sync with K1).
    if { exists(global.nxtReservedFrom) && var.ti >= global.nxtReservedFrom }
        set var.ti = { var.ti + 1 }
        continue
    if { var.ti < #tools && tools[var.ti] != null && tools[var.ti].name != "Unknown Tool" }
        if { global.nxtTT[var.ti] == null }
            set var.ti = { var.ti + 1 }
            continue
        var line = {"M4000 P" ^ var.ti ^ " R" ^ global.nxtTT[var.ti][0] ^ " S""" ^ tools[var.ti].name ^ """" }
        if { tools[var.ti].spindle != var.defS }
            set var.line = { var.line ^ " I" ^ tools[var.ti].spindle }
        if { global.nxtTT[var.ti][1][0] != 0 }
            set var.line = { var.line ^ " X" ^ global.nxtTT[var.ti][1][0] }
        if { global.nxtTT[var.ti][1][1] != 0 }
            set var.line = { var.line ^ " Y" ^ global.nxtTT[var.ti][1][1] }
        if { #global.nxtTT[var.ti] > 2 && global.nxtTT[var.ti][2] >= 0 }
            set var.line = { var.line ^ " F" ^ global.nxtTT[var.ti][2] }
        if { #global.nxtTT[var.ti] > 3 && global.nxtTT[var.ti][3] >= 0 }
            set var.line = { var.line ^ " L" ^ global.nxtTT[var.ti][3] }
        if { #global.nxtTT[var.ti] > 4 && global.nxtTT[var.ti][4] != 1 }
            set var.line = { var.line ^ " C" ^ global.nxtTT[var.ti][4] }
        if { #global.nxtTT[var.ti] > 5 && global.nxtTT[var.ti][5] != 1 }
            set var.line = { var.line ^ " B" ^ global.nxtTT[var.ti][5] }
        echo >>{var.TP} {var.line}

        var g10 = {"G10 L1 P" ^ var.ti }
        var g10any = false
        var axi = 0
        while { var.axi < #move.axes }
            if { var.axi < #move.axes && tools[var.ti].offsets[var.axi] != null }
                set var.g10 = { var.g10 ^ " " ^ move.axes[var.axi].letter ^ tools[var.ti].offsets[var.axi] }
                set var.g10any = true
            set var.axi = { var.axi + 1 }
        if { var.g10any }
            echo >>{var.TP} {var.g10}
        echo >>{var.TP} {""}
    set var.ti = { var.ti + 1 }

echo >>{var.TP} {"set global.nxtUserToolsLoadDepth = { global.nxtUserToolsLoadDepth - 1 }"}
