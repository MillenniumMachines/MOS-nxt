<#
.SYNOPSIS
  Build the NeXT DWC plugin ZIP for installation on a real machine.
  PowerShell port of dist/build-plugin.sh for Windows.

.PARAMETER DwcRoot
  Path to the DuetWebControl 3.6 development tree.
  Default: ..\DuetWebControl (sibling of this repo)

.EXAMPLE
  .\dist\build-plugin-win.ps1 -DwcRoot "C:\Users\jonat\Downloads\DuetWebControl-3.6-dev\DuetWebControl-3.6-dev"
#>
param(
  [string]$DwcRoot = "$PSScriptRoot\..\..\DuetWebControl"
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path "$PSScriptRoot\..").Path
$OutDir = Join-Path $Root "dist"
$DwcRoot = (Resolve-Path $DwcRoot).Path

Write-Host "=== NeXT Plugin Builder (Windows) ===" -ForegroundColor Cyan
Write-Host "  NeXT repo : $Root"
Write-Host "  DWC root  : $DwcRoot"

# --- Version from git ---
$gitSha = git -C $Root rev-parse --short HEAD 2>$null
if (-not $gitSha) { $gitSha = "unknown" }
$gitBranch = git -C $Root rev-parse --abbrev-ref HEAD 2>$null
if (-not $gitBranch) { $gitBranch = "dev" }
git -C $Root diff-index --quiet HEAD -- 2>$null
$dirty = if ($LASTEXITCODE -ne 0) { "-dirty" } else { "" }
$buildVersion = ("$gitBranch-$gitSha$dirty") -replace '[^A-Za-z0-9._-]', '-'
$outZip = "NeXT-$buildVersion.zip"


Write-Host "  Version   : $buildVersion"
Write-Host "  Output    : dist\$outZip"
Write-Host ""

# --- Cleanup ---
Write-Host "[1/6] Cleaning previous build artifacts..." -ForegroundColor Yellow
$pluginStaged = Join-Path $DwcRoot "src\plugins\NeXT"
# If the junction exists, remove it first (we'll copy files directly for prod build)
if (Test-Path $pluginStaged) {
  $item = Get-Item $pluginStaged -Force
  if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    Write-Host "  Removing junction: $pluginStaged"
    cmd /c rmdir "$pluginStaged" 2>$null
  } else {
    Write-Host "  Removing staged dir: $pluginStaged"
    Remove-Item $pluginStaged -Recurse -Force
  }
}
if (Test-Path (Join-Path $DwcRoot "dist")) {
  Remove-Item (Join-Path $DwcRoot "dist") -Recurse -Force
}
Get-ChildItem "$OutDir\NeXT-*.zip" -ErrorAction SilentlyContinue | Remove-Item -Force

# --- Stage plugin source (copy, not junction — required for prod build) ---
Write-Host "[2/6] Staging plugin source into DWC..." -ForegroundColor Yellow
$stagingDir = Join-Path $env:TEMP "next-plugin-build-$(Get-Random)"
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

# Copy UI source
Copy-Item -Path "$Root\ui\*" -Destination $stagingDir -Recurse -Force

# Copy into DWC plugins as real files
$pluginDest = Join-Path $DwcRoot "src\plugins\NeXT"
New-Item -ItemType Directory -Path $pluginDest -Force | Out-Null
Copy-Item -Path "$stagingDir\*" -Destination $pluginDest -Recurse -Force

# Stage SD files (macros)
Write-Host "[3/6] Staging SD macro files..." -ForegroundColor Yellow
$sdSys = Join-Path $stagingDir "sd\sys"
New-Item -ItemType Directory -Path "$sdSys\nxt" -Force | Out-Null

$macroDirs = @("system", "probing", "tooling", "spindle", "coolant", "utilities", "canned")
foreach ($d in $macroDirs) {
  $src = Join-Path $Root "macros\$d"
  if (Test-Path $src) {
    Copy-Item -Path "$src\*" -Destination $sdSys -Recurse -Force -Exclude "README.md",".gitkeep"
  }
}
$daemonSrc = Join-Path $Root "macros\daemon"
if (Test-Path $daemonSrc) {
  Copy-Item -Path "$daemonSrc\*" -Destination "$sdSys\nxt" -Recurse -Force -Exclude "README.md",".gitkeep"
}
$pluginsSrc = Join-Path $Root "macros\plugins"
if (Test-Path $pluginsSrc) {
  New-Item -ItemType Directory -Path "$sdSys\plugins" -Force | Out-Null
  Copy-Item -Path "$pluginsSrc\*" -Destination "$sdSys\plugins" -Recurse -Force -Exclude "README.md",".gitkeep"
}
$configSrc = Join-Path $Root "macros\nxt-config"
if (Test-Path $configSrc) {
  New-Item -ItemType Directory -Path "$sdSys\nxt\config" -Force | Out-Null
  Copy-Item -Path "$configSrc\*" -Destination "$sdSys\nxt\config" -Recurse -Force -Exclude "README.md",".gitkeep"
}

# Replace version placeholder in plugin.json
$pj = Join-Path $stagingDir "plugin.json"
if (Test-Path $pj) {
  (Get-Content $pj -Raw) -replace '%%NXT_VERSION%%', $buildVersion | Set-Content $pj -NoNewline
}
# Also in DWC staged copy
$pjDwc = Join-Path $pluginDest "plugin.json"
if (Test-Path $pjDwc) {
  (Get-Content $pjDwc -Raw) -replace '%%NXT_VERSION%%', $buildVersion | Set-Content $pjDwc -NoNewline
}
# Replace in nxt.g if present
$nxtG = Join-Path $sdSys "nxt.g"
if (Test-Path $nxtG) {
  (Get-Content $nxtG -Raw) -replace '%%NXT_VERSION%%', $buildVersion | Set-Content $nxtG -NoNewline
}

# --- Patch DWC build-plugin.js ---
Write-Host "[4/6] Patching DWC build-plugin.js for split chunks..." -ForegroundColor Yellow
$buildPluginJs = Join-Path $DwcRoot "scripts\build-plugin.js"
$buildPluginBak = "$buildPluginJs.next-bak"
Copy-Item $buildPluginJs $buildPluginBak -Force
Push-Location $Root
node "$Root\dist\patch-dwc-build-plugin-zip.cjs" $buildPluginJs
Pop-Location

# --- Run production build ---
Write-Host "[5/6] Running DWC production build (this takes ~60s)..." -ForegroundColor Yellow
try {
  Push-Location $DwcRoot
  $env:NOZIP = "1"
  # Pass plugin ID since files are already staged under src/plugins/NeXT
  # This makes build-plugin.js use the internal path (no re-copy, no module structure breakage)
  $buildLog = cmd /c "npm run build-plugin NeXT 2>&1"
  $buildLog | ForEach-Object { Write-Host "  $_" }
  Pop-Location
} catch {
  Write-Host "  Build warning (may be non-fatal): $_" -ForegroundColor Yellow
  Pop-Location
} finally {
  # Restore original build-plugin.js
  if (Test-Path $buildPluginBak) {
    Move-Item $buildPluginBak $buildPluginJs -Force
  }
}


# --- Merge SD files into ZIP ---
Write-Host "[6/6] Merging SD files into plugin ZIP..." -ForegroundColor Yellow
$dwcDistZip = Join-Path $DwcRoot "dist\$outZip"
if (-not (Test-Path $dwcDistZip)) {
  # Try to find any NeXT zip in DWC dist
  $found = Get-ChildItem (Join-Path $DwcRoot "dist") -Filter "NeXT*.zip" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($found) {
    $dwcDistZip = $found.FullName
    Write-Host "  Found ZIP: $($found.Name)"
  } else {
    Write-Error "No plugin ZIP found in $DwcRoot\dist\"
  }
}

$env:DWC_REPO_PATH = $DwcRoot
node "$Root\dist\merge-sd-into-plugin-zip.cjs" $dwcDistZip $stagingDir

# --- Copy output ---
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
Copy-Item $dwcDistZip (Join-Path $OutDir $outZip) -Force

# --- Cleanup ---
Remove-Item $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
# Remove the staged plugin tree from DWC
if (Test-Path $pluginDest) {
  Remove-Item $pluginDest -Recurse -Force
}

# --- Restore junction for dev ---
Write-Host ""
Write-Host "Restoring dev junction..." -ForegroundColor Yellow
cmd /c mklink /J "$pluginDest" "$Root\ui" 2>&1 | Out-Null
Write-Host "  Junction: $pluginDest -> $Root\ui"

$finalZip = Join-Path $OutDir $outZip
Write-Host ""
Write-Host "=== BUILD COMPLETE ===" -ForegroundColor Green
Write-Host "  Plugin ZIP: $finalZip" -ForegroundColor Green
Write-Host "  Size: $([math]::Round((Get-Item $finalZip).Length / 1KB)) KB" -ForegroundColor Green
Write-Host ""
Write-Host "To install:" -ForegroundColor Cyan
Write-Host "  1. Open DWC on your machine"
Write-Host "  2. Settings -> Plugins -> Install Plugin"
Write-Host "  3. Select: $outZip"
