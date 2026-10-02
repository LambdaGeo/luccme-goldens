
# luccme-goldens

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Docker Image](https://img.shields.io/badge/Docker-profsergiocosta%2Fterrame--luccme-blue)](https://hub.docker.com/r/profsergiocosta/terrame-luccme)
[![Open Science](https://img.shields.io/badge/Open%20Science-Reproducible%20Goldens-green.svg)](#)
[![DOI](https://zenodo.org/badge/1402144728.svg)](https://doi.org/10.5281/zenodo.23107747)

**Canonical Reference Execution Outputs (Goldens) for TerraME 2.0.1 and LuccME 3.1.**

This repository serves as the **Level 1 (Reference Goldens)** foundation for the paper:
> *"Declarative Spatial Data Cubes and Verifiable Provenance for Reproducible Land-Use Change Modelling: A Three-Level Replication of LuccME"*  
> Submitted to **Big Earth Data** (Taylor & Francis / CBAS).

---

## 1. Scientific Motivation

In environmental simulation science, proving that a newly engineered model (`disslucc` / `disscube`) faithfully replicates a legacy system (`TerraME` / `LuccME`) requires strict numerical parity against immutable reference outputs ("goldens").

Because TerraME 2.0.1 depends on a legacy Ubuntu 18.04 runtime, running the original model scripts on modern operating systems can be difficult. This repository solves that challenge through a dual approach:
1. **Pre-computed, Verifiable Goldens (No Re-run Needed):** Every reference CSV and baseline dataset is pre-computed, versioned, hashed with SHA-256, and published as a GitHub Release asset (and archived on Zenodo with DOI). Downstream projects ingest them in seconds via `Pooch`.
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
| **Lab10** | Discrete | `PotentialDNeighSimpleRule` + `AllocationDSimpleOrdering` | Moju/BR-163 (`cs_moju.shp`, 500 m) |
| **Lab11** | Discrete | `PotentialDInverseDistanceRule` + `AllocationDSimpleOrdering` | Moju/BR-163 (`cs_moju.shp`, 500 m) |
| **Lab12** | Discrete | `PotentialDNeighInverseDistanceRule` + `AllocationDSimpleOrdering` | Moju/BR-163 (`cs_moju.shp`, 500 m) |
| **Lab13** | Discrete | `PotentialDLogisticRegression` | Moju/BR-163 (`cs_moju.shp`, 500 m) |
| **Lab14** | Discrete | `PotentialDLogisticRegressionNeighAttract` + `AllocationDClueSLike` | Moju/BR-163 (`cs_moju.shp`, 500 m) |
| **Lab15** | Discrete | **`DemandPreComputed` + `PotentialDLogisticRegression` + `AllocationDClueSLike`** | **Moju/BR-163 (Paper Case 1)** |
| **Lab16** | Discrete | `DemandComputeTwoDates` + `PotentialDLogisticRegression` + `AllocationDClueSLike` | Moju/BR-163 (`cs_moju.shp`) |
| **Lab17** | Discrete | `DemandComputeThreeDates` + `PotentialDLogisticRegression` + `AllocationDClueSLike` | Moju/BR-163 (`cs_moju.shp`) |
| **Lab18** | Discrete | `PotentialDSampleBased` + `AllocationDClueSLike` | Moju/BR-163 (`cs_moju.shp`) |
| **Lab19** | Discrete | `PotentialDLogisticRegressionNeighAttractRepulsion` + `AllocationDClueSNeighOrdering` | Moju/BR-163 (`cs_moju.shp`) |
| **Lab20** | Mixed | `PotentialDLogisticRegressionNeighAttractRepulsion` + `AllocationCClueLike` | Moju/BR-163 (`cs_moju.shp`) |
| **Lab21** | Discrete | `PotentialDLogisticRegressionNeighAttractRepulsion` + `AllocationDClueSNeighOrdering` | Moju/BR-163 (`cs_moju.shp`) |

### Suite B: TerraME GIS Fill Cellular Space (`sources/fill/` → `goldens/fill/`)
Validates spatial aggregation and feature extraction on cellular grids against TerraME's `cl:fill{}`:

| Dataset | Grid Dimensions | Spatial CRS | Evaluated Operators |
| :--- | :--- | :--- | :--- |
| **`itaituba`** | 620 cells, 5 km | SIRGAS 2000 UTM 21S (EPSG:29191) | `average` (elevation), `coverage` (deforestation), `distance` (roads, localities), `sum` (population) |
| **`amazonia`** | 2,229 cells, 50 km | SIRGAS 2000 UTM 21S (EPSG:29191) | `coverage` (PRODES), `distance` (roads, ports), `area` (protected reserves) |
| **`emas`** | 5,514 cells, 500 m | SAD69 UTM 22S (EPSG:29192) | `presence` (firebreak, rivers), `maximum` & `minimum` (vegetation cover) |

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

### 3. Run All TerraME GIS Fill Cases

```bash
make run-fill

```

Executes `itaituba.lua`, `amazonia.lua`, and `emas.lua`, extracting cell attributes.

### 4. Build Release Package and Checksums

```bash
make package

```

Generates `checksums.sha256`, `manifest.json`, and `release/luccme-goldens-v1.0.0.zip`.

---

## 5. Repository Structure

```text
luccme-goldens/
├── Makefile                       # Main entry point: run-labs, run-fill, package
├── README.md                      # Comprehensive documentation and catalog
├── LICENSE                        # MIT and LGPL-3.0 attribution
├── checksums.sha256               # SHA-256 cryptographic hashes of all goldens
├── manifest.json                  # Machine-readable artifact manifest
│
├── sources/                       # Canonical upstream model scripts and input layers
│   ├── labs/                      # lab01.lua to lab21.lua (LuccME 3.1 upstream models)
│   └── fill/                      # itaituba.lua, amazonia.lua, emas.lua
│
├── scripts/                       # Automated execution and formatting harnesses
│   ├── run_all_labs.sh            # Batch and single-lab runner for LuccME simulation labs
│   ├── run_all_fill.sh            # Batch runner for TerraME GIS fill scripts
│   ├── export_reference.py        # Spatial parser converting SHP to standardized CSV
│   └── package_release.sh         # Release archiver and hash generator
│
├── goldens/                       # Reference outputs
│   ├── fill/                      # itaituba_terrame.csv, amazonia_terrame.csv, emas_terrame.csv
│   └── labs/                      # Canonical CSVs (tracked) and .zip shapefiles (local only)
│
└── release/                       # Release archive bundle for GitHub Releases / Zenodo
    └── luccme-goldens-v1.0.0.zip

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

Upstream TerraME and LuccME frameworks are Copyright (C) 2001–2017 INPE and TerraLAB/UFOP.

```

