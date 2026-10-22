<#
.SYNOPSIS
Runs the standalone pyramid canvas demo or its checks with the bundled wxLua runtime.
.DESCRIPTION
Run ./TestPyramidCanvas.ps1 for the interactive demo. Use -Check for automated
offscreen tests, or -Smoke for those tests plus a briefly opened native demo.
The custom object and its tests stay outside the wxLuma framework.
#>
param([switch]$Check, [switch]$Smoke)

$ErrorActionPreference = 'Stop'
$taskRoot = $PSScriptRoot.Replace('\', '/')
if (-not ('PyramidCanvasHost' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class PyramidCanvasHost {
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

    // Keep DLL lookup changes local to this host and always close the Lua state.
    public static int Run(string root, string code) {
        IntPtr state = IntPtr.Zero;
        try {
            if (!SetDllDirectory(root + "/Win/Bin") || LoadLibrary(root + "/Win/Bin/lua54.dll") == IntPtr.Zero)
                throw new InvalidOperationException("Cannot load the bundled Lua runtime.");
            state = luaL_newstate();
            if (state == IntPtr.Zero) throw new InvalidOperationException("Cannot create Lua state.");
            luaL_openlibs(state);
            int result = luaL_loadstring(state, code);
            if (result == 0) result = lua_pcallk(state, 0, 0, 0, IntPtr.Zero, IntPtr.Zero);
            if (result != 0) {
                UIntPtr length;
                // Windows PowerShell 5.1 uses .NET Framework, which lacks
                // Marshal.PtrToStringUTF8. Copy Lua's exact byte length first.
                IntPtr message = lua_tolstring(state, -1, out length);
                byte[] bytes = new byte[checked((int)length.ToUInt64())];
                if (message != IntPtr.Zero) Marshal.Copy(message, bytes, 0, bytes.Length);
                Console.Error.WriteLine(message == IntPtr.Zero ? "Unknown Lua error." : Encoding.UTF8.GetString(bytes));
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
}
$taskCode = @"
package.path=[==[$taskRoot/?.lua]==]..';'..package.path;
package.cpath=[==[$taskRoot/Win/Bin/?.dll]==];
local wx=require('wx');
wx.wxGetApp():SetExitOnFrameDelete(false);
local test=require('PyramidCanvasTest');
"@
if ($Check -or $Smoke) { $taskCode += "`ntest.runChecks();" }
if (-not $Check -or $Smoke) {
    $taskCode += "`nlocal demo=test.createDemo(); demo.Frame:Show(true);"
    if ($Smoke) {
        $taskCode += @'

local timer=wx.wxTimer(demo.Frame);
demo.Frame:Connect(timer:GetId(),wx.wxEVT_TIMER,function()
    assert(demo.Frame:IsShown() and demo.Canvas.Control:IsShownOnScreen(),'Pyramid demo did not appear.');
    test.runInputChecks(demo);
    demo.Canvas.setRotation({Yaw=75,Pitch=35,Roll=0},true); demo.Canvas.setZoom(1.2,true);
    demo.Frame:Close(); wx.wxGetApp():ExitMainLoop();
end);
timer:Start(350,true);
'@
    }
    $taskCode += "`nwx.wxGetApp():MainLoop();"
    # The interactive loop must finish when its final frame is closed.
    if (-not $Smoke) { $taskCode = $taskCode.Replace('SetExitOnFrameDelete(false)', 'SetExitOnFrameDelete(true)') }
}
$taskResult = [PyramidCanvasHost]::Run($taskRoot, $taskCode)
if ($taskResult -ne 0) { throw "Pyramid canvas failed: $taskResult" }
