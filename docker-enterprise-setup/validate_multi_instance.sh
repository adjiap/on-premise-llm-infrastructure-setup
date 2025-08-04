#!/bin/bash
# validate-multi-instance.sh

set -e

echo "=== Multi-Instance Ollama Platform Validation ==="
echo "Timestamp: $(date)"
echo ""

# Define departments and their ports
declare -A departments=(
    ["hr"]="3000"
    ["health"]="3001" 
    ["swdev"]="3002"
)

# Define expected containers
expected_containers=(
    "ollama-hr"
    "webui-hr"
    "ollama-health"
    "webui-health"
    "ollama-swdev"
    "webui-swdev"
    "ollama-monitoring"
    "ollama-nginx"
)

validation_errors=0
validation_warnings=0

# Function to log errors
log_error() {
    echo "❌ ERROR: $1"
    ((validation_errors++))
}

# Function to log warnings
log_warning() {
    echo "⚠️  WARNING: $1"
    ((validation_warnings++))
}

# Function to log success
log_success() {
    echo "✅ $1"
}

echo "1. Checking Docker Compose Status..."
echo "----------------------------------------"

# Check if docker-compose.yml exists
if [ ! -f "/opt/ollama-multi/docker-compose.yml" ]; then
    log_error "docker-compose.yml not found in /opt/ollama-multi/"
    exit 1
fi

# Check if we're in the right directory or can run compose
cd /opt/ollama-multi
if ! docker-compose config >/dev/null 2>&1; then
    log_error "docker-compose.yml is not valid"
    exit 1
fi
log_success "docker-compose.yml is valid"

echo ""
echo "2. Checking Container Status..."
echo "----------------------------------------"

# Check if all expected containers are running
for container in "${expected_containers[@]}"; do
    if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        log_success "Container '$container' is running"
    else
        if docker ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
            log_error "Container '$container' exists but is not running"
        else
            log_error "Container '$container' does not exist"
        fi
    fi
done

echo ""
echo "3. Checking Department Services..."
echo "----------------------------------------"

# Check each department's services
for dept in "${!departments[@]}"; do
    port=${departments[$dept]}
    echo "Checking $dept department (port $port)..."
    
    # Check Ollama container
    ollama_container="ollama-$dept"
    if docker ps | grep -q "$ollama_container"; then
        log_success "$dept Ollama container is running"
        
        # Check if models are available
        model_count=$(docker exec "$ollama_container" ollama list 2>/dev/null | grep -c ":" || echo "0")
        if [ "$model_count" -gt 0 ]; then
            log_success "$dept department has $model_count model(s) installed"
        else
            log_warning "$dept department has no models installed"
        fi
        
        # Test Ollama API
        if docker exec "$ollama_container" curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
            log_success "$dept Ollama API is responding"
        else
            log_error "$dept Ollama API is not responding"
        fi
    else
        log_error "$dept Ollama container is not running"
    fi
    
    # Check WebUI container
    webui_container="webui-$dept"
    if docker ps | grep -q "$webui_container"; then
        log_success "$dept WebUI container is running"
        
        # Test WebUI accessibility
        if curl -s --connect-timeout 5 http://localhost:$port >/dev/null 2>&1; then
            log_success "$dept WebUI is accessible on port $port"
        else
            log_warning "$dept WebUI may not be accessible on port $port"
        fi
    else
        log_error "$dept WebUI container is not running"
    fi
    
    echo ""
done

echo "4. Checking System Resources..."
echo "----------------------------------------"

# Check GPU availability
if command -v nvidia-smi >/dev/null 2>&1; then
    gpu_count=$(nvidia-smi -L | wc -l)
    log_success "Found $gpu_count GPU(s) available"
    
    # Check GPU utilization
    gpu_util=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -1)
    if [ "$gpu_util" -gt 90 ]; then
        log_warning "GPU utilization is high: ${gpu_util}%"
    else
        log_success "GPU utilization: ${gpu_util}%"
    fi
else
    log_warning "nvidia-smi not available - cannot check GPU status"
fi

# Check disk usage
disk_usage=$(df /opt/ollama-multi | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$disk_usage" -gt 90 ]; then
    log_error "Disk usage is critical: ${disk_usage}%"
elif [ "$disk_usage" -gt 80 ]; then
    log_warning "Disk usage is high: ${disk_usage}%"
else
    log_success "Disk usage: ${disk_usage}%"
fi

# Check memory usage
memory_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
if [ "$memory_usage" -gt 90 ]; then
    log_warning "Memory usage is high: ${memory_usage}%"
else
    log_success "Memory usage: ${memory_usage}%"
fi

echo ""
echo "5. Checking Network Connectivity..."
echo "----------------------------------------"

# Check if nginx is accessible
if curl -s --connect-timeout 5 http://localhost >/dev/null 2>&1; then
    log_success "Nginx reverse proxy is accessible"
else
    log_warning "Nginx reverse proxy may not be accessible"
fi

# Check monitoring
if curl -s --connect-timeout 5 http://localhost:9090 >/dev/null 2>&1; then
    log_success "Monitoring (Prometheus) is accessible"
else
    log_warning "Monitoring (Prometheus) may not be accessible"
fi

# Check Docker networks
for dept in "${!departments[@]}"; do
    network_name="${dept}-network"
    if docker network ls | grep -q "$network_name"; then
        log_success "Network '$network_name' exists"
    else
        log_error "Network '$network_name' does not exist"
    fi
done

echo ""
echo "6. Checking Data Persistence..."
echo "----------------------------------------"

# Check if data directories exist and have proper permissions
for dept in "${!departments[@]}"; do
    data_dir="/opt/ollama-multi/data/$dept"
    if [ -d "$data_dir/ollama" ] && [ -d "$data_dir/webui" ]; then
        log_success "$dept data directories exist"
        
        # Check permissions
        ollama_perms=$(stat -c "%a" "$data_dir/ollama" 2>/dev/null || echo "000")
        if [ "$ollama_perms" = "755" ]; then
            log_success "$dept ollama directory has correct permissions (755)"
        else
            log_warning "$dept ollama directory has permissions $ollama_perms (expected 755)"
        fi
    else
        log_error "$dept data directories are missing"
    fi
done

echo ""
echo "7. Running Health Checks..."
echo "----------------------------------------"

# Test model inference for each department
for dept in "${!departments[@]}"; do
    ollama_container="ollama-$dept"
    if docker ps | grep -q "$ollama_container"; then
        echo "Testing $dept model inference..."
        
        # Get first available model
        first_model=$(docker exec "$ollama_container" ollama list 2>/dev/null | grep ":" | head -1 | awk '{print $1}' || echo "")
        
        if [ -n "$first_model" ]; then
            # Test inference with timeout
            if timeout 30 docker exec "$ollama_container" ollama run "$first_model" "Hello" >/dev/null 2>&1; then
                log_success "$dept model inference test passed ($first_model)"
            else
                log_warning "$dept model inference test failed or timed out ($first_model)"
            fi
        else
            log_warning "$dept has no models to test"
        fi
    fi
done

echo ""
echo "=== Validation Summary ==="
echo "----------------------------------------"

if [ $validation_errors -eq 0 ] && [ $validation_warnings -eq 0 ]; then
    echo "🎉 All validations passed! Platform is healthy."
    exit 0
elif [ $validation_errors -eq 0 ]; then
    echo "✅ Platform is functional with $validation_warnings warning(s)."
    exit 0
else
    echo "❌ Platform has issues: $validation_errors error(s) and $validation_warnings warning(s)."
    echo ""
    echo "Suggested actions:"
    echo "1. Check container logs: docker-compose logs [service-name]"
    echo "2. Restart failed services: docker-compose restart [service-name]"
    echo "3. Check system resources and disk space"
    exit 1
fi
