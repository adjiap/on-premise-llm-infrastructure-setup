<#
.SYNOPSIS
    Detects available container runtime.

.DESCRIPTION
    Checks for podman or docker and outputs the binary name to use.
    Podman is preferred over Docker if both are available.
    Output is written to stdout for capture by callers (e.g. Makefile).

.OUTPUTS
    "podman" or "docker"
#>

if (Get-Command podman -ErrorAction SilentlyContinue) {
    Write-Output "podman"
} elseif (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-Output "docker"
} else {
    Write-Error "No container runtime found. Install podman or docker."
    exit 1
}
