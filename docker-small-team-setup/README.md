# Local LLM Infrastructure Setup (Small Team)

> [!CAUTION]
> This setup provides **shared access** to models and data. All users share the same Ollama instance

> [!TIP]
> Link to main [README.md](../README.md)

<!-- TABLE OF CONTENTS -->
## Table of Contents
<ol>
  <li>
    <a href="#about-the-setup">About The Setup</a>
  </li>
  <li>
    <a href="#getting-started">Getting Started</a>
    <ul>
      <li><a href="#quick-start-guide">Quick Start Guide</a>
        <ol>
          <li><a href="#common-operations">Common Operations</a></li>
          <li><a href="#troubleshooting">Troubleshooting</a></li>
        </ol>
      </li>
      <li><a href="#requirements-based-on-my-own-experience">Requirements (based on my own experience)</a></li>
      <li><a href="#installation">Installation</a>
      <ul>
          <li><a href="#setting-up-dependencies">Setting Up Dependencies</a>
            <ul>
              <li><a href="#setting-up-docker">Setting Up Docker</a></li>
              <li><a href="#setting-up-nvidia-drivers">Setting Up NVIDIA Drivers</a></li>
            </ul>
          </li>
          <li><a href="#setting-up-dockerized-components">Setting Up Dockerized Components</a>
            <ul>
              <li><a href="#setting-up-ollama-container">Setting Up Ollama Container</a></li>
              <li><a href="#setting-up-openwebui-container">Setting Up OpenWebUI Container</a></li>
            </ul>
          </li>
        </ul>
      </li>
    </ul>
  </li>
  <li>
    <a href="#usage">Usage</a>
    <ul>
      <li><a href="#user-access">User Access</a></li>
      <li><a href="#developer-access">Developer Access</a></li>
      <li><a href="#sysadmin-access">SysAdmin Access</a></li>
      <li><a href="#monitoring-setup">Monitoring Setup</a>
        <ul>
          <li><a href="#lgtm-stack-overview">LGTM Stack Overview</a></li>
          <li><a href="#monitoring-installation">Monitoring Installation</a></li>
          <li><a href="#monitoring-access">Monitoring Access</a></li>
        </ul>
      </li>
    </ul>
  </li>
</ol>

<!-- ABOUT THE SETUP -->
## About The Setup

> [!TIP]
> As a rule of thumb, if you're a team of *3-10* people, you're a small enough team to use this setup.

The small team setup should be followed when you need to work together within a team, and have the following requirements:

* Team is not allowed to use any commercially available LLM (e.g. Claude.AI, OpenAI ChatGPT, etc.)
* Team is allowed to have shared model access
* Team is allowed to have shared data access
* Team has access to a shared server with powerful CPU/GPUs
* No need to have an extremely strict "Need to know" role-based access control
* Trust-based collaboration environment

If you fulfill the requirements above, then run the small team setup. Otherwise, refer to the [Enterprise Setup](./docker-enterprise-setup/README.md)

> [!NOTE]
> Although the OS in example is [Rocky Linux](https://rockylinux.org/), it should generally be implementable in all Linux/Unix based environment.


<!-- GETTING STARTED -->
## Getting Started

> [!TIP]
> It is assumed that the **Sys Admin** will be provisioning the infrastructure in Quick Start or Installation below

### Quick Start Guide

Run the following commands in the shell of the LLM machine.

```sh
# Clone the repository and navigate to small team setup
git clone <repository-url>
cd docker-small-team-setup

# Copy and configure environment file
cp .env.example .env
nano .env # Edit configuration as needed

# Run Installation with Docker Compose (Recommended)
docker compose up -d
# FYI: no monitoring is set up here, if you want it, you need to run:
# docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d

# OR for learning purposes - manual setup with bash scripts
cd bash_script_setup
chmod +x setup_script.sh
./setup_script.sh
```

#### Common operations

```sh
# All compose operations are to be run in the `docker-small-team-setup` folder, so the `docker compose` is correctly running.

# Check container status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# View logs
docker logs ollama-container
docker logs openwebui

# Restart only LLM services (from main compose file)
docker compose restart

# Restart only monitoring services  
docker compose -f docker-compose.monitoring.yml restart

# Pull additional models
docker exec ollama-container ollama pull llama3.1:8b

# Check GPU usage
nvidia-smi

# Clean up everything
docker compose down
# OR if using bash scripts:
./cleanup.sh

# Monitoring operations
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml ps
docker compose -f docker-compose.monitoring.yml logs grafana

# Access monitoring dashboards
curl http://localhost:3001  # Grafana
curl http://localhost:9090  # Prometheus

# Clean up monitoring stack
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml down
```

#### Troubleshooting

```sh
# If models fail to download, check GPU memory: 
nvidia-smi

# If OpenWebUI won't start, check port conflicts:
netstat -tulpn | grep 3000

# For permission issues, ensure your user is in docker group:
groups $USER

# Check container resource usage:
docker stats

# Test Ollama API connectivity:
curl http://localhost:11434/api/tags

# Check OpenWebUI connectivity:
curl http://localhost:3000

# Verify Docker + NVIDIA integration:
docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu20.04 nvidia-smi

# Check monitoring stack health
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml ps

# Verify OpenTelemetry connectivity
curl http://localhost:4318/v1/metrics

# Check Grafana data sources
curl --user "admin:admin" http://localhost:3001/api/datasources

# Monitor resource usage across all containers
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

### Requirements (based on my own experience)

> [!NOTE]
> This is **not** necessarily a minimum requirement for the setup, because originally we can also install both Ollama and OpenWebUI in regular laptops as well.
> However, it **IS** a minimum requirement for multiple users.

**Minimum Requirements for Small Team Setup:**

* **CPU**: 4+ cores (Intel i7-8700 or equivalent)
* **Memory**: 16GB+ RAM (8GB minimum)
* **GPU**: 1x NVIDIA RTX 2080 Ti or equivalent (11GB VRAM minimum)
* **Storage**: 500GB+ SSD for models and data
* **Network**: Stable internet for initial model downloads

```sh
{
echo "=== SYSTEM OVERVIEW ==="
hostnamectl
echo -e "\n=== CPU INFO ==="
lscpu | grep -E "(Model name|Socket|Core|Thread)"
echo -e "\n=== MEMORY INFO ==="
free -h
echo -e "\n=== STORAGE INFO ==="
lsblk
df -h /var/lib/docker 2>/dev/null || echo "Docker not yet configured"
echo -e "\n=== NVIDIA-SMI ==="
nvidia-smi
}
```

### Installation

#### Setting Up Dependencies

##### Setting up Docker

```sh
# Remove any existing Docker installation
sudo dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine

# Add Docker's official repository for Rocky Linux
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install Docker with compose plugin
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to docker group
sudo usermod -aG docker $USER

# Note: You may need to log out and back in for group changes to take effect
```

##### Setting up NVIDIA Drivers

```sh
# Install the main driver package
sudo dnf install -y nvidia-driver

# Install CUDA support for NVIDIA driver
sudo dnf install -y nvidia-driver-cuda nvidia-driver-cuda-libs

# Install additional useful packages
sudo dnf install -y nvidia-settings nvidia-persistenced nvidia-container-toolkit

# Configure Docker to use NVIDIA runtime
sudo nvidia-ctk runtime configure --runtime=docker

# Restart Docker
sudo systemctl restart docker

# Verify NVIDIA + Docker integration
docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu20.04 nvidia-smi
```

#### Setting up Dockerized Components

##### Setting up Ollama container

> [!NOTE]
> The `docker run` bash script is considered to be deprecated, but it's kept in `bash_script_setup` as example setup

**Using Docker Compose (Recommended):**

```sh
# Start Ollama service
docker compose up -d ollama

# Wait for service to be ready
sleep 10

# Download base ollama models
models=(
  # Quick & Efficient Tasks
  "mistral:7b"
  "llama3.2:3b"
  # Higher quality output and CoT reasoning
  "llama3.1:8b"
  "deepseek-r1:8b"
  # Much higher quality CoT reasoning
  "deepseek-r1:14b"
  # Coding tasks
  "codellama:7b"
  # Fine-tuned for foreign language and following specific instructions
  "mistral:7b-instruct"
)

for model in "${models[@]}"; do
  echo "Pulling model: $model"
  docker exec ollama-container ollama pull "$model"
done
```

**Using Manual Docker Commands:**

```sh
# Create a Docker network for Ollama and OpenWebUI to communicate
docker network create ollama-network

# Create Ollama container
docker run -d \
  --gpus all \
  --name ollama-container \
  --network ollama-network \
  -v ollama_data:/root/.ollama \
  --restart unless-stopped \
  ollama/ollama:latest

# Download models (same as above)
```

> [!WARNING]
> For SysAdmins, In the future, do not manage AI models by accessing the `ollama-container` directly. Use the Admin Panel in OpenWebUI instead for better model lifecycle management.

##### Setting up OpenWebUI container

> [!NOTE]
> The `docker run` bash script is considered to be deprecated, but it's kept in `bash_script_setup` as example setup

**Using Docker Compose (Recommended):**
```sh
# Start OpenWebUI service
docker compose up -d openwebui

# Check if it's accessible
curl -s http://localhost:3000 >/dev/null && echo "✅ OpenWebUI is accessible" || echo "❌ OpenWebUI not accessible"
```

**Using Manual Docker Commands:**

```sh
# Create OpenWebUI container
docker run -d \
  --name openwebui \
  --network ollama-network \
  -p 3000:8080 \
  --env-file .env \  # update the .env.example, and expand it
  -v openwebui_data:/app/backend/data \
  --restart unless-stopped \
  ghcr.io/open-webui/open-webui:main
```

<!-- USAGE EXAMPLES -->
## Usage

### User Access

> [!NOTE]
> This is for typical users who only care about using the GUI as a Chatbot, or for accessing Knowledge Bases that's built with [RAG](https://en.wikipedia.org/wiki/Retrieval-augmented_generation)

**Access URL**: `http://your-server:3000`

#### Accessing Models

1. **Create Account**: Navigate to the OpenWebUI interface and create an account
2. **Admin Approval**: Wait for admin approval (if `DEFAULT_USER_ROLE=pending`)
3. **Select Models**: Choose from available models in the interface:
   * `llama3.2:3b` - Fast responses for general queries
   * `llama3.1:8b` - Higher quality responses
   * `mistral:7b` - Balanced performance and quality
   * `codellama:7b` - Code-related tasks

#### Creating Knowledge Bases

1. **Upload Documents**: Use the document upload feature (PDF, DOCX, TXT supported)
2. **Create Collections**: Organize documents into knowledge bases
3. **Query with Context**: Ask questions about your uploaded documents

#### Creating Models with specific system prompt

1. **Access Model Settings**: Go to Settings → Models
2. **Create Custom Model**: Set up custom system prompts
3. **Save Configuration**: Make the custom model available to team

### Developer Access

> [!NOTE]
> This is for power users who require the LLM for their development needs (e.g. Coding Assistant)

> [!TIP]
> Please refer to the other projects for APIs:
>
> * [Local Ollama PowerShell Wrapper API](https://github.com/adjiap/local-ollama-powershell-wrapper-api)
> * [Local Ollama Python Wrapper API](https://github.com/adjiap/local-ollama-python-wrapper-api)

> [!TIP]
> Please refer to the other project [local-ollama-powershell-setup](https://github.com/adjiap/local-ollama-powershell-setup) to set things up locally.


### SysAdmin Access

> [!NOTE]
> This is for System administration, setting up users, groups, inserting new models, monitoring, etc.

As a general rule, the SysAdmin's role are the following:

* Provisioning the LLM infrastructure
* Updating LLM models and system
* Setting up accessible models
* Managing user accounts and permissions
* Monitoring system resources and performance
* Setting up knowledge bases and shared resources

**Management Commands:**

```sh
# Check system status
docker ps
docker stats

# Monitor GPU usage
nvidia-smi
watch -n 5 nvidia-smi

# View container logs
docker logs ollama-container --tail 50
docker logs openwebui --tail 50

# Backup data
docker run --rm -v openwebui_data:/data -v $(pwd):/backup alpine tar czf /backup/openwebui_backup.tar.gz /data
docker run --rm -v ollama_data:/data -v $(pwd):/backup alpine tar czf /backup/ollama_backup.tar.gz /data

# Update containers
docker compose pull
docker compose up -d

# Add new models
docker exec ollama-container ollama pull llama3.1:13b

# Clean up unused models
docker exec ollama-container ollama rm unused-model:tag
```

**Monitoring Management:**

```sh
# Monitor system performance
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml logs --tail 50

# Check monitoring stack resource usage
docker stats grafana prometheus loki tempo otel-collector

# Backup monitoring data
docker run --rm -v grafana_data:/data -v $(pwd):/backup alpine tar czf /backup/grafana_backup.tar.gz /data
docker run --rm -v prometheus_data:/data -v $(pwd):/backup alpine tar czf /backup/prometheus_backup.tar.gz /data

# Update monitoring stack
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml pull
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d
```

**Access URLs:**

* **Main Interface**: `http://your-server:3000`
* **Admin Panel**: `http://your-server:3000/admin` (admin account required)
* **Grafana Admin**: `http://your-server:3001/admin`
* **Prometheus Targets**: `http://your-server:9090/targets`
* **System Metrics**: `http://your-server:9100/metrics`

## Monitoring Setup

### LGTM Stack Overview

The monitoring setup uses the LGTM (Loki, Grafana, Tempo, Mimir/Prometheus) observability stack to provide comprehensive monitoring of your LLM infrastructure:

**Components:**

* **Prometheus** - Metrics collection and storage
* **Grafana** - Visualization dashboards and alerting
* **Loki** - Log aggregation and querying
* **Tempo** - Distributed tracing
* **OpenTelemetry Collector** - Telemetry data collection and routing
* **Node Exporter** - Host system metrics
* **cAdvisor** - Container performance metrics

**What You Can Monitor:**

* LLM response times and throughput
* GPU utilization and memory usage
* Container resource consumption
* System performance metrics
* Application logs and traces
* User interaction patterns

### Monitoring Installation

> [!NOTE]
> The `.env.example` already gives out the recommended default environment variables

```sh
# If you want to add it to an existing composed service.
docker compose -f docker-compose.monitoring.yml up -d
```

## Security & Access Control

### Shared Environment Considerations

* **Shared Models**: All users access the same model instances
* **User Isolation**: Basic user separation through OpenWebUI authentication
* **Data Privacy**: Chat histories are isolated per user account
* **Resource Sharing**: GPU and compute resources are shared among all users

### Security Features

* **Authentication Required**: `WEBUI_AUTH=True`
* **Admin Approval**: New users require admin approval
* **API Key Management**: Controlled API access
* **File Upload Restrictions**: Limited to specific file types
* **No Code Execution**: Disabled by default for security

## Troubleshooting Common Issues

### Container Issues

```sh
# Check if containers are running
if ! docker ps | grep -q ollama-container; then
    echo "ERROR: Ollama container is not running"
    docker logs ollama-container
fi

if ! docker ps | grep -q openwebui; then
    echo "ERROR: OpenWebUI container is not running"
    docker logs openwebui
fi
```

### Model Issues

```sh
# Check if at least one model is available
if ! docker exec ollama-container ollama list | grep -q ":"; then
    echo "WARNING: No models seem to be installed"
    echo "Available models:"
    docker exec ollama-container ollama list
fi
```

### Connectivity Issues

```sh
# Test basic API connectivity
if ! curl -s http://localhost:3000 >/dev/null; then
    echo "WARNING: OpenWebUI web interface may not be accessible"
    netstat -tulpn | grep 3000
else
    echo "✅ OpenWebUI is accessible"
fi

# Test Ollama API
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{"model": "llama3.2:3b", "prompt": "Hello", "stream": false}'
```

### Resource Issues

```sh
# Check GPU memory usage
nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits

# Check disk space
df -h /var/lib/docker

# Check container resource usage
docker stats --no-stream
```

### Migrating Docker Volumes

```sh
# This was useful to move the original volume created by Dockerfile into the "name-of-folder_name-of-service" volume
docker run --rm -v openwebui_data:/source -v docker-small-team-setup_openwebui_data:/destination   alpine sh -c "cp -av /source/. /destination/"
docker run --rm -v ollama_data:/source -v docker-small-team-setup_ollama_data:/destination   alpine sh -c "cp -av /source/. /destination/"
```

## Linked Projects

* [Local Ollama PowerShell Wrapper API](https://github.com/adjiap/local-ollama-powershell-wrapper-api)
* [Local Ollama Python Wrapper API](https://github.com/adjiap/local-ollama-python-wrapper-api)
* [local-ollama-powershell-setup](https://github.com/adjiap/local-ollama-powershell-setup)

## References

* [OpenWebUI Environment Configuration](https://docs.openwebui.com/getting-started/env-configuration)
* [Ollama Documentation](https://ollama.ai/docs)
* [Docker Compose Documentation](https://docs.docker.com/compose/)
* [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/overview.html)
