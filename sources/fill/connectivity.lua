-- ==============================================================================
-- TerraME 2.0.1 - Golden Reference: Generalized Transport Cost (GTC) / e_connport
-- Package: gpm
-- ==============================================================================

import("gis")
import("gpm")

print(">>> 1. Preparando dados na pasta de trabalho local...")
local cs_file = tostring(filePath("br_cs_5880_25x25km.shp", "gpm"))
os.execute("cp " .. string.gsub(cs_file, "%.shp", ".*") .. " .")

print(">>> 2. Criando o Projeto GIS com as camadas registradas...")
local proj = Project{
    file = "connectivity.qgs",
    clean = true,
    title = "GTC Brasil",
    cs = "br_cs_5880_25x25km.shp",
    roads = filePath("br_roads_5880.shp", "gpm"),
    ports = filePath("br_ports_5880.shp", "gpm")
}

-- Ao criar com project e layer, o CellularSpace ganha capacidade de persistência (save)
local cs = CellularSpace{
    project = proj,
    layer = "cs"
}

local roads = CellularSpace{
    project = proj,
    layer = "roads",
    missing = 0
}

local ports = CellularSpace{
    project = proj,
    layer = "ports"
}

print(string.format(">>> Dados vinculados ao projeto: %d celulas, %d trechos de rodovia, %d portos", #cs, #roads, #ports))

print(">>> 3. Construindo a rede de transportes (Network)...")
local network = Network{
    lines = roads,
    target = ports,
    progress = false,
    validate = false,
    inside = function(distance, line)
        return distance * 1e-3 * line.custo_ajus
    end,
    outside = function(distance)
        return distance * 1e-3 * 2
    end
}

print(">>> 4. Calculando GPM (menor custo de transporte ate os portos)...")
local gpm = GPM{
    destination = network,
    origin = cs,
    progress = true
}

gpm:fill{
    strategy = "minimum",
    attribute = "cost",
    copy = "NOME_MICRO"
}

print(">>> 5. Salvando Shapefile connectivity.shp no projeto...")
-- Agora o TerraME consegue gravar connectivity.shp com as novas colunas cost e NOME_MICRO!
cs:save("connectivity", {"cost", "NOME_MICRO"})

print(">>> Golden GTC gerado com sucesso! Arquivo connectivity.shp gravado. <<<")