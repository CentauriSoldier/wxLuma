param(
    [string] $ExportRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
    [ValidateSet('Old', 'New')]
    [string] $Variant,
    [ValidateSet('HUD', 'Heavy')]
    [string] $Profile,
    [int] $Round = 1
)

$ErrorActionPreference = 'Stop'
$benchmarkPath = Join-Path $PSScriptRoot 'GameStress.lua'
$resultPath = Join-Path $PSScriptRoot 'GameStressResults.json'
$binPath = Join-Path $ExportRoot 'Bin'

# Separate processes prevent deferred native windows or app state from one trial
# changing the paint work performed by the next implementation.
if (-not $Variant) {
    $allTrials = @()

    foreach ($profileName in @('HUD', 'Heavy')) {
        foreach ($roundNumber in @(1, 2)) {
            $order = if ($roundNumber -eq 1) { @('Old', 'New') } else { @('New', 'Old') }
            $pair = @{}

            foreach ($variantName in $order) {
                & (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File $PSCommandPath -ExportRoot $ExportRoot -Variant $variantName -Profile $profileName -Round $roundNumber
                if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

                $trialPath = Join-Path $PSScriptRoot "GameStress-$profileName-$variantName-$roundNumber.json"
                $trialDocument = Get-Content -LiteralPath $trialPath -Raw | ConvertFrom-Json
                $trial = $trialDocument.Trials[0]
                $pair[$variantName] = $trial
                $allTrials += $trial
                Start-Sleep -Milliseconds 500
            }

            if ($pair.Old.Callbacks -ne $pair.New.Callbacks -or $pair.Old.FinalListSelection -ne $pair.New.FinalListSelection) {
                throw 'Old/new behavior checks differ.'
            }
        }
    }

    $trialDocument.Trials = $allTrials
    $trialDocument | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultPath -Encoding utf8
    Write-Output "PASS: all eight isolated trials completed with matching behavior. Results: $resultPath"
    exit 0
}

$resultPath = Join-Path $PSScriptRoot "GameStress-$Profile-$Variant-$Round.json"

# Host the existing Lua DLL and expose a monotonic, high-resolution wall clock.
# The production launcher and all framework modules remain untouched.
Add-Type -TypeDefinition @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

public static class WxLumaGameHost
{
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate int LuaFunction(IntPtr state);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool SetDllDirectory(string path);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr LoadLibrary(string path);

    [DllImport("winmm.dll")]
    private static extern uint timeBeginPeriod(uint period);

    [DllImport("winmm.dll")]
    private static extern uint timeEndPeriod(uint period);

    [DllImport("lua54.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr luaL_newstate();

    [DllImport("lua54.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern void luaL_openlibs(IntPtr state);

    [DllImport("lua54.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern void lua_close(IntPtr state);

    [DllImport("lua54.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern void lua_pushnumber(IntPtr state, double number);

    [DllImport("lua54.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern void lua_pushstring(IntPtr state, [MarshalAs(UnmanagedType.LPUTF8Str)] string text);

    [DllImport("lua54.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern void lua_setglobal(IntPtr state, [MarshalAs(UnmanagedType.LPUTF8Str)] string name);

    [DllImport("lua54.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern void lua_pushcclosure(IntPtr state, LuaFunction function, int upvalues);

    [DllImport("lua54.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern double lua_tonumberx(IntPtr state, int index, IntPtr isNumber);

    [DllImport("lua54.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern int luaL_loadfilex(IntPtr state, [MarshalAs(UnmanagedType.LPUTF8Str)] string path, IntPtr mode);

    [DllImport("lua54.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern int lua_pcallk(IntPtr state, int arguments, int results, int errorFunction, IntPtr context, IntPtr continuation);

    [DllImport("lua54.dll", CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr lua_tolstring(IntPtr state, int index, out UIntPtr length);

    private static readonly LuaFunction ClockCallback = Clock;
    private static readonly LuaFunction SleepCallback = Sleep;

    private static int Clock(IntPtr state)
    {
        lua_pushnumber(state, Stopwatch.GetTimestamp() * (1000.0 / Stopwatch.Frequency));
        return 1;
    }

    private static int Sleep(IntPtr state)
    {
        double milliseconds = lua_tonumberx(state, 1, IntPtr.Zero);
        Thread.Sleep((int)Math.Max(0, Math.Min(1000, milliseconds)));
        return 0;
    }

    public static int Run(string root, string script, string results, string bin, string profile, string variant, int round)
    {
        IntPtr state = IntPtr.Zero;
        bool timerResolution = false;

        try
        {
            if (!SetDllDirectory(bin) || LoadLibrary(System.IO.Path.Combine(bin, "lua54.dll")) == IntPtr.Zero)
                throw new InvalidOperationException("Cannot load the bundled Lua runtime.");

            timerResolution = timeBeginPeriod(1) == 0;
            state = luaL_newstate();
            if (state == IntPtr.Zero)
                throw new InvalidOperationException("Cannot create the benchmark Lua state.");

            luaL_openlibs(state);
            lua_pushstring(state, profile);
            lua_setglobal(state, "BENCH_PROFILE");
            lua_pushstring(state, variant);
            lua_setglobal(state, "BENCH_VARIANT");
            lua_pushnumber(state, round);
            lua_setglobal(state, "BENCH_ROUND");
            lua_pushstring(state, root);
            lua_setglobal(state, "APP_PATH");
            lua_pushstring(state, results);
            lua_setglobal(state, "BENCH_RESULT_PATH");
            lua_pushnumber(state, Stopwatch.Frequency);
            lua_setglobal(state, "BENCH_CLOCK_FREQUENCY");
            lua_pushnumber(state, timerResolution ? 1 : 0);
            lua_setglobal(state, "BENCH_TIMER_RESOLUTION");
            lua_pushcclosure(state, ClockCallback, 0);
            lua_setglobal(state, "BENCH_NOW");
            lua_pushcclosure(state, SleepCallback, 0);
            lua_setglobal(state, "BENCH_SLEEP");

            int status = luaL_loadfilex(state, script, IntPtr.Zero);
            if (status == 0)
                status = lua_pcallk(state, 0, 0, 0, IntPtr.Zero, IntPtr.Zero);

            if (status != 0)
            {
                UIntPtr length;
                IntPtr error = lua_tolstring(state, -1, out length);
                Console.Error.WriteLine(Marshal.PtrToStringUTF8(error, checked((int)length.ToUInt64())));
            }

            return status == 0 ? 0 : 1;
        }
        finally
        {
            if (state != IntPtr.Zero)
                lua_close(state);
            if (timerResolution)
                timeEndPeriod(1);
            SetDllDirectory(null);
        }
    }
}
"@

exit [WxLumaGameHost]::Run($ExportRoot, $benchmarkPath, $resultPath, $binPath, $Profile, $Variant, $Round)