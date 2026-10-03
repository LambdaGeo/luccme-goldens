# luccme-goldens

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23107748.svg)](https://doi.org/10.5281/zenodo.23107748)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Docker Image](https://img.shields.io/badge/Docker-profsergiocosta%2Fterrame--luccme-blue)](https://hub.docker.com/r/profsergiocosta/terrame-luccme)
[![Open Science](https://img.shields.io/badge/Open%20Science-Reproducible%20Goldens-green.svg)](#)

**Canonical Reference Execution Outputs (Goldens) for TerraME 2.0.1 and LuccME 3.1.**

This repository serves as the **Level 1 (Reference Goldens)** foundation for reproducible land-use change modelling across legacy (TerraME/LuccME) and modern data cube environments (`disscube`/`disslucc`).

---

## 1. Scientific Motivation

In environmental simulation science, proving that a newly engineered model (`disslucc` / `disscube`) faithfully replicates a legacy system (`TerraME` / `LuccME`) requires strict numerical parity against immutable reference outputs ("goldens").

Because TerraME 2.0.1 depends on a legacy Ubuntu 18.04 runtime, running the original model scripts on modern operating systems can be difficult. This repository solves that challenge through a dual approach:
1. **Pre-computed, Verifiable Goldens (No Re-run Needed):** Every reference CSV and baseline dataset is pre-computed, versioned, hashed with SHA-256, and published as a GitHub Release asset (and archived on Zenodo with DOI: [10.5281/zenodo.23107748](https://doi.org/10.5281/zenodo.23107748)). Downstream projects ingest them in seconds via `Pooch`.
2. **Reproducible Generation Harness:** A turnkey Dockerized harness (`profsergiocosta/terrame-luccme`) enables independent peer reviewers to execute all legacy scripts and re-verify every SHA-256 hash from scratch.

---

## 2. Catalog of Golden Suites

### Suite A: LuccME Simulation Models (`sources/labs/` → `goldens/labs/`)
Covers the official functional test suite of LuccME 3.1 across continuous and discrete land-use dynamics:

| Lab | Model Paradigm | Components Used | Study Area & Data |
| :--- | :--- | :--- | :--- |
| **Lab01** | Continuous | `DemandPreComputed` + `PotentialCLinearRegression` + `AllocationCClueLike` | Acre (`csAC.shp`, 25 km) |
| **Lab02** | Continuous | `DemandPreComputed` + `PotentialCSpatialLagRegression` + `AllocationCClueLike` | Acre (`csAC.shp`, 25 km) |
| **Lab03** | Continuous | `DemandPreComputed` + `PotentialCSpatialLagRegression` + **`AllocationCClueLikeSaturation`** | Acre (`csAC.shp`, 25 km) |
| **Lab04** | Continuous | `DemandComputeTwoDates` + `PotentialCSpatialLagRegression` + `AllocationCClueLike` | Acre (`csAC.shp`, 25 km) |
| **Lab05** | Continuous | `DemandComputeThreeDates` + `PotentialCSpatialLagRegression` + `AllocationCClueLike` | Acre (`csAC.shp`, 25 km) |
| **Lab06** | Continuous | Dynamic variables update (2009) | Acre (`csAC_2009.shp`) |
| **Lab07** | Continuous | Prospective scenario simulation (2015–2025) with dynamic updates (2020) | Acre (`csAC_cenarioA_2020.shp`) |
| **Lab08** | Continuous | `PotentialCSpatialLagLinearRegressionMix` | Acre (`csAC.shp`) |
| **Lab09** | Continuous | `PotentialCMaximumEntropyLike` | Acre (`csAC.shp`) |
| **Lab10** | Discrete | `PotentialDNeighSimpleRule` + `AllocationDSimpleOrdering` | Mojuí dos Campos/BR-163 (`cs_moju.shp`, 500 m) |
| **Lab11** | Discrete | `PotentialDInverseDistanceRule` + `AllocationDSimpleOrdering` | Mojuí dos Campos/BR-163 (`cs_moju.shp`, 500 m) |
| **Lab12** | Discrete | `PotentialDNeighInverseDistanceRule` + `AllocationDSimpleOrdering` | Mojuí dos Campos/BR-163 (`cs_moju.shp`, 500 m) |
| **Lab13** | Discrete | `PotentialDLogisticRegression` | Mojuí dos Campos/BR-163 (`cs_moju.shp`, 500 m) |
| **Lab14** | Discrete | `PotentialDLogisticRegressionNeighAttract` + `AllocationDClueSLike` | Mojuí dos Campos/BR-163 (`cs_moju.shp`, 500 m) |
| **Lab15** | Discrete | **`DemandPreComputed` + `PotentialDLogisticRegression` + `AllocationDClueSLike`** | **Mojuí dos Campos/BR-163 (Paper Case 1)** |
| **Lab16** | Discrete | `DemandComputeTwoDates` + `PotentialDLogisticRegression` + `AllocationDClueSLike` | Mojuí dos Campos/BR-163 (`cs_moju.shp`) |
| **Lab17** | Discrete | `DemandComputeThreeDates` + `PotentialDLogisticRegression` + `AllocationDClueSLike` | Mojuí dos Campos/BR-163 (`cs_moju.shp`) |
| **Lab18** | Discrete | `PotentialDSampleBased` + `AllocationDClueSLike` | Mojuí dos Campos/BR-163 (`cs_moju.shp`) |
| **Lab19** | Discrete | `PotentialDLogisticRegressionNeighAttractRepulsion` + `AllocationDClueSNeighOrdering` | Mojuí dos Campos/BR-163 (`cs_moju.shp`) |
| **Lab20** | Mixed | `PotentialDLogisticRegressionNeighAttractRepulsion` + `AllocationCClueLike` | Mojuí dos Campos/BR-163 (`cs_moju.shp`) |
| **Lab21** | Discrete | `PotentialDLogisticRegressionNeighAttractRepulsion` + `AllocationDClueSNeighOrdering` | Mojuí dos Campos/BR-163 (`cs_moju.shp`) |

**What `goldens/labs/` holds.** The **last year** of each lab, as saved by LuccME itself: the attributes of the cell layer (the model inputs, such as distances, slope and the initial land-use classes, plus the cell `id`, `row` and `col`) and the output column(s) the lab asks LuccME to save (`saveAttrs`, usually `d_out`). They are the checkpoint of the last year. They are also an input of the per-year generator, which takes the cell ids and `col`/`row` from this file and checks its own last year against it (see Suite A.2). Release `v1.0.0` (Zenodo) published these files.

### Suite A.2: Per-year goldens (`goldens/labs_per_year/`)

**These are the reference for validating a re-implementation year by year.** The goldens of Suite A keep only the last year of each lab, but validating a model needs the state of every cell at the end of every year and the number of iterations TerraME needed in each year. There is one folder per lab (`lab01` to `lab21`) and per variant:

| File | Contents |
| :--- | :--- |
| `<name>.csv.gz` | `year,id,col,row`, then `<lu>_out` and `<lu>_pot` of every cell, every year, 12 decimal places |
| `manifest.json` | source script and SHA-256, generator, years, cells, columns, iterations per year, and a cross-check of the last year against the canonical `goldens/labs/` file |
| `terrame.log` | TerraME output (demand, allocated area, iterations per year) |

A per-year golden gets `status: ok` only if its last year equals the corresponding `goldens/labs/` file within 1e-9; otherwise the generation exits with an error and the manifest says `status: crosscheck_failed`.

Generate one with `make run-labs-per-year LAB=15` (Docker). The lab is **not changed**: a recorder Event (`scripts/per_year_snapshot.lua`) runs after the model step and reads the cells. Listing every year in `save.saveYears` would not work, because the allocation components use it to manage `<lu>_backupYear`/`_chpast` and to restore the cell values, so it changes the simulation.

**Variants.** `make run-labs-per-year LAB=15 MD=10` runs the same lab with another `maxDifference` and writes `lab15_md10/`. Variants are **not labs of the LuccME package**: `manifest.json` records `variant_of` and the override, and there is no canonical final-year file for them (the cross-check is skipped). They exist to exercise the convergence loop, since in the package labs the allocation is accepted at the first pass.

Compare two per-year goldens (e.g. a re-generated one against another implementation's reference):

```bash
make compare-per-year NEW=goldens/labs_per_year/lab15/lab15.csv.gz REF=other/lab15.csv.gz \
     NEWM=goldens/labs_per_year/lab15/manifest.json REFM=other/manifest.json   # manifests optional
```

The files released with each version are listed in `manifest.json`.

### Suite B: TerraME GIS Fill Cellular Space (`sources/fill/` → `goldens/fill/`)
Validates spatial aggregation and feature extraction on cellular grids against TerraME's `cl:fill{}`:

| Dataset | Grid Dimensions | Spatial CRS | Evaluated Operators |
| :--- | :--- | :--- | :--- |
| **`itaituba`** | 620 cells, 5 km | SIRGAS 2000 UTM 21S (EPSG:29191) | `average` (elevation), `coverage` (deforestation), `distance` (roads, localities), `sum` (population) |
| **`amazonia`** | 2,229 cells, 50 km | SIRGAS 2000 UTM 21S (EPSG:29191) | `coverage` (PRODES), `distance` (roads, ports), `area` (protected reserves) |
| **`emas`** | 5,514 cells, 500 m | SAD69 UTM 22S (EPSG:29192) | `presence` (firebreak, rivers), `maximum` & `minimum` (vegetation cover) |
| **`majority`** | 620 cells, 5 km | SIRGAS 2000 UTM 21S (EPSG:29191) | `mode` (predominant deforestation class; text column, ties listed separated by comma) |

---

## 3. Quick Start: Using Pre-computed Goldens via Pooch

Downstream Python pipelines (`disscube`, `disslucc`, `dissmodel`) do **not** need Docker installed. They fetch and verify goldens directly:

```python
import pooch
import pandas as pd

# Download and verify Lab15 baseline
moju_csv = pooch.retrieve(
    url="[https://github.com/LambdaGeo/luccme-goldens/releases/download/v1.0.0/cs_moju_baseline.csv](https://github.com/LambdaGeo/luccme-goldens/releases/download/v1.0.0/cs_moju_baseline.csv)",
    known_hash="sha256:<HASH_FROM_CHECKSUMS>",
)
df_moju = pd.read_csv(moju_csv)

# Download and verify Itaituba fill reference
itaituba_csv = pooch.retrieve(
    url="[https://github.com/LambdaGeo/luccme-goldens/releases/download/v1.0.0/itaituba_terrame.csv](https://github.com/LambdaGeo/luccme-goldens/releases/download/v1.0.0/itaituba_terrame.csv)",
    known_hash="sha256:<HASH_FROM_CHECKSUMS>",
)
df_itaituba = pd.read_csv(itaituba_csv)

```

---

## 4. Reproducing the Goldens via Docker (Optional)

If you wish to re-execute the legacy TerraME models and regenerate all golden outputs:

### Prerequisites

* Docker engine installed and running.

### 1. Pull the Docker Appliance

```bash
make docker-pull
# Or manually:
docker pull profsergiocosta/terrame-luccme

```

### 2. Run LuccME Simulation Labs

To run a single lab (e.g., Lab 01 or Lab 15):

```bash
make run-labs LAB=01
# Or:
make run-labs LAB=15

```

To run all 21 labs in batch:

```bash
make run-labs

```

Each run automatically generates:

* **Canonical CSV (`.csv`)**: Used for numerical parity diffs and tracked in Git.
* **Zipped Shapefile (`.zip`)**: Ready to open in QGIS/ArcGIS (kept locally; ignored by Git to avoid repository bloat).

To generate the per-year goldens (Suite A.2), which need the matching `goldens/labs/Lab<NN>_<year>.csv` (a lab without it is skipped; run `make run-labs` first):

```bash
make run-labs-per-year LAB=15         # one lab -> goldens/labs_per_year/lab15/
make run-labs-per-year                # all 21 labs
make run-labs-per-year LAB=15 MD=10   # variant with another maxDifference -> lab15_md10/
```

### 3. Run TerraME GIS Fill Cases

To run a single fill case (e.g. Itaituba, Amazônia, Emas, or Majority):

```bash
make run-fill FILL=itaituba
# Or:
make run-fill FILL=amazonia
make run-fill FILL=emas
make run-fill FILL=majority

```

To run all 3 cases in batch:

```bash
make run-fill

```

Each run automatically generates:

* **Canonical CSV (`.csv`)**: Used for numerical parity diffs and tracked in Git.
* **Zipped Shapefile (`.zip`)**: Complete shapefile bundle (`.shp`, `.dbf`, `.shx`, `.prj`, `.cpg`) ready to open in QGIS/ArcGIS.

### 4. Build Release Package and Checksums

```bash
make package

```

Generates `checksums.sha256`, `manifest.json`, and `release/luccme-goldens-<version>.zip` (`VERSION=v1.1.0 make package` to override the default). Checksums cover `.csv`, `.csv.gz`, `.shp`, `.dbf` and `.tif`.

---

## 5. Repository Structure

```text
luccme-goldens/
├── Makefile                       # Main entry point: run-labs, run-fill, package
├── README.md                      # Comprehensive documentation and catalog
├── CITATION.cff                   # Citation metadata (Zenodo / GitHub integration)
├── LICENSE                        # MIT and LGPL-3.0 attribution
├── checksums.sha256               # SHA-256 cryptographic hashes of all goldens
├── manifest.json                  # Machine-readable artifact manifest
│
├── sources/                       # Canonical upstream model scripts and input layers
│   ├── labs/                      # lab01.lua to lab21.lua (LuccME 3.1 upstream models)
│   └── fill/                      # itaituba.lua, amazonia.lua, emas.lua, majority.lua
│
├── scripts/                       # Automated execution and formatting harnesses
│   ├── run_all_labs.sh            # Batch and single-lab runner for LuccME simulation labs
│   ├── run_all_fill.sh            # Batch runner for TerraME GIS fill scripts (with .zip packager)
│   ├── run_per_year.sh            # Per-year golden of one lab or variant (Docker)
│   ├── lab_per_year.py            # transform / consolidate / compare per-year goldens
│   ├── per_year_snapshot.lua      # Recorder Event inlined into the lab by lab_per_year.py
│   ├── export_reference.py        # Spatial parser converting SHP to standardized CSV
│   └── package_release.sh         # Release archiver and hash generator
│
├── goldens/                       # Reference outputs
│   ├── fill/                      # Canonical CSVs and zipped shapefiles (itaituba, amazonia, emas, majority)
│   ├── labs/                      # Canonical CSVs and zipped shapefiles (csAC, cs_moju, lab01-21)
│   └── labs_per_year/             # Year-by-year states (csv.gz, manifest.json, log) and _mdN variants
│
└── release/                       # Release archive bundle for GitHub Releases / Zenodo
    └── luccme-goldens-<version>.zip

```

---

## 6. Citation and Attribution

If you use these reference goldens in scientific research, please cite:

**APA:**

> Costa, S. S. (2026). *luccme-goldens: Canonical Reference Execution Outputs for TerraME 2.0.1 and LuccME 3.1* (Version v1.0.0) [Data set]. Zenodo. https://doi.org/10.5281/zenodo.23107748

**BibTeX:**

```bibtex
@software{costa_2026_23107748,
  author       = {Costa, S{\'e}rgio Souza},
  title        = {luccme-goldens: Canonical Reference Execution Outputs for TerraME 2.0.1 and LuccME 3.1},
  month        = oct,
  year         = 2026,
  publisher    = {Zenodo},
  version      = {v1.0.0},
  doi          = {10.5281/zenodo.23107748},
  url          = {[https://doi.org/10.5281/zenodo.23107748](https://doi.org/10.5281/zenodo.23107748)}
}

```

Upstream TerraME and LuccME frameworks are Copyright (C) 2001–2017 INPE and TerraLAB/UFOP.

```

