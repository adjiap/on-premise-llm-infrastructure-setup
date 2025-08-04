# Set bash to exit on first error and show commands
set -e
set -x
source .env  # Update the .env.example to fit your needs


echo "=== Ollama Team Setup ==="
echo "Starting setup at $(date)"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Working directory: $SCRIPT_DIR"

# Install basic tools if missing
echo "Installing basic system tools..."
sudo dnf install -y pciutils curl wget tar gzip findutils

# System checks
required_scripts=(
    "setup_ollama.sh"
    "setup_openwebui.sh"
)

for script in "${required_scripts[@]}"; do
    if [[ ! -f "./$script" ]]; then
        echo "ERROR: $script not found in current directory"
        exit 1
    fi
    
    # Make executable if not already
    if [[ ! -x "./$script" ]]; then
        sudo chmod 750 "$script"
        echo "Made $script executable"
    fi
done

if ! lspci | grep -i nvidia > /dev/null; then
    echo "ERROR: No NVIDIA GPU detected"
    exit 1    # Currently, the ollama setup utilizes NVIDIA GPU.
fi

# Check if Docker is already installed and working
if command -v docker >/dev/null 2>&1 && docker --version >/dev/null 2>&1; then
    echo "Docker already installed: $(docker --version)"
else
    echo "Installing Docker..."

    # Remove any existing Docker installation
    sudo dnf remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine -y

    # Add Docker's official repository for Rocky Linux
    sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

    # Install Docker
    sudo dnf install docker docker-compose docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

    # Start and enable Docker service
    sudo systemctl start docker
    sudo systemctl enable docker

    echo "✅ Docker installed successfully"
fi


# Add your user to docker group
if ! groups $USER | grep -q docker; then
    echo "Adding $USER to docker group..."
    sudo usermod -aG docker $USER
else
    echo "User $USER already in docker group"
fi

# Install the main driver package
sudo dnf install nvidia-driver

# Install CUDA support for NVIDIA driver
sudo dnf install nvidia-driver-cuda nvidia-driver-cuda-libs

# Install additional useful packages
sudo dnf install nvidia-settings nvidia-persistenced nvidia-container-toolkit

# Configure Docker to use NVIDIA runtime
sudo nvidia-ctk runtime configure --runtime=docker

# Restart Docker
sudo systemctl restart docker

# Refresh group membership and continue with docker group active
newgrp docker << 'EOF'

# Create a Docker network for Ollama and OpenWebUI to communicate
if ! docker network ls | grep -q ollama-network; then
    docker network create ollama-network
    echo "Created ollama-network"
else
    echo "ollama-network already exists, skipping creation"
fi

# Setup Ollama container
./setup_ollama.sh

# Download Ollama models
echo "Downloading Ollama models..."
# Download base ollama models
models=(
  "mistral:7b"
  "llama3.2:3b"
  "llama3.1:8b"
  "codellama:7b"
  "mistral:7b-instruct"
)

for model in "${models[@]}"; do
  echo "Pulling model: $model"
  docker exec ollama-container ollama pull "$model"
done

# Setup OpenWebUI container
./setup_openwebui.sh

EOF

# Validate the setup
echo "Validating setup..."

# Check if containers are running
if ! docker ps | grep -q ollama-container; then
    echo "ERROR: Ollama container is not running"
    exit 1
fi

if ! docker ps | grep -q openwebui; then
    echo "ERROR: OpenWebUI container is not running"
    exit 1
fi

# Check if at least one model is available
if ! docker exec ollama-container ollama list | grep -q ":"; then
    echo "WARNING: No models seem to be installed"
fi

# Test basic API connectivity
if ! curl -s http://$(hostname -I | awk '{print $1}'):${OPENWEBUI_PORT} >/dev/null; then
    echo "WARNING: OpenWebUI web interface may not be accessible"
else
    echo "OpenWebUI is accessible"
fi

echo "Validation complete"

echo ""
echo "=== Setup Complete! ==="
echo "Timestamp: $(date)"
echo ""
echo "Setup complete! Access OpenWebUI at http://$(hostname -I | awk '{print $1}'):${OPENWEBUI_PORT}"
