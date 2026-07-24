param(
    [Parameter(Mandatory = $false)]
    [string]$DockerHubUser = "ovelayos",

    [Parameter(Mandatory = $false)]
    [string]$Repository = "pihole-wd-ex4100",

    [Parameter(Mandatory = $false)]
    [string]$PiholeTag = "2026.07.2",

    [Parameter(Mandatory = $false)]
    [string]$Revision = "r4"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,
        [Parameter(Mandatory = $false)]
        [string[]]$Arguments = @()
    )

    Write-Host "> $Command $($Arguments -join ' ')"
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE"
    }
}

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$WorkDir = Join-Path $Root ".build"
$PatchScript = Join-Path $Root "scripts\patch_source.py"
$VersionTag = "$PiholeTag-ex4100-$Revision"
$Image = "$DockerHubUser/$Repository"
$LocalImage = "$Image`:local-$Revision"

if (Test-Path $WorkDir) {
    Remove-Item -Recurse -Force $WorkDir
}

Invoke-Checked "git" @("clone", "--depth", "1", "--branch", $PiholeTag, "https://github.com/pi-hole/docker-pi-hole.git", $WorkDir)
Invoke-Checked "python" @($PatchScript, $WorkDir)

$Dockerfile = Join-Path $WorkDir "src\Dockerfile"
$Context = Join-Path $WorkDir "src"

Write-Host "Building local smoke-test image..."
Invoke-Checked "docker" @(
    "buildx", "build",
    "--platform", "linux/arm/v7",
    "--file", $Dockerfile,
    "--tag", $LocalImage,
    "--provenance=false",
    "--sbom=false",
    "--load",
    "--progress=plain",
    $Context
)

Write-Host "Running ARMv7 smoke tests..."
Invoke-Checked "docker" @("run", "--rm", "--platform", "linux/arm/v7", "--entrypoint", "/bin/sh", $LocalImage, "-c", "echo shell=ok; test `$(cat /etc/alpine-release) = 3.17.10; uname -m")
Invoke-Checked "docker" @("run", "--rm", "--platform", "linux/arm/v7", "--entrypoint", "/usr/bin/pihole-FTL", $LocalImage, "-vv")

Write-Host "Logging in to Docker Hub..."
Invoke-Checked "docker" @("login")

Write-Host "Publishing $Image..."
Invoke-Checked "docker" @(
    "buildx", "build",
    "--platform", "linux/arm/v7",
    "--file", $Dockerfile,
    "--tag", "$Image`:$VersionTag",
    "--tag", "$Image`:latest-ex4100-armv7",
    "--tag", "$Image`:legacy-armv7",
    "--provenance=false",
    "--sbom=false",
    "--push",
    "--progress=plain",
    $Context
)

Write-Host "Published:"
Write-Host "  $Image`:$VersionTag"
Write-Host "  $Image`:latest-ex4100-armv7"
Write-Host "  $Image`:legacy-armv7"
