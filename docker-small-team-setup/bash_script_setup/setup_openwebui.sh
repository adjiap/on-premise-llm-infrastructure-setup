
# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Detecting GPU capabilities..."

# Check for NVIDIA GPU
if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
    echo "NVIDIA GPU detected. Setting up CUDA version"
    GPU_ARGS="--gpus all"
    REPO_TAG="cuda"
else
    echo "No NVIDIA GPU detected. Setting up CPU version"
    GPU_ARGS=""
    REPO_TAG="main"
fi

# update the .env.example, and expand it
docker run -d \
  ${GPU_ARGS} \
  --name openwebui \
  --network ollama-network \
  -p ${OPENWEBUI_PORT}:8080 \
  --env-file "${SCRIPT_DIR}/../.env" \
  -v openwebui_data:/app/backend/data \
  --restart unless-stopped \
  ghcr.io/open-webui/open-webui:$REPO_TAG
