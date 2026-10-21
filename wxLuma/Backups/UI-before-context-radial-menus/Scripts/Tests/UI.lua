-- UI workbench: reusable controls use isolated sample values only.
local wx = require("wx");
local Window = require("UI.Containers.Window");
local Controls = require("UI.Controls");

return function(oParent)
    local oFrame = wx.wxFrame(oParent, wx.wxID_ANY, "UI Test - Workbench", wx.wxDefaultPosition, wx.wxSize(1120, 900));
    oFrame:SetMinClientSize(wx.wxSize(920, 780));
    local tSkin = Controls.loadSkin();
    local tWidgets, tInteractive, tTips = {}, {}, {};
    local sMessage = "Sample values only. Choose a tab; Tab moves focus.";
    local bEnabled, bDisposed = true, false;
    local tWindow;
    local function fMessage(sText)
        if (bDisposed) then return; end
        sMessage = sText;
        local tContent = tWindow.getGeometry().Content;
        tWindow.Control:RefreshRect(wx.wxRect(tContent.x, tContent.y + tContent.height - 28, tContent.width, 28), false);
    end
    tWindow = Window.create(oFrame, {Title = "UI TEST", Subtitle = "UI WORKBENCH  /  COMMON CONTROLS", PaintContent = function(oDC, tContent)
        tSkin.text(oDC, sMessage, tContent.x, tContent.y + tContent.height - 26, true);
    end});
    local function fOptions(tOptions) tOptions.Skin = tSkin; return tOptions; end
    local function fRemember(sKey, tWidget)
        tWidgets[sKey] = tWidget; tInteractive[#tInteractive + 1] = tWidget; return tWidget;
    end
    local function fChanged(sName) return function(vValue) fMessage(sName .. ": " .. tostring(vValue)); end; end
    local tTabs = Controls.tabs(tWindow.Control, fOptions({
        Items = {"Original controls", "Lists & text", "Resources & panel", "Display", "Containers", "Data", "Orb meters"},
        OnChange = function(nValue)
            fMessage("Tab: "..nValue);

            -- Selecting the container demonstration makes its navigation keys
            -- immediately usable instead of leaving focus on the tab strip.
            if (nValue == 5 and tWidgets.ScrollContainer) then
                tWidgets.ScrollContainer.Control:SetFocus();
            end
        end
    }));
    tWidgets.Tabs = tTabs;
    local oOriginal, oInput, oResources = tTabs.Pages[1], tTabs.Pages[2], tTabs.Pages[3];
    local function fLabel(oParent, sText, nX, nY)
        local oLabel = wx.wxStaticText(oParent, wx.wxID_ANY, sText, wx.wxPoint(nX, nY));
        oLabel:SetFont(tSkin.Font); oLabel:SetForegroundColour(wx.wxColour(177, 193, 210)); return oLabel;
    end
    oOriginal:SetBackgroundStyle(wx.wxBG_STYLE_PAINT);
    oOriginal:Connect(wx.wxEVT_PAINT, function()
        local oDC = wx.wxAutoBufferedPaintDC(oOriginal);
        if (bDisposed) then oDC:delete(); return; end
        local nW = oOriginal:GetClientSizeWH();
        local oBrush = wx.wxBrush(wx.wxColour(24, 29, 36)); oDC:SetBackground(oBrush); oDC:Clear();
        tSkin.text(oDC, "STATE GALLERY", 12, 12, true);
        local nColumn = math.floor((nW - 174) / 4);
        for nIndex, sState in ipairs({"Normal", "Hover", "Pressed", "Disabled"}) do
            tSkin.text(oDC, sState, 172 + (nIndex - 1) * nColumn, 42, true);
            local nRow = 0;
            for _, sFamily in ipairs({"Checkbox", "Radio"}) do for _, sValue in ipairs({"Off", "On"}) do
                local nY = 68 + nRow * 34;
                if (nIndex == 1) then tSkin.text(oDC, sFamily .. " / " .. sValue, 12, nY + 7, true); end
                tSkin.drawOpaque(oDC, sFamily .. " " .. sValue .. " " .. sState, 186 + (nIndex - 1) * nColumn, nY);
                nRow = nRow + 1;
            end end
        end
        tSkin.text(oDC, "INTERACTIVE CONTROLS", 12, 222, true);
        tSkin.text(oDC, "Horizontal slider", 12, 354, true);
        tSkin.text(oDC, "Vertical", math.floor(nW * 0.45), 354, true);
        tSkin.text(oDC, "Integer spinner", math.floor(nW * 0.66), 354, true);
        oBrush:delete(); oDC:delete();
    end);
    fRemember("Checkbox", Controls.checkbox(oOriginal, fOptions({Text = "Enable ambient sound", OnChange = fChanged("Sound")})));
    fRemember("DisabledCheckbox", Controls.checkbox(oOriginal, fOptions({Text = "Selected, disabled", Selected = true, Enabled = false})));
    local tGroup = Controls.radioGroup();
    for nIndex, sText in ipairs({"Balanced", "Cautious", "Unavailable"}) do
        fRemember("Radio" .. nIndex, Controls.radio(oOriginal, fOptions({Text = sText, Group = tGroup, Value = sText,
            Selected = nIndex == 1, Enabled = nIndex ~= 3, OnChange = fChanged("Radio")})));
    end
    fRemember("Slider", Controls.slider(oOriginal, fOptions({Min = 0, Max = 100, Step = 5, Value = 40, OnChange = fChanged("Horizontal")})));
    fRemember("VerticalSlider", Controls.slider(oOriginal, fOptions({Min = 0, Max = 100, Step = 5, Value = 65, Vertical = true, OnChange = fChanged("Vertical")})));
    fRemember("Spinner", Controls.spinner(oOriginal, fOptions({Min = 0, Max = 20, Step = 1, Value = 4, OnChange = fChanged("Spinner")})));
    fRemember("Button", Controls.button(oOriginal, fOptions({Text = "Apply sample", OnClick = function() fMessage("Sample applied. Sample action completed."); end})));
    local tToggle = Controls.button(oOriginal, fOptions({Text = "Toggle controls", OnClick = function()
        bEnabled = not bEnabled;
        for _, tWidget in ipairs(tInteractive) do tWidget.setEnabled(bEnabled); end
        for _, tTip in ipairs(tTips) do tTip.setEnabled(bEnabled); end
        tWidgets.DisabledCheckbox.setEnabled(false); tWidgets.Radio3.setEnabled(false); tWidgets.DisabledText.setEnabled(false);
        fMessage(bEnabled and "Controls enabled." or "Controls disabled; selected values remain visible.");
    end})); tWidgets.Toggle = tToggle;

    fLabel(oInput, "SELECTABLE LIST  /  10,000 sample rows", 16, 14);
    fLabel(oInput, "DROPDOWN  /  preview with arrows, Enter commits", 354, 14);
    local tItems = {};

    for nIndex = 1, 10000 do
        tItems[nIndex] = string.format("Sample entry %05d", nIndex);
    end
    fRemember("List", Controls.list(oInput, fOptions({Items = tItems, Value = 1, OnChange = fChanged("List row")})));
    fRemember("Dropdown", Controls.dropdown(oInput, fOptions({Items = tItems, Value = 5, Rows = 8, OnChange = fChanged("Dropdown row")})));
    fLabel(oInput, "TEXT FIELD  /  native selection, clipboard and editing", 354, 104);
    fRemember("Text", Controls.textfield(oInput, fOptions({Value = "Editable sample", Hint = "Type here", OnChange = fChanged("Text"), OnEnter = fChanged("Enter")})));
    fLabel(oInput, "DISABLED TEXT", 354, 194);
    fRemember("DisabledText", Controls.textfield(oInput, fOptions({Value = "Unavailable sample", Enabled = false})));
    fLabel(oInput, "HORIZONTAL SCROLLBAR  /  offset 0-900", 354, 284);
    fRemember("Scrollbar", Controls.scrollbar(oInput, fOptions({Min = 0, Max = 900, Page = 100, Value = 0, Vertical = false, OnChange = fChanged("Offset")})));
    fLabel(oInput, "Hover or focus the text field for a skinned tooltip.", 354, 382);
    fRemember("ListMultiSelect", Controls.checkbox(oInput, fOptions({
        Text = "List multi-select",
        OnChange = function(bEnabled)
            tWidgets.List.setMultiSelectEnabled(bEnabled, true);
        end
    })));
    fLabel(oInput, "Multi-select: Shift selects a range.\nCtrl/Cmd toggles rows; Ctrl/Cmd+A selects all.", 354, 480);
    tTips[1] = Controls.tooltip(tWidgets.Text.TextControl, fOptions({Text = "Native text editing inside the common skin.\nEnter reports the sample; no data is saved."}));
    tTips[2] = Controls.tooltip(tWidgets.List.Control, fOptions({Text = "Wheel or drag the scrollbar.\nArrows, Page Up/Down, Home/End select rows."}));

    fLabel(oResources, "RESOURCE METERS  /  linear and circular progress", 16, 14);
    fRemember("Health", Controls.progress(oResources, fOptions({Min = 0, Max = 100, Value = 70, Text = "Health  %v / %m", Colour = {R = 107, G = 142, B = 91}})));
    fRemember("Mana", Controls.progress(oResources, fOptions({Min = 0, Max = 100, Value = 45, Text = "Mana  %v / %m", Colour = {R = 77, G = 120, B = 169}})));
    fRemember("Progress", Controls.progress(oResources, fOptions({Min = 0, Max = 100, Value = 25, Text = "Loading  %v%", Colour = {R = 150, G = 128, B = 83}})));
    fRemember("DirectionalProgress", Controls.progress(oResources, fOptions({
        Min = 0,
        Max = 100,
        Value = 70,
        Orientation = "vertical",
        Origin = "bottom",
        Text = "%v%",
        Appearance = "skin"
    })));

    -- Changing direction changes only fill policy. The example chooses suitable
    -- dimensions explicitly; the reusable progress object never resizes itself.
    local function fDirectionalLayout()
        local nWidth = oResources:GetClientSizeWH();

        if (tWidgets.DirectionalProgress.getOrientation() == "vertical") then
            tWidgets.DirectionalProgress.layout(nWidth - 355, 46, 54, 126);
        else
            tWidgets.DirectionalProgress.layout(nWidth - 410, 90, 160, 40);
        end
    end

    fRemember("ProgressOrigin", Controls.button(oResources, fOptions({
        Text = "Fill from: bottom",
        OnClick = function()
            local tNext = {bottom = "top", top = "right", right = "left", left = "bottom"};
            local sOrigin = tNext[tWidgets.DirectionalProgress.getOrigin()];
            tWidgets.DirectionalProgress.setOrigin(sOrigin, true);
            tWidgets.ProgressOrigin.Text = "Fill from: "..sOrigin;
            tWidgets.ProgressOrigin.refresh();
            fDirectionalLayout();
            fMessage("Progress fills from "..sOrigin);
        end
    })));
    fRemember("CircularProgress", Controls.circularProgress(oResources, fOptions({
        Min = 0,
        Max = 100,
        Value = 25,
        Direction = "CW",
        Text = "%v%"
    })));
    fRemember("CircularDirection", Controls.button(oResources, fOptions({
        Text = "Direction: CW",
        OnClick = function()
            local oProgress = tWidgets.CircularProgress;
            local sDirection = oProgress.getDirection() == "CW" and "CCW" or "CW";
            oProgress.setDirection(sDirection, true);
            tWidgets.CircularDirection.Text = "Direction: "..sDirection;
            tWidgets.CircularDirection.refresh();
            fMessage("Circular progress direction: "..sDirection);
        end
    })));
    fRemember("CircularStartAngle", Controls.button(oResources, fOptions({
        Text = "Circle start: 0 degrees",
        OnClick = function()
            local nAngle = (tWidgets.CircularProgress.getStartAngle() + 45) % 360;
            tWidgets.CircularProgress.setStartAngle(nAngle, true);
            tWidgets.CircularStartAngle.Text = "Circle start: "..nAngle.." degrees";
            tWidgets.CircularStartAngle.refresh();
            fMessage("Circle starting angle: "..nAngle.." degrees");
        end
    })));
    fLabel(oResources, "0 top / 90 right / 180 bottom / 270 left", 280, 338);
    fRemember("MeterSlider", Controls.slider(oResources, fOptions({Min = 0, Max = 100, Step = 1, Value = 70, OnChange = function(nValue)
        for _, sKey in ipairs({"Health", "Mana", "Progress", "DirectionalProgress", "CircularProgress"}) do tWidgets[sKey].setValue(nValue); end; fMessage("Sample meters: " .. nValue);
    end})));
    fRemember("ProgressSkin", Controls.checkbox(oResources, fOptions({
        Text = "Skin linear meters",
        OnChange = function(bEnabled)
            for _, sKey in ipairs({"Health", "Mana", "Progress"}) do
                tWidgets[sKey].setAppearance(bEnabled and "skin" or "colour", true);
            end
        end
    })));
    fRemember("CircularProgressSkin", Controls.checkbox(oResources, fOptions({
        Text = "Skin circular meter",
        Selected = true,
        OnChange = function(bEnabled)
            tWidgets.CircularProgress.setAppearance(bEnabled and "skin" or "colour", true);
        end
    })));
    fRemember("Panel", Controls.panel(oResources, fOptions({Text = "RESIZABLE EMBEDDED PANEL", MinWidth = 260, MinHeight = 200,
        OnResize = function(nW, nH) fMessage("Embedded panel: " .. nW .. " x " .. nH); end})));
    local tPanel = tWidgets.Panel;
    fLabel(tPanel.Content, "Drag the bottom-right grip.\nFocus the border and use arrow keys.\nShift + arrows: 10 pixels. Escape cancels drag.", 8, 6);
    fRemember("PanelButton", Controls.button(tPanel.Content, fOptions({Text = "Panel action", OnClick = function() fMessage("The embedded panel button works."); end})));
    tWidgets.PanelButton.layout(8, 75, 160, 40);
    -- Demonstrate explicit containment and per-object oversized policy without
    -- resizing the tooltip or changing the target's normal parent/layout.
    tTips[3] = Controls.tooltip(tWidgets.PanelButton.Control, fOptions({
        Text = "Contained by the selected boundary.\nIts natural size is always preserved.",
        Containment = tPanel.Content
    }));
    local bPanelTooltipBoundary = true;
    fRemember("TooltipBoundary", Controls.button(oResources, fOptions({
        Text = "Tooltip: panel / window",
        OnClick = function()
            bPanelTooltipBoundary = not bPanelTooltipBoundary;
            tTips[3].setContainment(bPanelTooltipBoundary and tPanel.Content or oFrame);
            fMessage(bPanelTooltipBoundary and "Panel tooltip contained by panel content." or "Panel tooltip contained by window client area.");
        end
    })));
    fRemember("TooltipOverflow", Controls.button(oResources, fOptions({
        Text = "Oversized: hide / allow",
        OnClick = function()
            local sNext = tTips[3].getContainmentOverflow() == "hide" and "allow" or "hide";
            tTips[3].setContainmentOverflow(sNext);
            fMessage("Panel tooltip oversized policy: "..sNext..". Size remains unchanged.");
        end
    })));
    local tPanelToggle = Controls.button(oResources, fOptions({Text = "Hide / show panel", OnClick = function() tPanel.show(not tPanel.Control:IsShown()); fMessage(tPanel.Control:IsShown() and "Panel shown." or "Panel hidden."); end}));
    tWidgets.PanelToggle = tPanelToggle;

    -- Display samples use the same public objects and shared skin as applications.
    -- Keep the original three page indices stable for existing integration tests.
    local oOrbs = tTabs.Pages[7];
    fRemember("GlobeHeading", Controls.label(oOrbs, fOptions({Value = "GLOBE / straight liquid level"})));
    fRemember("RadialHeading", Controls.label(oOrbs, fOptions({Value = "RADIAL / concentric fill"})));
    fRemember("GlobeProgress", Controls.globeProgress(oOrbs, fOptions({
        Min = 0,
        Max = 100,
        Value = 65,
        Origin = "bottom",
        Text = "%v%",
        OnChange = fChanged("Globe progress")
    })));
    fRemember("RadialProgress", Controls.radialProgress(oOrbs, fOptions({
        Min = 0,
        Max = 100,
        Value = 65,
        Direction = "outward",
        Text = "%v%",
        OnChange = fChanged("Radial progress")
    })));
    fRemember("GlobeOrigin", Controls.button(oOrbs, fOptions({
        Text = "Fill from: bottom",
        OnClick = function()
            local tNext = {bottom = "top", top = "right", right = "left", left = "bottom"};
            local sOrigin = tNext[tWidgets.GlobeProgress.getOrigin()];
            tWidgets.GlobeProgress.setOrigin(sOrigin, true);
            tWidgets.GlobeOrigin.Text = "Fill from: "..sOrigin;
            tWidgets.GlobeOrigin.refresh();
            fMessage("Globe fills from "..sOrigin);
        end
    })));
    fRemember("RadialDirection", Controls.button(oOrbs, fOptions({
        Text = "Direction: outward",
        OnClick = function()
            local sDirection = tWidgets.RadialProgress.getDirection() == "outward" and "inward" or "outward";
            tWidgets.RadialProgress.setDirection(sDirection, true);
            tWidgets.RadialDirection.Text = "Direction: "..sDirection;
            tWidgets.RadialDirection.refresh();
            fMessage("Radial fill: "..sDirection);
        end
    })));
    fRemember("GlobeSkin", Controls.checkbox(oOrbs, fOptions({
        Text = "Skin globe",
        Selected = true,
        OnChange = function(bEnabled)
            tWidgets.GlobeProgress.setAppearance(bEnabled and "skin" or "colour", true);
        end
    })));
    fRemember("RadialSkin", Controls.checkbox(oOrbs, fOptions({
        Text = "Skin radial meter",
        Selected = true,
        OnChange = function(bEnabled)
            tWidgets.RadialProgress.setAppearance(bEnabled and "skin" or "colour", true);
        end
    })));
    fRemember("OrbValue", Controls.slider(oOrbs, fOptions({
        Min = 0,
        Max = 100,
        Step = 1,
        Value = 65,
        OnChange = function(nValue)
            tWidgets.GlobeProgress.setValue(nValue, true);
            tWidgets.RadialProgress.setValue(nValue, true);
            fMessage("Orb meters: "..nValue.."%");
        end
    })));
    fRemember("OrbHelp", Controls.label(oOrbs, fOptions({
        Wrap = true,
        Value = "The slider changes both meters. Directions and skins can change without changing value.\n"
            .."Globe: progress controls straight level distance through the circle.\n"
            .."Radial: progress controls radius; 50% outward reaches half-radius, 50% inward leaves a half-radius hole."
    })));

    local oDisplay, oContainers = tTabs.Pages[4], tTabs.Pages[5];
    local pSampleImage = APP_PATH.."/Images/UI/Window/Window Ornament Upper Left.png";
    fRemember("Label", Controls.label(oDisplay, fOptions({
        Value = "LABEL / hover, left click, right click and keyboard events",
        VerticalAlign = "center"
    })));
    fRemember("WrappedLabel", Controls.label(oDisplay, fOptions({
        Value = "This is a wxLuma Label. Text wraps to the available width and uses the shared skin font.\n\nResize the workbench to see wrapping change. Click the image button to cycle its scaling mode.",
        Wrap = true
    })));
    fRemember("AlignedLabel", Controls.label(oDisplay, fOptions({
        Value = "Centered horizontally and vertically",
        Align = "center", VerticalAlign = "center", Wrap = true
    })));
    fRemember("Image", Controls.image(oDisplay, fOptions({
        Value = pSampleImage, ScaleMode = "contain"
    })));
    fRemember("ImageMode", Controls.button(oDisplay, fOptions({
        Text = "Cycle image scaling",
        OnClick = function()
            local tModes = {"contain", "cover", "stretch", "native"};
            local sCurrent = tWidgets.Image.getScaleMode();

            for nIndex, sMode in ipairs(tModes) do
                if (sMode == sCurrent) then
                    local sNext = tModes[nIndex % #tModes + 1];
                    tWidgets.Image.setScaleMode(sNext);
                    fMessage("Image scaling: "..sNext);
                    break;
                end
            end
        end
    })));

    for _, sKey in ipairs({"Label", "WrappedLabel", "AlignedLabel", "Image"}) do
        local oSample = tWidgets[sKey];

        for _, sEvent in ipairs({"pointerEnter", "pointerLeave", "leftClick", "rightClick",
            "middleClick", "leftDoubleClick", "contextMenu", "keyDown"}) do
            oSample.on(sEvent, function(oSource, tEvent)
                fMessage(sKey..": "..tEvent.Name);
            end);
        end
    end

    fRemember("ScrollContainer", Controls.scrollContainer(oContainers, fOptions({
        ContentWidth = 1200, ContentHeight = 1000,
        OnChange = function(tValue)
            fMessage("Scroll offset: "..tValue.X..", "..tValue.Y);
        end
    })));
    local oScrollContent = tWidgets.ScrollContainer.Content;
    fRemember("ScrollLabel", Controls.label(oScrollContent, fOptions({
        Value = "SCROLL CONTAINER / 1200 x 1000 content\n\nWheel scrolls; Shift + wheel scrolls horizontally. Focus the background and use arrows, Page Up/Down, Home or End. Child controls retain their own input.",
        Wrap = true
    })));
    tWidgets.ScrollLabel.layout(16, 16, 520, 150);
    fRemember("ScrollImage", Controls.image(oScrollContent, fOptions({
        Value = pSampleImage, ScaleMode = "contain"
    })));
    tWidgets.ScrollImage.layout(660, 30, 360, 240);
    fRemember("ScrollButton", Controls.button(oScrollContent, fOptions({
        Text = "Bottom-right action",
        OnClick = function()
            fMessage("The scrolled child button works.");
        end
    })));
    tWidgets.ScrollButton.layout(900, 880, 240, 48);
    fRemember("ScrollEndLabel", Controls.label(oScrollContent, fOptions({
        Value = "END OF CONTENT / both axes are scrollable", Wrap = true
    })));
    tWidgets.ScrollEndLabel.layout(700, 940, 460, 50);
    fRemember("ScrollReset", Controls.button(oContainers, fOptions({
        Text = "Scroll to origin",
        OnClick = function()
            tWidgets.ScrollContainer.scrollTo(0, 0, true);
            tWidgets.ScrollContainer.Control:SetFocus();
        end
    })));
    fRemember("ScrollEnd", Controls.button(oContainers, fOptions({
        Text = "Scroll to end",
        OnClick = function()
            tWidgets.ScrollContainer.scrollTo(1200, 1000, true);
            tWidgets.ScrollContainer.Control:SetFocus();
        end
    })));

    -- Static display samples inside the container hand focus back after a click;
    -- buttons and other interactive children retain their normal input ownership.
    for _, sKey in ipairs({"ScrollLabel", "ScrollImage", "ScrollEndLabel"}) do
        tWidgets[sKey].on("leftUp", function()
            tWidgets.ScrollContainer.Control:SetFocus();
        end);
    end
    -- Data controls expose stable IDs rather than tying application state to
    -- captions or current display order. Both demos support live add/remove.
    local oData = tTabs.Pages[6];
    fRemember("Tree", Controls.tree(oData, fOptions({
        Items = {
            {Id = "scene", Text = "Scene", Expanded = true, Children = {
                {Id = "actors", Text = "Actors", Expanded = true, Children = {
                    {Id = "player", Text = "Player"},
                    {Id = "merchant", Text = "Merchant"}
                }},
                {Id = "resources", Text = "Resources", Children = {
                    {Id = "textures", Text = "Textures"},
                    {Id = "sounds", Text = "Sounds"}
                }}
            }}
        },
        Value = "player", OnChange = fChanged("Tree selection")
    })));
    local tRows = {};

    for nIndex = 1, 1000 do
        tRows[nIndex] = {
            Id = "record-"..nIndex,
            Cells = {string.format("Object %04d", nIndex), nIndex % 2 == 0 and "Actor" or "Resource",
                string.format("%04d", nIndex * 3)}
        };
    end

    fRemember("Table", Controls.table(oData, fOptions({
        Columns = {{Text = "Name", Width = 190}, {Text = "Kind", Width = 130}, {Text = "Value", Width = 100}},
        Items = tRows, Value = "record-1", OnChange = fChanged("Table selection")
    })));
    fRemember("TableMultiSelect", Controls.checkbox(oData, fOptions({
        Text = "Multi-select",
        OnChange = function(bEnabled)
            tWidgets.Table.setMultiSelectEnabled(bEnabled, true);
        end
    })));
    fRemember("TreeHeading", Controls.label(oData, fOptions({Value = "TREE / add, remove, expand"})));
    fRemember("TableHeading", Controls.label(oData, fOptions({Value = "TABLE / 1,000 rows / click headers to sort"})));
    local nNewNode, nNewRow = 0, 1000;
    fRemember("TreeAdd", Controls.button(oData, fOptions({
        Text = "Add child",
        OnClick = function()
            nNewNode = nNewNode + 1;
            local sParent = tWidgets.Tree.getValue();
            local sId = "added-node-"..nNewNode;
            tWidgets.Tree.addNode(sParent, {Id = sId, Text = "New node "..nNewNode}, true);
            tWidgets.Tree.setValue(sId, true);
            tWidgets.Tree.TreeControl:SetFocus();
        end
    })));
    fRemember("TreeRemove", Controls.button(oData, fOptions({
        Text = "Remove node",
        OnClick = function()
            local sId = tWidgets.Tree.getValue();

            if (sId) then
                tWidgets.Tree.removeNode(sId, true);
                fMessage("Removed tree subtree: "..sId);
            end
        end
    })));
    fRemember("TableAdd", Controls.button(oData, fOptions({
        Text = "Add row",
        OnClick = function()
            nNewRow = nNewRow + 1;
            local sId = "record-"..nNewRow;
            tWidgets.Table.addRow({Id = sId, Cells = {"New object "..nNewRow, "Sample", "0000"}}, true);
            tWidgets.Table.setValue(sId, true);
            tWidgets.Table.TableControl:SetFocus();
        end
    })));
    fRemember("TableRemove", Controls.button(oData, fOptions({
        Text = "Remove row",
        OnClick = function()
            local tSelected = tWidgets.Table.getSelected();

            for _, sId in ipairs(tSelected) do
                tWidgets.Table.removeRow(sId, true);
            end

            fMessage("Removed table rows: "..#tSelected);
        end
    })));

    for _, sEvent in ipairs({"itemExpanded", "itemCollapsed", "itemActivated", "rightClick"}) do
        tWidgets.Tree.on(sEvent, function(oSource, tEvent)
            fMessage("Tree: "..tEvent.Name.." "..tostring(tEvent.Id or ""));
        end);
    end

    for _, sEvent in ipairs({"sorted", "itemActivated", "rightClick"}) do
        tWidgets.Table.on(sEvent, function(oSource, tEvent)
            fMessage("Table: "..tEvent.Name.." "..tostring(tEvent.Column or tEvent.Id or ""));
        end);
    end

    -- ListEx uses caller-defined typed columns while retaining whole-row
    -- selection. Its buttons demonstrate independent cell edits and row changes.
    local tCharacters = {};
    local tPortraits = {
        APP_PATH.."/Images/UI/Window/Window Ornament Upper Left.png",
        APP_PATH.."/Images/UI/Window/Window Ornament Upper Right.png",
        APP_PATH.."/Images/UI/Window/Window Ornament Lower Left.png",
        APP_PATH.."/Images/UI/Window/Window Ornament Lower Right.png"
    };
    local tClasses = {"Warrior", "Mage", "Ranger"};

    for nIndex = 1, 1000 do
        tCharacters[nIndex] = {
            Picture = tPortraits[(nIndex - 1) % #tPortraits + 1],
            Name = string.format("Character %04d", nIndex),
            Class = tClasses[(nIndex - 1) % #tClasses + 1]
        };
    end

    fRemember("ListEx", Controls.listEx(oData, fOptions({
        Columns = {
            {Key = "Picture", Type = "image", Width = 60},
            {Key = "Name", Type = "text", Weight = 2},
            {Key = "Class", Type = "text", Weight = 1}
        },
        Items = tCharacters, Value = 1, RowHeight = 56,
        OnChange = fChanged("Character row"),
        OnActivate = function(nIndex)
            fMessage("Activated: "..tWidgets.ListEx.getCell(nIndex, 2));
        end
    })));
    fRemember("ListExMultiSelect", Controls.checkbox(oData, fOptions({
        Text = "Multi-select",
        OnChange = function(bEnabled)
            tWidgets.ListEx.setMultiSelectEnabled(bEnabled, true);
        end
    })));

    -- Selection events expose a complete snapshot even when the primary row
    -- stays unchanged, such as removing another row from a multi-selection.
    for _, sKey in ipairs({"List", "ListEx", "Table"}) do
        tWidgets[sKey].on("selectionChanged", function(oSource)
            fMessage(sKey..": "..#oSource.getSelected().." selected");
        end);
    end

    local oListExHeading = fLabel(oData, "LISTEX / picture, name, class / 1,000 initial rows", 16, 0);
    local nNewCharacter = 1000;
    fRemember("ListExUpdate", Controls.button(oData, fOptions({
        Text = "Change class",
        OnClick = function()
            local nIndex = tWidgets.ListEx.getValue();

            if (nIndex > 0) then
                local sOld = tWidgets.ListEx.getCell(nIndex, 3);
                tWidgets.ListEx.setCell(nIndex, 3, sOld == "Mage" and "Ranger" or "Mage", true);
                fMessage("Changed only the selected character's class.");
            end
        end
    })));
    fRemember("ListExAdd", Controls.button(oData, fOptions({
        Text = "Add row",
        OnClick = function()
            nNewCharacter = nNewCharacter + 1;
            tWidgets.ListEx.addItem({Picture = tPortraits[1], Name = "New character "..nNewCharacter, Class = "Warrior"}, true);
            tWidgets.ListEx.setValue(#tWidgets.ListEx.Items, true);
        end
    })));
    fRemember("ListExRemove", Controls.button(oData, fOptions({
        Text = "Remove row",
        OnClick = function()
            local tSelected = tWidgets.ListEx.getSelected();

            -- Remove from the end so earlier indices still refer to the same rows.
            for nPosition = #tSelected, 1, -1 do
                tWidgets.ListEx.removeItem(tSelected[nPosition], true);
            end
        end
    })));
    -- Split panes live with the scrolling demo in the Containers category.
    fRemember("SplitContainer", Controls.splitContainer(oContainers, fOptions({
        Value = 0.5, MinFirst = 100, MinSecond = 100,
        OnChange = function(nRatio)
            fMessage(string.format("Split: %.1f%%", nRatio * 100));
        end
    })));
    fRemember("SplitFirstLabel", Controls.label(tWidgets.SplitContainer.First, fOptions({
        Value = "FIRST PANE\nDrag the divider, or focus it and use arrows, Home and End. Escape cancels a drag.",
        Wrap = true
    })));
    fRemember("SplitSecondLabel", Controls.label(tWidgets.SplitContainer.Second, fOptions({
        Value = "SECOND PANE\nEach pane is a native parent for independent child controls.", Wrap = true
    })));
    fRemember("SplitFirstButton", Controls.button(tWidgets.SplitContainer.First, fOptions({
        Text = "First pane action", OnClick = function()
            fMessage("First split pane action.");
        end
    })));
    fRemember("SplitSecondButton", Controls.button(tWidgets.SplitContainer.Second, fOptions({
        Text = "Second pane action", OnClick = function()
            fMessage("Second split pane action.");
        end
    })));
    fRemember("SplitToggle", Controls.button(oContainers, fOptions({
        Text = "Switch split direction",
        OnClick = function()
            local oSplit = tWidgets.SplitContainer;
            oSplit.setOrientation(oSplit.getOrientation() == "vertical" and "horizontal" or "vertical");
            oSplit.Control:SetFocus();
        end
    })));

    -- Pane size notifications lay out their own children while dragging, rather
    -- than waiting for the whole workbench frame to be resized.
    local function fSplitChildren()
        for nIndex, sPrefix in ipairs({"SplitFirst", "SplitSecond"}) do
            local nPaneWidth, nPaneHeight = tWidgets.SplitContainer.Panes[nIndex]:GetClientSizeWH();
            tWidgets[sPrefix.."Label"].layout(12, 8, math.max(1, nPaneWidth - 24), math.max(1, nPaneHeight - 66));
            tWidgets[sPrefix.."Button"].layout(12, math.max(8, nPaneHeight - 50),
                math.max(1, math.min(190, nPaneWidth - 24)), 40);
        end
    end

    for _, oPane in ipairs(tWidgets.SplitContainer.Panes) do
        oPane:Connect(wx.wxEVT_SIZE, function(jEvent)
            if (not bDisposed) then
                fSplitChildren();
            end

            jEvent:Skip();
        end);
    end
    local function fLayout()
        local nW, nH = tWindow.Control:GetClientSizeWH(); if (nW < 320 or nH < 240) then return; end
        local tContent = tWindow.getGeometry().Content;
        tTabs.layout(tContent.x, tContent.y, tContent.width, tContent.height - 42);
        local nWidth, nHeight = oOriginal:GetClientSizeWH();
        tWidgets.Checkbox.layout(12, 252, math.floor(nWidth * 0.42), 36);
        tWidgets.DisabledCheckbox.layout(12, 295, math.floor(nWidth * 0.42), 36);
        local nRadioX = math.floor(nWidth * 0.45);
        for nIndex = 1, 3 do tWidgets["Radio" .. nIndex].layout(nRadioX, 248 + (nIndex - 1) * 30, 175, 32); end
        tWidgets.Button.layout(nWidth - 186, 250, 174, 40); tToggle.layout(nWidth - 186, 296, 174, 40);
        tWidgets.Slider.layout(12, 394, math.floor(nWidth * 0.39), 44);
        tWidgets.VerticalSlider.layout(nRadioX + 20, 384, 44, math.min(148, nHeight - 390));
        tWidgets.Spinner.layout(math.floor(nWidth * 0.66), 394, 140, 40);
        local nInputW, nInputH = oInput:GetClientSizeWH();
        local nRightW = math.max(200, nInputW - 370);
        tWidgets.List.layout(16, 46, 310, nInputH - 62);
        tWidgets.Dropdown.layout(354, 46, nRightW, 40);
        tWidgets.ListMultiSelect.layout(354, 430, nRightW, 36);
        tWidgets.Text.layout(354, 136, nRightW, 40); tWidgets.DisabledText.layout(354, 226, nRightW, 40);
        tWidgets.Scrollbar.layout(354, 320, nRightW, 26);

        local nResourceW = oResources:GetClientSizeWH();
        tWidgets.CircularProgress.layout(nResourceW - 210, 40, 160, 140);
        tWidgets.CircularDirection.layout(nResourceW - 230, 190, 200, 36);
        fDirectionalLayout();
        tWidgets.ProgressOrigin.layout(nResourceW - 420, 190, 180, 36);
        tWidgets.CircularStartAngle.layout(16, 330, 250, 36);
        for nIndex, sKey in ipairs({"Health", "Mana", "Progress"}) do tWidgets[sKey].layout(16, 46 + (nIndex - 1) * 46, math.min(500, nResourceW - 450), 34); end
        tWidgets.MeterSlider.layout(16, 184, math.min(500, nResourceW - 450), 44);
        tPanelToggle.layout(16, 236, 210, 40);
        tWidgets.TooltipBoundary.layout(242, 236, 240, 40);
        tWidgets.TooltipOverflow.layout(498, 236, 240, 40);
        tWidgets.ProgressSkin.layout(16, 282, 300, 36);
        tWidgets.CircularProgressSkin.layout(354, 282, 300, 36);
        local nPanelW, nPanelH = tPanel.Control:GetSizeWH();
        if (nPanelW < 260 or nPanelH < 140) then nPanelW, nPanelH = 440, 190; end
        tPanel.layout(16, 380, nPanelW, nPanelH); tPanel.resize(nPanelW, nPanelH);
        local nOrbWidth, nOrbHeight = oOrbs:GetClientSizeWH();
        local nOrbHalf = math.floor(nOrbWidth / 2);
        local nOrbDiameter = math.max(32, math.min(220, nOrbHalf - 48, nOrbHeight - 280));
        local nOrbButtonY = nOrbDiameter + 78;
        tWidgets.GlobeHeading.layout(16, 12, nOrbHalf - 32, 36);
        tWidgets.RadialHeading.layout(nOrbHalf + 16, 12, nOrbWidth - nOrbHalf - 32, 36);
        tWidgets.GlobeProgress.layout(math.floor((nOrbHalf - nOrbDiameter) / 2), 60, nOrbDiameter, nOrbDiameter);
        tWidgets.RadialProgress.layout(nOrbHalf + math.floor((nOrbWidth - nOrbHalf - nOrbDiameter) / 2),
            60, nOrbDiameter, nOrbDiameter);
        tWidgets.GlobeOrigin.layout(24, nOrbButtonY, nOrbHalf - 48, 40);
        tWidgets.RadialDirection.layout(nOrbHalf + 24, nOrbButtonY, nOrbWidth - nOrbHalf - 48, 40);
        tWidgets.GlobeSkin.layout(24, nOrbButtonY + 48, nOrbHalf - 48, 36);
        tWidgets.RadialSkin.layout(nOrbHalf + 24, nOrbButtonY + 48, nOrbWidth - nOrbHalf - 48, 36);
        tWidgets.OrbValue.layout(24, nOrbButtonY + 104, nOrbWidth - 48, 44);
        tWidgets.OrbHelp.layout(24, nOrbButtonY + 164, nOrbWidth - 48, math.max(32, nOrbHeight - nOrbButtonY - 180));
        local nDisplayWidth = oDisplay:GetClientSizeWH();
        local nTextWidth = math.floor((nDisplayWidth - 48) / 2);
        tWidgets.Label.layout(16, 16, nDisplayWidth - 32, 48);
        tWidgets.WrappedLabel.layout(16, 80, nTextWidth, 220);
        tWidgets.AlignedLabel.layout(16, 320, nTextWidth, 100);
        tWidgets.Image.layout(32 + nTextWidth, 80, nTextWidth, 300);
        tWidgets.ImageMode.layout(32 + nTextWidth, 400, nTextWidth, 42);
        local nContainerWidth, nContainerHeight = oContainers:GetClientSizeWH();
        tWidgets.ScrollReset.layout(16, 12, 200, 40);
        tWidgets.ScrollEnd.layout(232, 12, 200, 40);
        tWidgets.SplitToggle.layout(448, 12, 240, 40);
        local nScrollHeight = math.floor(math.max(160, nContainerHeight - 84) * 0.58);
        tWidgets.ScrollContainer.layout(16, 68, nContainerWidth - 32, nScrollHeight);
        local nSplitY = 80 + nScrollHeight;
        tWidgets.SplitContainer.layout(16, nSplitY, nContainerWidth - 32,
            math.max(60, nContainerHeight - nSplitY - 16));
        fSplitChildren();
        local nDataWidth, nDataHeight = oData:GetClientSizeWH();
        local nTreeWidth = math.floor((nDataWidth - 48) * 0.36);
        local nTableX = 32 + nTreeWidth;
        local nTableWidth = nDataWidth - nTableX - 16;
        tWidgets.TreeHeading.layout(16, 12, nTreeWidth, 30);
        tWidgets.TableHeading.layout(nTableX, 12, nTableWidth, 30);
        local nDataControlHeight = math.max(80, math.floor((nDataHeight - 160) * 0.58));
        local nDataButtonY = 66 + nDataControlHeight;
        tWidgets.Tree.layout(16, 54, nTreeWidth, nDataControlHeight);
        tWidgets.Table.layout(nTableX, 54, nTableWidth, nDataControlHeight);
        local nTreeButtonWidth = math.floor((nTreeWidth - 8) / 2);
        tWidgets.TreeAdd.layout(16, nDataButtonY, nTreeButtonWidth, 40);
        tWidgets.TreeRemove.layout(24 + nTreeButtonWidth, nDataButtonY, nTreeButtonWidth, 40);
        tWidgets.TableAdd.layout(nTableX, nDataButtonY, 130, 40);
        tWidgets.TableRemove.layout(nTableX + 142, nDataButtonY, 130, 40);
        tWidgets.TableMultiSelect.layout(nTableX + 284, nDataButtonY, math.max(120, nTableWidth - 284), 40);
        local nListExY = nDataButtonY + 82;
        oListExHeading:SetSize(16, nDataButtonY + 52, nDataWidth - 32, 24);
        tWidgets.ListEx.layout(16, nListExY, nDataWidth - 220, math.max(64, nDataHeight - nListExY - 16));
        tWidgets.ListExUpdate.layout(nDataWidth - 188, nListExY, 172, 36);
        tWidgets.ListExAdd.layout(nDataWidth - 188, nListExY + 44, 172, 36);
        tWidgets.ListExRemove.layout(nDataWidth - 188, nListExY + 88, 172, 36);
        tWidgets.ListExMultiSelect.layout(nDataWidth - 188, nListExY + 132, 172, 34);
    end
    local oSizer = wx.wxBoxSizer(wx.wxVERTICAL); oSizer:Add(tWindow.Control, 1, wx.wxEXPAND); oFrame:SetSizer(oSizer);
    tWindow.Control:Connect(wx.wxEVT_SIZE, function(oEvent) if (not bDisposed) then fLayout(); end; oEvent:Skip(); end);
    oFrame:Connect(wx.wxEVT_CHAR_HOOK, function(oEvent)
        if (oEvent:GetKeyCode() == wx.WXK_ESCAPE) then
            if (tWidgets.Dropdown.isOpen()) then tWidgets.Dropdown.close(false);
            elseif (tPanel.Control:HasCapture()) then tPanel.handleKey("down", wx.WXK_ESCAPE);
            elseif (tWidgets.SplitContainer.Control:HasCapture()) then
                tWidgets.SplitContainer.handleKey("down", wx.WXK_ESCAPE);
            else oFrame:Close(); end
        else oEvent:Skip(); end
    end);
    oFrame:Connect(wx.wxEVT_ACTIVATE, function(oEvent)
        if (not oEvent:GetActive()) then for _, tTip in ipairs(tTips) do tTip.hide(); end end; oEvent:Skip();
    end);
    oFrame:Connect(wx.wxEVT_CLOSE_WINDOW, function(oEvent)
        bDisposed = true;
        for _, tTip in ipairs(tTips) do tTip.destroy(); end
        for _, tWidget in pairs(tWidgets) do tWidget.destroy(); end
        tSkin.destroy(); tWindow.destroy(); oEvent:Skip();
    end);
    oFrame:SetClientSize(wx.wxSize(1120, 900)); oFrame:Centre(); oFrame:Show(true); fLayout();
    return {Frame = oFrame, Window = tWindow, Widgets = tWidgets, Skin = tSkin, Group = tGroup, Layout = fLayout, Tooltips = tTips};
end;
