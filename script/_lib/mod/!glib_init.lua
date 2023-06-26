--- Create a new class object!
---@type fun(className:string,attr:table) : Class
local new_class = require "script.groovy.includes.30-log"

local path_of_groove = "script/groovy/"

do
    local Old = ModLog
    function ModLog(text)
        Old(tostring(text))
    end
end

---@class GLib : Class
local defaults = {
    ---@type table<string, GLib.Log>
    logs = {
        -- lib = nil,
    },

    --- TODO pointers for all of the currently loaded modules
    _Modules = {},
}

---@class GLib : Class
GLib = new_class("GLib", defaults)

---@type json
GLib.Json = require "script.groovy.includes.json"

---@class GLib.Log : Class
local log_defaults = {
    prefix = "[lib]",
    show_time = true,

    current_tab = 0,

    lines = {},
    
    file_name = "",

    enabled = true,

    ---@type file*
    file = nil,
}

---@class GLib.Log : Class
---@field __new fun():GLib.Log
local Log = new_class("VLib_Log", log_defaults)

--- Create a new Log Object.
---@param key string
---@param file_name string?
---@param prefix string?
function Log.new(key, file_name, prefix)
    local o = Log:__new()
    ---@cast o GLib.Log
    o:init(key, file_name, prefix)

    return o
end

function Log:init(key, file_name, prefix)
    self.key = key
    self.file_name = file_name or "logging.txt"
    self.prefix = prefix or "[lib]"

    --- TODO some test to see if this file was made in this session
    local file = io.open(self.file_name, "w+")
    self.file = file
end

function Log:__call(...)
    self:log(...)
end

function Log:get_tabs()
    local t = ""
    for i = 1,self.current_tab do
        t = t .. "\t"
    end

    return t
end

function Log:log(t, ...)
    if not self.enabled then return end

    --- TODO prevent errors if the string fails to format (ie. you pass a %s but no varargs)
    if ... then
        t = string.format(t, ...)
    end

    t = string.format("\n%s %s%s", self.prefix, self:get_tabs(), t)

    self.lines[#self.lines+1] = t
    self.file:write(t)
end

function Log:set_enabled(b)
    if not is_boolean(b) then b = true end

    self.enabled = b
end

--- Change the tab amount for this log.
---@param change number? The amount to change the tabs by (ie. -1, 1). Defaults to 1 if left blank.
function Log:tab(change)
    if not is_number(change) then change = 1 end
    self.current_tab = self.current_tab + change
end

--- Set the absolute amount for the tab.
---@param tab_amount number? The number of tabs to force, ie. if 4 is used then 4 tabs will be printed. Defaults to 0.
function Log:tab_abs(tab_amount)
    if not is_number(tab_amount) then tab_amount = 0 end
    self.current_tab = tab_amount
end

function GLib.FlushLogs()
    for _,log in pairs(GLib.logs) do
        log.file:flush()
    end
end

function GLib.init()
    --- TODO print
    GLib.logs.lib = GLib.NewLog("lib", "!groove_log.txt")

    local function start_flush()
        core:get_tm():repeat_real_callback(function()
            GLib.FlushLogs()
        end, 10, "vlib_logging")
    end 

    if core:is_campaign() then
        cm:add_first_tick_callback(start_flush)
    else
        start_flush()
    end

    GLib.LoadInternalModules()
end

--- Create a new Class object, which can be used to simulate OOP systems.
---@param key string The name of the Class object.
---@param params table? An optional table of defaults to assign to the Class and every Instance of it.
---@return Class
function GLib.NewClass(key, params)
    if not params then params = {} end
    return new_class(key, params)
end

--- Create a new Log Object.
---@param key string
---@param file_name string?
---@param prefix string?
function GLib.NewLog(key, file_name, prefix)
    if GLib.logs[key] then
        return GLib.logs[key]
    end

    --- TODO errcheck the types
    local o = Log.new(key, file_name, prefix)
    GLib.logs[key] = o

    return o
end

--- Get the @LogObj with this name.
---@param name string? The name of the log object when created. Leave blank to get the default one.
---@return GLib.Log?
function GLib.GetLog(name)
    if not is_string(name) then name = "lib" end
    local t = GLib.logs[name]
    if t then
        return t
    end

    GLib.Warn("Tried to get a Log with the name %s but none was found. Returning the default log object.", name)
end

function GLib.Log(t, ...)
    GLib.logs.lib:log(t, ...)
end

function GLib.Warn(t, ...)
    GLib.logs.lib:log("WARNING!\n" .. t, ...)
end

function GLib.Error(t, ...)
    GLib.logs.lib:log("ERROR!\n" .. t, ...)
    GLib.logs.lib:log(debug.traceback(1))
end

--- TODO handle the internal loading of modules!
function GLib.LoadInternalModules()
    local helpers_path = path_of_groove .. "helpers/"
    local modules_path = path_of_groove .. "modules/"

    GLib.LoadModule("extensions", helpers_path)
    GLib.LoadModule("helpers", helpers_path)
    GLib.LoadModule("uic", helpers_path)
    
    -- get individual modules!
    local function m(p) return modules_path .. p .. "/" end
    
    GLib.LoadModule("main", m("mp_communicator"))

    --- load up MCT
    --- TODO make this prettier; provide a path and autoload main.lua?
    local mct = GLib.LoadModule("main", m("mct"))

    ---@type CommandManager
    GLib.CommandManager = GLib.LoadModule("main", m("command_manager"))
    GLib.CommandManager:init()
end

--- Load a single file, and return its contents.
---@param module_name string The name of the file, without the ".lua" extension
---@param path string The path to the file, from .pack.
---@return any
function GLib.LoadModule(module_name, path)
    local full_path = path .. module_name .. ".lua"

    if GLib._Modules[full_path] then
        vlogf("Found an existing module %s! Returning that! Yay!", module_name)
        return GLib._Modules[full_path]
    end

    vlogf("Loading module w/ full path %q", full_path)
    local file, load_error = loadfile(full_path)

    if not file then
        verr("Attempted to load module with name ["..module_name.."], but loadfile had an error: ".. load_error .."")
        --return
    else
        vlog("Loading module with name [" .. module_name .. ".lua]")

        local global_env = core:get_env()
        setfenv(file, global_env)

        -- passing the `file` chunk any parameters turn into the vararg accessible in that file! Useful for localizing file paths.
        local lua_module = file(full_path)

        if lua_module ~= false then
            vlog("[" .. module_name .. ".lua] loaded successfully!")
        end

        GLib._Modules[full_path] = lua_module

        return lua_module
    end

    local ok, msg = pcall(function() require(module_name) end)

    if not ok then
        verr("Tried to load module with name [" .. module_name .. ".lua], failed on runtime. Error below:")
        verr(msg)
        return false
    end
end

--- Load every file, and return the Lua module, from within the folder specified, using the pattern specified.
---@param path string The path you're checking. Local to data, so if you're checking for any file within the script folder, use "script/" as the path.
---@param search_override string The file you're checking for. I believe it requires a wildcard somewhere, "*", but I haven't messed with it enough. Use "*" for any file, or "*.lua" for any lua file, or "*/main.lua" for any file within a subsequent folder with the name main.lua.
---@param func_for_each fun(filename:string, module:table)? Code to run for each module loaded.
---@param fail_func fun(filename:string, err:string)? Code to run if a module fails.
function GLib.LoadModules(path, search_override, func_for_each, fail_func)
    if not search_override then search_override = "*.lua" end
    -- vlogf("Checking %s for all main.lua files!", path)

    ---@diagnostic disable-next-line # stupid API error on my end.
    local file_str = common.filesystem_lookup(path, search_override)
    -- vlogf("Checking all module folders for main.lua, found: %s", file_str)
    
    for filename in string.gmatch(file_str, '([^,]+)') do
        local filename_for_out = filename

        local pointer = 1
        while true do
            local next_sep = string.find(filename, "\\", pointer) or string.find(filename, "/", pointer)

            if next_sep then
                pointer = next_sep + 1
            else
                if pointer > 1 then
                    filename = string.sub(filename, pointer)
                end
                break
            end
        end

        local suffix = string.sub(filename, string.len(filename) - 3)

        if string.lower(suffix) == ".lua" then
            filename = string.sub(filename, 1, string.len(filename) -4)
        end

        if not fail_func then
            fail_func = function(f, err) 
                verr("Failed to load module: " .. f)
                verr(err)
            end
        end

        GLib.CurrentlyLoadingFile = {
            name = filename,
            path = filename_for_out,
        }

        local module
        local ok, err = pcall(function()
            module = GLib.LoadModule(filename, string.gsub(filename_for_out, filename..".lua", ""))
            if func_for_each and is_function(func_for_each) then
                func_for_each(filename, module)
            end
            
        end)
        
        if not ok then
            ---@cast err string
            verr(err)
            fail_func(filename, err)
        end
    end

    GLib.CurrentlyLoadingFile = {}
end

---@return string #Full path for this file!
function GLib.ThisPath(...)
    --- (...) convert the full path of this file (ie. script/folder/folders/this_file.lua) to just the path leading to specifically this file (ie. script/folder/folders/), to grab subfolders easily while still allowing me to restructure this entire mod four times a year!
    return (string.gsub( (...) , "[^/]+$", ""))
end

function GLib.CopyToClipboard(txt)
    assert(is_string(txt), "You must pass a string to the clipboard!")

    common.set_context_value("CcoScriptObject", "GLibClipboard", txt)
    common.call_context_command("CcoScriptObject", "GLibClipboard", "CopyStringToClipboard(StringValue)")
end

--- Investigate an object and its metatable, and log all functions found.
---@param obj userdata
function GLib.Investigate(obj, name)
    if not name then name = "Unknown Object" end

    local l = GLib.Log

    l("Investigating object: %s", name)

    local mt = getmetatable(obj)

    if mt then
        for k,v in pairs(mt) do
            if is_function(v) then
                l("\tFound " .. name.."."..k.."()")
            elseif k == "__index" then
                l("\tIn index!")
                for ik,iv in pairs(v) do
                    if is_function(iv) then
                        l("\t\tFound " .. name.."."..ik.."()")
                    else
                        l("\t\tFound " .. name.."."..ik)
                    end
                end
            else
                l("\tFound " .. name.."."..k)
            end
        end
    end
end

function get_vlog(prefix)
    if not is_string(prefix) then prefix = "[lib]" end

    return --- Return log,logf,err,errf
        function(text) GLib.Log(prefix .. " " .. text) end,
        function(text, ...) GLib.Log(prefix .. " " .. text, ...) end,
        function(text) GLib.Error(prefix .. " " .. text) end,
        function(text, ...) GLib.Error(prefix .. " " .. text, ...) end
end

function vlog(text)
    GLib.Log(text)
end

function vlogf(text, ...)
    GLib.Log(text, ...)
end

function verr(text)
    GLib.Error(text)
end

function verrf(text, ...)
    GLib.Error(text, ...)
end

function GLib.EnableInternalLogging(b)
    GLib.logs.lib:set_enabled(b)
end

function GLib.EnableGameLogging(b)
    if b then
        -- Already enabled!
        if __write_output_to_logfile == true then
            return
        end

        __write_output_to_logfile = true

        -- if the logfile wasn't made yet, set it to the default.
        if __logfile_path == "" then
            -- Set the path to script_log_DDMMYY_HHMM.txt, based on the time this session was started (current_time - run_time)
            __logfile_path = "script_log_" .. os.date("%d".."".."%m".."".."%y".."_".."%H".."".."%M", os.time() - os.clock()) .. ".txt"

            local file, err_str = io.open(__logfile_path, "w");
	
            if not file then
                __write_output_to_logfile = false;
                script_error("ERROR: tried to create logfile with filename " .. __logfile_path .. " but operation failed with error: " .. tostring(err_str));
            else
                file:write("\n");
                file:write("creating logfile " .. __logfile_path .. "\n");
                file:write("\n");
                file:close();
                _G.logfile_path = __logfile_path;
            end;
        end
    else
        __write_output_to_logfile = false
    end
end

core:add_listener(
    "MctInitialized",
    "MctInitialized",
    true,
    function()
        local mod = get_mct():get_mod_by_key("mct_mod")
        local lib_logging = mod:get_option_by_key("lib_logging")
        local game_logging = mod:get_option_by_key("game_logging")

        -- if __write_output_to_logfile is already set, we can assume the user has already enabled it, so we should disable these functions.
        if __write_output_to_logfile then
            function GLib.EnableGameLogging() end

            game_logging:set_locked(true, "Another mod has already enabled game logging!")
        else
            game_logging:set_locked(false)
        end

        GLib.EnableInternalLogging(lib_logging:get_finalized_setting())
        GLib.EnableGameLogging(game_logging:get_finalized_setting())
    end,
    true
)

core:add_listener(
    "MctFinalized",
    "MctFinalized",
    true,
    function()
        local mod = get_mct():get_mod_by_key("mct_mod")
        local lib_logging = mod:get_option_by_key("lib_logging")
        local game_logging = mod:get_option_by_key("game_logging")

        GLib.EnableInternalLogging(lib_logging:get_finalized_setting())
        GLib.EnableGameLogging(game_logging:get_finalized_setting())
    end,
    true
)

GLib.init()

-- Backwards compat
VLib = GLib