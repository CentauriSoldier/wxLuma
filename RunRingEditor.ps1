<#
.SYNOPSIS
Runs the standalone wxLuma/CoG ring editor with the bundled wxLua runtime.
.DESCRIPTION
Run without switches for the interactive editor. -Check tests the model;
-Smoke also shows the editor, exercises native actions and closes it.
LuaExRoot is the repository directory containing LuaEx/load.lua. Its default
locates the existing LuaEx checkout beside this user's Sync/Projects directory.
No dependency is copied and no framework source file is changed.
#>
param(
    [switch]$Check,
    [switch]$Smoke,
    [string]$LuaExRoot = (Join-Path $PSScriptRoot '..\..\Documents\GitHub\LuaEx'),
    [string]$CapturePath
)

$ErrorActionPreference = 'Stop'
$taskRoot = $PSScriptRoot.Replace('\', '/')
$taskLuaRoot = (Resolve-Path -LiteralPath $LuaExRoot).Path.Replace('\', '/')
if (-not (Test-Path -LiteralPath (Join-Path $taskLuaRoot 'LuaEx/load.lua'))) {
    throw 'LuaExRoot must contain LuaEx/load.lua.'
}
if ($CapturePath -and -not $Smoke) { throw 'CapturePath requires -Smoke.' }
if (-not ('RingEditorHost' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class RingEditorHost {
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

    // Match the existing standalone host: always close Lua and restore DLL lookup.
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

# Long-bracket literals protect spaces, quotes and backslashes in installation paths.
if ($taskRoot.Contains(']==]') -or $taskLuaRoot.Contains(']==]') -or ($CapturePath -and $CapturePath.Contains(']==]'))) {
    throw 'A path contains the reserved Lua delimiter ]==].'
}
$taskCode = @"
package.path=[==[$taskRoot/?.lua;$taskRoot/?/init.lua;$taskLuaRoot/?.lua;$taskLuaRoot/?/init.lua]==]..';'..package.path;
package.cpath=[==[$taskRoot/Win/Bin/?.dll]==];
local wx=require('wx');
wx.wxGetApp():SetExitOnFrameDelete(false);
local editor=require('RingEditor');
local tests=require('RingEditorTest');
"@
if ($Check -or $Smoke) { $taskCode += "`ntests.runChecks();" }
if (-not $Check -or $Smoke) {
    $taskCode += @'

local created,demo=xpcall(editor.createDemo,debug.traceback);
if not created then print(demo); error(demo) end;
demo.Frame:Show(true);
'@
    if ($Smoke) {
        $taskCode += @'

local failure;
local timer=wx.wxTimer(demo.Frame);
demo.Frame:Connect(timer:GetId(),wx.wxEVT_TIMER,function()
    local ok,reason=xpcall(function()
        tests.runInputChecks(demo);
'@
        if ($CapturePath) {
            $taskCapture = [System.IO.Path]::GetFullPath($CapturePath).Replace('\', '/')
            $taskCode += @"

        demo.Frame:Refresh(); demo.Frame:Update(); wx.wxGetApp():Yield();
        local width,height=demo.Frame:GetClientSizeWH();
        local target=wx.wxBitmap(width,height);
        local dc=wx.wxMemoryDC(); dc:SelectObject(target);
        local screen=wx.wxClientDC(demo.Frame);
        dc:Blit(0,0,width,height,screen,0,0,wx.wxCOPY);
        screen:delete(); dc:SelectObject(wx.wxNullBitmap); dc:delete();
        assert(target:SaveFile([==[$taskCapture]==],wx.wxBITMAP_TYPE_PNG)); target:delete();
"@
        }
        $taskCode += @'

    end,debug.traceback);
    if not ok then failure=reason end;
    demo.Frame:Close(); wx.wxGetApp():ExitMainLoop();
end);
timer:Start(350,true);
'@
    }
    $taskCode += "`nwx.wxGetApp():MainLoop();"
    if ($Smoke) { $taskCode += "`nassert(not failure,failure); print('Ring editor smoke passed.');" }
    else { $taskCode = $taskCode.Replace('SetExitOnFrameDelete(false)', 'SetExitOnFrameDelete(true)') }
}
$taskResult = [RingEditorHost]::Run($taskRoot, $taskCode)
if ($taskResult -ne 0) { throw "Ring editor failed: $taskResult" }
