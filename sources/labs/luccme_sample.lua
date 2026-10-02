-- Minimal LuccME example model
-- Usage: docker compose run --rm terrame luccme_sample.lua
--    or: docker run --rm -v "$PWD/models":/work profsergiocosta/terrame-luccme luccme_sample.lua

import("gis")
import("luccme")

print("Initializing LuccME sample model...")

local projFile = File("t3mp.tview")
if projFile:exists() then
	projFile:delete()
end

local proj = Project{
	file = "t3mp.tview",
	clean = true
}

local l1 = Layer{
	project = proj,
	name = "layer",
	file = filePath("test/csAC.shp", "luccme")
}

print("Loaded spatial layer: " .. l1.name)

local model = LuccMEModel{
	name = "SampleLuccME",
	startTime = 2008,
	endTime = 2010,
	cs = CellularSpace{
		project = proj,
		layer = l1.name,
		cellArea = 25
	},
	landUseTypes = { "f", "d", "outros" },
	landUseNoData = "outros",
	demand = DemandPreComputedValues{
		annualDemand = {
			{137878.1691, 19982.62882, 6489.202049}, -- 2008
			{137622.2199, 20238.57805, 6489.202049}, -- 2009
			{137366.2707, 20494.52729, 6489.202049}  -- 2010
		}
	},
	potential = PotentialCLinearRegression{
		potentialData = {
			{
				-- Region 1: Forest (f)
				{
					isLog = false,
					const = 0.7392,
					betas = { assentamen = -0.2193, uc_us = 0.1754, fertilidad = -0.1313 }
				},
				-- Region 1: Deforestation (d)
				{
					isLog = false,
					const = 0.267,
					betas = { assentamen = 0.2294, rodovias = -0.0000009922, fertilidad = 0.1281 }
				},
				-- Region 1: Others (outros)
				{
					isLog = false,
					const = 0,
					betas = {}
				}
			}
		}
	},
	allocation = AllocationCClueLike{
		maxDifference = 5000,
		maxIteration = 100,
		initialElasticity = 0.1,
		minElasticity = 0.001,
		maxElasticity = 1.5,
		complementarLU = "f",
		allocationData = {
			{
				{ static = -1, minValue = 0, maxValue = 1, minChange = 0, maxChange = 1, changeLimiarValue = 1, maxChangeAboveLimiar = 0 },
				{ static = -1, minValue = 0, maxValue = 1, minChange = 0, maxChange = 1, changeLimiarValue = 1, maxChangeAboveLimiar = 0 },
				{ static = 1, minValue = 0, maxValue = 1, minChange = 0, maxChange = 1, changeLimiarValue = 1, maxChangeAboveLimiar = 0 }
			}
		}
	},
	save = {
		outputTheme = "SampleOut_",
		mode = "multiple",
		saveYears = { 2010 },
		saveAttrs = { "d_out" }
	},
	isCoupled = false
}

print("Running simulation from 2008 to 2010...")
local timer = Timer{
	Event{
		start = model.startTime,
		action = function(event)
			model:run(event)
			print("Simulated year: " .. event:getTime())
		end
	}
}

local env = Environment{}
env:add(timer)
env:run(model.endTime)

print("LuccME simulation finished successfully!")

if projFile:exists() then
	projFile:delete()
end
