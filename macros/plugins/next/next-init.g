; next-init.g
; One-time boot/session initialization for the built-in NeXT plugin.

echo "[nxt-plugin:next] init"
if { exists(global.nxtPlatformProfile) && global.nxtPlatformProfile != null }
    echo "[nxt-plugin:next] nxtPlatformProfile=" ^ global.nxtPlatformProfile
if { exists(global.nxtBoardPackEntry) && global.nxtBoardPackEntry != null }
    echo "[nxt-plugin:next] nxtBoardPackEntry=" ^ global.nxtBoardPackEntry
if { exists(global.nxtScyllaMotorVoltage) && global.nxtScyllaMotorVoltage != null }
    echo "[nxt-plugin:next] nxtScyllaMotorVoltage=" ^ global.nxtScyllaMotorVoltage
