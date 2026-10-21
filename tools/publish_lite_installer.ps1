param([Parameter(Mandatory)][string]$Build,[Parameter(Mandatory)][string]$Tag,[Parameter(Mandatory)][string]$Repository)
$ErrorActionPreference='Stop'
$manifest=Get-Content -Raw -LiteralPath (Join-Path $Build 'build-manifest.json') | ConvertFrom-Json
if ($manifest.validation -or $manifest.tag -ne $Tag -or $Tag -ne "lite-v$($manifest.version)" -or -not $manifest.installer.native_installer_test) { throw 'Only a tagged build with successful native installer validation may publish' }
$allowed=@($manifest.installer.filename,$manifest.update.filename,'SHA256SUMS.txt','build-manifest.json')
$releases=gh api "repos/$Repository/releases?per_page=100" | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect releases' }
$existing=@($releases | Where-Object tag_name -eq $Tag)
if ($existing.Count -gt 1 -or ($existing.Count -eq 1 -and -not $existing[0].draft)) { throw 'Never replace a published release' }
if ($existing.Count -eq 1) {
  foreach ($asset in $existing[0].assets) { if ($asset.name -notin $allowed) { throw 'Unexpected draft asset' } }
  gh release edit $Tag --repo $Repository --prerelease --notes-file (Join-Path $Build 'RELEASE_NOTES.md')
} else {
  gh release create $Tag --repo $Repository --verify-tag --draft --prerelease --title "Hearthtable Lite $($manifest.version)" --notes-file (Join-Path $Build 'RELEASE_NOTES.md')
}
if ($LASTEXITCODE -ne 0) { throw 'Cannot prepare release draft' }
$files=@($allowed | ForEach-Object { Join-Path $Build $_ })
gh release upload $Tag --repo $Repository @files --clobber
if ($LASTEXITCODE -ne 0) { throw 'Cannot upload assets; draft retained' }
$check=Join-Path $Build 'download-check';New-Item -ItemType Directory -Path $check | Out-Null
gh release download $Tag --repo $Repository --dir $check
if ($LASTEXITCODE -ne 0) { throw 'Cannot verify downloads; draft retained' }
$remote=@((gh api "repos/$Repository/releases?per_page=100" | ConvertFrom-Json) | Where-Object tag_name -eq $Tag)
if ($LASTEXITCODE -ne 0 -or $remote.Count -ne 1 -or -not $remote[0].draft) { throw 'Expected exactly one unpublished draft' }
foreach ($name in $allowed) {
  $hash=(Get-FileHash -LiteralPath (Join-Path $Build $name) -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($hash -ne (Get-FileHash -LiteralPath (Join-Path $check $name) -Algorithm SHA256).Hash.ToLowerInvariant()) { throw 'Downloaded checksum mismatch' }
  $asset=@($remote[0].assets | Where-Object name -eq $name)
  if ($asset.Count -ne 1 -or $asset[0].digest -ne "sha256:$hash") { throw 'GitHub digest mismatch' }
}
gh release edit $Tag --repo $Repository --draft=false --prerelease
if ($LASTEXITCODE -ne 0) { throw 'Verified draft retained; repository owner connection must finish publication' }
gh release view $Tag --repo $Repository --json url,isDraft,isPrerelease
