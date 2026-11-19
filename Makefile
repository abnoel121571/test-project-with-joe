.PHONY: help build up down logs shell test clean

help:        ## Show this help
	@grep -E '^[a-z]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-8s %s\n", $$1, $$2}'

build:       ## Build the spark-jupyter image
	docker compose build

up:          ## Start the stack in the background
	docker compose up -d
	@echo "JupyterLab → http://localhost:$${JUPYTER_HOST_PORT:-8888}"

down:        ## Stop the stack (MinIO data is kept)
	docker compose down

logs:        ## Follow logs from all services
	docker compose logs -f

shell:       ## Open a bash shell in the spark-jupyter container
	docker compose exec spark-jupyter bash

test:        ## Run the environment smoke test headlessly (stack must be up)
	docker compose exec spark-jupyter jupyter nbconvert --to notebook --execute \
	    00_environment_test.ipynb --output-dir /tmp --output env_test_result.ipynb

clean:       ## Stop the stack AND delete MinIO data and catalog state
	docker compose down -v
