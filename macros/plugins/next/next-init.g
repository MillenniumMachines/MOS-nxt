; next-init.g
; One-time boot/session initialization for the built-in nxt plugin.

echo "[nxt-plugin:next] init"
if { exists(global.nxtPlatformProfile) && global.nxtPlatformProfile != null }
    echo "[nxt-plugin:next] nxtPlatformProfile=" ^ global.nxtPlatformProfile
if { exists(global.nxtBoardPackEntry) && global.nxtBoardPackEntry != null }
    echo "[nxt-plugin:next] nxtBoardPackEntry=" ^ global.nxtBoardPackEntry
if { exists(global.nxtBoardPackExpectedEntry) && global.nxtBoardPackExpectedEntry != null }
    echo "[nxt-plugin:next] nxtBoardPackExpectedEntry=" ^ global.nxtBoardPackExpectedEntry
if { exists(global.nxtBoardMotorVoltage) && global.nxtBoardMotorVoltage != null }
    echo "[nxt-plugin:next] nxtBoardMotorVoltage=" ^ global.nxtBoardMotorVoltage
elif { exists(global.nxtScyllaMotorVoltage) && global.nxtScyllaMotorVoltage != null }
    echo "[nxt-plugin:next] nxtScyllaMotorVoltage (deprecated)=" ^ global.nxtScyllaMotorVoltage
