docker run -d \
  --name openwebui \
  --network ollama-network \
  -p ${OPENWEBUI_PORT}:8080 \
  --env-file ../.env \  # update the .env.example, and expand it
  -v openwebui_data:/app/backend/data \
  --restart unless-stopped \
  ghcr.io/open-webui/open-webui:main
