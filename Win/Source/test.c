#define UNICODE
#define _UNICODE
#include <windows.h>
#include <shellapi.h>
#include <stdio.h>
#include <wchar.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

static wchar_t Root[32768];

static int Error(const char *message)
{
    wchar_t path[32768];
    wchar_t text[8192];
    FILE *file = NULL;
    if (swprintf_s(path, 32768, L"%ls\\test-error.log", Root) >= 0)
    {
        _wfopen_s(&file, path, L"ab");
        if (file != NULL) { fprintf(file, "%s\n", message); fclose(file); }
    }
    if (MultiByteToWideChar(CP_UTF8, 0, message, -1, text, 8192) == 0)
    {
        wcscpy_s(text, 8192, L"UI test startup failed. See test-error.log.");
    }
    MessageBoxW(NULL, text, L"UI Test", MB_OK | MB_ICONERROR);
    return 1;
}

static int PushWide(lua_State *state, const wchar_t *text)
{
    char utf8[131072];
    int length = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text, -1, utf8, sizeof(utf8), NULL, NULL);
    if (length == 0) { return 0; }
    lua_pushlstring(state, utf8, (size_t)(length - 1));
    return 1;
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, PWSTR command, int show)
{
    wchar_t bin[32768], libraryPath[32768], scriptPath[32768];
    wchar_t *separator, **arguments;
    char script[131072];
    DWORD length;
    HMODULE library;
    lua_State *state;
    int count, index, status;
    (void)instance; (void)previous; (void)command; (void)show;
    length = GetModuleFileNameW(NULL, Root, 32768);
    if (length == 0 || length >= 32768) { return Error("Cannot locate test.exe."); }
    separator = wcsrchr(Root, L'\\');
    if (separator == NULL) { return Error("Cannot determine the test folder."); }
    *separator = L'\0';
    if (swprintf_s(bin, 32768, L"%ls\\Bin", Root) < 0 ||
        swprintf_s(libraryPath, 32768, L"%ls\\lua54.dll", bin) < 0 ||
        swprintf_s(scriptPath, 32768, L"%ls\\init.lua", Root) < 0)
    { return Error("The test folder path is too long."); }
    if (!SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_DEFAULT_DIRS) ||
        AddDllDirectory(bin) == NULL || !SetCurrentDirectoryW(Root))
    { return Error("Cannot initialize the test runtime folder."); }
    library = LoadLibraryExW(libraryPath, NULL, LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
    if (library == NULL) { return Error("Cannot load Bin/lua54.dll or its runtime dependencies. Copy the entire test export folder."); }
    state = luaL_newstate();
    if (state == NULL) { return Error("Cannot create the Lua environment."); }
    luaL_openlibs(state);
    if (!PushWide(state, Root)) { lua_close(state); return Error("Cannot encode the test folder."); }
    lua_setglobal(state, "APP_PATH");
    arguments = CommandLineToArgvW(GetCommandLineW(), &count);
    if (arguments == NULL) { lua_close(state); return Error("Cannot read test arguments."); }
    lua_newtable(state);
    for (index = 0; index < count; ++index)
    {
        if (!PushWide(state, arguments[index]))
        { LocalFree(arguments); lua_close(state); return Error("Cannot encode a test argument."); }
        lua_rawseti(state, -2, index);
    }
    LocalFree(arguments);
    lua_setglobal(state, "arg");
    if (WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, scriptPath, -1, script, sizeof(script), NULL, NULL) == 0)
    { lua_close(state); return Error("Cannot encode the loader path."); }
    status = luaL_loadfile(state, script);
    if (status == LUA_OK) { status = lua_pcall(state, 0, 0, 0); }
    if (status != LUA_OK)
    {
        const char *message = lua_tostring(state, -1);
        Error(message == NULL ? "UI test failed." : message);
    }
    lua_close(state);
    FreeLibrary(library);
    return status == LUA_OK ? 0 : 1;
}