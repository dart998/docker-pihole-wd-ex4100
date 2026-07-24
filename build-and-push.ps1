param(
    [Parameter(Mandatory = $false)]
    [string]$DockerHubUser = "ovelayos",

    [Parameter(Mandatory = $false)]
    [string]$Repository = "pihole-wd-ex4100",

    [Parameter(Mandatory = $false)]
    [string]$PiholeTag = "2026.04.1",

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

if (-not (Test-Path $Dockerfile)) {
    throw "Patched upstream Dockerfile not found: $Dockerfile"
}

$BuildArgs = @(
    "--build-arg", "PIHOLE_DOCKER_TAG=$PiholeTag",
    "--build-arg", "CORE_BRANCH=master",
    "--build-arg", "WEB_BRANCH=master",
    "--build-arg", "FTL_BRANCH=master",
    "--build-arg", "PADD_BRANCH=master"
)

Write-Host "Building local smoke-test image..."
Invoke-Checked "docker" (@(
    "buildx", "build",
    "--platform", "linux/arm/v7",
    "--file", $Dockerfile,
    "--tag", $LocalImage,
    "--provenance=false",
    "--sbom=false",
    "--load",
    "--progress=plain"
) + $BuildArgs + @($Context))

Write-Host "Running ARMv7 smoke tests..."
Invoke-Checked "docker" @("image", "inspect", $LocalImage)
Invoke-Checked "docker" @("run", "--rm", "--platform", "linux/arm/v7", "--entrypoint", "/bin/sh", $LocalImage, "-c", "set -eu; test `$(cat /etc/alpine-release) = 3.17.10; test `$(head -n 1 /usr/bin/start.sh) = '#!/bin/bash'; ! grep -RIl `$'\r' /usr/bin /usr/local/bin /opt/pihole 2>/dev/null | grep -q .")
Invoke-Checked "docker" @("run", "--rm", "--platform", "linux/arm/v7", "--entrypoint", "/usr/bin/pihole-FTL", $LocalImage, "-vv")

Write-Host "Logging in to Docker Hub..."
Invoke-Checked "docker" @("login")

Write-Host "Publishing validated image $Image..."
Invoke-Checked "docker" @("tag", $LocalImage, "$Image`:$VersionTag")
Invoke-Checked "docker" @("tag", $LocalImage, "$Image`:latest-ex4100-armv7")
Invoke-Checked "docker" @("tag", $LocalImage, "$Image`:legacy-armv7")
Invoke-Checked "docker" @("push", "$Image`:$VersionTag")
Invoke-Checked "docker" @("push", "$Image`:latest-ex4100-armv7")
Invoke-Checked "docker" @("push", "$Image`:legacy-armv7")

Write-Host "Published:"
Write-Host "  $Image`:$VersionTag"
Write-Host "  $Image`:latest-ex4100-armv7"
Write-Host "  $Image`:legacy-armv7"
