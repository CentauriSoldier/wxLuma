local _Layout = require("wxLuma.Core.SkinLayout");
local SkinLayoutRegression = {};

--[[!
@fqxn wxLuma.Tests.SkinLayoutRegression.run
@desc Verifies the mandatory per-object layout, including shared artwork
    families and custom prefixes. Resolution never probes a flat directory.
@ret number nChecks Successful layout assertions.
!]]
function SkinLayoutRegression.run()
    local nChecks = 0;
    local fOpen = io.open;
    -- A flat file would appear to exist if the resolver attempted a probe.
    -- The mandatory layout must resolve deterministically without filesystem IO.
    io.open = function() error("Skin resolution must not probe flat files."); end;
    local bOK, sError = xpcall(function()
        for _, tCase in ipairs({
            {"Button Left Normal", "PushButton"},
            {"Dropdown Arrow Normal", "Dropdown"},
            {"Iris Progress Fill Normal", "IrisProgress"},
            {"Circular Progress Track Disabled", "CircularProgress"},
            {"Property Grid Surface Normal", "PropertyGrid"},
            {"Menu Row Normal", "ContextMenu"},
            {"Menu Circle Normal", "RadialMenu"},
            {"Log Viewer Icon Normal", "LogViewer"},
            {"Custom Fill Normal", "Custom"},
        }) do
            for _, sRoot in ipairs({"Skins/Obsidian", "Skins/Obsidian/", "Skins/Obsidian\\"}) do
                assert(_Layout.path(sRoot, tCase[1]) == "Skins/Obsidian/"..tCase[2].."/Control "..tCase[1]..".png",
                    "Artwork must resolve inside its object's directory.");
                nChecks = nChecks + 1;
            end
        end
    end, debug.traceback);
    io.open = fOpen;
    assert(bOK, sError);
    print("Skin layout regression: "..nChecks.." checks passed.");
    return nChecks;
end

return SkinLayoutRegression;
