# Local LLM Infrastructure Setup (Small Team)

> [!CAUTION]
> This setup provides **shared access** to models and data. All users share the same Ollama instance

> [!TIP]
> Link to main [README.md](../README.md)

<!-- TABLE OF CONTENTS -->
## Table of Contents
<ol>
  <li><a href="#about-the-setup">About The Setup</a></li>
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
      <li>
        <a href="#installation">Installation</a>
        <ul>
          <li><a href="#setting-up-dependencies">Setting Up Dependencies</a>
            <ul>
              <li><a href="#linux--podman-recommended">Linux — Podman (Recommended)</a></li>
              <li><a href="#linux--docker">Linux — Docker</a></li>
              <li><a href="#windows">Windows</a></li>
              <li><a href="#setting-up-nvidia-drivers">Setting Up NVIDIA Drivers</a></li>
            </ul>
          </li>
          <li><a href="#setting-up-dockerized-components">Setting Up Dockerized Components</a></li>
        </ul>
      </li>
    </ul>
  </li>
  <li><a href="#server-administration-setup">Server Administration Setup</a></li>
  <li>
    <a href="#usage">Usage</a>
    <ul>
      <li><a href="#user-access">User Access</a></li>
      <li><a href="#developer-access">Developer Access</a></li>
      <li><a href="#sysadmin-access">SysAdmin Access</a></li>
    </ul>
  </li>
  <li><a href="#monitoring-setup">Monitoring Setup</a></li>
  <li><a href="#security--access-control">Security & Access Control</a></li>
  <li><a href="#troubleshooting-common-issues">Troubleshooting Common Issues</a></li>
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

# Verify all prerequisites are met (also copies .env.example → .env if missing)
make check

# Edit configuration as needed
# nano .env

# Start the stack (auto-detects GPU and container runtime)
make compose

# Pull default models after first start
make model-pull-defaults

# Optional: start the monitoring stack alongside
make monitoring-up
```

#### Common operations

```sh
# Check container status
make compose-ps

# View LLM services logs
make compose-logs

# Restart LLM services
make compose-down && make compose

# Restart monitoring services
make monitoring-down && make monitoring-up

# List installed models
make model-list

# Check GPU usage
nvidia-smi

# Stop everything
make compose-down
# OR if you want to purge everything (will ask you first):
make clean

# Monitoring operations
make monitoring-ps
make monitoring-logs log=grafana

# Access monitoring dashboards
curl http://localhost:3001  # Grafana
curl http://localhost:9090  # Prometheus

# Clean up monitoring stack
make monitoring-down
```

#### Troubleshooting

```sh
# First: run pre-flight checks to diagnose most issues
make check

# If models fail to download, check GPU memory: 
nvidia-smi

# If OpenWebUI won't start, check port conflicts:
netstat -tulpn | grep ${OPENWEBUI_PORT:-3000}

# For permission issues, ensure your user is in docker group:
groups $USER

# Check container resource usage (works for both Docker and Podman)
docker stats --no-stream
# OR
podman stats --no-stream

# Test Ollama API connectivity (from inside the container — Ollama is not exposed to host)
docker exec ollama-container curl -s http://localhost:11434/api/tags
# OR
podman exec ollama-container curl -s http://localhost:11434/api/tags

# Check OpenWebUI connectivity
curl http://localhost:${OPENWEBUI_PORT:-3000}

# Verify container runtime + NVIDIA integration
docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu20.04 nvidia-smi
# OR for Podman
podman run --rm --device /dev/nvidia0 nvidia/cuda:11.8-base-ubuntu20.04 nvidia-smi

# If models are not persisting after make clean
# Ensure LOCAL_DOWNLOADED_MODELS_MOUNTED is set in .env to a host path
# e.g. LOCAL_DOWNLOADED_MODELS_MOUNTED=/opt/ollama-models

# Check monitoring stack health
make monitoring-ps

# Verify OpenTelemetry connectivity
curl http://localhost:4318/v1/metrics

# Check Grafana data sources
curl --user "admin:admin" http://localhost:${GRAFANA_PORT:-3001}/api/datasources

# Monitor resource usage across all containers
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
# OR
podman stats --format "table {{.Names}}\t{{.CPUPerc}}\t{{.MemUsage}}"
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

> [!TIP]
> For automated installation, run the following from the repository root:
>
> ```sh
> sudo bash scripts/install-host-deps.sh
> ```
>
> The script detects your distro, asks which runtime you prefer, and only installs what is missing. Manual steps are documented below for reference.

#### Setting Up Dependencies

##### Setting Up a Container Runtime

###### Linux — Podman (Recommended)
```sh
# RHEL-based (Rocky Linux, AlmaLinux, RHEL)
sudo dnf install -y podman

# Debian-based (Ubuntu, Debian)
sudo apt update && sudo apt install -y podman

# Verify installation
podman --version
podman compose version
```

###### Linux — Docker
```sh
# RHEL-based
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

# Debian-based
sudo apt update && sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

# Note: log out and back in for group changes to take effect
```

###### Windows

> [!NOTE]
> Windows is supported as a developer workstation. For production server deployments, use Linux.

Run the following in PowerShell as Administrator:

```powershell
# Install Docker Desktop (includes compose plugin)
winget install Docker.DockerDesktop

# OR install Podman Desktop
winget install RedHat.Podman
winget install RedHat.Podman-Desktop

# Verify
docker compose version
# OR
podman compose version
```

> [!TIP]
> After installing Docker Desktop or Podman Desktop, ensure the application is running before calling `make compose`.

> [!WARNING]
> Run all `make` commands from **WSL** or **Git Bash**. Native PowerShell and cmd.exe are not supported for the `make` workflow.

##### Setting Up NVIDIA Drivers

```sh
# RHEL-based
sudo dnf install -y nvidia-driver nvidia-driver-cuda nvidia-driver-cuda-libs \
    nvidia-settings nvidia-persistenced nvidia-container-toolkit

# Configure container runtime
sudo nvidia-ctk runtime configure --runtime=docker   # for Docker
sudo nvidia-ctk runtime configure --runtime=podman   # for Podman

# Debian-based
sudo apt install -y ubuntu-drivers-common
sudo ubuntu-drivers install
sudo apt install -y nvidia-container-toolkit

# Verify
nvidia-smi
```

> [!WARNING]
> A reboot is typically required after installing NVIDIA drivers for the first time.

#### Setting up Dockerized Components

> [!TIP]
> This is handled automatically by `make compose`. The manual steps below are for reference only.

##### Starting the Stack
```sh
# Navigate to the small team setup directory
cd docker-small-team-setup

# Verify prerequisites are met
make check

# Start the stack — auto-detects GPU and container runtime
make compose

# OR force a specific mode
make compose-cpu
make compose-gpu
```

##### Pulling Models
```sh
# Pull the default recommended models (defined in default-models.txt)
make model-pull-defaults

# Pull a specific model
make model-pull model=llama3.1:8b

# List currently installed models
make model-list
```

> [!NOTE]
> Models are stored in the location defined by `LOCAL_DOWNLOADED_MODELS_MOUNTED` in `.env`.
> If not set, models fall back to a named Docker/Podman volume and will be lost on `make clean`.
> It is strongly recommended to set this to a persistent host path, e.g.:
> ```sh
> LOCAL_DOWNLOADED_MODELS_MOUNTED=/opt/ollama-models
> ```

> [!NOTE]
> On Windows, without WSL, pull default models manually from PowerShell:
>
> ```powershell
> $runtime = & "..\scripts\detect_container_runtime.ps1"
> $models = Get-Content "default-models.txt" | Where-Object { $_ -match '\S' }
> foreach ($model in $models) {
>   & $runtime exec ollama-container ollama pull $model
> }
> ```

##### Stopping the Stack
```sh
# Stop containers (preserves volumes and models)
make compose-down

# Stop and remove everything including volumes (will prompt for confirmation)
make clean
```

## Server Administration Setup

> [!NOTE]
> This section is for sysadmins provisioning a shared Linux server. If you are running this on a 
> personal workstation, you can skip this section.

### Group Structure
```
svc-llm-admins    = Sysadmins who manage the LLM stack (start/stop/update)
docker or podman  = All users who need to run container commands directly
```

Typical users do not need any Linux group membership — they access the service via browser at 
`http://your-server:${OPENWEBUI_PORT:-3000}` and are managed through OpenWebUI's own user management.

### Initial Setup
```sh
# Create the sysadmin group
sudo groupadd svc-llm-admins

# Add sysadmins to the group
sudo usermod -aG svc-llm-admins user1
sudo usermod -aG svc-llm-admins user2

# Set ownership of the service directory
sudo chown -R root:svc-llm-admins /opt/services/docker-small-team-setup
sudo chmod -R 2775 /opt/services/docker-small-team-setup

# If using Docker, add sysadmins to the docker group
sudo usermod -aG docker user1
sudo usermod -aG docker user2

# Note: log out and back in for group changes to take effect
```

### Restricting sudo Access

Rather than granting full root access, restrict sysadmins to only the commands they need:
```sh
sudo visudo -f /etc/sudoers.d/svc-llm-admins
```

Add the following:
```
# Podman
%svc-llm-admins ALL=(ALL) NOPASSWD: /usr/bin/podman, /usr/bin/make

# OR Docker
%svc-llm-admins ALL=(ALL) NOPASSWD: /usr/bin/docker, /usr/bin/make
```

> [!WARNING]
> Being in the `docker` group is effectively equivalent to root access. For stricter environments, prefer Podman rootful with the sudoers restriction above.

### Model Storage Permissions

If using a shared model directory (recommended), ensure it is accessible to the container runtime:
```sh
# Create the shared model directory
sudo mkdir -p /opt/ollama-models

# Set ownership to the sysadmin group
sudo chown -R root:svc-llm-admins /opt/ollama-models
sudo chmod -R 2775 /opt/ollama-models
```

Then set in `.env`:
```sh
LOCAL_DOWNLOADED_MODELS_MOUNTED=/opt/ollama-models
```

### ISO 27001 Compliance Notes

This setup maintains a full audit trail because:
- Each sysadmin uses their **own individual account** — no shared credentials
- All `sudo` commands are logged in `/var/log/secure` (RHEL) or `/var/log/auth.log` (Debian), recording exactly which user ran what
- `sudo` scope is restricted to `podman`/`docker` and `make` only — not blanket root
- Typical users have no shell access to the server — only browser access via OpenWebUI

> [!NOTE]
> Alternative: No-Login Service Account Pattern
> For cases where a team needs a single named process owner without shared credentials,
> a no-login service account can be used alongside individual user accounts.
> This preserves the audit trail while providing a clean ownership model.
>
> ```sh
> # Create a no-login service account
> sudo useradd --system --no-create-home --shell /sbin/nologin llm-admin
>
> # Create the group and add sysadmins
> sudo groupadd svc-llm-admins
> sudo usermod -aG svc-llm-admins user1
> sudo usermod -aG svc-llm-admins user2
>
> # Set service directory ownership
> sudo chown -R llm-admin:svc-llm-admins /opt/services/docker-small-team-setup
> sudo chmod -R 2775 /opt/services/docker-small-team-setup
>
> # Restrict sudo to only podman/make as llm-admin (not full root)
> sudo visudo -f /etc/sudoers.d/llm-admins
> # Add: %svc-llm-admins ALL=(llm-admin) NOPASSWD: /usr/bin/podman, /usr/bin/make
> ```
>
> **When to prefer this over pure group-based permissions:**
> - You want a single unambiguous process owner in `ps` and container inspect output
> - Your security policy requires a named service identity for compliance auditing

<!-- USAGE EXAMPLES -->
## Usage

### User Access

> [!NOTE]
> This is for typical users who only care about using the GUI as a Chatbot, or for accessing Knowledge Bases that's built with [RAG](https://en.wikipedia.org/wiki/Retrieval-augmented_generation)

**Access URL**: `http://your-server:${OPENWEBUI_PORT:-3000}`

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
> This is for sysadmins managing the LLM infrastructure — starting/stopping services, updating models, monitoring resources, and managing users.

As a general rule, the SysAdmin's responsibilities are:

* Provisioning the LLM infrastructure
* Updating LLM models and the stack
* Managing user accounts and permissions via OpenWebUI
* Monitoring system resources and performance
* Setting up knowledge bases and shared resources

#### Stack Management
```sh
# Start the stack
make compose

# Stop the stack
make compose-down

# Pull latest images
make compose-pull

# Check container status
make compose-ps

# View logs
make compose-logs
```

#### Model Management
```sh
# Pull default models (defined in default-models.txt)
make model-pull-defaults

# Pull a specific model
make model-pull model=llama3.1:8b

# List installed models
make model-list

# Remove a model
make model-rm model=llama3.1:8b
```

#### Monitoring Management
```sh
# Start monitoring stack
make monitoring-up

# Stop monitoring stack
make monitoring-down

# View monitoring logs
make monitoring-logs
```

#### Backup
```sh
# Backup OpenWebUI data (chat history, users, settings)
docker run --rm \
  -v openwebui_data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/openwebui_backup_$(date +%Y%m%d).tar.gz /data

# Backup Ollama models (only needed if not using LOCAL_DOWNLOADED_MODELS_MOUNTED)
docker run --rm \
  -v ollama_data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/ollama_backup_$(date +%Y%m%d).tar.gz /data

# Backup monitoring data
docker run --rm \
  -v grafana_data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/grafana_backup_$(date +%Y%m%d).tar.gz /data
```

> [!TIP]
> If `LOCAL_DOWNLOADED_MODELS_MOUNTED` is set to a host path, models are already on the host filesystem and don't need a separate backup step — just back up that directory directly.

#### Resource Monitoring
```sh
# GPU usage
nvidia-smi
watch -n 5 nvidia-smi

# Container resource usage
docker stats
# OR
podman stats

# Disk usage
df -h /var/lib/docker       # Docker
df -h /var/lib/containers   # Podman
```

#### Access URLs

* **Main Interface**: `http://your-server:${OPENWEBUI_PORT:-3000}`
* **Admin Panel**: `http://your-server:${OPENWEBUI_PORT:-3000}/admin`
* **Grafana**: `http://your-server:${GRAFANA_PORT:-3001}`
* **Prometheus**: `http://your-server:${PROMETHEUS_PORT:-9090}`
* **System Metrics**: `http://your-server:${NODE_EXPORTER_PORT:-9100}/metrics`

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
make monitoring-up
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

> [!TIP]
> Always run `make check` first — it diagnoses most common issues automatically.

### Container Issues
```sh
# Check if containers are running
make compose-ps

# View logs for a specific container
docker logs ollama-container --tail 50
# OR
podman logs ollama-container --tail 50

docker logs openwebui --tail 50
# OR
podman logs openwebui --tail 50
```

### Model Issues
```sh
# List installed models
make model-list

# If no models are installed, pull defaults
make model-pull-defaults

# If models are not persisting after restart, check LOCAL_DOWNLOADED_MODELS_MOUNTED in .env
# It should point to a host path, e.g.:
# LOCAL_DOWNLOADED_MODELS_MOUNTED=/opt/ollama-models
```

### Connectivity Issues

```sh
# Test basic API connectivity
if ! curl -s http://localhost:${OPENWEBUI_PORT:-3000} >/dev/null; then
    echo "WARNING: OpenWebUI web interface may not be accessible"
    netstat -tulpn | grep ${OPENWEBUI_PORT:-3000}
else
    echo "✅ OpenWebUI is accessible"
fi
```

### Resource Issues

```sh
# Check GPU memory usage
nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits

# Check disk space
df -h /var/lib/docker       # Docker
df -h /var/lib/containers   # Podman

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
