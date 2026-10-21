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
        LayoutMode = "wrap",
        Items = {"Original controls", "Lists & text", "Resources & panel", "Display", "Containers", "Data", "Orb meters", "Menus", "Editors", "Tools", "Tabs", "TreeEx"},
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
        for _, tWidget in ipairs(tInteractive) do
            -- Removed tab pages dispose their sample children through native
            -- ownership; the global switch must skip those retired objects.
            if (not tWidget.Disposed) then
                tWidget.setEnabled(bEnabled);
            end
        end
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
    fRemember("IrisHeading", Controls.label(oOrbs, fOptions({Value = "IRIS / aperture blades"})));
    fRemember("IrisProgress", Controls.irisProgress(oOrbs, fOptions({
        Min = 0,
        Max = 100,
        Value = 65,
        Text = "%v%",
        BackgroundImage = APP_PATH.."/Images/UI/Menu/Command Shield.png",
        OnChange = fChanged("Iris progress")
    })));
    fRemember("IrisDirection", Controls.button(oOrbs, fOptions({
        Text = "Iris: opening",
        OnClick = function()
            local sDirection = tWidgets.IrisProgress.getDirection() == "opening" and "closing" or "opening";
            tWidgets.IrisProgress.setDirection(sDirection, true);
            tWidgets.IrisDirection.Text = "Iris: "..sDirection;
            tWidgets.IrisDirection.refresh();
        end
    })));
    fRemember("IrisBlades", Controls.button(oOrbs, fOptions({
        Text = "Blades: 6 / rotate",
        OnClick = function()
            local nCount = tWidgets.IrisProgress.getBladeCount() % 10 + 3;
            tWidgets.IrisProgress.setBladeCount(nCount, true);
            tWidgets.IrisProgress.setRotation(tWidgets.IrisProgress.getRotation() + 15, true);
            tWidgets.IrisBlades.Text = "Blades: "..nCount.." / rotate";
            tWidgets.IrisBlades.refresh();
        end
    })));
    fRemember("IrisPicture", Controls.checkbox(oOrbs, fOptions({
        Text = "Clipped iris picture",
        Selected = true,
        OnChange = function(bSelected)
            tWidgets.IrisProgress.setBackgroundImage(bSelected
                and APP_PATH.."/Images/UI/Menu/Command Shield.png" or nil, true);
        end
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
            tWidgets.IrisProgress.setValue(nValue, true);
            fMessage("Orb meters: "..nValue.."%");
        end
    })));
    fRemember("OrbReserved", Controls.slider(oOrbs, fOptions({
        Min = 0,
        Max = 100,
        Step = 1,
        Value = 0,
        OnChange = function(nValue)
            for _, sKey in ipairs({"GlobeProgress", "RadialProgress", "IrisProgress", "CircularProgress", "Progress"}) do
                tWidgets[sKey].setReserved(nValue, true);
            end

            fMessage("Reserved capacity: "..nValue.." / 100");
        end
    })));
    fRemember("GlobeReserveOrigin", Controls.button(oOrbs, fOptions({
        Text = "Reserve edge: automatic",
        OnClick = function()
            local tNext = {left = "right", right = "top", top = "bottom"};
            local sOld = tWidgets.GlobeProgress.getReserveOrigin();
            local sNew = sOld == nil and "left" or tNext[sOld];
            tWidgets.GlobeProgress.setReserveOrigin(sNew, true);
            tWidgets.GlobeReserveOrigin.Text = "Reserve edge: "..(sNew or "automatic");
            tWidgets.GlobeReserveOrigin.refresh();
        end
    })));
    fRemember("RadialReserveDirection", Controls.button(oOrbs, fOptions({
        Text = "Reserve: automatic",
        OnClick = function()
            local sOld = tWidgets.RadialProgress.getReserveDirection();
            local sNew;

            if (sOld == nil) then
                sNew = "inward";
            elseif (sOld == "inward") then
                sNew = "outward";
            end

            tWidgets.RadialProgress.setReserveDirection(sNew, true);
            tWidgets.RadialReserveDirection.Text = "Reserve: "..(sNew or "automatic");
            tWidgets.RadialReserveDirection.refresh();
        end
    })));
    fRemember("CircularPie", Controls.checkbox(oOrbs, fOptions({
        Text = "Circular meter: solid pie",
        Selected = false,
        OnChange = function(bSelected)
            if (bSelected) then
                tWidgets.CircularProgress.setRadii(0, 100, true);
            else
                tWidgets.CircularProgress.setRadii(nil, nil, true);
            end
        end
    })));
    fRemember("OrbHelp", Controls.label(oOrbs, fOptions({
        Wrap = true,
        Value = "First slider: current. Second slider: reserve (purple). Reserve buttons change its independent direction.\n"
            .."Globe: progress controls straight level distance through the circle.\n"
            .."Radial measures distance along the usable radius. Current never overlaps the reserve.\nThe pie option changes the circular meter on Resources & panel."
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
    local oMenus = tTabs.Pages[8];
    local tMenuImages = {
        APP_PATH.."/Images/UI/Menu/Command Sword.png",
        APP_PATH.."/Images/UI/Menu/Command Shield.png",
        APP_PATH.."/Images/UI/Menu/Command Banner.png"
    };
    local tMenuChildren = {};

    for nIndex = 1, 26 do
        tMenuChildren[nIndex] = {Id = "build-"..nIndex, Text = "Build "..nIndex,
            Shape = ({"circle", "diamond", "square"})[(nIndex - 1) % 3 + 1],
            Image = nIndex % 3 == 0 and tMenuImages[2] or nil, Value = {Command = "build", Index = nIndex}};
    end

    tMenuChildren[2].Items = {
        {Id = "upgrade-armor", Text = "Armor", Image = tMenuImages[2], Value = "armor"},
        {Id = "upgrade-weapons", Text = "Arms", Image = tMenuImages[1], Value = "weapons"}
    };
    local tMenuItems = {
        {Id = "attack", Text = "Attack", Image = tMenuImages[1], Width = 80, Height = 80,
            ImageWidth = 104, ImageHeight = 104, Value = "attack"},
        {Id = "defend", Text = "Guard", Image = tMenuImages[2], Shape = "diamond", Width = 80, Height = 80, Value = "defend"},
        {Id = "build", Text = "Build", Image = tMenuImages[3], Shape = "square", Items = tMenuChildren},
        {Id = "unavailable", Text = "Locked", Enabled = false, Value = "locked"}
    };

    for nIndex = 1, 22 do
        tMenuItems[#tMenuItems + 1] = {Id = "command-"..nIndex, Text = "Cmd "..nIndex,
            Shape = nIndex % 2 == 0 and "square" or nil, Value = nIndex};
    end

    local function fMenuSelected(tSelection, oMenu)
        local sPath = table.concat(tSelection.Path, " / ");
        tWidgets.MenuSelection.setValue("Selected: "..sPath);
        fMessage(oMenu.Kind.." action: "..tSelection.Id);
    end

    fRemember("ContextMenu", Controls.contextMenu(oMenus, fOptions({Items = tMenuItems, OnSelect = fMenuSelected})));
    fRemember("RadialMenu", Controls.radialMenu(oMenus, fOptions({Items = tMenuItems,
        MinRadius = 64, MaxRadius = 160, Spacing = 12, OnSelect = fMenuSelected})));
    fRemember("ContextMenuTarget", Controls.button(oMenus, fOptions({
        Text = "Context menu: click / right-click",
        OnClick = function()
            tWidgets.ContextMenu.showAtObject(tWidgets.ContextMenuTarget);
        end
    })));
    fRemember("RadialMenuTarget", Controls.button(oMenus, fOptions({
        Text = "Radial menu: click / right-click",
        OnClick = function()
            tWidgets.RadialMenu.showAtObject(tWidgets.RadialMenuTarget);
        end
    })));
    tWidgets.ContextMenu.attach(tWidgets.ContextMenuTarget);
    tWidgets.RadialMenu.attach(tWidgets.RadialMenuTarget);
    fRemember("MenuSelection", Controls.label(oMenus, fOptions({Value = "No menu action selected.", Wrap = true})));
    fRemember("MenuDirection", Controls.button(oMenus, fOptions({
        Text = "Direction: CW",
        OnClick = function()
            local sDirection = tWidgets.RadialMenu.getDirection() == "CW" and "CCW" or "CW";
            tWidgets.RadialMenu.setDirection(sDirection, true);
            tWidgets.MenuDirection.Text = "Direction: "..sDirection;
            tWidgets.MenuDirection.refresh();
        end
    })));
    fRemember("MenuShape", Controls.button(oMenus, fOptions({
        Text = "Default shape: circle",
        OnClick = function()
            local tNext = {circle = "diamond", diamond = "square", square = "circle"};
            local sShape = tNext[tWidgets.RadialMenu.getShape()];
            tWidgets.RadialMenu.setShape(sShape, true);
            tWidgets.MenuShape.Text = "Default shape: "..sShape;
            tWidgets.MenuShape.refresh();
        end
    })));
    fLabel(oMenus, "Start angle (0 top, clockwise degrees)", 16, 180);
    fRemember("MenuAngle", Controls.spinner(oMenus, fOptions({Min = 0, Max = 359, Step = 15, Value = 0,
        OnChange = function(nValue)
            tWidgets.RadialMenu.setStartAngle(nValue, true);
        end
    })));
    fLabel(oMenus, "Minimum edge spacing", 16, 270);
    fRemember("MenuSpacing", Controls.slider(oMenus, fOptions({Min = 0, Max = 40, Step = 1, Value = 12,
        OnChange = function(nValue)
            tWidgets.RadialMenu.setSpacing(nValue, true);
        end
    })));
    fLabel(oMenus, "Minimum / maximum radius", 360, 180);
    fRemember("MenuMinRadius", Controls.spinner(oMenus, fOptions({Min = 0, Max = 300, Step = 8, Value = 64,
        OnChange = function(nValue)
            local nMax = math.max(nValue, tWidgets.MenuMaxRadius.getValue());
            tWidgets.MenuMaxRadius.setValue(nMax);
            tWidgets.RadialMenu.setRadiusRange(nValue, nMax, true);
        end
    })));
    fRemember("MenuMaxRadius", Controls.spinner(oMenus, fOptions({Min = 0, Max = 300, Step = 8, Value = 160,
        OnChange = function(nValue)
            local nMin = math.min(nValue, tWidgets.MenuMinRadius.getValue());
            tWidgets.MenuMinRadius.setValue(nMin);
            tWidgets.RadialMenu.setRadiusRange(nMin, nValue, true);
        end
    })));
    fRemember("MenuClipImage", Controls.checkbox(oMenus, fOptions({Text = "Clip Attack image to its host", Selected = true,
        OnChange = function(bValue)
            tWidgets.RadialMenu.setItem("attack", {ClipImage = bValue}, true);
        end
    })));
    fRemember("MenuHelp", Controls.label(oMenus, fOptions({Wrap = true,
        Value = "Build opens a submenu; Build 2 opens another. More carries additional choices, with Back on every nested page.\n"
            .."Escape goes back, then closes the root. Enter/Space selects; arrows/Tab traverse enabled items.\n"
            .."Actions close before returning Id, application Value and the item Path. Both menus use the current skin."
    })));
    tWidgets.RadialMenu.on("layoutFailed", function(oSource, tEvent)
        fMessage("Radial menu: "..tEvent.Reason);
    end);

    -- Editors retain native typing while skinned actions demonstrate reusable dialogs.
    local oEditors = tTabs.Pages[9];
    fRemember("ToggleButton", Controls.toggleButton(oEditors, fOptions({Text = "Auto-cast", Value = true,
        OnChange = fChanged("Auto-cast")})));
    fRemember("NumericField", Controls.numericField(oEditors, fOptions({Min = -100, Max = 100,
        Value = 12.5, Step = 0.25, Precision = 2, OnChange = fChanged("Decimal value")})));
    fRemember("NumericPlain", Controls.numericField(oEditors, fOptions({Min = 0, Max = 10,
        Value = 1.125, Step = 0.125, Precision = 3, StepButtons = false,
        OnChange = fChanged("Typed decimal")})));
    fRemember("NumericReadOnly", Controls.numericField(oEditors, fOptions({Min = 0, Max = 100,
        Value = 42.5, ReadOnly = true})));
    fRemember("Dialog", Controls.dialog(oFrame, fOptions({Title = "Sample settings",
        Message = "Reusable modeless dialog. Choose OK or Cancel; Escape cancels.",
        OnClose = fChanged("Dialog result")})));
    fRemember("ModalDialog", Controls.dialog(oFrame, fOptions({Title = "Confirm sample action",
        Message = "A native modal dialog with a skinned client. Yes, No, or Escape to cancel.",
        Buttons = {"yes", "no", "cancel"}, DefaultResult = "yes"})));
    fRemember("DialogOpen", Controls.button(oEditors, fOptions({Text = "Open modeless dialog",
        OnClick = function()
            tWidgets.Dialog.show();
        end})));
    fRemember("DialogModalOpen", Controls.button(oEditors, fOptions({Text = "Open modal dialog",
        OnClick = function()
            local sResult = tWidgets.ModalDialog.showModal();
            fMessage("Modal result: "..tostring(sResult));
        end})));
    fRemember("EditorHelp", Controls.label(oEditors, fOptions({Wrap = true,
        Value = "Toggle: mouse, Enter or Space. Decimal fields: type and press Enter, or leave the field to commit. Up/Down step; Page Up/Down step ten times. Left/Right/Home/End edit text. Invalid text restores the last value. Escape restores an edit. The second field has no step buttons; the third is read-only."})));

    -- Tool strips, independent status sections and linked color channels share
    -- this category so runtime changes are visible together.
    local oTools = tTabs.Pages[10];
    local tToolItems = {
        {Id = "attack", Text = "Attack", Image = APP_PATH.."/Images/UI/Menu/Command Sword.png",
            Width = 124, Tooltip = "Attack the selected target"},
        {Id = "guard", Text = "Guard", Image = APP_PATH.."/Images/UI/Menu/Command Shield.png",
            Width = 124, Tooltip = "Protect nearby allies"},
        {Id = "sep", Kind = "separator"},
        {Id = "auto", Text = "Auto-cast", Kind = "toggle", Selected = true, Tooltip = "Toggle automatic casting"},
        {Id = "unavailable", Text = "Unavailable", Enabled = false},
    };
    for nIndex = 1, 8 do
        tToolItems[#tToolItems + 1] = {Id = "command"..nIndex, Text = "Command "..nIndex,
            Tooltip = "Overflow command "..nIndex};
    end
    fRemember("StatusBar", Controls.statusBar(oTools, fOptions({Items = {
        {Id = "message", Text = "Ready", Weight = 2},
        {Id = "color", Text = "RGBA", Width = 190},
        {Id = "meter", Width = 180},
    }, OnActivate = function(sId)
        fMessage("Status section: "..sId);
    end})));
    fRemember("Toolbar", Controls.toolbar(oTools, fOptions({Items = tToolItems,
        OnActivate = function(sId)
            tWidgets.StatusBar.setItem("message", {Text = "Command: "..sId}, true);
            fMessage("Toolbar command: "..sId);
        end})));
    local oStatusHost = tWidgets.StatusBar.getSection("meter");
    fRemember("StatusProgress", Controls.progress(oStatusHost, fOptions({Min = 0, Max = 100,
        Value = 65, Text = "%v%", Appearance = "skin"})));
    oStatusHost:Connect(wx.wxEVT_SIZE, function(jEvent)
        local nWidth, nHeight = oStatusHost:GetClientSizeWH();
        tWidgets.StatusProgress.layout(4, 3, math.max(1, nWidth - 8), math.max(1, nHeight - 6));
        jEvent:Skip();
    end);
    fRemember("ColorPicker", Controls.colorPicker(oTools, fOptions({Value = {R = 65, G = 140, B = 210, A = 190},
        OnChange = function(tColor)
            local sHex = string.format("#%02X%02X%02X%02X", tColor.R, tColor.G, tColor.B, tColor.A);
            tWidgets.StatusBar.setItem("color", {Text = sHex}, true);
            fMessage("Color: "..sHex);
        end})));
    fRemember("ColorPickerAlpha", Controls.colorPicker(oTools, fOptions({Value = {R = 210, G = 90, B = 65, A = 100}})));
    fRemember("ToolbarAdd", Controls.button(oTools, fOptions({Text = "Add command",
        OnClick = function()
            local tItems = tWidgets.Toolbar.getItems();
            tItems[#tItems + 1] = {Id = "added"..#tItems, Text = "Added "..#tItems};
            tWidgets.Toolbar.setItems(tItems, true);
        end})));
    fRemember("ToolbarRemove", Controls.button(oTools, fOptions({Text = "Remove last command",
        OnClick = function()
            local tItems = tWidgets.Toolbar.getItems();
            if (#tItems > 0) then
                table.remove(tItems);
                tWidgets.Toolbar.setItems(tItems, true);
            end
        end})));
    fRemember("ToolsHelp", Controls.label(oTools, fOptions({Wrap = true,
        Value = "Toolbar: arrows/Home/End navigate, Enter/Space activates; More reveals hidden commands. Hover for skinned hints. Status sections resize independently; the last hosts a progress control. Color picker: RGB, HSV and alpha sliders share a preview. Up/Down/Tab choose a channel; Left/Right adjust; Page Up/Down step ten; Home/End set limits. Apply/Enter commits, Cancel/Escape/outside click cancels."})));

    -- The workbench uses the real Tabs object; this nested instance exposes its
    -- runtime policies without disturbing the stable outer example categories.
    local oTabsPage = tTabs.Pages[11];
    local nTabSerial = 4;
    fRemember("ExampleTabs", Controls.tabs(oTabsPage, fOptions({
        Items = {
            {Id = "first", Text = "First page"},
            {Id = "second", Text = "A longer caption", Image = APP_PATH.."/Images/UI/Menu/Command Shield.png"},
            {Id = "disabled", Text = "Disabled page", Enabled = false},
            {Id = "last", Text = "Last page"},
        }, OnChange = fChanged("Nested tab")
    })));
    local function fTabLabel(vTab)
        local oPage = tWidgets.ExampleTabs.getPage(vTab);
        local oLabel = fRemember("TabPageLabel"..nTabSerial, Controls.label(oPage, fOptions({Wrap = true,
            Value = "This page keeps its native controls when you rename or move its tab. Change the header edge or switch between wrap and scroll. Ctrl/Cmd+Tab changes pages from child controls."})));
        nTabSerial = nTabSerial + 1;
        local function fSize()
            local nWidth, nHeight = oPage:GetClientSizeWH();
            oLabel.layout(16, 16, math.max(1, nWidth - 32), math.max(1, nHeight - 32));
        end
        oPage:Connect(wx.wxEVT_SIZE, function(jEvent)
            if (not oLabel.Disposed) then
                fSize();
            end
            jEvent:Skip();
        end);
        fSize();
    end
    for nIndex = 1, 4 do
        fTabLabel(nIndex);
    end
    fRemember("TabsMode", Controls.button(oTabsPage, fOptions({Text = "Wrap / scroll",
        OnClick = function()
            local oTabs = tWidgets.ExampleTabs;
            oTabs.setLayoutMode(oTabs.getLayoutMode() == "wrap" and "scroll" or "wrap", true);
        end})));
    fRemember("TabsPosition", Controls.button(oTabsPage, fOptions({Text = "Change header edge",
        OnClick = function()
            local tNext = {top = "right", right = "bottom", bottom = "left", left = "top"};
            tWidgets.ExampleTabs.setPosition(tNext[tWidgets.ExampleTabs.getPosition()], true);
        end})));
    fRemember("TabsAdd", Controls.button(oTabsPage, fOptions({Text = "Add page",
        OnClick = function()
            local sId = "added:"..nTabSerial;
            tWidgets.ExampleTabs.addItem({Id = sId, Text = "Added page "..nTabSerial}, nil, true);
            fTabLabel(sId);
            tWidgets.ExampleTabs.setValue(sId, true);
        end})));
    fRemember("TabsRemove", Controls.button(oTabsPage, fOptions({Text = "Remove selected",
        OnClick = function()
            local oTabs = tWidgets.ExampleTabs;
            if (oTabs.getValue() > 0) then
                oTabs.removeItem(oTabs.getValue(), true);
            end
        end})));
    fRemember("TabsRename", Controls.button(oTabsPage, fOptions({Text = "Rename selected",
        OnClick = function()
            local oTabs = tWidgets.ExampleTabs;
            if (oTabs.getValue() > 0) then
                oTabs.setItem(oTabs.getValue(), {Text = "Renamed page "..nTabSerial}, true);
            end
        end})));
    fRemember("TabsMove", Controls.button(oTabsPage, fOptions({Text = "Move selected first",
        OnClick = function()
            local oTabs = tWidgets.ExampleTabs;
            if (oTabs.getValue() > 0) then
                oTabs.moveItem(oTabs.getValue(), 1, true);
            end
        end})));

    -- Check membership is deliberately separate from row selection. Both
    -- examples start with checkbox presentation off, matching factory defaults.
    local oTreeExPage = tTabs.Pages[12];
    local tCheckColumns = {
        {Key = "Picture", Type = "image", Width = 48, Title = "Icon"},
        {Key = "Name", Type = "text", Weight = 2, Title = "Name"},
        {Key = "Class", Type = "text", Width = 100, Title = "Class"},
    };
    local tCheckRows = {
        {Name = "Faramir", Class = "Ranger", Picture = APP_PATH.."/Images/UI/Menu/Command Sword.png"},
        {Name = "Boromir", Class = "Captain", Picture = APP_PATH.."/Images/UI/Menu/Command Shield.png"},
        {Name = "Gandalf", Class = "Wizard", Picture = APP_PATH.."/Images/UI/Menu/Command Banner.png"},
    };
    fRemember("CheckListEx", Controls.listEx(oTreeExPage, fOptions({Columns = tCheckColumns,
        Items = tCheckRows, RowHeight = 48, OnCheckChange = function(nIndex, bChecked)
            fMessage("ListEx row "..nIndex.." checked: "..tostring(bChecked));
        end})));
    fRemember("TreeEx", Controls.treeEx(oTreeExPage, fOptions({Columns = {
        {Key = "Name", Type = "text", Weight = 2, Title = "Name"},
        {Key = "Class", Type = "text", Width = 100, Title = "Class"},
    }, HierarchyColumn = 1,
        Items = {
            {Id = "gondor", Name = "Gondor", Class = "Faction", Expanded = true, Children = {
                {Id = "faramir", Name = "Faramir", Class = "Ranger", Image = tCheckRows[1].Picture},
                {Id = "boromir", Name = "Boromir", Class = "Captain", Image = tCheckRows[2].Picture},
            }},
            {Id = "istari", Name = "Istari", Class = "Order", Expanded = true, Children = {
                {Id = "gandalf", Name = "Gandalf", Class = "Wizard", Image = tCheckRows[3].Picture},
            }},
        }, OnChange = fChanged("TreeEx selected"), OnCheckChange = function(sId, bChecked)
            fMessage("TreeEx "..sId.." checked: "..tostring(bChecked));
        end})));
    fRemember("CheckListToggle", Controls.checkbox(oTreeExPage, fOptions({Text = "ListEx checkboxes",
        OnChange = function(bFlag)
            tWidgets.CheckListEx.setCheckboxesEnabled(bFlag, true);
        end})));
    fRemember("CheckTreeToggle", Controls.checkbox(oTreeExPage, fOptions({Text = "TreeEx checkboxes",
        OnChange = function(bFlag)
            tWidgets.TreeEx.setCheckboxesEnabled(bFlag, true);
        end})));
    fRemember("TreeExMulti", Controls.checkbox(oTreeExPage, fOptions({Text = "TreeEx multi-select",
        OnChange = function(bFlag)
            tWidgets.TreeEx.setMultiSelectEnabled(bFlag, true);
        end})));
    fRemember("CheckListMulti", Controls.checkbox(oTreeExPage, fOptions({Text = "ListEx multi-select",
        OnChange = function(bFlag)
            tWidgets.CheckListEx.setMultiSelectEnabled(bFlag, true);
        end})));
    fRemember("TreeExPropagation", Controls.checkbox(oTreeExPage, fOptions({Text = "Cascade checks to descendants", Selected = true,
        OnChange = function(bFlag)
            tWidgets.TreeEx.setCheckPropagationEnabled(bFlag, true);
        end})));
    fRemember("TreeExHelp", Controls.label(oTreeExPage, fOptions({Wrap = true,
        Value = "Checkboxes default off. Clicking a checkbox toggles it without selecting the row. Plain Space toggles the focused checkbox; Ctrl/Cmd+Space retains multi-selection behavior. Tree checks cascade to every descendant by default, including collapsed children; turn cascade off for independent checks. Node icons follow indentation beside their labels. Left/Right collapse, expand and navigate branches. Shift and Ctrl/Cmd select rows as usual."})));

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
        local nTreeExWidth, nTreeExHeight = oTreeExPage:GetClientSizeWH();
        local nTreeExHalf = math.floor(nTreeExWidth / 2);
        tWidgets.CheckListToggle.layout(16, 12, nTreeExHalf - 24, 36);
        tWidgets.CheckTreeToggle.layout(nTreeExHalf + 8, 12, nTreeExHalf - 24, 36);
        tWidgets.CheckListMulti.layout(16, 52, nTreeExHalf - 24, 36);
        tWidgets.TreeExMulti.layout(nTreeExHalf + 8, 52, nTreeExHalf - 24, 36);
        tWidgets.TreeExPropagation.layout(nTreeExHalf + 8, 92, nTreeExHalf - 24, 36);
        local nTreeExDataHeight = math.max(140, nTreeExHeight - 280);
        tWidgets.CheckListEx.layout(16, 140, nTreeExHalf - 24, nTreeExDataHeight);
        tWidgets.TreeEx.layout(nTreeExHalf + 8, 140, nTreeExHalf - 24, nTreeExDataHeight);
        tWidgets.TreeExHelp.layout(16, 152 + nTreeExDataHeight, nTreeExWidth - 32,
            math.max(80, nTreeExHeight - nTreeExDataHeight - 168));
        local nTabsWidth, nTabsHeight = oTabsPage:GetClientSizeWH();
        local nTabButtonWidth = math.floor((nTabsWidth - 48) / 3);
        for nIndex, sKey in ipairs({"TabsMode", "TabsPosition", "TabsAdd", "TabsRemove", "TabsRename", "TabsMove"}) do
            tWidgets[sKey].layout(16 + ((nIndex - 1) % 3) * (nTabButtonWidth + 8),
                16 + math.floor((nIndex - 1) / 3) * 48, nTabButtonWidth, 40);
        end
        tWidgets.ExampleTabs.layout(16, 124, nTabsWidth - 32, math.max(100, nTabsHeight - 140));
        local nToolsWidth, nToolsHeight = oTools:GetClientSizeWH();
        tWidgets.Toolbar.layout(16, 16, nToolsWidth - 32, 48);
        tWidgets.StatusBar.layout(16, 82, nToolsWidth - 32, 44);
        tWidgets.ColorPicker.layout(16, 154, 280, 48);
        tWidgets.ColorPickerAlpha.layout(316, 154, 280, 48);
        tWidgets.ToolbarAdd.layout(16, 224, 240, 40);
        tWidgets.ToolbarRemove.layout(276, 224, 280, 40);
        tWidgets.ToolsHelp.layout(16, 294, nToolsWidth - 32, math.max(64, nToolsHeight - 310));
        local nEditorWidth, nEditorHeight = oEditors:GetClientSizeWH();
        tWidgets.ToggleButton.layout(16, 20, 240, 44);
        tWidgets.NumericField.layout(16, 92, 240, 40);
        tWidgets.NumericPlain.layout(16, 152, 240, 40);
        tWidgets.NumericReadOnly.layout(16, 212, 240, 40);
        tWidgets.DialogOpen.layout(300, 20, 300, 44);
        tWidgets.DialogModalOpen.layout(300, 84, 300, 44);
        tWidgets.EditorHelp.layout(16, 290, nEditorWidth - 32, math.max(64, nEditorHeight - 310));
        local nMenuWidth, nMenuHeight = oMenus:GetClientSizeWH();
        local nMenuHalf = math.floor(nMenuWidth / 2);
        tWidgets.ContextMenuTarget.layout(16, 18, nMenuHalf - 32, 50);
        tWidgets.RadialMenuTarget.layout(nMenuHalf + 16, 18, nMenuWidth - nMenuHalf - 32, 50);
        tWidgets.MenuSelection.layout(16, 82, nMenuWidth - 32, 56);
        tWidgets.MenuDirection.layout(16, 132, 300, 40);
        tWidgets.MenuShape.layout(360, 132, 300, 40);
        tWidgets.MenuAngle.layout(16, 214, 180, 40);
        tWidgets.MenuMinRadius.layout(360, 214, 140, 40);
        tWidgets.MenuMaxRadius.layout(516, 214, 140, 40);
        tWidgets.MenuSpacing.layout(16, 300, 300, 44);
        tWidgets.MenuClipImage.layout(360, 300, math.max(250, nMenuWidth - 376), 40);
        tWidgets.MenuHelp.layout(16, 370, nMenuWidth - 32, math.max(80, nMenuHeight - 386));
        local nOrbWidth, nOrbHeight = oOrbs:GetClientSizeWH();
        local nOrbColumn = math.floor(nOrbWidth / 3);
        local nOrbDiameter = math.max(32, math.min(220, nOrbColumn - 48, nOrbHeight - 460));
        local nOrbButtonY = nOrbDiameter + 78;

        for nIndex, sPrefix in ipairs({"Globe", "Radial", "Iris"}) do
            local nColumnX = (nIndex - 1) * nOrbColumn;
            tWidgets[sPrefix.."Heading"].layout(nColumnX + 16, 12, nOrbColumn - 32, 36);
            tWidgets[sPrefix.."Progress"].layout(nColumnX + math.floor((nOrbColumn - nOrbDiameter) / 2),
                60, nOrbDiameter, nOrbDiameter);
        end

        tWidgets.GlobeOrigin.layout(24, nOrbButtonY, nOrbColumn - 48, 40);
        tWidgets.RadialDirection.layout(nOrbColumn + 24, nOrbButtonY, nOrbColumn - 48, 40);
        tWidgets.IrisDirection.layout(2 * nOrbColumn + 24, nOrbButtonY, nOrbColumn - 48, 40);
        tWidgets.GlobeSkin.layout(24, nOrbButtonY + 48, nOrbColumn - 48, 36);
        tWidgets.RadialSkin.layout(nOrbColumn + 24, nOrbButtonY + 48, nOrbColumn - 48, 36);
        tWidgets.IrisBlades.layout(2 * nOrbColumn + 24, nOrbButtonY + 48, nOrbColumn - 48, 36);
        tWidgets.OrbValue.layout(24, nOrbButtonY + 104, nOrbWidth - 48, 44);
        tWidgets.OrbReserved.layout(24, nOrbButtonY + 152, nOrbWidth - 48, 44);
        tWidgets.GlobeReserveOrigin.layout(24, nOrbButtonY + 202, nOrbColumn - 48, 36);
        tWidgets.RadialReserveDirection.layout(nOrbColumn + 24, nOrbButtonY + 202, nOrbColumn - 48, 36);
        tWidgets.IrisPicture.layout(2 * nOrbColumn + 24, nOrbButtonY + 202, nOrbColumn - 48, 36);
        tWidgets.CircularPie.layout(24, nOrbButtonY + 244, nOrbWidth - 48, 36);
        tWidgets.OrbHelp.layout(24, nOrbButtonY + 286, nOrbWidth - 48, math.max(32, nOrbHeight - nOrbButtonY - 302));
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
