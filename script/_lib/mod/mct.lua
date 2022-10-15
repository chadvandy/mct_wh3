---@alias MCT.OptionType 'slider'|'dropdown'|'checkbox'|'text_input'

---@class ModConfigurationTool : Class
local mct_defaults = {
    _mods_path = "/script/mct/settings/",
    _self_path = "/script/vlib/mct/",
    _initialized = false,
    
    _registered_mods = {},

    ---@type {[1]: MCT.Mod, [2]: MCT.Page}
    _selected_mod = {nil, nil},

    _version = 0.9,
}

local load_module = VLib.LoadModule
local load_modules = VLib.LoadModules

---@class ModConfigurationTool : Class
local mct = VLib.NewClass("ModConfigurationTool", mct_defaults)

--- Initial creation and loading of MCT, and all the individual MCT Mods.
function mct:init()
    self:load_modules()
    self:load_mods()

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
        
        cm:add_loading_game_callback(function(context)
            vlog("LOADING GAME CALBACK")
            if not cm.game_interface:model():is_multiplayer() then
                mct:load_and_start(context, false)
            else
                mct:load_and_start(context, true)
            end

            vlog("Done the loading game callback!")
        end)
    end
end

function mct:get_version()
    return self._version
end

--- Create a new MCT.Page type
---@param key string
---@param layout MCT.Page
function mct:add_new_page_type(key, layout)
    self._MCT_PAGE_TYPES[key] = layout
end

---@param key string
---@return MCT.Page
function mct:get_page_type(key)
    return self._MCT_PAGE_TYPES[key]
end

--- Load up all the included modules for MCT - UI, Options, Settings, etc.
function mct:load_modules()
    local path = "script/vlib/mct/"
    local core_path = path .. "core/"
    local ui_path = core_path .. "ui/"
    local obj_path = path .. "objects/"
    local options_path = path .. "option_types/"
    local layout_path = path .. "layouts/"

    -- ---@type MCT.Settings
    -- self.settings = load_module("settings", core_path)

    ---@type MCT.Profile
    self._MCT_PROFILE = load_module("profile", obj_path)

    ---@type MCT.Registry
    self.registry = load_module("registry", obj_path)

    ---@type MCT.UI
    self.ui = load_module("main", ui_path)

    ---@type MCT.Sync
    self.sync = load_module("sync", obj_path)

    if __game_mode == __lib_type_battle then
        load_module("battle", ui_path)
    elseif __game_mode == __lib_type_campaign then
        load_module("campaign", ui_path)
    elseif __game_mode == __lib_type_frontend then
        load_module("frontend", ui_path)
    end

    ---@type MCT.Page
    self._MCT_PAGE = load_module("layout", obj_path)

    ---@type table<string, MCT.Page>
    self._MCT_PAGE_TYPES = { }

    --- TODO use the func_for_each thing 
    --- Load all Page types 
    load_modules(layout_path, "*.lua")

    ---@type table<string, MCT.Option>
    self._MCT_TYPES = { }

    --- TODO autoload
    ---@type MCT.Option
    self._MCT_OPTION = load_module("option", obj_path)
    
    ---@type MCT.Option.Dummy
    self._MCT_TYPES.dummy = load_module("dummy", options_path)

    ---@type MCT.Option.Slider
    self._MCT_TYPES.slider = load_module("slider", options_path)

    ---@type MCT.Option.Dropdown
    self._MCT_TYPES.dropdown = load_module("dropdown", options_path)
    
    ---@type MCT.Option.SpecialDropdown
    self._MCT_TYPES.dropdown_game_object = load_module("dropdown_game_object", options_path)

    ---@type MCT.Option.Checkbox
    self._MCT_TYPES.checkbox = load_module("checkbox", options_path)

    ---@type MCT.Option.TextInput
    self._MCT_TYPES.text_input = load_module("text_input", options_path)

    ---@type MCT.Mod
    self._MCT_MOD = load_module("mod", obj_path)

    ---@type MCT.Section
    self._MCT_SECTION = load_module("section", obj_path)
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

    if not self._MCT_TYPES[key] then
        --- errmsg
        return nil
    end

    return self._MCT_TYPES[key]
end

--- TODO clean this the fuck up
function mct:load_and_start(loading_game_context, is_mp)
    self._initialized = true
    self.registry:load(loading_game_context, is_mp)
end

function mct:load_mods()
    vlog("[mct] Loading Mod Settings!")
    local mods_path = self._mods_path
    load_modules(
        mods_path, 
        "*.lua", 
        function(filepath, module)
            vlogf("Loading mod %s!", filepath)
        end
    )
end

function mct:open_panel()
    self.ui:open_frame()
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
    if not self.registry:has_pending_changes() then return end

    -- check if it's MP!
    if __game_mode == __lib_type_campaign and cm.game_interface:model():is_multiplayer() then
        -- check if it's the host
        if cm:get_local_faction_name(true) == cm:get_saved_value("mct_host") then
            -- Send finalized settings to all clients (including self to keep models synced!)
            self.sync:distribute_finalized_settings()
            self.registry:local_only_finalize(true)
        else
            self.registry:local_only_finalize(false)
        end
    else
        self.registry:save()

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

function mct:get_mods_from_file(filepath)
    local mod_list = self._registered_mods
    local retval = {}
    for key, mod in pairs(mod_list) do
        local compare_path = mod._FILEPATH

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
    local info = debug.getinfo(2, "S")
    local filepath = info.source
    if self:has_mod_with_name_been_registered(mod_name) then
        verr("Loading mod with name ["..mod_name.."], but it's already been registered. Only use `mct:register_mod()` once. Returning the previous version.")
        return self:get_mod_by_key(mod_name)
    end

    if mod_name == "mct_cached_settings" then
        verr("mct:register_mod() called with key \"mct_cached_settings\". Why have you tried to do this? Use a different key.")
            ---@diagnostic disable-next-line
        return
    end


    local new_mod = self._MCT_MOD:new(mod_name)
    new_mod._FILEPATH = filepath
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

--- Type-checker for @{mct_mod}s
--- @param obj any Tested value.
--- @return boolean Whether it passes.
function mct:is_mct_mod(obj)
    return is_table(obj) and obj.class
    and obj:instanceOf(mct._MCT_MOD)
end

--- Type-checker for @{mct_option}s
--- @param obj any Tested value.
--- @return boolean Whether it passes.
function mct:is_mct_option(obj)
    return is_table(obj) and obj.class
    and obj:instanceOf(mct._MCT_OPTION)
end

--- Type-checker for @{mct_section}s
--- @param obj any Tested value.
--- @return boolean Whether it passes.
function mct:is_mct_section(obj)
    return is_table(obj) and obj.class
    and obj:instanceOf(mct._MCT_SECTION)
end

--- Type-checker for @{mct_option} types.
--- @param val any Tested value.
--- @return boolean Whether it passes.
function mct:is_valid_option_type(val)
    return self._MCT_TYPES[val] ~= nil
end

function mct:get_valid_option_types()
    local retval = {}
    for k,_ in pairs(self._MCT_TYPES) do
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

mct:init()

core:add_ui_created_callback(function()
    mct.ui:ui_created()
end)