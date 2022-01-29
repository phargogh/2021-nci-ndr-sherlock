.PHONY: env run docker-build run-test

CONTAINER_NAME := ghcr.io/phargogh/nci-groundwater-concentrations
CONTAINER_HASH := sha256:f0f7ca82d9239e3e5d9569ce0738317ab86660711244bcb88e4167fe674610a9

env:
	conda create -p ./env --file=environment.yml

docker-build:
	docker build . -t $(CONTAINER_NAME)
	$(make) run-test

run-test:
	docker run --rm -ti -v `pwd`:/nci -w /nci $(CONTAINER_NAME)@$(CONTAINER_HASH) compute-rafas-request.py --test-imports

run:
	docker run --rm -ti -v `pwd`:/nci -w /nci $(CONTAINER_NAME)@$(CONTAINER_HASH) compute-rafas-request.py
