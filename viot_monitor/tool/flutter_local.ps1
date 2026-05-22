$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$localAppData = Join-Path $repoRoot '.codex_appdata'
$dartToolDir = Join-Path $localAppData '.dart-tool'

New-Item -ItemType Directory -Force -Path $dartToolDir | Out-Null
$env:APPDATA = $localAppData

& 'C:\devapp\flutter\bin\flutter.bat' @args
exit $LASTEXITCODE
