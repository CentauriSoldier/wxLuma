local _wx = require("wx");
local TaskDeskRegression = {};

--[[!
@fqxn wxLuma.Tests.TaskDeskRegression.run
@desc Exercises the real application model, editor save policy, filtering,
    completion dashboard, native menu routing, resizing and skin changes.
    The application stays hidden; visual inspection remains with the user.
@ret number nChecks Successful workflow assertions.
!]]
function TaskDeskRegression.run()
    local oApp = require("Win.Tests.TaskDesk")(_wx.NULL, {Show = false});
    local tWidgets, nChecks = oApp.Widgets, 0;
    --[[!
    @fqxn wxLuma.Tests.TaskDeskRegression.fCheck
    @desc Counts a successful application behavior assertion.
    !]]
    local function fCheck(bPassed, sMessage) assert(bPassed, sMessage); nChecks = nChecks + 1; end
    --[[!
    @fqxn wxLuma.Tests.TaskDeskRegression.fClick
    @desc Invokes a button through its shared keyboard activation policy.
    !]]
    local function fClick(oButton)
        oButton.handleKey("down", _wx.WXK_RETURN); oButton.handleKey("up", _wx.WXK_RETURN);
    end
    local bOK, sError = xpcall(function()
        fCheck(#oApp.GetTasks() == 6 and #tWidgets.Tasks.Items == 6, "Queue presents its task model.");
        local tHelpers = {loadSkin = true, radioGroup = true, setDefaultContainmentOverflow = true, getDefaultContainmentOverflow = true};
        for sFactory in pairs(require("wxLuma.Controls")) do
            if (not tHelpers[sFactory]) then
                fCheck(oApp.Coverage[sFactory] and oApp.Coverage[sFactory].Control ~= nil,
                    "Workspace showcases exported control: "..sFactory);
            end
        end
        fCheck(tWidgets.Title.getValue() == "Prepare release notes", "Initial selection populates the editor.");
        fCheck(tWidgets.Progress.getValue() == 33, "Completion summary derives from task status.");
        tWidgets.Title.setValue("Prepare final release notes", true);
        fCheck(oApp.GetTasks()[1].Title == "Prepare final release notes", "Autosave commits real editor changes.");
        tWidgets.Autosave.setValue(false, true);
        tWidgets.Notes.setValue("Draft notes remain editable.", true);
        fCheck(oApp.GetTasks()[1].Notes ~= "Draft notes remain editable.", "Manual save keeps a draft separate.");
        local oNative = tWidgets.Notes.TextControl;
        oNative:SetSelection(1, 6);
        for _, sName in ipairs({"Obsidian", "System"}) do
            oApp.SetSkin(sName);
            local nStart, nEnd = oNative:GetSelection();
            fCheck(tWidgets.Notes.TextControl == oNative and nStart == 1 and nEnd == 6,
                "Appearance preserves the native editor and selection.");
            fCheck(tWidgets.Notes.getValue() == "Draft notes remain editable." and not tWidgets.Autosave.getValue(),
                "Appearance preserves the unsaved draft and save policy.");
        end
        fClick(tWidgets.Save);
        fCheck(oApp.GetTasks()[1].Notes == "Draft notes remain editable.", "Save commits the current task draft.");
        fClick(tWidgets.Complete);
        fCheck(oApp.GetTasks()[1].Done and tWidgets.Progress.getValue() == 50, "Completion updates task state and progress together.");
        local tSeries = tWidgets.Chart.getSeries("done");
        fCheck(tSeries.Points[3].Y == 2, "Priority chart reflects the completed high-priority task.");
        fClick(tWidgets.Complete);
        fCheck(not oApp.GetTasks()[1].Done and tWidgets.Progress.getValue() == 33, "Reopening a task reverses dashboard totals.");
        tWidgets.Search.setValue("project icons", true);
        tWidgets.Search.search();
        fCheck(#tWidgets.Tasks.Items == 1, "Search narrows the queue without discarding tasks.");
        tWidgets.Tasks.setValue(1, true);
        fCheck(tWidgets.Title.getValue() == "Update project icons", "Filtered row selection binds the correct task.");
        local oEvent = _wx.wxCommandEvent(_wx.wxEVT_COMMAND_MENU_SELECTED, oApp.MenuIds.New);
        oApp.Frame:GetEventHandler():ProcessEvent(oEvent); oEvent:delete();
        fCheck(#oApp.GetTasks() == 7 and #tWidgets.Tasks.Items == 7, "Native Add task command clears the filter and adds a task.");
        fCheck(tWidgets.Title.getValue() == "New task 7", "New tasks become the current editable task.");
        fCheck(tWidgets.Activity.getEntryCount() >= 5, "Activity records the actual workflow.");
        oApp.Pages.Objects.Capacity.setValue(42, true);
        fCheck(oApp.Pages.Settings.Capacity == 42 and oApp.Pages.Objects.Workers.getValue() == 42
            and oApp.Pages.Objects.Storage.getValue() == 42, "Capacity controls operate the resource dashboard together.");
        local oWorkers = oApp.Pages.Objects.Workers;
        oWorkers.handleKey("down", _wx.WXK_RIGHT);
        oWorkers.handleKey("up", _wx.WXK_RIGHT);
        fCheck(oApp.Pages.Objects.WorkersComplete.getValue():find("Worker allocation complete:", 1, true) ~= nil,
            "The shipped resource page displays actual knob completion.");
        local oProjectColor, oAccentColor = oApp.Pages.Objects.ProjectColor, oApp.Pages.Objects.AccentColor;
        fCheck(oProjectColor.getLayout() == "square" and oAccentColor.getLayout() == "wheel"
            and oApp.Tabs.Pages[5]:IsDescendant(oProjectColor.Control)
            and oApp.Tabs.Pages[5]:IsDescendant(oAccentColor.Control),
            "Both new color layouts are reachable in the shipped Settings tab.");
        oApp.Pages.Objects.ColorLayout.setValue(3, true);
        fCheck(oProjectColor.getLayout() == "wheel", "Task Desk's layout selector controls the actual project picker.");
        oApp.Pages.Objects.ColorLayout.setValue(1, true);
        fCheck(oProjectColor.getLayout() == "sliders", "Task Desk can select the original slider layout.");
        oApp.Pages.Objects.ColorLayout.setValue(2, true);
        oProjectColor.setValue({R = 25, G = 140, B = 220, A = 95}, true);
        fCheck(oApp.Pages.Settings.Color.A == 95 and oApp.Pages.Objects.ColorStatus.getValue():find("Project color:", 1, true),
            "Project color editing updates actual settings and its status readout.");
        oApp.Pages.Objects.ProgressDirection.setValue(2, true);
        for _, sMeter in ipairs({"Package", "Processor", "Storage", "Memory"}) do
            fCheck(oApp.Pages.Objects[sMeter].getFillDirection() == 1, "The working app uses unified numeric direction: "..sMeter);
        end
        oApp.Pages.Objects.ProgressReserve.setValue(4, true);
        for _, sMeter in ipairs({"Package", "Processor", "Storage", "Memory"}) do
            local oMeter = oApp.Pages.Objects[sMeter];
            fCheck(oMeter.getValue() == 0 and oMeter.getReserved() == 100, "Unified fully reserved app meter clamps to empty: "..sMeter);
        end
        oApp.Pages.Objects.ProgressReserve.setValue(1, true);
        oApp.Pages.Objects.ProgressDirection.setValue(1, true);
        local tObjects = oApp.Pages.Objects;
        for mode = 0, 2 do
            fCheck(tObjects["Polygon"..mode].getShape() == 2 and tObjects["Polygon"..mode].getFillMode() == mode,
                "The shipped resource page contains every polygon fill mode.");
        end
        tObjects.PolygonReserveDirection.setValue(3, true);
        fCheck(tObjects.Polygon1.getReserveDirection() == "inward" and tObjects.Polygon2.getReserveDirection() == "CCW",
            "Polygon reserve direction can oppose the fill in the working app.");
        tObjects.PolygonReserveDirection.setValue(1, true);
        fCheck(tObjects.Polygon1.getReserveDirection() == nil, "The polygon demo restores automatic reserve direction.");
        tObjects.PolygonVertices.setValue(2, true);
        fCheck(#tObjects.Polygon1.getPolygon() == 6, "The test app can select a concave polygon.");
        tObjects.PolygonRadii.setValue(2, true);
        fCheck(tObjects.Polygon1.getRadii() == 25 and select(2, tObjects.Polygon1.getRadii()) == 90,
            "The test app exercises polygon radial bands.");
        tObjects.PolygonStartAngle.setValue(6, true); tObjects.PolygonReserveAngle.setValue(3, true);
        fCheck(tObjects.Polygon2.getStartAngle() == 359 and tObjects.Polygon2.getReserveStartAngle() == 45,
            "Polygon fill and reserve arc angles are independently selectable.");
        oApp.Pages.Objects.Properties.setValue("version", "1.1", true);
        fCheck(oApp.Pages.Settings.version == "1.1", "Project inspector edits actual settings.");
        local oFiles = oApp.Pages.Objects.ProjectFiles;
        fCheck(oFiles.Kind == "FileBrowser" and #oFiles.getEntries() > 0, "Resources embeds a populated project file browser.");
        local sProjectDirectory = oFiles.getDirectory();
        fCheck(oFiles.navigate("Core") and oFiles.goBack() and oFiles.getDirectory() == sProjectDirectory,
            "Project browser navigation works in the scrollable application page.");
        oFiles.setFilter("init.lua");
        fCheck(#oFiles.getEntries() == 1 and oFiles.getEntries()[1].Name == "init.lua", "Project browser filters actual framework files.");
        oFiles.setFilter("");
        local oArtwork = oApp.Pages.Objects.Artwork;
        fCheck(oArtwork.Kind == "ImageViewer", "Release artwork uses the interactive image viewer.");
        fClick(oApp.Pages.Objects.ArtworkActual);
        fCheck(oArtwork.getZoom() == 1 and oArtwork.getView().Mode == "manual", "Artwork 1:1 action centers the source at actual size.");
        oApp.Pages.Objects.ArtworkSelect.setValue(true, true);
        fCheck(oArtwork.getTool() == "select", "Artwork selection toggle changes the viewer tool.");
        fClick(oApp.Pages.Objects.ArtworkFit);
        fCheck(oArtwork.getView().Mode == "fit", "Artwork Fit action restores responsive fitting.");
        oApp.Pages.Objects.ArtworkPanEnabled.setValue(false, true);
        oApp.Pages.Objects.ArtworkZoomEnabled.setValue(false, true);
        oApp.Pages.Objects.ArtworkSelectionEnabled.setValue(false, true);
        fCheck(not oArtwork.isPanEnabled() and not oArtwork.isZoomEnabled() and not oArtwork.isSelectionEnabled(),
            "Artwork permission toggles control all three interactions independently.");
        oApp.Pages.Objects.ArtworkBindingPreset.setValue(2, true);
        fCheck(oArtwork.getBinding("Pan")[1].Button == "right" and oArtwork.getBinding("Fit")[1].Key == _wx.WXK_HOME,
            "Alternate artwork preset changes actual bindings.");
        oApp.Pages.Objects.ArtworkBindingPreset.setValue(1, true);
        fCheck(oArtwork.getBinding("Pan")[1].Button == "left", "Default artwork preset restores the built-in bindings.");
        oApp.Pages.Objects.ArtworkPanEnabled.setValue(true, true);
        oApp.Pages.Objects.ArtworkZoomEnabled.setValue(true, true);
        oApp.Pages.Objects.ArtworkSelectionEnabled.setValue(true, true);
        for _, sSkin in ipairs({"Obsidian", "System"}) do
            oApp.SetSkin(sSkin);
            for nPage = 1, 5 do oApp.Tabs.setValue(nPage); oApp.Pages.refresh(); end
            for sFactory, oControl in pairs(oApp.Coverage) do
                if (oControl.draw) then
                    local oBitmap = _wx.wxBitmap(480, 240);
                    local oDC = _wx.wxMemoryDC(); oDC:SelectObject(oBitmap);
                    oControl.draw(oDC, 480, 240);
                    oDC:SelectObject(_wx.wxNullBitmap); oDC:delete(); oBitmap:delete();
                    fCheck(not oControl.Disposed, sFactory.." renders in the working app using "..sSkin..".");
                end
            end
        end
        oApp.Tabs.setValue(1);
        for _, tSize in ipairs({{920, 720}, {1080, 820}, {1280, 900}}) do
            oApp.Frame:SetClientSize(_wx.wxSize(tSize[1], tSize[2])); oApp.Frame:Layout();
            local oRoot = tWidgets.Tasks.Control:GetParent(); oRoot:Layout();
            oApp.Pages.refresh();
            local oHistoryBar = oApp.Pages.Objects.HistoryOffset;
            local nBarWidth = oHistoryBar.Control:GetSizeWH();
            local nExpectedWidth = _wx.wxSystemSettings.GetMetric(_wx.wxSYS_VSCROLL_X, oHistoryBar.Control);
            if (nExpectedWidth <= 0) then nExpectedWidth = oHistoryBar.Control:FromDIP(17); end
            fCheck(nBarWidth == nExpectedWidth, "History scrollbar retains OS thickness as the window grows.");
            local nRootW, nRootH = oRoot:GetClientSizeWH();
            for sKey, oWidget in pairs(tWidgets) do
                local nX, nY = oWidget.Control:GetPositionXY();
                local nW, nH = oWidget.Control:GetSizeWH();
                fCheck(nW > 0 and nH > 0 and nX >= 0 and nY >= 0 and nX + nW <= nRootW and nY + nH <= nRootH,
                    sKey.." remains inside the app at supported sizes.");
            end
        end
    end, debug.traceback);
    oApp.Frame:Close(); _wx.wxYield();
    assert(bOK, sError);
    print("Task desk regression: "..nChecks.." checks passed.");
    return nChecks;
end

return TaskDeskRegression;
