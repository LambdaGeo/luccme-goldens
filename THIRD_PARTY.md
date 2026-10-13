# Third-party material and licences

This repository mixes four kinds of content. Each has its own origin and licence.

| Path | What it is | Origin (fixed commit) | Licence |
|---|---|---|---|
| `scripts/`, `Makefile`, `release/`, `sources/fill/majority.lua`, `sources/fill/connectivity.lua`, `sources/labs/luccme_sample.lua` | Our code (harness, runners, two parity cases) | this repository | MIT (`LICENSE`) |
| `sources/labs/lab01.lua` to `lab21.lua` | LuccME functional tests, **byte-identical** to `tests/functional/` | [TerraME/luccme](https://github.com/TerraME/luccme) commit `6244dd461f94259efb6e1d2170d32fc7e28c033c` (27 Mar 2019, "LuccME version 3.1 for Terrame integration") | LGPL-3.0, CCST/INPE |
| `sources/labs/data/` (`csAC`, `csAC_2009`, `csAC_cenarioA_2020`, `cs_moju`) | Cell layers used by the labs, **byte-identical** to `data/test/` | same LuccME commit; SHA-256 in `sources/labs/data/UPSTREAM.sha256` | LGPL-3.0, CCST/INPE |
| `sources/fill/amazonia.lua`, `emas.lua`, `itaituba.lua` | Data-creation scripts of the `gis` package, **byte-identical** to `packages/gis/data/` | [TerraME/terrame](https://github.com/TerraME/terrame) commit `84faddc4e5149a89d7486444b61b8c50474e199c` | LGPL-3.0 (INPE and TerraLAB/UFOP) |
| `goldens/` | Values computed by TerraME 2.0.1 / LuccME 3.1 from the layers above and from the `gis` and `gpm` data of the image, plus our hashes and timing | this repository, generated with [`terrame-docker`](https://github.com/profsergiocosta/terrame-docker) 0.4.2 | see below |

## The goldens

The `goldens/` CSVs are the output of upstream software run on upstream data. We claim no
rights over the input values they carry (the attributes of the LuccME layers, and the geometry-derived
values of the `gis` and `gpm` example data); those stay under the licence of their origin (LGPL-3.0, above).
What we add (selection, organisation, hashes, timing, the per-year series and the documentation) is
offered under CC-BY-4.0. Reuse the goldens with attribution to this repository and to INPE and TerraLAB/UFOP.

## What is not stored here

The `gis` data (`amazonia-*`, `emas-*`, `itaituba-*`) and the `gpm` data (`br_roads_5880`, `br_ports_5880`,
`br_cs_5880_25x25km`) are not copied into this repository. They come with the TerraME 2.0.1 binary and the
gpm 0.6 package inside the `terrame-docker` image. The downstream benchmark fetches them from fixed upstream commits
(TerraME/terrame `84faddc`, TerraME/gpm `3aa0e91498f37d1b55adbe54d5d0fda3137f251f`) and checks each SHA-256
(see `disscube-benchmark/THIRD_PARTY.md`).

The `gpm` package declares LGPL-3 in `description.lua` and carries the GPL-3 text in `license.txt`; we only run it.
