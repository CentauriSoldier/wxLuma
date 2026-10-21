-- Independent UI workbench. The framework is beside the Windows test host.
assert(APP_PATH, "Launch this test with test.exe.");
package.path = APP_PATH .. "/../?.lua;" .. APP_PATH .. "/../?/init.lua;" .. APP_PATH .. "/?.lua;" .. APP_PATH .. "/?/init.lua;" ..
    APP_PATH .. "/Plugins/?.lua;" .. APP_PATH .. "/Plugins/?/init.lua";
package.cpath = APP_PATH .. "/Bin/?.dll";
local wx = require("wx");
wx.wxGetApp():SetAppName("UI Test");
local Run = require("Tests.UI");
local ui = Run(wx.NULL);
local smoke = arg[1] == "--smoke";
local timer;
if (smoke) then
    timer = wx.wxTimer(ui.Frame);
    ui.Frame:Connect(timer:GetId(), wx.wxEVT_TIMER, function()
        timer:Stop();
        assert(ui.Frame:IsShown() and ui.Widgets.List and ui.Widgets.Panel, "Workbench startup incomplete.");
        ui.Widgets.Tabs.setValue(2);
        ui.Widgets.List.setValue(25);
        ui.Widgets.Tabs.setValue(3);
        ui.Widgets.Panel.resize(440, 200);
        assert(ui.Widgets.Panel.Content:IsShown() and not ui.Widgets.Panel.Content:IsFrozen(), "Live panel unavailable.");
        ui.Frame:Close();
    end);
    timer:Start(500, true);
end
wx.wxGetApp():MainLoop();
collectgarbage("collect");
if (smoke) then
    local file = assert(io.open(APP_PATH .. "/smoke-result.txt", "w"));
    file:write("UI workbench startup, tab/list/panel operations, close and garbage collection passed.\n");
    file:close();
end