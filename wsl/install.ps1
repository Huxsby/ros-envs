# Creates a WSL distro with a ROS environment: ROS-Noetic (Ubuntu 20.04) or ROS-Jazzy (Ubuntu 24.04).
# Usage, in PowerShell:
#   .\install.ps1 -Distro noetic -User <linux user> [-TimeZone Area/City] [-Location C:\WSL] [-Ref v1.0.1]
# It downloads what it needs to a temporary folder and deletes it at the end.
param(
    [Parameter(Mandatory)][ValidateSet('noetic', 'jazzy')][string]$Distro,
    [Parameter(Mandatory)][ValidatePattern('^[a-z_][a-z0-9_-]*$')][string]$User,
    [ValidatePattern('^[A-Za-z0-9_+/-]+$')][string]$TimeZone = 'Etc/UTC',
    [string]$Location = (Join-Path $env:USERPROFILE 'WSL'),
    [string]$Ref = 'v1.0.1',
    # Without a password prompt, for unattended runs such as CI
    [switch]$NoPassword
)
$ErrorActionPreference = 'Stop'

$Name = "ROS-$((Get-Culture).TextInfo.ToTitleCase($Distro))"
$Installer = "https://raw.githubusercontent.com/Huxsby/ros-envs/$Ref/install.sh"
$Images = @{
    # Ubuntu-20.04 no longer appears in wsl --install, but Canonical's official appx can still be downloaded
    noetic = 'https://publicwsldistros.blob.core.windows.net/wsldistrostorage/Ubuntu2004-230608_x64.appx'
    jazzy  = 'https://releases.ubuntu.com/24.04.5/ubuntu-24.04.5-wsl-amd64.wsl'
}

function Invoke-Wsl {
    & wsl.exe @args
    if ($LASTEXITCODE -ne 0) { throw "wsl $args failed with exit code $LASTEXITCODE" }
}

# wsl --list prints UTF-16: the null characters would break the comparison
$Existing = (& wsl.exe --list --quiet) -replace "`0", '' | ForEach-Object { $_.Trim() }
if ($Existing -contains $Name) { throw "$Name already exists. To start over: wsl --unregister $Name" }

$Temporary = Join-Path ([IO.Path]::GetTempPath()) "ros-envs-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $Temporary | Out-Null
try {
    Write-Host "== Downloading the Ubuntu image of $Name"
    $Image = Join-Path $Temporary 'image'
    & curl.exe -fL -o $Image $Images[$Distro]
    if ($LASTEXITCODE -ne 0) { throw 'The Ubuntu image could not be downloaded' }
    if ($Distro -eq 'noetic') {
        & tar.exe -xf $Image -C $Temporary install.tar.gz
        if ($LASTEXITCODE -ne 0) { throw 'install.tar.gz could not be extracted from the appx' }
        $Image = Join-Path $Temporary 'install.tar.gz'
    }

    Write-Host "== Importing $Name into $Location"
    $Target = Join-Path $Location $Name
    New-Item -ItemType Directory -Force -Path $Target | Out-Null
    # wsl prints its own success message in the language of Windows: left out, the script reports each step
    Invoke-Wsl --import $Name $Target $Image --version 2 | Out-Null

    Write-Host '== Root step: user, repositories and packages'
    # Set in the environment so that it applies to whatever ref the installer was pinned to
    Invoke-Wsl -d $Name -u root -- bash -c "curl -fsSL $Installer | ROS_ENVS_REF=$Ref bash -s -- root $Distro $User $TimeZone"
    Invoke-Wsl --terminate $Name | Out-Null
    if (-not $NoPassword) {
        Write-Host "== Password for sudo ($User)"
        Invoke-Wsl -d $Name -u root passwd $User
    }

    Write-Host '== User step: .bashrc, machine detection and workspace'
    Invoke-Wsl -d $Name -- bash -c "curl -fsSL $Installer | ROS_ENVS_REF=$Ref bash -s -- user $Distro"
    Write-Host "== $Name is ready"
    Write-Host "   Enter it:            wsl -d $Name"
    Write-Host "   Then check it with:  git clone https://github.com/Huxsby/ros-envs.git && bash ros-envs/ros/$Distro/smoke-test.sh"
}
finally {
    Remove-Item -Recurse -Force $Temporary -ErrorAction SilentlyContinue
}
