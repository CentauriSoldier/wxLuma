local _wx = require("wx");
local _load = require("wxLuma");

--[[!
@fqxn wxLuma.Tests.TaskDesk.create
@desc Builds a working task workspace. Custom controls handle search, editing,
    task selection, completion and activity; native menus, labels, choices and
    sizers provide the application shell. Data belongs to this demo instance.
@param wxWindow|nil oParent Native owner.
@param table|nil tOptions Show=false creates a hidden automated fixture.
@ret table oApp Frame, Widgets, Skin and workspace operations.
!]]
return function(oParent, tOptions)
    tOptions = tOptions or {};
    local oLuma = _load();
    local Controls, oTheme, tCoverage = {}, oLuma.Theme, {};
    -- Keep an executable inventory, including convenience factories. Coverage
    -- describes controls actually created by this app, not a hand-written list.
    for sName, fFactory in pairs(oLuma.Controls) do
        Controls[sName] = function(...)
            local oControl = fFactory(...); tCoverage[sName] = oControl; return oControl;
        end;
    end
    local oFrame = _wx.wxFrame(oParent or _wx.NULL, _wx.wxID_ANY, "Task desk — wxLuma",
        _wx.wxDefaultPosition, _wx.wxSize(1080, 820));
    oFrame:SetMinClientSize(_wx.wxSize(920, 720));
    local oTabs = Controls.tabs(oFrame, {Items = {"Work", "Planning", "Resources", "Reports", "Settings"}});
    local oRoot = _wx.wxPanel(oTabs.Pages[1], _wx.wxID_ANY);
    local tWidgets, tNative, tOwned = {}, {oRoot}, {oTabs};
    local oPages;
    local bDisposed, bLoading, bDirty = false, false, false;
    local nSelected, nNextId = 1, 7;
    local tVisible = {};
    local tTasks = {
        {Title = "Prepare release notes", Priority = "High", Notes = "Summarize the changes and attach the review checklist.", Done = false},
        {Title = "Review navigation", Priority = "Normal", Notes = "Check keyboard navigation and menu actions.", Done = false},
        {Title = "Update project icons", Priority = "Low", Notes = "Check readability in both appearances.", Done = false},
        {Title = "Confirm chart totals", Priority = "Normal", Notes = "Compare the chart against completed tasks.", Done = false},
        {Title = "Organize the workspace", Priority = "Low", Notes = "Keep related actions close to their content.", Done = true},
        {Title = "Set up the activity log", Priority = "High", Notes = "Record meaningful actions as they happen.", Done = true},
    };
    local fSelect, fRefresh, fSave;

    --[[!
    @fqxn wxLuma.Tests.TaskDesk.fLabel
    @desc Creates native application text that participates in skin changes.
    !]]
    local function fLabel(sText, bHeading)
        local oLabel = _wx.wxStaticText(oRoot, _wx.wxID_ANY, sText);
        tNative[#tNative + 1] = oLabel;
        if (bHeading) then oLabel:SetName("heading"); end
        return oLabel;
    end

    --[[!
    @fqxn wxLuma.Tests.TaskDesk.fKeep
    @desc Records custom ownership and adds a control to a native layout sizer.
    !]]
    local function fKeep(sKey, oWidget, oSizer, nHeight, nWeight)
        tWidgets[sKey] = oWidget; tOwned[#tOwned + 1] = oWidget;
        oWidget.Control:SetMinSize(_wx.wxSize(1, nHeight));
        oSizer:Add(oWidget.Control, nWeight or 0, _wx.wxEXPAND + _wx.wxBOTTOM, 8);
        return oWidget;
    end

    --[[!
    @fqxn wxLuma.Tests.TaskDesk.fLog
    @desc Records a user action in the workspace's activity stream.
    !]]
    local function fLog(sText)
        tWidgets.Activity.addEntry({Text = sText, IconArtwork = "Icon Normal"});
    end

    local oOuter = _wx.wxBoxSizer(_wx.wxVERTICAL);
    local oHeader = _wx.wxBoxSizer(_wx.wxHORIZONTAL);
    oHeader:Add(fLabel("Task desk", true), 1, _wx.wxALIGN_CENTER_VERTICAL);
    oHeader:Add(fLabel("Appearance"), 0, _wx.wxALIGN_CENTER_VERTICAL + _wx.wxRIGHT, 8);
    local oAppearance = _wx.wxChoice(oRoot, _wx.wxID_ANY, _wx.wxDefaultPosition, _wx.wxDefaultSize, {"System", "Obsidian"});
    tNative[#tNative + 1] = oAppearance; oHeader:Add(oAppearance, 0, _wx.wxALIGN_CENTER_VERTICAL);
    oOuter:Add(oHeader, 0, _wx.wxEXPAND + _wx.wxBOTTOM, 6);
    oOuter:Add(fLabel("Plan the work, edit a task, and follow the results."), 0, _wx.wxBOTTOM, 14);

    local oSummary = _wx.wxBoxSizer(_wx.wxHORIZONTAL);
    local oRing = _wx.wxBoxSizer(_wx.wxVERTICAL);
    fKeep("Progress", Controls.irisProgress(oRoot, {Min = 0, Max = 100, Value = 0, Text = "%v%"}), oRing, 84);
    tWidgets.Progress.Control:SetMinSize(_wx.wxSize(84, 84)); oSummary:Add(oRing, 0, _wx.wxRIGHT, 16);
    local oSummaryText = _wx.wxBoxSizer(_wx.wxVERTICAL);
    local oTotals = fLabel("", true);
    oSummaryText:Add(oTotals, 0, _wx.wxTOP + _wx.wxBOTTOM, 12);
    oSummaryText:Add(fLabel("Complete a task to update the dashboard."), 0);
    oSummary:Add(oSummaryText, 1, _wx.wxEXPAND);
    local oAuto = _wx.wxBoxSizer(_wx.wxVERTICAL);
    oAuto:Add(fLabel("Save edits automatically"), 0, _wx.wxBOTTOM, 4);
    fKeep("Autosave", Controls.switch(oRoot, {Value = true, OnChange = function(bValue)
        if (bValue and bDirty) then fSave(); end
        fLog(bValue and "Automatic saving enabled." or "Automatic saving paused.");
    end}), oAuto, 30);
    tWidgets.Autosave.Control:SetMinSize(_wx.wxSize(76, 30));
    oSummary:Add(oAuto, 0, _wx.wxLEFT + _wx.wxTOP, 12);
    oOuter:Add(oSummary, 0, _wx.wxEXPAND + _wx.wxBOTTOM, 12);

    local oWork = _wx.wxBoxSizer(_wx.wxHORIZONTAL);
    local oQueue = _wx.wxBoxSizer(_wx.wxVERTICAL);
    oQueue:Add(fLabel("Work queue", true), 0, _wx.wxBOTTOM, 8);
    fKeep("Search", Controls.searchField(oRoot, {Hint = "Find a task…", Debounce = 0,
        OnSearch = function() fRefresh(); end}), oQueue, 36);
    fKeep("Tasks", Controls.listEx(oRoot, {RowHeight = 36, Items = {},
        Columns = {{Key = "Title", Title = "Task", Weight = 3}, {Key = "Priority", Title = "Priority", Width = 70},
            {Key = "State", Title = "Status", Width = 78}},
        OnChange = function(nIndex) if (not bLoading and tVisible[nIndex]) then fSelect(tVisible[nIndex]); end end}), oQueue, 220, 1);
    fKeep("NewTask", Controls.button(oRoot, {Text = "Add task", OnClick = function()
        if (bDirty) then fSave(); end
        tTasks[#tTasks + 1] = {Title = "New task "..nNextId, Priority = "Normal", Notes = "", Done = false};
        nNextId = nNextId + 1;
        tWidgets.Search.setValue(""); fSelect(#tTasks); fLog("Added a task.");
        tWidgets.Title.TextControl:SetFocus(); tWidgets.Title.TextControl:SelectAll();
    end}), oQueue, 36);
    oWork:Add(oQueue, 1, _wx.wxEXPAND + _wx.wxRIGHT, 20);

    local oDetails = _wx.wxBoxSizer(_wx.wxVERTICAL);
    oDetails:Add(fLabel("Task details", true), 0, _wx.wxBOTTOM, 8);
    local oEditStatus = fLabel("All changes saved");
    --[[!
    @fqxn wxLuma.Tests.TaskDesk.fEdited
    @desc Marks real user edits and applies the selected save policy.
    !]]
    local function fEdited()
        if (bLoading or bDisposed) then return; end
        bDirty = true; oEditStatus:SetLabel("Unsaved changes");
        if (tWidgets.Autosave.getValue()) then fSave(); end
    end
    fKeep("Title", Controls.textfield(oRoot, {Value = "", Hint = "Task title", OnChange = fEdited}), oDetails, 36);
    oDetails:Add(fLabel("Priority"), 0, _wx.wxBOTTOM, 4);
    local oPriority = _wx.wxChoice(oRoot, _wx.wxID_ANY, _wx.wxDefaultPosition, _wx.wxDefaultSize, {"Low", "Normal", "High"});
    tNative[#tNative + 1] = oPriority;
    oDetails:Add(oPriority, 0, _wx.wxEXPAND + _wx.wxBOTTOM, 8);
    oPriority:Connect(_wx.wxEVT_COMMAND_CHOICE_SELECTED, fEdited);
    oDetails:Add(fLabel("Notes"), 0, _wx.wxBOTTOM, 4);
    fKeep("Notes", Controls.multilineText(oRoot, {Value = "", OnChange = fEdited}), oDetails, 100, 1);
    local oActions = _wx.wxBoxSizer(_wx.wxHORIZONTAL);
    fKeep("Save", Controls.button(oRoot, {Text = "Save changes", OnClick = function() fSave(); end}), oActions, 36);
    fKeep("Complete", Controls.button(oRoot, {Text = "Mark complete", OnClick = function()
        fSave(); local tTask = tTasks[nSelected]; tTask.Done = not tTask.Done;
        fLog((tTask.Done and "Completed: " or "Reopened: ")..tTask.Title); fSelect(nSelected);
    end}), oActions, 36);
    -- Equal action widths avoid tiny native sizer defaults for custom buttons.
    tWidgets.Save.Control:SetMinSize(_wx.wxSize(145, 36)); tWidgets.Complete.Control:SetMinSize(_wx.wxSize(145, 36));
    oDetails:Add(oActions, 0, _wx.wxEXPAND); oDetails:Add(oEditStatus, 0, _wx.wxBOTTOM, 8);
    oWork:Add(oDetails, 1, _wx.wxEXPAND); oOuter:Add(oWork, 1, _wx.wxEXPAND + _wx.wxBOTTOM, 12);

    local oBottom = _wx.wxBoxSizer(_wx.wxHORIZONTAL);
    local oActivity = _wx.wxBoxSizer(_wx.wxVERTICAL);
    oActivity:Add(fLabel("Recent activity", true), 0, _wx.wxBOTTOM, 6);
    fKeep("Activity", Controls.logViewer(oRoot, {MaxEntries = 100, IconSize = 16,
        Entries = {{Text = "Workspace ready. Select a task to begin.", IconArtwork = "Icon Normal"}}}), oActivity, 140, 1);
    oBottom:Add(oActivity, 1, _wx.wxEXPAND + _wx.wxRIGHT, 20);
    fKeep("Chart", Controls.barChart(oRoot, {Title = "Completed tasks by priority", Legend = false,
        Series = {}, XRange = {Min = 0, Max = 4}, YRange = {Min = 0, Max = 6}}), oBottom, 170, 1);
    oOuter:Add(oBottom, 0, _wx.wxEXPAND);
    oOuter:Add(fLabel("Demo workspace · Low / Normal / High priorities are plotted from left to right."), 0, _wx.wxTOP, 6);
    local oPadding = _wx.wxBoxSizer(_wx.wxVERTICAL); oPadding:Add(oOuter, 1, _wx.wxEXPAND + _wx.wxALL, 18); oRoot:SetSizer(oPadding);
    local oWorkSizer = _wx.wxBoxSizer(_wx.wxVERTICAL); oWorkSizer:Add(oRoot, 1, _wx.wxEXPAND); oTabs.Pages[1]:SetSizer(oWorkSizer);
    local oFrameSizer = _wx.wxBoxSizer(_wx.wxVERTICAL); oFrameSizer:Add(oTabs.Control, 1, _wx.wxEXPAND); oFrame:SetSizer(oFrameSizer);

    --[[!
    @fqxn wxLuma.Tests.TaskDesk.fRefresh
    @desc Derives queue rows, totals and chart points from one task model.
        Filtering changes visibility only and does not discard the current task.
    !]]
    fRefresh = function()
        local sFind = tWidgets.Search.getValue():lower();
        local tRows, nDone, tCounts, nRow = {}, 0, {Low = 0, Normal = 0, High = 0}, 0;
        tVisible = {};
        for nIndex, tTask in ipairs(tTasks) do
            if (tTask.Done) then nDone = nDone + 1; tCounts[tTask.Priority] = tCounts[tTask.Priority] + 1; end
            if (tTask.Title:lower():find(sFind, 1, true)) then
                tVisible[#tVisible + 1] = nIndex;
                tRows[#tRows + 1] = {Title = tTask.Title, Priority = tTask.Priority, State = tTask.Done and "Complete" or "Open"};
                if (nIndex == nSelected) then nRow = #tRows; end
            end
        end
        tWidgets.Tasks.setItems(tRows); tWidgets.Tasks.setValue(nRow);
        tWidgets.Progress.setValue(math.floor(nDone / #tTasks * 100));
        oTotals:SetLabel(nDone.." of "..#tTasks.." tasks complete");
        tWidgets.Chart.setSeries({{Id = "done", Text = "Completed", Points = {
            {Id = "low", X = 1, Y = tCounts.Low}, {Id = "normal", X = 2, Y = tCounts.Normal}, {Id = "high", X = 3, Y = tCounts.High}}}});
        tWidgets.Complete.Text = tTasks[nSelected].Done and "Reopen task" or "Mark complete";
        tWidgets.Complete.Control:Refresh(false);
        if (oPages) then oPages.update(); end
    end;

    --[[!
    @fqxn wxLuma.Tests.TaskDesk.fSave
    @desc Commits current editors to their task without replacing controls.
    !]]
    fSave = function()
        if (not bDirty) then return; end
        local tTask, sTitle = tTasks[nSelected], tWidgets.Title.getValue();
        tTask.Title = sTitle:find("%S") and sTitle or "Untitled task";
        tTask.Notes, tTask.Priority = tWidgets.Notes.getValue(), oPriority:GetStringSelection();
        bDirty = false; oEditStatus:SetLabel("All changes saved"); fRefresh(); fLog("Saved: "..tTask.Title);
    end;

    --[[!
    @fqxn wxLuma.Tests.TaskDesk.fSelect
    @desc Commits the previous draft and silently binds the selected task.
    !]]
    fSelect = function(nIndex)
        assert(tTasks[nIndex], "Unknown task.");
        if (bDirty) then fSave(); end
        nSelected, bLoading = nIndex, true;
        tWidgets.Title.setValue(tTasks[nIndex].Title); tWidgets.Notes.setValue(tTasks[nIndex].Notes);
        oPriority:SetStringSelection(tTasks[nIndex].Priority); bLoading = false; fRefresh();
    end;

    --[[!
    @fqxn wxLuma.Tests.TaskDesk.fSetSkin
    @desc Updates custom controls and native application colors without resetting
        the task, current draft, search or selection.
    !]]
    local function fSetSkin(sName)
        oTheme.setName(sName); oAppearance:SetStringSelection(sName);
        for _, oNative in ipairs(tNative) do
            oNative:SetBackgroundColour(oTheme.color("Background")); oNative:SetForegroundColour(oTheme.color("Text"));
            local oFont = _wx.wxFont(oTheme.Font);
            if (oNative:GetName() == "heading") then oFont:SetWeight(_wx.wxFONTWEIGHT_BOLD); end
            oNative:SetFont(oFont); oFont:delete(); oNative:Refresh(false);
        end
        if (oPages) then oPages.refresh(); end
        oFrame:Layout(); oRoot:Layout();
    end
    oAppearance:Connect(_wx.wxEVT_COMMAND_CHOICE_SELECTED, function() fSetSkin(oAppearance:GetStringSelection()); end);
    local oMenuBar, oWorkspace = _wx.wxMenuBar(), _wx.wxMenu();
    local nNew, nSave, nExit = _wx.wxNewId(), _wx.wxNewId(), _wx.wxNewId();
    oWorkspace:Append(nNew, "&Add task\tCtrl+N"); oWorkspace:Append(nSave, "&Save changes\tCtrl+S");
    oWorkspace:AppendSeparator(); oWorkspace:Append(nExit, "E&xit"); oMenuBar:Append(oWorkspace, "&Workspace"); oFrame:SetMenuBar(oMenuBar);
    oFrame:Connect(nNew, _wx.wxEVT_COMMAND_MENU_SELECTED, function()
        tWidgets.NewTask.handleKey("down", _wx.WXK_RETURN); tWidgets.NewTask.handleKey("up", _wx.WXK_RETURN);
    end);
    oFrame:Connect(nSave, _wx.wxEVT_COMMAND_MENU_SELECTED, function() fSave(); end);
    oFrame:Connect(nExit, _wx.wxEVT_COMMAND_MENU_SELECTED, function() oFrame:Close(); end);
    oPages = require("Win.Tests.TaskDeskPages").create(oLuma, Controls, oFrame, oTabs, {
        Log = fLog, GetTasks = function() return tTasks; end, SelectTask = fSelect,
        Refresh = function() fRefresh(); end,
    });
    oFrame:Connect(_wx.wxEVT_CLOSE_WINDOW, function(oEvent)
        if (not bDisposed) then
            bDisposed = true;
            oPages.destroy();
            for nIndex = #tOwned, 1, -1 do tOwned[nIndex].destroy(); end
            oTheme.destroy();
        end
        oEvent:Skip();
    end);
    fSelect(1); fSetSkin(oTheme.getName());
    oFrame:SetClientSize(_wx.wxSize(1080, 820)); oFrame:Layout(); oRoot:Layout(); oFrame:Centre();
    if (tOptions.Show ~= false) then oFrame:Show(true); end
    return {Frame = oFrame, Widgets = tWidgets, Skin = oTheme, SetSkin = fSetSkin, SelectTask = fSelect,
        Priority = oPriority, Appearance = oAppearance, MenuIds = {New = nNew, Save = nSave},
        Tabs = oTabs, Pages = oPages, Coverage = tCoverage,
        GetTasks = function()
            local tCopy = {};
            for nIndex, tTask in ipairs(tTasks) do
                tCopy[nIndex] = {}; for sKey, vValue in pairs(tTask) do tCopy[nIndex][sKey] = vValue; end
            end
            return tCopy;
        end};
end;
