# Local LLM Infrastructure Setup (Enterprise Multi-Department)

> ![CAUTION]
> The Enterprise setup as of 30.07 2025 has not been experimented, and security-tested. It is **NOT** considered to be compliant yet, because it hasn't been audited.

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
      <li><a href="#requirements-based-on-the-ith-server-machine">Requirements (based on the ITH-Server Machine)</a></li>
      <li><a href="#installation">Installation</a>
      <ul>
          <li><a href="#setting-up-dependencies">Setting Up Dependencies</a>
            <ul>
              <li><a href="#setting-up-docker">Setting Up Docker</a></li>
              <li><a href="#setting-up-nvidia-drivers">Setting Up NVIDIA Drivers</a></li>
            </ul>
          </li>
          <li><a href="#setting-up-multi-instance-infrastructure">Setting Up Multi-Instance Infrastructure</a>
            <ul>
              <li><a href="#setting-up-department-isolation">Setting Up Department Isolation</a></li>
              <li><a href="#setting-up-monitoring">Setting Up Monitoring</a></li>
              <li><a href="#setting-up-load-balancing">Setting Up Load Balancing</a></li>
            </ul>
          </li>
        </ul>
      </li>
    </ul>
  </li>
  <li>
    <a href="#usage">Usage</a>
    <ul>
      <li><a href="#hr-department-access">HR Department Access</a></li>
      <li><a href="#health-department-access">Health Department Access</a></li>
      <li><a href="#development-department-access">Development Department Access</a></li>
      <li><a href="#sysadmin-access">SysAdmin Access</a></li>
    </ul>
  </li>
</ol>

<!-- ABOUT THE SETUP -->
## About The Setup

> [!TIP]
> As a rule of thumb, if you have *multiple departments* with different security requirements, you need this enterprise setup.

The enterprise multi-department setup should be followed when you need departmental isolation and have the following requirements:

* Multiple departments with different security/privacy needs
* LLMs are not allowed to be shared across departments
* Database of knowledge is not allowed to be shared across departments
* Require Department-specific model configurations
* Each department requires isolated AI models and data
* Need for granular resource allocation (GPU scheduling)
* Users are not allowed to access or get any information from users from a different department. (Need-to-know Role-Based Access Control)
* Environment needs to be compliant to standards such as GDPR, ISO 27001

If you need the requirements above, then run the enterprise multi-department setup.

> [!NOTE]
> Although the OS in example is [Rocky Linux](https://rockylinux.org/), it should generally be implementable in all Linux/Unix based environment.

> [!WARNING]
> This setup provides true isolation between departments. Each department gets **their own** Ollama instance, WebUI, GPU allocation, and data storage.

<!-- GETTING STARTED -->
## Getting Started

> [!TIP]
> It is assumed that the **Sys Admin** will be provisioning the infrastructure in Quick Start or Installation below

### Quick Start Guide

Run the following commands in the shell of the LLM server.
```sh
# Clone the repository and navigate to small team setup
git clone <repository-url>
cd docker-enterprise-setup

# Copy and configure environment file
cp .env-health.example .env-health
cp .env-hrd.example .env-hrd
cp .env-swdev.example .env-swdev

# # Edit configuration as needed
# nano .env-health
# nano .env-hrd
# nano .env-swdev

# Make setup scripts executable
chmod +x setup_script.sh

# # edit based on departments to be provisioned
# nano ./setup_multi_instance.sh  
# nano ./setup_ollama_enterprise.sh

# Run enterprise installation
./setup_script.sh
```

#### Common operations
```sh
# All compose operations are to be run in the `docker-small-team-setup` folder, so the `docker compose` is correctly running.

# Check all department containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# View department-specific logs
docker logs ollama-hr
docker logs webui-health
docker logs ollama-swdev

# Check platform status
/opt/ollama-multi/scripts/manage.sh status

# Restart specific department
/opt/ollama-multi/scripts/manage.sh restart hr

# Pull models for specific department
/opt/ollama-multi/scripts/manage.sh pull-models development codellama:13b

# Backup department data
/opt/ollama-multi/scripts/manage.sh backup health

# Clean up everything
cd /opt/ollama-multi && docker-compose down
```

#### Troubleshooting

```sh
# Check GPU allocation across departments
nvidia-smi

# Check department-specific resource usage
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

# Validate entire platform
/opt/ollama-multi/scripts/validate_multi_instance.sh

# Check network connectivity between departments (should be isolated)
docker network ls | grep -E "(hr|health|swdev)"

# Check disk usage per department
du -sh /opt/ollama-multi/data/*

# For permission issues with multi-instance setup:
ls -la /opt/ollama-multi/data/
groups $USER
```

### Requirements (based on my own experience)

> [!NOTE]
> This setup requires **significantly more resources** than the small team setup due to multiple isolated instances.

**Minimum Requirements for Enterprise Setup:**
- **CPU**: 6+ cores (Intel i7-8700 or equivalent)
- **Memory**: 32GB+ RAM (16GB minimum)
- **GPU**: 2x NVIDIA RTX 2080 Ti or equivalent (22GB total VRAM)
- **Storage**: 1TB+ SSD for models and data
- **Network**: Gigabit Ethernet for department access

```sh
{
echo "=== SYSTEM OVERVIEW ==="
hostnamectl
echo -e "\n=== CPU INFO ==="
lscpu | grep -E "(Model name|Socket|Core|Thread)"
echo -e "\n=== MEMORY INFO ==="
free -h
echo -e "\n=== STORAGE INFO ==="
df -h /opt/ollama-multi 2>/dev/null || echo "Multi-instance not yet installed"
echo -e "\n=== GPU INFO ==="
nvidia-smi --query-gpu=index,name,memory.total,memory.free --format=csv,noheader,nounits
echo -e "\n=== DOCKER INFO ==="
docker system df 2>/dev/null || echo "Docker not yet configured"
}
```

### Installation

#### Setting Up Dependencies

> [!NOTE]
> These step-by-step commands are already in the `setup_script.sh`.

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

# Verify GPU + Docker integration
docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu20.04 nvidia-smi
```

#### Setting up Multi-Instance Infrastructure

##### Setting up Department Isolation

The enterprise setup creates isolated environments for each department:

```sh
# Directory structure created:
/opt/ollama-multi/
├── config/
│   ├── docker-compose.yml
│   ├── nginx.conf
│   └── prometheus.yml
├── data/
│   ├── hr/
│   │   ├── ollama/          # HR's isolated models
│   │   └── webui/           # HR's isolated chat data
│   ├── health/
│   │   ├── ollama/          # Health's isolated models
│   │   └── webui/           # Health's isolated chat data
│   └── swdev/
│       ├── ollama/          # Development's isolated models
│       └── webui/           # Development's isolated chat data
├── logs/                    # Department-specific logs
├── scripts/                 # Management utilities
└── backups/                 # Automated backups
```

**GPU Allocation Strategy:**

- HR Department: GPU 0 (RTX 2080 Ti #1)
- Health Department: GPU 1 (RTX 2080 Ti #2)  
- Development Department: Both GPUs (can utilize both for heavy workloads)

##### Setting up Monitoring

```sh
# Prometheus monitoring automatically configured for:
# - Container health metrics
# - GPU utilization per department
# - Resource usage tracking
# - Department-specific alerts

# Access monitoring dashboard:
# http://your-server:9090
```

##### Setting up Load Balancing

```sh
# Nginx reverse proxy provides:
# - Department-specific URLs
# - Load balancing for development team
# - SSL termination capability
# - Access logging per department

# Department URLs:
# http://hr.ollama.local
# http://health.ollama.local  
# http://dev.ollama.local
```

**Docker Compose Services Created:**
```yaml
# Each department gets:
services:
  ollama-{department}:    # Isolated Ollama instance
  webui-{department}:     # Isolated WebUI instance
  
# Shared services:
  monitoring:             # Prometheus monitoring
  nginx:                  # Load balancer/proxy
```

<!-- USAGE EXAMPLES -->
## Usage

### HR Department Access

> [!NOTE]
> HR department has restricted model access focused on document processing and communication tasks.

**Access URL**: `http://your-server:3000`

**Available Models**:
- `llama3.2:3b` - Fast responses for general queries
- `mistral:7b-instruct` - Document summarization and HR tasks

**Features**:
- Document upload (PDF, DOCX, TXT only)
- No code execution capability
- Admin approval required for new users
- Isolated data storage

### Health Department Access

> [!NOTE]
> Health department has medical-focused models with strict privacy controls.

**Access URL**: `http://your-server:3001`

**Available Models**:
- `llama3.1:8b` - Medical text analysis
- `mistral:7b` - Clinical documentation support

**Features**:
- HIPAA-compliant data isolation
- No external integrations
- Dedicated GPU allocation
- Audit logging enabled

### Development Department Access

> [!NOTE]
> Development department has full access to coding models and advanced features.

**Access URL**: `http://your-server:3002`

**Available Models**:
- `llama3.1:8b` - General development tasks
- `codellama:7b` - Code generation and review
- `deepseek-r1:8b` - Advanced reasoning and debugging

**Features**:
- Code execution enabled
- Multiple file format support
- Both GPU access for heavy workloads
- API key generation enabled
- User self-registration allowed

### SysAdmin Access

> [!NOTE]
> System administration across all departments with centralized management.

**Management Commands**:
```sh
# Platform status
/opt/ollama-multi/scripts/manage.sh status

# Department management
/opt/ollama-multi/scripts/manage.sh restart {hr|health|swdev}
/opt/ollama-multi/scripts/manage.sh backup {hr|health|swdev}

# Model management per department
/opt/ollama-multi/scripts/manage.sh pull-models hr llama3.2:3b
/opt/ollama-multi/scripts/manage.sh pull-models health mistral:7b
/opt/ollama-multi/scripts/manage.sh pull-models swdev codellama:13b

# Platform validation
/opt/ollama-multi/scripts/validate_multi_instance.sh

# Resource monitoring
nvidia-smi
docker stats
```

**Access URLs**:
- **Monitoring Dashboard**: `http://your-server:9090`
- **HR Department**: `http://your-server:3000`
- **Health Department**: `http://your-server:3001`
- **Development Department**: `http://your-server:3002`

**Admin Responsibilities**:
- Monitor resource usage across departments
- Manage department-specific models
- Handle user access requests
- Backup and restore department data
- Update and maintain the platform
- Configure department-specific security policies

## Security & Compliance

### Department Isolation
- **Network isolation**: Each department runs in separate Docker networks
- **Data isolation**: Department data stored in separate directories with restricted permissions
- **Resource isolation**: Dedicated GPU allocation prevents resource conflicts
- **User isolation**: Separate WebUI instances with independent user databases

### Access Control
- **HR**: Pending user approval, document-focused, no code execution
- **Health**: Strict data privacy, medical models, audit logging
- **Development**: Full features, self-registration, advanced models

### Monitoring & Auditing
- **Resource usage tracking** per department
- **Container health monitoring** with automated alerts
- **Access logging** for compliance requirements
- **Backup automation** with retention policies

## Troubleshooting Common Issues

### Container Issues
```sh
# Check if all department containers are running
docker ps | grep -E "(ollama-|webui-)"

# Restart specific department
docker-compose restart ollama-hr webui-hr

# Check container logs
docker logs ollama-hr --tail 50
```

### GPU Issues
```sh
# Check GPU allocation
nvidia-smi

# Verify NVIDIA container support
docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu20.04 nvidia-smi

# Check GPU utilization per department
docker exec ollama-hr nvidia-smi
```

### Permission Issues
```sh
# Check data directory permissions
ls -la /opt/ollama-multi/data/

# Fix permissions if needed
sudo /opt/ollama-multi/scripts/fix-permissions.sh
```

## Linked Projects

* [Local Ollama PowerShell Wrapper API](https://github.com/adjiap/local-ollama-powershell-wrapper-api)
* [Local Ollama Python Wrapper API](https://github.com/adjiap/local-ollama-python-wrapper-api)

## References

* [OpenWebUI Environment Configuration](https://docs.openwebui.com/getting-started/env-configuration)
* [Docker Compose Best Practices](https://docs.docker.com/compose/production/)
* [NVIDIA Container Toolkit Documentation](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/overview.html)
* [Prometheus Monitoring Guide](https://prometheus.io/docs/prometheus/latest/getting_started/)
