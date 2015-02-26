#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lauxlib.h>
#import <pthread.h>
#import "../../Crashlytics.framework/Headers/Crashlytics.h"

// ----------------------- API Implementation ---------------------

/// hs.crash.crash()
/// Function
/// Causes Hammerspoon to immediately crash.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * This is for testing purposes only, you are extremely unlikely to need this in normal Hammerspoon usage
static int burnTheWorld(lua_State *L __unused) {
    int *x = NULL; *x = 42;
    return 0;
}

extern pthread_t mainthreadid;

/// hs.crash.isMainThread() -> bool
/// Function
/// Determine if Lua execution is happening on the main thread
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, true if you are on the main thread, false if not
///
/// Notes:
/// * This is for testing purposes only, you are extremely unlikely to need this in normal Hammerspoon usage
/// * When developing a new extension, especially one that involves handlers for outside events, this function
///   can be used to make sure your event handling happens on the main thread. It is extremely important that Lua
///   execution happen only on the main thread of Hammerspoon
/// * You can use this Lua code to make Hammerspoon abort if anything happens on a different thread:
///   ```lua
///   local function crashifnotmain(reason)
///     print("crashifnotmain called with reason", reason) -- may want to remove this, very verbose otherwise
///     if not hs.crash.isMainThread() then
///       print("not in main thread, crashing")
///       hs.crash.crash()
///     end
///   end
///
///   debug.sethook(crashifnotmain, 'c')
///   ```

static int isMainThread(lua_State *L)
{
    pthread_t id = pthread_self();

    lua_pushboolean(L, pthread_equal(mainthreadid, id));
    return 1;
}

/// hs.crash.dumpCLIBS() -> table
/// Function
/// Dumps the contents of Lua's CLIBS registry
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing all the paths of C libraries that have been loaded into the Lua runtime
///
/// Notes:
///  * This is probably only useful to extension developers as a useful way of ensuring that you are loading C libraries from the places you expect.
static int dumpCLIBS(lua_State *L) {
    int stack_ref;
    int i;
    NSMutableSet *cLibs = [[NSMutableSet alloc] init];

    lua_getfield(L, LUA_REGISTRYINDEX, "_CLIBS");
    stack_ref = lua_gettop(L);

    lua_pushnil(L);
    while (lua_next(L, stack_ref) != 0) {
        // lua_next pushed two things onto the stack, the key at -2 and the value at -1
        if (lua_type(L, -2) == LUA_TSTRING) {
            [cLibs addObject:[NSString stringWithUTF8String:lua_tostring(L, -2)]];
        }
        lua_pop(L, 1);
    }

    i = 1;
    lua_newtable(L);
    for (NSString *cLib in [cLibs allObjects]) {
        lua_pushnumber(L, i++);
        lua_pushstring(L, [cLib UTF8String]);
        lua_settable(L, -3);
    }
    return 1;
}

/// hs.crash.crashLog(logMessage)
/// Function
/// Leaves a breadcrumb log message in any Crashlytics crash dump generated by this Hammerspoon session
///
/// Parameters:
///  * logMessage - A string
///
/// Returns:
///  * None
///
/// Notes:
///  * This is probably only useful to extension developers. If you are trying to track down a confusing crash, and you have access to the Crashlytics project for Hammerspoon (or access to someone who has access!), this can be a useful way to leave breadcrumbs from Lua in the crash dump
static int crashLog(lua_State *L) {
    CLS_LOG("%s", lua_tostring(L, -1));

    return 0;
}

// ----------------------- Lua/hs glue GAR ---------------------

static const luaL_Reg crashlib[] = {
    {"crash", burnTheWorld},
    {"isMainThread", isMainThread},
    {"dumpCLIBS", dumpCLIBS},
    {"crashLog", crashLog},

    {}
};

/* NOTE: The substring "hs_crash_internal" in the following function's name
         must match the require-path of this file, i.e. "hs.crash.internal". */

int luaopen_hs_crash_internal(lua_State *L) {
    // Table for luaopen
    luaL_newlib(L, crashlib);

    return 1;
}
