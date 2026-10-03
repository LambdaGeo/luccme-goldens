# ==============================================================================
# Makefile — luccme-goldens
# Canonical Reference Goldens for TerraME 2.0.1 and LuccME 3.1
# ==============================================================================

DOCKER_IMAGE ?= profsergiocosta/terrame-luccme
LAB ?= all
FILL ?= all

.PHONY: help docker-pull run-labs run-lab run-fill package clean check

help:
	@echo "luccme-goldens — Automation Tasks"
	@echo "--------------------------------------------------"
	@echo "  make docker-pull         Pull official Docker image from Docker Hub"
	@echo "  make run-labs            Execute all 21 LuccME labs in Docker"
	@echo "  make run-labs LAB=15     Execute a specific lab (e.g. lab15, lab01, 15)"
	@echo "  make run-fill            Execute all 4 TerraME GIS fill cases in Docker"
	@echo "  make run-fill FILL=emas  Execute a specific fill case (itaituba, amazonia, emas, majority)"
	@echo "  make package             Compute SHA-256 hashes and build release ZIP"
	@echo "  make check               Verify checksums against checksums.sha256"
	@echo "  make clean               Remove temporary logs and intermediate files"

docker-pull:
	docker pull $(DOCKER_IMAGE)

run-labs:
	bash scripts/run_all_labs.sh $(LAB) $(DOCKER_IMAGE)

run-lab: run-labs

run-fill:
	bash scripts/run_all_fill.sh $(FILL) $(DOCKER_IMAGE)

package:
	bash scripts/package_release.sh

check:
	sha256sum -c checksums.sha256

clean:
	rm -rf goldens/labs/*_err.log goldens/labs/*.log goldens/fill/*_err.log release/*.zip