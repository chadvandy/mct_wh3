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

---@class GLib.Log : Class
local log_defaults = {
    prefix = "[lib]",
    show_time = true,

    current_tab = 0,

    lines = {},
    
    file_name = "",

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
    --- TODO prevent errors if the string fails to format (ie. you pass a %s but no varargs)
    if ... then
        t = string.format(t, ...)
    end

    t = string.format("\n%s %s%s", self.prefix, self:get_tabs(), t)

    self.lines[#self.lines+1] = t

    out(t)
    self.file:write(t)
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
    GLib.logs.lib = GLib.NewLog("lib", "!vandy_lib_log.txt")

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

    local helpers_path = path_of_groove .. "helpers/"
    local modules_path = path_of_groove .. "modules/"

    GLib.LoadModule("extensions", helpers_path)
    GLib.LoadModule("helpers", helpers_path)
    GLib.LoadModule("uic", helpers_path)

    
    -- get individual modules!
    local function m(p) return modules_path .. p .. "/" end
    
    --- load up MCT
    --- TODO make this prettier; provide a path and autoload main.lua?
    local mct = GLib.LoadModule("main", m("mct"))

    ---@type CommandManager
    GLib.CommandManager = GLib.LoadModule("main", m("command_manager"))
    GLib.CommandManager:init()
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

--- Load a single file, and return its contents.
---@param module_name string The name of the file, without the ".lua" extension
---@param path string The path to the file, from .pack.
---@return any
function GLib.LoadModule(module_name, path)
    local full_path = path .. module_name .. ".lua"
    vlogf("Loading module w/ full path %q", full_path)
    local file, load_error = loadfile(full_path)

    if not file then
        verr("Attempted to load module with name ["..module_name.."], but loadfile had an error: ".. load_error .."")
        --return
    else
        vlog("Loading module with name [" .. module_name .. ".lua]")

        local global_env = core:get_env()
        setfenv(file, global_env)
        local lua_module = file(full_path)

        if lua_module ~= false then
            vlog("[" .. module_name .. ".lua] loaded successfully!")
        end

        GLib._Modules[module_name] = lua_module

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
function GLib.LoadModules(path, search_override, func_for_each)
    if not search_override then search_override = "*.lua" end
    -- vlogf("Checking %s for all main.lua files!", path)

    ---@diagnostic disable-next-line # stupid API error on my end.
    local file_str = common.filesystem_lookup(path, search_override)
    -- vlogf("Checking all module folders for main.lua, found: %s", file_str)
    
    --- TODO make this safe if one module breaks
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

        local module = GLib.LoadModule(filename, string.gsub(filename_for_out, filename..".lua", ""))
        if func_for_each and is_function(func_for_each) then
            func_for_each(filename, module)
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


GLib.init()