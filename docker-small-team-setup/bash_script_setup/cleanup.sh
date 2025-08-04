echo "Cleaning up Local LLM infrastructure..."

# Stop and remove containers
docker stop ollama-container openwebui 2>/dev/null || true
docker rm ollama-container openwebui 2>/dev/null || true

# Remove volumes (optional - ask user)
read -p "Do you want to remove all data (models, conversations)? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker volume rm ollama_data openwebui_data 2>/dev/null || true
    echo "Data volumes removed"
fi

# Remove network
docker network rm ollama-network 2>/dev/null || true

echo "Cleanup complete!"