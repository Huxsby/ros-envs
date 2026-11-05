# Creates a WSL distro with a ROS environment: ROS-Kinetic (Ubuntu 16.04), ROS-Melodic (18.04), ROS-Noetic (20.04)
# or ROS-Jazzy (24.04).
# Usage, in PowerShell:
#   .\install.ps1 -Distro kinetic|melodic|noetic|jazzy -User <linux user> [-TimeZone Area/City] [-Location C:\WSL] [-Ref v1.0.2]
# It downloads what it needs to a temporary folder and deletes it at the end.
param(
    [Parameter(Mandatory)][ValidateSet('kinetic', 'melodic', 'noetic', 'jazzy')][string]$Distro,
    [Parameter(Mandatory)][ValidatePattern('^[a-z_][a-z0-9_-]*$')][string]$User,
    [ValidatePattern('^[A-Za-z0-9_+/-]+$')][string]$TimeZone = 'Etc/UTC',
    [string]$Location = (Join-Path $env:USERPROFILE 'WSL'),
    [string]$Ref = 'v1.0.2',
    # Without a password prompt, for unattended runs such as CI
    [switch]$NoPassword
)
$ErrorActionPreference = 'Stop'

$Name = "ROS-$((Get-Culture).TextInfo.ToTitleCase($Distro))"
$Installer = "https://raw.githubusercontent.com/Huxsby/ros-envs/$Ref/install.sh"
$Images = @{
    # 16.04, 18.04 and 20.04 no longer appear in wsl --install, but Canonical's official appx can still be downloaded
    # (the first two are the targets of aka.ms/wsl-ubuntu-1604 and aka.ms/wsl-ubuntu-1804)
    kinetic = 'https://wslstorestorage.blob.core.windows.net/wslblob/Ubuntu_1604.2019.523.0_x64.appx'
    melodic = 'https://wslstorestorage.blob.core.windows.net/wslblob/Ubuntu_1804.2019.522.0_x64.appx'
    noetic  = 'https://publicwsldistros.blob.core.windows.net/wsldistrostorage/Ubuntu2004-230608_x64.appx'
    jazzy   = 'https://releases.ubuntu.com/24.04.5/ubuntu-24.04.5-wsl-amd64.wsl'
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
    # the appx images are zip files with the root file system inside; the 24.04 .wsl is the file system itself
    if ($Distro -ne 'jazzy') {
        & tar.exe -xf $Image -C $Temporary install.tar.gz
        if ($LASTEXITCODE -ne 0) { throw 'install.tar.gz could not be extracted from the appx' }
        $Image = Join-Path $Temporary 'install.tar.gz'
    }

    Write-Host "== Importing $Name into $Location"
    $Target = Join-Path $Location $Name
    New-Item -ItemType Directory -Force -Path $Target | Out-Null
    # wsl prints its own success message in the language of Windows: left out, the script reports each step
    Invoke-Wsl --import $Name $Target $Image --version 2 | Out-Null

    # The 16.04 and 18.04 images date from 2019: their root certificates may not validate GitHub, where the installer
    # comes from, until updated
    Write-Host '== Updating curl and the root certificates of the image'
    Invoke-Wsl -d $Name -u root -- bash -c 'apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl ca-certificates >/dev/null'

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
