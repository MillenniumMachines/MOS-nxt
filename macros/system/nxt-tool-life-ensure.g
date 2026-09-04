; nxt-tool-life-ensure.g — allocate nxtToolLife if still null (OM ~8KB: not filled at boot)
if { !exists(global.nxtToolLife) }
    global nxtToolLife = { vector(min(limits.tools, 50), null) }
elif { global.nxtToolLife == null }
    set global.nxtToolLife = { vector(min(limits.tools, 50), null) }
