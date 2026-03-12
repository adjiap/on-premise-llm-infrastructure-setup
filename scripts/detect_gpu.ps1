<#
.SYNOPSIS
    Detects whether an NVIDIA GPU is available.

.DESCRIPTION
    Checks for nvidia-smi and outputs "gpu" if functional, "cpu" otherwise.
    Output is written to stdout for capture by callers (e.g. Makefile).

.OUTPUTS
    "gpu" or "cpu"
#>

if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
    $smiCheck = & nvidia-smi 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Output "gpu"
    } else {
        Write-Output "cpu"
    }
} else {
    Write-Output "cpu"
}
