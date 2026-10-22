--[[!
@fqxn wxLuma.Tests.ReserveValueRegression
@desc Verifies hard usable-capacity limits, distinct maxima, atomic reserve/value
    notifications, creation clamping and the demo's bounded slider input.
!]]
APP_PATH = assert(arg[1], "Pass the export root.");
package.path = APP_PATH.."/../?.lua;"..APP_PATH.."/../?/init.lua;"..APP_PATH.."/?.lua;"..APP_PATH.."/?/init.lua;"..package.path;
package.cpath = APP_PATH.."/Bin/?.dll";
local _wx = require("wx");
local _Controls = require("wxLuma")().Controls;
local _nChecks = 0;

--[[!
@fqxn wxLuma.Tests.ReserveValueRegression.check
@desc Counts successful assertions and reports the violated capacity contract.
!]]
local function check(bPassed, sMessage)
    assert(bPassed, sMessage);
    _nChecks = _nChecks + 1;
end

--[[!
@fqxn wxLuma.Tests.ReserveValueRegression.run
@desc Checks all five progress factories with a nonzero Min, then exercises the
    actual workbench callbacks, keyboard endpoint and native pointer adapter.
!]]
local function run()
    _wx.wxGetApp():SetExitOnFrameDelete(false);
    local oSkin = _Controls.loadSkin();
    local oFrame = _wx.wxFrame(_wx.NULL, _wx.wxID_ANY, "Reserve value regression");

    for _, sFactory in ipairs({"progress", "circularProgress", "globeProgress", "radialProgress", "irisProgress"}) do
        local tOrder = {};
        local oMeter;
        oMeter = _Controls[sFactory](oFrame, {Skin = oSkin, Min = 10, Max = 110, Value = 110, Reserved = 20,
            OnChange = function(nValue, oSender)
                check(oSender == oMeter and nValue == oMeter.getValue()
                    and nValue <= oMeter.getEffectiveMax(), "OnChange sees committed usable value.");
                tOrder[#tOrder + 1] = "callback";
            end});
        check(oMeter.getValue() == 90 and #tOrder == 0, sFactory.." silently clamps creation value.");
        check(oMeter.getMax() == 110 and oMeter.getEffectiveMax() == 90, "Total and usable maxima are distinct.");
        oMeter.on("valueChanged", function(oSender, tEvent)
            check(oSender == oMeter and tEvent.Value == oMeter.getValue()
                and tEvent.OldValue ~= tEvent.Value, "Value event describes the committed change.");
            tOrder[#tOrder + 1] = "value";
        end);
        oMeter.on("reservedChanged", function(oSender, tEvent)
            check(oSender == oMeter and tEvent.EffectiveMax == oMeter.getEffectiveMax()
                and oMeter.getValue() <= tEvent.EffectiveMax, "Reserve event sees a coherent bounded value.");
            tOrder[#tOrder + 1] = "reserve";
        end);
        oMeter.setValue(oMeter.getMax(), true);
        oMeter.setValue(1000, true);
        check(oMeter.getValue() == 90 and #tOrder == 0 and oMeter.isFull(), "Setting full/overflow is capped and unchanged requests are silent.");
        oMeter.setValue(35.5, true);
        check(oMeter.getValue() == 35.5 and table.concat(tOrder, ",") == "callback,value", "Finite fractional values retain normal notifications.");
        tOrder = {};
        oMeter.setValue(oMeter.getMax(), true);
        check(oMeter.getValue() == 90 and table.concat(tOrder, ",") == "callback,value", "Setting full emits the accepted usable maximum.");
        tOrder = {};
        oMeter.setReserved(50, true);
        check(oMeter.getValue() == 60 and oMeter.getEffectiveMax() == 60
            and table.concat(tOrder, ",") == "callback,value,reserve", "Reserve increase trims current before all notifications.");
        tOrder = {};
        oMeter.setReserved(10, true);
        check(oMeter.getValue() == 60 and oMeter.getEffectiveMax() == 100
            and table.concat(tOrder, ",") == "reserve", "Reserve decrease leaves accepted current unchanged.");
        tOrder = {};
        oMeter.setReserved(100);
        check(oMeter.getValue() == 10 and oMeter.getEffectiveMax() == 10 and oMeter.isFull()
            and #tOrder == 0, "Silent fully reserved capacity clamps to Min.");
        oMeter.setValue(oMeter.getMax(), true);
        oMeter.setReserved(100, true);
        check(oMeter.getValue() == 10 and #tOrder == 0, "Full requests and repeated reserve stay silent at zero usable capacity.");
        oMeter.setReserved(0);
        check(oMeter.getValue() == 10 and oMeter.getMax() == oMeter.getEffectiveMax(), "Removing reserve does not restore discarded current.");

        for _, nBad in ipairs({-1, 101, math.huge, 0/0}) do
            check(not pcall(oMeter.setReserved, nBad, true) and oMeter.getReserved() == 0
                and oMeter.getValue() == 10, "Invalid reserve preserves value and capacity.");
        end

        check(not pcall(oMeter.setValue, math.huge, true) and oMeter.getValue() == 10, "Invalid current preserves the bounded state.");
        oMeter.destroy();
        local oFullReserve = _Controls[sFactory](oFrame, {Skin = oSkin, Min = 10, Max = 110, Value = 110, Reserved = 100});
        check(oFullReserve.getValue() == 10 and oFullReserve.isFull(), "Fully reserved creation stores Min.");
        oFullReserve.destroy();
    end

    oSkin.destroy();
    oFrame:Destroy();
    _wx.wxGetApp():Yield();
    local tDemo = require("Tests.UI")(_wx.NULL);
    local tWidgets = tDemo.Widgets;
    tDemo.Gallery.show("OrbValue", true);
    tWidgets.OrbValue.setValue(100, true);
    tWidgets.OrbReserved.setValue(25, true);
    check(tWidgets.OrbValue.getValue() == 75, "Demo reserve increase reflects the objects' accepted value.");
    tWidgets.OrbValue.setValue(100, true);
    tWidgets.OrbValue.handleKey("down", _wx.WXK_END);
    tWidgets.OrbValue.handleKey("up", _wx.WXK_END);
    check(tWidgets.OrbValue.getValue() == 75, "Demo programmatic/full-key input stops at reserve.");
    local nWidth, nHeight = tWidgets.OrbValue.Control:GetClientSizeWH();
    tWidgets.OrbValue.handlePointer("down", nWidth - 16, math.floor(nHeight / 2));
    tWidgets.OrbValue.handlePointer("up", nWidth - 16, math.floor(nHeight / 2));
    check(tWidgets.OrbValue.getValue() == 75, "Demo pointer endpoint cannot pass reserve.");

    for _, sKey in ipairs({"GlobeProgress", "RadialProgress", "IrisProgress"}) do
        check(tWidgets[sKey].getValue() == 75 and tWidgets[sKey].getEffectiveMax() == 75
            and tWidgets[sKey].getMax() == 100, "Demo meter and input agree: "..sKey);
    end

    tWidgets.OrbReserved.setValue(100, true);
    tWidgets.OrbValue.setValue(100, true);
    check(tWidgets.OrbValue.getValue() == 0 and tWidgets.IrisProgress.getValue() == 0,
        "Fully reserved demo accepts only zero.");
    tWidgets.OrbReserved.setValue(0, true);
    check(tWidgets.OrbValue.getValue() == 0, "Removing demo reserve does not restore discarded values.");
    tWidgets.OrbValue.setValue(100, true);
    check(tWidgets.GlobeProgress.getValue() == 100, "Removing reserve restores available input capacity.");
    tDemo.Frame:Close();
    _wx.wxGetApp():Yield();
end

run();
print("Reserve value regression: ".._nChecks.." checks passed.");
