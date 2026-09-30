# Shortcuts — `make help` lists targets.
DC  := docker compose
OBS := --profile observability

.PHONY: help secrets config pull up up-core down ps logs bootstrap smoke backup reload-prom

help:        ## list targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-12s %s\n", $$1, $$2}'

secrets:     ## create .env with generated secrets
	./scripts/gen-secrets.sh

config:      ## validate the compose file
	$(DC) $(OBS) config --quiet && echo "compose OK"

pull:        ## pull all pinned images
	$(DC) $(OBS) pull --ignore-buildable

up:          ## start gateway + observability
	$(DC) $(OBS) up -d --build --wait

up-core:     ## start gateway only (etcd + APISIX)
	$(DC) up -d --build --wait

down:        ## stop everything (data volumes are kept)
	$(DC) $(OBS) --profile demo down

ps:          ## container status
	$(DC) $(OBS) --profile demo ps

logs:        ## follow APISIX logs
	$(DC) logs -f --tail=100 apisix

bootstrap:   ## apply baseline global rules via Admin API
	./scripts/bootstrap.sh

smoke:       ## end-to-end test with the demo upstream
	$(DC) --profile demo up -d --wait demo-upstream
	./scripts/smoke-test.sh

backup:      ## etcd snapshot -> ./backups
	./scripts/etcd-backup.sh

reload-prom: ## hot-reload Prometheus config/rules
	curl -fsS -X POST http://127.0.0.1:9090/-/reload && echo reloaded
