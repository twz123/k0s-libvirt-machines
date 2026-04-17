Start-Transcript -Path "C:\Windows\Panther\UnattendGC\specialize.log"

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

foreach ($pkg in @(
    # 'E:\guest-agent\qemu-ga-x86_64.msi'
    'E:\virtio-win-gt-x64.msi'
    'F:\spice-webdavd-x64-latest.msi'
    'F:\UsbDk_1.0.22_x64.msi'
    'F:\spice-vdagent-x64-0.10.0.msi'
    'F:\PowerShell-win-x64.msi'
  )) {
  $base = [System.IO.Path]::GetFileNameWithoutExtension($pkg)
  $log = Join-Path 'C:\Windows\Panther\UnattendGC' "$base.log"
  Write-Information "Installing $pkg"

  $proc = Start-Process -Wait -PassThru -FilePath msiexec.exe -ArgumentList @('/i', $pkg, '/qn', '/norestart', '/L*v', $log)
  if ($proc.ExitCode -ne 0) {
    Write-Warning "Installation failed for $pkg with exit code $($proc.ExitCode)"
  }
}

# Install OpenSSH
try {
  $openSsh = (Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*')[0]
  $name = $openSsh.Name
  if ($openSsh.State -ne 'Installed') {
    Write-Information "Installing OpenSSH Server: $name"
    $installed = $openSsh | Add-WindowsCapability -Online
    $restartNeeded = $installed.RestartNeeded
    Write-Information "Installed OpenSSH Server (RestartNeeded: $restartNeeded)"
  }
  else {
    Write-Information "OpenSSH Server is installed: $name"
  }
  
  # Start the service
  Set-Service -Name sshd -StartupType Automatic
  Start-Service sshd

  # Open the firewall
  Set-NetFirewallRule -Name OpenSSH-Server-In-TCP -Profile Domain, Private, Public
  Enable-NetFirewallRule -Name 'OpenSSH-Server-In-TCP'

  # Register pwsh/powershell as default shell
  $pwsh = [System.IO.Path]::Combine($env:ProgramFiles, 'PowerShell', '7', 'pwsh.exe')
  if (Get-Item $pwsh -ErrorAction SilentlyContinue) {
    New-ItemProperty -Path HKLM:\SOFTWARE\OpenSSH -Name DefaultShell -PropertyType String -Value $pwsh -Force | Out-Null
  }
  elseif ($powershell = Get-Command powershell -ErrorAction SilentlyContinue) {
    New-ItemProperty -Path HKLM:\SOFTWARE\OpenSSH -Name DefaultShell -PropertyType String -Value $powershell.Path -Force | Out-Null
  }
}
catch {
  [string]$msg = $_.Exception.Message
  Write-Warning "Failed to install OpenSSH Server: $msg"
}

# Write OpenSSH administrators_authorized_keys
if (!(Test-Path -LiteralPath $env:ProgramData -PathType Container)) {
  throw "%ProgramData% is not a directory: $env:ProgramData"
}
for ($attempt = 1; $true; $attempt++) {
  $sshConfigDir = Join-Path $env:ProgramData 'ssh'
  if (Test-Path -LiteralPath $sshConfigDir -PathType Container) {
    $authorizedKeysPath = New-Item -Path (Join-Path $sshConfigDir 'administrators_authorized_keys') -ItemType File -Force
    & icacls $authorizedKeysPath /inheritance:r | Out-Null
    & icacls $authorizedKeysPath /grant 'SYSTEM:(F)' 'BUILTIN\Administrators:(F)' 'NT SERVICE\SSHD:(R)' | Out-Null
    & icacls $authorizedKeysPath /setowner "BUILTIN\Administrators" | Out-Null
    Get-Content F:\authorized_keys | Set-Content $authorizedKeysPath -Encoding ascii
    break
  }
  if ($attempt -gt 30) {
    throw "OpenSSH config directory doesn't exist: $sshConfigDir"
  }
  Start-Sleep -Seconds 1
}

try {
  Write-Information "Unpacking age"
  [IO.Compression.ZipFile]::OpenRead((Resolve-Path F:\age-v*-windows-amd64.zip).Path).Entries | ForEach-Object {
    if (-not $_.Name) { return } # skip directories
    $parts = $_.FullName -split '[\\/]' | Select-Object -Skip 1
    if ($parts.Count -ne 1) { return }
    $destPath = [System.IO.Path]::Combine($env:SystemRoot, 'system32', $parts)
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, $destPath, $true)
  }

  $adminUser = (Get-LocalUser | Where-Object { $_.SID -like "S-1-5-21-*-500" })
  if (-not $adminUser) {
    throw "Administrative account not found"
  }

  # Generate a random 18 byte password (will be 24 ASCII characters)
  $bytes = New-Object byte[] 18
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  $password = [Convert]::ToBase64String($bytes).Replace('+', '-').Replace('/', '_')

  # Store that password in an age-encrypted file.
  $password | & age -a -R F:\authorized_keys > \password.txt.age
  $password = ConvertTo-SecureString $password -AsPlainText -Force

  # Set that password as the admin password.
  Write-Information "Setting password for $adminUser"
  Set-LocalUser -Name $adminUser.Name -Password $password
}
catch {
  [string]$msg = $_.Exception.Message
  Write-Warning "Failed to generate, encrypt, store and set the password for the administrative account: $msg"
}

Write-Information 'Done'
Stop-Transcript
