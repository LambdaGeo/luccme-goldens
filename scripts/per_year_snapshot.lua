-- ==============================================================================
-- per_year_snapshot.lua — per-year state recorder for LuccME labs
--
-- Inlined by scripts/lab_per_year.py into a standalone copy of a lab, right after
-- `env_<Lab>:add(timer)`. It adds one extra Timer to the Environment with an Event
-- of priority 22: it runs after the model step (priority 0) and after the
-- databaseSave events (priorities 20 and 21), so it sees the final state of each
-- year without touching the lab's own `save` parameters.
--
-- Why not just list every year in `save.saveYears`? Because the allocation
-- components use `belong(time, saveYears)` to manage `<lu>_backupYear`, `_chpast`
-- and to restore `cell[<lu>]`, so changing it changes the simulation itself.
--
-- Cell ids are captured when the recorder is created, before any year runs.
-- LuccMEModel:dinamicVars() (labs with `updateYears`) overwrites every cell
-- attribute that also exists in the csAC_<year> layer, `id` included, pairing the
-- two spaces by position; reading cell.id each year would relabel the cells from
-- the first update year on (the values stay with the right cell, the ids do not).
--
-- Output: CSV `year,id,<lu>_out...,<lu>_pot...`, one row per cell per year,
-- 12 decimal places; a missing attribute is written as `nan`.
-- ==============================================================================
function perYearSnapshot(model, path)
	local fh = assert(io.open(path, "w"))
	local lus = model.landUseTypes

	local header = {"year", "id"}
	for _, lu in ipairs(lus) do header[#header + 1] = lu .. "_out" end
	for _, lu in ipairs(lus) do header[#header + 1] = lu .. "_pot" end
	fh:write(table.concat(header, ",") .. "\n")

	local ids = {}
	forEachCell(model.cs, function(cell)
		ids[cell] = tostring(cell.id or cell.object_id_ or cell.object_id0)
	end)

	local function fmt(v)
		if type(v) ~= "number" then return "nan" end
		return string.format("%.12f", v)
	end

	return Timer{
		Event{
			start = model.startTime,
			priority = 22,
			action = function(event)
				local year = string.format("%d", event:getTime())
				forEachCell(model.cs, function(cell)
					local id = ids[cell]
					if id == nil then error("cell not present when the recorder was created") end
					local row = {year, id}
					for _, lu in ipairs(lus) do row[#row + 1] = fmt(cell[lu .. "_out"]) end
					for _, lu in ipairs(lus) do row[#row + 1] = fmt(cell[lu .. "_pot"]) end
					fh:write(table.concat(row, ",") .. "\n")
				end)
				fh:flush()
				return true
			end
		}
	}
end
