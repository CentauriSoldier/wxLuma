local _wx = require("wx");
local PolygonProgressRegression = {};

--[[!
@fqxn wxLuma.Tests.PolygonProgressRegression.run
@desc Exercises real polygon/rectangular radial painters in both themes, both
    enabled states, both supersampling settings and every numeric fill/reserve
    direction pairing, including automatic reserve and all capacity endpoints.
    Validation, concave geometry, state, cache reuse and disposal are checked too.
!]]
function PolygonProgressRegression.run()
    local oLuma = require("wxLuma")();
    local P = oLuma.Progress;
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Polygon progress regression");
    oFrame:SetBackgroundColour(_wx.wxColour(0, 0, 0));
    local oTheme = require("wxLuma.Core.ControlTheme").create("System", oLuma.Config.SkinPath);
    local oBitmap, oDC = _wx.wxBitmap(32, 32), _wx.wxMemoryDC(); oDC:SelectObject(oBitmap);
    local tOwned, nChecks, nRenders = {}, 0, 0;
    local tPolygon = {{X = 0.5, Y = 0}, {X = 1, Y = 0.3}, {X = 0.85, Y = 1}, {X = 0.15, Y = 1}, {X = 0, Y = 0.3}};
    local tConcave = {{X = 0, Y = 0}, {X = 1, Y = 0}, {X = 0.6, Y = 0.5}, {X = 1, Y = 1}, {X = 0, Y = 1}, {X = 0.3, Y = 0.5}};

    --[[!
    @fqxn wxLuma.Tests.PolygonProgressRegression.run.check
    @desc Counts successful native rendering or public API assertions.
    !]]
    local function fCheck(bValue, sMessage) assert(bValue, sMessage); nChecks = nChecks + 1; end
    local bOK, sError = xpcall(function()
        local nChildren = oFrame:GetChildren():GetCount();
        for _, tBad in ipairs({{}, {{X = 0, Y = 0}, {X = 1, Y = 1}},
            {{X = 0, Y = 0}, {X = 1, Y = 1}, {X = 0, Y = 1}, {X = 1, Y = 0}},
            {{X = 0, Y = 0}, {X = 0.5, Y = 0}, {X = 1, Y = 0}},
            {{X = -0.1, Y = 0}, {X = 1, Y = 0}, {X = 0.5, Y = 1}},
            {[1] = {X = 0, Y = 0}, [3] = {X = 1, Y = 1}}}) do
            fCheck(not pcall(oLuma.Controls.progress, oFrame, {Shape = 2, Polygon = tBad, Min = 0, Max = 100, Value = 50})
                and oFrame:GetChildren():GetCount() == nChildren, "Malformed polygons fail before native allocation.");
        end
        fCheck(not pcall(oLuma.Controls.progress, oFrame, {Shape = 2, Polygon = tPolygon, Min = 0, Max = 100, Value = 50, ReserveRenderer = "native"}),
            "Disc-only native reservation is rejected explicitly for polygons.");
        for _, sTheme in ipairs({"System", "Obsidian"}) do
            oTheme.setName(sTheme);
            for _, shape in ipairs({P.Shape.RECTANGLE, P.Shape.POLYGON}) do
                for mode = 0, 2 do
                    if (shape == P.Shape.POLYGON or mode ~= P.Fill.LINEAR) then
                        for direction = 0, 1 do
                            for _, reserve in ipairs({"auto", 0, 1}) do
                                for _, scale in ipairs({2, 4}) do
                                    local oMeter = oLuma.Controls.progress(oFrame, {Theme = oTheme, Shape = shape, FillMode = mode,
                                        Polygon = tPolygon, Direction = direction, ReserveDirection = reserve ~= "auto" and reserve or nil,
                                        Min = 10, Max = 110, Value = 60, Text = "", Outline = false, Supersampling = scale});
                                    tOwned[#tOwned + 1] = oMeter; oMeter.layout(0, 0, 32, 32);
                                    fCheck(oMeter.getShape() == shape and oMeter.getFillMode() == mode and oMeter.getFillDirection() == direction,
                                        "All shape/mode/direction selectors reach the real painter.");
                                    for _, reserved in ipairs({0, 25, 50, 75, 100}) do
                                        oMeter.setReserved(reserved);
                                        for _, value in ipairs({10, 35, 60, 85, 110}) do
                                            oMeter.setValue(value);
                                            fCheck(oMeter.getValue() == math.min(value, 110 - reserved), "Polygon capacity clamps at every reserved amount.");
                                            for _, enabled in ipairs({true, false}) do
                                                oMeter.setEnabled(enabled); oMeter.draw(oDC, 32, 32); nRenders = nRenders + 1;
                                            end
                                        end
                                    end
                                    oMeter.setEnabled(true); oMeter.setReserved(25); oMeter.setValue(60);
                                    if (mode == 2) then
                                        local nAngles = 0;
                                        oMeter.on("startAngleChanged", function() nAngles = nAngles + 1; end);
                                        oMeter.setStartAngle(360, true); oMeter.setStartAngle(45, true); oMeter.setStartAngle(405, true);
                                        fCheck(nAngles == 1 and oMeter.getStartAngle() == 45, "Equivalent wrapped arc angles remain silent.");
                                    end
                                    if (shape == P.Shape.POLYGON) then
                                        local nGeometryEvents = 0;
                                        oMeter.on("polygonChanged", function() nGeometryEvents = nGeometryEvents + 1; end);
                                        local tCopy = oMeter.getPolygon(); tCopy[1].X = 0.1;
                                        fCheck(oMeter.getPolygon()[1].X == 0.5, "Polygon getters detach vertex data.");
                                        local tState = oMeter.getObjectState();
                                        oMeter.setPolygon(tConcave, true); oMeter.setPolygon(tConcave, true);
                                        fCheck(nGeometryEvents == 1, "Identical polygon replacements neither notify nor rebuild geometry.");
                                        oMeter.draw(oDC, 32, 32); nRenders = nRenders + 1;
                                        fCheck(not pcall(oMeter.setPolygon, {{X = 0, Y = 0}}) and #oMeter.getPolygon() == 6,
                                            "Rejected polygon updates preserve a live concave silhouette.");
                                        oMeter.setObjectState(tState);
                                        fCheck(#oMeter.getPolygon() == 5 and oMeter.getReserved() == 25 and oMeter.getValue() == 60,
                                            "Polygon vertices, reserved capacity and current restore together.");
                                    end
                                    oMeter.draw(oDC, 32, 32);
                                    local fBitmap, nBitmaps = _wx.wxBitmap, 0;
                                    _wx.wxBitmap = function(...) nBitmaps = nBitmaps + 1; return fBitmap(...); end;
                                    local bDrawn, sDrawError = pcall(oMeter.draw, oDC, 32, 32);
                                    _wx.wxBitmap = fBitmap;
                                    fCheck(bDrawn and nBitmaps == 0, "Unchanged polygon rendering reuses its raster: "..tostring(sDrawError));
                                    local tGeometryModule = require("wxLuma.Core.ProgressShapeGeometry");
                                    local fPrepare, nPrepared = tGeometryModule.prepare, 0;
                                    tGeometryModule.prepare = function(...) nPrepared = nPrepared + 1; return fPrepare(...); end;
                                    nBitmaps = 0; _wx.wxBitmap = function(...) nBitmaps = nBitmaps + 1; return fBitmap(...); end;
                                    bDrawn, sDrawError = pcall(function()
                                        for nUpdate = 1, 5 do oMeter.setValue(20 + nUpdate); oMeter.draw(oDC, 32, 32); end
                                    end);
                                    tGeometryModule.prepare, _wx.wxBitmap = fPrepare, fBitmap;
                                    fCheck(bDrawn and nPrepared == 0 and nBitmaps == 5,
                                        "Value-only updates reuse geometry, reserve base and work buffers: "..tostring(sDrawError));
                                    oMeter.destroy(); oMeter.Control:Destroy();
                                end
                            end
                        end
                    end
                end
            end
            _wx.wxYield();
        end
    end, debug.traceback);
    for _, oMeter in ipairs(tOwned) do if (not oMeter.Disposed) then oMeter.destroy(); oMeter.Control:Destroy(); end end
    oDC:SelectObject(_wx.wxNullBitmap); oDC:delete(); oBitmap:delete(); oFrame:Destroy(); _wx.wxYield();
    oTheme.destroy(); oLuma.Theme.destroy(); assert(bOK, sError);
    print(string.format("Polygon progress regression: %d checks, %d native renders passed.", nChecks, nRenders));
    return nChecks;
end

return PolygonProgressRegression;
