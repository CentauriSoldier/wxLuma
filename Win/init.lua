-- Task desk showcase. The framework is beside the Windows test host.
assert(APP_PATH, "Launch this test with test.exe.");
package.path = APP_PATH .. "/../?.lua;" .. APP_PATH .. "/../?/init.lua;" .. APP_PATH .. "/?.lua;" .. APP_PATH .. "/?/init.lua;" ..
    APP_PATH .. "/Plugins/?.lua;" .. APP_PATH .. "/Plugins/?/init.lua";
package.cpath = APP_PATH .. "/Bin/?.dll";
local wx = require("wx");
wx.wxGetApp():SetAppName("wxLuma Task Desk");
local Run = require("Tests.UI");
local ui = Run(wx.NULL);
local smoke = arg[1] == "--smoke";
local timer;
if (smoke) then
    timer = wx.wxTimer(ui.Frame);
    ui.Frame:Connect(timer:GetId(), wx.wxEVT_TIMER, function()
        timer:Stop();
        assert(ui.Frame:IsShown() and ui.Widgets.Tasks and ui.Pages, "Task workspace startup incomplete.");
        ui.SelectTask(2);
        ui.Widgets.Title.setValue("Smoke review", true);
        assert(ui.GetTasks()[2].Title == "Smoke review", "Task editor did not save.");
        ui.Tabs.setValue(5);
        ui.Pages.Objects.Properties.setValue("version", "1.1", true);
        assert(ui.Pages.Settings.version == "1.1", "Project settings did not update.");
        ui.SetSkin("Obsidian"); ui.SetSkin("System");
        ui.Tabs.setValue(1);
        assert(ui.Widgets.Title.getValue() == "Smoke review", "Appearance changes reset the task.");
        ui.Frame:Close();
    end);
    timer:Start(500, true);
end
wx.wxGetApp():MainLoop();
collectgarbage("collect");
if (smoke) then
    local file = assert(io.open(APP_PATH .. "/smoke-result.txt", "w"));
    file:write("Task workspace startup, navigation, editing, settings, appearance changes, close and garbage collection passed.\n");
    file:close();
end
