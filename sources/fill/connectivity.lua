-------------------------------------------------------------------------------------------
-- TerraME 2.0.1 - Golden Reference: GPM Network Connectivity (e_connport)
-- Package: gpm
-------------------------------------------------------------------------------------------

import("gis")
import("gpm")

-- 1. Projeto e Dados Espaciais (dados oficiais do pacote GIS do TerraME)
amazonia = Project{
	file = "connectivity.qgs",
	clean = true,
	title = "Amazonia Network Connectivity",
	roads = filePath("amazonia-roads.shp", "gis"),
	ports = filePath("amazonia-ports.shp", "gis"),
	limit = filePath("amazonia-limit.shp", "gis")
}

-- 2. Grade Celular (50 km de resolução, EPSG:29191 / SAD69 Polyconic)
cells = Layer{
	project = amazonia,
	file = "connectivity.shp",
	clean = true,
	input = "limit",
	name = "cells",
	resolution = 50000,
	progress = false
}

-- 3. Espaços Celulares para o GPM
cs_roads = CellularSpace{
	project = amazonia,
	layer = "roads"
}

cs_ports = CellularSpace{
	project = amazonia,
	layer = "ports"
}

cs_cells = CellularSpace{
	project = amazonia,
	layer = "cells"
}

-- 4. Construção da Rede Viária (Network)
-- Distância dentro da rede (inside) com impedância e acesso fora da rede (outside)
net = Network{
	lines = cs_roads,
	target = cs_ports,
	progress = false,
	inside = function(distance, cell)
		-- Se a linha tiver atributo de pavimentação, pondera o custo/tempo
		if cell.status == "paved" or cell.status == "pavimentada" then
			return distance * 1.0
		else
			return distance * 2.0
		end
	end,
	outside = function(distance)
		-- Penalidade de acesso euclidiano da célula até a rodovia
		return distance * 2.0
	end
}

-- 5. Generalized Proximity Matrix (GPM)
gpm_matrix = GPM{
	origin = cs_cells,
	destination = net,
	progress = false
}

-- 6. Preenchimento do atributo de menor custo de viagem até o porto (e_connport)
gpm_matrix:fill{
	strategy = "minimum",
	attribute = "e_connport"
}

-- 7. Persistência do Shapefile de saída com o atributo calculado
cs_cells:save("connectivity.shp")

print(">>> Golden connectivity.shp gerado com sucesso pelo TerraME GPM! <<<")