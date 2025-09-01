docker network create ollama-network 2>/dev/null || true

# Set up ollama-container
docker run -d \
  --name ollama-container \
  --network ollama-network \
  -v ollama_data:/root/.ollama \
  --restart unless-stopped \
  ollama/ollama:latest

echo "Waiting for Ollama to start..."
max_attempts=10
attempt=0
while ! docker exec ollama-container ollama list >/dev/null 2>&1; do
    if [ $attempt -ge $max_attempts ]; then
        echo "Error: Ollama failed to start after $max_attempts attempts"
        exit 1
    fi
    echo "Attempt $((attempt+1))/$max_attempts: Ollama not ready yet, waiting..."
    sleep 2
    ((attempt++))
done
echo "Ollama is ready!"
