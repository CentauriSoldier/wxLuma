local _wx = require("wx");
local ImageViewerRegression = {};

--[[!
@fqxn wxLuma.Tests.ImageViewerRegression.run
@desc Checks known RGBA source data, zoom anchoring, selection/cancellation,
    native input routing, crop-before-scale bounds, bitmap reuse, theme changes
    and disposal. A generated PNG fixture is removed after success or failure.
@ret number nChecks Successful behavior assertions.
!]]
function ImageViewerRegression.run()
    local oLuma = require("wxLuma")();
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Image viewer regression");
    local pFixture = os.tmpname();
    local oViewer, nChecks = nil, 0;
    local bOriginalExit = _wx.wxGetApp():GetExitOnFrameDelete();
    _wx.wxGetApp():SetExitOnFrameDelete(false);

    --[[!
    @fqxn wxLuma.Tests.ImageViewerRegression.fCheck
    @desc Counts a successful behavior check with a useful failure message.
    !]]
    local function fCheck(bValue, sMessage)
        assert(bValue, sMessage); nChecks = nChecks + 1;
    end

    --[[!
    @fqxn wxLuma.Tests.ImageViewerRegression.fNear
    @desc Compares coordinate conversions without requiring exact binary floats.
    !]]
    local function fNear(nLeft, nRight) return math.abs(nLeft - nRight) < 0.000001; end

    --[[!
    @fqxn wxLuma.Tests.ImageViewerRegression.fPaint
    @desc Renders into an independent destination and returns RGB bytes without
        resizing the viewer's native window or changing its live geometry.
    !]]
    local function fPaint(nWidth, nHeight)
        local oBitmap = _wx.wxBitmap(nWidth, nHeight);
        local oDC = _wx.wxMemoryDC(); oDC:SelectObject(oBitmap);
        oViewer.draw(oDC, nWidth, nHeight);
        oDC:SelectObject(_wx.wxNullBitmap); oDC:delete();
        local oImage = oBitmap:ConvertToImage(); local sPixels = oImage:GetData();
        oImage:delete(); oBitmap:delete(); return sPixels;
    end

    --[[!
    @fqxn wxLuma.Tests.ImageViewerRegression.fMouse
    @desc Sends a native event through the production observer/policy chain.
        Read-only wxLua input accessors are supplied by this native fixture.
    !]]
    local function fMouse(nType, nX, nY)
        local oEvent = _wx.wxMouseEvent(nType);
        oEvent.GetX = function() return nX; end;
        oEvent.GetY = function() return nY; end;
        oEvent.GetWheelRotation = function() return 120; end;
        oEvent.GetWheelDelta = function() return 120; end;
        oEvent:SetEventObject(oViewer.Control); oEvent:SetId(oViewer.Control:GetId());
        oViewer.Control:GetEventHandler():ProcessEvent(oEvent); oEvent:delete();
    end

    local bOK, sError = xpcall(function()
        -- Known source bytes make pixel inspection independent of display colors.
        local tRGB, tAlpha = {}, {};
        for nY = 0, 31 do
            for nX = 0, 63 do
                tRGB[#tRGB + 1] = string.char(nX * 4, nY * 8, 127);
                tAlpha[#tAlpha + 1] = string.char(nX == 0 and 0 or 192);
            end
        end
        local oSource = _wx.wxImage(64, 32);
        oSource:SetData(table.concat(tRGB)); oSource:SetAlpha(table.concat(tAlpha));
        local bSaved = oSource:SaveFile(pFixture, _wx.wxBITMAP_TYPE_PNG); oSource:delete();
        fCheck(bSaved, "Save the deterministic RGBA fixture.");
        oViewer = oLuma.Controls.imageViewer(oFrame, {Value = pFixture, Border = _wx.wxBORDER_NONE});
        oViewer.layout(0, 0, 128, 96); oFrame:SetClientSize(128, 96);
        fCheck(next(oViewer) == nil and getmetatable(oViewer) == "wxLuma.UI.ImageViewer", "Public object follows the decoy convention.");
        local nW, nH = oViewer.getImageSize();
        fCheck(nW == 64 and nH == 32, "Source dimensions survive decoding.");
        fCheck(fNear(oViewer.getZoom(), 2), "Fit contains a 2:1 image in a taller viewport.");
        local nX, nY = oViewer.imageToClient(0, 0);
        fCheck(fNear(nX, 0) and fNear(nY, 16), "Fit centers the image with letterboxing.");
        local nSourceX, nSourceY, bInside = oViewer.clientToImage(10, 26);
        fCheck(fNear(nSourceX, 5) and fNear(nSourceY, 5) and bInside, "Coordinate mapping accounts for letterboxing.");
        local _, _, bOutside = oViewer.clientToImage(10, 0);
        fCheck(not bOutside, "Letterbox coordinates are outside the image.");
        local tPixel = oViewer.getPixel(5, 7);
        fCheck(tPixel.Red == 20 and tPixel.Green == 56 and tPixel.Blue == 127 and tPixel.Alpha == 192, "Pixel inspection returns original RGBA bytes.");
        fCheck(oViewer.getPixel(0, 0).Alpha == 0, "Fully transparent source pixels remain inspectable.");
        fCheck(oViewer.getPixel(-1, 0) == nil and oViewer.getPixel(64, 0) == nil, "Out-of-bounds pixels return nil.");
        fCheck(not pcall(oViewer.getPixel, 1.5, 0), "Fractional pixel indices are rejected.");

        local nViews, nSelections, nValues, nHovers = 0, 0, 0, 0;
        oViewer.on("viewChanged", function() nViews = nViews + 1; end);
        oViewer.on("selectionChanged", function() nSelections = nSelections + 1; end);
        oViewer.on("valueChanged", function() nValues = nValues + 1; end);
        oViewer.on("pixelHovered", function() nHovers = nHovers + 1; end);
        oViewer.setZoom(4);
        fCheck(nViews == 0, "Programmatic zoom defaults to silent.");
        local nBeforeX, nBeforeY = oViewer.clientToImage(70, 45);
        oViewer.setZoom(8, true, 70, 45);
        local nAfterX, nAfterY = oViewer.clientToImage(70, 45);
        fCheck(fNear(nBeforeX, nAfterX) and fNear(nBeforeY, nAfterY), "Zoom preserves the source point under its client anchor.");
        fCheck(nViews == 1, "Changed notifying zoom emits once.");
        oViewer.setZoom(8, true, 70, 45);
        fCheck(nViews == 1, "Unchanged zoom suppresses duplicate events.");
        fCheck(not pcall(oViewer.setZoom, 0) and not pcall(oViewer.setZoom, 65)
            and not pcall(oViewer.setPan, 0 / 0, 0), "Invalid geometry is rejected before native drawing.");
        oViewer.setPan(100000, -100000);
        local tView = oViewer.getView();
        fCheck(fNear(tView.PanX, 192) and fNear(tView.PanY, -80), "Pan is clamped to the enlarged image edges.");
        oViewer.actualSize(); tView = oViewer.getView();
        fCheck(tView.Mode == "manual" and tView.Zoom == 1 and tView.PanX == 0 and tView.PanY == 0, "Actual size resets to a centered 1:1 view.");
        oViewer.setPan(100, 100); tView = oViewer.getView();
        fCheck(tView.PanX == 0 and tView.PanY == 0, "Smaller images stay centered while panning.");

        local tRect = {X = 1, Y = 2, Width = 3, Height = 4};
        oViewer.setSelection(tRect); tRect.X = 20;
        local tCopy = oViewer.getSelection(); tCopy.Y = 20;
        fCheck(oViewer.getSelection().X == 1 and oViewer.getSelection().Y == 2 and nSelections == 0, "Selection setters/getters copy bounds and default to silent.");
        fCheck(not pcall(oViewer.setSelection, {X = 63, Y = 0, Width = 2, Height = 1})
            and oViewer.getSelection().X == 1, "Invalid selection retains committed bounds.");

        -- Native wheel routing must retain the cursor position, unlike the
        -- shared surface's coordinate-free wheel policy.
        oFrame:Show(true); _wx.wxYield(); oViewer.setZoom(4); oViewer.setPan(0, 0);
        local oFocusTarget = _wx.wxButton(oFrame, _wx.wxID_ANY, "Focus fixture");
        oFocusTarget:SetSize(0, 0, 1, 1); oFocusTarget:SetFocus();
        fCheck(oFocusTarget:HasFocus(), "Wheel/keyboard sequence starts with focus on another control.");
        nBeforeX, nBeforeY = oViewer.clientToImage(70, 45);
        fMouse(_wx.wxEVT_MOUSEWHEEL, 70, 45);
        nAfterX, nAfterY = oViewer.clientToImage(70, 45);
        fCheck(fNear(oViewer.getZoom(), 5) and fNear(nBeforeX, nAfterX) and fNear(nBeforeY, nAfterY), "Native wheel events perform cursor-anchored zoom.");
        fCheck(oViewer.Control:HasFocus(), "Handled wheel zoom transfers keyboard focus to the viewer.");
        -- Deliver keys to the actual focused window rather than forcing the
        -- viewer as the target, which would hide focus-routing failures.
        for _, nFitKey in ipairs({string.byte("F"), _wx.WXK_HOME}) do
            oViewer.setBinding("Fit", {{Type = "key", Key = nFitKey}});
            oViewer.setZoom(4);
            local oFocused = _wx.wxWindow.FindFocus();
            local oKey = _wx.wxKeyEvent(_wx.wxEVT_KEY_DOWN);
            oKey.GetKeyCode = function() return nFitKey; end;
            oKey:SetEventObject(oFocused); oKey:SetId(oFocused:GetId());
            oFocused:GetEventHandler():ProcessEvent(oKey); oKey:delete();
            fCheck(oViewer.getView().Mode == "fit", "Fit key reaches the viewer through current native focus: "..nFitKey);
        end
        oViewer.resetBindings();
        oViewer.setZoomEnabled(false); oFocusTarget:SetFocus();
        fMouse(_wx.wxEVT_MOUSEWHEEL, 70, 45);
        fCheck(oFocusTarget:HasFocus(), "Disabled wheel zoom does not steal focus from another control.");
        oViewer.setZoomEnabled(true); oFocusTarget:Destroy();
        oViewer.setZoom(4); oViewer.setPan(0, 0); oViewer.setTool("select");
        local nAX, nAY = oViewer.imageToClient(25.5, 12.5);
        local nBX, nBY = oViewer.imageToClient(20.5, 10.5);
        fMouse(_wx.wxEVT_LEFT_DOWN, nAX, nAY);
        fMouse(_wx.wxEVT_MOTION, nBX, nBY);
        fCheck(oViewer.Control:HasCapture() and oViewer.getSelection().X == 1, "Drag preview captures the mouse without committing selection.");
        fMouse(_wx.wxEVT_LEFT_UP, nBX, nBY);
        tRect = oViewer.getSelection();
        fCheck(tRect.X == 20 and tRect.Y == 10 and tRect.Width == 6 and tRect.Height == 3
            and not oViewer.Control:HasCapture(), "Reverse drag commits an inclusive source rectangle and releases capture.");
        fMouse(_wx.wxEVT_LEFT_DOWN, nAX, nAY); fMouse(_wx.wxEVT_MOTION, nBX, nBY);
        oViewer.handleKey("down", _wx.WXK_ESCAPE);
        fCheck(oViewer.getSelection().Width == 6 and not oViewer.Control:HasCapture(), "Escape cancels preview and retains committed selection.");
        oViewer.handleKey("down", _wx.WXK_ESCAPE);
        fCheck(oViewer.getSelection() == nil, "Escape without a drag clears selection.");
        oViewer.setPan(0, 0);
        fMouse(_wx.wxEVT_MIDDLE_DOWN, 64, 48); fMouse(_wx.wxEVT_MOTION, 74, 53); fMouse(_wx.wxEVT_MIDDLE_UP, 74, 53);
        tView = oViewer.getView();
        fCheck(tView.PanX == 10 and tView.PanY == 5 and not oViewer.Control:HasCapture(), "Middle drag pans while the select tool is active.");
        local nHoverBefore = nHovers;
        oViewer.pointer("move", 64, 48); oViewer.pointer("move", 64, 48);
        fCheck(nHovers <= nHoverBefore + 1, "Hover suppresses duplicate notifications for the same source pixel.");
        oViewer.setEnabled(false); local nOldZoom = oViewer.getZoom();
        fMouse(_wx.wxEVT_MOUSEWHEEL, 64, 48);
        fCheck(oViewer.getZoom() == nOldZoom and not oViewer.Control:HasCapture(), "Disabled native input cannot zoom or retain capture.");
        oViewer.setEnabled(true);

        -- Permission flags gate every bound input, but leave application-driven
        -- view/selection setters and original pixel inspection available.
        fCheck(oViewer.isPanEnabled() and oViewer.getZoomEnabled() and oViewer.isSelectionEnabled(), "All interactions default to enabled.");
        local nInteractions, nBindings = 0, 0;
        oViewer.on("interactionChanged", function(oSource, tEvent)
            fCheck(type(tEvent.Value) == "boolean" and tEvent.Value ~= tEvent.OldValue, "Interaction events describe actual boolean transitions.");
            nInteractions = nInteractions + 1;
        end);
        oViewer.on("bindingsChanged", function(oSource, tEvent)
            fCheck(type(tEvent.Bindings) == "table" and type(tEvent.OldBindings) == "table", "Binding events carry map snapshots.");
            tEvent.Bindings.Pan = {}; nBindings = nBindings + 1;
        end);
        oViewer.setPanEnabled(false); oViewer.setPanEnabled(false, true);
        fCheck(nInteractions == 0, "Permission setters are silent by default and suppress unchanged notifications.");
        oViewer.setPanEnabled(true, true);
        fCheck(nInteractions == 1 and not pcall(oViewer.setPanEnabled, "false"), "Changed permissions notify once and reject nonbooleans.");
        for nMask = 0, 7 do
            local bPan, bZoom, bSelection = nMask & 1 ~= 0, nMask & 2 ~= 0, nMask & 4 ~= 0;
            oViewer.setPanEnabled(bPan); oViewer.setZoomEnabled(bZoom); oViewer.setSelectionEnabled(bSelection);
            oViewer.setZoom(4); oViewer.setPan(0, 0); oViewer.setTool("pan"); oViewer.setSelection(nil);
            fMouse(_wx.wxEVT_LEFT_DOWN, 64, 48); fMouse(_wx.wxEVT_MOTION, 74, 53); fMouse(_wx.wxEVT_LEFT_UP, 74, 53);
            fCheck(oViewer.getView().PanX == (bPan and 10 or 0), "Left drag obeys PanEnabled independently: "..nMask);
            oViewer.setPan(0, 0);
            fMouse(_wx.wxEVT_MIDDLE_DOWN, 64, 48); fMouse(_wx.wxEVT_MOTION, 74, 53); fMouse(_wx.wxEVT_MIDDLE_UP, 74, 53);
            fCheck(oViewer.getView().PanX == (bPan and 10 or 0) and not oViewer.Control:HasCapture(), "Middle drag obeys PanEnabled and releases capture: "..nMask);
            oViewer.setPan(0, 0); oViewer.setTool("select");
            fMouse(_wx.wxEVT_LEFT_DOWN, 64, 48); fMouse(_wx.wxEVT_LEFT_UP, 68, 52);
            fCheck((oViewer.getSelection() ~= nil) == bSelection, "Selection drag obeys SelectionEnabled independently: "..nMask);
            oViewer.setSelection({X = 1, Y = 1, Width = 2, Height = 2});
            oViewer.handleKey("down", _wx.WXK_ESCAPE, {Alt = false});
            fCheck((oViewer.getSelection() == nil) == bSelection, "Keyboard selection clearing obeys SelectionEnabled: "..nMask);
            fMouse(_wx.wxEVT_MOUSEWHEEL, 64, 48);
            fCheck(oViewer.getZoom() == (bZoom and 5 or 4), "Wheel obeys ZoomEnabled independently: "..nMask);
            oViewer.setZoom(4); oViewer.handleKey("down", string.byte("F"), {Alt = false});
            fCheck(oViewer.getView().Mode == (bZoom and "fit" or "manual"), "Fit key obeys ZoomEnabled: "..nMask);
            oViewer.setZoom(4); oViewer.handleKey("down", string.byte("1"), {Alt = false});
            fCheck(oViewer.getZoom() == (bZoom and 1 or 4), "Actual-size key obeys ZoomEnabled: "..nMask);
            oViewer.setZoom(4); oViewer.handleKey("down", string.byte("="), {Alt = false});
            fCheck(oViewer.getZoom() == (bZoom and 5 or 4), "Zoom key obeys ZoomEnabled: "..nMask);
            fCheck(oViewer.getPixel(5, 7).Red == 20, "Inspection remains available for every permission combination: "..nMask);
        end
        oViewer.setPanEnabled(true); oViewer.setZoomEnabled(true); oViewer.setSelectionEnabled(true);
        oViewer.setZoom(4); oViewer.setPan(0, 0); oViewer.setTool("pan");
        fMouse(_wx.wxEVT_LEFT_DOWN, 64, 48); fMouse(_wx.wxEVT_MOTION, 68, 50);
        oViewer.setPanEnabled(false); local nStoppedPan = oViewer.getView().PanX;
        fMouse(_wx.wxEVT_MOTION, 90, 60); fMouse(_wx.wxEVT_LEFT_UP, 90, 60);
        fCheck(oViewer.getView().PanX == nStoppedPan and not oViewer.Control:HasCapture(), "Disabling pan cancels an in-progress gesture.");
        oViewer.setPanEnabled(true); oViewer.setTool("select");
        oViewer.setSelection({X = 1, Y = 2, Width = 3, Height = 4});
        fMouse(_wx.wxEVT_LEFT_DOWN, 64, 48); fMouse(_wx.wxEVT_MOTION, 68, 50);
        oViewer.setSelectionEnabled(false); fMouse(_wx.wxEVT_LEFT_UP, 68, 50);
        fCheck(oViewer.getSelection().X == 1 and not oViewer.Control:HasCapture(), "Disabling selection discards preview while retaining committed selection.");
        oViewer.setSelectionEnabled(true);

        local tMap = oViewer.getBindings(); tMap.Pan[1].Button = "right";
        fCheck(oViewer.getBinding("Pan")[1].Button == "left", "Binding getters return independent nested copies.");
        local tPan = {{Type = "drag", Button = "right"}};
        oViewer.setBinding("Pan", tPan, true); tPan[1].Button = "middle";
        fCheck(nBindings == 1 and oViewer.getBinding("Pan")[1].Button == "right", "Rebinding copies inputs and event snapshots cannot mutate the live map.");
        oViewer.setBinding("Pan", oViewer.getBinding("Pan"), true);
        fCheck(nBindings == 1, "Unchanged binding maps do not notify.");
        oViewer.setZoom(4); oViewer.setPan(0, 0); oViewer.setTool("pan");
        fMouse(_wx.wxEVT_LEFT_DOWN, 64, 48); fMouse(_wx.wxEVT_MOTION, 74, 53); fMouse(_wx.wxEVT_LEFT_UP, 74, 53);
        fCheck(oViewer.getView().PanX == 0, "Rebinding removes the old left-drag pan input.");
        fMouse(_wx.wxEVT_RIGHT_DOWN, 64, 48); fMouse(_wx.wxEVT_MOTION, 74, 53); fMouse(_wx.wxEVT_RIGHT_UP, 74, 53);
        fCheck(oViewer.getView().PanX == 10 and not oViewer.Control:HasCapture(), "Rebound right drag pans through native event routing.");
        oViewer.setPanEnabled(false); oViewer.setPan(0, 0);
        fMouse(_wx.wxEVT_RIGHT_DOWN, 64, 48); fMouse(_wx.wxEVT_MOTION, 74, 53); fMouse(_wx.wxEVT_RIGHT_UP, 74, 53);
        fCheck(oViewer.getView().PanX == 0, "Rebinding cannot bypass PanEnabled.");
        oViewer.setPanEnabled(true);
        oViewer.setBinding("ZoomIn", {{Type = "key", Key = string.byte("Z"), Command = true, Alt = true}});
        oViewer.setZoom(4);
        fCheck(not oViewer.handleKey("down", string.byte("Z"), {Command = true, Alt = false}) and oViewer.getZoom() == 4,
            "Rebound key requires every declared modifier.");
        oViewer.handleKey("down", string.byte("Z"), {Command = true, Alt = true});
        fCheck(oViewer.getZoom() == 5, "Rebound command/Alt key zooms.");
        oViewer.setZoomEnabled(false);
        oViewer.handleKey("down", string.byte("Z"), {Command = true, Alt = true});
        fCheck(oViewer.getZoom() == 5, "Rebinding cannot bypass ZoomEnabled.");
        oViewer.setZoomEnabled(true);
        local tInvalid = oViewer.getBindings(); tInvalid.Fit = {{Type = "key", Key = _wx.WXK_ESCAPE}};
        fCheck(not pcall(oViewer.setBindings, tInvalid) and oViewer.getBinding("Fit")[1].Key == string.byte("F"),
            "Conflicting bindings are rejected atomically.");
        fCheck(not pcall(oViewer.setBinding, "Unknown", {})
            and not pcall(oViewer.setBinding, "Pan", {{Type = "key", Key = 80}})
            and not pcall(oViewer.setBindings, {Fit = false})
            and not pcall(oViewer.setBinding, "Fit", {{Type = "key", Key = 70, Shfit = true}}), "Unknown actions, invalid types and misspelled fields are rejected.");
        oViewer.setBindings({}); oViewer.setZoom(4); oViewer.setPan(0, 0);
        fCheck(#oViewer.getBinding("Pan") == 0 and not oViewer.handleWheel(1, 64, 48, {Alt = false})
            and not oViewer.handleKey("down", string.byte("F"), {Alt = false}), "An empty complete map unbinds all actions.");
        oViewer.resetBindings();
        local tDefault = oViewer.getDefaultBindings(); tDefault.Pan = {};
        fCheck(#oViewer.getBinding("Pan") == 2 and #oViewer.getDefaultBindings().Pan == 2, "Reset/default bindings are independent per caller.");
        tMap = oViewer.getBindings(); tMap.ZoomIn = {{Type = "wheel", Direction = -1}}; tMap.ZoomOut = {};
        oViewer.setBindings(tMap);
        oViewer.setZoom(4); oViewer.handleWheel(-1, 64, 48, {Alt = false});
        fCheck(oViewer.getZoom() == 5, "Wheel direction can be rebound independently of zoom direction.");
        oViewer.resetBindings();

        local oRestricted = oLuma.Controls.imageViewer(oFrame, {Value = pFixture, PanEnabled = false,
            ZoomEnabled = false, SelectionEnabled = false, Bindings = {}});
        fCheck(not oRestricted.getPanEnabled() and not oRestricted.isZoomEnabled() and not oRestricted.getSelectionEnabled()
            and #oRestricted.getBinding("Pan") == 0 and #oViewer.getBinding("Pan") == 2, "Constructor flags/maps are independent between viewers.");
        oRestricted.destroy();

        for _, sViewMode in ipairs({"fit", "manual"}) do
            oViewer.setZoom(8); oViewer.setPan(100, 40);
            if (sViewMode == "fit") then oViewer.fit(); end
            local tBefore = oViewer.getView();
            local nOriginX, nOriginY = oViewer.imageToClient(0, 0);
            local sBefore = fPaint(128, 96);
            fPaint(31, 27); fPaint(900, 700);
            local tAfter = oViewer.getView();
            local nAfterOriginX, nAfterOriginY = oViewer.imageToClient(0, 0);
            fCheck(tBefore.Mode == tAfter.Mode and tBefore.Zoom == tAfter.Zoom and tBefore.PanX == tAfter.PanX
                and tBefore.PanY == tAfter.PanY and nOriginX == nAfterOriginX and nOriginY == nAfterOriginY,
                "Offscreen drawing preserves live zoom, pan and coordinate mapping: "..sViewMode);
            fCheck(fPaint(128, 96) == sBefore, "Returning from another destination size rebuilds the correct cached pixels: "..sViewMode);
        end

        oViewer.setZoom(8); oViewer.setPan(30, 20); oViewer.setTool("select");
        oViewer.setSelection({X = 3, Y = 4, Width = 5, Height = 6});
        oViewer.setPanEnabled(false); oViewer.setZoomEnabled(false); oViewer.setSelectionEnabled(false);
        oViewer.setBinding("Fit", {{Type = "key", Key = _wx.WXK_HOME}}); oViewer.setEnabled(false);
        local tSavedViewer = oViewer.getObjectState();
        oViewer.setEnabled(true); oViewer.fit(); oViewer.setTool("pan"); oViewer.setSelection(nil);
        oViewer.setPanEnabled(true); oViewer.setZoomEnabled(true); oViewer.setSelectionEnabled(true); oViewer.resetBindings();
        local nSavedNotifications = nViews + nSelections + nBindings + nInteractions + nValues;
        oViewer.setObjectState(tSavedViewer);
        local tRestoredView = oViewer.getView();
        fCheck(tRestoredView.Mode == "manual" and tRestoredView.Zoom == 8 and tRestoredView.PanX == 30
            and tRestoredView.PanY == 20 and oViewer.getSelection().X == 3, "Object state restores manual geometry and source-pixel selection.");
        fCheck(oViewer.getTool() == "select" and oViewer.getBinding("Fit")[1].Key == _wx.WXK_HOME
            and not oViewer.isPanEnabled() and not oViewer.isZoomEnabled() and not oViewer.isSelectionEnabled()
            and not oViewer.Control:IsThisEnabled(), "Object state restores bindings, tool and all interaction/enabled flags.");
        fCheck(nViews + nSelections + nBindings + nInteractions + nValues == nSavedNotifications, "Viewer object-state restoration suppresses semantic notifications.");
        local tDetached = oViewer.getViewerState(); tDetached.Bindings.Fit[1].Key = 123;
        fCheck(oViewer.getBinding("Fit")[1].Key == _wx.WXK_HOME, "Viewer state getter detaches nested bindings.");
        local tInvalidViewer = oViewer.getViewerState(); tInvalidViewer.Selection.Width = 10000;
        fCheck(not pcall(oViewer.setViewerState, tInvalidViewer) and oViewer.getZoom() == 8
            and oViewer.getSelection().Width == 5, "Invalid aggregate viewer state preserves source, view and selection.");
        tInvalidViewer = oViewer.getViewerState(); tInvalidViewer.Value = pFixture..".missing";
        fCheck(not pcall(oViewer.setViewerState, tInvalidViewer) and oViewer.getValue() == pFixture,
            "Missing saved source is rejected before the current image is changed.");
        local tInvalidObject = oViewer.getObjectState();
        tInvalidObject.Objects[1].Properties.Custom.Selection.Width = 10000;
        fCheck(not pcall(oViewer.setObjectState, tInvalidObject) and oViewer.getZoom() == 8
            and oViewer.getSelection().Width == 5, "Failed object-state application rolls back through the viewer adapter.");
        oViewer.setEnabled(true); oViewer.setPanEnabled(true); oViewer.setZoomEnabled(true); oViewer.setSelectionEnabled(true);

        -- Observe native image scaling without exposing implementation caches.
        -- A 64x full-source raster would be 4096x2048; only the viewport is needed.
        local nScales = 0;
        local fImage = _wx.wxImage;
        -- Instance accessors, rather than class-table fields, are the native
        -- dispatch boundary in this wxLua binding. Restore the constructor even
        -- when a scaling assertion fails.
        _wx.wxImage = function(...)
            local oImage = fImage(...);
            local fSubImage = oImage.GetSubImage;
            oImage.GetSubImage = function(oSource, oRect)
                local oCrop = fSubImage(oSource, oRect);
                local fScale = oCrop.Scale;
                oCrop.Scale = function(oSelf, nWidth, nHeight, nQuality)
                    nScales = nScales + 1;
                    fCheck(nWidth <= 128 + 256 and nHeight <= 96 + 256, "Crop-before-scale bounds each native raster allocation.");
                    return fScale(oSelf, nWidth, nHeight, nQuality);
                end;
                return oCrop;
            end;
            return oImage;
        end;
        local bRendered, sRenderError = xpcall(function()
            oViewer.setValue(nil); oViewer.setValue(pFixture);
            oViewer.setZoom(64); oViewer.setPan(0, 0);
            local oBitmap = _wx.wxBitmap(128, 96);
            local oDC = _wx.wxMemoryDC(); oDC:SelectObject(oBitmap);
            for nIndex = 1, 20 do oViewer.draw(oDC, 128, 96); end
            oDC:SelectObject(_wx.wxNullBitmap); oDC:delete(); oBitmap:delete();
        end, debug.traceback);
        _wx.wxImage = fImage; assert(bRendered, sRenderError);
        fCheck(nScales == 1, "Repeated unchanged paints reuse the retained display bitmap.");

        oViewer.setSelection({X = 4, Y = 5, Width = 6, Height = 7});
        for _, sTheme in ipairs({"Obsidian", "System"}) do
            oLuma.Theme.setName(sTheme);
            local oBitmap = _wx.wxBitmap(128, 96); local oDC = _wx.wxMemoryDC(); oDC:SelectObject(oBitmap);
            oViewer.draw(oDC, 128, 96);
            oDC:SelectObject(_wx.wxNullBitmap); oDC:delete(); oBitmap:delete();
            fCheck(oViewer.getZoom() == 64 and oViewer.getSelection().X == 4 and oViewer.getValue() == pFixture,
                "Theme changes preserve image, zoom and selection: "..sTheme);
        end
        fCheck(not pcall(oViewer.setValue, pFixture..".missing") and oViewer.getValue() == pFixture
            and oViewer.getSelection().X == 4, "Failed loads preserve the current image and selection.");
        oViewer.fit(); oViewer.layout(0, 0, 64, 64);
        fCheck(fNear(oViewer.getZoom(), 1) and oViewer.getSelection().Width == 6, "Fit recalculates after resize without clearing selection.");
        oViewer.setValue(nil, true);
        nW, nH = oViewer.getImageSize();
        fCheck(nW == 0 and nH == 0 and oViewer.getSelection() == nil and nValues == 1, "Clearing an image resets source and selection and emits one value event.");
        fCheck(oViewer.clientToImage(0, 0) == nil and oViewer.getPixel(0, 0) == nil, "Empty viewers return no source coordinate or pixel.");
        oViewer.destroy(); oViewer.destroy();
        fCheck(oViewer.Disposed and not pcall(oViewer.setZoom, 2), "Disposal is idempotent and rejects further source/view mutation.");
    end, debug.traceback);
    if (oViewer and not oViewer.Disposed) then oViewer.destroy(); end
    oFrame:Destroy(); _wx.wxYield(); oLuma.Theme.destroy(); os.remove(pFixture);
    _wx.wxGetApp():SetExitOnFrameDelete(bOriginalExit);
    assert(bOK, sError);
    print("Image viewer regression: "..nChecks.." checks passed.");
    return nChecks;
end

return ImageViewerRegression;
