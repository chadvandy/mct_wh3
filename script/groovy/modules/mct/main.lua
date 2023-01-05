---@alias MCT.OptionType 'slider'|'dropdown'|'checkbox'|'text_input'
---@alias MCT.System {_Types : {}, _Object : {}, _UI : {}, }

--- (...) convert the full path of this file (ie. script/folder/folders/this_file.lua) to just the path leading to specifically this file (ie. script/folder/folders/), to grab subfolders easily while still allowing me to restructure this entire mod four times a year!
local this_path = string.gsub( (...) , "[^/]+$", "")

---@class ModConfigurationTool : Class
local mct_defaults = {
    _mods_path = "/script/mct/settings/",
    _self_path = this_path,
    _initialized = false,
    
    _registered_mods = {},

    ---@type {[1]: MCT.Mod, [2]: MCT.Page}
    _selected_mod = {nil, nil},

    _version = 0.9,

    _Systems = {},

    _Objects = {},
}

local load_module = GLib.LoadModule
local load_modules = GLib.LoadModules

---@class ModConfigurationTool : Class
local mct = GLib.NewClass("ModConfigurationTool", mct_defaults)

--- TODO figure out how to get "this path" w/ the way loadfile is being done 
-- local this_path = (...):gsub("\\", "/")

--- Initial creation and loading of MCT, and all the individual MCT Mods.
function mct:init()
    ModLog("MCT.Init")
    local ok, err = pcall(function()
        self:load_modules()
        self:load_mods()
    end) if not ok then ModLog(err) end


    ModLog("Done loading mods!")

    core:add_static_object("mod_configuration_tool", self)

    if not core:is_campaign() then
        -- trigger load_and_start after all mod scripts are loaded!
        core:add_listener(
            "MCT_Init",
            "ScriptEventAllModsLoaded",
            true,
            function(context)
                local ok, err = pcall(function()
                mct:load_and_start()
                end) if not ok then vlogf(err) end
            end,
            false
        )
    else
        vlog("LISTENING FOR LOAD GAME")
        
        mct:load_and_start()
    end
end

function mct:get_version()
    return self._version
end

---@return MCT.Registry
function mct:get_registry() return self:get_system("registry") end
---@return MCT.NotificationSystem
function mct:get_notification_system() return self:get_system("notifications") end
---@return MCT.Notification
function mct:get_notification() return self:get_object("notifications") end
---@return MCT.UI
function mct:get_ui() return self:get_system("ui") end
---@return MCT.Sync
function mct:get_sync() return self:get_system("sync") end
---@return MCT.Mod
function mct:get_mct_mod() return self:get_object("mods") end
---@return MCT.Option
function mct:get_mct_option() return self:get_object("options") end
---@return MCT.Option
function mct:get_mct_option_type(t) return self:get_object_type("options", t) end
---@return MCT.Section
function mct:get_mct_section() return self:get_object("sections") end
---@return MCT.Page
function mct:get_mct_page() return self:get_object("page") end
---@param key string
---@return MCT.Page
function mct:get_mct_page_type(key) return self:get_object_type("page", key) end

function mct:get_system(system_name, internal)
    local s = self._Systems[system_name]
    if internal then
        return s[internal]
    end

    return s
end

function mct:get_object(object_name)
    return self._Objects[object_name]
end

function mct:get_object_type(object_name, type_name)
    local o = self:get_object(object_name)

    if not o._Types then
        -- errmsg
        return false
    end

    return o._Types[type_name]
end

function mct:get_object_types(object_name)
    local o = self:get_object(object_name)

    return o._Types
end

function mct:get_path(...)
    local s = this_path
    
    for _, path_name in ipairs{...} do
        s = s .. path_name .. "/"
    end

    return s
end

--- Autoloader for each internal system, dealing with internal types, ui, main, and obj stuff
function mct:load_system(system_name)
    local path = self:get_path("systems", system_name)
    local sys_filename = "main"

    local function ex(file) return common.vfs_exists(path .. file .. ".lua") end

    if self._Systems[system_name] then
        return self._Systems[system_name]
    end

    -- Check for main first
    if ex(sys_filename) then
        self._Systems[system_name] = load_module(sys_filename, path)

        if is_function(self._Systems[system_name].init) then
            self._Systems[system_name]:init()
        end
    else
        --- TODO error?
        --- TODO does it want any specific fields maybe?
        self._Systems[system_name] = {}
    end
end

function mct:load_object(object_name, internal_type_loader)
    local obj_path = self:get_path("objects", object_name)
    local obj_filename = "obj"
    local function ex(file) return common.vfs_exists(obj_path .. file .. ".lua") end

    if self._Objects[object_name] then
        -- errmsg, already loaded!
        return self._Objects[object_name]
    end

    if ex(obj_filename) then
        self._Objects[object_name] = load_module(obj_filename, obj_path)
    end

    local o = self._Objects[object_name]
    o._Types = {}

    if not is_function(internal_type_loader) then
        internal_type_loader = function(filename, module)
            o._Types[filename] = module
        end
    end

    -- then autoload all internal "types"
    load_modules(
        obj_path.."types/",
        "*.lua",
        internal_type_loader
    )
end
--- Load up all the included modules for MCT - UI, Options, Settings, etc.
function mct:load_modules()

    self:load_system("ui")

    self:load_system("registry")
    self:load_system("sync")

    self:load_system("profiles")
    self:load_system("notifications")

    local ok, err = pcall(function()
    
    self:load_object("options")
    self:load_object("mods")

    self:load_object("page")
    self:load_object("sections")

    self:load_object("profiles")
    self:load_object("notifications")


    end) if not ok then GLib.Log("Error: " .. err) end
end

---comment
---@overload fun(key:"checkbox"):MCT.Option.Checkbox
---@overload fun(key:"text_input"):MCT.Option.TextInput
---@overload fun(key:"slider"):MCT.Option.Slider
---@overload fun(key:"dropdown"):MCT.Option.Dropdown
---@overload fun(key:"dummy"):MCT.Option.Dummy
---@param key string
---@return MCT.Option?
function mct:get_option_type(key)
    if not is_string(key) then
        --- errmsg
    end

    return self:get_object_type("options", key)
end

function mct:load_and_start()
    self._initialized = true
    self:get_registry():load()
end

function mct:load_mods()
    vlog("[mct] Loading Mod Settings!")

    local mods_path = self._mods_path

    load_modules(
        mods_path, 
        "*.lua", 
        function(filepath, module)
            vlogf("Loading mod %s!", filepath)
        end,
        function (filename, err)
            vlogf("Failed to load mod file %s! Error is %s", filename, err)

            local mods = self:get_mods_from_file(filename)
            ---@type string|string[]
            local mod_str = {}

            for mod_key, mod_obj in pairs(mods) do
                mod_str[#mod_str+1] = mod_key

                --- TODO put the MCT.Mod in timeout
                -- mod_obj:
            end

            mod_str = table.concat(mod_str, ", ")

            --- TODO trigger a notification with the error message + the mod in question.
            get_mct():get_ui():add_ui_created_callback(function()
                local n = self:get_notification_system():create_notification()
    
                n:set_title("Error Loading Mod!")
                n:set_short_text("Error while loading the mod " .. mod_str .. "!")
                n:set_long_text("Error while loading the mod " .. mod_str .. "!\nError is: " .. err)
                n:set_persistent(true)
    
                n:trigger_banner_popup()
            end)

        end
    )
end

--- the main holder with collapsible sections and all action buttons
---@param parent UIC The CA topbar that we're attaching underneath.
function mct:create_main_holder(parent)
    --- TODO add any title? tooltip?
    --- TODO add an open/close button for collapsing

    
    local holder = core:get_or_create_component("groovy_holder", "ui/groovy/holders/intense_holder", parent)
    holder:SetVisible(true)
    holder:Resize(parent:Width() * 0.7, 50)
    holder:SetDockingPoint(1)
    holder:SetDockOffset(5, parent:Height() * 0.7)

    local list = core:get_or_create_component("listview", "ui/groovy/layouts/hlistview", holder)
    list:Resize(holder:Width(), holder:Height())

    local box = find_uicomponent(list, "list_clip", "list_box")

    self:get_ui():create_mct_button(box)
    self:get_notification_system()._UI:create_button(box)
end

function mct:open_panel()
    local ok, err = pcall(function()
    self:get_ui():open_frame()
    end) if not ok then GLib.Log("Panel brkoe!\n%s", err) end
end

---comment
---@param mod_obj MCT.Mod
---@param page_obj MCT.Page
function mct:set_selected_mod(mod_obj, page_obj)
    self._selected_mod  = {
        mod_obj,
        page_obj,
    }

    common.set_context_value("mct_currently_selected_mod", mod_obj:get_key())
end

function mct:get_selected_mod_name()
    return self._selected_mod[1]:get_key()
end

---@return MCT.Mod
---@return MCT.Page #The opened page.
function mct:get_selected_mod()
    return self._selected_mod[1], self._selected_mod[2]
end

function mct:has_mod_with_name_been_registered(mod_name)
    return not not self._registered_mods[mod_name]
end

function mct:get_mod_with_name(mod_name)
    return self:get_mod_by_key(mod_name)
end

--- Internal use only. Triggers all the functionality for "Finalize Settings!"
function mct:finalize()
    if not self:get_registry():has_pending_changes() then return end

    -- check if it's MP!
    if __game_mode == __lib_type_campaign and cm.game_interface:model():is_multiplayer() then
        -- check if it's the host
        if cm:get_local_faction_name(true) == cm:get_saved_value("mct_host") then
            -- Send finalized settings to all clients (including self to keep models synced!)
            self:get_sync():distribute_finalized_settings()
            self:get_registry():local_only_finalize(true)
        else
            self:get_registry():local_only_finalize(false)
        end
    else
        self:get_registry():save()

        core:trigger_custom_event("MctFinalized", {["mct"] = self, ["mp_sent"] = false})
    end
end

--- Getter for the @{mct_mod} with the supplied key.
---@param mod_name string Unique identifier for the desired mct_mod.
---@return MCT.Mod?
function mct:get_mod_by_key(mod_name)
    if not is_string(mod_name) then
        verr("get_mod_by_key() called, but the mod_name provided ["..tostring(mod_name).."] is not a string!")
        return nil
    end
    
    local test = self._registered_mods[mod_name]
    if type(test) == "nil" then
        -- errlog("Trying to get mod with name ["..mod_name.."] but none is found! Returning nil.")
        return nil
    end
        
    return self._registered_mods[mod_name]
end

---@return table<string, MCT.Mod>
function mct:get_mods()
    return self._registered_mods
end

---@return table<string, MCT.Mod>
function mct:get_mods_from_file(filepath)
    local mod_list = self._registered_mods
    local retval = {}
    for key, mod in pairs(mod_list) do
        local compare_path = mod._FILENAME

        if compare_path == filepath then
            retval[key] = mod
        end
    end

    return retval
end

--- Primary function to begin adding settings to a "mod".
--- Calls the internal function @{mct_mod.new}.
--- @param mod_name string The identifier for this mod.
--- @see mct_mod.new
---@return MCT.Mod
function mct:register_mod(mod_name)
    vlogf("Registering mod %s", mod_name)


    -- get info about where this function was called from, to save that Lua file as a part of the mod obj
    local filename = GLib.CurrentlyLoadingFile.name

    if self:has_mod_with_name_been_registered(mod_name) then
        verr("Loading mod with name ["..mod_name.."], but it's already been registered. Only use `mct:register_mod()` once. Returning the previous version.")
        return self:get_mod_by_key(mod_name)
    end

    if mod_name == "mct_cached_settings" then
        verr("mct:register_mod() called with key \"mct_cached_settings\". Why have you tried to do this? Use a different key.")
            ---@diagnostic disable-next-line
        return
    end


    local new_mod = self:get_mct_mod():new(mod_name)
    new_mod._FILENAME = filename
    self._registered_mods[mod_name] = new_mod


    vlogf("Registered mod %s", mod_name)

    return new_mod
end

function mct:context(test_context)
    --- TODO 
    if not is_nil(cm) then
        return "campaign"
    end

    if not is_nil(bm) then
        if bm:get_campaign_key() == "" then 
            return "battle"
        else
            return "campaign"
        end
    end

    return "frontend"
end

--- Get the current state of MCT - if we're in view or edit mode, which registry is open, and what parts of that registry are available.
function mct:get_state()
    return {
        primary = "edit",
        views = {
            global = true,
            campaign = true,
        },
        is_client = false,
    }
end

function mct:get_state_text()
    local state = self:get_state()

    local primary = state.primary
    local views = state.views
    local is_client = state.is_client

    local u = primary:sub(1, 1)
    primary = u:upper() .. primary:sub(2)

    return string.format("%sing: %s", primary, "Global")
end

--- Unified system for verifying object keys. 
---@param obj table
---@param key string
---@return boolean #False if invalid, true if fine.
---@return string? #Error message!
function mct:verify_key(obj, key)
    -- Search for spaces.
    if key:match("%s") then
        return false, "You can't have any spaces in MCT keys!"
    end

    -- Search for anything BUT (^) alphanumeric characters (%w) and underscores (_)
    if key:match("[^%w_]") then
        return false, "Only alphanumerical characters and underscores are allowed in MCT keys!"
    end

    obj._key = key
    return true
end

--- Type-checker for @{mct_mod}s
--- @param obj any Tested value.
--- @return boolean Whether it passes.
function mct:is_mct_mod(obj)
    return is_table(obj) and obj.class
    and obj:instanceOf(mct:get_mct_mod())
end

--- Type-checker for @{mct_option}s
--- @param obj any Tested value.
--- @return boolean Whether it passes.
function mct:is_mct_option(obj)
    return is_table(obj) and obj.class
    and obj:instanceOf(mct:get_mct_option())
end

--- Type-checker for @{mct_section}s
--- @param obj any Tested value.
--- @return boolean Whether it passes.
function mct:is_mct_section(obj)
    return is_table(obj) and obj.class
    and obj:instanceOf(mct:get_mct_section())
end

--- Type-checker for @{mct_option} types.
--- @param val any Tested value.
--- @return boolean Whether it passes.
function mct:is_valid_option_type(val)
    return self:get_object_type("options", val)  ~= nil
end

function mct:get_valid_option_types()
    local retval = {}
    for k,_ in pairs(self:get_object_types("options")) do
        if k ~= "template" then
            retval[#retval+1] = k
        end
    end

    return retval
end

function mct:get_valid_option_types_table()
    local types = self:get_valid_option_types()
    local o = {}

    for i = 1, #types do
        local type = types[i]
        o[type] = {}
    end

    return o
end

---@return ModConfigurationTool
function get_mct()
    return mct
end

local ok, err = pcall(function()
mct:init()
end) if not ok then GLib.Log("Error loading MCT!\n%s", err) end

core:add_ui_created_callback(function()
    mct:get_ui():ui_created()
end)