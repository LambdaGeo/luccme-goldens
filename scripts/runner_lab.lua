-- ==============================================================================
-- runner_lab.lua — Universal Standalone Runner for LuccME Functional Labs
-- ==============================================================================

print("==> Initializing LuccME Runner...")

-- 1. Mock unitTest para evitar que o assertSnapshot trave
local mockUnitTest = {
    assertSnapshot = function(self, map, imgName)
        print("    [Snapshot captured]: " .. tostring(imgName))
    end
}

-- 2. Intercepta File:delete para PRESERVAR os shapefiles gerados!
local original_delete = File.delete
File.delete = function(self)
    local fname = tostring(self.name or "")
    if fname:match("%.shp$") or fname:match("%.dbf$") or fname:match("%.shx$") or fname:match("%.csv$") then
        print("    [Preserved Golden Artifact]: " .. fname)
        return true
    end
    return original_delete(self)
end

-- 3. Carrega o target_lab.lua do diretorio atual
local ok, module_or_err = pcall(dofile, "target_lab.lua")
if not ok then
    print("Error loading target_lab.lua: " .. tostring(module_or_err))
    os.exit(1)
end

if type(module_or_err) == "table" then
    local lab_name, lab_func = next(module_or_err)
    if type(lab_func) == "function" then
        print("==> Executing " .. tostring(lab_name) .. " simulation dynamics...")
        local run_ok, run_err = pcall(lab_func, mockUnitTest)
        if not run_ok then
            print("Simulation error in " .. tostring(lab_name) .. ": " .. tostring(run_err))
            os.exit(1)
        end
        print("==> " .. tostring(lab_name) .. " finished successfully!")
    else
        print("Error: No function found in target_lab.lua")
        os.exit(1)
    end
else
    print("Error: target_lab.lua did not return a table")
    os.exit(1)
end