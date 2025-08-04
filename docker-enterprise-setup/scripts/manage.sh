#!/bin/bash
# /opt/ollama-multi/scripts/manage.sh

PLATFORM_DIR="/opt/ollama-multi"
COMPOSE_FILE="$PLATFORM_DIR/docker-compose.yml"

show_status() {
    echo "=== Department AI Platform Status ==="
    cd $PLATFORM_DIR
    docker-compose ps
    
    echo -e "\n=== GPU Usage ==="
    nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits
    
    echo -e "\n=== Access URLs ==="
    echo "HR Department:     http://$(hostname -I | awk '{print $1}'):3000"
    echo "Health Department: http://$(hostname -I | awk '{print $1}'):3001"
    echo "Dev Department:    http://$(hostname -I | awk '{print $1}'):3002"
    echo "Monitoring:        http://$(hostname -I | awk '{print $1}'):9090"
    
    echo -e "\n=== Disk Usage ==="
    du -sh $PLATFORM_DIR/data/*
}

pull_models() {
    local department=$1
    shift
    local models=("$@")
    
    if [ -z "$department" ]; then
        echo "Usage: $0 pull-models <department> <model1> [model2] ..."
        echo "Departments: hr, health, development"
        exit 1
    fi
    
    echo "Pulling models for $department department..."
    for model in "${models[@]}"; do
        echo "Pulling $model..."
        docker exec ollama-$department ollama pull "$model"
    done
}

backup_department() {
    local department=$1
    
    if [ -z "$department" ]; then
        echo "Usage: $0 backup <department>"
        echo "Departments: hr, health, development"
        exit 1
    fi
    
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_file="$PLATFORM_DIR/backups/${department}-${timestamp}.tar.gz"
    
    echo "Backing up $department department..."
    tar -czf "$backup_file" -C "$PLATFORM_DIR/data" "$department"
    
    echo "Backup created: $backup_file"
}

restart_department() {
    local department=$1
    
    if [ -z "$department" ]; then
        echo "Usage: $0 restart <department>"
        echo "Departments: hr, health, development"
        exit 1
    fi
    
    echo "Restarting $department department..."
    cd $PLATFORM_DIR
    docker-compose restart ollama-$department webui-$department
}

case "$1" in
    status)
        show_status
        ;;
    pull-models)
        pull_models "${@:2}"
        ;;
    backup)
        backup_department $2
        ;;
    restart)
        restart_department $2
        ;;
    start)
        cd $PLATFORM_DIR && docker-compose up -d
        ;;
    stop)
        cd $PLATFORM_DIR && docker-compose down
        ;;
    *)
        echo "Usage: $0 {status|pull-models|backup|restart|start|stop}"
        echo ""
        echo "Examples:"
        echo "  $0 status"
        echo "  $0 pull-models development llama3.1:8b codellama:7b"
        echo "  $0 backup hr"
        echo "  $0 restart health"
        exit 1
        ;;
esac
