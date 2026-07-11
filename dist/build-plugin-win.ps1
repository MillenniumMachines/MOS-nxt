<#
.SYNOPSIS
  Build the nxt DWC plugin ZIP for installation on a real machine.
  PowerShell port of dist/build-plugin.sh for Windows.

.PARAMETER DwcRoot
  Path to the DuetWebControl tree (3.7 Vite preferred; 3.6 webpack still supported).
  Default: ..\DuetWebControl (sibling of this repo)

.EXAMPLE
  .\dist\build-plugin-win.ps1 -DwcRoot "C:\path\to\DuetWebControl"
#>
param(
  [string]$DwcRoot = "$PSScriptRoot\..\..\DuetWebControl"
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path "$PSScriptRoot\..").Path
$OutDir = Join-Path $Root "dist"
$DwcRoot = (Resolve-Path $DwcRoot).Path

Write-Host "=== nxt Plugin Builder (Windows) ===" -ForegroundColor Cyan
Write-Host "  MOS-nxt repo : $Root"
Write-Host "  DWC root  : $DwcRoot"

# --- Version from git ---
$gitSha = git -C $Root rev-parse --short HEAD 2>$null
if (-not $gitSha) { $gitSha = "unknown" }
$gitBranch = git -C $Root rev-parse --abbrev-ref HEAD 2>$null
if (-not $gitBranch) { $gitBranch = "dev" }
git -C $Root diff-index --quiet HEAD -- 2>$null
$dirty = if ($LASTEXITCODE -ne 0) { "-dirty" } else { "" }
$buildVersion = ("$gitBranch-$gitSha$dirty") -replace '[^A-Za-z0-9._-]', '-'
$outZip = "nxt-$buildVersion.zip"
# DWC Vite names the ZIP from plugin.json version after %%NXT_VERSION%% substitution.
$dwcPluginZip = "nxt-$buildVersion.zip"

Write-Host "  Version   : $buildVersion"
Write-Host "  Output    : dist\$outZip"
Write-Host ""

Write-Host "Checking RRF macro line lengths (max 200)..." -ForegroundColor Yellow
node (Join-Path $Root "dist\check-gcode-line-length.mjs")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$builder = (node (Join-Path $Root "dist\detect-dwc-plugin-builder.mjs") $DwcRoot).Trim()
Write-Host "  DWC builder: $builder"

# --- Cleanup ---
Write-Host "[1/5] Cleaning previous build artifacts..." -ForegroundColor Yellow
$pluginStaged = Join-Path $DwcRoot "src\plugins\nxt"
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
Get-ChildItem "$OutDir\nxt-*.zip" -ErrorAction SilentlyContinue | Remove-Item -Force

# --- Stage plugin source (external plugin dir for Vite; not under src/plugins) ---
Write-Host "[2/5] Staging plugin source..." -ForegroundColor Yellow
$stagingDir = Join-Path $env:TEMP "next-plugin-build-$(Get-Random)"
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
Copy-Item -Path "$Root\ui\*" -Destination $stagingDir -Recurse -Force

# Stage SD files (macros)
Write-Host "[3/5] Staging SD macro files..." -ForegroundColor Yellow
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
  New-Item -ItemType Directory -Path "$sdSys\nxt-config" -Force | Out-Null
  Copy-Item -Path "$configSrc\*" -Destination "$sdSys\nxt-config" -Recurse -Force -Exclude "README.md",".gitkeep"
}

$pj = Join-Path $stagingDir "plugin.json"
if (Test-Path $pj) {
  (Get-Content $pj -Raw) -replace '%%NXT_VERSION%%', $buildVersion | Set-Content $pj -NoNewline
}
$nxtG = Join-Path $sdSys "nxt.g"
if (Test-Path $nxtG) {
  (Get-Content $nxtG -Raw) -replace '%%NXT_VERSION%%', $buildVersion | Set-Content $nxtG -NoNewline
}

node (Join-Path $Root "dist\generate-nxt-config-manifest.mjs") $Root

# Webpack-only: patch chunk filter. Vite: no-op.
$buildPluginJs = Join-Path $DwcRoot "scripts\build-plugin.js"
$buildPluginBak = "$buildPluginJs.next-bak"
if ($builder -eq "webpack") {
  Write-Host "[4/5] Patching DWC webpack build-plugin.js..." -ForegroundColor Yellow
  Copy-Item $buildPluginJs $buildPluginBak -Force
  node "$Root\dist\patch-dwc-build-plugin-zip.cjs" $buildPluginJs
} else {
  Write-Host "[4/5] DWC Vite builder — skipping webpack patch" -ForegroundColor Yellow
}

Write-Host "[5/5] Running DWC build-plugin..." -ForegroundColor Yellow
try {
  Push-Location $DwcRoot
  if (-not (Test-Path "node_modules")) {
    npm ci
  }
  if ($builder -eq "webpack") {
    npm install three@0.181.0
  }
  npm run build-plugin -- $stagingDir
  if ($LASTEXITCODE -ne 0) { throw "npm run build-plugin failed ($LASTEXITCODE)" }
  Pop-Location
} catch {
  Pop-Location -ErrorAction SilentlyContinue
  if (Test-Path $buildPluginBak) {
    Move-Item $buildPluginBak $buildPluginJs -Force
  }
  throw
} finally {
  if (Test-Path $buildPluginBak) {
    Move-Item $buildPluginBak $buildPluginJs -Force
  }
}

# Vite: ZIP next to staging; webpack: under DuetWebControl/dist/
$builtZip = Join-Path $stagingDir $dwcPluginZip
if (-not (Test-Path $builtZip)) {
  $builtZip = Join-Path $DwcRoot "dist\$dwcPluginZip"
}
if (-not (Test-Path $builtZip)) {
  $found = @(
    Get-ChildItem $stagingDir -Filter "nxt*.zip" -ErrorAction SilentlyContinue
    Get-ChildItem (Join-Path $DwcRoot "dist") -Filter "nxt*.zip" -ErrorAction SilentlyContinue
  ) | Select-Object -First 1
  if ($found) {
    $builtZip = $found.FullName
    Write-Host "  Using unexpected ZIP name: $($found.Name)" -ForegroundColor Yellow
  } else {
    Write-Error "No plugin ZIP found in staging or $DwcRoot\dist\"
  }
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$workZip = Join-Path $OutDir $outZip
Copy-Item $builtZip $workZip -Force

$env:DWC_REPO_PATH = $DwcRoot
node "$Root\dist\merge-sd-into-plugin-zip.cjs" $workZip $stagingDir
node "$Root\dist\inject-plugin-dwcfiles.cjs" $workZip
node "$Root\dist\verify-plugin-zip.mjs" $workZip

Remove-Item $stagingDir -Recurse -Force -ErrorAction SilentlyContinue

# Restore junction for Vite/webpack in-tree dev when imports.ts or symlink workflow is used
Write-Host ""
Write-Host "Restoring dev junction..." -ForegroundColor Yellow
$pluginDest = Join-Path $DwcRoot "src\plugins\nxt"
if (-not (Test-Path $pluginDest)) {
  cmd /c mklink /J "$pluginDest" "$Root\ui" 2>&1 | Out-Null
  Write-Host "  Junction: $pluginDest -> $Root\ui"
}
$importsTs = Join-Path $DwcRoot "src\plugins\imports.ts"
if (Test-Path $importsTs) {
  node "$Root\dist\regenerate-dwc-plugin-imports.cjs" $DwcRoot
}

Write-Host ""
Write-Host "=== BUILD COMPLETE ===" -ForegroundColor Green
Write-Host "  Plugin ZIP: $workZip" -ForegroundColor Green
Write-Host "  Size: $([math]::Round((Get-Item $workZip).Length / 1KB)) KB" -ForegroundColor Green
Write-Host ""
Write-Host "To install:" -ForegroundColor Cyan
Write-Host "  1. Open DWC on your machine"
Write-Host "  2. Settings -> Plugins -> Install Plugin"
Write-Host "  3. Select: $outZip"
