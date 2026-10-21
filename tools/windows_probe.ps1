param([Parameter(Mandatory)][string]$Tag, [Parameter(Mandatory)][string]$Repository)
$ErrorActionPreference = 'Stop'
$qaRoot = Join-Path $env:RUNNER_TEMP "hearthtable-native-$env:GITHUB_RUN_ID"
New-Item -ItemType Directory -Path $qaRoot | Out-Null
$expectedData = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Godot/app_userdata/Hearthtable Lite'
if (Test-Path -LiteralPath $expectedData) { throw 'Expected a fresh hosted runner with no existing Hearthtable Lite data' }
$metadata = gh api "repos/$Repository/releases/tags/$Tag" | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Release metadata unavailable' }
$asset = $metadata.assets | Where-Object name -eq 'Hearthtable_Lite_Portable.exe'
gh release download $Tag --repo $Repository --pattern Hearthtable_Lite_Portable.exe --dir $qaRoot
if ($LASTEXITCODE -ne 0) { throw 'Download failed' }
$program = Join-Path $qaRoot 'Hearthtable_Lite_Portable.exe'
$actual = (Get-FileHash -LiteralPath $program -Algorithm SHA256).Hash.ToLowerInvariant()
if ($asset.digest -ne "sha256:$actual") { throw 'Published executable digest mismatch' }
$info = [Diagnostics.ProcessStartInfo]::new()
$info.FileName = $program
$info.WorkingDirectory = $qaRoot
$info.UseShellExecute = $false
$info.RedirectStandardOutput = $true
$info.RedirectStandardError = $true
foreach ($arg in @('--headless','--script',(Join-Path $PSScriptRoot '../tests/windows_prepared_import.gd'),'--',"--version=$($Tag -replace '^lite-v','')")) { $info.ArgumentList.Add($arg) }
$process = [Diagnostics.Process]::new(); $process.StartInfo = $info
if (-not $process.Start()) { throw 'Windows EXE did not start' }
$stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
if (-not $process.WaitForExit(180000)) { $process.Kill(); throw 'Windows EXE timed out' }
$text = $stdout.Result + $stderr.Result
[IO.File]::WriteAllText((Join-Path $qaRoot 'native.log'), $text)
$escaped = $text.Substring([Math]::Max(0,$text.Length-12000)).Replace('%','%25').Replace("`r",'%0D').Replace("`n",'%0A')
if ($process.ExitCode -ne 0 -or $text -match '(?m)^(SCRIPT ERROR:|ERROR:|.*FAIL )' -or $text -notmatch 'WINDOWS_IMPORT_RESULT \d+ passed, 0 failed') {
  Write-Host "::error title=Native Windows import probe::$escaped"
  throw 'Native Windows import validation failed'
}
Write-Host "::notice title=Native Windows import probe::$escaped"
Write-Host $text
