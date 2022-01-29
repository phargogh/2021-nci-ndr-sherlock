.PHONY: env run

CONTAINER_NAME := ghcr.io/phargogh/nci-groundwater-concentrations
CONTAINER_HASH := sha256:c6fcdfffe907c573d3cf4ba96395a844447d3ded75d8d6be523648cca15eec09

env:
	conda create -p ./env --file=environment.yml

run:
	docker run --rm -ti -v `pwd`:/nci -w /nci $(CONTAINER_NAME)@$(CONTAINER_HASH) compute-rafas-request.py
