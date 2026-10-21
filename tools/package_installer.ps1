param([Parameter(Mandatory)][string]$Build, [switch]$Validate)
$ErrorActionPreference = 'Stop'
$Build = (Resolve-Path -LiteralPath $Build).Path
$manifest = Get-Content -Raw -LiteralPath (Join-Path $Build 'build-manifest.json') | ConvertFrom-Json
$version = $manifest.version
if ($version -notmatch '^\d+\.\d+\.\d+$' -or $manifest.edition -ne 'lite' -or $manifest.dirty) { throw 'Expected a clean Lite build manifest' }
$program = Join-Path $Build 'Hearthtable_Lite_Portable.exe'
$programHash = (Get-FileHash -LiteralPath $program -Algorithm SHA256).Hash.ToLowerInvariant()
if ($programHash -ne $manifest.sha256) { throw 'Player payload does not match build manifest' }
$sourceArchive = Join-Path $Build 'Hearthtable-Lite-Source.zip'
if ((Get-FileHash -LiteralPath $sourceArchive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.source_sha256) { throw 'Source archive does not match build manifest' }
. (Join-Path $PSScriptRoot 'windows_signing.ps1')
$signing=Start-HearthSigning
try {
Sign-HearthBinary $signing $program
$manifest.sha256=(Get-FileHash -LiteralPath $program -Algorithm SHA256).Hash.ToLowerInvariant()
$stage = Join-Path $Build 'installer-stage'
New-Item -ItemType Directory -Path $stage | Out-Null
Copy-Item -LiteralPath $program -Destination $stage
$source = Join-Path $stage "Source/$version"
Expand-Archive -LiteralPath $sourceArchive -DestinationPath $source
if (-not (Test-Path -LiteralPath (Join-Path $source 'project.godot'))) { throw 'Missing editable source' }
foreach ($private in @('.git','.godot','builds','test-results')) {
  if (Test-Path -LiteralPath (Join-Path $source $private)) { throw "Unexpected generated/private source directory: $private" }
}
$compiler = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6/ISCC.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'Inno Setup 6 is required (https://jrsoftware.org/isdl.php)' }
$signArgs=@()
if ($signing) {
  $command='$q'+$signing.compiler+'$q sign /sha1 '+$signing.thumbprint+' /fd SHA256 /tr https://timestamp.digicert.com /td SHA256 $f'
  $signArgs=@('/DSigningEnabled=1',('/Shearthsign='+$command))
}
& $compiler @signArgs "/DProductVersion=$version" "/DPayloadDir=$stage" "/DOutputDir=$Build" (Join-Path $PSScriptRoot 'installer/hearthtable-lite.iss')
if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed' }
$setup = Join-Path $Build "Hearthtable-Lite-$version-Setup.exe"
Sign-HearthBinary $signing $setup
if ($Validate) { & (Join-Path $PSScriptRoot 'test_installer.ps1') -Setup $setup -Payload $program -Version $version -ExpectedPublisher $(if ($signing) { $signing.thumbprint } else { "" }) }
$notesPath=Join-Path $Build 'RELEASE_NOTES.md'
$notes=Get-Content -Raw -LiteralPath $notesPath
$notes=$notes.Replace($programHash,$manifest.sha256)
if ($signing) { $notes=$notes.Replace('The application is unsigned.','The application, installer and uninstaller have trusted timestamped Authenticode signatures.') }
Set-Content -LiteralPath $notesPath -Value $notes -Encoding utf8
$zipStage = Join-Path $Build 'download'
New-Item -ItemType Directory -Path $zipStage | Out-Null
Copy-Item -LiteralPath $setup -Destination $zipStage
@"
Hearthtable Lite $version — Windows x64

Extract this ZIP, then run Hearthtable-Lite-$version-Setup.exe.
Accept Windows' administrator prompt to install in:
C:\Program Files (x86)\Hearthtable Lite
A desktop shortcut and Start menu entry are created automatically.

Editable source and license notices are in the Source\$version subfolder.
Copy that source to a writable development folder before editing it.
Campaigns, imported maps, Settings updates and backups stay in your Windows
AppData\Roaming\Godot\app_userdata\Hearthtable Lite folder.
Uninstalling the app keeps that data. Keep private campaign backups separately.

Windows validates the publisher when this build has a trusted signature.
Unsigned builds show Unknown publisher. SmartScreen can warn about new downloads.
Use this project's GitHub Releases downloads and check SHA256SUMS.txt.
Source commit: $($manifest.commit)
"@ | Set-Content -LiteralPath (Join-Path $zipStage 'READ-ME.txt') -Encoding utf8
$zip = Join-Path $Build "Hearthtable-Lite-$version-Windows.zip"
Compress-Archive -Path (Join-Path $zipStage '*') -DestinationPath $zip -CompressionLevel Optimal
$manifest | Add-Member -NotePropertyName installer -NotePropertyValue @{
 filename = [IO.Path]::GetFileName($zip)
 sha256 = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
 setup_sha256 = (Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash.ToLowerInvariant()
 native_installer_test = [bool]$Validate
 signed = [bool]$signing
}
$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $Build 'build-manifest.json') -Encoding utf8
$update = Join-Path $Build $manifest.update.filename
if ((Get-FileHash -LiteralPath $update -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.update.sha256) { throw 'Update payload mismatch' }
@("$($manifest.installer.sha256)  $([IO.Path]::GetFileName($zip))", "$($manifest.update.sha256)  $([IO.Path]::GetFileName($update))") | Set-Content -LiteralPath (Join-Path $Build 'SHA256SUMS.txt') -Encoding ascii
Write-Host "::notice title=Installer packaged::$([IO.Path]::GetFileName($zip)) · $((Get-Item -LiteralPath $zip).Length) bytes · SHA256 $($manifest.installer.sha256)"

} finally { Stop-HearthSigning $signing }
