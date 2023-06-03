---@module MCT

---@alias MCT.OptionType 'slider'|'dropdown'|'checkbox'|'text_input'
---@alias MCT.System {_Types : {}, _Object : {}, _UI : {}, }

---@alias MCT.SelectedMod {[1]: mct_mod, [2]: Page}
---@alias MCT.Mode {context:'"global"'|'"campaign"', edit: boolean} #The current mode we're in.

--- (...) convert the full path of this file (ie. script/folder/folders/this_file.lua) to just the path leading to specifically this file (ie. script/folder/folders/), to grab subfolders easily while still allowing me to restructure this entire mod four times a year!
local this_path = string.gsub( (...) , "[^/]+$", "")

---@ignore
---@class mct
local mct_defaults = {
    _mods_path = "/script/mct/settings/",
    _self_path = this_path,
    _initialized = false,
    
    _registered_mods = {},

    ---@type MCT.SelectedMod
    _selected_mod = {nil, nil},

    _version = {0.9, "0.9-beta"},

    _Systems = {},

    _Objects = {},

    ---@type MCT.Mode
    __mode = {
        context = "global",
        edit = false,
    },
}

local load_module = GLib.LoadModule
local load_modules = GLib.LoadModules

---@class mct
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
        mct:load_and_start()
    end
end

---@return string
function mct:get_version()
    return self._version[2]
end

---@return number
function mct:get_version_number()
    return self._version[1]
end

---@return Registry
function mct:get_registry() return self:get_system("registry") end
---@return NotificationSystem
function mct:get_notification_system() return self:get_system("notifications") end
---@return UI_Main
function mct:get_ui() return self:get_system("ui") end
---@return Sync
function mct:get_sync() return self:get_system("sync") end
---@return mct_mod
function mct:get_mct_mod_class() return self:get_object("mods") end

---@return Control
function mct:get_mct_control_class() return self:get_object("controls") end
---@return Control
function mct:get_mct_control_class_type(t) return self:get_object_type("controls", t) end

---@return mct_option
function mct:get_mct_option_class() return self:get_object("options") end
---@return mct_option
function mct:get_mct_option_class_subtype(t) return self:get_object_type("options", t) end
---@return mct_section
function mct:get_mct_section_class() return self:get_object("sections") end

---@return Profile
function mct:get_profile_class() return self:get_object("profiles") end

---@return Notification
function mct:get_notification_class() return self:get_object("notifications") end
---@param type string
---@return Notification
function mct:get_notification_class_subtype(type) return self:get_object_type("notifications", type) end

---@return ControlGroup
function mct:get_control_group_class() return self:get_object("control_groups") end

---@return Page
function mct:get_mct_page_class() return self:get_object("page") end
---@param key string
---@return Page
function mct:get_mct_page_type(key) return self:get_object_type("page", key) end

---@return Main
function mct:get_mct_main_page_clas() return self:get_object_type("page", "main") end
---@return Settings
function mct:get_mct_settings_page_class() return self:get_object_type("page", "settings") end

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
    
    self:load_object("control_groups")
    self:load_object("controls")
    
    self:load_object("options")
    self:load_object("mods")

    self:load_object("page")
    self:load_object("sections")

    self:load_object("profiles")
    self:load_object("notifications")


    end) if not ok then GLib.Log("Error: " .. err) end
end

---comment
---@overload fun(key:"checkbox"):Checkbox
---@overload fun(key:"text_input"):TextInput
---@overload fun(key:"slider"):Slider
---@overload fun(key:"dropdown"):Dropdown
---@overload fun(key:"dummy"):Dummy
---@param key string
---@return Option?
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

            local long_err = debug.traceback("", 1)

            local mods = self:get_mods_from_file(filename)
            ---@type string|string[]
            local mod_str = {}

            for mod_key, mod_obj in pairs(mods) do
                mod_str[#mod_str+1] = mod_key

                --- put the Mod in timeout
                mod_obj:set_disabled(true, "Error while loading Mod File!")
            end

            mod_str = table.concat(mod_str, ", ")

            local n = self:get_notification_system():create_error_notification()
                    
            n
                :set_title("Error Loading MCT Mod!")
                :set_short_text(string.format("[[col:red]]Error while loading the mod %q in settings file `script/mct/settings/%s.lua`.[[/col]]\nThis mod has been disabled until the next game start.", mod_str, filename))
            n:set_error_text(string.format("[[col:red]]%q has been disabled due to an error while loading it.[[/col]] Report this issue to the mod author.\nFilepath is script/mct/settings/%s.lua\n\nError: %s", mod_str, filename, err))
                :set_long_text(long_err)
                :set_persistent(true)
        end
    )
end

--- TODO this should be in GLib!
--- the main holder with collapsible sections and all action buttons
---@param parent UIC The CA topbar that we're attaching underneath.
function mct:create_main_holder(parent)
    --- TODO add any title? tooltip?
    --- TODO add an open/close button for collapsing

    
    -- local holder = core:get_or_create_component("groovy_holder", "ui/groovy/holders/intense_holder", parent)
    -- holder:SetVisible(true)
    -- holder:Resize(parent:Width() * 0.7, 50)
    -- holder:SetDockingPoint(1)
    -- holder:SetDockOffset(5, parent:Height() * 0.7)

    -- local list = core:get_or_create_component("listview", "ui/groovy/layouts/hlistview", holder)
    -- list:Resize(holder:Width(), holder:Height())

    -- local box = find_uicomponent(list, "list_clip", "list_box")

    local existing_button
    local x = 0
    local x1,x2,y = 0,0,0
    local w = 0

    -- find the further button to the right on this holder, to use for spacing purposes
    for i = parent:ChildCount() - 1, 0, -1 do
        local child = UIComponent(parent:Find(i))

        if string.find(child:Id(), "button_") then
            -- set the last button to existing_button even if its not visible, so we always have ONE.
            if not existing_button then
                existing_button = child
            end

            if child:VisibleFromRoot() then
                existing_button = child
                break
            end
        end
    end

    if existing_button then
        x, y = existing_button:Position()
        w = existing_button:Width()

        if existing_button:VisibleFromRoot() then
            x1 = x + w
            x2 = x + (w) * 2
        else
            -- we're in frontend so move stuff backwards
            x1 = x - w
            x2 = x
        end
    end

    local button = self:get_ui():create_mct_button(parent, x1, y)
    local other_button = self:get_notification_system():get_ui():create_button(parent, x2, y)
end

function mct:open_panel()
    local ok, err = pcall(function()
    self:get_ui():open_frame()
    end) if not ok then GLib.Log("Panel brkoe!\n%s", err) end
end

---comment
---@param mod_obj mct_mod
---@param page_obj Page
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

---@return mct_mod
---@return Page #The opened page.
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
function mct:finalize(bForce)
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
---@return mct_mod?
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

---@return table<string, mct_mod>
function mct:get_mods()
    return self._registered_mods
end

---@return table<string, mct_mod>
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
---@return mct_mod
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


    local new_mod = self:get_mct_mod_class():new(mod_name)
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

function mct:set_mode(state, edit)
    if state == "global" or state == "campaign" then
        self.__mode.context = state
        self.__mode.edit = edit
    else
        GLib.Error("Invalid mode [%s] passed to set_mode().", state)
    end
end

function mct:get_mode()
    return self.__mode
end

function mct:get_mode_text()
    local mode = self:get_mode()

    -- Capitalize the word "global" or "campaign"
    local state = mode.context
    state = state:sub(1, 1):upper() .. state:sub(2)

    if mode.edit then
        return string.format("Editing %s Settings", state)
    else
        return string.format("Viewing %s Settings", state)
    end
    -- return string.format("Settings loaded from %s", mode.state)
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

    -- Search for anything BUT (^) alphanumeric characters (%w), hyphens (-) and underscores (_)
    if key:match("[^%w_%-]") then
        return false, "Only alphanumerical characters, hyphens and underscores are allowed in MCT keys!"
    end

    obj._key = key
    return true
end

--- Type-checker for @{mct_mod}s
--- @param obj any Tested value.
--- @return boolean Whether it passes.
function mct:is_mct_mod(obj)
    return is_table(obj) and obj.class
    and obj:instanceOf(mct:get_mct_mod_class())
end

function mct:is_mct_page(obj)
    return is_table(obj) and obj.class
    and obj:instanceOf(mct:get_mct_page_class())
end

function mct:is_mct_settings_page(obj)
    return is_table(obj) and obj.class
    and obj:instanceOf(mct:get_mct_settings_page_class())
end

function mct:is_mct_main_page(obj)
    return is_table(obj) and obj.class
    and obj:instanceOf(mct:get_mct_main_page_clas())
end

--- Type-checker for @{mct_option}s
--- @param obj any Tested value.
--- @return boolean Whether it passes.
function mct:is_mct_option(obj)
    return is_table(obj) and obj.class
    and obj:instanceOf(mct:get_mct_option_class())
end

--- Type-checker for @{mct_section}s
--- @param obj any Tested value.
--- @return boolean Whether it passes.
function mct:is_mct_section(obj)
    return is_table(obj) and obj.class
    and obj:instanceOf(mct:get_mct_section_class())
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

---@return mct
function get_mct()
    return mct
end

local ok, err = pcall(function()
mct:init()
end) if not ok then GLib.Log("Error loading MCT!\n%s", err) end

core:add_ui_created_callback(function()
    mct:get_ui():ui_created()
end)
