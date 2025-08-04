# Set bash to exit on first error and show commands
set -e
set -x

echo "=== Ollama Enterprise Multi-Instance Setup ==="
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
    "setup_multi_instance.sh"
    "setup_ollama_enterprise.sh"
    "validate_multi_instance.sh"
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
    echo "Warning: No NVIDIA GPU detected"
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
sudo dnf install nvidia-driver -y

# Install CUDA support for NVIDIA driver
sudo dnf install nvidia-driver-cuda nvidia-driver-cuda-libs -y

# Install additional useful packages
sudo dnf install nvidia-settings nvidia-persistenced nvidia-container-toolkit -y

# Configure Docker to use NVIDIA runtime
sudo nvidia-ctk runtime configure --runtime=docker

# Restart Docker
sudo systemctl restart docker

# Setup Linux Infrastructure
echo "Setting up multi-instance infrastructure..."
if ! ./setup_multi_instance.sh; then
    echo "ERROR: Failed to setup multi-instance infrastructure"
    exit 1
fi

echo "Multi-instance infrastructure setup complete"

# Setup containers with docker compose
echo "Setting up containers..."
if ! ./setup_ollama_enterprise.sh; then
    echo "ERROR: Failed to setup Ollama containers"
    exit 1
fi

# Validate the setup
echo "Validating setup..."
cd "$SCRIPT_DIR"
if ! ./validate-multi-instance.sh; then
    echo "WARNING: Validation found issues, but setup may still be functional"
    echo "Check the validation output above for details"
else
    echo "All validations passed!"
fi

echo ""
echo "=== Setup Complete! ==="
echo "Timestamp: $(date)"
echo ""
echo "Access URLs will be:"
echo "- HR Department: http://$(hostname -I | awk '{print $1}'):3000"
echo "- Health Department: http://$(hostname -I | awk '{print $1}'):3001"  
echo "- Software Development: http://$(hostname -I | awk '{print $1}'):3002"
echo "- Monitoring: http://$(hostname -I | awk '{print $1}'):9090"
echo ""
echo "Management commands:"
echo "- Status: /opt/ollama-multi/scripts/manage.sh status"
echo "- Restart: /opt/ollama-multi/scripts/manage.sh restart <department>"
echo "- Backup: /opt/ollama-multi/scripts/manage.sh backup <department>"
echo ""
