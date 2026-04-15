# ==============================================================================
# docker-small-team-setup — Makefile
# Works on: Linux, macOS, Windows (via WSL or Git Bash)
# Supports: CPU-only and NVIDIA GPU hosts
# ==============================================================================

SCRIPTS_DIR := ../scripts

DETECT_GPU     := $(SCRIPTS_DIR)/detect_gpu.sh
DETECT_COMPOSE := $(SCRIPTS_DIR)/detect_compose.sh
CHECK_PREREQS  := $(SCRIPTS_DIR)/check_prerequisites.sh
DETECT_RUNTIME := $(SCRIPTS_DIR)/detect_container_runtime.sh

# Ensure scripts are executable
$(shell chmod +x $(SCRIPTS_DIR)/*.sh $(SCRIPTS_DIR)/lib/*.sh 2>/dev/null)

# ==============================================================================

.PHONY: help check compose compose-cpu compose-gpu compose-down compose-pull \
        compose-logs compose-ps model-pull model-list model-rm model-pull-defaults \
        monitoring-up monitoring-down monitoring-ps monitoring-logs clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-22s\033[0m %s\n", $$1, $$2}'

check: ## Verify all prerequisites are met
	@$(CHECK_PREREQS)

compose: check ## Auto-detect GPU and start containers
	@PROFILE=$$($(DETECT_GPU)) && \
	COMPOSE=$$($(DETECT_COMPOSE)) && \
	RUNTIME=$$($(DETECT_RUNTIME)) && \
	[ "$$PROFILE" = "gpu" ] && PROFILE="$${PROFILE}-$${RUNTIME}" ; \
	echo "Starting with profile: $$PROFILE" && \
	$$COMPOSE -f compose.yaml --profile $$PROFILE up -d

compose-cpu: check ## Force CPU mode regardless of hardware
	@COMPOSE=$$($(DETECT_COMPOSE)) && \
	echo "Starting in CPU mode..." && \
	$$COMPOSE -f compose.yaml --profile cpu up -d

compose-gpu: check ## Force GPU mode (requires NVIDIA drivers + container toolkit)
	@COMPOSE=$$($(DETECT_COMPOSE)) && \
	RUNTIME=$$($(DETECT_RUNTIME)) && \
	PROFILE="gpu-$${RUNTIME}" ; \
	echo "Starting in GPU mode..." && \
	$$COMPOSE -f compose.yaml --profile $$PROFILE  up -d

compose-down: ## Stop all containers including monitoring
	@COMPOSE=$$($(DETECT_COMPOSE)) && \
	$$COMPOSE -f compose.yaml --profile cpu --profile gpu-docker --profile gpu-podman down --remove-orphans && \
	$$COMPOSE -f compose.monitoring.yaml down --remove-orphans

compose-pull: ## Pull latest images
	@COMPOSE=$$($(DETECT_COMPOSE)) && \
	$$COMPOSE -f compose.yaml pull

compose-logs: ## Tail logs for llm containers (usage: make compose-logs log=ollama-container tail=50)
	@COMPOSE=$$($(DETECT_COMPOSE)) && \
	$$COMPOSE -f compose.yaml logs -f --tail $${tail:-50} $(log)

compose-ps: ## Show running llm containers
	@COMPOSE=$$($(DETECT_COMPOSE)) && \
	$$COMPOSE -f compose.yaml ps

model-pull: ## Pull a model into Ollama (usage: make model-pull model=llama3.1:8b)
	@RUNTIME=$$($(DETECT_RUNTIME)) && \
	$$RUNTIME exec ollama-container ollama pull $(model)

model-list: ## List installed models
	@RUNTIME=$$($(DETECT_RUNTIME)) && \
	$$RUNTIME exec ollama-container ollama ls

model-rm: ## Remove a model (usage: make model-rm model=llama3.1:8b)
	@RUNTIME=$$($(DETECT_RUNTIME)) && \
	$$RUNTIME exec ollama-container ollama rm $(model)

model-pull-defaults: ## Pull models listed in default-models.txt
	@RUNTIME=$$($(DETECT_RUNTIME)) && \
	while IFS= read -r model; do \
		echo "Pulling $$model..." && \
		$$RUNTIME exec ollama-container ollama pull $$model; \
	done < default-models.txt

monitoring-up: check ## Start the monitoring stack
	@COMPOSE=$$($(DETECT_COMPOSE)) && \
	$$COMPOSE -f compose.monitoring.yaml up -d

monitoring-down: ## Stop the monitoring stack
	@COMPOSE=$$($(DETECT_COMPOSE)) && \
	$$COMPOSE -f compose.monitoring.yaml down --remove-orphans

monitoring-ps: ## Show running monitoring containers
	@COMPOSE=$$($(DETECT_COMPOSE)) && \
	$$COMPOSE -f compose.monitoring.yaml ps

monitoring-logs: ## Tail logs for monitoring containers (usage: make monitoring-logs log=grafana tail=50)
	@COMPOSE=$$($(DETECT_COMPOSE)) && \
	$$COMPOSE -f compose.monitoring.yaml logs -f --tail $${tail:-50} $(log)

clean: ## Remove containers and volumes (WARNING: deletes all models and data)
	@read -p "This will delete all models and chat data. Are you sure? [y/N] " confirm && \
	[ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] || (echo "Aborted." && exit 1) && \
	COMPOSE=$$($(DETECT_COMPOSE)) && \
	$$COMPOSE -f compose.yaml --profile cpu --profile gpu down --volumes --remove-orphans
	$$COMPOSE -f compose.monitoring.yaml --profile cpu --profile gpu down --volumes --remove-orphans
