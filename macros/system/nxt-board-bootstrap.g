; nxt-board-bootstrap.g
; Runs from nxt.g BEFORE nxt-vars.g when board kit auto-load is requested.
;
; Opt-in:  create empty file 0:/sys/nxt-board-bootstrap.requested
; Opt-out: create 0:/sys/nxt-board-bootstrap.skip
; Override: 0:/sys/nxt-user-board.g (your own M98 chain; runs instead of auto-detect)
;
; shortName values must match RRF firmware (object model boards[0].shortName). Verify with M409 / DWC.
; Auto paths load v1.5 kits; for v1.6/v2 use 0:/sys/nxt-user-board.g → nxt/config/v1.6_v2/.../entry.g

if { !fileexists("0:/sys/nxt-board-bootstrap.requested") }
    M99

if { fileexists("0:/sys/nxt-board-bootstrap.skip") }
    echo "[NeXT] board bootstrap: skipped (nxt-board-bootstrap.skip)"
    M117 "NeXT kit bootstrap SKIPPED"
    M99

echo "[NeXT] board bootstrap: starting (kit fragments before nxt-vars.g)"
M117 "NeXT kit bootstrap start"

if { fileexists("0:/sys/nxt-user-board.g") }
    M117 "NeXT nxt-user-board.g"
    M98 P"nxt-user-board.g"
    echo "[NeXT] board bootstrap: finished (nxt-user-board.g)"
    M99

if { #boards < 1 }
    echo "[NeXT] board bootstrap: no boards[] in object model; add nxt-user-board.g"
    M117 "NeXT kit no boards[] OM"
    M99

; Fly CDYv3 (RRF reports boards[0].shortName "cdy3_f4")
if { boards[0].shortName == "cdy3_f4" }
    M117 "NeXT kit v1.5 Fly CDYv3"
    M98 P"nxt/config/v1.5/ldo-kit-fly-cdyv3/entry.g"
    echo "[NeXT] board bootstrap: Fly CDYv3 kit loaded (shortName cdy3_f4)"
    M99

; Scylla v1.0 (RRF reports boards[0].shortName "scylla1_0_h723") — default 24 V kit; 48 V via nxt-user-board.g
if { boards[0].shortName == "scylla1_0_h723" }
    M117 "NeXT kit v1.5 Scylla 24V"
    M98 P"nxt/config/v1.5/ldo-kit-scylla-24v/entry.g"
    echo "[NeXT] board bootstrap: Scylla 24V kit loaded (shortName scylla1_0_h723; 48V → nxt-user-board.g)"
    M99

echo "[NeXT] board bootstrap: unknown boards[0].shortName — add nxt-user-board.g on SD; inspect OM boards[0].shortName"
M117 "NeXT kit board UNKNOWN"
