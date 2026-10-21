# UI Test

Copy this entire folder to another Windows x64 workstation and run test.exe. Keep Bin, Scripts and Images beside it. No installation, original repository, game startup, database, mods or preferences are used. Paths come from test.exe's own folder, regardless of the working directory. Live resizing is retained. Close the window or press Escape to exit (Escape first dismisses an open dropdown or cancels a panel drag).

Bin contains the Lua/wxLua/wxWidgets DLL dependency closure and three app-local Microsoft C/C++ runtime DLLs. Windows supplies its system DLLs and Universal C Runtime. This export was tested on the current Windows workstation, not a clean second machine. No WebView browser or media feature is used by the workbench.

## LuaEx

LuaEx is deliberately NOT included. Its reserved relative location is Scripts/Plugins/LuaEx/load.lua (put the LuaEx package folder, containing load.lua, at Scripts/Plugins/LuaEx). The loader already includes Scripts/Plugins/?.lua and Scripts/Plugins/?/init.lua in package.path. No junction or external absolute path is used.

The current workbench requires only wxLua and the reusable UI modules: it runs without LuaEx and does not initialize LuaEx. Dropping LuaEx into that location makes it available for future explicitly added tests; it does not initialize it automatically. There is consequently no missing-LuaEx error for this workbench.

## Contents

- test.exe: newly compiled native launcher for this independent UI test, not a renamed application executable.
- Bin: 18 runtime DLLs, selected from recursive native import inspection.
- Scripts/init.lua: minimal loader; only starts Tests/UI.lua and the wx event loop.
- Scripts/Tests/UI.lua: standalone workbench copy with UI Test branding and sample data.
- Scripts/UI: 13 widget implementations, five shared helpers, Controls.lua compatibility facade and Window.lua surface. Window's default title is neutral in this export copy.
- Images/UI/Controls and Images/UI/Window: 57 PNG skin parts.
- Source: launcher C source, build.cmd, copy/runtime hash records and validation notes. Source is not required to run.
- Licenses: upstream runtime/library notices. Microsoft runtime binaries are from the installed Visual Studio redistribution directory; their applicable Microsoft redistribution terms remain in force.

No original files were moved or modified by packaging. Existing reusable module documentation may retain its original namespace.

## Diagnostic run and rebuilding

Run test.exe --smoke for a brief automatic startup/tab/list/live-panel/close check. Success writes smoke-result.txt beside test.exe after garbage collection. Startup errors display a UI Test error message and append test-error.log beside test.exe.

Rebuilding is optional and needs an x64 Visual Studio Developer Command Prompt, Lua 5.4 headers and its matching lua54.lib. From Source run:

    build.cmd "path to Lua include folder" "path to lua54.lib"

The build writes ../test.exe and test.obj in Source; the SDK is not needed to run the built export.