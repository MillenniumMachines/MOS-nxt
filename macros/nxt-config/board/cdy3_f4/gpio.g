; gpio.g — create gpOut ports for free named pins (Configuration UI / M42)
; Indices must match pinmap.json free[].gpOutIndex for this board.
; Fan0/Fan1 and spindle pins stay in fans.g / spindle.g (not gpOut here).

M950 J0 C"fan2"
M950 J1 C"e0heat"
M950 J2 C"e1heat"
M950 J3 C"e2heat"
