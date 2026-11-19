local _wx = require("wx");
local _Border = require("wxLuma.Core.ControlBorder");
local _load = require("wxLuma");
local BorderRegression = {};

--[[!
@fqxn wxLuma.Tests.BorderRegression.run
@desc Verifies native default/explicit border flags, composite border ownership,
    preserved input styles, provider changes and stable floating client geometry.
    Memory rendering checks that System does not paint replacement client frames.
@ret number nChecks Successful border assertions.
!]]
function BorderRegression.run()
    local nChecks = 0;
    local oLuma = _load();
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Border regression");
    local tOwned = {};
    --[[!
    @fqxn wxLuma.Tests.BorderRegression.fCheck
    @desc Counts assertions with a focused native-border failure message.
    !]]
    local function fCheck(bPassed, sMessage) assert(bPassed, sMessage); nChecks = nChecks + 1; end
    local bOK, sError = xpcall(function()
        local nInputFlags = _wx.wxWANTS_CHARS + _wx.wxTAB_TRAVERSAL;
        fCheck(_Border.style({}, nInputFlags) == nInputFlags, "Omitted Border delegates to the wxWidgets default.");
        for _, nBorder in ipairs({_wx.wxBORDER_DEFAULT, _wx.wxBORDER_NONE, _wx.wxBORDER_SIMPLE,
            _wx.wxBORDER_SUNKEN, _wx.wxBORDER_RAISED, _wx.wxBORDER_STATIC, _wx.wxBORDER_THEME}) do
            fCheck((_Border.style({Border = nBorder}, nInputFlags + _wx.wxBORDER_NONE) & _wx.wxBORDER_MASK) == nBorder,
                "Border replaces existing border bits without combining incompatible styles.");
        end
        fCheck(not pcall(_Border.style, {Border = "sunken"}) and not pcall(_Border.style, {Border = 1}), "Invalid border values fail clearly.");
        local tFactories = {
            button = {Text = "Action"}, checkbox = {Text = "Option"}, slider = {Min = 0, Max = 100, Step = 1, Value = 50},
            textfield = {Value = "Text"}, multilineText = {Value = "Notes"}, searchField = {Value = "Search"},
            comboBox = {Value = "Owner", Items = {"Owner"}}, numericField = {Value = 2},
            spinner = {Min = 0, Max = 10, Step = 1, Value = 2}, dateTimePicker = {Value = "2026-12-01"},
            tree = {Items = {}}, table = {Columns = {{Text = "Name"}}, Items = {}},
            listEx = {Columns = {{Key = "Name"}}, Items = {{Name = "Row"}}},
            barChart = {Series = {}}, panel = {}, dialog = {}, dockablePanel = {},
        };
        for sFactory, tBase in pairs(tFactories) do
            for _, nBorder in ipairs({_wx.wxBORDER_DEFAULT, _wx.wxBORDER_NONE, _wx.wxBORDER_SUNKEN, _wx.wxBORDER_SIMPLE}) do
                local tOptions = {}; for sKey, vValue in pairs(tBase) do tOptions[sKey] = vValue; end
                if (nBorder ~= _wx.wxBORDER_DEFAULT) then tOptions.Border = nBorder; end
                local oControl = oLuma.Controls[sFactory](oFrame, tOptions); tOwned[#tOwned + 1] = oControl;
                local oNative = oControl.BorderControl or oControl.Control;
                local nActual = oNative:GetWindowStyleFlag() & _wx.wxBORDER_MASK;
                local nExpected = nBorder;
                if (nBorder == _wx.wxBORDER_DEFAULT and (sFactory == "slider" or sFactory == "button" or sFactory == "checkbox")) then
                    nExpected = _wx.wxBORDER_NONE;
                elseif (nBorder == _wx.wxBORDER_DEFAULT) then
                    -- Native classes may resolve DEFAULT into THEME or SUNKEN.
                    -- Compare with an ordinary wxWidgets instance of that class,
                    -- rather than assuming that its stored flags remain zero.
                    local nFlags = oNative:GetWindowStyleFlag() & ~_wx.wxBORDER_MASK;
                    local oReference;
                    if (oControl.TreeControl) then
                        oReference = _wx.wxTreeCtrl(oFrame, _wx.wxID_ANY, _wx.wxDefaultPosition, _wx.wxDefaultSize, nFlags);
                    elseif (oControl.TableControl) then
                        oReference = _wx.wxListCtrl(oFrame, _wx.wxID_ANY, _wx.wxDefaultPosition, _wx.wxDefaultSize, nFlags);
                    elseif (oControl.TextControl) then
                        oReference = _wx.wxTextCtrl(oFrame, _wx.wxID_ANY, "", _wx.wxDefaultPosition, _wx.wxDefaultSize, nFlags);
                    else
                        oReference = _wx.wxControl(oFrame, _wx.wxID_ANY, _wx.wxDefaultPosition, _wx.wxDefaultSize, nFlags);
                    end
                    nExpected = oReference:GetWindowStyleFlag() & _wx.wxBORDER_MASK;
                    oReference:Destroy();
                end
                fCheck(nActual == nExpected, sFactory.." uses the requested native border.");
                if (oControl.BorderControl) then
                    fCheck((oControl.Control:GetWindowStyleFlag() & _wx.wxBORDER_MASK) == _wx.wxBORDER_DEFAULT,
                        "Composite host does not duplicate its native child's border.");
                end
                fCheck(tOptions.Border == (nBorder ~= _wx.wxBORDER_DEFAULT and nBorder or nil), "Constructor options remain caller-owned.");
            end
        end
        local tMeters = {
            progress = {Min = 0, Max = 100, Value = 50}, circularProgress = {Shape = 1, FillMode = 2, Min = 0, Max = 100, Value = 50},
            globeProgress = {Shape = 1, FillMode = 0, Min = 0, Max = 100, Value = 50}, radialProgress = {Shape = 1, FillMode = 1, Min = 0, Max = 100, Value = 50},
            irisProgress = {Min = 0, Max = 100, Value = 50}, knob = {Min = 0, Max = 100, Value = 50, Rate = 1},
            led = {Value = true}, slider = {Min = 0, Max = 100, Step = 1, Value = 50},
            rangeSlider = {Min = 0, Max = 100, Step = 1, Value = {Low = 20, High = 80}},
        };
        local tMeterBorders = {};
        for sFactory, tBase in pairs(tMeters) do
            for _, nBorder in ipairs({false, _wx.wxBORDER_DEFAULT, _wx.wxBORDER_NONE, _wx.wxBORDER_SIMPLE, _wx.wxBORDER_SUNKEN}) do
                local tOptions = {}; for sKey, vValue in pairs(tBase) do tOptions[sKey] = vValue; end
                if (nBorder ~= false) then tOptions.Border = nBorder; end
                local fCreate = tOptions.Shape ~= nil and oLuma.Controls.progress or oLuma.Controls[sFactory];
                local oMeter = fCreate(oFrame, tOptions); tOwned[#tOwned + 1] = oMeter;
                local nExpected = nBorder == false and _wx.wxBORDER_NONE or nBorder;
                fCheck((oMeter.Control:GetWindowStyleFlag() & _wx.wxBORDER_MASK) == nExpected,
                    sFactory.." is borderless by default and honors explicit overrides.");
                fCheck(tOptions.Border == (nBorder ~= false and nBorder or nil), "Meter constructor leaves caller options unchanged.");
                tMeterBorders[#tMeterBorders + 1] = {Object = oMeter, Expected = nExpected};
            end
        end
        local oDock = oLuma.Controls.dockablePanel(oFrame, {Text = "Inspector"}); tOwned[#tOwned + 1] = oDock;
        local tPlacement = oDock.getDockState();
        for nPass = 1, 5 do
            oDock.setDockState(tPlacement);
            local tNext = oDock.getDockState();
            fCheck(tNext.Width == tPlacement.Width and tNext.Height == tPlacement.Height,
                "Native inspector chrome does not shrink restored client dimensions.");
        end
        fCheck((oDock.FloatingWindow:GetWindowStyleFlag() & _wx.wxCAPTION) ~= 0, "Floating inspector has OS window chrome.");
        oLuma.Theme.setName("Obsidian"); oLuma.Theme.setName("System");
        for _, tMeter in ipairs(tMeterBorders) do
            fCheck((tMeter.Object.Control:GetWindowStyleFlag() & _wx.wxBORDER_MASK) == tMeter.Expected,
                "Meter border defaults and overrides survive provider switching.");
        end
        for _, oControl in ipairs(tOwned) do
            if (oControl.BorderControl) then
                fCheck((oControl.Control:GetWindowStyleFlag() & _wx.wxBORDER_MASK) == _wx.wxBORDER_DEFAULT,
                    "Appearance changes do not add a duplicate composite frame.");
            end
        end
        local oField = oLuma.Controls.textfield(oFrame, {Value = "Native frame"}); tOwned[#tOwned + 1] = oField;
        local oBitmap = _wx.wxBitmap(200, 40); local oDC = _wx.wxMemoryDC(); oDC:SelectObject(oBitmap);
        oField.draw(oDC, 200, 40); oDC:SelectObject(_wx.wxNullBitmap); oDC:delete();
        local oImage = oBitmap:ConvertToImage(); local oEditor = oLuma.Theme.color("Editor");
        fCheck(oImage:GetRed(0, 0) == oEditor:Red() and oImage:GetGreen(0, 0) == oEditor:Green()
            and oImage:GetBlue(0, 0) == oEditor:Blue(), "System client drawing leaves borders to wxWidgets.");
        oImage:delete(); oBitmap:delete();
        local oMeter = oLuma.Controls.progress(oFrame, {Min = 0, Max = 100, Value = 50, Text = ""});
        tOwned[#tOwned + 1] = oMeter;
        oLuma.Theme.setName("Obsidian");
        local oMeterBitmap = _wx.wxBitmap(200, 40);
        local oMeterDC = _wx.wxMemoryDC(); oMeterDC:SelectObject(oMeterBitmap);
        oMeter.draw(oMeterDC, 200, 40); oMeterDC:SelectObject(_wx.wxNullBitmap); oMeterDC:delete();
        local oMeterImage = oMeterBitmap:ConvertToImage(); local oBackground = oLuma.Theme.color("Background");
        fCheck(oMeterImage:GetRed(0, 0) == oBackground:Red() and oMeterImage:GetGreen(0, 0) == oBackground:Green()
            and oMeterImage:GetBlue(0, 0) == oBackground:Blue(), "Image-skin surface painting does not add a replacement border to a borderless meter.");
        oMeterImage:delete(); oMeterBitmap:delete();
    end, debug.traceback);
    for nIndex = #tOwned, 1, -1 do tOwned[nIndex].destroy(); end
    oFrame:Destroy(); _wx.wxYield();
    assert(bOK, sError); oLuma.Theme.destroy();
    print("Border regression: "..nChecks.." checks passed.");
    return nChecks;
end

return BorderRegression;
