; nxt-select-wcs.g: select workplace G54…G59.3 by W (1–9)
;
; RRF forbids dynamic G/M command numbers (only T{…} is allowed).
; Callers must not use G{53 + wcs}; use this helper instead.
;
; USAGE: M98 P"nxt-select-wcs.g" W{1-9}
;   W1 = G54 … W6 = G59 … W9 = G59.3

if { !inputs[state.thisInput].active }
    M99

if { !exists(param.W) || param.W == null || param.W < 1 || param.W > 9 }
    abort { "nxt-select-wcs: W must be 1-9 (G54…G59.3)" }

if { param.W == 1 }
    G54
elif { param.W == 2 }
    G55
elif { param.W == 3 }
    G56
elif { param.W == 4 }
    G57
elif { param.W == 5 }
    G58
elif { param.W == 6 }
    G59
elif { param.W == 7 }
    G59.1
elif { param.W == 8 }
    G59.2
else
    G59.3
