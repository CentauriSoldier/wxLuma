local _wx = require("wx");
local TaskDeskPages = {};

--[[!
@fqxn wxLuma.Tests.TaskDeskPages.create
@desc Completes Task desk with planning, build resources, reports and settings.
    Controls operate on project settings, task data or the shared build preview.
    Scrollable pages keep every feature reachable without a wall of examples.
!]]
function TaskDeskPages.create(oLuma, Controls, oFrame, oTabs, tApp)
    local tOwned, tNative, tPages, tObjects, tCharts = {}, {}, {}, {}, {};
    local tSettings = {Owner = "Alex", Budget = 1200, TeamSize = 4, Capacity = 65, Profile = "Balanced"};
    local bDisposed = false;
    local oModule = {Objects = tObjects, Settings = tSettings};

    --[[!
    @fqxn wxLuma.Tests.TaskDeskPages.fOwn
    @desc Constructs an application-owned control through the audited facade.
    !]]
    local function fOwn(sKey, sFactory, oParent, tOptions)
        local oWidget = Controls[sFactory](oParent, tOptions or {});
        tOwned[#tOwned + 1] = oWidget; tObjects[sKey] = oWidget; return oWidget;
    end

    --[[!
    @fqxn wxLuma.Tests.TaskDeskPages.fText
    @desc Creates native section text with the shared appearance palette.
    !]]
    local function fText(oParent, sText)
        local oText = _wx.wxStaticText(oParent, _wx.wxID_ANY, sText);
        tNative[#tNative + 1] = oText; return oText;
    end

    --[[!
    @fqxn wxLuma.Tests.TaskDeskPages.fPage
    @desc Creates a scrollable workspace page and lays out complete sections.
    !]]
    local function fPage(nIndex)
        local oParent = oTabs.Pages[nIndex];
        local oScroll = fOwn("Page"..nIndex, "scrollContainer", oParent, {Step = 36});
        local tPage = {Scroll = oScroll, Sections = {}}; tPages[#tPages + 1] = tPage;
        function tPage.Layout()
            if (bDisposed) then return; end
            local nW, nH = oParent:GetClientSizeWH(); oScroll.layout(0, 0, math.max(1, nW), math.max(1, nH));
            local nView = oScroll.getViewportSize(); local nWidth, nY = math.max(1, nView - 28), 14;
            for _, tSection in ipairs(tPage.Sections) do
                tSection.Control:SetSize(14, nY, nWidth, tSection.Height + 34);
                tSection.Title:SetSize(0, 0, nWidth, 26);
                for _, tPlace in ipairs(tSection.Children) do
                    tPlace.Object.layout(math.floor(tPlace.X * nWidth), 32 + tPlace.Y,
                        math.max(1, math.floor(tPlace.Width * nWidth)), tPlace.Height);
                end
                if (tSection.Layout) then tSection.Layout(nWidth); end
                nY = nY + tSection.Height + 50;
            end
            oScroll.setContentSize(0, nY);
        end
        oParent:Connect(_wx.wxEVT_SIZE, function(oEvent) tPage.Layout(); oEvent:Skip(); end);
        return tPage;
    end

    --[[!
    @fqxn wxLuma.Tests.TaskDeskPages.fSection
    @desc Groups one project workflow with its own heading and bounded layout.
    !]]
    local function fSection(tPage, sTitle, nHeight)
        local oPanel = _wx.wxPanel(tPage.Scroll.Content, _wx.wxID_ANY);
        tNative[#tNative + 1] = oPanel;
        local tSection = {Control = oPanel, Title = fText(oPanel, sTitle), Height = nHeight, Children = {}};
        tPage.Sections[#tPage.Sections + 1] = tSection; return tSection;
    end

    --[[!
    @fqxn wxLuma.Tests.TaskDeskPages.fPut
    @desc Adds a control to a section using proportional width and compact height.
    !]]
    local function fPut(tSection, sKey, sFactory, tOptions, nX, nY, nWidth, nHeight)
        local oWidget = fOwn(sKey, sFactory, tSection.Control, tOptions);
        tSection.Children[#tSection.Children + 1] = {Object = oWidget, X = nX or 0, Y = nY or 0, Width = nWidth or 1, Height = nHeight or 36};
        return oWidget;
    end

    -- Planning controls own project choices rather than independent sample values.
    local tPlanning = fPage(2);
    local tCommands = fSection(tPlanning, "Project commands", 82);
    local oNotice = fPut(tCommands, "Notice", "notification", {Value = "Plan the release, then review it before delivery.", Duration = 0}, 0, 42, 1, 40);
    local oDialog = fOwn("Review", "dialog", oFrame, {Title = "Release review", Message = "Review the task list, choose the output folder, and confirm the delivery settings.",
        Buttons = {"ok", "cancel"}, OnClose = function(sResult) tApp.Log("Release review: "..tostring(sResult)); end});
    local oOverview = oLuma.TopLevelWindow.create(oFrame, {Title = "Project overview", Width = 540, Height = 360,
        PaintContent = function(oDC, tRect)
            oDC:SetFont(oLuma.Theme.Font);
            oLuma.Theme.text(oDC, "Release workspace", tRect.x + 16, tRect.y + 16, true);
            oLuma.Theme.text(oDC, #tApp.GetTasks().." tasks · Planning, resources and delivery reports", tRect.x + 16, tRect.y + 48, true);
        end,
        OnClose = function(oWindow, oEvent)
            if (oEvent:CanVeto()) then oEvent:Veto(); oWindow.show(false); end
        end});
    tOwned[#tOwned + 1] = oOverview;
    tObjects.OverviewWindow, tObjects.OverviewSurface = oOverview, oOverview.Surface;
    local function fReview() oDialog.show(); end
    fPut(tCommands, "ProjectMenu", "menuBar", {Menus = {
        {Id = "project", Text = "Project", Items = {{Id = "overview", Text = "Project overview"}, {Id = "review", Text = "Review release"}, {Id = "refresh", Text = "Refresh dashboard"}}},
        {Id = "navigate", Text = "Navigate", Items = {{Id = "work", Text = "Work queue"}, {Id = "reports", Text = "Reports"}}}},
        OnSelect = function(tChoice)
            if (tChoice.Id == "overview") then oOverview.show(); elseif (tChoice.Id == "review") then fReview(); elseif (tChoice.Id == "refresh") then tApp.Refresh();
            elseif (tChoice.Id == "work") then oTabs.setValue(1); else oTabs.setValue(4); end
        end}, 0, 0, 1, 36);
    local tSchedule = fSection(tPlanning, "Release schedule and ownership", 144);
    fPut(tSchedule, "Owner", "comboBox", {Items = {"Alex", "Jordan", "Sam"}, Value = "Alex", Hint = "Project owner",
        OnChange = function(sValue) tSettings.Owner = sValue; end}, 0, 0, 0.48, 36);
    fPut(tSchedule, "Milestone", "dropdown", {Items = {"Planning", "Implementation", "Review", "Delivery"}, Value = 1,
        OnChange = function(nValue) tSettings.Milestone = nValue; end}, 0.52, 0, 0.48, 36);
    fPut(tSchedule, "DueDate", "dateTimePicker", {Mode = "date", Value = "2026-12-01",
        OnChange = function(sValue) tSettings.DueDate = sValue; end}, 0, 48, 0.48, 36);
    fPut(tSchedule, "Budget", "numericField", {Min = 0, Max = 100000, Step = 50, Value = 1200, Precision = 0,
        OnChange = function(nValue) tSettings.Budget = nValue; end}, 0.52, 48, 0.48, 36);
    fPut(tSchedule, "TeamSize", "spinner", {Min = 1, Max = 30, Step = 1, Value = 4,
        OnChange = function(nValue) tSettings.TeamSize = nValue; end}, 0, 96, 0.25, 36);
    fPut(tSchedule, "ScheduleHelp", "label", {Value = "Owner / milestone · Due date / budget · Team size", Wrap = true}, 0.3, 96, 0.7, 36);
    local tStructure = fSection(tPlanning, "Project folders and deliverables", 250);
    local oSplit = fPut(tStructure, "ProjectSplit", "splitContainer", {Value = 0.35, MinFirst = 160, MinSecond = 260}, 0, 0, 1, 250);
    local oTree = fOwn("Folders", "tree", oSplit.First, {Items = {{Id = "release", Text = "Release", Expanded = true, Children = {
        {Id = "notes", Text = "Documentation"}, {Id = "assets", Text = "Artwork"}, {Id = "build", Text = "Build output"}}}},
        OnChange = function(sId) tApp.Log("Project folder: "..tostring(sId)); end});
    local oTable = fOwn("Deliverables", "table", oSplit.Second, {Columns = {{Text = "Deliverable", Width = 190}, {Text = "Owner", Width = 90}},
        Items = {{Id = "notes", Cells = {"Release notes", "Alex"}}, {Id = "package", Cells = {"Application package", "Jordan"}}}});
    local function fSplitLayout()
        local nW, nH = oSplit.First:GetClientSizeWH(); oTree.layout(0, 0, math.max(1, nW), math.max(1, nH));
        nW, nH = oSplit.Second:GetClientSizeWH(); oTable.layout(0, 0, math.max(1, nW), math.max(1, nH));
    end
    oSplit.First:Connect(_wx.wxEVT_SIZE, function(oEvent) fSplitLayout(); oEvent:Skip(); end);
    oSplit.Second:Connect(_wx.wxEVT_SIZE, function(oEvent) fSplitLayout(); oEvent:Skip(); end);
    tStructure.Layout = fSplitLayout;
    local tApprovals = fSection(tPlanning, "Release approval checklist", 180);
    fPut(tApprovals, "Approvals", "treeEx", {Columns = {{Key = "Name", Title = "Review item", Weight = 2}, {Key = "Owner", Title = "Reviewer", Width = 140}},
        Checkboxes = true, Items = {{Id = "review", Name = "Release review", Expanded = true, Children = {
            {Id = "docs", Name = "Documentation", Owner = "Alex"}, {Id = "quality", Name = "Quality checks", Owner = "Sam"}}}},
        OnCheckChange = function(sId, bValue) tApp.Log("Approval "..sId..(bValue and " checked." or " reopened.")); end}, 0, 0, 1, 180);

    local tResources = fPage(3);
    local tBuild = fSection(tResources, "Build controls", 116);
    local tMeters = {};
    local function fCapacity(nValue)
        tSettings.Capacity = nValue;
        for _, oMeter in ipairs(tMeters) do oMeter.setValue(nValue); end
        for _, sKey in ipairs({"Capacity", "Workers"}) do
            if (tObjects[sKey]) then tObjects[sKey].setValue(nValue); end
        end
        if (tObjects.ReadyLED) then tObjects.ReadyLED.setValue(nValue == 100); end
        if (tObjects.Status) then tObjects.Status.setItem("state", {Text = nValue == 100 and "Ready" or "Allocating"}); end
    end
    fPut(tBuild, "BuildToolbar", "toolbar", {Items = {{Id = "build", Text = "Run build", Width = 110}, {Id = "review", Text = "Review", Width = 90}},
        OnActivate = function(sId)
            if (sId == "review") then fReview(); else
                fCapacity(100); oNotice.show("Build finished. Ready for review.", "success", 0);
                tObjects.BuildHistory.addItem("Current release — build completed"); tApp.Log("Build completed.");
            end
        end}, 0, 0, 1, 38);
    fPut(tBuild, "Capacity", "slider", {Min = 0, Max = 100, Step = 1, Value = 65, OnChange = fCapacity}, 0, 52, 0.48, 36);
    fPut(tBuild, "Workers", "knob", {Min = 0, Max = 100, Value = 65, Rate = 5, OnChange = fCapacity}, 0.53, 42, 0.15, 74);
    fPut(tBuild, "BuildLabel", "label", {Value = "Build capacity / worker allocation", Wrap = true}, 0.72, 56, 0.28, 48);
    local tUsage = fSection(tResources, "Capacity: package · processor · storage · memory", 130);
    for nIndex, tMeter in ipairs({{"Package", "progress"}, {"Processor", "circularProgress"}, {"Storage", "globeProgress"}, {"Memory", "radialProgress"}}) do
        tMeters[#tMeters + 1] = fPut(tUsage, tMeter[1], tMeter[2], {Min = 0, Max = 100, Value = 65, Text = "%v%", Appearance = "skin"},
            (nIndex - 1) * 0.25, nIndex == 1 and 42 or 0, 0.23, nIndex == 1 and 36 or 112);
    end
    local tActivity = fSection(tResources, "Build history", 150);
    local oHistory = fPut(tActivity, "BuildHistory", "list", {Items = {"Release package — ready", "Documentation — reviewed", "Quality checks — pending"}, RowHeight = 36}, 0, 0, 0.84, 140);
    local oHistoryBar = fPut(tActivity, "HistoryOffset", "scrollbar", {Min = 0, Max = 20, Page = 3, Value = 0,
        OnChange = function(nValue) oHistory.scrollTo(nValue + 1); end}, 0.9, 0, 0.05, 140);
    tActivity.Layout = function(nWidth)
        -- Scrollbar thickness is an OS metric, not a percentage of page width.
        local nBar = _wx.wxSystemSettings.GetMetric(_wx.wxSYS_VSCROLL_X, oHistoryBar.Control);
        if (nBar <= 0) then nBar = oHistoryBar.Control:FromDIP(17); end
        local nGap = oHistoryBar.Control:FromDIP(8);
        oHistory.layout(0, 32, math.max(1, nWidth - nBar - nGap), 140);
        oHistoryBar.layout(math.max(0, nWidth - nBar), 32, nBar, 140);
    end;
    local tPreview = fSection(tResources, "Release artwork and review", 220);
    local pImage = oLuma.Config.ImagePath.."/Menu/Command Shield.png";
    local oPreview = fPut(tPreview, "PreviewPanel", "panel", {Text = "Release preview", MinWidth = 220, MinHeight = 160}, 0, 0, 0.6, 200);
    local oImage = fOwn("Artwork", "image", oPreview.Content, {Value = pImage, ScaleMode = "contain"});
    oPreview.Content:Connect(_wx.wxEVT_SIZE, function(oEvent)
        local nW, nH = oPreview.Content:GetClientSizeWH(); oImage.layout(0, 0, math.max(1, nW), math.max(1, nH)); oEvent:Skip();
    end);
    fPut(tPreview, "ReviewArtwork", "imageButton", {Image = pImage, Text = "Review release", OnClick = fReview}, 0.66, 20, 0.24, 110);
    local oContext = fOwn("BuildContext", "contextMenu", oFrame, {Items = {{Id = "review", Text = "Review release"}, {Id = "ready", Text = "Mark build ready"}},
        OnSelect = function(tChoice) if (tChoice.Id == "review") then fReview(); else fCapacity(100); end end});
    local oRadial = fOwn("BuildRadial", "radialMenu", oFrame, {Items = {{Id = "review", Text = "Review"}, {Id = "build", Text = "Build"}},
        OnSelect = function(tChoice) if (tChoice.Id == "review") then fReview(); else fCapacity(100); end end});
    local oActions = fPut(tPreview, "BuildActions", "button", {Text = "Build actions", OnClick = function() oContext.showAtObject(oHistory); end}, 0.66, 148, 0.3, 36);
    fOwn("BuildTip", "tooltip", oActions.Control, {Text = "Open release commands. Right-click the build history for the same actions."});
    oContext.attach(oHistory.Control);
    fPut(tPreview, "QuickActions", "button", {Text = "Quick actions", OnClick = function() oRadial.showAtObject(oActions); end}, 0.66, 188, 0.3, 32);

    local tReports = fPage(4);
    for _, tReport in ipairs({{"Throughput", "lineChart", "Completed tasks in queue order"}, {"Effort", "areaChart", "Open effort by task"},
        {"PriorityEffort", "scatterChart", "Priority versus estimated effort"}, {"TaskStatus", "pieChart", "Open and completed work"},
        {"PriorityMix", "donutChart", "Tasks by priority"}, {"Delivery", "chart", "Delivery trend"}}) do
        local tSection = fSection(tReports, tReport[3], 230);
        local oChart = fPut(tSection, tReport[1], tReport[2], {Type = "line", Legend = true, Series = {}}, 0, 0, 1, 230);
        tCharts[tReport[1]] = oChart;
    end

    local tPreferences = fPage(5);
    local tFiles = fSection(tPreferences, "Source material and delivery folder", 128);
    local oFile = fPut(tFiles, "SourceFile", "filePicker", {Value = "", Hint = "Choose release notes",
        OnChange = function(sValue) tSettings.SourceFile = sValue; end}, 0, 0, 1, 36);
    fPut(tFiles, "OutputFolder", "folderPicker", {Value = "", Hint = "Choose delivery folder",
        OnChange = function(sValue) tSettings.OutputFolder = sValue; end}, 0, 46, 1, 36);
    fPut(tFiles, "ProjectPath", "breadcrumb", {Items = {{Id = "workspace", Text = "Workspace"}, {Id = "release", Text = "Release"}, {Id = "delivery", Text = "Delivery"}},
        OnChange = function(sId) tApp.Log("Project path: "..sId); end}, 0, 92, 1, 36);
    fOwn("SourceHelp", "tooltip", oFile.Control, {Text = "Attach existing release documentation; choosing a file does not modify it."});
    local tPolicy = fSection(tPreferences, "Delivery policy", 174);
    fPut(tPolicy, "Publish", "checkbox", {Text = "Include release notes", Selected = true, OnChange = function(bValue) tSettings.IncludeNotes = bValue; end}, 0, 0, 0.48, 32);
    fPut(tPolicy, "Pinned", "toggleButton", {Text = "Pin this project", Value = false, OnChange = function(bValue) tSettings.Pinned = bValue; end}, 0.52, 0, 0.4, 36);
    local oGroup = Controls.radioGroup();
    for nIndex, sProfile in ipairs({"Balanced", "Fast"}) do
        fPut(tPolicy, "Profile"..sProfile, "radio", {Group = oGroup, Value = sProfile, Text = sProfile.." delivery", Selected = nIndex == 1,
            OnChange = function(sValue) tSettings.Profile = sValue; end}, (nIndex - 1) * 0.52, 46, 0.48, 32);
    end
    fPut(tPolicy, "WorkHours", "rangeSlider", {Min = 0, Max = 24, Step = 1, Value = {Low = 9, High = 17},
        OnChange = function(tValue) tSettings.WorkHours = tValue; end}, 0, 94, 0.6, 42);
    fPut(tPolicy, "ProjectColor", "colorPicker", {Value = {R = 40, G = 120, B = 200}, OnChange = function(tColor) tSettings.Color = tColor; end}, 0.67, 94, 0.18, 36);
    fPut(tPolicy, "ReadyLED", "led", {Value = true, Size = 24, Color = {R = 50, G = 170, B = 90}}, 0.88, 92, 0.1, 42);
    fPut(tPolicy, "HoursLabel", "label", {Value = "Working hours · Project color · Ready", Wrap = true}, 0, 140, 1, 32);
    local tAdvanced = fSection(tPreferences, "Advanced project settings", 240);
    fPut(tAdvanced, "Properties", "propertyGrid", {Properties = {{Id = "project", Type = "category", Text = "Project"},
        {Id = "name", Text = "Name", Value = "Release workspace"}, {Id = "version", Text = "Version", Value = "1.0"},
        {Id = "archived", Text = "Archived", Type = "boolean", Value = false}},
        OnChange = function(sId, vValue) tSettings[sId] = vValue; end}, 0, 0, 0.56, 230);
    local oDisclosure = fPut(tAdvanced, "MoreOptions", "collapsiblePanel", {Text = "Delivery notes", Expanded = true, ContentHeight = 90}, 0.6, 0, 0.4, 130);
    local oNotes = fOwn("PolicyNotes", "label", oDisclosure.Content, {Value = "Use the review dialog before delivery. Project files remain unchanged.", Wrap = true});
    oNotes.layout(8, 8, 250, 72);
    local tReference = fSection(tPreferences, "Project reference and inspector", 250);
    local oAccordion = fPut(tReference, "Reference", "accordion", {Sections = {{Id = "review", Text = "Review checklist", Height = 90, Expanded = true},
        {Id = "delivery", Text = "Delivery checklist", Height = 90}}}, 0, 0, 0.48, 240);
    for _, sId in ipairs({"review", "delivery"}) do
        local oCheck = fOwn("Reference"..sId, "checkbox", oAccordion.getSection(sId).Content, {Text = "Checklist reviewed", OnChange = function(bValue) tSettings[sId] = bValue; end});
        oCheck.layout(8, 8, 240, 36);
    end
    local oDock = fPut(tReference, "Inspector", "dockablePanel", {Text = "Project inspector", Extent = 220}, 0.52, 0, 0.48, 190);
    local oInspector = fOwn("InspectorText", "label", oDock.Content, {Value = "Owner, schedule, budget and delivery options belong to this project.", Wrap = true});
    oInspector.layout(8, 8, 270, 90);
    fPut(tReference, "FloatInspector", "button", {Text = "Float inspector", OnClick = function() if (oDock.isFloating()) then oDock.dock("fill"); else oDock.float(); end end}, 0.52, 200, 0.3, 36);
    local tFooter = fSection(tPreferences, "Workspace status", 40);
    fPut(tFooter, "Status", "statusBar", {Items = {{Id = "project", Text = "Release workspace", Weight = 1}, {Id = "state", Text = "Ready", Width = 100}}}, 0, 0, 1, 36);

    --[[!
    @fqxn wxLuma.Tests.TaskDeskPages.update
    @desc Rebuilds every report from the live task model rather than unrelated
        canned chart data. Estimates default to two hours per task.
    !]]
    function oModule.update()
        local tTasks = tApp.GetTasks(); local tDone, tEffort, tScatter, nDone, tCounts = {}, {}, {}, 0, {Low = 0, Normal = 0, High = 0};
        for nIndex, tTask in ipairs(tTasks) do
            if (tTask.Done) then nDone = nDone + 1; end
            tCounts[tTask.Priority] = tCounts[tTask.Priority] + 1;
            tDone[#tDone + 1] = {X = nIndex, Y = nDone};
            tEffort[#tEffort + 1] = {X = nIndex, Y = tTask.Done and 0 or (tTask.Estimate or 2)};
            tScatter[#tScatter + 1] = {X = ({Low = 1, Normal = 2, High = 3})[tTask.Priority], Y = tTask.Estimate or 2};
        end
        for _, sKey in ipairs({"Throughput", "Delivery"}) do tCharts[sKey].setSeries({{Id = "done", Text = "Completed", Points = tDone}}); end
        tCharts.Effort.setSeries({{Id = "effort", Text = "Open hours", Points = tEffort}});
        tCharts.PriorityEffort.setSeries({{Id = "effort", Text = "Hours", Points = tScatter}});
        tCharts.TaskStatus.setSeries({{Id = "status", Points = {{Id = "open", Text = "Open", Y = #tTasks - nDone}, {Id = "done", Text = "Complete", Y = nDone}}}});
        tCharts.PriorityMix.setSeries({{Id = "priority", Points = {{Text = "Low", Y = tCounts.Low}, {Text = "Normal", Y = tCounts.Normal}, {Text = "High", Y = tCounts.High}}}});
    end

    --[[!
    @fqxn wxLuma.Tests.TaskDeskPages.refresh
    @desc Refreshes native section colors and reachable page geometry.
    !]]
    function oModule.refresh()
        for _, oNative in ipairs(tNative) do
            oNative:SetFont(oLuma.Theme.Font); oNative:SetBackgroundColour(oLuma.Theme.color("Background"));
            oNative:SetForegroundColour(oLuma.Theme.color("Text")); oNative:Refresh(false);
        end
        for _, tPage in ipairs(tPages) do tPage.Layout(); end
    end

    --[[!
    @fqxn wxLuma.Tests.TaskDeskPages.destroy
    @desc Releases popup and nested controls before their containing pages.
    !]]
    function oModule.destroy()
        if (bDisposed) then return; end
        bDisposed = true;
        for nIndex = #tOwned, 1, -1 do tOwned[nIndex].destroy(); end
    end
    fCapacity(65); oModule.update(); oModule.refresh();
    return oModule;
end

return TaskDeskPages;
