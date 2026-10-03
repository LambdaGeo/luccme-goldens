-------------------------------------------------------------------------------------------
-- TerraME 2.0.1 - Parity test for the "mode" (majority / predominant class) fill operation.
-- Dataset: Itaituba / PA (5 km, EPSG:29191), deforestation raster (classes of the land cover).
--
-- "mode" is TerraME's name for the most common qualitative value among the pixels of a cell
-- (DisSCube: operator "majority"). The attribute is written as a string: when two or more
-- classes tie, all of them are listed, separated by comma (e.g. "7,87").
-------------------------------------------------------------------------------------------

import("gis")

itaituba = Project{
	file = "majority.tview",
	clean = true,
	census = filePath("itaituba-census.shp", "gis")
}

Layer{
	project = itaituba,
	name = "deforestation",
	file = filePath("itaituba-deforestation.tif", "gis"),
	epsg = 29191
}

cells = Layer{
	project = itaituba,
	name = "cells",
	clean = true,
	file = "majority.shp",
	input = "census",
	resolution = 5000,
	progress = false
}

cells:fill{
	operation = "mode",
	layer = "deforestation",
	attribute = "defor_mode",
	progress = false
}
