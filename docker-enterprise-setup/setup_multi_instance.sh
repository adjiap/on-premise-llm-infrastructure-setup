#!/bin/bash

echo "Setting up multi-instance Ollama infrastructure..."

# Define departments
departments=(
    "hr"
    "health"
    "swdev"
)

# Create main directory structure
sudo mkdir -p /opt/ollama-multi/{config,data,logs,scripts,backups}

# Create department-specific directories using the list
for dept in "${departments[@]}"; do
    sudo mkdir -p /opt/ollama-multi/data/$dept
    sudo mkdir -p /opt/ollama-multi/logs/$dept
done

# Create department-specific data directories
for dept in "${departments[@]}"; do
    sudo mkdir -p /opt/ollama-multi/data/$dept/{ollama,webui}
    sudo mkdir -p /opt/ollama-multi/logs/$dept/{ollama,webui}
done

# Create ollama group and add users
sudo groupadd ollama-admins 2>/dev/null || true
sudo usermod -aG ollama-admins $USER

# Set permissions
sudo chown -R root:ollama-admins /opt/ollama-multi
sudo chmod 750 /opt/ollama-multi
sudo chmod 750 /opt/ollama-multi/data
sudo chmod 750 /opt/ollama-multi/logs
sudo chmod 750 /opt/ollama-multi/scripts
sudo chmod 750 /opt/ollama-multi/config

# Set Docker container access (directories only, no -R)
for dept in "${departments[@]}"; do
    # Directories need 755 for container access
    sudo chmod 755 /opt/ollama-multi/data/$dept/ollama
    sudo chmod 755 /opt/ollama-multi/data/$dept/webui
    
    # When containers create files, they'll have reasonable permissions
    # We don't need to pre-set file permissions since they don't exist yet
done

echo "Directory structure created successfully!"

# Copy docker-compose.yml
sudo cp docker-compose.yml /opt/ollama-multi/
sudo cp configs/nginx.conf /opt/ollama-multi/config/
sudo cp configs/prometheus.yml /opt/ollama-multi/config/
sudo cp manage.sh /opt/ollama-multi/scripts/

# Set permissions on copied files
sudo chmod 640 /opt/ollama-multi/docker-compose.yml
sudo chmod 750 /opt/ollama-multi/scripts/manage.sh

# Config files: readable by group, not executable
sudo find /opt/ollama-multi/config -type f -exec chmod 640 {} \;

# Copy management script
sudo cp manage.sh /opt/ollama-multi/scripts/
sudo chmod 750 /opt/ollama-multi/scripts/manage.sh
