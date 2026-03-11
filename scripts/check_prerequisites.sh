#!/usr/bin/env bash
# scripts/check_prerequisites.sh
# Pre-flight checks before running the compose stack.
# Non-destructive: only checks, plus copying .env from .env.example if missing.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_DIR="$(dirname "$SCRIPT_DIR")/docker-small-team-setup"

ERRORS=0

log_ok()    { echo "✅ $1"; }
log_warn()  { echo "⚠️  $1"; }
log_error() { echo "❌ $1"; ERRORS=$((ERRORS + 1)); }

echo "=== Pre-flight Checks ==="
echo ""

# ------------------------------------------------------------------------------
# 1. Container runtime
# ------------------------------------------------------------------------------
if command -v podman &> /dev/null; then
  RUNTIME="podman"
elif command -v docker &> /dev/null; then
  RUNTIME="docker"
else
  log_error "No container runtime found. Install Docker or Podman."
  exit 1
fi
log_ok "Container runtime: $RUNTIME"

# ------------------------------------------------------------------------------
# 2. Daemon is running
# ------------------------------------------------------------------------------
if ! $RUNTIME info &> /dev/null; then
  log_error "$RUNTIME daemon is not running. Start it before proceeding."
  exit 1
fi
log_ok "$RUNTIME daemon is running"

# ------------------------------------------------------------------------------
# 3. Compose plugin is available
# ------------------------------------------------------------------------------
if $RUNTIME compose version &> /dev/null 2>&1; then
  log_ok "Compose plugin: $RUNTIME compose"
else
  log_error "No compose plugin found for $RUNTIME. Install the compose plugin."
  exit 1
fi

# ------------------------------------------------------------------------------
# 4. .env file
# ------------------------------------------------------------------------------
ENV_FILE="$SETUP_DIR/.env"
ENV_EXAMPLE="$SETUP_DIR/.env.example"

if [ -f "$ENV_FILE" ]; then
  log_ok ".env file exists"
else
  log_warn ".env not found"
  if [ -f "$ENV_EXAMPLE" ]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    log_ok "Copied .env.example → .env. Review and edit before proceeding."
  else
    log_error ".env.example not found either. Cannot proceed without .env."
  fi
fi

# ------------------------------------------------------------------------------
# 5. GPU checks (only if nvidia-smi is present)
# ------------------------------------------------------------------------------
if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null 2>&1; then
  log_ok "nvidia-smi found and functional"

  # Podman: check device nodes
  if [ "$RUNTIME" = "podman" ]; then
    for dev in /dev/nvidia0 /dev/nvidiactl /dev/nvidia-uvm /dev/nvidia-modeset; do
      if [ -e "$dev" ]; then
        log_ok "Device node exists: $dev"
      else
        log_warn "Device node missing: $dev (Podman GPU passthrough may fail)"
      fi
    done
  fi

  # Docker: check NVIDIA container toolkit
  if [ "$RUNTIME" = "docker" ]; then
    if docker info 2>/dev/null | grep -q "nvidia"; then
      log_ok "NVIDIA container runtime configured for Docker"
    else
      log_warn "NVIDIA container runtime not detected in Docker. Run: nvidia-ctk runtime configure --runtime=docker"
    fi
  fi
else
  log_warn "nvidia-smi not found or not functional — will use CPU profile"
fi

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
echo ""
if [ "$ERRORS" -gt 0 ]; then
  echo "❌ $ERRORS error(s) found. Resolve the above before running compose."
  exit 1
else
  echo "✅ All checks passed."
fi
