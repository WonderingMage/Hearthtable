# Optional Authenticode signing. Private keys are supplied through the Windows
# certificate store or GitHub Secrets, never through repository files or chat.
function Start-HearthSigning {
  $thumbprint=$env:HEARTHTABLE_SIGNING_THUMBPRINT
  $imported=$false
  if (-not $thumbprint -and $env:HEARTHTABLE_WINDOWS_PFX_BASE64) {
    if (-not $env:RUNNER_TEMP) { throw 'PFX import requires a private runner temporary directory' }
    $pfx=Join-Path $env:RUNNER_TEMP ("hearthtable-signing-"+[Guid]::NewGuid().ToString('N')+'.pfx')
    try {
      [IO.File]::WriteAllBytes($pfx,[Convert]::FromBase64String($env:HEARTHTABLE_WINDOWS_PFX_BASE64))
      $password=ConvertTo-SecureString -String $env:HEARTHTABLE_WINDOWS_PFX_PASSWORD -AsPlainText -Force
      $certs=@(Import-PfxCertificate -FilePath $pfx -Password $password -CertStoreLocation 'Cert:\CurrentUser\My')
      $keys=@($certs | Where-Object HasPrivateKey)
      if ($keys.Count -ne 1) { throw 'Expected exactly one private code-signing certificate' }
      $thumbprint=$keys[0].Thumbprint;$imported=$true
    } finally {
      if (Test-Path -LiteralPath $pfx) { Remove-Item -LiteralPath $pfx -Force }
      $env:HEARTHTABLE_WINDOWS_PFX_BASE64=$null;$env:HEARTHTABLE_WINDOWS_PFX_PASSWORD=$null
    }
  }
  if (-not $thumbprint) {
    Write-Host '::notice title=Windows publisher::No signing identity configured. This validation build is unsigned; Windows may show Unknown publisher/SmartScreen. See docs/windows-installation.md.'
    return $null
  }
  $thumbprint=$thumbprint.Replace(' ','')
  if ($thumbprint -notmatch '^[0-9a-fA-F]{40}$') { throw 'Invalid signing certificate thumbprint' }
  $certificate=Get-Item -LiteralPath "Cert:\CurrentUser\My\$thumbprint"
  if (-not $certificate.HasPrivateKey -or $certificate.NotAfter -le (Get-Date) -or $certificate.NotBefore -gt (Get-Date)) { throw 'Code-signing certificate is unavailable or expired' }
  if ('1.3.6.1.5.5.7.3.3' -notin @($certificate.EnhancedKeyUsageList | ForEach-Object { $_.ObjectId.Value })) { throw 'Certificate must permit code signing' }
  $kits=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/bin'
  $signtool=@(Get-ChildItem -Path "$kits/*/x64/signtool.exe" | Sort-Object FullName -Descending)[0].FullName
  if (-not $signtool) { throw 'Windows SDK SignTool is required' }
  return @{ thumbprint=$thumbprint; compiler=$signtool; imported=$imported }
}
function Sign-HearthBinary($Signing,[string]$Path) {
  if (-not $Signing) { return }
  & $Signing.compiler sign /sha1 $Signing.thumbprint /fd SHA256 /tr https://timestamp.digicert.com /td SHA256 $Path
  if ($LASTEXITCODE -ne 0) { throw 'Authenticode signing failed' }
  & $Signing.compiler verify /pa /all $Path
  if ($LASTEXITCODE -ne 0) { throw 'Authenticode trust verification failed' }
  $signature=Get-AuthenticodeSignature -LiteralPath $Path
  if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ne $Signing.thumbprint -or -not $signature.TimeStamperCertificate) { throw 'Expected a trusted, timestamped signature from the configured publisher' }
}
function Stop-HearthSigning($Signing) {
  if ($Signing -and $Signing.imported) { Remove-Item -LiteralPath "Cert:\CurrentUser\My\$($Signing.thumbprint)" -Force }
}
