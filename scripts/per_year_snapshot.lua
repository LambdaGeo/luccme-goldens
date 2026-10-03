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
					local row = {year, tostring(cell.id or cell.object_id_ or cell.object_id0)}
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
