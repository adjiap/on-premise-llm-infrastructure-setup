echo "Starting Docker Compose services..."
cd /opt/ollama-multi
sudo docker-compose up -d

echo "Waiting for containers to initialize..."
sleep 30

# Pull base models for each instance
./scripts/manage.sh pull-models development llama3.1:8b codellama:7b deepseek-r1:8b
./scripts/manage.sh pull-models hr llama3.2:3b mistral:7b-instruct
./scripts/manage.sh pull-models health llama3.1:8b mistral:7b

./scripts/manage.sh status
