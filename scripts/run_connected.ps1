[CmdletBinding()]
param(
    [string]$Device,
    [string]$FlutterSdk,
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$requiredVersion = (Get-Content -LiteralPath (Join-Path $repoRoot '.flutter-version') -Raw).Trim()
if (-not $FlutterSdk) {
    $FlutterSdk = Join-Path (Split-Path -Parent $repoRoot) "ms-papigiras-app/target/toolchains/flutter-$requiredVersion"
}
$flutterCommand = Join-Path $FlutterSdk 'bin/flutter.bat'
$versionFile = Join-Path $FlutterSdk 'bin/cache/flutter.version.json'
if (-not (Test-Path -LiteralPath $flutterCommand) -or -not (Test-Path -LiteralPath $versionFile)) {
    throw "Flutter $requiredVersion is required. Pass -FlutterSdk with the path to that SDK. Expected: $FlutterSdk"
}
$sdkVersion = Get-Content -LiteralPath $versionFile -Raw | ConvertFrom-Json
if ($sdkVersion.frameworkVersion -ne $requiredVersion) {
    throw "Expected Flutter $requiredVersion; found $($sdkVersion.frameworkVersion) at $FlutterSdk."
}
$flutterCommand = (Resolve-Path -LiteralPath $flutterCommand).Path
$flutterArguments = @('run', '--dart-define=PAPIGIRAS_API_URL=https://stingray-app-9tqd9-djh6d.ondigitalocean.app')
if ($Device) {
    $flutterArguments += @('-d', $Device)
}
Write-Host "Flutter $($sdkVersion.frameworkVersion): $flutterCommand"
Write-Host "Connected app: $($flutterArguments -join ' ')"
if ($CheckOnly) { return }

Push-Location -LiteralPath $repoRoot
try {
    & $flutterCommand @flutterArguments
    $flutterExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $flutterExitCode
