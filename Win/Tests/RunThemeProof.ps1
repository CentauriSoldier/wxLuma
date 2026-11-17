<#
.SYNOPSIS
Runs the System/Obsidian proof with the packaged Lua and wxLua runtime.
.DESCRIPTION
Use -Check for automated behavior and memory-rendering regression checks.
Without switches, opens the interactive comparison for user visual inspection.
#>
param([switch]$Check)

$ErrorActionPreference = 'Stop'
$taskRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent).Replace('\', '/')
if ($taskRoot.Contains(']==]')) { throw 'The repository path contains a reserved Lua delimiter.' }

if (-not ('WxLumaThemeProofHost' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class WxLumaThemeProofHost {
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

    // Match the production host's DLL lookup, error reporting and Lua teardown.
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

# Long-bracket strings keep installation paths out of shell/Lua escape parsing.
$taskCode = @"
APP_PATH=[==[$taskRoot/Win]==];
package.path=[==[$taskRoot/?.lua;$taskRoot/?/init.lua]==]..';'..package.path;
package.cpath=[==[$taskRoot/Win/Bin/?.dll]==];
local wx=require('wx');
wx.wxGetApp():SetExitOnFrameDelete(false);
"@
if ($Check) {
    $taskCode += "`nrequire('Win.Tests.ThemeProofRegression').run();"
} else {
    $taskCode += @'

local demo=require('Win.Tests.ThemeProof').create();
wx.wxGetApp():SetExitOnFrameDelete(true);
demo.Frame:Show(true);
wx.wxGetApp():MainLoop();
collectgarbage('collect');
'@
}
$taskResult = [WxLumaThemeProofHost]::Run($taskRoot, $taskCode)
if ($taskResult -ne 0) { throw "Theme proof failed: $taskResult" }
