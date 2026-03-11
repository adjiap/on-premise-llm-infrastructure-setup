<#
.SYNOPSIS
    Detects available container compose tool.

.DESCRIPTION
    Checks for podman compose or docker compose and outputs the command to use.
    Podman is preferred over Docker if both are available.
    Output is written to stdout for capture by callers (e.g. Makefile).

.OUTPUTS
    "podman compose" or "docker compose"
#>

if (Get-Command podman -ErrorAction SilentlyContinue) {
    $composeCheck = & podman compose version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Output "podman compose"
        exit 0
    }
}

if (Get-Command docker -ErrorAction SilentlyContinue) {
    $composeCheck = & docker compose version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Output "docker compose"
        exit 0
    }
}

Write-Error "No compose tool found. Install podman-compose, podman with compose plugin, or docker compose"
exit 1
