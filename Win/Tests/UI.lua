-- UI workbench: reusable controls use isolated sample values only.
local wx = require("wx");
local loadwxLuma = require("wxLuma");
local wxLuma = loadwxLuma();
local Window = wxLuma.Window;
local Controls = wxLuma.Controls;
local DemoGallery = require("Win.Tests.DemoGallery");

return function(oParent)
    -- wxLua requires a native null parent when launching this demo standalone.
    local oFrame = wx.wxFrame(oParent or wx.NULL, wx.wxID_ANY, "wxLuma - Control Gallery", wx.wxDefaultPosition, wx.wxSize(1120, 900));
    oFrame:SetMinClientSize(wx.wxSize(920, 780));
    local tSkin = Controls.loadSkin();
    local tWidgets, tInteractive, tTips = {}, {}, {};
    local sMessage = "Choose a category. Each example includes usage and API guidance. Tab moves focus.";
    local bEnabled, bDisposed = true, false;
    -- Resolve shared demo assets from the framework location, independent of cwd.
    local sSoundPath = wxLuma.Path.."/../Sound/";
    local oHoverSound = wx.wxSound(sSoundPath.."Hover.wav");
    local oClickSound = wx.wxSound(sSoundPath.."Click.wav");
    assert(oHoverSound:IsOk() and oClickSound:IsOk(), "Cannot load demo sounds from "..sSoundPath);
    local tItemHover = {Tabs = true, ExampleTabs = true, List = true, ListEx = true,
        CheckListEx = true, TreeEx = true, Toolbar = true, ContextMenu = true, RadialMenu = true,
        MenuBar = true, ComboBox = true, LogViewer = "entryHovered", ActionLog = "entryHovered"};

    --[[!
    @fqxn wxLuma.Tests.UI.fWireAudio
    @desc Plays brief asynchronous feedback for enabled controls. Item controls
        sound on row/item transitions; ordinary controls sound on pointer entry.
        Both physical mouse buttons share a cue played immediately on press.
    @param string sKey Demo widget name.
    @param table tWidget Public component receiving interaction notifications.
    !]]
    local function fWireAudio(sKey, tWidget)
        local function fPlay(oSound, tEvent)
            if (not bDisposed and not tWidget.Disposed and tWidget.isEnabled()
                and (not tEvent.Child or tEvent.Child.isEnabled())) then
                oSound:Play(wx.wxSOUND_ASYNC);
            end
        end

        local sHoverEvent = type(tItemHover[sKey]) == "string" and tItemHover[sKey] or tItemHover[sKey] and "itemHovered" or "pointerEnter";
        tWidget.on(sHoverEvent, function(oSource, tEvent) fPlay(oHoverSound, tEvent); end);
        tWidget.on("leftDown", function(oSource, tEvent) fPlay(oClickSound, tEvent); end);
        tWidget.on("rightDown", function(oSource, tEvent) fPlay(oClickSound, tEvent); end);
    end

    local tWindow;
    local oGallery;
    local function fMessage(sText)
        if (bDisposed) then return; end
        sMessage = sText;
        local tContent = tWindow.getGeometry().Content;
        tWindow.Control:RefreshRect(wx.wxRect(tContent.x, tContent.y + tContent.height - 28, tContent.width, 28), false);
    end
    tWindow = Window.create(oFrame, {Title = "wxLuma", Subtitle = "CONTROL GALLERY  /  DOCUMENTED EXAMPLES", PaintContent = function(oDC, tContent)
        tSkin.text(oDC, sMessage, tContent.x, tContent.y + tContent.height - 26, true);
    end});
    local function fOptions(tOptions) tOptions.Skin = tSkin; return tOptions; end
    local function fRemember(sKey, tWidget)
        fWireAudio(sKey, tWidget);
        tWidgets[sKey] = tWidget; tInteractive[#tInteractive + 1] = tWidget; return tWidget;
    end
    local function fChanged(sName) return function(vValue) fMessage(sName .. ": " .. tostring(vValue)); end; end
    --[[!
    @fqxn wxLuma.Tests.UI.fDemoParent
    @desc Selects the final documented parent before creation so native lifetime
        ownership and popup containment include the category's scroll viewport.
    !]]
    local function fDemoParent(sKey, oFallback) return oGallery.parent(sKey, oFallback); end
    local tTabs = Controls.tabs(tWindow.Control, fOptions({
        LayoutMode = "wrap",
        Items = DemoGallery.getTitles(),
        OnChange = function(nValue)
            fMessage("Tab: "..nValue);

            if (oGallery) then oGallery.focusCategory(nValue); end
        end
    }));
    tWidgets.Tabs = tTabs;
    fWireAudio("Tabs", tTabs);
    oGallery = DemoGallery.create(tTabs, tSkin);
    local oOriginal, oInput, oResources = tTabs.Pages[1], tTabs.Pages[2], tTabs.Pages[3];
    local function fLabel(oParent, sText, nX, nY)
        local oLabel = wx.wxStaticText(oParent, wx.wxID_ANY, sText, wx.wxPoint(nX, nY));
        oLabel:SetFont(tSkin.Font); oLabel:SetForegroundColour(wx.wxColour(177, 193, 210)); return oLabel;
    end
    fRemember("Checkbox", Controls.checkbox(fDemoParent("Checkbox", oOriginal), fOptions({Text = "Enable sample option", OnChange = fChanged("Checkbox")})));
    fRemember("DisabledCheckbox", Controls.checkbox(fDemoParent("DisabledCheckbox", oOriginal), fOptions({Text = "Selected, disabled", Selected = true, Enabled = false})));
    local tGroup = Controls.radioGroup();
    for nIndex, sText in ipairs({"Balanced", "Cautious", "Unavailable"}) do
        fRemember("Radio" .. nIndex, Controls.radio(fDemoParent("Radio"..nIndex, oOriginal), fOptions({Text = sText, Group = tGroup, Value = sText,
            Selected = nIndex == 1, Enabled = nIndex ~= 3, OnChange = fChanged("Radio")})));
    end
    fRemember("Slider", Controls.slider(fDemoParent("Slider", oOriginal), fOptions({Min = 0, Max = 100, Step = 5, Value = 40, OnChange = fChanged("Horizontal")})));
    fRemember("VerticalSlider", Controls.slider(fDemoParent("VerticalSlider", oOriginal), fOptions({Min = 0, Max = 100, Step = 5, Value = 65, Vertical = true, OnChange = fChanged("Vertical")})));
    fRemember("Spinner", Controls.spinner(fDemoParent("Spinner", oOriginal), fOptions({Min = 0, Max = 20, Step = 1, Value = 4, OnChange = fChanged("Spinner")})));
    fRemember("Button", Controls.button(fDemoParent("Button", oOriginal), fOptions({Text = "Apply sample", OnClick = function() fMessage("Sample applied. Sample action completed."); end})));
    local tToggle = Controls.button(fDemoParent("Toggle", oOriginal), fOptions({Text = "Toggle controls", OnClick = function()
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
    fWireAudio("Toggle", tToggle);

    local tItems = {};

    for nIndex = 1, 10000 do
        tItems[nIndex] = string.format("Sample entry %05d", nIndex);
    end
    fRemember("List", Controls.list(fDemoParent("List", oInput), fOptions({Items = tItems, Value = 1, OnChange = fChanged("List row")})));
    fRemember("Dropdown", Controls.dropdown(fDemoParent("Dropdown", oInput), fOptions({Items = tItems, Value = 5, Rows = 8, OnChange = fChanged("Dropdown row")})));
    fRemember("Text", Controls.textfield(fDemoParent("Text", oInput), fOptions({Value = "Editable sample", Hint = "Type here", OnChange = fChanged("Text"), OnEnter = fChanged("Enter")})));
    fRemember("DisabledText", Controls.textfield(fDemoParent("DisabledText", oInput), fOptions({Value = "Unavailable sample", Enabled = false})));
    fRemember("Scrollbar", Controls.scrollbar(fDemoParent("Scrollbar", oInput), fOptions({Min = 0, Max = 900, Page = 100, Value = 0, Vertical = false, OnChange = fChanged("Offset")})));
    fRemember("ListMultiSelect", Controls.checkbox(fDemoParent("ListMultiSelect", oInput), fOptions({
        Text = "List multi-select",
        OnChange = function(bEnabled)
            tWidgets.List.setMultiSelectEnabled(bEnabled, true);
        end
    })));
    tTips[1] = Controls.tooltip(tWidgets.Text.TextControl, fOptions({Text = "Native text editing inside the common skin.\nEnter reports the sample; no data is saved."}));
    tTips[2] = Controls.tooltip(tWidgets.List.Control, fOptions({Text = "Wheel or drag the scrollbar.\nArrows, Page Up/Down, Home/End select rows."}));

    fRemember("Health", Controls.progress(fDemoParent("Health", oResources), fOptions({Min = 0, Max = 100, Value = 70, Text = "Health  %v / %m", Colour = {R = 107, G = 142, B = 91}})));
    fRemember("Mana", Controls.progress(fDemoParent("Mana", oResources), fOptions({Min = 0, Max = 100, Value = 45, Text = "Mana  %v / %m", Colour = {R = 77, G = 120, B = 169}})));
    fRemember("Progress", Controls.progress(fDemoParent("Progress", oResources), fOptions({Min = 0, Max = 100, Value = 25, Text = "Loading  %v%", Colour = {R = 150, G = 128, B = 83}})));
    fRemember("DirectionalProgress", Controls.progress(fDemoParent("DirectionalProgress", oResources), fOptions({
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
        oGallery.layoutCard("DirectionalProgress");
    end
    fRemember("ProgressOrigin", Controls.button(fDemoParent("ProgressOrigin", oResources), fOptions({
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
    fRemember("CircularProgress", Controls.circularProgress(fDemoParent("CircularProgress", oResources), fOptions({
        Min = 0,
        Max = 100,
        Value = 25,
        Direction = "CW",
        Text = "%v%"
    })));
    fRemember("CircularDirection", Controls.button(fDemoParent("CircularDirection", oResources), fOptions({
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
    fRemember("CircularStartAngle", Controls.button(fDemoParent("CircularStartAngle", oResources), fOptions({
        Text = "Circle start: 0 degrees",
        OnClick = function()
            local nAngle = (tWidgets.CircularProgress.getStartAngle() + 45) % 360;
            tWidgets.CircularProgress.setStartAngle(nAngle, true);
            tWidgets.CircularStartAngle.Text = "Circle start: "..nAngle.." degrees";
            tWidgets.CircularStartAngle.refresh();
            fMessage("Circle starting angle: "..nAngle.." degrees");
        end
    })));
    fRemember("MeterSlider", Controls.slider(fDemoParent("MeterSlider", oResources), fOptions({Min = 0, Max = 100, Step = 1, Value = 70, OnChange = function(nValue)
        for _, sKey in ipairs({"Health", "Mana", "Progress", "DirectionalProgress", "CircularProgress"}) do tWidgets[sKey].setValue(nValue); end; fMessage("Sample meters: " .. nValue);
    end})));
    fRemember("ProgressSkin", Controls.checkbox(fDemoParent("ProgressSkin", oResources), fOptions({
        Text = "Skin linear meters",
        OnChange = function(bEnabled)
            for _, sKey in ipairs({"Health", "Mana", "Progress"}) do
                tWidgets[sKey].setAppearance(bEnabled and "skin" or "colour", true);
            end
        end
    })));
    fRemember("CircularProgressSkin", Controls.checkbox(fDemoParent("CircularProgressSkin", oResources), fOptions({
        Text = "Skin circular meter",
        Selected = true,
        OnChange = function(bEnabled)
            tWidgets.CircularProgress.setAppearance(bEnabled and "skin" or "colour", true);
        end
    })));
    fRemember("CircularPie", Controls.checkbox(fDemoParent("CircularPie", oResources), fOptions({
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
    fRemember("Panel", Controls.panel(fDemoParent("Panel", oResources), fOptions({Text = "RESIZABLE EMBEDDED PANEL", MinWidth = 260, MinHeight = 200,
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
    fRemember("TooltipBoundary", Controls.button(fDemoParent("TooltipBoundary", oResources), fOptions({
        Text = "Tooltip: panel / window",
        OnClick = function()
            bPanelTooltipBoundary = not bPanelTooltipBoundary;
            tTips[3].setContainment(bPanelTooltipBoundary and tPanel.Content or oFrame);
            fMessage(bPanelTooltipBoundary and "Panel tooltip contained by panel content." or "Panel tooltip contained by window client area.");
        end
    })));
    fRemember("TooltipOverflow", Controls.button(fDemoParent("TooltipOverflow", oResources), fOptions({
        Text = "Oversized: hide / allow",
        OnClick = function()
            local sNext = tTips[3].getContainmentOverflow() == "hide" and "allow" or "hide";
            tTips[3].setContainmentOverflow(sNext);
            fMessage("Panel tooltip oversized policy: "..sNext..". Size remains unchanged.");
        end
    })));
    local tPanelToggle = Controls.button(fDemoParent("PanelToggle", oResources), fOptions({Text = "Hide / show panel", OnClick = function() tPanel.show(not tPanel.Control:IsShown()); fMessage(tPanel.Control:IsShown() and "Panel shown." or "Panel hidden."); end}));
    tWidgets.PanelToggle = tPanelToggle;
    fWireAudio("PanelToggle", tPanelToggle);

    -- Factories receive their gallery parents while stable widget keys remain
    -- available to callbacks, application examples and regression fixtures.
    local oOrbs = tTabs.Pages[7];
    fRemember("GlobeProgress", Controls.globeProgress(fDemoParent("GlobeProgress", oOrbs), fOptions({
        Min = 0,
        Max = 100,
        Value = 65,
        Supersampling = 2,
        Origin = "bottom",
        Text = "%v%",
        OnChange = fChanged("Globe progress")
    })));
    fRemember("RadialProgress", Controls.radialProgress(fDemoParent("RadialProgress", oOrbs), fOptions({
        Min = 0,
        Max = 100,
        Value = 65,
        Supersampling = 2,
        Direction = "outward",
        Text = "%v%",
        OnChange = fChanged("Radial progress")
    })));
    fRemember("IrisProgress", Controls.irisProgress(fDemoParent("IrisProgress", oOrbs), fOptions({
        Min = 0,
        Max = 100,
        Value = 65,
        Text = "%v%",
        BackgroundImage = wxLuma.Config.ImagePath.."/Menu/Command Shield.png",
        Supersampling = 2,
        OnChange = fChanged("Iris progress")
    })));
    fRemember("IrisDirection", Controls.button(fDemoParent("IrisDirection", oOrbs), fOptions({
        Text = "Iris: opening",
        OnClick = function()
            local sDirection = tWidgets.IrisProgress.getDirection() == "opening" and "closing" or "opening";
            tWidgets.IrisProgress.setDirection(sDirection, true);
            tWidgets.IrisDirection.Text = "Iris: "..sDirection;
            tWidgets.IrisDirection.refresh();
        end
    })));
    fRemember("IrisBlades", Controls.button(fDemoParent("IrisBlades", oOrbs), fOptions({
        Text = "Blades: 6 / rotate",
        OnClick = function()
            local nCount = tWidgets.IrisProgress.getBladeCount() % 10 + 3;
            tWidgets.IrisProgress.setBladeCount(nCount, true);
            tWidgets.IrisProgress.setRotation(tWidgets.IrisProgress.getRotation() + 15, true);
            tWidgets.IrisBlades.Text = "Blades: "..nCount.." / rotate";
            tWidgets.IrisBlades.refresh();
        end
    })));
    fRemember("IrisPicture", Controls.checkbox(fDemoParent("IrisPicture", oOrbs), fOptions({
        Text = "Clipped iris picture",
        Selected = true,
        OnChange = function(bSelected)
            tWidgets.IrisProgress.setBackgroundImage(bSelected
                and wxLuma.Config.ImagePath.."/Menu/Command Shield.png" or nil, true);
        end
    })));
    fRemember("GlobeOrigin", Controls.button(fDemoParent("GlobeOrigin", oOrbs), fOptions({
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
    fRemember("RadialDirection", Controls.button(fDemoParent("RadialDirection", oOrbs), fOptions({
        Text = "Direction: outward",
        OnClick = function()
            local sDirection = tWidgets.RadialProgress.getDirection() == "outward" and "inward" or "outward";
            tWidgets.RadialProgress.setDirection(sDirection, true);
            tWidgets.RadialDirection.Text = "Direction: "..sDirection;
            tWidgets.RadialDirection.refresh();
            fMessage("Radial fill: "..sDirection);
        end
    })));
    fRemember("GlobeSkin", Controls.checkbox(fDemoParent("GlobeSkin", oOrbs), fOptions({
        Text = "Skin globe",
        Selected = true,
        OnChange = function(bEnabled)
            tWidgets.GlobeProgress.setAppearance(bEnabled and "skin" or "colour", true);
        end
    })));
    fRemember("RadialSkin", Controls.checkbox(fDemoParent("RadialSkin", oOrbs), fOptions({
        Text = "Skin radial meter",
        Selected = true,
        OnChange = function(bEnabled)
            tWidgets.RadialProgress.setAppearance(bEnabled and "skin" or "colour", true);
        end
    })));
    fRemember("OrbValue", Controls.slider(fDemoParent("OrbValue", oOrbs), fOptions({
        Min = 0,
        Max = 100,
        Step = 1,
        Value = 65,
        OnChange = function(nValue)
            tWidgets.GlobeProgress.setValue(nValue, true);
            tWidgets.RadialProgress.setValue(nValue, true);
            tWidgets.IrisProgress.setValue(nValue, true);
            fMessage("Orb meters: "..tWidgets.GlobeProgress.getValue().." / "..tWidgets.GlobeProgress.getEffectiveMax()
                .." usable ("..tWidgets.GlobeProgress.getReserved().." / "..tWidgets.GlobeProgress.getMax().." reserved)");
        end
    })));

    --[[!
    @fqxn wxLuma.Tests.UI.orbValue.setValue
    @desc Makes pointer, keyboard and programmatic demo input stop at the meters'
        actual usable maximum. Keep the full 0..100 track so the stopped thumb
        shows how much of the original capacity is unavailable.
    !]]
    local fSetOrbValue = tWidgets.OrbValue.setValue;
    tWidgets.OrbValue.setValue = function(nValue, bNotify)
        assert(type(nValue) == "number" and nValue == nValue and math.abs(nValue) < math.huge,
            "Orb value must be finite.");
        return fSetOrbValue(math.min(nValue, tWidgets.GlobeProgress.getEffectiveMax()), bNotify);
    end;

    fRemember("OrbReserved", Controls.slider(fDemoParent("OrbReserved", oOrbs), fOptions({
        Min = 0,
        Max = 100,
        Step = 1,
        Value = 0,
        OnChange = function(nValue)
            for _, sKey in ipairs({"GlobeProgress", "RadialProgress", "IrisProgress", "CircularProgress", "Progress"}) do
                tWidgets[sKey].setReserved(nValue, true);
            end

            -- Objects enforce the limit; reflect their accepted current in the
            -- input without issuing a second set of value-change notifications.
            tWidgets.OrbValue.setValue(tWidgets.GlobeProgress.getValue());
            fMessage("Orb meters: "..tWidgets.GlobeProgress.getValue().." / "..tWidgets.GlobeProgress.getEffectiveMax()
                .." usable ("..nValue.." / "..tWidgets.GlobeProgress.getMax().." reserved)");
        end
    })));
    fRemember("GlobeReserveOrigin", Controls.button(fDemoParent("GlobeReserveOrigin", oOrbs), fOptions({
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
    fRemember("RadialReserveDirection", Controls.button(fDemoParent("RadialReserveDirection", oOrbs), fOptions({
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

    local oDisplay, oContainers = tTabs.Pages[4], tTabs.Pages[5];
    local pSampleImage = wxLuma.Config.ImagePath.."/Window/Window Ornament Upper Left.png";
    fRemember("Label", Controls.label(fDemoParent("Label", oDisplay), fOptions({
        Value = "LABEL / hover, left click, right click and keyboard events",
        VerticalAlign = "center"
    })));
    fRemember("WrappedLabel", Controls.label(fDemoParent("WrappedLabel", oDisplay), fOptions({
        Value = "This is a wxLuma Label. Text wraps to the available width and uses the shared skin font.\n\nResize the workbench to see wrapping change. Click the image button to cycle its scaling mode.",
        Wrap = true
    })));
    fRemember("AlignedLabel", Controls.label(fDemoParent("AlignedLabel", oDisplay), fOptions({
        Value = "Centered horizontally and vertically",
        Align = "center", VerticalAlign = "center", Wrap = true
    })));
    fRemember("Image", Controls.image(fDemoParent("Image", oDisplay), fOptions({
        Value = pSampleImage, ScaleMode = "contain"
    })));
    fRemember("ImageButton", Controls.imageButton(fDemoParent("ImageButton", oDisplay), fOptions({
        Image = wxLuma.Config.ImagePath.."/Menu/Command Shield.png", Text = "Image action",
        OnClick = function() fMessage("The image button action works."); end
    })));
    fRemember("TooltipTarget", Controls.button(fDemoParent("TooltipTarget", oDisplay), fOptions({
        Text = "Hover or focus for help", OnClick = function() fMessage("Hover or focus this target to show its tooltip."); end
    })));
    tTips[#tTips + 1] = Controls.tooltip(tWidgets.TooltipTarget.Control, fOptions({
        Text = "Skinned target help.\nTooltips preserve natural size and respect containment."
    }));
    fRemember("ImageMode", Controls.button(fDemoParent("ImageMode", oDisplay), fOptions({
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

    fRemember("ScrollContainer", Controls.scrollContainer(fDemoParent("ScrollContainer", oContainers), fOptions({
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
    fRemember("ScrollReset", Controls.button(fDemoParent("ScrollReset", oContainers), fOptions({
        Text = "Scroll to origin",
        OnClick = function()
            tWidgets.ScrollContainer.scrollTo(0, 0, true);
            tWidgets.ScrollContainer.Control:SetFocus();
        end
    })));
    fRemember("ScrollEnd", Controls.button(fDemoParent("ScrollEnd", oContainers), fOptions({
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
    fRemember("Tree", Controls.tree(fDemoParent("Tree", oData), fOptions({
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

    fRemember("Table", Controls.table(fDemoParent("Table", oData), fOptions({
        Columns = {{Text = "Name", Width = 190}, {Text = "Kind", Width = 130}, {Text = "Value", Width = 100}},
        Items = tRows, Value = "record-1", OnChange = fChanged("Table selection")
    })));
    fRemember("TableMultiSelect", Controls.checkbox(fDemoParent("TableMultiSelect", oData), fOptions({
        Text = "Multi-select",
        OnChange = function(bEnabled)
            tWidgets.Table.setMultiSelectEnabled(bEnabled, true);
        end
    })));
    local nNewNode, nNewRow = 0, 1000;
    fRemember("TreeAdd", Controls.button(fDemoParent("TreeAdd", oData), fOptions({
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
    fRemember("TreeRemove", Controls.button(fDemoParent("TreeRemove", oData), fOptions({
        Text = "Remove node",
        OnClick = function()
            local sId = tWidgets.Tree.getValue();

            if (sId) then
                tWidgets.Tree.removeNode(sId, true);
                fMessage("Removed tree subtree: "..sId);
            end
        end
    })));
    fRemember("TableAdd", Controls.button(fDemoParent("TableAdd", oData), fOptions({
        Text = "Add row",
        OnClick = function()
            nNewRow = nNewRow + 1;
            local sId = "record-"..nNewRow;
            tWidgets.Table.addRow({Id = sId, Cells = {"New object "..nNewRow, "Sample", "0000"}}, true);
            tWidgets.Table.setValue(sId, true);
            tWidgets.Table.TableControl:SetFocus();
        end
    })));
    fRemember("TableRemove", Controls.button(fDemoParent("TableRemove", oData), fOptions({
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
        wxLuma.Config.ImagePath.."/Window/Window Ornament Upper Left.png",
        wxLuma.Config.ImagePath.."/Window/Window Ornament Upper Right.png",
        wxLuma.Config.ImagePath.."/Window/Window Ornament Lower Left.png",
        wxLuma.Config.ImagePath.."/Window/Window Ornament Lower Right.png"
    };
    local tClasses = {"Warrior", "Mage", "Ranger"};

    for nIndex = 1, 1000 do
        tCharacters[nIndex] = {
            Picture = tPortraits[(nIndex - 1) % #tPortraits + 1],
            Name = string.format("Character %04d", nIndex),
            Class = tClasses[(nIndex - 1) % #tClasses + 1]
        };
    end

    fRemember("ListEx", Controls.listEx(fDemoParent("ListEx", oData), fOptions({
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
    fRemember("ListExMultiSelect", Controls.checkbox(fDemoParent("ListExMultiSelect", oData), fOptions({
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

    local nNewCharacter = 1000;
    fRemember("ListExUpdate", Controls.button(fDemoParent("ListExUpdate", oData), fOptions({
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
    fRemember("ListExAdd", Controls.button(fDemoParent("ListExAdd", oData), fOptions({
        Text = "Add row",
        OnClick = function()
            nNewCharacter = nNewCharacter + 1;
            tWidgets.ListEx.addItem({Picture = tPortraits[1], Name = "New character "..nNewCharacter, Class = "Warrior"}, true);
            tWidgets.ListEx.setValue(#tWidgets.ListEx.Items, true);
        end
    })));
    fRemember("ListExRemove", Controls.button(fDemoParent("ListExRemove", oData), fOptions({
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
    fRemember("SplitContainer", Controls.splitContainer(fDemoParent("SplitContainer", oContainers), fOptions({
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
    fRemember("SplitToggle", Controls.button(fDemoParent("SplitToggle", oContainers), fOptions({
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
        wxLuma.Config.ImagePath.."/Menu/Command Sword.png",
        wxLuma.Config.ImagePath.."/Menu/Command Shield.png",
        wxLuma.Config.ImagePath.."/Menu/Command Banner.png"
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

    fRemember("ContextMenu", Controls.contextMenu(fDemoParent("ContextMenu", oMenus), fOptions({Items = tMenuItems, OnSelect = fMenuSelected})));
    fRemember("RadialMenu", Controls.radialMenu(fDemoParent("RadialMenu", oMenus), fOptions({Items = tMenuItems,
        MinRadius = 64, MaxRadius = 160, Spacing = 12, OnSelect = fMenuSelected})));
    fRemember("ContextMenuTarget", Controls.button(fDemoParent("ContextMenuTarget", oMenus), fOptions({
        Text = "Context menu: click / right-click",
        OnClick = function()
            tWidgets.ContextMenu.showAtObject(tWidgets.ContextMenuTarget);
        end
    })));
    fRemember("RadialMenuTarget", Controls.button(fDemoParent("RadialMenuTarget", oMenus), fOptions({
        Text = "Radial menu: click / right-click",
        OnClick = function()
            tWidgets.RadialMenu.showAtObject(tWidgets.RadialMenuTarget);
        end
    })));
    tWidgets.ContextMenu.attach(tWidgets.ContextMenuTarget);
    tWidgets.RadialMenu.attach(tWidgets.RadialMenuTarget);
    fRemember("MenuSelection", Controls.label(fDemoParent("MenuSelection", oMenus), fOptions({Value = "No menu action selected.", Wrap = true})));
    fRemember("MenuDirection", Controls.button(fDemoParent("MenuDirection", oMenus), fOptions({
        Text = "Direction: CW",
        OnClick = function()
            local sDirection = tWidgets.RadialMenu.getDirection() == "CW" and "CCW" or "CW";
            tWidgets.RadialMenu.setDirection(sDirection, true);
            tWidgets.MenuDirection.Text = "Direction: "..sDirection;
            tWidgets.MenuDirection.refresh();
        end
    })));
    fRemember("MenuShape", Controls.button(fDemoParent("MenuShape", oMenus), fOptions({
        Text = "Default shape: circle",
        OnClick = function()
            local tNext = {circle = "diamond", diamond = "square", square = "circle"};
            local sShape = tNext[tWidgets.RadialMenu.getShape()];
            tWidgets.RadialMenu.setShape(sShape, true);
            tWidgets.MenuShape.Text = "Default shape: "..sShape;
            tWidgets.MenuShape.refresh();
        end
    })));
    fRemember("MenuAngle", Controls.spinner(fDemoParent("MenuAngle", oMenus), fOptions({Min = 0, Max = 359, Step = 15, Value = 0,
        OnChange = function(nValue)
            tWidgets.RadialMenu.setStartAngle(nValue, true);
        end
    })));
    fRemember("MenuSpacing", Controls.slider(fDemoParent("MenuSpacing", oMenus), fOptions({Min = 0, Max = 40, Step = 1, Value = 12,
        OnChange = function(nValue)
            tWidgets.RadialMenu.setSpacing(nValue, true);
        end
    })));
    fRemember("MenuMinRadius", Controls.spinner(fDemoParent("MenuMinRadius", oMenus), fOptions({Min = 0, Max = 300, Step = 8, Value = 64,
        OnChange = function(nValue)
            local nMax = math.max(nValue, tWidgets.MenuMaxRadius.getValue());
            tWidgets.MenuMaxRadius.setValue(nMax);
            tWidgets.RadialMenu.setRadiusRange(nValue, nMax, true);
        end
    })));
    fRemember("MenuMaxRadius", Controls.spinner(fDemoParent("MenuMaxRadius", oMenus), fOptions({Min = 0, Max = 300, Step = 8, Value = 160,
        OnChange = function(nValue)
            local nMin = math.min(nValue, tWidgets.MenuMinRadius.getValue());
            tWidgets.MenuMinRadius.setValue(nMin);
            tWidgets.RadialMenu.setRadiusRange(nMin, nValue, true);
        end
    })));
    fRemember("MenuClipImage", Controls.checkbox(fDemoParent("MenuClipImage", oMenus), fOptions({Text = "Clip Attack image to its host", Selected = true,
        OnChange = function(bValue)
            tWidgets.RadialMenu.setItem("attack", {ClipImage = bValue}, true);
        end
    })));
    tWidgets.RadialMenu.on("layoutFailed", function(oSource, tEvent)
        fMessage("Radial menu: "..tEvent.Reason);
    end);

    -- Editors retain native typing while skinned actions demonstrate reusable dialogs.
    local oEditors = tTabs.Pages[9];
    fRemember("ToggleButton", Controls.toggleButton(fDemoParent("ToggleButton", oEditors), fOptions({Text = "Auto-cast", Value = true,
        OnChange = fChanged("Auto-cast")})));
    fRemember("NumericField", Controls.numericField(fDemoParent("NumericField", oEditors), fOptions({Min = -100, Max = 100,
        Value = 12.5, Step = 0.25, Precision = 2, OnChange = fChanged("Decimal value")})));
    fRemember("NumericPlain", Controls.numericField(fDemoParent("NumericPlain", oEditors), fOptions({Min = 0, Max = 10,
        Value = 1.125, Step = 0.125, Precision = 3, StepButtons = false,
        OnChange = fChanged("Typed decimal")})));
    fRemember("NumericReadOnly", Controls.numericField(fDemoParent("NumericReadOnly", oEditors), fOptions({Min = 0, Max = 100,
        Value = 42.5, ReadOnly = true})));
    fRemember("Dialog", Controls.dialog(oFrame, fOptions({Title = "Sample settings",
        Message = "Reusable modeless dialog. Choose OK or Cancel; Escape cancels.",
        OnClose = fChanged("Dialog result")})));
    fRemember("ModalDialog", Controls.dialog(oFrame, fOptions({Title = "Confirm sample action",
        Message = "A native modal dialog with a skinned client. Yes, No, or Escape to cancel.",
        Buttons = {"yes", "no", "cancel"}, DefaultResult = "yes"})));
    fRemember("DialogOpen", Controls.button(fDemoParent("DialogOpen", oEditors), fOptions({Text = "Open modeless dialog",
        OnClick = function()
            tWidgets.Dialog.show();
        end})));
    fRemember("DialogModalOpen", Controls.button(fDemoParent("DialogModalOpen", oEditors), fOptions({Text = "Open modal dialog",
        OnClick = function()
            local sResult = tWidgets.ModalDialog.showModal();
            fMessage("Modal result: "..tostring(sResult));
        end})));

    -- Tool strips, independent status sections and linked color channels share
    -- this category so runtime changes are visible together.
    local oTools = tTabs.Pages[10];
    local tToolItems = {
        {Id = "attack", Text = "Attack", Image = wxLuma.Config.ImagePath.."/Menu/Command Sword.png",
            Width = 124, Tooltip = "Attack the selected target"},
        {Id = "guard", Text = "Guard", Image = wxLuma.Config.ImagePath.."/Menu/Command Shield.png",
            Width = 124, Tooltip = "Protect nearby allies"},
        {Id = "sep", Kind = "separator"},
        {Id = "auto", Text = "Auto-cast", Kind = "toggle", Selected = true, Tooltip = "Toggle automatic casting"},
        {Id = "unavailable", Text = "Unavailable", Enabled = false},
    };
    for nIndex = 1, 8 do
        tToolItems[#tToolItems + 1] = {Id = "command"..nIndex, Text = "Command "..nIndex,
            Tooltip = "Overflow command "..nIndex};
    end
    fRemember("StatusBar", Controls.statusBar(fDemoParent("StatusBar", oTools), fOptions({Items = {
        {Id = "message", Text = "Ready", Weight = 2},
        {Id = "color", Text = "RGBA", Width = 190},
        {Id = "meter", Width = 180},
    }, OnActivate = function(sId)
        fMessage("Status section: "..sId);
    end})));
    fRemember("Toolbar", Controls.toolbar(fDemoParent("Toolbar", oTools), fOptions({Items = tToolItems,
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
    fRemember("ColorPicker", Controls.colorPicker(fDemoParent("ColorPicker", oTools), fOptions({Value = {R = 65, G = 140, B = 210, A = 190},
        OnChange = function(tColor)
            local sHex = string.format("#%02X%02X%02X%02X", tColor.R, tColor.G, tColor.B, tColor.A);
            tWidgets.StatusBar.setItem("color", {Text = sHex}, true);
            fMessage("Color: "..sHex);
        end})));
    fRemember("ColorPickerAlpha", Controls.colorPicker(fDemoParent("ColorPickerAlpha", oTools), fOptions({Value = {R = 210, G = 90, B = 65, A = 100}})));
    fRemember("ToolbarAdd", Controls.button(fDemoParent("ToolbarAdd", oTools), fOptions({Text = "Add command",
        OnClick = function()
            local tItems = tWidgets.Toolbar.getItems();
            tItems[#tItems + 1] = {Id = "added"..#tItems, Text = "Added "..#tItems};
            tWidgets.Toolbar.setItems(tItems, true);
        end})));
    fRemember("ToolbarRemove", Controls.button(fDemoParent("ToolbarRemove", oTools), fOptions({Text = "Remove last command",
        OnClick = function()
            local tItems = tWidgets.Toolbar.getItems();
            if (#tItems > 0) then
                table.remove(tItems);
                tWidgets.Toolbar.setItems(tItems, true);
            end
        end})));

    -- The workbench uses the real Tabs object; this nested instance exposes its
    -- runtime policies without disturbing the stable outer example categories.
    local oTabsPage = tTabs.Pages[11];
    local nTabSerial = 4;
    fRemember("ExampleTabs", Controls.tabs(fDemoParent("ExampleTabs", oTabsPage), fOptions({
        Items = {
            {Id = "first", Text = "First page"},
            {Id = "second", Text = "A longer caption", Image = wxLuma.Config.ImagePath.."/Menu/Command Shield.png"},
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
    fRemember("TabsMode", Controls.button(fDemoParent("TabsMode", oTabsPage), fOptions({Text = "Wrap / scroll",
        OnClick = function()
            local oTabs = tWidgets.ExampleTabs;
            oTabs.setLayoutMode(oTabs.getLayoutMode() == "wrap" and "scroll" or "wrap", true);
        end})));
    fRemember("TabsPosition", Controls.button(fDemoParent("TabsPosition", oTabsPage), fOptions({Text = "Change header edge",
        OnClick = function()
            local tNext = {top = "right", right = "bottom", bottom = "left", left = "top"};
            tWidgets.ExampleTabs.setPosition(tNext[tWidgets.ExampleTabs.getPosition()], true);
        end})));
    fRemember("TabsAdd", Controls.button(fDemoParent("TabsAdd", oTabsPage), fOptions({Text = "Add page",
        OnClick = function()
            local sId = "added:"..nTabSerial;
            tWidgets.ExampleTabs.addItem({Id = sId, Text = "Added page "..nTabSerial}, nil, true);
            fTabLabel(sId);
            tWidgets.ExampleTabs.setValue(sId, true);
        end})));
    fRemember("TabsRemove", Controls.button(fDemoParent("TabsRemove", oTabsPage), fOptions({Text = "Remove selected",
        OnClick = function()
            local oTabs = tWidgets.ExampleTabs;
            if (oTabs.getValue() > 0) then
                oTabs.removeItem(oTabs.getValue(), true);
            end
        end})));
    fRemember("TabsRename", Controls.button(fDemoParent("TabsRename", oTabsPage), fOptions({Text = "Rename selected",
        OnClick = function()
            local oTabs = tWidgets.ExampleTabs;
            if (oTabs.getValue() > 0) then
                oTabs.setItem(oTabs.getValue(), {Text = "Renamed page "..nTabSerial}, true);
            end
        end})));
    fRemember("TabsMove", Controls.button(fDemoParent("TabsMove", oTabsPage), fOptions({Text = "Move selected first",
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
        {Name = "Faramir", Class = "Ranger", Picture = wxLuma.Config.ImagePath.."/Menu/Command Sword.png"},
        {Name = "Boromir", Class = "Captain", Picture = wxLuma.Config.ImagePath.."/Menu/Command Shield.png"},
        {Name = "Gandalf", Class = "Wizard", Picture = wxLuma.Config.ImagePath.."/Menu/Command Banner.png"},
    };
    fRemember("CheckListEx", Controls.listEx(fDemoParent("CheckListEx", oTreeExPage), fOptions({Columns = tCheckColumns,
        Items = tCheckRows, RowHeight = 48, OnCheckChange = function(nIndex, bChecked)
            fMessage("ListEx row "..nIndex.." checked: "..tostring(bChecked));
        end})));
    fRemember("TreeEx", Controls.treeEx(fDemoParent("TreeEx", oTreeExPage), fOptions({Columns = {
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
    fRemember("CheckListToggle", Controls.checkbox(fDemoParent("CheckListToggle", oTreeExPage), fOptions({Text = "ListEx checkboxes",
        OnChange = function(bFlag)
            tWidgets.CheckListEx.setCheckboxesEnabled(bFlag, true);
        end})));
    fRemember("CheckTreeToggle", Controls.checkbox(fDemoParent("CheckTreeToggle", oTreeExPage), fOptions({Text = "TreeEx checkboxes",
        OnChange = function(bFlag)
            tWidgets.TreeEx.setCheckboxesEnabled(bFlag, true);
        end})));
    fRemember("TreeExMulti", Controls.checkbox(fDemoParent("TreeExMulti", oTreeExPage), fOptions({Text = "TreeEx multi-select",
        OnChange = function(bFlag)
            tWidgets.TreeEx.setMultiSelectEnabled(bFlag, true);
        end})));
    fRemember("CheckListMulti", Controls.checkbox(fDemoParent("CheckListMulti", oTreeExPage), fOptions({Text = "ListEx multi-select",
        OnChange = function(bFlag)
            tWidgets.CheckListEx.setMultiSelectEnabled(bFlag, true);
        end})));
    fRemember("TreeExPropagation", Controls.checkbox(fDemoParent("TreeExPropagation", oTreeExPage), fOptions({Text = "Cascade checks to descendants", Selected = true,
        OnChange = function(bFlag)
            tWidgets.TreeEx.setCheckPropagationEnabled(bFlag, true);
        end})));

    -- Inspector controls share the same artwork and audio hooks as the gallery.
    local oInspector = tTabs.Pages[13];
    fRemember("MenuBar", Controls.menuBar(fDemoParent("MenuBar", oInspector), fOptions({Menus = {
        {Id = "file", Text = "File", Items = {{Id = "open", Text = "Choose file"}, {Id = "folder", Text = "Choose folder"}}},
        {Id = "view", Text = "View", Items = {{Id = "expand", Text = "Expand details"}, {Id = "collapse", Text = "Collapse details"}}},
        {Id = "help", Text = "Help", Items = {{Id = "about", Text = "About inspector controls"}}},
    }, OnSelect = function(tSelection)
        if (tSelection.Id == "open") then oGallery.show("FilePicker", true); tWidgets.FilePicker.open();
        elseif (tSelection.Id == "folder") then oGallery.show("FolderPicker", true); tWidgets.FolderPicker.open();
        elseif (tSelection.Id == "expand") then oGallery.show("CollapsiblePanel", true); tWidgets.CollapsiblePanel.setExpanded(true, true);
        elseif (tSelection.Id == "collapse") then oGallery.show("CollapsiblePanel", true); tWidgets.CollapsiblePanel.setExpanded(false, true);
        else fMessage("Inspector: skinned editors, menus, file browsing and disclosure containers."); end
    end})));
    fRemember("SearchField", Controls.searchField(fDemoParent("SearchField", oInspector), fOptions({Hint = "Type a sample search", Debounce = 180,
        OnSearch = function(sText) fMessage("Search: "..sText); end})));
    fRemember("ComboBox", Controls.comboBox(fDemoParent("ComboBox", oInspector), fOptions({Items = {"Balanced", "Cautious", "Fast"},
        Value = "Balanced", Hint = "Choose or type a profile", OnChange = fChanged("Profile")})));
    fRemember("FilePicker", Controls.filePicker(fDemoParent("FilePicker", oInspector), fOptions({Hint = "Choose an existing file", OnChange = fChanged("File")})));
    fRemember("FolderPicker", Controls.folderPicker(fDemoParent("FolderPicker", oInspector), fOptions({Hint = "Choose an existing folder", OnChange = fChanged("Folder")})));
    local oDetails = fRemember("CollapsiblePanel", Controls.collapsiblePanel(fDemoParent("CollapsiblePanel", oInspector), fOptions({Text = "Details",
        ContentHeight = 64, OnChange = function(bExpanded)
            local nX, nY = tWidgets.CollapsiblePanel.Control:GetPositionXY();
            local nWidth = tWidgets.CollapsiblePanel.Control:GetSizeWH();
            tWidgets.CollapsiblePanel.layout(nX, nY, nWidth, tWidgets.CollapsiblePanel.getBestHeight());
            fMessage(bExpanded and "Details expanded." or "Details collapsed.");
        end})));
    fRemember("DetailsText", Controls.label(oDetails.Content, fOptions({Value = "Collapsing preserves child values.", Wrap = true})));
    local oAccordion = fRemember("Accordion", Controls.accordion(fDemoParent("Accordion", oInspector), fOptions({Sections = {
        {Id = "appearance", Text = "Appearance", Height = 62, Expanded = true},
        {Id = "behavior", Text = "Behavior", Height = 62},
    }, OnChange = function(sId, bExpanded) fMessage(sId..(bExpanded and " expanded." or " collapsed.")); end})));
    fRemember("AppearanceText", Controls.label(oAccordion.getSection("appearance").Content,
        fOptions({Value = "Every glyph and surface comes from the skin.", Wrap = true})));
    fRemember("BehaviorCheck", Controls.checkbox(oAccordion.getSection("behavior").Content,
        fOptions({Text = "Keep sample state", Selected = true})));
    fRemember("PropertyGrid", Controls.propertyGrid(fDemoParent("PropertyGrid", oInspector), fOptions({LabelWidth = 130, Properties = {
        {Id = "general", Text = "General", Type = "category"},
        {Id = "name", Text = "Name", Value = "Sample object"},
        {Id = "enabled", Text = "Enabled", Type = "boolean", Value = true},
        {Id = "opacity", Text = "Opacity", Type = "number", Min = 0, Max = 1, Step = 0.05, Precision = 2, Value = 0.8},
        {Id = "profile", Text = "Profile", Type = "choice", Items = {"Balanced", "Cautious", "Fast"}, Value = "Balanced"},
        {Id = "tint", Text = "Tint", Type = "color", Value = {R = 90, G = 180, B = 210}},
        {Id = "resources", Text = "Resources", Type = "category"},
        {Id = "file", Text = "File", Type = "file"},
        {Id = "folder", Text = "Folder", Type = "folder"},
        {Id = "identifier", Text = "Identifier", Value = "sample-001", ReadOnly = true},
    }, OnChange = function(sId, vValue) fMessage("Property "..sId..": "..tostring(vValue)); end})));

    fRemember("MultilineText", Controls.multilineText(fDemoParent("MultilineText", oInput), fOptions({
        Value = "Notes and descriptions\n\nEnter inserts a newline. Try selection, clipboard and undo.", OnChange = fChanged("Notes")})));
    fRemember("RangeSlider", Controls.rangeSlider(fDemoParent("RangeSlider", oInput), fOptions({
        Min = 0, Max = 100, Step = 1, Value = {Low = 20, High = 80}, OnChange = function(tValue)
            fMessage("Selected range: "..tValue.Low.." to "..tValue.High);
        end})));
    for nIndex, sMode in ipairs({"none", "revolve", "alternate"}) do
        local sKey = ({"Knob", "KnobWrap", "KnobBounce"})[nIndex];
        fRemember(sKey, Controls.knob(fDemoParent(sKey, oInput), fOptions({Min = 0, Max = 100,
            Value = 95, Rate = 10, Continuity = sMode, OnChange = fChanged("Knob "..sMode)})));
    end
    for _, tAction in ipairs({{"KnobIncrease", "Increase all", "increase"}, {"KnobDecrease", "Decrease all", "decrease"}}) do
        fRemember(tAction[1], Controls.button(fDemoParent(tAction[1], oInput), fOptions({Text = tAction[2], OnClick = function()
            for _, sKey in ipairs({"Knob", "KnobWrap", "KnobBounce"}) do tWidgets[sKey][tAction[3]](1, true); end
        end})));
    end
    for _, tSample in ipairs({{"DateTimePicker", "date", "2026-10-21"}, {"TimePicker", "time", "14:30"},
        {"CombinedPicker", "datetime", "2026-10-21 14:30"}}) do
        fRemember(tSample[1], Controls.dateTimePicker(fDemoParent(tSample[1], oInput), fOptions({
            Mode = tSample[2], Value = tSample[3], OnChange = fChanged("Selected "..tSample[2])})));
    end
    fRemember("Breadcrumb", Controls.breadcrumb(fDemoParent("Breadcrumb", oInput), fOptions({Items = {
        {Id = "home", Text = "Home"}, {Id = "project", Text = "Project"}, {Id = "assets", Text = "Assets"},
        {Id = "icons", Text = "Icons"}, {Id = "selected", Text = "Selected item"}}, OnChange = fChanged("Path")})));
    fRemember("Notification", Controls.notification(fDemoParent("Notification", oInput), fOptions({
        Value = "Choose a notification below. Close or Escape dismisses it.", Duration = 3000})));
    for _, sSeverity in ipairs({"info", "success", "warning", "error"}) do
        local sKey = "Notify"..sSeverity:sub(1, 1):upper()..sSeverity:sub(2);
        fRemember(sKey, Controls.button(fDemoParent(sKey, oInput), fOptions({Text = "Show "..sSeverity, OnClick = function()
            tWidgets.Notification.show("Sample "..sSeverity.." notification", sSeverity, sSeverity == "error" and 0 or 3000);
        end})));
    end
    local oDock = fRemember("DockablePanel", Controls.dockablePanel(fDemoParent("DockablePanel", oInput),
        fOptions({Text = "Inspector", Extent = 240, OnChange = function(tState)
            fMessage(tState.Floating and "Inspector is floating." or "Inspector docked: "..tState.Side);
        end})));
    local oDockText = fRemember("DockText", Controls.textfield(oDock.Content, fOptions({Value = "Child text survives docking."})));
    local function fDockContent() local nWidth = oDock.Content:GetClientSizeWH(); oDockText.layout(12, 12, math.max(1, nWidth - 24), 38); end
    oDock.Content:Connect(wx.wxEVT_SIZE, function(oEvent) fDockContent(); oEvent:Skip(); end); fDockContent();
    for _, tAction in ipairs({{"DockFloat", "Float", "float"}, {"DockLeft", "Dock left", "left"},
        {"DockRight", "Dock right", "right"}, {"DockFill", "Dock fill", "fill"}}) do
        fRemember(tAction[1], Controls.button(fDemoParent(tAction[1], oInput), fOptions({Text = tAction[2], OnClick = function()
            if (tAction[3] == "float") then oDock.float(nil, nil, true); else oDock.dock(tAction[3], true); end
        end})));
    end

    for nIndex, tSample in ipairs({{"Switch", "horizontal", false}, {"SwitchReverse", "horizontal", true},
        {"SwitchVertical", "vertical", false}, {"SwitchVerticalReverse", "vertical", true}}) do
        fRemember(tSample[1], Controls.switch(fDemoParent(tSample[1], oInput), fOptions({
            Orientation = tSample[2], Reversed = tSample[3], Value = nIndex % 2 == 1,
            OnChange = fChanged(tSample[1])})));
    end
    for _, tAction in ipairs({{"SwitchOrientation", "Rotate switches", "orientation"},
        {"SwitchDirection", "Reverse switches", "direction"}}) do
        fRemember(tAction[1], Controls.button(fDemoParent(tAction[1], oInput), fOptions({Text = tAction[2], OnClick = function()
            for _, sKey in ipairs({"Switch", "SwitchReverse", "SwitchVertical", "SwitchVerticalReverse"}) do
                local oSwitch = tWidgets[sKey];
                if (tAction[3] == "orientation") then
                    oSwitch.setOrientation(oSwitch.getOrientation() == "horizontal" and "vertical" or "horizontal", true);
                else oSwitch.setReversed(not oSwitch.getReversed(), true); end
            end
        end})));
    end
    for _, tSample in ipairs({{"LED", true, false, {R = 80, G = 220, B = 140}},
        {"LEDGlass", true, true, {R = 245, G = 80, B = 65}}, {"LEDOff", false, true, {R = 65, G = 160, B = 245}}}) do
        fRemember(tSample[1], Controls.led(fDemoParent(tSample[1], oInput), fOptions({
            Value = tSample[2], Glass = tSample[3], Color = tSample[4], Size = 72})));
    end
    for _, tAction in ipairs({{"LEDValue", "Power", "Value"}, {"LEDGlow", "Glow", "Glow"}, {"LEDGlassToggle", "Glass cover", "Glass"}}) do
        fRemember(tAction[1], Controls.checkbox(fDemoParent(tAction[1], oInput), fOptions({
            Text = tAction[2], Selected = tAction[3] ~= "Glass", OnChange = function(bValue)
                tWidgets.LED["set"..tAction[3]](bValue, true);
            end})));
    end
    fRemember("LEDBrightness", Controls.slider(fDemoParent("LEDBrightness", oInput), fOptions({
        Min = 0, Max = 100, Value = 100, Step = 1, OnChange = function(nValue) tWidgets.LED.setBrightness(nValue / 100, true); end})));
    fRemember("LEDSize", Controls.slider(fDemoParent("LEDSize", oInput), fOptions({
        Min = 12, Max = 96, Value = 72, Step = 1, OnChange = function(nValue)
            tWidgets.LED.setSize(nValue, true);
            if (tWidgets.LED.getGlowRadius() == nil) then tWidgets.LEDGlowRadius.setValue(nValue * 0.75); end
        end})));
    fRemember("LEDColor", Controls.colorPicker(fDemoParent("LEDColor", oInput), fOptions({
        Value = {R = 80, G = 220, B = 140}, OnChange = function(tColor) tWidgets.LED.setColor(tColor, true); end})));
    fRemember("LEDGlowRadius", Controls.slider(fDemoParent("LEDGlowRadius", oInput), fOptions({
        Min = 0, Max = 72, Value = 54, Step = 1, OnChange = function(nValue) tWidgets.LED.setGlowRadius(nValue, true); end})));
    fRemember("LEDGlowAutomatic", Controls.button(fDemoParent("LEDGlowAutomatic", oInput), fOptions({
        Text = "Automatic glow radius", OnClick = function()
            tWidgets.LED.setGlowRadius(nil, true);
            tWidgets.LEDGlowRadius.setValue(tWidgets.LED.getSize() * 0.75);
        end})));

    local sLogIcon = wxLuma.Path.."/Images/Controls/Control Log Viewer Icon Normal.png";
    local tLogSamples = {{Id = "ready", Text = "Ready. Drag across text to select a substring.", Icon = sLogIcon, Timestamp = "12:00:00"},
        {Id = "unicode", Text = "Unicode: café, 雪, and ☃ remain selectable and copyable.", Timestamp = "12:00:01"},
        {Id = "warning", Text = "An optional warning severity has no effect until enabled.", Severity = "warning", Timestamp = "12:00:02"},
        {Id = "multiline", Text = "Multiple lines belong to the same entry.\nCopying the entry preserves every line.", Icon = sLogIcon, Timestamp = "12:00:03"}};
    fRemember("LogViewer", Controls.logViewer(fDemoParent("LogViewer", oInput), fOptions({Entries = tLogSamples})));
    fRemember("ActionLog", Controls.logViewer(fDemoParent("ActionLog", oInput), fOptions({Entries = {
        {Text = "You enter the old watchtower.", Icon = sLogIcon}, {Text = "A hidden door opens."}, {Text = "You gain 25 experience."}},
        Transparent = true, Background = function(oDC, oLog)
            local nW, nH = oLog.Control:GetClientSizeWH(); tSkin.draw(oDC, "Log Viewer Game Background", 0, 0, nW, nH);
        end})));
    fWireAudio("LogMenu", tWidgets.LogViewer.ContextMenu);
    fWireAudio("ActionLogMenu", tWidgets.ActionLog.ContextMenu);
    local nLogAction = 0;
    for _, tAction in ipairs({{"LogAppend", "Append actions", "append"}, {"LogClear", "Clear logs", "clear"},
        {"LogCopy", "Copy selection", "copy"}, {"LogFollow", "Follow latest", "follow"}}) do
        fRemember(tAction[1], Controls.button(fDemoParent(tAction[1], oInput), fOptions({Text = tAction[2], OnClick = function()
            if (tAction[3] == "append") then
                nLogAction = nLogAction + 1;
                tWidgets.LogViewer.addEntry({Text = "Sample output "..nLogAction, Severity = nLogAction % 3 == 0 and "warning" or nil, Icon = sLogIcon}, true);
                tWidgets.ActionLog.addEntry({Text = "Action "..nLogAction..": your party advances.", Icon = sLogIcon}, true);
            elseif (tAction[3] == "clear") then tWidgets.LogViewer.clear(true); tWidgets.ActionLog.clear(true);
            elseif (tAction[3] == "copy") then local bCopied = tWidgets.LogViewer.copySelected(); fMessage(bCopied and "Log selection copied." or "Select log text or entries first.");
            else tWidgets.LogViewer.scrollToEnd(true); tWidgets.ActionLog.scrollToEnd(true); end
        end})));
    end
    fRemember("LogFilter", Controls.searchField(fDemoParent("LogFilter", oInput), fOptions({Hint = "Filter log text", Debounce = 120,
        OnSearch = function(sText) tWidgets.LogViewer.setFilterText(sText, true); tWidgets.ActionLog.setFilterText(sText, true); end})));
    for _, tAction in ipairs({{"LogSeverity", "Severity colors / labels", "SeverityEnabled", false},
        {"LogWrap", "Wrap log text", "Wrap", true}, {"LogAutoScroll", "Auto-scroll logs", "AutoScroll", true}}) do
        fRemember(tAction[1], Controls.checkbox(fDemoParent(tAction[1], oInput), fOptions({Text = tAction[2], Selected = tAction[4], OnChange = function(bValue)
            tWidgets.LogViewer["set"..tAction[3]](bValue, true);
            if (tAction[3] ~= "SeverityEnabled") then tWidgets.ActionLog["set"..tAction[3]](bValue, true); end
        end})));
    end
    fRemember("LogLimit", Controls.spinner(fDemoParent("LogLimit", oInput), fOptions({Min = 10, Max = 10000, Step = 10, Value = 1000,
        OnChange = function(nValue) tWidgets.LogViewer.setMaxEntries(nValue, true); tWidgets.ActionLog.setMaxEntries(nValue, true); end})));

    local tChartSeries = {{Id = "north", Text = "North", Points = {}}, {Id = "south", Text = "South", Points = {}}};
    for nIndex = 1, 6 do
        tChartSeries[1].Points[nIndex] = {Id = "p"..nIndex, X = nIndex, Y = 20 + (nIndex * 7) % 23};
        tChartSeries[2].Points[nIndex] = {Id = "p"..nIndex, X = nIndex, Y = 12 + (nIndex * 11) % 19};
    end
    for _, tSample in ipairs({{"LineChart", "lineChart", "Line"}, {"AreaChart", "areaChart", "Area"},
        {"BarChart", "barChart", "Grouped"}, {"StackedBarChart", "barChart", "Stacked"},
        {"HorizontalBarChart", "barChart", "Horizontal"}, {"ScatterChart", "scatterChart", "XY points"}}) do
        tItemHover[tSample[1]] = "pointHovered";
        fRemember(tSample[1], Controls[tSample[2]](fDemoParent(tSample[1], oInput), fOptions({Title = tSample[3], Series = tChartSeries,
            Stacked = tSample[1] == "StackedBarChart", Orientation = tSample[1] == "HorizontalBarChart" and "horizontal" or "vertical",
            MaxPoints = 12, Precision = 0, OnChange = function(tValue) fMessage(tValue and "Selected "..tValue.Series.." / "..tValue.Point or "Chart selection cleared."); end})));
    end
    local tSlices = {{Id = "actions", Text = "Actions", Points = {{Id = "attack", Text = "Attack", Y = 45},
        {Id = "defend", Text = "Defend", Y = 25}, {Id = "move", Text = "Move", Y = 20}, {Id = "other", Text = "Other", Y = 10}}}};
    for _, sKey in ipairs({"PieChart", "DonutChart"}) do
        tItemHover[sKey] = "pointHovered";
        fRemember(sKey, Controls[sKey == "PieChart" and "pieChart" or "donutChart"](fDemoParent(sKey, oInput),
            fOptions({Title = sKey == "PieChart" and "Pie" or "Donut", Series = tSlices, Precision = 0})));
    end
    local nChartPoint = 6;
    for _, tAction in ipairs({{"ChartAppend", "Append values", "append"}, {"ChartReset", "Reset graph views", "reset"},
        {"BarOrientation", "Rotate bars", "rotate"}, {"PieRotate", "Rotate slices", "pie"}, {"ScatterReset", "Reset scatter view", "scatter"}}) do
        fRemember(tAction[1], Controls.button(fDemoParent(tAction[1], oInput), fOptions({Text = tAction[2], OnClick = function()
            if (tAction[3] == "append") then
                nChartPoint = nChartPoint + 1;
                for _, sKey in ipairs({"LineChart", "AreaChart"}) do
                    tWidgets[sKey].addPoint("north", {Id = "p"..nChartPoint, X = nChartPoint, Y = 20 + (nChartPoint * 7) % 23}, true);
                    tWidgets[sKey].addPoint("south", {Id = "p"..nChartPoint, X = nChartPoint, Y = 12 + (nChartPoint * 11) % 19}, true);
                end
            elseif (tAction[3] == "reset") then tWidgets.LineChart.resetView(true); tWidgets.AreaChart.resetView(true);
            elseif (tAction[3] == "rotate") then for _, sKey in ipairs({"BarChart", "StackedBarChart"}) do tWidgets[sKey].setOrientation(tWidgets[sKey].getOrientation() == "vertical" and "horizontal" or "vertical", true); end
            elseif (tAction[3] == "pie") then for _, sKey in ipairs({"PieChart", "DonutChart"}) do tWidgets[sKey].setStartAngle(tWidgets[sKey].getStartAngle() + 30, true); end
            else tWidgets.ScatterChart.resetView(true); end
        end})));
    end
    for _, tAction in ipairs({{"ChartMarkers", "Graph markers", "Markers", true, {"LineChart", "AreaChart"}},
        {"ChartGrid", "Graph grids", "Grid", true, {"LineChart", "AreaChart"}},
        {"BarStacked", "Stack first bar chart", "Stacked", false, {"BarChart"}},
        {"PieClockwise", "Clockwise slices", "Clockwise", true, {"PieChart", "DonutChart"}},
        {"ScatterGrid", "Scatter grid", "Grid", true, {"ScatterChart"}}}) do
        fRemember(tAction[1], Controls.checkbox(fDemoParent(tAction[1], oInput), fOptions({Text = tAction[2], Selected = tAction[4], OnChange = function(bValue)
            for _, sKey in ipairs(tAction[5]) do tWidgets[sKey]["set"..tAction[3]](bValue, true); end
        end})));
    end
    for _, tAction in ipairs({{"ChartLineWidth", "LineWidth", 1, 8, 2, 1, {"LineChart", "AreaChart"}},
        {"ChartAreaOpacity", "AreaOpacity", 0, 100, 30, 0.01, {"AreaChart"}},
        {"BarGap", "BarGap", 0, 90, 20, 0.01, {"BarChart", "StackedBarChart", "HorizontalBarChart"}},
        {"DonutHole", "HoleSize", 0, 90, 50, 0.01, {"DonutChart"}},
        {"PieGap", "SliceGap", 0, 20, 0, 1, {"PieChart", "DonutChart"}},
        {"ScatterMarkerSize", "MarkerSize", 3, 20, 7, 1, {"ScatterChart"}}}) do
        fRemember(tAction[1], Controls.slider(fDemoParent(tAction[1], oInput), fOptions({Min = tAction[3], Max = tAction[4], Value = tAction[5], Step = 1, OnChange = function(nValue)
            for _, sKey in ipairs(tAction[7]) do tWidgets[sKey]["set"..tAction[2]](nValue * tAction[6], true); end
        end})));
    end

    -- Bind every example before layout; the gallery owns only presentation.
    oGallery.bind(tWidgets);

    --[[!
    @fqxn wxLuma.Tests.UI.fLayout
    @desc Fits the category gallery and its scrollable documented containers.
        Nested examples keep their own native Content parents and input policies.
    !]]
    local function fLayout()
        local nW, nH = tWindow.Control:GetClientSizeWH();
        if (nW < 320 or nH < 240) then return; end
        local tContent = tWindow.getGeometry().Content;
        tTabs.layout(tContent.x, tContent.y, tContent.width, tContent.height - 42);
        oGallery.layout();
        fSplitChildren();
        local nWidth = tWidgets.CollapsiblePanel.Content:GetClientSizeWH();
        tWidgets.DetailsText.layout(8, 8, math.max(1, nWidth - 16), 42);
        nWidth = tWidgets.Accordion.getSection("appearance").Content:GetClientSizeWH();
        tWidgets.AppearanceText.layout(8, 8, math.max(1, nWidth - 16), 42);
        nWidth = tWidgets.Accordion.getSection("behavior").Content:GetClientSizeWH();
        tWidgets.BehaviorCheck.layout(8, 8, math.max(1, nWidth - 16), 36);
    end
    local oSizer = wx.wxBoxSizer(wx.wxVERTICAL); oSizer:Add(tWindow.Control, 1, wx.wxEXPAND); oFrame:SetSizer(oSizer);
    tWindow.Control:Connect(wx.wxEVT_SIZE, function(oEvent) if (not bDisposed) then fLayout(); end; oEvent:Skip(); end);
    oFrame:Connect(wx.wxEVT_CHAR_HOOK, function(oEvent)
        if (oEvent:GetKeyCode() == wx.WXK_ESCAPE) then
            if (tWidgets.Dropdown.isOpen()) then tWidgets.Dropdown.close(false);
            elseif (tWidgets.ComboBox.isOpen()) then tWidgets.ComboBox.close(false);
            elseif (tPanel.Control:HasCapture()) then tPanel.handleKey("down", wx.WXK_ESCAPE);
            elseif (tWidgets.SplitContainer.Control:HasCapture()) then
                tWidgets.SplitContainer.handleKey("down", wx.WXK_ESCAPE);
            else
                local oFocus = wx.wxWindow.FindFocus();
                if (oFocus and wx.wxDynamicCast(oFocus, "wxTextCtrl")) then oEvent:Skip();
                else oFrame:Close(); end
            end
        else oEvent:Skip(); end
    end);
    oFrame:Connect(wx.wxEVT_ACTIVATE, function(oEvent)
        if (not oEvent:GetActive()) then for _, tTip in ipairs(tTips) do tTip.hide(); end end; oEvent:Skip();
    end);
    oFrame:Connect(wx.wxEVT_CLOSE_WINDOW, function(oEvent)
        bDisposed = true;
        -- Stop asynchronous playback before releasing its native resources.
        wx.wxSound.Stop();
        oHoverSound:delete(); oClickSound:delete();
        for _, tTip in ipairs(tTips) do tTip.destroy(); end
        for _, tWidget in pairs(tWidgets) do tWidget.destroy(); end
        oGallery.destroy();
        tWindow.destroy(); tSkin.destroy(); oEvent:Skip();
    end);
    oFrame:SetClientSize(wx.wxSize(1120, 900)); oFrame:Centre(); oFrame:Show(true); fLayout();
    return {Frame = oFrame, Window = tWindow, Widgets = tWidgets, Skin = tSkin, Group = tGroup,
        Layout = fLayout, Tooltips = tTips, Gallery = oGallery};
end;
