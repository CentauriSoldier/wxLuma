local _wx = require("wx");
local _Pyramid = require("PyramidCanvas");
local PyramidCanvasTest = {};

--[[!
@fqxn Custom.PyramidCanvasTest.check
@desc Fails a standalone regression with a specific diagnostic.
!]]
local function check(bCondition, sMessage) assert(bCondition, sMessage); end

--[[!
@fqxn Custom.PyramidCanvasTest.runChecks
@desc Tests topology, independent state, atomic input validation, projection,
    zoom limits, native keyboard/wheel events, translucent raster output,
    cache reuse and cleanup. No framework demo or framework files are modified.
!]]
function PyramidCanvasTest.runChecks()
    _wx.wxGetApp():SetExitOnFrameDelete(false);
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Pyramid checks");
    local oCanvas = _Pyramid.create(oFrame);
    local oOther = _Pyramid.create(oFrame, {Rotation = {Yaw = -25, Pitch = 45, Roll = 5}, Zoom = 1.2});
    local oBitmap = _wx.wxBitmap(800, 540); local oDC = _wx.wxMemoryDC(); oDC:SelectObject(oBitmap);
    local nChecks = 0;
    --[[!
    @fqxn Custom.PyramidCanvasTest.runChecks.check
    @desc Records successful checks while preserving the assertion diagnostic.
    !]]
    local function fCheck(bCondition, sMessage) check(bCondition, sMessage); nChecks = nChecks + 1; end
    --[[!
    @fqxn Custom.PyramidCanvasTest.runChecks.pixels
    @desc Captures actual native drawing bytes without retaining native image handles.
    !]]
    local function fPixels()
        oCanvas.draw(oDC, 800, 540); local oImage = oBitmap:ConvertToImage(); local sData = oImage:GetData(); oImage:delete(); return sData;
    end
    local bOK, sError = xpcall(function()
        local tGeometry = oCanvas.getGeometry(800, 540);
        fCheck(#tGeometry.Faces == 4 and #tGeometry.Vertices == 5, "Exactly nine named face/vertex items.");
        fCheck(#tGeometry.Edges == 8, "Square pyramid contains exactly eight neighboring-vertex edges.");
        local tUnique, tDegree = {}, {0, 0, 0, 0, 0};
        for _, tEdge in ipairs(tGeometry.Edges) do
            local sKey = math.min(tEdge[1], tEdge[2])..":"..math.max(tEdge[1], tEdge[2]);
            fCheck(not tUnique[sKey], "Edges never duplicate."); tUnique[sKey] = true;
            tDegree[tEdge[1]], tDegree[tEdge[2]] = tDegree[tEdge[1]] + 1, tDegree[tEdge[2]] + 1;
        end
        fCheck(tDegree[1] == 3 and tDegree[2] == 3 and tDegree[3] == 3 and tDegree[4] == 3 and tDegree[5] == 4,
            "Base corners have three neighbors; apex connects to all four.");
        for _, tFace in ipairs(tGeometry.Faces) do
            fCheck(#tFace.Vertices == 3 and tFace.Color.A > 0 and tFace.Color.A < 255, "Each side is a colored translucent triangle.");
        end
        local tNames = oCanvas.getFaceNames(); tNames[1] = "Changed";
        fCheck(oCanvas.getFaceNames()[1] == "Side 1", "Name getters return independent values.");
        oCanvas.setFaceNames(tNames); tNames[1] = "Mutated";
        fCheck(oCanvas.getFaceNames()[1] == "Changed" and oOther.getFaceNames()[1] == "Side 1", "Name inputs and instances are independent.");
        fCheck(not pcall(oCanvas.setVertexNames, {"Too few"}) and oCanvas.getVertexNames()[5] == "Apex", "Invalid names reject atomically.");
        local tColors = oCanvas.getVertexColors(); tColors[1].A = 999;
        fCheck(not pcall(oCanvas.setVertexColors, tColors) and oCanvas.getVertexColors()[1].A == 185, "Invalid colors reject atomically.");
        fCheck(not pcall(oCanvas.setZoom, 0/0) and not pcall(oCanvas.setRotation, {Yaw = 1, Pitch = math.huge, Roll = 0}), "Nonfinite views reject.");
        local nEvents = 0; local fListener = oCanvas.on("viewChanged", function() nEvents = nEvents + 1; end);
        oCanvas.setZoom(999, true); oCanvas.setZoom(999, true);
        fCheck(oCanvas.getZoom() == 1.65 and nEvents == 1, "Zoom clamps high and only changed views notify.");
        oCanvas.setZoom(-999); fCheck(oCanvas.getZoom() == 0.6, "Zoom clamps low.");
        oCanvas.off("viewChanged", fListener); oCanvas.resetView(true); fCheck(nEvents == 1, "Event removal works.");
        oOther.setRotation({Yaw = 5, Pitch = 10, Roll = 0}); oOther.setZoom(0.6); oOther.resetView();
        fCheck(oOther.getRotation().Yaw == -25 and oOther.getRotation().Pitch == 45 and oOther.getZoom() == 1.2,
            "Reset restores the instance's configured initial view.");
        oCanvas.setRotation({Yaw = 392, Pitch = 380, Roll = 360});
        fCheck(oCanvas.getRotation().Yaw == 32 and oCanvas.getRotation().Pitch == 20 and oCanvas.getRotation().Roll == 0, "All rotation axes wrap predictably.");
        for _, nAngle in ipairs({-180, -90, 0, 90, 180}) do
            oCanvas.setRotation({Yaw = nAngle, Pitch = nAngle / 2, Roll = nAngle / 3});
            local tView = oCanvas.getGeometry(800, 540);
            for _, tPoint in ipairs(tView.Vertices) do fCheck(tPoint.X == tPoint.X and tPoint.Y == tPoint.Y and math.abs(tPoint.X) < 10000,
                "Full rotation keeps projection finite and outside the camera plane."); end
        end
        oCanvas.resetView(); local sInitial = fPixels(); fCheck(sInitial == fPixels(), "Cached repeat painting is pixel-identical.");
        oCanvas.setRotation({Yaw = 62, Pitch = 20, Roll = 0}); fCheck(sInitial ~= fPixels(), "Rotation changes actual raster output.");
        oCanvas.resetView(); oCanvas.setZoom(1.4); fCheck(sInitial ~= fPixels(), "Zoom changes actual raster output.");
        oCanvas.resetView(); oCanvas.setFacesVisible(false); fCheck(sInitial ~= fPixels(), "Wireframe-only mode removes translucent face fills.");
        oCanvas.setFacesVisible(true);
        local tTransparent = oCanvas.getFaceColors(); for _, tColor in ipairs(tTransparent) do tColor.A = 0; end
        oCanvas.setFaceColors(tTransparent); local sTransparent = fPixels();
        for _, tColor in ipairs(tTransparent) do tColor.A = 200; end
        oCanvas.setFaceColors(tTransparent); fCheck(sTransparent ~= fPixels(), "Per-face alpha affects actual composited pixels.");
        local tNodes = oCanvas.getVertexColors(); for _, tColor in ipairs(tNodes) do tColor.A = 0; end
        oCanvas.setVertexColors(tNodes); local sNoNodes = fPixels();
        for _, tColor in ipairs(tNodes) do tColor.A = 255; end
        oCanvas.setVertexColors(tNodes); fCheck(sNoNodes ~= fPixels(), "Per-vertex alpha affects marker pixels.");
        oCanvas.draw(oDC, 1, 1); oCanvas.draw(oDC, 317, 213); fCheck(true, "Tiny and resized viewports render without native errors.");
        oCanvas.resetView();
        local oKey = _wx.wxKeyEvent(_wx.wxEVT_KEY_DOWN); oKey.GetKeyCode = function() return _wx.WXK_RIGHT; end;
        oKey:SetId(oCanvas.Control:GetId()); oKey:SetEventObject(oCanvas.Control); oCanvas.Control:GetEventHandler():ProcessEvent(oKey); oKey:delete();
        fCheck(oCanvas.getRotation().Yaw == 37, "Native keyboard events rotate the canvas.");
        local oWheel = _wx.wxMouseEvent(_wx.wxEVT_MOUSEWHEEL);
        oWheel.GetWheelDelta = function() return 120; end; oWheel.GetWheelRotation = function() return 120; end;
        oWheel:SetId(oCanvas.Control:GetId()); oWheel:SetEventObject(oCanvas.Control); oCanvas.Control:GetEventHandler():ProcessEvent(oWheel); oWheel:delete();
        fCheck(math.abs(oCanvas.getZoom() - 1.12) < 1e-10, "Native wheel events zoom the canvas.");
        oCanvas.destroy(); oCanvas.destroy(); fCheck(not pcall(oCanvas.setZoom, 1), "Repeat-safe disposal rejects mutation.");
    end, debug.traceback);
    oCanvas.destroy(); oOther.destroy(); oDC:SelectObject(_wx.wxNullBitmap); oDC:delete(); oBitmap:delete();
    oFrame:Destroy(); _wx.wxGetApp():Yield(); assert(bOK, sError);
    print("Pyramid canvas: "..nChecks.." checks passed.");
end

--[[!
@fqxn Custom.PyramidCanvasTest.runInputChecks
@desc Exercises real mouse capture, drag rotation, click-versus-drag behavior,
    and named-item click delivery on a shown native demo. Used by -Smoke.
!]]
function PyramidCanvasTest.runInputChecks(oDemo)
    local oCanvas, oControl = oDemo.Canvas, oDemo.Canvas.Control;
    --[[!
    @fqxn Custom.PyramidCanvasTest.runInputChecks.mouse
    @desc Dispatches a native mouse event with explicit client coordinates.
    !]]
    local function fMouse(nType, nX, nY)
        local oEvent = _wx.wxMouseEvent(nType);
        oEvent.GetX = function() return nX; end; oEvent.GetY = function() return nY; end;
        oEvent:SetId(oControl:GetId()); oEvent:SetEventObject(oControl); oControl:GetEventHandler():ProcessEvent(oEvent); oEvent:delete();
    end
    oCanvas.resetView(); fMouse(_wx.wxEVT_LEFT_DOWN, 100, 100);
    check(oControl:HasCapture(), "Drag acquires native mouse capture.");
    fMouse(_wx.wxEVT_MOTION, 140, 125); fMouse(_wx.wxEVT_LEFT_UP, 140, 125);
    local tRotation = oCanvas.getRotation();
    check(math.abs(tRotation.Yaw - 50) < 1e-10 and math.abs(tRotation.Pitch - 31.25) < 1e-10, "Native drag rotates both axes.");
    check(not oControl:HasCapture(), "Drag releases native mouse capture.");
    oCanvas.resetView();
    local nWidth, nHeight = oControl:GetClientSizeWH();
    local oBitmap = _wx.wxBitmap(nWidth, nHeight); local oDC = _wx.wxMemoryDC(); oDC:SelectObject(oBitmap);
    local fDrawText = oDC.DrawText; local nLabelX, nLabelY; local nLabels = 0;
    oDC.DrawText = function(oTarget, sText, nX, nY)
        nLabels = nLabels + 1; if (sText == "Apex") then nLabelX, nLabelY = nX, nY; end
        return fDrawText(oTarget, sText, nX, nY);
    end;
    oCanvas.draw(oDC, nWidth, nHeight); oDC.DrawText = fDrawText;
    oDC:SelectObject(_wx.wxNullBitmap); oDC:delete(); oBitmap:delete();
    check(nLabels == 9 and nLabelX ~= nil, "All nine item names are drawn.");
    local tClicked; local fListener = oCanvas.on("itemClicked", function(tItem) tClicked = tItem; end);
    fMouse(_wx.wxEVT_LEFT_DOWN, nLabelX + 2, nLabelY + 2); fMouse(_wx.wxEVT_LEFT_UP, nLabelX + 2, nLabelY + 2);
    oCanvas.off("itemClicked", fListener);
    check(tClicked and tClicked.Kind == "vertex" and tClicked.Index == 5 and tClicked.Name == "Apex", "Native label click identifies the correct item.");
    fMouse(_wx.wxEVT_LEFT_DOWN, 100, 100); fMouse(_wx.wxEVT_MOTION, 120, 110);
    fMouse(_wx.wxEVT_LEFT_DCLICK, 120, 110);
    check(oCanvas.getRotation().Yaw == 32 and oCanvas.getZoom() == 1 and not oControl:HasCapture(), "Double-click resets and cancels capture.");
    print("Pyramid native input: 6 checks passed.");
end

--[[!
@fqxn Custom.PyramidCanvasTest.createDemo
@desc Opens an independent demo with nine example names, translucent item colors,
    rotation/zoom instructions, a wireframe toggle and a reset action. Returns
    Frame/Canvas so an embedding host can run its own event loop or smoke check.
!]]
function PyramidCanvasTest.createDemo()
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Custom pyramid canvas", _wx.wxDefaultPosition, _wx.wxSize(1040, 760));
    local oPanel = _wx.wxPanel(oFrame, _wx.wxID_ANY);
    local oHeading = _wx.wxStaticText(oPanel, _wx.wxID_ANY, "Four colored sides + five colored vertices | translucent structural view");
    local oHint = _wx.wxStaticText(oPanel, _wx.wxID_ANY, "Drag to rotate | Wheel to zoom | Arrow keys and +/- | Home or double-click to reset | Click a name for details");
    local oCanvas = _Pyramid.create(oPanel, {FaceNames = {"North", "East", "South", "West"},
        VertexNames = {"Northwest", "Northeast", "Southeast", "Southwest", "Apex"}});
    local oReset = _wx.wxButton(oPanel, _wx.wxID_ANY, "Reset view");
    local oWire = _wx.wxCheckBox(oPanel, _wx.wxID_ANY, "Show translucent faces"); oWire:SetValue(true);
    local oStatus = _wx.wxStaticText(oPanel, _wx.wxID_ANY, "Zoom 100% | Yaw 32 | Pitch 20");
    local oActions = _wx.wxBoxSizer(_wx.wxHORIZONTAL);
    oActions:Add(oReset, 0, _wx.wxRIGHT, 16); oActions:Add(oWire, 0, _wx.wxALIGN_CENTER_VERTICAL + _wx.wxRIGHT, 20);
    oActions:Add(oStatus, 1, _wx.wxALIGN_CENTER_VERTICAL);
    local oSizer = _wx.wxBoxSizer(_wx.wxVERTICAL);
    oSizer:Add(oHeading, 0, _wx.wxALL, 12); oSizer:Add(oHint, 0, _wx.wxLEFT + _wx.wxRIGHT + _wx.wxBOTTOM, 12);
    oSizer:Add(oCanvas.Control, 1, _wx.wxEXPAND + _wx.wxLEFT + _wx.wxRIGHT, 12); oSizer:Add(oActions, 0, _wx.wxEXPAND + _wx.wxALL, 12);
    oPanel:SetSizer(oSizer);
    local oFrameSizer = _wx.wxBoxSizer(_wx.wxVERTICAL); oFrameSizer:Add(oPanel, 1, _wx.wxEXPAND); oFrame:SetSizer(oFrameSizer);
    oReset:Connect(_wx.wxEVT_COMMAND_BUTTON_CLICKED, function() oCanvas.resetView(true); end);
    oWire:Connect(_wx.wxEVT_COMMAND_CHECKBOX_CLICKED, function() oCanvas.setFacesVisible(oWire:GetValue()); end);
    oCanvas.on("viewChanged", function(tEvent)
        oStatus:SetLabel(string.format("Zoom %.0f%% | Yaw %.0f | Pitch %.0f", tEvent.Zoom * 100, tEvent.Rotation.Yaw, tEvent.Rotation.Pitch));
    end);
    oCanvas.on("itemClicked", function(tItem) oStatus:SetLabel(tItem.Kind.." "..tItem.Index..": "..tItem.Name); end);
    oFrame:Connect(_wx.wxEVT_CLOSE_WINDOW, function(oEvent) oCanvas.destroy(); oEvent:Skip(); end);
    return {Frame = oFrame, Canvas = oCanvas};
end

return PyramidCanvasTest;
