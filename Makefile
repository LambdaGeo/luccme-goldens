# ==============================================================================
# Makefile — luccme-goldens
# Canonical Reference Goldens for TerraME 2.0.1 and LuccME 3.1
# ==============================================================================

# Pin a version (or, better, a digest: profsergiocosta/terrame-luccme@sha256:...). 0.4.2 adds GNU time.
DOCKER_IMAGE ?= profsergiocosta/terrame-luccme:0.4.2
LAB ?= all
MD ?=
FILL ?= all
REPS ?= 5
BENCH ?=
REF ?=
DOI ?=

.PHONY: help docker-pull run-labs run-lab run-labs-per-year compare-per-year run-fill timing timing-report package pins clean check

help:
	@echo "luccme-goldens — Automation Tasks"
	@echo "--------------------------------------------------"
	@echo "  make docker-pull         Pull official Docker image from Docker Hub"
	@echo "  make run-labs            Execute all 21 LuccME labs in Docker"
	@echo "  make run-labs LAB=15     Execute a specific lab (e.g. lab15, lab01, 15)"
	@echo "  make run-labs-per-year   Execute per-year goldens for all labs"
	@echo "  make run-labs-per-year LAB=15 [MD=10]  Per-year golden of one lab (MD = maxDifference variant)"
	@echo "  make compare-per-year NEW=... REF=...  Compare two per-year goldens (.csv.gz)"
	@echo "  make run-fill            Execute all 5 TerraME GIS fill cases in Docker"
	@echo "  make run-fill FILL=emas  Execute a specific fill case (itaituba, amazonia, emas, majority, connectivity)"
	@echo "  make timing FILL=connectivity REPS=5   Measure TerraME time/memory of fill cases (frozen measurement)"
	@echo "  make timing-report       Write goldens/timing/environment.json and timing_terrame.json"
	@echo "  make package             Compute SHA-256 hashes and build release ZIP"
	@echo "  make pins REF=v1.1.0 DOI=10.5281/zenodo.N BENCH=../disscube-benchmark   Export benchmark_pins.json (BENCH: also update compare.toml)"
	@echo "  make check               Verify checksums.sha256 and per-year manifests (generator/script hashes)"
	@echo "  make clean               Remove temporary logs and intermediate files"

docker-pull:
	docker pull $(DOCKER_IMAGE)

run-labs:
	bash scripts/run_all_labs.sh $(LAB) $(DOCKER_IMAGE)

run-lab: run-labs

run-labs-per-year:
	bash scripts/run_per_year.sh $(LAB) $(if $(MD),--max-difference $(MD),) --image $(DOCKER_IMAGE)

compare-per-year:
	python3 scripts/lab_per_year.py compare $(NEW) $(REF) $(if $(NEWM),--manifests $(NEWM) $(REFM),)

run-fill:
	bash scripts/run_all_fill.sh $(FILL) $(DOCKER_IMAGE)

timing:
	bash scripts/measure_timing.sh $(FILL) $(REPS) $(DOCKER_IMAGE)

timing-report:
	python3 scripts/timing_report.py env --image $(DOCKER_IMAGE)
	python3 scripts/timing_report.py summarize

package:
	DOCKER_IMAGE="$(DOCKER_IMAGE)" bash scripts/package_release.sh

pins:
	python3 scripts/benchmark_pins.py $(if $(REF),--ref $(REF),) $(if $(DOI),--doi $(DOI),) $(if $(BENCH),--apply $(BENCH),)

check:
	sha256sum -c checksums.sha256
	python3 scripts/check_manifests.py

clean:
	rm -rf goldens/labs/*_err.log goldens/labs/*.log goldens/fill/*_err.log release/*.zip