<#
.SYNOPSIS
    Pre-flight checks before running the compose stack.

.DESCRIPTION
    Verifies that all required tools and configuration are in place before
    compose targets are run. Non-destructive except for copying .env from
    .env.example if the .env file is missing.

    Checks performed:
    - Container runtime (Docker or Podman) is installed
    - Runtime daemon is running
    - Compose plugin is available
    - .env file exists (copies from .env.example if not)
    - GPU: nvidia-smi functional (if applicable)
    - GPU + Podman: NVIDIA device nodes exist (if applicable)
    - GPU + Docker: NVIDIA container runtime configured (if applicable)

.OUTPUTS
    Colored status output to console. Exits with code 1 if any errors are found.
#>

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$SetupDir   = Join-Path (Split-Path -Parent $ScriptDir) "docker-small-team-setup"
$Errors     = 0

function Log-Ok    { param($msg) Write-Host "✅ $msg" -ForegroundColor Green }
function Log-Warn  { param($msg) Write-Host "⚠️  $msg" -ForegroundColor Yellow }
function Log-Error { param($msg) Write-Host "❌ $msg" -ForegroundColor Red; $script:Errors++ }

# ------------------------------------------------------------------------------
# 1. Container runtime
# ------------------------------------------------------------------------------
$Runtime = $null

if (Get-Command podman -ErrorAction SilentlyContinue) {
    $Runtime = "podman"
} elseif (Get-Command docker -ErrorAction SilentlyContinue) {
    $Runtime = "docker"
} else {
    Log-Error "No container runtime found. Install Docker or Podman."
    exit 1
}
Log-Ok "Container runtime: $Runtime"

# ------------------------------------------------------------------------------
# 2. Daemon is running
# ------------------------------------------------------------------------------
$daemonCheck = & $Runtime info 2>&1
if ($LASTEXITCODE -ne 0) {
    Log-Error "$Runtime daemon is not running. Start it before proceeding."
    exit 1
}
Log-Ok "$Runtime daemon is running"

# ------------------------------------------------------------------------------
# 3. Compose plugin is available
# ------------------------------------------------------------------------------
$composeCheck = & $Runtime compose version 2>&1
if ($LASTEXITCODE -eq 0) {
    Log-Ok "Compose plugin: $Runtime compose"
} else {
    Log-Error "No compose plugin found for $Runtime. Install the compose plugin."
    exit 1
}

# ------------------------------------------------------------------------------
# 4. .env file
# ------------------------------------------------------------------------------
$EnvFile    = Join-Path $SetupDir ".env"
$EnvExample = Join-Path $SetupDir ".env.example"

if (Test-Path $EnvFile) {
    Log-Ok ".env file exists"
} else {
    Log-Warn ".env not found"
    if (Test-Path $EnvExample) {
        Copy-Item $EnvExample $EnvFile
        Log-Ok "Copied .env.example -> .env. Review and edit before proceeding."
    } else {
        Log-Error ".env.example not found either. Cannot proceed without .env."
    }
}

# ------------------------------------------------------------------------------
# 5. GPU checks (only if nvidia-smi is present)
# ------------------------------------------------------------------------------
if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
    $smiCheck = & nvidia-smi 2>&1
    if ($LASTEXITCODE -eq 0) {
        Log-Ok "nvidia-smi found and functional"

        # Podman: check device nodes (WSL2 exposes these as files)
        if ($Runtime -eq "podman") {
            foreach ($dev in @("/dev/nvidia0", "/dev/nvidiactl", "/dev/nvidia-uvm", "/dev/nvidia-modeset")) {
                if (Test-Path $dev) {
                    Log-Ok "Device node exists: $dev"
                } else {
                    Log-Warn "Device node missing: $dev (Podman GPU passthrough may fail)"
                }
            }
        }

        # Docker: check NVIDIA container toolkit
        if ($Runtime -eq "docker") {
            $dockerInfo = & docker info 2>&1
            if ($dockerInfo -match "nvidia") {
                Log-Ok "NVIDIA container runtime configured for Docker"
            } else {
                Log-Warn "NVIDIA container runtime not detected in Docker. Run: nvidia-ctk runtime configure --runtime=docker"
            }
        }
    } else {
        Log-Warn "nvidia-smi not functional — will use CPU profile"
    }
} else {
    Log-Warn "nvidia-smi not found — will use CPU profile"
}

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
Write-Host ""
if ($Errors -gt 0) {
    Write-Host "❌ $Errors error(s) found. Resolve the above before running compose." -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ All checks passed." -ForegroundColor Green
}
