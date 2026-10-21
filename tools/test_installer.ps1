param([Parameter(Mandatory)][string]$Setup,[Parameter(Mandatory)][string]$Payload,[Parameter(Mandatory)][string]$Version,[string]$ExpectedPublisher="")
$ErrorActionPreference = 'Stop'
# Only the disposable GitHub-hosted Windows VM is allowed to run destructive QA.
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') { throw 'Installer tests require a fresh GitHub-hosted Windows VM' }
$destination = Join-Path ${env:ProgramFiles(x86)} 'Hearthtable Lite'
$data = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Godot/app_userdata/Hearthtable Lite'
$shortcut = Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'Hearthtable Lite.lnk'
if ((Test-Path -LiteralPath $destination) -or (Test-Path -LiteralPath $data) -or (Test-Path -LiteralPath $shortcut)) { throw 'QA refuses to replace any existing app or campaign' }
function Run-Installer([string]$Path,[string[]]$Arguments) {
  $process = Start-Process -FilePath $Path -ArgumentList $Arguments -PassThru
  if (-not $process.WaitForExit(120000)) { $process.Kill(); throw 'Installer timed out' }
  if ($process.ExitCode -ne 0) { throw "Installer returned $($process.ExitCode)" }
}
Run-Installer $Setup @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART')
$installed = Join-Path $destination 'Hearthtable Lite.exe'
if ((Get-FileHash -LiteralPath $installed).Hash -ne (Get-FileHash -LiteralPath $Payload).Hash) { throw 'Installed app differs from the tested player payload' }
if ($ExpectedPublisher) {
  foreach ($binary in @($installed,(Join-Path $destination 'unins000.exe'))) {
    $signature=Get-AuthenticodeSignature -LiteralPath $binary
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ne $ExpectedPublisher -or -not $signature.TimeStamperCertificate) { throw 'Installed app/uninstaller signature is not trusted' }
  }
}
foreach ($relative in @("Source/$Version/project.godot", "Source/$Version/LICENSE.txt", "Source/$Version/AGENTS.md")) {
  if (-not (Test-Path -LiteralPath (Join-Path $destination $relative))) { throw "Missing installed source: $relative" }
}
$shell = New-Object -ComObject WScript.Shell
foreach ($link in @($shortcut,(Join-Path ([Environment]::GetFolderPath('CommonPrograms')) 'Hearthtable Lite/Hearthtable Lite.lnk'))) {
  $target = $shell.CreateShortcut($link)
  if ($target.TargetPath -ne $installed -or $target.WorkingDirectory -ne $destination -or -not (Test-Path -LiteralPath $link)) { throw 'Missing or invalid desktop/Start Menu shortcut' }
}
$info = [Diagnostics.ProcessStartInfo]::new();$info.FileName=$installed;$info.WorkingDirectory=$destination;$info.UseShellExecute=$false;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
foreach ($arg in @('--headless','--script',(Join-Path $PSScriptRoot '../tests/windows_prepared_import.gd'),'--',"--version=$Version",'--bundled')) { $info.ArgumentList.Add($arg) }
$process=[Diagnostics.Process]::new();$process.StartInfo=$info
if (-not $process.Start()) { throw 'Installed Windows app failed to start' }
$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
if (-not $process.WaitForExit(180000)) { $process.Kill();throw 'Installed app test timed out' }
$text=$stdout.Result+$stderr.Result
$escaped=$text.Substring([Math]::Max(0,$text.Length-12000)).Replace('%','%25').Replace("`r",'%0D').Replace("`n",'%0A')
if ($process.ExitCode -ne 0 -or $text -match '(?m)^(SCRIPT ERROR:|ERROR:|.*FAIL )' -or $text -notmatch 'WINDOWS_IMPORT_RESULT \d+ passed, 0 failed') {
  Write-Host "::error title=Installed Windows app diagnostic::$escaped";throw 'Installed native Windows checks failed'
}
Write-Host "::notice title=Installed Windows app checks::$escaped"
# This data belongs to this disposable test. An uninstaller must preserve it.
$marker=Join-Path $data 'installer-preservation.txt';[IO.File]::WriteAllText($marker,'Synthetic installer QA marker')
Run-Installer (Join-Path $destination 'unins000.exe') @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART')
if ((Test-Path -LiteralPath $installed) -or (Test-Path -LiteralPath $shortcut)) { throw 'Uninstall left the app or desktop shortcut behind' }
if ((Get-Content -Raw -LiteralPath $marker) -ne 'Synthetic installer QA marker') { throw 'Uninstall changed user data' }
Write-Host '::notice title=Installer validation::Install to Program Files (x86), payload integrity, editable source, desktop and Start Menu shortcuts, native throne imports, uninstall and AppData preservation passed.'
