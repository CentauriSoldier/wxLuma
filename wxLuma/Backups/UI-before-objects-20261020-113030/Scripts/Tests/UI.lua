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
    local tTabs = Controls.tabs(tWindow.Control, fOptions({Items = {"Original controls", "Lists & text", "Resources & panel"}, OnChange = fChanged("Tab")}));
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
    tTips[1] = Controls.tooltip(tWidgets.Text.TextControl, fOptions({Text = "Native text editing inside the common skin.\nEnter reports the sample; no data is saved."}));
    tTips[2] = Controls.tooltip(tWidgets.List.Control, fOptions({Text = "Wheel or drag the scrollbar.\nArrows, Page Up/Down, Home/End select rows."}));

    fLabel(oResources, "RESOURCE METERS  /  sample controls below change all three", 16, 14);
    fRemember("Health", Controls.progress(oResources, fOptions({Min = 0, Max = 100, Value = 70, Text = "Health  %v / %m", Colour = {R = 107, G = 142, B = 91}})));
    fRemember("Mana", Controls.progress(oResources, fOptions({Min = 0, Max = 100, Value = 45, Text = "Mana  %v / %m", Colour = {R = 77, G = 120, B = 169}})));
    fRemember("Progress", Controls.progress(oResources, fOptions({Min = 0, Max = 100, Value = 25, Text = "Loading  %v%", Colour = {R = 150, G = 128, B = 83}})));
    fRemember("MeterSlider", Controls.slider(oResources, fOptions({Min = 0, Max = 100, Step = 1, Value = 70, OnChange = function(nValue)
        for _, sKey in ipairs({"Health", "Mana", "Progress"}) do tWidgets[sKey].setValue(nValue); end; fMessage("Sample meters: " .. nValue);
    end})));
    fRemember("Panel", Controls.panel(oResources, fOptions({Text = "RESIZABLE EMBEDDED PANEL", MinWidth = 260, MinHeight = 200,
        OnResize = function(nW, nH) fMessage("Embedded panel: " .. nW .. " x " .. nH); end})));
    local tPanel = tWidgets.Panel;
    fLabel(tPanel.Content, "Drag the bottom-right grip.\nFocus the border and use arrow keys.\nShift + arrows: 10 pixels. Escape cancels drag.", 8, 6);
    fRemember("PanelButton", Controls.button(tPanel.Content, fOptions({Text = "Panel action", OnClick = function() fMessage("The embedded panel button works."); end})));
    tWidgets.PanelButton.layout(8, 75, 160, 40);
    local tPanelToggle = Controls.button(oResources, fOptions({Text = "Hide / show panel", OnClick = function() tPanel.show(not tPanel.Control:IsShown()); fMessage(tPanel.Control:IsShown() and "Panel shown." or "Panel hidden."); end}));
    tWidgets.PanelToggle = tPanelToggle;

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
        tWidgets.Text.layout(354, 136, nRightW, 40); tWidgets.DisabledText.layout(354, 226, nRightW, 40);
        tWidgets.Scrollbar.layout(354, 320, nRightW, 26);
        local nResourceW = oResources:GetClientSizeWH();
        for nIndex, sKey in ipairs({"Health", "Mana", "Progress"}) do tWidgets[sKey].layout(16, 46 + (nIndex - 1) * 46, math.min(500, nResourceW - 32), 34); end
        tWidgets.MeterSlider.layout(16, 184, math.min(500, nResourceW - 32), 44);
        tPanelToggle.layout(16, 236, 210, 40);
        local nPanelW, nPanelH = tPanel.Control:GetSizeWH();
        if (nPanelW < 260 or nPanelH < 140) then nPanelW, nPanelH = 440, 190; end
        tPanel.layout(16, 290, nPanelW, nPanelH); tPanel.resize(nPanelW, nPanelH);
    end
    local oSizer = wx.wxBoxSizer(wx.wxVERTICAL); oSizer:Add(tWindow.Control, 1, wx.wxEXPAND); oFrame:SetSizer(oSizer);
    tWindow.Control:Connect(wx.wxEVT_SIZE, function(oEvent) if (not bDisposed) then fLayout(); end; oEvent:Skip(); end);
    oFrame:Connect(wx.wxEVT_CHAR_HOOK, function(oEvent)
        if (oEvent:GetKeyCode() == wx.WXK_ESCAPE) then
            if (tWidgets.Dropdown.isOpen()) then tWidgets.Dropdown.close(false);
            elseif (tPanel.Control:HasCapture()) then tPanel.handleKey("down", wx.WXK_ESCAPE);
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
