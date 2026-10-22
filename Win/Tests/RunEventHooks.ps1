# Run event, inspector, gallery, state and additional-control regressions using the packaged runtime.
# Syntax loading does not execute other test scripts or write result files.
$ErrorActionPreference = 'Stop'
$taskRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent).Replace('\', '/')

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class WxLumaEventHookHost {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)]
    static extern bool SetDllDirectory(string path);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)]
    static extern IntPtr LoadLibrary(string path);
    [DllImport("lua54.dll", CallingConvention=CallingConvention.Cdecl)]
    static extern IntPtr luaL_newstate();
    [DllImport("lua54.dll", CallingConvention=CallingConvention.Cdecl)]
    static extern void luaL_openlibs(IntPtr state);
    [DllImport("lua54.dll", CallingConvention=CallingConvention.Cdecl)]
    static extern int luaL_loadstring(IntPtr state, [MarshalAs(UnmanagedType.LPUTF8Str)] string code);
    [DllImport("lua54.dll", CallingConvention=CallingConvention.Cdecl)]
    static extern int lua_pcallk(IntPtr state, int args, int results, int err, IntPtr ctx, IntPtr cont);
    [DllImport("lua54.dll", CallingConvention=CallingConvention.Cdecl)]
    static extern IntPtr lua_tolstring(IntPtr state, int index, out UIntPtr length);
    [DllImport("lua54.dll", CallingConvention=CallingConvention.Cdecl)]
    static extern void lua_close(IntPtr state);

    // Keep native DLL search changes scoped to this isolated test process.
    public static int Run(string root, string code) {
        IntPtr state = IntPtr.Zero;
        try {
            if (!SetDllDirectory(root + "/Win/Bin") || LoadLibrary(root + "/Win/Bin/lua54.dll") == IntPtr.Zero)
                throw new InvalidOperationException("Cannot load packaged Lua runtime.");
            state = luaL_newstate();
            if (state == IntPtr.Zero) throw new InvalidOperationException("Cannot create Lua state.");
            luaL_openlibs(state);
            int result = luaL_loadstring(state, code);
            if (result == 0) result = lua_pcallk(state, 0, 0, 0, IntPtr.Zero, IntPtr.Zero);
            if (result != 0) {
                UIntPtr length;
                Console.Error.WriteLine(Marshal.PtrToStringUTF8(lua_tolstring(state, -1, out length)));
            }
            return result;
        }
        finally {
            if (state != IntPtr.Zero) lua_close(state);
            SetDllDirectory(null);
        }
    }
}
'@

# Lua long strings preserve Windows paths without shell or Lua escape expansion.
$taskFiles = Get-ChildItem -LiteralPath $taskRoot -Recurse -File -Filter '*.lua'
$taskChecks = foreach ($taskFile in $taskFiles) {
    "assert(loadfile([==[$($taskFile.FullName)]==]));"
}
$taskCode = ($taskChecks -join "`n") + "`nAPP_PATH=[==[$taskRoot/Win]==]; assert(loadfile(APP_PATH..'/Tests/EventHooksRegression.lua'))(); assert(loadfile(APP_PATH..'/Tests/InspectorRegression.lua'))(); assert(loadfile(APP_PATH..'/Tests/DemoGalleryRegression.lua'))(); assert(loadfile(APP_PATH..'/Tests/StateRegression.lua'))(); assert(loadfile(APP_PATH..'/Tests/AdditionalControlsRegression.lua'))(); assert(loadfile(APP_PATH..'/Tests/SwitchLEDRegression.lua'))();"
$taskCode += " assert(loadfile(APP_PATH..'/Tests/LogChartRegression.lua'))();"
$taskResult = [WxLumaEventHookHost]::Run($taskRoot, $taskCode)
if ($taskResult -ne 0) { throw "wxLuma regression failed: $taskResult" }
Write-Output "Syntax loading passed for $($taskFiles.Count) Lua files."
